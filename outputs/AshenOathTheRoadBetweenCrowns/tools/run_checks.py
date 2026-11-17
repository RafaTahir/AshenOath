#!/usr/bin/env python3
"""One fast entry point for static contracts and five isolated Godot headless suites."""
from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

from check_architecture import lex

PROJECT = Path(__file__).resolve().parents[1]
TOOLS = PROJECT / "tools"
REPO = PROJECT.parents[1]
LOGS = REPO / ".release-gate/phase5"
DIAGNOSTICS = re.compile(r"(?m)^\s*(?:SCRIPT ERROR|ERROR|WARNING):|ObjectDB instances leaked|resources still in use at exit")
SUITES = (
    ("Phase 1: core/economy", "test_phase1_core_and_economy.gd", r"PHASE 1 PASS: (\d+) checks"),
    ("Phase 2: combat/bow", "test_phase2_combat_and_bow.gd", r"PHASE 2 PASS: (\d+) checks"),
    ("Phase 3: zones/travel", "test_phase3_zones_and_transitions.gd", r"PHASE 3 ZONES AND TRANSITIONS: PASS \((\d+) checks\)"),
    ("Phase 4: cast/input/HUD", "test_phase4_cast_input_and_hud.gd", r"PHASE 4 CAST INPUT AND HUD: PASS \((\d+) checks\)"),
    ("Phase 5: campaign replay", "test_phase5_campaign_replay_benchmark.gd", r"PHASE 5 CAMPAIGN REPLAY: PASS \((\d+) checks\)"),
)
UI_SOURCES = (
    "assets/ui/fonts/Spectral-Medium.ttf",
    "assets/icons/iron_trap.svg",
    "assets_external/ui/greyfen_menu_stylized.png",
    "assets/ui/story_chapters_atlas.png",
)


@dataclass
class Result:
    name: str
    status: str
    elapsed_ms: float
    detail: str


def command(name: str, argv: list[str], log: str, success: str = "", timeout: int = 90) -> Result:
    started = time.perf_counter()
    try:
        profile = LOGS / "profiles" / Path(log).stem
        profile.mkdir(parents=True, exist_ok=True)
        process = subprocess.run(argv, cwd=REPO, capture_output=True, text=True,
                                 encoding="utf-8", errors="replace", timeout=timeout,
                                 env={**os.environ, "PYTHONUTF8": "1", "GODOT_SILENCE_ROOT_WARNING": "1",
                                      "APPDATA": str(profile), "XDG_DATA_HOME": str(profile),
                                      "XDG_CONFIG_HOME": str(profile / "config")})
        output = process.stdout + process.stderr
        passed = process.returncode == 0 and not DIAGNOSTICS.search(output)
        match = re.search(success, output) if success else None
        if success and not match:
            passed = False
        detail = f"{match.group(1)} checks; exit 0" if match else f"exit {process.returncode}"
        if passed and not match:
            summaries = [line for line in output.splitlines() if re.match(r"(?:ARCHITECTURE|CONTENT|ARCHIVE) PASS:", line)]
            if summaries:
                detail = summaries[-1].split(":", 1)[1].strip()
        if DIAGNOSTICS.search(output):
            detail += "; unexpected engine diagnostics"
    except (OSError, subprocess.TimeoutExpired) as exc:
        output, passed, detail = str(exc), False, "launch failure/timeout"
    elapsed = (time.perf_counter() - started) * 1000.0
    (LOGS / log).write_text(output, encoding="utf-8")
    if not passed:
        print(f"\n--- {name} ---\n{output}", flush=True)
    return Result(name, "PASS" if passed else "FAIL", elapsed, detail)


def godot_binary() -> str | None:
    explicit = os.environ.get("GODOT_BIN")
    if explicit:
        candidate = Path(explicit).expanduser()
        return str(candidate.resolve()) if candidate.is_file() else shutil.which(explicit)
    return next((found for name in ("godot", "godot4", "godot4.6") if (found := shutil.which(name))), None)


