"""Release guard regressions. All HTTP calls are mocked; no Roblox request runs."""

import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "prototype/tools/publish_closed_test.py"
SPEC = importlib.util.spec_from_file_location("publish_closed_test", SCRIPT)
publish = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(publish)
FAKE_KEY = "fixture-private-token"


class PublishGuardTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="brainrot-publish-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "source"
        self.build = Path(self.temporary.name) / "checked"
        self.build.mkdir()
        for name in ("src/Example.luau", "tests/compile.luau", "tests/test_example.py", "prototype/tools/check_background.py",
                     "rokit.toml", "default.project.json", "assets/BrainrotCollection.rbxmx"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("checked input\n")
        hashes = {}
        for extension in ("rbxl", "rbxlx"):
            name = f"DateABrainrot-Prototype.{extension}"
            data = f"checked {extension} fixture".encode()
            (self.build / name).write_bytes(data)
            hashes[name] = publish.digest(data)
        self.checks = {
            "passed": True, "input_sha256": publish.current_inputs(self.root), "build_sha256": hashes,
            "steps": [{"name": name, "exit_code": 0} for name in ("compile", "python-tests", "build-rbxl", "build-rbxlx")],
        }
        self.write_checks()
        self.addCleanup(mock.patch.stopall)
        mock.patch.object(publish, "ROOT", self.root).start()

    def write_checks(self):
        (self.build / "check-run.json").write_text(json.dumps(self.checks))

    def invoke(self, *arguments):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            code = publish.main(["--checked-build", str(self.build), *arguments])
        reports = list(self.build.glob("closed-test-publish-*.json"))
        report = json.loads(reports[-1].read_text()) if reports else None
        self.assertNotIn(FAKE_KEY, stdout.getvalue() + stderr.getvalue() + json.dumps(report))
        return code, report

    def test_dry_run_validates_without_reading_a_key_or_opening_http(self):
        with mock.patch.object(publish, "read_key", side_effect=AssertionError("key should not be read")), \
             mock.patch.object(publish.urllib.request, "build_opener", side_effect=AssertionError("HTTP should not open")):
            code, report = self.invoke("--api-key-file", str(self.root / "does-not-exist"))
        self.assertEqual((code, report["status"], report["network_attempts"]), (0, "ready", 0))
        self.assertEqual((report["universe_id"], report["place_id"]), (10770822773, 114564825581977))

    def test_stale_source_is_rejected_before_credentials_or_http(self):
        (self.root / "src/Example.luau").write_text("changed input\n")
        with mock.patch.object(publish, "read_key", side_effect=AssertionError("must fail before credentials")):
            code, report = self.invoke("--publish")
        self.assertEqual((code, report["status"], report["network_attempts"]), (1, "validation_failed", 0))

    def test_added_test_and_changed_tool_invalidate_checked_inputs(self):
        for name in ("tests/new_regression.luau", "prototype/tools/check_background.py"):
            with self.subTest(name=name):
                path = self.root / name
                previous = path.read_bytes() if path.exists() else None
                path.write_text("new input\n")
                with self.assertRaises(publish.ValidationError):
                    publish.validate_checked_build(self.build)
                if previous is None:
                    path.unlink()
                else:
                    path.write_bytes(previous)

    def test_changed_binary_or_xml_is_rejected(self):
        for extension in ("rbxl", "rbxlx"):
            with self.subTest(extension=extension):
                path = self.build / f"DateABrainrot-Prototype.{extension}"
                previous = path.read_bytes()
                path.write_bytes(previous + b"changed")
                with self.assertRaises(publish.ValidationError):
                    publish.validate_checked_build(self.build)
                path.write_bytes(previous)

    def test_failed_or_incomplete_check_report_is_rejected(self):
        for change in ("passed", "python-tests"):
            with self.subTest(change=change):
                previous = json.loads(json.dumps(self.checks))
                if change == "passed":
                    self.checks["passed"] = False
                else:
                    self.checks["steps"] = [step for step in self.checks["steps"] if step["name"] != change]
                self.write_checks()
                with self.assertRaises(publish.ValidationError):
                    publish.validate_checked_build(self.build)
                self.checks = previous
                self.write_checks()

    def test_publication_uses_one_fixed_endpoint_and_reports_only_version(self):
        response = mock.MagicMock()
        response.__enter__.return_value = response
        response.status = 200
        response.read.return_value = json.dumps({"versionNumber": 17, "ignoredEcho": FAKE_KEY}).encode()
        opener = mock.Mock()
        opener.open.return_value = response
        with mock.patch.dict(os.environ, {"ROBLOX_API_KEY": FAKE_KEY}), \
             mock.patch.object(publish.urllib.request, "build_opener", return_value=opener):
            code, report = self.invoke("--publish")
        self.assertEqual((code, report["status"], report["version_number"], report["network_attempts"]), (0, "published", 17, 1))
        self.assertEqual(opener.open.call_count, 1)
        request = opener.open.call_args.args[0]
        self.assertEqual(request.full_url, "https://apis.roblox.com/universes/v1/10770822773/places/114564825581977/versions?versionType=Published")
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(request.data, (self.build / publish.BUILD_NAME).read_bytes())
        self.assertEqual(request.get_header("X-api-key"), FAKE_KEY)

    def test_network_error_is_unknown_and_never_retried_or_echoed(self):
        opener = mock.Mock()
        opener.open.side_effect = urllib.error.URLError("response echoed " + FAKE_KEY)
        with mock.patch.dict(os.environ, {"ROBLOX_API_KEY": FAKE_KEY}), \
             mock.patch.object(publish.urllib.request, "build_opener", return_value=opener):
            code, report = self.invoke("--publish")
        self.assertEqual((code, report["status"], report["network_attempts"]), (1, "unknown", 1))
        self.assertEqual(opener.open.call_count, 1)

    def test_invalid_success_response_is_unknown_not_a_success(self):
        response = mock.MagicMock()
        response.__enter__.return_value = response
        response.status = 200
        response.read.return_value = b'{"versionNumber":true}'
        opener = mock.Mock()
        opener.open.return_value = response
        with mock.patch.object(publish.urllib.request, "build_opener", return_value=opener):
            result = publish.publish_once(b"fixture", FAKE_KEY)
        self.assertEqual(result["status"], "unknown")
        self.assertEqual(opener.open.call_count, 1)

    def test_http_errors_are_not_retried_or_echoed(self):
        for status, expected in ((403, "rejected"), (500, "unknown"), (302, "unknown")):
            with self.subTest(status=status):
                opener = mock.Mock()
                opener.open.side_effect = urllib.error.HTTPError(publish.ENDPOINT, status, FAKE_KEY, {}, io.BytesIO(FAKE_KEY.encode()))
                with mock.patch.object(publish.urllib.request, "build_opener", return_value=opener):
                    result = publish.publish_once(b"fixture", FAKE_KEY)
                self.assertEqual(result["status"], expected)
                self.assertNotIn(FAKE_KEY, json.dumps(result))
                self.assertEqual(opener.open.call_count, 1)

    def test_redirects_are_not_followed_with_the_key(self):
        self.assertIsNone(publish.NoRedirect().redirect_request(None, None, 302, "redirect", {}, "https://elsewhere.invalid"))

    def test_lost_final_report_keeps_unknown_outcome_without_retry(self):
        original = publish.write_report
        def write_until_response(path, report):
            if report["status"] == "published":
                raise OSError("simulated disk failure")
            original(path, report)
        with mock.patch.dict(os.environ, {"ROBLOX_API_KEY": FAKE_KEY}), \
             mock.patch.object(publish, "write_report", side_effect=write_until_response), \
             mock.patch.object(publish, "publish_once", return_value={"status": "published", "version_number": 17}) as attempt:
            code, report = self.invoke("--publish")
        self.assertEqual((code, report["status"], report["network_attempts"]), (1, "unknown", 1))
        self.assertEqual(attempt.call_count, 1)

    def test_existing_report_is_not_overwritten_and_no_request_starts(self):
        report = self.build / "existing.json"
        report.write_text('{"status":"unknown"}')
        with mock.patch.object(publish.urllib.request, "build_opener", side_effect=AssertionError("HTTP should not open")):
            code, _ = self.invoke("--publish", "--report", str(report))
        self.assertEqual(code, 1)
        self.assertEqual(report.read_text(), '{"status":"unknown"}')


if __name__ == "__main__":
    unittest.main()
