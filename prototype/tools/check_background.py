"""Run offline tests and build the game without opening Roblox Studio.

Usage: python3 prototype/tools/check_background.py [--output /path/to/new-folder]
Install the tools from rokit.toml beforehand. The checker never installs tools,
publishes a place, or treats these checks as a visual/runtime playtest.
"""

import argparse
import datetime
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tool(name):
    executable = shutil.which(name)
    if executable:
        return executable
    # The macOS GUI may start without the user's shell PATH.
    candidate = Path.home() / ".rokit" / "bin" / name
    if candidate.is_file():
        return str(candidate)
    raise RuntimeError(f"Missing {name}. Install the tools pinned in rokit.toml first.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New or empty folder for the build and reports; defaults to a temporary folder")
    args = parser.parse_args()
    output = args.output.expanduser().resolve() if args.output else Path(tempfile.mkdtemp(prefix="date-a-brainrot-checks-"))
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        parser.error("--output must be a new or empty folder; old results are never overwritten")
    output.mkdir(parents=True, exist_ok=True)
    (output / "logs").mkdir()
    report = {
        "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "scope": "Offline Luau tests and Rojo build only; no Studio, Web Play, DataStore service or visual QA",
        "passed": False,
        "steps": [],
    }
    print(f"Results: {output}", flush=True)

    def run(name, command, work):
        started = time.monotonic()
        result = subprocess.run(command, cwd=work, capture_output=True, text=True, timeout=120)
        log = result.stdout + result.stderr
        (output / "logs" / f"{name}.log").write_text(log, encoding="utf-8")
        report["steps"].append({
            "name": name, "exit_code": result.returncode,
            "seconds": round(time.monotonic() - started, 3),
            "log": f"logs/{name}.log",
        })
        print(log.strip(), flush=True)
        if result.returncode:
            raise RuntimeError(f"{name} failed (exit {result.returncode}); see logs/{name}.log")
        return result.stdout.strip()

    try:
        lune, rojo = tool("lune"), tool("rojo")
        with tempfile.TemporaryDirectory(prefix="date-a-brainrot-source-") as temporary:
            work = Path(temporary)
            for directory in ("src", "tests", "prototype/tools"):
                shutil.copytree(ROOT / directory, work / directory, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "*.pyo"))
            (work / "assets").mkdir()
            shutil.copy2(ROOT / "assets/BrainrotCollection.rbxmx", work / "assets/BrainrotCollection.rbxmx")
            for name in ("default.project.json", "rokit.toml"):
                shutil.copy2(ROOT / name, work / name)
            report["input_sha256"] = {
                path.relative_to(work).as_posix(): sha256(path)
                for path in sorted(work.rglob("*")) if path.is_file()
            }
            evidence = work / "prototype/evidence"
            evidence.mkdir(parents=True)
            try:
                report["tools"] = {
                    "lune": run("lune-version", [lune, "--version"], work),
                    "rojo": run("rojo-version", [rojo, "--version"], work),
                }
                # Only top-level tests run offline; tests/studio requires Roblox.
                tests = sorted(
                    (path for path in (work / "tests").glob("*.luau") if path.is_file()),
                    key=lambda path: (path.stem != "compile", path.name),
                )
                if not tests:
                    raise RuntimeError("No offline tests found in tests/*.luau")
                for test in tests:
                    run(test.stem, [lune, "run", test.relative_to(work).as_posix()], work)
                if any((work / "tests").glob("test_*.py")):
                    run("python-tests", [sys.executable, "-B", "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"], work)
                for extension in ("rbxl", "rbxlx"):
                    target = output / f"DateABrainrot-Prototype.{extension}"
                    run(f"build-{extension}", [rojo, "build", "default.project.json", "-o", str(target)], work)
                report["build_sha256"] = {
                    path.name: sha256(path) for path in sorted(output.glob("*.rbxl*"))
                }
                report["passed"] = True
            finally:
                shutil.copytree(evidence, output / "evidence")
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        report["error"] = str(error)
        print(f"Check failed: {error}", file=sys.stderr)
    finally:
        report["finished_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        (output / "check-run.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if report["passed"]:
        print("Offline checks passed. Visual and live-service tests are separate.")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
