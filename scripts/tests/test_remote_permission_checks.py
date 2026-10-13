"""Permission results must belong to each native row, never a nearby Allowed label."""
import importlib.util
from pathlib import Path
import unittest
from unittest import mock
import subprocess
import sys
import tempfile
import json
import os
import io
import contextlib

path = Path(__file__).resolve().parents[1] / "remote_permission_checks.py"
spec = importlib.util.spec_from_file_location("remote_permission_checks", path)
remote = importlib.util.module_from_spec(spec)
spec.loader.exec_module(remote)


class PermissionReceiptTests(unittest.TestCase):
    def test_public_proof_excludes_machine_details_and_unexpected_fields(self):
        private = {"space": "private-test-space", "screenshot": "/Users/private-user/capture.png",
                   "host_name": "private-test-host", "unexpected": "private-value",
                   "metadata": {"bundle_id": "com.msgblast.development", "team_id": "TESTTEAM01",
                                "designated_requirement": "test requirement", "code_hash": "a" * 40,
                                "source_revision": "private-source-reference", "app_path": "/Users/private-user/App.app"},
                   "permissions": {"Messages access": "Allowed", "Contacts": "Allowed", "Sending Messages": "Allowed", "unexpected": "private-value"},
                   "contacts_api_search": "empty success", "contacts_surface": "Discover", "rebuild_retention": True,
                   "limits": "private details must not be copied"}
        exported = remote.public_receipt(private)
        text = json.dumps(exported)
        self.assertNotIn("private-", text)
        self.assertNotIn("/Users/", text)
        self.assertNotIn("source_revision", text)
        self.assertEqual(exported["permissions"], {"Messages access": "Allowed", "Contacts": "Allowed", "Sending Messages": "Allowed"})
        self.assertTrue(exported["rebuild_retention"])

    def test_private_config_requires_explicit_target_and_owner_only_permissions(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "config.json"
            data = {"space": "test-space", "host_name": "test-host", "team_id": "TESTTEAM01", "source_sha": "a" * 40}
            path.write_text(json.dumps(data)); path.chmod(0o600)
            self.assertEqual(remote.load_private_config(path), data)
            path.chmod(0o644)
            with self.assertRaisesRegex(RuntimeError, "owner-only"):
                remote.load_private_config(path)
            path.chmod(0o600); del data["host_name"]; path.write_text(json.dumps(data))
            with self.assertRaisesRegex(RuntimeError, "requires"):
                remote.load_private_config(path)

    def test_private_receipt_cannot_be_written_inside_source_and_is_owner_only(self):
        with self.assertRaisesRegex(RuntimeError, "outside the source checkout"):
            remote.write_private_json(remote.SOURCE_ROOT / "private-receipt.json", {})
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "receipt.json"
            path.write_text("old"); path.chmod(0o644)
            remote.write_private_json(path, {"private": "test data"})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(path.read_text()), {"private": "test data"})

    def test_failure_detail_is_saved_privately_and_not_printed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            config = root / "permission-testing.json"
            config.write_text(json.dumps({"space": "private-space", "host_name": "private-host", "team_id": "TESTTEAM01", "source_sha": "a" * 40})); config.chmod(0o600)
            output = io.StringIO()
            with mock.patch.object(remote, "CONFIG_ROOT", root), mock.patch.object(sys, "argv", ["check", "--config", str(config)]), mock.patch.object(remote, "run", side_effect=RuntimeError("private-host /Users/private-user")), contextlib.redirect_stdout(output):
                with self.assertRaises(SystemExit) as raised:
                    remote.main()
            self.assertNotIn("private-host", str(raised.exception))
            self.assertEqual(output.getvalue(), "")
            error = root / "permission-receipts/last-error.json"
            self.assertEqual(error.stat().st_mode & 0o777, 0o600)
            self.assertIn("private-host", error.read_text())

    def test_stalled_cua_peer_times_out_and_is_collected(self):
        peer = subprocess.Popen([sys.executable, "-u", "-c", "import sys,time; sys.stdin.readline(); time.sleep(5)"],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        with mock.patch.object(remote.subprocess, "Popen", return_value=peer), mock.patch.object(remote, "RPC_TIMEOUT", 0.05):
            with self.assertRaisesRegex(RuntimeError, "timed out"):
                remote.SpaceClient("test")
        self.assertIsNotNone(peer.poll())
        self.assertTrue(peer.stdin.closed)
        self.assertTrue(peer.stdout.closed)

    def test_old_empty_result_cannot_pass_and_failed_probe_restores_query(self):
        client = DiscoverFixture(complete_new_search=False)
        with mock.patch.object(remote.time, "sleep"):
            with self.assertRaisesRegex(RuntimeError, "fresh expected result"):
                remote.probe_contacts(client, 1, 2)
        self.assertEqual(client.query, "original unmatched query")

    def test_fresh_result_passes_and_restores_query(self):
        client = DiscoverFixture(complete_new_search=True)
        with mock.patch.object(remote.time, "sleep"):
            remote.probe_contacts(client, 1, 2)
        self.assertEqual(client.query, "original unmatched query")
    def test_rebuild_must_change_code_without_changing_identity(self):
        previous = {"designated_requirement": 'identifier "com.msgblast.development" and anchor apple generic', "code_hash": "a" * 40}
        current = dict(previous, code_hash="b" * 40)
        remote.verify_rebuild(previous, current)
        with self.assertRaisesRegex(RuntimeError, "different code hashes"):
            remote.verify_rebuild(previous, dict(previous))
        with self.assertRaisesRegex(RuntimeError, "trusted application identity"):
            remote.verify_rebuild(previous, dict(current, designated_requirement='cdhash H"1234"'))

    def test_placeholder_is_empty_but_actual_discover_text_is_preserved(self):
        state = {"elements": [{"role": "AXTextField", "label": "Search Discover", "value": "Search agents, contacts, phone or email"}]}
        self.assertEqual(remote.contact_query(state), "")
        state["elements"].append({"role": "AXButton", "label": "Clear Discover search"})
        self.assertEqual(remote.contact_query(state), "Search agents, contacts, phone or email")
        state = {"elements": [{"role": "AXTextField", "label": "Find onboarding contact", "value": "Search contacts, phone or email"}]}
        self.assertEqual(remote.contact_query(state), "")

    def test_onboarding_missing_grant_cannot_click_permission_or_continue(self):
        class MissingGrant:
            def __init__(self): self.actions = []
            def snapshot(self, *args):
                return {"tree_markdown": 'AXStaticText = "Current step"', "elements": [
                    {"role": "AXButton", "label": "Messages access", "value": "Complete"},
                    {"role": "AXButton", "label": "Contacts", "value": "Incomplete"},
                    {"role": "AXButton", "label": "Sending Messages", "value": "Complete"}]}
            def driver(self, name, **args): self.actions.append((name, args))
        client = MissingGrant()
        with mock.patch.object(remote.time, "sleep"):
            with self.assertRaisesRegex(RuntimeError, "checklist is not complete"):
                remote.open_contact_surface(client, 1, 2)
        self.assertEqual([name for name, _ in client.actions], ["invoke_menu"])

    def test_denied_contacts_cannot_borrow_allowed_status_from_messages(self):
        tree = '''- AXStaticText = "Messages access, Find the agents you already text."
  - AXStaticText = "Allowed"
  - AXButton (Manage)
  - AXStaticText = "Contacts, Match your agents’ names and photos."
  - AXStaticText = "Off"
  - AXButton (Open Settings)
  - AXStaticText = "Sending Messages, Send messages to your agents."
  - AXStaticText = "Allowed"
'''
        self.assertEqual(remote.permission_states(tree), {"Messages access": "Allowed", "Contacts": "Off", "Sending Messages": "Allowed"})
        with self.assertRaisesRegex(RuntimeError, "Contacts"):
            remote.permission_states(tree.replace('AXStaticText = "Contacts,', 'AXStaticText = "Other,'))


class DiscoverFixture:
    """Simulated UI: clearing is delayed, and the new API response may never arrive."""
    def __init__(self, complete_new_search):
        self.query = "original unmatched query"
        self.result = remote.EMPTY_CONTACT_RESULT
        self.clear_wait = 0
        self.complete_new_search = complete_new_search

    def snapshot(self, pid, window):
        if not self.query and self.clear_wait:
            self.clear_wait -= 1
            if not self.clear_wait:
                self.result = ""
        return {"tree_markdown": self.result, "elements": [{"role": "AXTextField", "label": "Search Discover",
                                                            "value": self.query, "element_token": "s00000001:1"}]}

    def driver(self, name, **arguments):
        if name == "set_value":
            self.query = arguments["value"]
            if not self.query:
                self.clear_wait = 3
            elif self.query.startswith("msgblastpermissionprobe") and self.complete_new_search:
                self.result = remote.EMPTY_CONTACT_RESULT
