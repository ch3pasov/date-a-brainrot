"""Packaging must not turn baseline screenshots or dry runs into current QA."""

import contextlib
import io
import json
import sys
import tempfile
import unittest
import xml.etree.ElementTree as E
import zipfile
from pathlib import Path
from unittest import mock

TOOLS = Path(__file__).resolve().parents[1] / "prototype/tools"
sys.path.insert(0, str(TOOLS))
try:
    import package_prototype as package
    import publish_closed_test as publisher
finally:
    sys.path.remove(str(TOOLS))


class EvidenceBindingTests(unittest.TestCase):
    def publication(self, status="published", version=4, binary="a" * 64):
        return package.normalize_publication({
            "universe_id": package.UNIVERSE_ID, "place_id": package.PLACE_ID,
            "status": status, "version_number": version, "build_sha256": {package.BUILD_NAME: binary},
        }, "publication.json")

    def runtime(self, version=4):
        return {
            "schema_version": 1, "kind": "web_play", "evidence_path": "web-play-proof.json",
            "universe_id": package.UNIVERSE_ID, "place_id": package.PLACE_ID,
            "runtime_place_version": version, "expected_published_version": 4,
            "checks": [{"id": "swipe", "status": "passed"}, {"id": "rejoin_persistence", "status": "passed"}],
        }

    def test_same_version_and_exact_hash_bind_runtime_to_current_build(self):
        status = package.evidence_status([self.publication()], [self.runtime()], "a" * 64)
        self.assertTrue(status["current_build_published"])
        self.assertTrue(status["current_build_runtime_identity_verified"])
        self.assertTrue(status["current_build_runtime_verified"])
        self.assertTrue(status["current_build_rejoin_persistence_verified"])
        self.assertEqual(status["web_play"][0]["publication_evidence"], "publication.json")

    def test_old_build_runtime_stays_baseline_when_local_hash_changes(self):
        status = package.evidence_status([self.publication()], [self.runtime()], "b" * 64)
        self.assertEqual(status["latest_confirmed_published_version"], 4)
        self.assertFalse(status["current_build_published"])
        self.assertFalse(status["current_build_runtime_verified"])
        self.assertFalse(status["current_build_rejoin_persistence_verified"])
        self.assertEqual(len(status["web_play"]), 1)

    def test_null_missing_or_different_runtime_version_cannot_bind(self):
        for version in (None, 3, True, "4"):
            with self.subTest(version=version):
                runtime = self.runtime(version)
                runtime["exact_build_verified"] = True  # Never trust this assertion alone.
                status = package.evidence_status([self.publication()], [runtime], "a" * 64)
                self.assertFalse(status["current_build_runtime_verified"])
        runtime = self.runtime()
        del runtime["runtime_place_version"]
        self.assertFalse(package.evidence_status([self.publication()], [runtime], "a" * 64)["current_build_runtime_verified"])

    def test_ready_unknown_and_rejected_never_count_as_a_publication(self):
        for outcome in ("ready", "unknown", "rejected"):
            with self.subTest(outcome=outcome):
                status = package.evidence_status([self.publication(outcome)], [self.runtime()], "a" * 64)
                self.assertIsNone(status["latest_confirmed_published_version"])
                self.assertFalse(status["current_build_published"])
                self.assertFalse(status["current_build_runtime_verified"])
                self.assertEqual(status["unresolved_publication_attempt"], outcome == "unknown")

    def test_wrong_target_and_old_freeform_runtime_are_not_accepted(self):
        record = self.runtime()
        record["place_id"] = 42
        self.assertEqual(package.evidence_status([self.publication()], [record], "a" * 64)["web_play"], [])
        self.assertIsNone(package.normalize_publication({"universe_id": 1, "place_id": 2, "status": "published"}, "wrong.json"))
        old = {"testedBuild": "published version4", "passed": ["swipe"], "evidence_path": "old.json"}
        self.assertEqual(package.evidence_status([self.publication()], [old], "a" * 64)["web_play"], [])

    def test_failed_or_not_run_rejoin_is_not_live_persistence_qa(self):
        for result in ("failed", "not_run"):
            runtime = self.runtime()
            runtime["checks"][1]["status"] = result
            status = package.evidence_status([self.publication()], [runtime], "a" * 64)
            self.assertTrue(status["current_build_runtime_identity_verified"])
            self.assertFalse(status["current_build_runtime_verified"])
            self.assertFalse(status["current_build_rejoin_persistence_verified"])

    def test_linked_load_pass_and_date_failure_are_not_an_overall_pass(self):
        runtime = self.runtime()
        runtime["checks"] = [
            {"id": "load", "status": "passed"},
            {"id": "date", "status": "failed"},
            {"id": "rejoin_persistence", "status": "passed"},
        ]
        status = package.evidence_status([self.publication()], [runtime], "a" * 64)
        self.assertTrue(status["current_build_runtime_identity_verified"])
        self.assertFalse(status["current_build_runtime_verified"])
        self.assertFalse(status["web_play"][0]["all_declared_checks_passed"])
        self.assertTrue(status["current_build_rejoin_persistence_verified"])
        with tempfile.TemporaryDirectory() as temporary:
            page = package.render_index({"status": status}, Path(temporary))
        self.assertIn("проверка сценариев неполная или содержит ошибки", page)
        self.assertNotIn("На этой сборке прошли перечисленные ниже сценарии Web Play", page)

    def test_empty_or_malformed_scenario_lists_do_not_pass(self):
        for checks in (None, [], [{"id": "load", "status": "passed"}, {"status": "failed"}]):
            runtime = self.runtime()
            runtime["checks"] = checks
            status = package.evidence_status([self.publication()], [runtime], "a" * 64)
            self.assertTrue(status["current_build_runtime_identity_verified"])
            self.assertFalse(status["current_build_runtime_verified"])

    def test_a_passing_linked_report_cannot_hide_failures_in_another(self):
        failed = self.runtime()
        failed["checks"] = [{"id": "date", "status": "failed"}]
        status = package.evidence_status([self.publication()], [self.runtime(), failed], "a" * 64)
        self.assertFalse(status["current_build_runtime_verified"])

    def test_legacy_publication_can_bind_only_with_its_real_binary_hash(self):
        legacy = package.normalize_publication({
            "universe_id": package.UNIVERSE_ID, "place_id": package.PLACE_ID,
            "game_published": True, "published_version": 3, "built_binary_sha256": "a" * 64,
        }, "publication-status-2026-10-27.json")
        self.assertTrue(package.evidence_status([legacy], [self.runtime(3)], "a" * 64)["current_build_runtime_verified"])
        self.assertFalse(package.evidence_status([legacy], [self.runtime(3)], "b" * 64)["current_build_runtime_verified"])


