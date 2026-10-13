#!/usr/bin/env python3
"""Check real Dev permissions through Cua in a privately configured isolated Space.

Never grants/resets permissions, sends Messages, writes Contacts, or uses a local
desktop fallback. A missing grant is a failed integration check, not a fixture.
"""
import argparse
import json
import os
from pathlib import Path
import re
import select
import shlex
import subprocess
import time
import uuid

RPC_TIMEOUT = 60
EMPTY_CONTACT_RESULT = "No matching contact. Try a name, email, or full phone number."


CONFIG_ROOT = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "msgblast"
SOURCE_ROOT = Path(__file__).resolve().parents[1]


def private_path(path):
    path = path.expanduser().resolve()
    if path.is_relative_to(SOURCE_ROOT):
        raise RuntimeError("Private configuration and receipts must be outside the source checkout")
    return path


def load_private_config(path):
    path = private_path(path)
    if path.stat().st_mode & 0o077:
        raise RuntimeError("Private configuration must have owner-only permissions (chmod 600)")
    data = json.loads(path.read_text())
    for key in ("space", "host_name", "team_id", "source_sha"):
        if not isinstance(data.get(key), str) or not data[key].strip():
            raise RuntimeError("Private configuration requires space, host_name, team_id, and source_sha")
    return data


def write_private_json(path, data):
    path = private_path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags, 0o600)
    with os.fdopen(descriptor, "w") as file:
        os.fchmod(file.fileno(), 0o600)
        json.dump(data, file, indent=2)
        file.write("\n")


def public_receipt(receipt):
    """Allowlist public proof; never copy host IDs, source refs, paths, or free text."""
    metadata = receipt["metadata"]
    return {"schema": "public-permission-proof-v1", "source_verified": True,
            "metadata": {key: metadata[key] for key in
                         ("bundle_id", "team_id", "designated_requirement", "code_hash")},
            "permissions": {key: receipt["permissions"][key] for key in
                            ("Messages access", "Contacts", "Sending Messages")},
            "contacts_api_search": receipt["contacts_api_search"],
            "contacts_surface": receipt["contacts_surface"],
            "rebuild_retention": receipt["rebuild_retention"],
            "limits": "Read-only permission checks; no sends, Contacts writes, account login, or clean-machine prompt coverage"}


