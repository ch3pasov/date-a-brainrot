"""Validate or publish a checked build to the fixed Date a Brainrot test place.

Dry run (default):
  python3 prototype/tools/publish_closed_test.py --checked-build /path/to/checks

Publish only after authorizing the exact build:
  python3 prototype/tools/publish_closed_test.py --checked-build /path/to/checks \
    --publish --api-key-file /path/to/private-key-file

ROBLOX_API_KEY is the alternative credential source. Keys are never CLI values,
printed, written into reports, or forwarded across redirects. No automatic retry
is performed: an unknown outcome must be checked in Roblox version history.

API: https://create.roblox.com/docs/cloud/guides/usage-place-publishing
"""

import argparse
import datetime
import hashlib
import json
import os
import sys
import tempfile
import urllib.error
import urllib.request
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
UNIVERSE_ID = 10770822773
PLACE_ID = 114564825581977
BUILD_NAME = "DateABrainrot-Prototype.rbxl"
ENDPOINT = f"https://apis.roblox.com/universes/v1/{UNIVERSE_ID}/places/{PLACE_ID}/versions?versionType=Published"


class ValidationError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_report(path, report):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, prefix=".publish-report-", delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(report, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def current_inputs(root):
    files = [root / name for name in ("rokit.toml", "default.project.json", "assets/BrainrotCollection.rbxmx")]
    for directory in ("src", "tests", "prototype/tools"):
        files.extend(path for path in (root / directory).rglob("*")
                     if path.is_file() and "__pycache__" not in path.parts and path.suffix not in (".pyc", ".pyo"))
    return {path.relative_to(root).as_posix(): digest(path.read_bytes()) for path in sorted(files)}


def validate_checked_build(directory, root=None):
    root = ROOT if root is None else root
    raw_report = (directory / "check-run.json").read_bytes()
    try:
        checks = json.loads(raw_report)
    except (ValueError, UnicodeError):
        raise ValidationError("The check report is not valid JSON.") from None
    if not isinstance(checks, dict) or checks.get("passed") is not True:
        raise ValidationError("The checked build has not passed its offline checks.")
    inputs = current_inputs(root)
    if checks.get("input_sha256") != inputs:
        raise ValidationError("Current source/config/asset/test inputs differ from the checked build. Run check_background.py again.")
    required_steps = {"build-rbxl", "build-rbxlx"}
    required_steps.update(path.stem for path in (root / "tests").glob("*.luau") if path.is_file())
    if any((root / "tests").glob("test_*.py")):
        required_steps.add("python-tests")
    steps = checks.get("steps")
    if not isinstance(steps, list) or any(not isinstance(step, dict) or step.get("exit_code") != 0 for step in steps):
        raise ValidationError("The check report contains missing or failed steps.")
    if not required_steps.issubset({step.get("name") for step in steps}):
        raise ValidationError("The check report is missing a required test or build step.")
    payload = None
    hashes = {}
    recorded_hashes = checks.get("build_sha256")
    if not isinstance(recorded_hashes, dict):
        raise ValidationError("The check report has no build hashes.")
    for extension in ("rbxl", "rbxlx"):
        name = f"DateABrainrot-Prototype.{extension}"
        data = (directory / name).read_bytes()
        hashes[name] = digest(data)
        if not data or recorded_hashes.get(name) != hashes[name]:
            raise ValidationError("A build file differs from its checked hash. Run check_background.py again.")
        if name == BUILD_NAME:
            payload = data
    return payload, {
        "check_report_sha256": digest(raw_report),
        "input_sha256": inputs,
        "build_sha256": hashes,
        "inputs_verified_utc": now(),
    }


def read_key(path):
    try:
        value = path.read_text(encoding="utf-8") if path else os.environ.get("ROBLOX_API_KEY", "")
    except (OSError, UnicodeError):
        raise ValidationError("Unable to read the API key file.") from None
    value = value.strip()
    if not value or len(value) > 16384 or not value.isascii() or any(ord(character) < 33 or ord(character) > 126 for character in value):
        raise ValidationError("A nonempty API key without whitespace/control characters is required for --publish.")
    return value


def publish_once(payload, key):
    request = urllib.request.Request(ENDPOINT, data=payload, method="POST", headers={
        "x-api-key": key,
        "Content-Type": "application/octet-stream",
        "Accept": "application/json",
    })
    opener = urllib.request.build_opener(NoRedirect())
    try:
        with opener.open(request, timeout=60) as response:
            status = response.status
            # Do not keep raw response bodies: error services could echo headers.
            result = json.loads(response.read(65536))
        version = result.get("versionNumber") if isinstance(result, dict) else None
        if not 200 <= status < 300 or type(version) is not int or version <= 0:
            return {"status": "unknown", "http_status": status, "error": "No valid published version was returned. Check Roblox version history before another attempt."}
        return {"status": "published", "http_status": status, "version_number": version}
    except urllib.error.HTTPError as error:
        # A server-side error can occur after a write; never infer safe retry.
        rejected = 400 <= error.code < 500
        return {
            "status": "rejected" if rejected else "unknown",
            "http_status": error.code,
            "error": "Roblox rejected the request; no retry was attempted." if rejected else "Publication outcome is unknown. Check Roblox version history before another attempt.",
        }
    except Exception:
        # Exception strings, request objects and raw HTTP responses can contain
        # credentials. Only a fixed, nonsecret diagnostic leaves this boundary.
        return {"status": "unknown", "error": "Publication outcome is unknown. Check Roblox version history before another attempt."}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checked-build", type=Path, required=True)
    parser.add_argument("--publish", action="store_true", help="Send one POST after validating the build; otherwise make no network requests")
    parser.add_argument("--api-key-file", type=Path, help="Read the key from a file instead of ROBLOX_API_KEY; unused in dry run")
    parser.add_argument("--report", type=Path, help="New JSON report path; existing reports are never overwritten")
    args = parser.parse_args(argv)
    directory = args.checked_build.expanduser().resolve()
    report_path = args.report.expanduser().resolve() if args.report else directory / f"closed-test-publish-{uuid.uuid4().hex}.json"
    report = {
        "started_utc": now(), "universe_id": UNIVERSE_ID, "place_id": PLACE_ID,
        "mode": "publish" if args.publish else "dry_run", "status": "validating",
        "access_settings_changed": False, "network_attempts": 0,
    }
    try:
        # Reserve the report before any request so previous outcomes cannot be lost.
        with report_path.open("x", encoding="utf-8") as stream:
            json.dump(report, stream, indent=2)
    except OSError:
        print("Cannot create a new report file; no request was sent.", file=sys.stderr)
        return 1

    try:
        payload, verified = validate_checked_build(directory)
        report.update(verified)
        if args.publish:
            key_path = args.api_key_file.expanduser() if args.api_key_file else None
            key = read_key(key_path)
            # Check again immediately before sending; use the same validated
            # in-memory payload even if a build file changes during the upload.
            if current_inputs(ROOT) != verified["input_sha256"]:
                raise ValidationError("Inputs changed before publication. Run check_background.py again.")
            report.update(status="unknown", network_attempts=1)
            write_report(report_path, report)
            report.update(publish_once(payload, key))
            del key
        else:
            report["status"] = "ready"
    except ValidationError as error:
        report.update(status="validation_failed", error=str(error))
    except (OSError, ValueError, TypeError):
        report.update(status="unknown" if report["network_attempts"] else "validation_failed",
                      error="Unable to validate the build or save its report; no automatic retry was attempted.")
    finally:
        report["finished_utc"] = now()
        try:
            write_report(report_path, report)
        except OSError:
            print("Unable to save the final report. If publication was attempted, check Roblox version history before another attempt.", file=sys.stderr)
            return 1
    print(json.dumps({"status": report["status"], "version_number": report.get("version_number"), "report": str(report_path)}))
    return 0 if report["status"] in ("ready", "published") else 1


if __name__ == "__main__":
    sys.exit(main())
