"""Write/read a nonsecret publication receipt through Git, without a browser.

CI prepares a whitelisted report, then an isolated job records it in an
annotated tag using its short-lived GITHUB_TOKEN. Locally, existing SSH Git
access reads the tag. A missing/unknown receipt never authorizes a republish.
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

REPOSITORY = "ch3pasov/date_a_brainrot"
REMOTE = f"git@github.com:{REPOSITORY}.git"
UNIVERSE_ID, PLACE_ID = 10770822773, 114564825581977
PREFIX = "roblox-publish"
STATUSES = {"published", "unknown", "rejected", "validation_failed", "unconfirmed"}
HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")


def require(value, pattern, label):
    if not isinstance(value, str) or not pattern.fullmatch(value):
        raise ValueError(f"Invalid {label}")
    return value


def identity(env):
    commit = require(env.get("RELEASE_COMMIT"), HEX40, "source commit")
    run = require(env.get("RELEASE_RUN_ID"), re.compile(r"[1-9][0-9]*"), "run ID")
    attempt = require(env.get("RELEASE_RUN_ATTEMPT"), re.compile(r"[1-9][0-9]*"), "run attempt")
    return commit, run, attempt


def prepare(report, checks, env):
    commit, run, attempt = identity(env)
    status = "unconfirmed"
    hashes = {}
    if isinstance(report, dict):
        if report.get("universe_id") != UNIVERSE_ID or report.get("place_id") != PLACE_ID:
            raise ValueError("Publication target mismatch")
        status = report.get("status")
        if status not in STATUSES:
            status = "unknown" if report.get("network_attempts") else "unconfirmed"
        for name in ("DateABrainrot-Prototype.rbxl", "DateABrainrot-Prototype.rbxlx"):
            value = report.get("build_sha256", {}).get(name)
            if isinstance(value, str) and HEX64.fullmatch(value):
                hashes[name] = value
    version = report.get("version_number") if isinstance(report, dict) else None
    checks_passed = isinstance(checks, dict) and checks.get("passed") is True
    if status == "published":
        if type(version) is not int or version <= 0 or not checks_passed or len(hashes) != 2:
            raise ValueError("Incomplete success receipt")
        if checks.get("build_sha256") != hashes:
            raise ValueError("Checked/published build mismatch")
    else:
        version = None
    return {
        "schema_version": 1, "kind": "roblox_publication_receipt", "status": status,
        "source_commit": commit, "run_id": run, "run_attempt": attempt,
        "universe_id": UNIVERSE_ID, "place_id": PLACE_ID, "version_number": version,
        "build_sha256": hashes, "checks_passed": checks_passed,
        "workflow_run_url": f"https://github.com/{REPOSITORY}/actions/runs/{run}",
        "checked_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "access_settings_changed": False,
    }


def tag_name(receipt):
    return f"{PREFIX}/{receipt['source_commit']}/{receipt['run_id']}-{receipt['run_attempt']}"


def validate(receipt, commit):
    if not isinstance(receipt, dict) or receipt.get("schema_version") != 1 or receipt.get("kind") != "roblox_publication_receipt":
        raise ValueError("Invalid receipt schema")
    if receipt.get("source_commit") != commit or receipt.get("universe_id") != UNIVERSE_ID or receipt.get("place_id") != PLACE_ID:
        raise ValueError("Receipt source/target mismatch")
    if receipt.get("status") not in STATUSES:
        raise ValueError("Invalid publication status")
    # Rebuild only the allowed fields; never forward arbitrary report content.
    rebuilt = prepare(receipt, {"passed": receipt.get("checks_passed"), "build_sha256": receipt.get("build_sha256")}, {
        "RELEASE_COMMIT": commit, "RELEASE_RUN_ID": receipt.get("run_id"), "RELEASE_RUN_ATTEMPT": receipt.get("run_attempt"),
    })
    if receipt.get("workflow_run_url") != rebuilt["workflow_run_url"] or receipt.get("access_settings_changed") is not False:
        raise ValueError("Invalid receipt metadata")
    timestamp = receipt.get("checked_utc")
    if not isinstance(timestamp, str):
        raise ValueError("Invalid receipt timestamp")
    datetime.datetime.fromisoformat(timestamp)
    rebuilt["checked_utc"] = timestamp
    return rebuilt


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None


def api_post(path, data, token):
    request = urllib.request.Request(f"https://api.github.com/repos/{REPOSITORY}/git/{path}",
        data=json.dumps(data).encode(), method="POST", headers={
            "Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json",
            "Content-Type": "application/json", "X-GitHub-Api-Version": "2026-03-10",
        })
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=30) as response:
        return json.loads(response.read(65536))


def record(receipt, env, post=api_post):
    commit, _, _ = identity(env)
    receipt = validate(receipt, commit)
    token = env.get("GITHUB_TOKEN")
    if not token:
        raise ValueError("Missing temporary GitHub token")
    name = tag_name(receipt)
    result = post("tags", {"tag": name, "message": json.dumps(receipt, separators=(",", ":")), "object": commit, "type": "commit"}, token)
    sha = require(result.get("sha"), HEX40, "tag object")
    post("refs", {"ref": f"refs/tags/{name}", "sha": sha}, token)
    return name


def git(arguments, cwd):
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_SSH_COMMAND="ssh -o BatchMode=yes")
    result = subprocess.run(["git", *arguments], cwd=cwd, env=env, capture_output=True, text=True, timeout=45)
    if result.returncode:
        raise RuntimeError("Git receipt transport failed; no publication was attempted")
    return result.stdout


def decode_tag(raw, selected, commit):
    header, message = raw.split("\n\n", 1)
    if f"object {commit}\n" not in header + "\n" or "\ntype commit\n" not in "\n" + header + "\n":
        raise ValueError("Receipt tag points to a different commit")
    receipt = validate(json.loads(message), commit)
    if selected != f"refs/tags/{tag_name(receipt)}":
        raise ValueError("Receipt tag identity mismatch")
    return receipt


def read(commit, wait_seconds=0, interval=10, output=None):
    require(commit, HEX40, "source commit")
    deadline = time.monotonic() + wait_seconds
    while True:
        rows = git(["ls-remote", "--tags", "--refs", REMOTE, f"refs/tags/{PREFIX}/{commit}/*"], None)
        refs = [line.split()[1] for line in rows.splitlines() if len(line.split()) == 2]
        if refs:
            def order(ref):
                run, attempt = ref.rsplit("/", 1)[1].split("-")
                return int(run), int(attempt)
            selected = max(refs, key=order)
            with tempfile.TemporaryDirectory(prefix="brainrot-receipt-") as temp:
                git(["init", "--bare", "--quiet"], temp)
                git(["fetch", "--depth=1", "--no-tags", REMOTE, selected], temp)
                raw = git(["cat-file", "tag", "FETCH_HEAD"], temp)
            receipt = decode_tag(raw, selected, commit)
            if output:
                output.write_text(json.dumps(receipt, indent=2) + "\n")
            print(json.dumps(receipt, indent=2))
            return 0 if receipt["status"] == "published" else 1
        if time.monotonic() >= deadline:
            print(json.dumps({"status": "no_receipt_yet", "source_commit": commit, "publication_attempted_by_reader": False}))
            return 2
        time.sleep(min(interval, max(0, deadline - time.monotonic())))


def read_latest(output=None):
    """Read the newest recorded attempt, including failures; never publish.

    A workflow still in progress has no receipt yet. This command does not
    assert that the newest recorded attempt is the current running server.
    """
    rows = git(["ls-remote", "--tags", "--refs", REMOTE, f"refs/tags/{PREFIX}/*"], None)
    pattern = re.compile(rf"refs/tags/{re.escape(PREFIX)}/([0-9a-f]{{40}})/([1-9][0-9]*)-([1-9][0-9]*)")
    attempts = []
    for line in rows.splitlines():
        if not line.strip():
            continue
        fields = line.split()
        if len(fields) != 2 or not HEX40.fullmatch(fields[0]):
            raise ValueError("Invalid receipt listing")
        match = pattern.fullmatch(fields[1])
        if not match:
            # An invalid newest record must not silently fall back to an old
            # success and make a broken publication look current.
            raise ValueError("Invalid receipt reference")
        commit, run, attempt = match.groups()
        attempts.append((int(run), int(attempt), commit))
    if not attempts:
        print(json.dumps({"status": "no_receipt_yet", "source_commit": None, "publication_attempted_by_reader": False}))
        return 2
    _, _, commit = max(attempts)
    return read(commit, output=output)


def load_if_exists(path):
    return json.loads(path.read_text()) if path and path.exists() else None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    prep = sub.add_parser("prepare")
    prep.add_argument("--report", type=Path, required=True)
    prep.add_argument("--checks", type=Path, required=True)
    prep.add_argument("--github-output", type=Path, required=True)
    sub.add_parser("record")
    reader = sub.add_parser("read")
    reader.add_argument("--commit", required=True)
    reader.add_argument("--wait", type=int, default=0)
    reader.add_argument("--output", type=Path)
    latest = sub.add_parser("latest", help="Read the newest recorded attempt without publishing or changing the checkout")
    latest.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "prepare":
            receipt = prepare(load_if_exists(args.report), load_if_exists(args.checks), os.environ)
            with args.github_output.open("a") as stream:
                stream.write("json=" + json.dumps(receipt, separators=(",", ":")) + "\n")
            return 0
        if args.command == "record":
            payload = os.environ.get("PUBLICATION_RECEIPT")
            receipt = json.loads(payload) if payload else prepare(None, None, os.environ)
            print(json.dumps({"receipt_tag": record(receipt, os.environ)}))
            return 0
        if args.command == "latest":
            return read_latest(output=args.output)
        return read(args.commit, max(0, min(args.wait, 600)), output=args.output)
    except urllib.error.HTTPError as error:
        print(f"Receipt API failed (HTTP {error.code}); no Roblox request was made by this step", file=sys.stderr)
    except Exception:
        # Avoid exception strings: transport/request objects can contain tokens.
        print("Unable to validate/transfer publication receipt; no automatic republish", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