class SpaceClient:
    def __init__(self, space):
        self.space = space
        self.sequence = 0
        self.pending = b""
        self.process = subprocess.Popen(["cua", "mcp"], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE)
        try:
            self.rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                                   "clientInfo": {"name": "msgblast-permission-check", "version": "1"}})
        except Exception:
            self.close()
            raise

    def rpc(self, method, parameters):
        self.sequence += 1
        self.process.stdin.write((json.dumps({"jsonrpc": "2.0", "id": self.sequence,
                                             "method": method, "params": parameters}) + "\n").encode())
        self.process.stdin.flush()
        deadline = time.monotonic() + RPC_TIMEOUT
        while True:
            if b"\n" not in self.pending:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not select.select([self.process.stdout], [], [], remaining)[0]:
                    raise RuntimeError("Cua request timed out: " + method)
                chunk = os.read(self.process.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError("Cua connection closed")
                self.pending += chunk
                continue
            line, self.pending = self.pending.split(b"\n", 1)
            response = json.loads(line)
            if response.get("id") == self.sequence:
                if "error" in response:
                    raise RuntimeError(response["error"])
                return response["result"]

    def tool(self, name, arguments):
        result = self.rpc("tools/call", {"name": name, "arguments": arguments})
        if result.get("isError"):
            raise RuntimeError(result.get("structuredContent") or "Cua rejected " + name)
        if "structuredContent" in result:
            return result["structuredContent"]
        text = "\n".join(block.get("text", "") for block in result.get("content", []) if block["type"] == "text")
        try:
            return json.loads(text)
        except ValueError:
            return text

    def bash_json(self, program):
        result = self.tool("space_bash", {"space": self.space, "command": "python3 -c " + shlex.quote(program), "timeout": 30})
        if not isinstance(result, str) or not result.rstrip().endswith("[exit 0]"):
            raise RuntimeError("Remote preflight failed: " + str(result))
        return json.JSONDecoder().raw_decode(result)[0]

    def driver(self, name, **arguments):
        if name != "list_windows":
            arguments["session"] = "msgblast-permission-check"
        return self.tool("call_tool", {"space": self.space, "tool": name, "arguments": arguments})

    def window(self, pid, title=None):
        for _ in range(20):
            candidates = [w for w in self.driver("list_windows")["windows"]
                          if w["pid"] == pid and (w["title"] in ("", "msgblast Dev") and w["bounds"]["width"] >= 740
                                                  if title is None else w["title"] == title)]
            if len(candidates) == 1:
                return candidates[0]["window_id"]
            time.sleep(0.25)
        raise RuntimeError("Remote window is missing or ambiguous")

    def snapshot(self, pid, window, **options):
        options.setdefault("include_screenshot", False)
        return self.driver("get_window_state", pid=pid, window_id=window, **options)

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        finally:
            self.process.stdin.close()
            self.process.stdout.close()


def permission_states(markdown):
    states = {}
    for label in ("Messages access", "Contacts", "Sending Messages"):
        match = re.search(r'AXStaticText = "' + re.escape(label) + r',[^"\n]*"\s*- AXStaticText = "([^"\n]+)"', markdown)
        if not match:
            raise RuntimeError("Permission row is missing: " + label)
        states[label] = match[1]
    return states


def verify_rebuild(previous, metadata):
    if previous["designated_requirement"] != metadata["designated_requirement"]:
        raise RuntimeError("Rebuild changed the trusted application identity")
    if previous["code_hash"] == metadata["code_hash"]:
        raise RuntimeError("Rebuild retention requires two apps with different code hashes")


def contact_field(state):
    fields = [e for e in state["elements"] if e.get("role") == "AXTextField" and e.get("label") in ("Search Discover", "Find onboarding contact")]
    if len(fields) != 1:
        raise RuntimeError("Native Contacts search field is missing or ambiguous")
    return fields[0]


def contact_query(state):
    field = contact_field(state)
    value = field.get("value", "")
    # SwiftUI exposes its placeholder as AXValue when the field is empty.
    placeholder = {"Search Discover": "Search agents, contacts, phone or email",
                   "Find onboarding contact": "Search contacts, phone or email"}[field["label"]]
    if value == placeholder:
        if field["label"] == "Find onboarding contact" or not any(
                e.get("label") == "Clear Discover search" for e in state["elements"]):
            return ""
    return value


def click_button(client, pid, window, label):
    for _ in range(20):
        state = client.snapshot(pid, window)
        buttons = [e for e in state["elements"] if e.get("role") == "AXButton"
                   and e.get("label") == label and e.get("enabled", True)]
        if len(buttons) == 1:
            client.driver("click", pid=pid, window_id=window, element_token=buttons[0]["element_token"])
            return
        time.sleep(0.25)
    raise RuntimeError("Native button is missing or ambiguous: " + label)


def open_contact_surface(client, pid, window):
    state = client.snapshot(pid, window)
    if 'AXStaticText = "Current step"' not in state["tree_markdown"]:
        client.driver("invoke_menu", pid=pid, window_id=window, path=["View", "Show Discover"])
        return "Discover"
    # A permission-only VM has no agent accounts to finish onboarding with.
    client.driver("invoke_menu", pid=pid, window_id=window, path=["File", "Review Messages Setup…"])
    for _ in range(20):
        state = client.snapshot(pid, window)
        complete = {e.get("label") for e in state["elements"] if e.get("role") == "AXButton" and e.get("value") == "Complete"}
        if {"Messages access", "Contacts", "Sending Messages"}.issubset(complete):
            break
        time.sleep(0.25)
    else:
        raise RuntimeError("Onboarding permission checklist is not complete")
    click_button(client, pid, window, "Continue setup")
    click_button(client, pid, window, "Search for more agents in Messages")
    return "onboarding contact picker"


def set_contact_query(client, pid, window, query):
    field = contact_field(client.snapshot(pid, window))
    client.driver("set_value", pid=pid, window_id=window, element_token=field["element_token"], value=query)


def wait_for_contact_result(client, pid, window, query, empty_result):
    for _ in range(20):
        state = client.snapshot(pid, window)
        if contact_query(state) == query and (EMPTY_CONTACT_RESULT in state["tree_markdown"]) == empty_result:
            return
        time.sleep(0.5)
    raise RuntimeError("Native Contacts search did not return a fresh expected result")


def probe_contacts(client, pid, window):
    original_query = contact_query(client.snapshot(pid, window))
    query = "msgblastpermissionprobe" + "".join(chr(ord("a") + int(c, 16)) for c in uuid.uuid4().hex)
    try:
        # Clear and observe the old result before starting a distinct lookup.
        set_contact_query(client, pid, window, "")
        wait_for_contact_result(client, pid, window, "", False)
        set_contact_query(client, pid, window, query)
        wait_for_contact_result(client, pid, window, query, True)
    finally:
        if contact_query(client.snapshot(pid, window)) != original_query:
            set_contact_query(client, pid, window, original_query)
        if contact_query(client.snapshot(pid, window)) != original_query:
            raise RuntimeError("Contacts query restoration could not be verified")


def run(options):
    client = SpaceClient(options.space)
    try:
        spaces = client.tool("list_spaces", {})
        target = next((s for s in spaces if s["id"] == options.space), {})
        if target.get("host_name") != options.host_name or not target.get("host"):
            raise RuntimeError("Choose an isolated Space on the privately configured host, never the host desktop")
        metadata = client.bash_json('''import json, os, plistlib, subprocess
from pathlib import Path
app = Path.home() / 'Applications/msgblast Dev.app'
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.msgblast.development'
assert info.get('msgblastDemo') is False
assert info['msgblastSupportDirectory'] == 'msgblast-Dev'
assert not info.get('SUFeedURL') and not info.get('SUEnableAutomaticChecks')
assert info['msgblastSourceRevision'] == ''' + repr(options.source_sha) + '''
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
signature = subprocess.run(['codesign', '-dv', '--verbose=4', str(app)], capture_output=True, text=True, check=True).stderr
assert 'TeamIdentifier=' + ''' + repr(options.team_id) + ''' in signature, 'Dev must be signed by the trusted Apple team'
assert 'Authority=Developer ID Application:' in signature and '(runtime)' in signature, 'Dev requires Developer ID signing and hardened runtime'
requirement_report = subprocess.run(['codesign', '-dr', '-', str(app)], capture_output=True, text=True, check=True)
requirement = (requirement_report.stderr + '\\n' + requirement_report.stdout).split('designated =>', 1)[1].strip()
assert 'anchor apple generic' in requirement and 'cdhash' not in requirement
code_hash = next(line.split('=', 1)[1] for line in signature.splitlines() if line.startswith('CDHash='))
print(json.dumps({'source_revision': info['msgblastSourceRevision'], 'bundle_id': info['CFBundleIdentifier'], 'team_id': ''' + repr(options.team_id) + ''', 'designated_requirement': requirement, 'code_hash': code_hash, 'app_path': str(app)}))
''')
        if options.previous_receipt:
            previous = json.loads(options.previous_receipt.read_text())
            verify_rebuild(previous["metadata"], metadata)
        # Launching Messages lets the app check Automation without requesting consent.
        client.driver("launch_app", bundle_id="com.apple.MobileSMS")
        launched = client.driver("launch_app", bundle_id="com.msgblast.development")
        pid = launched["pid"]
        client.bash_json('''import json, subprocess
from pathlib import Path
expected = str(Path.home() / 'Applications/msgblast Dev.app/Contents/MacOS/msgblast')
actual = subprocess.check_output(['ps', '-p', ''' + repr(str(pid)) + ''', '-o', 'comm='], text=True).strip()
assert actual == expected, 'Launch Services opened a different Dev app'
processes = subprocess.check_output(['ps', '-axo', 'comm='], text=True).splitlines()
assert sum('/msgblast Dev.app/Contents/MacOS/msgblast' in p for p in processes) == 1, 'Duplicate Dev apps are running'
print(json.dumps({'exact_running_app': True}))
''')
        main = client.window(pid)
        client.snapshot(pid, main)
        client.driver("invoke_menu", pid=pid, window_id=main, path=["File", "Refresh Messages"])
        client.snapshot(pid, main)
        client.driver("invoke_menu", pid=pid, window_id=main, path=["msgblast Dev", "Settings…"])
        settings = client.window(pid, "msgblast Dev Settings")
        states = {}
        for _ in range(10):
            state = client.snapshot(pid, settings)
            states = permission_states(state["tree_markdown"])
            if all(value == "Allowed" for value in states.values()):
                break
            time.sleep(0.5)
        if any(value != "Allowed" for value in states.values()):
            raise RuntimeError("Real permissions are not provisioned: " + json.dumps(states))
        screenshot = "~/Downloads/msgblast-permissions-" + uuid.uuid4().hex + ".png"
        client.snapshot(pid, settings, include_screenshot=True, max_image_dimension=0, screenshot_out_file=screenshot)
        client.driver("press_key", pid=pid, window_id=settings, key="w", modifiers=["cmd"], delivery_mode="foreground")
        client.snapshot(pid, main)
        surface = open_contact_surface(client, pid, main)
        try:
            probe_contacts(client, pid, main)
        finally:
            if surface == "onboarding contact picker":
                click_button(client, pid, main, "Cancel")
        receipt = {"space": options.space, "metadata": metadata, "permissions": states,
                   "contacts_api_search": "empty success", "contacts_surface": surface, "rebuild_retention": bool(options.previous_receipt),
                   "screenshot": screenshot, "limits": "No sends, Contacts writes, or account login; permission-only onboarding is not completed; no clean-machine prompt coverage"}
        write_private_json(options.output, receipt)
        summary = public_receipt(receipt)
        if options.public_output:
            options.public_output.write_text(json.dumps(summary, indent=2) + "\n")
        print(json.dumps(summary, indent=2))
    finally:
        client.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=CONFIG_ROOT / "permission-testing.json")
    parser.add_argument("--source-sha", help="Override the reviewed app source recorded in private configuration")
    parser.add_argument("--previous-receipt", type=Path)
    parser.add_argument("--output", type=Path, default=CONFIG_ROOT / "permission-receipts/latest.json")
    parser.add_argument("--public-output", type=Path, help="Explicitly export an allowlisted shareable proof")
    options = parser.parse_args()
    try:
        config = load_private_config(options.config)
        options.space = config["space"]
        options.host_name = config["host_name"]
        options.team_id = config["team_id"]
        options.source_sha = options.source_sha or config["source_sha"]
        options.output = private_path(options.output)
        if options.previous_receipt:
            options.previous_receipt = private_path(options.previous_receipt)
        if not re.fullmatch(r"[0-9a-f]{40}", options.source_sha):
            raise RuntimeError("Use the full reviewed source SHA")
        if not re.fullmatch(r"[A-Z0-9]{10}", options.team_id):
            raise RuntimeError("Use the trusted ten-character Apple team ID")
        if options.public_output and options.public_output.expanduser().resolve() == options.output:
            raise RuntimeError("Public proof and private receipt need separate output files")
        run(options)
    except Exception as error:
        diagnostic = CONFIG_ROOT / "permission-receipts/last-error.json"
        try:
            write_private_json(diagnostic, {"error_type": type(error).__name__, "error": str(error)})
        except Exception:
            raise SystemExit("Permission check failed; the private diagnostic could not be saved") from None
        raise SystemExit("Permission check failed; details are saved in the private diagnostic file") from None



if __name__ == "__main__":
    main()