class PackageOutputTests(unittest.TestCase):
    def test_package_uses_checked_build_and_excludes_python_cache(self):
        with tempfile.TemporaryDirectory(prefix="brainrot-package-test-") as temporary:
            base = Path(temporary)
            source, checked, output = base / "source", base / "checked", base / "output"
            for folder in ("src", "tests/__pycache__", "prototype/tools", "prototype/evidence", "assets", "build", ".github/workflows"):
                (source / folder).mkdir(parents=True)
            checked.mkdir()
            for name in ("README.md", "VERSION_CONTROL.md", "BACKLOG.md", "CLOSED_TEST.md", "DEPLOYMENT.md", "WORK_PLAN.md", "default.project.json", "rokit.toml"):
                (source / name).write_text("fixture\n")
            (source / "src/Example.luau").write_text("return {}")
            (source / "tests/compile.luau").write_text("fixture")
            (source / "tests/__pycache__/old.pyc").write_bytes(b"must not ship")
            (source / "prototype/tools/check_background.py").write_text("fixture")
            (source / ".github/workflows/verify.yml").write_text("fixture")
            (source / "build" / package.BUILD_NAME).write_bytes(b"old unverified build")
            (source / "prototype/index.html").write_text("OLD STUDIO INSTRUCTION")
            (source / "prototype/evidence/logic-tests.json").write_text('{"passed":999}')
            model = E.Element("roblox")
            for _ in range(34):
                E.SubElement(model, "Item", {"class": "Model"})
            for _ in range(68):
                E.SubElement(model, "Item", {"class": "KeyframeSequence"})
            (source / "assets/BrainrotCollection.rbxmx").write_bytes(E.tostring(model))
            script = E.SubElement(model, "Item", {"class": "ModuleScript"})
            properties = E.SubElement(script, "Properties")
            E.SubElement(properties, "string", {"name": "Name"}).text = "Example"
            E.SubElement(properties, "ProtectedString", {"name": "Source"}).text = "return {}"
            (checked / "DateABrainrot-Prototype.rbxlx").write_bytes(E.tostring(model))
            (checked / package.BUILD_NAME).write_bytes(b"fresh checked fixture build")
            report = {
                "passed": True, "input_sha256": publisher.current_inputs(source),
                "build_sha256": {path.name: package.sha(path) for path in checked.glob("*.rbxl*")},
                "steps": [{"name": name, "exit_code": 0} for name in ("compile", "build-rbxl", "build-rbxlx")],
            }
            (checked / "check-run.json").write_text(json.dumps(report))
            (checked / "evidence").mkdir()
            (checked / "logs").mkdir()
            with mock.patch.object(package, "ROOT", source), \
                 mock.patch.object(package, "validate_checked_build", side_effect=lambda directory: publisher.validate_checked_build(directory, source)), \
                 contextlib.redirect_stdout(io.StringIO()):
                package.main(["--checked-build", str(checked), "--output", str(output)])
            with zipfile.ZipFile(output / "build/DateABrainrot-Prototype-Package.zip") as archive:
                self.assertFalse(any("__pycache__" in name or name.endswith((".pyc", ".pyo")) for name in archive.namelist()))
                self.assertEqual(archive.read("build/" + package.BUILD_NAME), b"fresh checked fixture build")
                self.assertIn(".github/workflows/verify.yml", archive.namelist())
                summary = json.loads(archive.read("prototype/evidence/final-verification.json"))
                self.assertEqual(summary["input_sha256"], report["input_sha256"])
                self.assertNotIn("logic_tests_passed", summary)
                self.assertFalse(summary["status"]["current_build_runtime_verified"])
                self.assertNotIn(b"OLD STUDIO INSTRUCTION", archive.read("prototype/index.html"))
            self.assertEqual((source / "build" / package.BUILD_NAME).read_bytes(), b"old unverified build")
            # The exported proof keeps a discoverable name even when the
            # original upload report had a custom filename outside the repo.
            upload = base / "approved-upload.json"
            upload.write_text(json.dumps({
                "status": "published", "version_number": 4,
                "universe_id": package.UNIVERSE_ID, "place_id": package.PLACE_ID,
                "build_sha256": report["build_sha256"],
            }))
            exported = base / "published-package"
            with mock.patch.object(package, "ROOT", source), \
                 mock.patch.object(package, "validate_checked_build", side_effect=lambda directory: publisher.validate_checked_build(directory, source)), \
                 contextlib.redirect_stdout(io.StringIO()):
                package.main(["--checked-build", str(checked), "--output", str(exported), "--publication-report", str(upload)])
            repack = base / "repacked"
            with mock.patch.object(package, "ROOT", exported), \
                 mock.patch.object(package, "validate_checked_build", side_effect=lambda directory: publisher.validate_checked_build(directory, exported)), \
                 contextlib.redirect_stdout(io.StringIO()):
                package.main(["--checked-build", str(checked), "--output", str(repack)])
            summary = json.loads((repack / "prototype/evidence/final-verification.json").read_text())
            self.assertTrue(summary["status"]["current_build_published"])
            self.assertFalse(summary["status"]["current_build_runtime_verified"])


if __name__ == "__main__":
    unittest.main()
