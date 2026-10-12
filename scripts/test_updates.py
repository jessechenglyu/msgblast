#!/usr/bin/env python3
"""Exercise real Sparkle against temporary signed localhost fixtures. Never touches the live app."""
import argparse
import functools
import http.server
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import threading
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SP = "http://www.andymatuschak.org/xml-namespaces/sparkle"

def run(args, **kwargs):
    result = subprocess.run([str(x) for x in args], capture_output=True, text=True, **kwargs)
    if result.returncode:
        raise RuntimeError(f"{args[0]} failed: {result.stderr or result.stdout}")
    return result.stdout.strip()

class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

def bundle(source, destination, build, feed, key, store, probe=False, recovery=False):
    run(["ditto", source, destination])
    path = destination / "Contents/Info.plist"
    info = plistlib.loads(path.read_bytes())
    info.update(CFBundleIdentifier="com.msgblast.update-fixture", CFBundleName="msgblast Update Fixture",
                CFBundleShortVersionString="0.1." + str(build), CFBundleVersion=str(build),
                SUFeedURL=feed, SUPublicEDKey=key, msgblastDemo=True, msgblastUpdateFixture=True,
                msgblastFixtureStore=str(store), msgblastUpdateProbeRelaunch=probe, msgblastUpdateRecoveryFixture=recovery, SUEnableAutomaticChecks=False, SUAutomaticallyUpdate=False)
    path.write_bytes(plistlib.dumps(info))
    run(["codesign", "--force", "--sign", "-", "--options", "runtime", "--entitlements", ROOT / "msgblast/msgblastDebug.entitlements", destination])
    run(["codesign", "--verify", "--deep", "--strict", destination])

def seed(store):
    store.mkdir(parents=True, exist_ok=True)
    staged = store / "Attachments/fixture/retained.txt"
    staged.parent.mkdir(parents=True, exist_ok=True)
    staged.write_text("Retain this synthetic attachment through an update.\n")
    # This fixture checks that an explicit recipient choice survives an update.
    # An empty choice must remain empty; app launch no longer auto-selects agents.
    state = {"version": 1, "agents": [{"id": "11111111-1111-1111-1111-111111111111", "name": "Cedar", "handles": ["cedar@example.com"], "colorIndex": 0, "contactID": "fixture-0"}], "comparisons": [], "selection": ["11111111-1111-1111-1111-111111111111"], "draft": "Retained update-fixture draft", "frames": {},
             "attachmentsDraft": [{"id": "fixture", "filename": "retained.txt", "path": str(staged), "byteCount": staged.stat().st_size}]}
    (store / "state.json").write_text(json.dumps(state))
    return staged

def version(app):
    return plistlib.loads((app / "Contents/Info.plist").read_bytes())["CFBundleVersion"]

