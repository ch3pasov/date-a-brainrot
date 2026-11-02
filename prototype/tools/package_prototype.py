"""Package an explicitly checked build; never launch Studio or publish Roblox.

python3 prototype/tools/package_prototype.py --checked-build /path/to/checks
Outputs go to a new temporary folder, or to a new/empty --output folder.
Web Play evidence uses schema_version=1, kind=web_play, checks[].status/evidence.
"""

import argparse
import datetime
import hashlib
import html
import json
import re
import shutil
import tempfile
import xml.etree.ElementTree as E
import zipfile
from pathlib import Path

from publish_closed_test import BUILD_NAME, PLACE_ID, ROOT, UNIVERSE_ID, ValidationError, current_inputs, validate_checked_build


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def positive_integer(value):
    return value if type(value) is int and value > 0 else None


def target_matches(record):
    return record.get("universe_id") == UNIVERSE_ID and record.get("place_id") == PLACE_ID


def normalize_publication(record, evidence):
    if not isinstance(record, dict) or not target_matches(record):
        return None
    legacy = record.get("game_published") is True
    status = "published" if legacy else record.get("status")
    version = positive_integer(record.get("published_version") if legacy else record.get("version_number"))
    hashes = record.get("build_sha256")
    binary = record.get("built_binary_sha256") if legacy else (hashes.get(BUILD_NAME) if isinstance(hashes, dict) else None)
    if not isinstance(binary, str) or not re.fullmatch(r"[0-9a-f]{64}", binary):
        binary = None
    return {
        "status": status, "version_number": version, "built_binary_sha256": binary,
        "universe_id": UNIVERSE_ID, "place_id": PLACE_ID, "evidence": evidence,
        "checked_utc": record.get("finished_utc") or record.get("checked_utc") or record.get("started_utc") or "",
    }


def evidence_status(publications, runtimes, binary_hash):
    confirmed = [record for record in publications if record["status"] == "published" and record["version_number"]]
    latest = max(confirmed, key=lambda record: record["version_number"]) if confirmed else None
    current_publications = [record for record in confirmed if record["built_binary_sha256"] == binary_hash]
    rows = []
    for record in runtimes:
        if record.get("schema_version") != 1 or record.get("kind") != "web_play" or not target_matches(record):
            continue
        version = positive_integer(record.get("runtime_place_version"))
        binding = next((item for item in current_publications if version and item["version_number"] == version), None)
        declared = record.get("checks")
        checks = [item for item in declared if isinstance(item, dict) and isinstance(item.get("id"), str)] if isinstance(declared, list) else []
        all_passed = bool(checks) and len(checks) == len(declared) and all(item.get("status") == "passed" for item in checks)
        rows.append({
            "checked_utc": record.get("checked_utc", ""), "evidence": record["evidence_path"],
            "runtime_place_version": version, "expected_published_version": positive_integer(record.get("expected_published_version")),
            "exact_build_verified": binding is not None,
            "all_declared_checks_passed": all_passed,
            "publication_evidence": binding["evidence"] if binding else None,
            "browser_visible": record.get("browser_visible"), "studio_running": record.get("studio_running"),
            "user_confirmed_no_interference": record.get("user_confirmed_no_interference"), "checks": checks,
        })
    exact = [row for row in rows if row["exact_build_verified"]]
    return {
        "latest_confirmed_published_version": latest["version_number"] if latest else None,
        "current_build_published": bool(current_publications),
        "publication_attempts": publications,
        "unresolved_publication_attempt": any(item["status"] == "unknown" for item in publications),
        "web_play": rows,
        "current_build_runtime_identity_verified": bool(exact),
        "current_build_runtime_verified": bool(exact) and all(row["all_declared_checks_passed"] for row in exact),
        "current_build_rejoin_persistence_verified": any(
            check.get("id") == "rejoin_persistence" and check.get("status") == "passed" for row in exact for check in row["checks"]
        ),
    }