def prepare_class_index() -> Result:
    """Bootstrap Godot's generated class-name cache without importing world assets."""
    started = time.perf_counter()
    classes: dict[str, dict] = {}
    try:
        for path in sorted((PROJECT / "scripts").rglob("*.gd")):
            source = path.read_text(encoding="utf-8-sig")
            if "class_name" not in source:
                continue
            tokens, lines = lex(source), source.splitlines()
            name, base = "", "RefCounted"
            for index, token in enumerate(tokens[:-1]):
                if token.kind != "identifier" or token.value not in {"class_name", "extends"}:
                    continue
                if not lines[token.line - 1].startswith(token.value + " "):
                    continue
                value = tokens[index + 1]
                if token.value == "class_name":
                    name = value.value
                else:
                    base = value.value
            if name:
                if name in classes:
                    raise ValueError("duplicate global class: " + name)
                classes[name] = {"base":base, "path":"res://" + path.relative_to(PROJECT).as_posix(),
                                 "is_tool":bool(re.search(r"(?m)^@tool\b", source)),
                                 "is_abstract":bool(re.search(r"(?m)^@abstract\b", source))}
        records = []
        for name, data in sorted(classes.items()):
            records.append('{"base": &' + json.dumps(data["base"]) + ', "class": &' + json.dumps(name)
                           + ', "icon": "", "language": &"GDScript", "path": ' + json.dumps(data["path"])
                           + ', "is_tool": ' + str(data["is_tool"]).lower()
                           + ', "is_abstract": ' + str(data["is_abstract"]).lower() + '}')
        cache = PROJECT / ".godot/global_script_class_cache.cfg"
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text("list=[\n" + ",\n".join(records) + "\n]\n", encoding="utf-8")
        return Result("GDScript class index", "PASS", (time.perf_counter() - started) * 1000.0,
                      f"{len(classes)} actual class declarations; no world import")
    except (ValueError, OSError) as exc:
        return Result("GDScript class index", "FAIL", (time.perf_counter() - started) * 1000.0, str(exc))