def generate_key(directory):
    private = directory / "fixture-private-key"
    code = """import Foundation
import CryptoKit
let key = Curve25519.Signing.PrivateKey()
try Data(key.rawRepresentation.base64EncodedString().utf8).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print(key.publicKey.rawRepresentation.base64EncodedString())
"""
    script = directory / "key.swift"
    script.write_text(code)
    public = run(["swift", script, private])
    private.chmod(0o600)
    return private, public

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derived-data", type=Path, default=ROOT / "build/updater-validation")
    parser.add_argument("--ui", action="store_true", help="Serve an isolated fixture for manual native UI verification until interrupted")
    parser.add_argument("--keep", action="store_true", help="Keep fixture bundles and reports; private key is always deleted")
    args = parser.parse_args()
    derived = args.derived_data.resolve()
    source = derived / "Build/Products/Debug/msgblast.app"
    tools = derived / "SourcePackages/artifacts/sparkle/Sparkle/bin"
    if not source.is_dir():
        parser.error("Build the Debug app with Xcode in the chosen derived data directory first")
    source_info = plistlib.loads((source / "Contents/Info.plist").read_bytes())
    if source_info.get("CFBundleIconName") != "AppIconDemo":
        parser.error("Updater fixtures require AppIconDemo; rebuild with ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo")
    work = Path(tempfile.mkdtemp(prefix="msgblast-update-fixture-"))
    server = None
    key_file = None
    report = {"fixture_root": str(work), "limitations": "Local signed, ad-hoc Debug fixtures; no production notarization, real sends or Contacts writes.", "cases": []}
    try:
        key_file, public = generate_key(work)
        served = work / "served"
        served.mkdir()
        server = Server(("127.0.0.1", 0), functools.partial(QuietHandler, directory=str(served)))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = f"http://127.0.0.1:{server.server_port}/"
        # Store on macOS's per-user temporary root, which the DEBUG fixture policy accepts.
        store = work / "data"
        staged = seed(store)
        candidate = work / "candidate/msgblast.app"
        candidate.parent.mkdir()
        bundle(source, candidate, 2, base + "appcast.xml", public, store, probe=not args.ui)
        archive = served / "msgblast-0.1.2.zip"
        run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", candidate, archive])
        (served / "msgblast-0.1.2.md").write_text("- Native update checks and preferences\n- Keep drafts and staged attachments through updates\n")
        run([tools / "generate_appcast", "--ed-key-file", key_file, "--download-url-prefix", base, "--embed-release-notes", "--maximum-deltas", "0", served])
        good_feed = (served / "appcast.xml").read_bytes()
        good_archive = archive.read_bytes()
        if args.ui:
            installed = work / "ui/msgblast.app"
            installed.parent.mkdir()
            bundle(source, installed, 1, base + "appcast.xml", public, store)
            print(f"UI fixture app: {installed}\nSynthetic draft and attachment store: {store}\nSigned localhost feed: {base}appcast.xml", flush=True)
            try: threading.Event().wait()
            except KeyboardInterrupt: return
        for name, expected_exit, expected_build in [("install-and-preserve", 0, "2"), ("unreadable-state-recovery", 0, "2"), ("no-update", 3, "2"), ("invalid-signature", 1, "1"), ("failed-download", 1, "1")]:
            recovery = name == "unreadable-state-recovery"
            case_store = work / "recovery-store" if recovery else store
            if recovery:
                seed(case_store)
                # Complete synthetic state with a provider unknown to this reader.
                future_state = json.loads((case_store / "state.json").read_text())
                future_state["comparisons"] = [{"id": "22222222-2222-2222-2222-222222222222",
                    "prompt": "Synthetic saved comparison", "created": 0, "members": [], "followUps": [],
                    "allDraft": "Saved comparison draft", "privateDrafts": {},
                    "webProviders": ["future-provider"], "webProviderIdentityVersion": 2}]
                original_bytes = json.dumps(future_state).encode()
                (case_store / "state.json").write_bytes(original_bytes)
                recovery_candidate = work / "recovery-candidate/msgblast.app"
                recovery_candidate.parent.mkdir()
                bundle(source, recovery_candidate, 2, base + "appcast.xml", public, case_store, probe=True, recovery=True)
                run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", recovery_candidate, archive])
                run([tools / "generate_appcast", "--ed-key-file", key_file, "--download-url-prefix", base, "--embed-release-notes", "--maximum-deltas", "0", served])
                recovery_feed = (served / "appcast.xml").read_bytes()
            elif name == "no-update":
                # Restore the normal candidate once after the recovery case.
                archive.write_bytes(good_archive)
            installed = work / name / "msgblast.app"
            installed.parent.mkdir()
            starting_build = 2 if name == "no-update" else 1
            bundle(source, installed, starting_build, base + "appcast.xml", public, case_store, probe=True, recovery=recovery)
            feed = served / "appcast.xml"
            feed.write_bytes(recovery_feed if recovery else good_feed)
            if name in ("invalid-signature", "failed-download"):
                tree = ET.fromstring(good_feed)
                # Remove the original signed-feed comment by serialization, then sign this altered fixture feed.
                enclosure = tree.find("./channel/item/enclosure")
                if name == "invalid-signature":
                    import base64
                    enclosure.set(f"{{{SP}}}edSignature", base64.b64encode(bytes(64)).decode())
                else:
                    enclosure.set("url", base + "missing.zip")
                feed.write_bytes(ET.tostring(tree, encoding="utf-8", xml_declaration=True))
                run([tools / "sign_update", "--ed-key-file", key_file, feed])
            command = [str(installed / "Contents/MacOS/msgblast"), "--update-probe"]
            if name == "install-and-preserve": command.append("--update-probe-busy")
            output_path = installed.parent / "stdout.log"
            error_path = installed.parent / "stderr.log"
            with output_path.open("w") as output, error_path.open("w") as errors:
                process = subprocess.Popen(command, stdout=output, stderr=errors, text=True)
                try: code = process.wait(timeout=70)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()
                    report["cases"].append({"name": name, "passed": False, "error": "Probe timed out", "stdout": output_path.read_text(), "stderr": error_path.read_text()})
                    raise
            result = subprocess.CompletedProcess(command, code, output_path.read_text(), error_path.read_text())
            if name == "install-and-preserve" or recovery:
                deadline = time.monotonic() + 30
                while (version(installed) != expected_build or not (case_store / "relaunch.json").exists()) and time.monotonic() < deadline: time.sleep(0.2)
            actual = version(installed)
            state = json.loads((store / "state.json").read_text())
            preserved = state.get("version") == 1 and state["selection"] == ["11111111-1111-1111-1111-111111111111"] and state["draft"] == "Retained update-fixture draft" and state["attachmentsDraft"][0]["path"] == str(staged) and staged.read_text().startswith("Retain this synthetic")
            if recovery:
                snapshots = list((case_store / "Recovery").glob("*/drafts-state.json"))
                originals = list((case_store / "Recovery").glob("*/original-state.json"))
                preserved = ((case_store / "state.json").read_bytes() == original_bytes
                    and any(json.loads(p.read_text())["draft"] == "New draft after unreadable state" for p in snapshots)
                    and bool(originals) and all(p.read_bytes() == original_bytes for p in originals)
                    and (case_store / "relaunch.json").exists())
                if preserved:
                    relaunched = json.loads((case_store / "relaunch.json").read_text())
                    preserved = relaunched["build"] == expected_build and relaunched["recovery"] is True
            passed = result.returncode == expected_exit and actual == expected_build and preserved
            if name == "install-and-preserve":
                passed = passed and "postponed for submission" in result.stdout and "submission finished" in result.stdout and "ready; install and quit" in result.stdout and (store / "relaunch.json").exists()
                if passed:
                    relaunched = json.loads((store / "relaunch.json").read_text())
                    passed = relaunched["build"] == "2" and relaunched["draft"] == state["draft"]
            case = {"name": name, "passed": passed, "exit_code": result.returncode, "build": actual, "draft_and_attachment_preserved": preserved, "stdout": result.stdout.strip(), "stderr": result.stderr.strip()}
            report["cases"].append(case)
            print(json.dumps(case), flush=True)
            if not passed: raise RuntimeError(f"{name} did not satisfy its update contract")
            run(["codesign", "--verify", "--deep", "--strict", installed])
        report["result"] = "Passed"
    finally:
        if server: server.shutdown(); server.server_close()
        if key_file: key_file.unlink(missing_ok=True)
        (work / "results.json").write_text(json.dumps(report, indent=2) + "\n")
        if args.keep: print(f"Fixture report: {work / 'results.json'}")
        else: shutil.rmtree(work)

if __name__ == "__main__":
    main()