def inspect_build(directory, verified):
    root = E.parse(directory / "DateABrainrot-Prototype.rbxlx").getroot()
    items, classes, scripts = list(root.iter("Item")), {}, []
    for item in items:
        kind = item.get("class")
        classes[kind] = classes.get(kind, 0) + 1
        if kind in ("Script", "LocalScript", "ModuleScript"):
            source = next(prop for prop in item.find("Properties") if prop.get("name") == "Source").text or ""
            assert source and "PersistenceTestFailures" not in source, "Invalid script or Studio-only fault fixture in build"
            scripts.append({"name": item.findtext('Properties/string[@name="Name"]'), "class": kind, "sha256": hashlib.sha256(source.encode()).hexdigest()})
    source_hashes = {name: value for name, value in verified["input_sha256"].items() if name.startswith("src/") and name.endswith(".luau")}
    assert len(scripts) == len(source_hashes) and classes.get("Model") == 34 and classes.get("KeyframeSequence") == 68
    assert not classes.get("PackageLink")
    assert all(value in {script["sha256"] for script in scripts} for value in source_hashes.values()), "Built sources differ"
    references = {item.get("referent") for item in items}
    assert all(ref.text in (None, "null") or ref.text in references for ref in root.iter("Ref")), "Broken model reference"
    asset = E.parse(ROOT / "assets/BrainrotCollection.rbxmx").getroot()
    assert not any(item.get("class") in ("Script", "LocalScript", "ModuleScript", "PackageLink") for item in asset.iter("Item"))
    return {"characters": 34, "variants_per_character": 4, "authored_local_clips": 68, "authored_script_files": len(scripts),
            "built_sources_match_checked_inputs": True, "xml_internal_references_valid": True, "scripts": scripts}


def read_record(path):
    record = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(record, dict):
        raise ValidationError(f"Evidence is not an object: {path.name}")
    return record


