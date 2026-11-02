"""Background receipt regressions; no live API, credentials or publication."""
import contextlib
import copy
import importlib.util
import io
import json
import unittest
from pathlib import Path
from unittest import mock

PATH = Path(__file__).resolve().parents[1] / "prototype/tools/release_receipt.py"
SPEC = importlib.util.spec_from_file_location("release_receipt", PATH)
receipt = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(receipt)
SHA = "a" * 40
ENV = {"RELEASE_COMMIT": SHA, "RELEASE_RUN_ID": "123", "RELEASE_RUN_ATTEMPT": "1", "GITHUB_TOKEN": "fixture-private-token"}
HASHES = {"DateABrainrot-Prototype.rbxl": "b" * 64, "DateABrainrot-Prototype.rbxlx": "c" * 64}


class ReceiptTests(unittest.TestCase):
    def make(self, status="published"):
        report = {"status": status, "universe_id": receipt.UNIVERSE_ID, "place_id": receipt.PLACE_ID,
                  "version_number": 13, "build_sha256": HASHES, "network_attempts": 1,
                  "error": ENV["GITHUB_TOKEN"], "raw_response": ENV["GITHUB_TOKEN"]}
        return receipt.prepare(report, {"passed": True, "build_sha256": HASHES}, ENV)

    def test_receipt_contains_only_nonsecret_publication_fields(self):
        value = self.make()
        self.assertEqual((value["status"], value["version_number"], value["source_commit"]), ("published", 13, SHA))
        self.assertNotIn(ENV["GITHUB_TOKEN"], json.dumps(value))

    def test_unknown_or_missing_outcome_never_becomes_success(self):
        for status in ("unknown", "rejected", "validation_failed"):
            value = self.make(status)
            self.assertEqual((value["status"], value["version_number"]), (status, None))
        self.assertEqual(receipt.prepare(None, None, ENV)["status"], "unconfirmed")

    def test_success_requires_passed_checks_valid_version_and_matching_hashes(self):
        good = self.make()
        for change in ({"version_number": None}, {"version_number": True}, {"checks_passed": False}, {"build_sha256": {}}):
            value = dict(good, **change)
            with self.assertRaises(ValueError):
                receipt.validate(value, SHA)
        with self.assertRaises(ValueError):
            receipt.prepare(good, {"passed": True, "build_sha256": {}}, ENV)

    def test_wrong_game_or_commit_is_rejected(self):
        for change in ({"place_id": 1}, {"universe_id": 1}, {"source_commit": "d" * 40}):
            with self.assertRaises(ValueError):
                receipt.validate(dict(self.make(), **change), SHA)

    def test_record_only_creates_one_tag_and_ref_without_forwarding_extra_fields(self):
        value = dict(self.make(), unexpected=ENV["GITHUB_TOKEN"])
        calls = []
        def post(path, data, token):
            calls.append((path, data))
            self.assertEqual(token, ENV["GITHUB_TOKEN"])
            self.assertNotIn(token, json.dumps(data))
            return {"sha": "d" * 40}
        name = receipt.record(value, ENV, post)
        self.assertEqual([row[0] for row in calls], ["tags", "refs"])
        self.assertEqual(calls[0][1]["object"], SHA)
        self.assertEqual(calls[1][1], {"ref": f"refs/tags/{name}", "sha": "d" * 40})

    def test_tag_reader_binds_the_message_to_commit_and_reference(self):
        value = self.make()
        ref = "refs/tags/" + receipt.tag_name(value)
        raw = f"object {SHA}\ntype commit\ntag {receipt.tag_name(value)}\n\n" + json.dumps(value)
        self.assertEqual(receipt.decode_tag(raw, ref, SHA)["version_number"], 13)
        for changed_raw, changed_ref in ((raw.replace(f"object {SHA}", "object " + "d" * 40), ref), (raw, ref + "0")):
            with self.assertRaises(ValueError):
                receipt.decode_tag(changed_raw, changed_ref, SHA)

    def test_reader_pending_is_read_only_and_does_not_republish(self):
        with mock.patch.object(receipt, "git", return_value="") as git, mock.patch.object(receipt, "api_post", side_effect=AssertionError("No API write")):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                code = receipt.read(SHA)
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(output.getvalue())["status"], "no_receipt_yet")
        self.assertEqual(git.call_args.args[0][0], "ls-remote")

    def test_invalid_ref_identity_is_never_sent_to_github(self):
        for bad in ("a\njson=injected", "x" * 40, "../../main"):
            with self.assertRaises(ValueError):
                receipt.identity(dict(ENV, RELEASE_COMMIT=bad))

    def test_latest_selects_numeric_run_and_attempt_across_commits(self):
        older, newer = "d" * 40, "e" * 40
        rows = "\n".join([
            f"{'1' * 40} refs/tags/{receipt.PREFIX}/{SHA}/99-1",
            f"{'2' * 40} refs/tags/{receipt.PREFIX}/{older}/100-1",
            f"{'3' * 40} refs/tags/{receipt.PREFIX}/{newer}/100-2",
        ])
        with mock.patch.object(receipt, "git", return_value=rows), mock.patch.object(receipt, "read", return_value=0) as reader:
            self.assertEqual(receipt.read_latest(), 0)
        reader.assert_called_once_with(newer, output=None)

    def test_latest_failure_is_reported_instead_of_older_success(self):
        value = self.make("unknown")
        ref = "refs/tags/" + receipt.tag_name(value)
        rows = f"{'1' * 40} refs/tags/{receipt.PREFIX}/{'d' * 40}/122-1\n{'2' * 40} {ref}"
        raw = f"object {SHA}\ntype commit\ntag {receipt.tag_name(value)}\n\n" + json.dumps(value)
        with mock.patch.object(receipt, "git", side_effect=[rows, f"{'2' * 40} {ref}", "", "", raw]) as git, \
             mock.patch.object(receipt, "api_post", side_effect=AssertionError("No API writes")), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            code = receipt.read_latest()
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(output.getvalue())["status"], "unknown")
        self.assertEqual([call.args[0][0] for call in git.call_args_list], ["ls-remote", "ls-remote", "init", "fetch", "cat-file"])

    def test_latest_missing_or_malformed_listing_never_reports_success(self):
        with mock.patch.object(receipt, "git", return_value=""), \
             mock.patch.object(receipt, "api_post", side_effect=AssertionError("No API writes")), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(receipt.read_latest(), 2)
        self.assertEqual(json.loads(output.getvalue())["status"], "no_receipt_yet")
        for bad in ("not a ref", f"{'1' * 40} refs/tags/{receipt.PREFIX}/invalid", f"not-a-sha refs/tags/{receipt.PREFIX}/{SHA}/123-1"):
            with self.subTest(bad=bad), mock.patch.object(receipt, "git", return_value=bad), mock.patch.object(receipt, "read") as reader:
                with self.assertRaises(ValueError):
                    receipt.read_latest()
                reader.assert_not_called()


if __name__ == "__main__":
    unittest.main()