def import_ui(godot: str) -> Result:
    """Compile only the real UI resources used by the headless suites, not the game."""
    started = time.perf_counter()
    missing = [name for name in UI_SOURCES if not (PROJECT / name).is_file()]
    if missing:
        return Result("Headless UI imports", "FAIL", 0.0, "missing: " + ", ".join(missing))
    stamp = PROJECT / ".godot/phase5-ui-imports.json"
    hashes = {name: hashlib.sha256((PROJECT / name).read_bytes()).hexdigest() for name in UI_SOURCES}
    if stamp.is_file():
        try:
            cached = json.loads(stamp.read_text(encoding="utf-8"))
            files = cached["files"]
            if not isinstance(files, dict):
                raise ValueError("invalid UI import cache")
            safe = all(name in {source + ".import" for source in UI_SOURCES}
                       or name.startswith(".godot/imported/") and ".." not in Path(name).parts for name in files)
            if cached["sources"] == hashes and cached["godot"] == godot and files and safe and all(
                (PROJECT / name).is_file() and hashlib.sha256((PROJECT / name).read_bytes()).hexdigest() == digest
                for name, digest in files.items()
            ):
                return Result("Headless UI imports", "PASS", (time.perf_counter() - started) * 1000.0,
                              "4 hash-validated resource imports reused")
        except (ValueError, KeyError, TypeError, OSError):
            pass
    with tempfile.TemporaryDirectory(prefix="ui-import-", dir=LOGS) as directory:
        scratch = Path(directory)
        (scratch / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Ashen Oath headless UI imports"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        for name in UI_SOURCES:
            target = scratch / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(PROJECT / name, target)
        result = command("Headless UI imports", [godot, "--headless", "--editor", "--path", str(scratch), "--import"],
                         "ui_import.log")
        if result.status == "PASS":
            compiled: dict[str, str] = {}
            for name in UI_SOURCES:
                sidecar = scratch / (name + ".import")
                if not sidecar.is_file():
                    return Result(result.name, "FAIL", result.elapsed_ms, "no importer result: " + name)
                shutil.copy2(sidecar, PROJECT / (name + ".import"))
                compiled[name + ".import"] = hashlib.sha256(sidecar.read_bytes()).hexdigest()
            imports = PROJECT / ".godot/imported"
            imports.mkdir(parents=True, exist_ok=True)
            for source in (scratch / ".godot/imported").iterdir():
                if source.is_file():
                    shutil.copy2(source, imports / source.name)
                    compiled[".godot/imported/" + source.name] = hashlib.sha256(source.read_bytes()).hexdigest()
            stamp.write_text(json.dumps({"sources": hashes, "godot": godot, "files": compiled}, indent=2), encoding="utf-8")
        result.elapsed_ms = (time.perf_counter() - started) * 1000.0
        result.detail = "4 original UI resources; no game/world import" if result.status == "PASS" else result.detail
        return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-godot", action="store_true", help="fail instead of skipping headless suites without Godot")
    args = parser.parse_args()
    LOGS.mkdir(parents=True, exist_ok=True)
    started = time.perf_counter()
    results: list[Result] = []
    for name, script, flags, log in (
        ("Architecture rule self-tests", "check_architecture.py", ["--self-test"], "architecture_self_test.log"),
        ("Architecture ratchet", "check_architecture.py", [], "architecture.log"),
        ("JSON/schema + references", "check_content_integrity.py", [], "content_integrity.log"),
        ("Archive hashes + references", "check_archive_references.py", [], "archive_references.log"),
    ):
        results.append(command(name, [sys.executable, str(TOOLS / script), *flags], log))
    godot = godot_binary()
    if godot:
        version = command("Godot 4.6 runtime", [godot, "--headless", "--version"], "godot_version.log")
        if not re.match(r"4\.6(?:\.|\s|$)", (LOGS / "godot_version.log").read_text().strip()):
            version.status, version.detail = "FAIL", "requires Godot 4.6.x (pinned in CI)"
        results.append(version)
        if version.status == "PASS":
            indexed = prepare_class_index()
            results.append(indexed)
            imported = import_ui(godot)
            results.append(imported)
            if imported.status == "PASS" and indexed.status == "PASS":
                for name, script, success in SUITES:
                    results.append(command(name, [godot, "--headless", "--path", str(PROJECT), "-s", "res://tools/tests/" + script],
                                           script.removesuffix(".gd") + ".log", success))
    else:
        results.append(Result("Godot headless suites", "FAIL" if args.require_godot else "SKIP", 0.0,
                              "set GODOT_BIN or install Godot 4.6.x on PATH"))
    expected = {name for name, _, _ in SUITES}
    if godot and not expected.issubset({result.name for result in results}):
        results.append(Result("Five-suite completeness", "FAIL", 0.0, "suites blocked by failed runtime/resource preparation"))
    print("\nAshen Oath unified checks (headless simulation, not GPU/phone certification)")
    print(f"{'Suite / gate':31} | {'Result':6} | {'Wall ms':>10} | Details")
    print("-" * 107)
    for result in results:
        print(f"{result.name:31} | {result.status:6} | {result.elapsed_ms:10.3f} | {result.detail}")
    elapsed = (time.perf_counter() - started) * 1000.0
    failed = any(result.status == "FAIL" for result in results)
    (LOGS / "summary.json").write_text(json.dumps({"scope":"headless simulation; not GPU/phone/runtime acceptance",
        "passed":not failed, "elapsed_ms":elapsed, "results":[asdict(result) for result in results]}, indent=2) + "\n", encoding="utf-8")
    print(f"TOTAL {'FAIL' if failed else 'PASS'}: {elapsed:.3f} ms; logs: .release-gate/phase5/")
    for result in results:
        if result.name == "Phase 5: campaign replay":
            print((LOGS / "test_phase5_campaign_replay_benchmark.log").read_text().strip())
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