def render_index(report, evidence_root):
    status = report["status"]
    publication = "Новая локальная сборка ещё не подтверждена в Roblox."
    if status["current_build_published"]:
        publication = "Хеш локальной сборки совпадает с подтверждённой публикацией Roblox."
    if status["latest_confirmed_published_version"]:
        publication += f' Последняя подтверждённая опубликованная версия: №{status["latest_confirmed_published_version"]}.'
    if status["unresolved_publication_attempt"]:
        publication += " Есть попытка публикации с неизвестным исходом; её нужно сверить с историей Roblox."
    runtime = "Новая сборка ещё не проверена в Web Play."
    if status["current_build_runtime_verified"]:
        runtime = "На этой сборке прошли перечисленные ниже сценарии Web Play."
    elif status["current_build_runtime_identity_verified"]:
        runtime = "Версия и хеш сборки подтверждены, но проверка сценариев неполная или содержит ошибки. Результаты каждого сценария перечислены ниже."
    sections, figures = [], []
    for row in status["web_play"]:
        version = row["runtime_place_version"]
        identity = f"версия сервера №{version}" if version else f'ожидаемая публикация №{row["expected_published_version"] or "?"}; версия сервера не подтверждена'
        scope = "текущая сборка" if row["exact_build_verified"] else "baseline, не подтверждает новую сборку"
        label = f'Web Play · {row["checked_utc"][:10]} · {identity} · {scope}'
        checks = "".join(f'<li>{html.escape(check.get("label") or check["id"])}: {html.escape(str(check.get("status", "not_run")))}</li>' for check in row["checks"])
        sections.append(f'<section><h3>{html.escape(label)}</h3><ul>{checks}</ul><a href="evidence/{html.escape(row["evidence"])}">Запись проверки</a></section>')
        for check in row["checks"]:
            for name in check.get("evidence", []):
                if not isinstance(name, str):
                    continue
                image = (evidence_root / row["evidence"]).parent / name
                try:
                    relative = image.resolve().relative_to(evidence_root.resolve()).as_posix()
                except ValueError:
                    continue
                if image.is_file() and image.suffix.lower() in (".jpg", ".jpeg", ".png"):
                    caption = (check.get("label") or check["id"]) + " · " + scope
                    figures.append(f'<figure><figcaption>{html.escape(caption)}</figcaption><img loading="lazy" src="evidence/{html.escape(relative)}" alt="{html.escape(caption)}"></figure>')
    archive = []
    for name, caption in (("2026-10-27-cold-phone-chat.jpg", "Переписка · Studio · 27 октября 2026 · архив"),
                          ("2026-10-27-cold-phone-date.jpg", "Свидание · Studio · 27 октября 2026 · архив"),
                          ("night-pc-matches-v6.jpg", "Знакомства · Studio · 14 октября 2026 · архив")):
        if (evidence_root / name).is_file():
            archive.append(f'<figure><figcaption>{caption}</figcaption><img loading="lazy" src="evidence/{name}" alt="{caption}"></figure>')
    return '''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>date a brainrot — проверенная сборка</title><style>body{background:#fff9ef;color:#312d42;font:17px/1.65 system-ui;max-width:1280px;margin:auto;padding:32px}h1{font-size:44px;line-height:1.1}a{color:#6f4ba7}header{max-width:1000px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,290px),1fr));gap:22px}figure{margin:0;background:white;border:1px solid #dedad2;border-radius:20px;padding:16px}img{width:100%;height:460px;object-fit:contain;background:#fff9ef;border-radius:12px}figcaption{font-size:18px;font-weight:650}.note{color:#6f697d}.status{padding:18px 22px;background:#f5f0e7;border-radius:18px}details,section{margin:30px 0}</style><header><h1>date a brainrot</h1><p>Свайпы, телефонная переписка, жесты в звонке и свидание в выбранном месте. 34 блочных персонажа × 4 варианта.</p><p><a href="https://create.roblox.com/dashboard/creations/experiences/10770822773/overview">Открыть Creator Hub → Play in Browser</a> · <a href="../build/DateABrainrot-Prototype.rbxl">Скачать проверенную сборку</a> · <a href="../build/DateABrainrot-Prototype-Package.zip">Скачать пакет</a></p><div class="status"><p>Автоматические проверки этой локальной сборки пройдены. Они не заменяют визуальную проверку.</p><p>PUBLICATION</p><p>RUNTIME</p></div><p>Для запуска опубликованной игры используй Play in Browser в аккаунте владельца. Локальные изменения появятся там только после публикации. Управление: кнопки, перетаскивание или стрелки; в мини-играх — 1–3 и 1–4. Пробел — жест «помахать», «?» — справка.</p><p class="note">Разработка и автоматические проверки не требуют Studio. При фоновой проверке браузер остаётся скрытым; управление направляется только в игровую вкладку. Кадры и результаты относятся к указанной версии, а не ко всем последующим изменениям.</p></header><main>SECTIONS<div class="grid">FIGURES</div><details><summary>Архивные кадры Studio — не проверка новой сборки</summary><div class="grid">ARCHIVE</div></details></main><p><a href="evidence/final-verification.json">Точный отчёт и хеши</a> · <a href="../BACKLOG.md">Беклог</a> · <a href="../CLOSED_TEST.md">Закрытый тест</a> · <a href="../README.md">Инструкции</a></p></html>'''.replace("PUBLICATION", html.escape(publication)).replace("RUNTIME", html.escape(runtime)).replace("SECTIONS", "".join(sections)).replace("FIGURES", "".join(figures)).replace("ARCHIVE", "".join(archive))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checked-build", type=Path, required=True)
    parser.add_argument("--output", type=Path, help="New or empty package folder; defaults to a temporary folder")
    parser.add_argument("--publication-report", type=Path, action="append", default=[])
    args = parser.parse_args(argv)
    checked = args.checked_build.expanduser().resolve()
    _, verified = validate_checked_build(checked)
    checks = read_record(checked / "check-run.json")
    structure = inspect_build(checked, verified)
    output = args.output.expanduser().resolve() if args.output else Path(tempfile.mkdtemp(prefix="date-a-brainrot-package-"))
    if output == ROOT or any(output == ROOT / folder or ROOT / folder in output.parents for folder in ("src", "assets", "tests", "prototype", ".github")):
        parser.error("Package output must not be inside a source folder")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        parser.error("--output must be a new or empty folder")
    output.mkdir(parents=True, exist_ok=True)
    for name in ("README.md", "VERSION_CONTROL.md", "BACKLOG.md", "CLOSED_TEST.md", "DEPLOYMENT.md", "WORK_PLAN.md", "default.project.json", "rokit.toml"):
        shutil.copy2(ROOT / name, output / name)
    for folder in ("src", "assets", "tests", "prototype", ".github"):
        if (ROOT / folder).exists():
            shutil.copytree(ROOT / folder, output / folder, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "*.pyo"))
    if current_inputs(output) != verified["input_sha256"]:
        raise ValidationError("Inputs changed while packaging; run the checker again")
    (output / "build").mkdir()
    for name, expected in verified["build_sha256"].items():
        shutil.copy2(checked / name, output / "build" / name)
        if sha(output / "build" / name) != expected:
            raise ValidationError("A checked build changed while packaging")
    evidence = output / "prototype/evidence"
    offline = evidence / "offline-checks" / verified["check_report_sha256"][:12]
    # A restored package may already contain this check. Replace only its
    # copied staging directory, never the source checkout's evidence.
    if offline.exists():
        shutil.rmtree(offline)
    offline.mkdir(parents=True)
    shutil.copy2(checked / "check-run.json", offline / "check-run.json")
    for folder in ("evidence", "logs"):
        shutil.copytree(checked / folder, offline / folder, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "*.pyo"))
    publication_paths = list(evidence.glob("publication-status-*.json")) + list(evidence.rglob("closed-test-publish-*.json"))
    for source in sorted(set(args.publication_report + list(checked.glob("closed-test-publish-*.json")))):
        destination = evidence / "publications" / f"closed-test-publish-{sha(source)[:16]}.json"
        destination.parent.mkdir(exist_ok=True)
        shutil.copy2(source, destination)
        publication_paths.append(destination)
    publications = []
    for path in sorted(set(publication_paths)):
        item = normalize_publication(read_record(path), path.relative_to(evidence).as_posix())
        if item:
            publications.append(item)
    runtimes = []
    for path in evidence.rglob("web-play-proof*.json"):
        record = read_record(path)
        record["evidence_path"] = path.relative_to(evidence).as_posix()
        runtimes.append(record)
    report = {
        "schema_version": 1, "checked_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "universe_id": UNIVERSE_ID, "place_id": PLACE_ID,
        "build_sha256": verified["build_sha256"], "input_sha256": verified["input_sha256"],
        "structure": structure,
        "offline_checks": {"passed": True, "evidence": (offline / "check-run.json").relative_to(evidence).as_posix(), "steps": checks["steps"]},
        "status": evidence_status(publications, runtimes, verified["build_sha256"][BUILD_NAME]),
        "scope": "Offline checks, publication records and Web Play scenarios are separate evidence; baseline does not verify a changed build.",
    }
    (evidence / "final-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (output / "prototype/index.html").write_text(render_index(report, evidence), encoding="utf-8")
    archive = output / "build/DateABrainrot-Prototype-Package.zip"
    package_report = evidence / "package-verification.json"
    files = [path for path in output.rglob("*") if path.is_file() and path != package_report]
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as package:
        for path in sorted(files):
            package.write(path, path.relative_to(output).as_posix())
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None
    package_report.write_text(json.dumps({"bytes": archive.stat().st_size, "sha256": sha(archive), "integrity": "OK"}, indent=2) + "\n")
    print(json.dumps({"package": str(archive), "overview": str(output / "prototype/index.html"), "report": str(evidence / "final-verification.json"), "status": report["status"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
