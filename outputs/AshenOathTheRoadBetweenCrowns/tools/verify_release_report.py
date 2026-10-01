#!/usr/bin/env python3
"""Validate an Ashen Oath release report against current source and artifact.

The strict mode is used only for a milestone release. Targeted development
runs may keep a partial report while evidence is still being collected.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

from PIL import Image, ImageStat
from release_identity import HashCache, artifact_snapshot, harness_fingerprint, runtime_fingerprint
from visual_evidence import capture_identity_error, needs_input_digest, rendering_inputs_sha256, review_error


REQUIRED_SCREENSHOTS = {
    "01_greyfen_spawn",
    "05_sister_anwen_dialogue",
    "70_greyfen_river_bridge",
    "10_combat_clearing",
    "15_player_sword_ready",
    "13_player_light_attack_arc",
    "14_player_heavy_attack_arc",
    "73_combat_001_blade_contact",
    "36_vargan_approach",
    "38_record_hall",
    "41_white_hart_glade",
}

RELEASE_PHASE_EXCLUSIONS = {
    "candidate": {"CERT-001", "RELEASE-001"},
    "release": {"RELEASE-001"},
    "final": set(),
}
CURRENT_TICKET_STATUSES = {"accepted", "pending", "visually_rejected", "blocked", "deferred"}


def source_fingerprint(project: Path) -> str:
    # Compatibility alias retained for existing scripts. It now represents
    # runtime content only; harness and registry identities are independent.
    cache = HashCache(project / ".release-gate" / "release_identity_cache.json")
    value = runtime_fingerprint(project, cache)
    cache.save()
    return value


def git_value(repo: Path, *args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo), *args], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def fail(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def valid_owned_gate_result(result: dict[str, Any]) -> bool:
    process = result.get("process")
    return (
        isinstance(process, dict)
        and process.get("owner") == "release-runner"
        and type(process.get("exit_code")) is int
        and process["exit_code"] == 0
        and process.get("timed_out") is False
    )


def valid_gate_identity(identity: Any) -> bool:
    if not isinstance(identity, dict) or identity.get("protocol") != "release-gate-v4":
        return False
    contract = identity.get("contract")
    dependencies = contract.get("dependencies") if isinstance(contract, dict) else None
    if not isinstance(dependencies, list) or not dependencies:
        return False
    for dependency in dependencies:
        if not isinstance(dependency, dict):
            return False
        path = Path(str(dependency.get("path", "")))
        if not path.is_file():
            return False
        if hashlib.sha256(path.read_bytes()).hexdigest() != str(dependency.get("sha256", "")).lower():
            return False
    return True


def gate_set_differences(required: Any, results: Any) -> tuple[list[str], list[str]]:
    required_names = list(map(str, required)) if isinstance(required, list) else []
    result_names = [str(item.get("name", "")) for item in results if isinstance(item, dict)] if isinstance(results, list) else []
    missing = sorted(set(required_names) - set(result_names))
    duplicates = sorted({name for name in result_names if name and result_names.count(name) > 1})
    return missing, duplicates


def expected_registry_blockers(snapshot: dict[str, Any], phase: str) -> list[dict[str, str]]:
    excluded = RELEASE_PHASE_EXCLUSIONS.get(phase, set())
    return sorted(
        [
            item
            for item in snapshot.get("ticket_statuses", [])
            if item.get("status") != "accepted" and item.get("id") not in excluded
        ],
        key=lambda item: item["id"],
    )


def validate_artifact(project: Path, report: dict[str, Any], errors: list[str]) -> None:
    artifact = report.get("artifact")
    fail(errors, isinstance(artifact, dict), "report artifact snapshot is missing")
    if not isinstance(artifact, dict):
        return
    directory = Path(str(artifact.get("directory", "")))
    if not directory.is_absolute():
        directory = project.parent / directory
    fail(errors, directory.is_dir(), f"artifact directory is missing: {directory}")
    if not directory.is_dir():
        return
    actual_files = sorted(path for path in directory.rglob("*") if path.is_file())
    actual_by_relative = {
        path.relative_to(directory).as_posix(): path for path in actual_files
    }
    recorded = artifact.get("files", [])
    fail(errors, isinstance(recorded, list) and bool(recorded), "artifact file list is empty")
    recorded_by_path: dict[str, dict[str, Any]] = {}
    for item in recorded if isinstance(recorded, list) else []:
        if not isinstance(item, dict):
            errors.append("artifact file record is not an object")
            continue
        relative = str(item.get("path", ""))
        if not relative or relative in recorded_by_path:
            errors.append(f"artifact file record is invalid or duplicated: {relative}")
            continue
        recorded_by_path[relative] = item
        path = actual_by_relative.get(relative)
        fail(errors, path is not None, f"recorded artifact file is missing: {relative}")
        if path is None:
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        fail(errors, int(item.get("bytes", -1)) == path.stat().st_size, f"artifact size mismatch: {relative}")
        fail(errors, str(item.get("sha256", "")).lower() == digest, f"artifact hash mismatch: {relative}")
    fail(errors, set(recorded_by_path) == set(actual_by_relative), "artifact record does not match files on disk")
    total = sum(path.stat().st_size for path in actual_files)
    fail(errors, int(artifact.get("total_bytes", -1)) == total, "artifact total size is stale")
    fail(errors, total < int(artifact.get("max_bytes", 100 * 1024 * 1024)), f"artifact exceeds 100 MiB: {total} bytes")
    pck = actual_by_relative.get("index.pck")
    fail(errors, pck is not None, "artifact has no root index.pck")
    if pck is not None:
        fail(errors, str(artifact.get("pck_sha256", "")).lower() == hashlib.sha256(pck.read_bytes()).hexdigest(), "root PCK hash is stale")
    actual_identity = artifact_snapshot(directory)
    fail(errors, artifact.get("fingerprint") == actual_identity["fingerprint"], "artifact fingerprint is stale")


def validate_export_provenance(report: dict[str, Any], errors: list[str]) -> None:
    artifact = report.get("artifact")
    provenance = artifact.get("export_provenance") if isinstance(artifact, dict) else None
    if not isinstance(provenance, dict):
        errors.append("strict report has no export-time source provenance")
        return
    if provenance.get("binding_origin") == "preserved_v10_export_and_capture":
        fail(errors, report.get("acceptance_profile") == "functional_candidate",
             "preserved V10 binding cannot substitute for strict export-time provenance")
        project = Path(report.get("evidence_project", ""))
        fail(errors, project.is_dir() and provenance.get("rendering_inputs_sha256") == rendering_inputs_sha256(project),
             "preserved export's captured runtime inputs changed")
        log = Path(str(provenance.get("export_log", "")))
        fail(errors, log.is_file(), "preserved export log is missing")
        if log.is_file():
            fail(errors, hashlib.sha256(log.read_bytes()).hexdigest() == provenance.get("export_log_sha256"),
                 "preserved export log changed")
            fail(errors, f"WEB EXPORT PCK SHA256: {artifact.get('pck_sha256')}" in log.read_text(errors="replace"),
                 "preserved export log does not identify these bytes")
    fail(
        errors,
        bool(provenance.get("runtime_content_fingerprint"))
        and provenance.get("runtime_content_fingerprint") == report.get("runtime_content_fingerprint"),
        "exported Web bytes do not match the report source fingerprint",
    )
    fail(
        errors,
        bool(provenance.get("pck_sha256"))
        and provenance.get("pck_sha256") == artifact.get("pck_sha256"),
        "export-time root PCK hash does not match the report artifact",
    )
    files = artifact.get("files")
    exported_files = provenance.get("files")
    fail(
        errors,
        isinstance(files, list) and bool(files) and exported_files == files,
        "Web files differ from the export-time artifact snapshot",
    )


def validate_revision_identity(
    report: dict[str, Any], repo: Path, head: str, runtime: str, harness: str,
    errors: list[str],
) -> None:
    source_commit = str(report.get("source_commit", ""))
    canonical = len(source_commit) in (40, 64) and all(char in "0123456789abcdef" for char in source_commit)
    fail(errors, bool(head), "current Git HEAD is unavailable")
    fail(errors, canonical and git_value(repo, "cat-file", "-t", source_commit) == "commit",
         "report source commit is not a valid canonical Git commit")
    if head and canonical and source_commit != head:
        fail(errors, git_value(repo, "merge-base", source_commit, head) == source_commit,
             "report source commit is not an ancestor of current HEAD")
    # A dirty candidate's tested bytes may be committed after certification.
    # Commit-path changes do not invalidate identical content; changed bytes do.
    fail(errors, bool(runtime) and report.get("runtime_content_fingerprint") == runtime,
         "report runtime-content fingerprint is stale")
    fail(errors, bool(runtime) and report.get("source_fingerprint") == runtime,
         "report source compatibility fingerprint is stale")
    fail(errors, bool(harness) and report.get("test_harness_fingerprint") == harness,
         "report test-harness fingerprint is stale")


def validate_worktree_state(report: dict[str, Any], errors: list[str], strict: bool) -> None:
    if not strict:
        return
    status = report.get("git_status")
    fail(errors, isinstance(status, list), "strict report has no worktree status")
    # Certification binds dirty source to its exact content/export fingerprints.
    # Promotion still requires a clean committed worktree.
    if report.get("release_phase") != "candidate":
        fail(errors, isinstance(status, list) and not status,
             "strict release report was generated from a dirty worktree")


def current_registry_snapshot(project: Path) -> tuple[dict[str, Any] | None, str, str | None]:
    path = project / "RECOVERY_004_ISSUE_REGISTRY.json"
    try:
        raw = path.read_bytes()
        registry = json.loads(raw.decode("utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        return None, "", str(error)
    category_statuses = sorted(
        [
            {
                "id": str(item.get("id", "")),
                "severity": str(item.get("severity", "")),
                "status": str(item.get("status", "")),
            }
            for item in registry.get("categories", [])
            if isinstance(item, dict)
        ],
        key=lambda item: item["id"],
    )
    acceptance = registry.get("current_program", {}).get("acceptance")
    if not isinstance(acceptance, dict) or not acceptance or any(
        not isinstance(key, str) or not key or not isinstance(value, str)
        for key, value in acceptance.items()
    ):
        return None, "", "current recovery ticket acceptance map is missing or malformed"
    invalid_statuses = sorted({value for value in acceptance.values() if value not in CURRENT_TICKET_STATUSES})
    if invalid_statuses:
        return None, "", f"current recovery ticket acceptance has invalid statuses: {invalid_statuses}"
    ticket_statuses = [
        {"id": key, "severity": "blocker", "status": value}
        for key, value in sorted(acceptance.items())
    ]
    snapshot = {
        "path": path.name,
        "exists": True,
        "sha256": hashlib.sha256(raw).hexdigest(),
        "schema_version": int(registry.get("schema_version", 0)),
        "registry_id": str(registry.get("registry_id", "")),
        "category_statuses": category_statuses,
        "ticket_statuses": ticket_statuses,
    }
    return snapshot, snapshot["sha256"], None


def validate_registry(project: Path, report: dict[str, Any], errors: list[str]) -> None:
    current, digest, read_error = current_registry_snapshot(project)
    fail(errors, current is not None, f"issue registry is unreadable: {read_error or 'unknown error'}")
    recorded = report.get("issue_registry")
    fail(errors, isinstance(recorded, dict), "report issue registry snapshot is missing")
    if current is None or not isinstance(recorded, dict):
        return
    fail(errors, recorded.get("exists") is True, "report issue registry snapshot is not present")
    fail(errors, str(recorded.get("sha256", "")).lower() == digest, "issue registry snapshot is stale")
    fail(errors, recorded.get("schema_version") == current.get("schema_version"), "issue registry schema is stale")
    fail(errors, recorded.get("registry_id") == current.get("registry_id"), "issue registry identity is stale")
    for key, message in (("category_statuses", "issue registry category statuses are stale"),
                         ("ticket_statuses", "current ticket acceptance snapshot is stale or missing")):
        entries = recorded.get(key)
        normalized = sorted(entries, key=lambda item: str(item.get("id", ""))) if isinstance(entries, list) else None
        fail(errors, normalized == current.get(key), message)
    phase = str(report.get("release_phase", ""))
    fail(errors, phase in RELEASE_PHASE_EXCLUSIONS, f"release phase is invalid: {phase}")
    expected_blockers = expected_registry_blockers(current, phase)
    actual_blockers = report.get("release_blockers", [])
    fail(errors, isinstance(actual_blockers, list), "report release blockers are not a list")
    if isinstance(actual_blockers, list):
        normalized = sorted(
            [
                {
                    "id": str(item.get("id", "")),
                    "severity": str(item.get("severity", "")),
                    "status": str(item.get("status", "")),
                }
                for item in actual_blockers
                if isinstance(item, dict)
            ],
            key=lambda item: item["id"],
        )
        fail(errors, normalized == expected_blockers, "report release blockers do not match the current issue registry")


def validate_screenshots(project: Path, report: dict[str, Any], errors: list[str], strict: bool) -> None:
    gallery = project / "Development_Gallery" / "screenshots"
    fail(errors, gallery.is_dir(), f"screenshot gallery is missing: {gallery}")
    if not gallery.is_dir() or not strict:
        return
    approval_path = project / "Development_Gallery" / "qa_003_approval_manifest.json"
    try:
        approval = json.loads(approval_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"strict screenshot approval manifest is unreadable: {error}")
        return
    policy = approval.get("policy", {})
    fail(errors, isinstance(policy, dict) and policy.get("visual_review") == "codex", "strict screenshot policy is not Codex-reviewed")
    views = approval.get("views", [])
    current_rendering_digest = rendering_inputs_sha256(project) if needs_input_digest(gallery, views) else ""
    view_by_id = {
        str(item.get("id")): item
        for item in views
        if isinstance(item, dict) and item.get("id")
    }
    source_roots = (project / "scripts", project / "scenes", project / "data")
    source_files = [project / "project.godot"]
    source_files.extend(
        path
        for root in source_roots
        if root.is_dir()
        for path in root.rglob("*")
        if path.is_file()
    )
    source_mtime = max(
        (path.stat().st_mtime for path in source_files if path.is_file()),
        default=0.0,
    )
    listed = report.get("screenshots", {})
    fail(errors, isinstance(listed, dict), "strict report has no screenshot evidence map")
    capture_revision = str(approval.get("capture_source_revision", ""))
    current_revision = git_value(project.parent.parent, "rev-parse", "HEAD")
    # A documentation-only checkpoint must not invalidate identical rendered
    # inputs. Each PNG's source/asset identity is checked below instead.
    fail(errors, bool(capture_revision), "screenshot capture revision is missing")
    for stem in REQUIRED_SCREENSHOTS:
        matching_views = [
            item
            for item in view_by_id.values()
            if bool(item.get("required")) and stem in str(item.get("current_glob", ""))
        ]
        fail(errors, len(matching_views) == 1, f"required screenshot is not uniquely mapped in approval manifest: {stem}")
        if len(matching_views) != 1:
            continue
        view = matching_views[0]
        view_id = str(view.get("id"))
        fail(errors, str(view.get("status", "")) == "approved", f"screenshot is not approved: {view_id}")
        fail(errors, "codex" in str(view.get("reviewer", "")).lower(), f"screenshot reviewer is not Codex: {view_id}")
        expected_size = view.get("expected_size", [1280, 720])
        heuristics = view.get("heuristics", {})
        candidates = sorted(
            gallery.glob(str(view.get("current_glob", f"*{stem}*.png"))),
            key=lambda path: path.stat().st_mtime if path.exists() else 0.0,
            reverse=True,
        )
        fail(errors, bool(candidates), f"required screenshot is missing: {view_id}")
        if not candidates:
            continue
        image = candidates[0]
        if current_rendering_digest:
            identity_error = capture_identity_error(image, current_rendering_digest)
            fail(errors, identity_error is None, f"screenshot capture identity failed: {view_id}: {identity_error}")
        elif view.get("status") == "approved":
            errors.append(f"screenshot capture identity is unverified; approval is ineligible: {view_id}")
        semantic_error = review_error(view)
        fail(errors, semantic_error is None, f"screenshot semantic review failed: {view_id}: {semantic_error}")
        approved_sha256 = str(view.get("approved_sha256", ""))
        fail(errors, len(approved_sha256) == 64 and all(char in "0123456789abcdef" for char in approved_sha256), f"screenshot has no valid reviewed-image SHA-256: {view_id}")
        if len(approved_sha256) == 64:
            fail(errors, hashlib.sha256(image.read_bytes()).hexdigest() == approved_sha256, f"screenshot bytes changed since visual approval: {view_id}")
        fail(errors, image.stat().st_size >= 4096, f"screenshot is blank or corrupt: {image.name}")
        evidence = listed.get(view_id) if isinstance(listed, dict) else None
        fail(errors, isinstance(evidence, dict), f"strict report has no evidence for screenshot: {view_id}")
        if not isinstance(evidence, dict):
            continue
        fail(errors, str(evidence.get("status", "")) == "approved", f"report screenshot is not approved: {view_id}")
        evidence_image = Path(str(evidence.get("image", "")))
        if not evidence_image.is_absolute():
            evidence_image = project / evidence_image
        try:
            evidence_image = evidence_image.resolve()
            evidence_image.relative_to(gallery.resolve())
            inside_gallery = True
        except (OSError, ValueError):
            inside_gallery = False
        fail(errors, inside_gallery, f"report screenshot is outside the gallery: {view_id}")
        fail(errors, evidence_image == image.resolve(), f"report screenshot is not the newest approved capture: {view_id}")
        try:
            with Image.open(image) as opened:
                rgb = opened.convert("RGB")
                width, height = rgb.size
                stats = ImageStat.Stat(rgb)
                mean_luminance = sum(stats.mean) / 3.0
                max_channel_variance = max(stats.var)
                pixels = list(rgb.getdata())
                bright_ratio = sum(1 for red, green, blue in pixels if min(red, green, blue) >= 250) / max(1, len(pixels))
                fail(errors, [width, height] == list(expected_size), f"screenshot dimensions are invalid: {view_id} ({width}x{height})")
                fail(errors, mean_luminance >= float(heuristics.get("min_mean_luminance", 1.5)), f"screenshot exposure is too dark: {view_id}")
                fail(errors, max_channel_variance >= float(heuristics.get("min_channel_variance", 4.0)), f"screenshot has no visible variance: {view_id}")
                fail(errors, bright_ratio <= float(heuristics.get("max_bright_ratio", 0.985)), f"screenshot is overexposed: {view_id}")
        except (OSError, ValueError, TypeError) as error:
            errors.append(f"screenshot pixels could not be inspected: {view_id}: {error}")


def check_functional_evidence(project: Path, bundle_path: Path) -> int:
    """Aggregate the approved lean scope without rerunning unchanged gameplay."""
    errors: list[str] = []
    bundle = json.loads(bundle_path.read_text(encoding="utf-8-sig"))
    fail(errors, bundle.get("acceptance_profile") == "functional_candidate", "evidence profile is not explicit")
    fail(errors, bundle.get("browser_certification_scope") == "lean_functional_smoke", "browser scope is not lean")
    fail(errors, bundle.get("exhaustive_browser_campaign_certified") is False, "omitted coverage is not disclosed")
    fail(errors, bundle.get("listening_reviewed") is False, "unreviewed listening is not disclosed")
    identity = artifact_snapshot(Path(bundle["artifact_directory"]))
    pck_sha256 = next((item["sha256"] for item in identity["files"] if item["path"] == "index.pck"), "")
    fail(errors, pck_sha256 == bundle.get("pck_sha256"), "preserved PCK identity differs")
    fail(errors, identity["fingerprint"] == bundle.get("artifact_fingerprint"), "preserved artifact identity differs")
    digest = rendering_inputs_sha256(project)
    fail(errors, digest == bundle.get("rendering_inputs_sha256"), "captured V10 runtime inputs changed")
    visual = json.loads(Path(bundle["visual_report"]).read_text(encoding="utf-8-sig"))
    fail(errors, visual.get("status") == "pass" and visual.get("rendering_inputs_sha256") == digest,
         "current-source visual report is absent or stale")
    measured = json.loads(Path(bundle["native_measurements"]).read_text(encoding="utf-8-sig"))
    fail(errors, measured.get("status") == "pass" and measured.get("acceptance_profile") == "functional_candidate"
         and measured.get("performance_certified") is False and bool(measured.get("target_misses"))
         and bool(measured.get("zones")) and bool(measured.get("transitions")), "native measurements are incomplete")
    memory = json.loads(Path(bundle["native_owned_memory"]).read_text(encoding="utf-8-sig"))
    fail(errors, memory.get("exit_code") == 0 and memory.get("watchdog_timeout") is False
         and memory.get("sample_count", 0) > 0 and memory.get("peak_private_bytes", 0) > 0
         and memory.get("artifact_pck_sha256") == pck_sha256
         and not str(memory.get("executable", "")).endswith("_console.exe"), "owned native runtime measurement is invalid")
    required_logs = {"packed_startup", "native_performance", "audio_sync", "audio_combat", "audio_parry", "native_main_route"}
    logs = bundle.get("native_logs", {})
    fail(errors, set(logs) == required_logs, "mandatory scoped native evidence is missing")
    fatal = re.compile(r"SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot open|ERROR:|RID allocations .* leaked at exit|ObjectDB instances leaked at exit|Parameter \"material\" is null")
    for name, entry in logs.items():
        stdout, stderr = Path(entry["stdout"]), Path(entry["stderr"])
        text = stdout.read_text(errors="replace")
        diagnostics = text + stderr.read_text(errors="replace")
        fail(errors, entry.get("required_marker", "MISSING") in text, f"{name} has no successful scoped result")
        fail(errors, not fatal.search(diagnostics), f"{name} has an unclassified runtime error")
        fail(errors, bool(entry.get("scope")), f"{name} reuse scope is missing")
    required_records = {"story", "world_opening", "world_campaign", "presentation", "audio", "accessibility"}
    records = bundle.get("retained_records", {})
    fail(errors, set(records) == required_records, "retained acceptance records are incomplete")
    for name, value in records.items():
        paths = [project / item for item in value]
        fail(errors, bool(paths) and all(path.is_file() and path.stat().st_size > 0 for path in paths),
             f"{name} scoped acceptance record is missing")
    for error in errors:
        print(f"FUNCTIONAL EVIDENCE: FAIL - {error}")
    if errors:
        return 1
    print("FUNCTIONAL EVIDENCE: PASS - preserved V10 native/visual evidence, current measurements and explicit lean scope")
    print("CHECK: no claim of exhaustive browser campaign, strict performance certification or listening approval")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--acceptance-profile", choices=("strict", "functional_candidate"), default="strict")
    parser.add_argument("--print-source-fingerprint", action="store_true")
    parser.add_argument("--print-runtime-fingerprint", action="store_true")
    parser.add_argument("--print-harness-fingerprint", action="store_true")
    parser.add_argument("--check-functional-evidence", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    if args.check_functional_evidence:
        return check_functional_evidence(project, args.check_functional_evidence)
    if args.print_source_fingerprint or args.print_runtime_fingerprint:
        print(source_fingerprint(project))
        return 0
    if args.print_harness_fingerprint:
        print(harness_fingerprint(project))
        return 0
    report_path = (args.report or project / "release_reports" / "latest.json").resolve()
    errors: list[str] = []
    try:
        report = json.loads(report_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"RELEASE REPORT: FAIL - {error}")
        return 1
    fail(errors, int(report.get("schema_version", 0)) >= 4, "report schema must be version 4 or newer")
    fail(errors, report.get("acceptance_profile", "strict") == args.acceptance_profile, "acceptance profile is missing or mismatched")
    if args.acceptance_profile == "functional_candidate":
        fail(errors, report.get("performance_certified") is False, "functional candidate must not claim numerical performance certification")
        fail(errors, report.get("listening_reviewed") is False, "unreviewed mix must be explicitly disclosed")
        fail(errors, report.get("release_basis") == "functionality-certified candidate", "functional release basis is missing")
    fail(errors, bool(str(report.get("report_id", ""))), "report id is missing")
    allowed_statuses = {"pass"} if args.strict else {"pass", "partial-pass"}
    fail(errors, str(report.get("status", "")) in allowed_statuses, "report status is not a release pass")
    repo = project.parent.parent
    head = git_value(repo, "rev-parse", "HEAD")
    source_commit = str(report.get("source_commit", ""))
    current_runtime_fingerprint = source_fingerprint(project)
    current_harness_fingerprint = harness_fingerprint(project)
    validate_revision_identity(report, repo, head, current_runtime_fingerprint, current_harness_fingerprint, errors)
    revision = report.get("verification_revision")
    fail(errors, isinstance(revision, dict), "report verification revision is missing")
    if isinstance(revision, dict):
        fail(errors, revision.get("source_commit") == source_commit, "verification revision source commit is stale")
        fail(errors, revision.get("runtime_content_fingerprint") == report.get("runtime_content_fingerprint"), "verification runtime-content fingerprint is stale")
        fail(errors, revision.get("test_harness_fingerprint") == report.get("test_harness_fingerprint"), "verification test-harness fingerprint is stale")
        fail(errors, revision.get("execution_fingerprint") == report.get("execution_fingerprint"), "verification execution fingerprint is stale")
    validate_worktree_state(report, errors, args.strict)
    blockers = report.get("release_blockers", [])
    fail(errors, isinstance(blockers, list), "release blockers are not a list")
    if args.strict or str(report.get("status", "")) == "pass":
        fail(errors, isinstance(blockers, list) and not blockers, "release blockers remain")
    else:
        fail(errors, isinstance(blockers, list) and bool(blockers), "partial report does not identify its release blockers")
    validate_registry(project, report, errors)
    results = report.get("results", [])
    fail(errors, isinstance(results, list) and bool(results), "report has no gate results")
    required_gates = report.get("required_gates", [])
    if args.strict:
        fail(errors, isinstance(required_gates, list) and bool(required_gates), "strict report has no mandatory gate set")
        if isinstance(required_gates, list):
            missing, duplicates = gate_set_differences(required_gates, results)
            fail(errors, not missing, f"strict report is missing mandatory gates: {missing}")
            fail(errors, not duplicates, f"strict report has duplicate gate results: {duplicates}")
    for result in results if isinstance(results, list) else []:
        if not isinstance(result, dict) or not result.get("name") or not result.get("log") or str(result.get("status", "")) != "pass":
            errors.append(f"non-passing gate in report: {result}")
            continue
        if args.strict:
            fail(errors, isinstance(result.get("assertions"), list) and bool(result["assertions"]),
                 f"{result['name']} lacks assertion evidence")
            fail(errors, isinstance(result.get("warnings"), list), f"{result['name']} lacks warning evidence field")
            fail(errors, isinstance(result.get("runtime_phase"), str) and bool(result["runtime_phase"]),
                 f"{result['name']} lacks runtime phase")
            fail(
                errors,
                valid_owned_gate_result(result),
                f"{result['name']} lacks a successful owned-process exit",
            )
            identities = result.get("identities")
            fail(errors, isinstance(identities, dict), f"{result['name']} lacks gate identities")
            if isinstance(identities, dict):
                fail(errors, identities.get("runtime_content") == report.get("runtime_content_fingerprint"), f"{result['name']} runtime identity is stale")
                fail(errors, valid_gate_identity(identities.get("gate")), f"{result['name']} gate-harness identity is stale")
                fail(errors, identities.get("execution") == report.get("execution_fingerprint"), f"{result['name']} execution identity is stale")
                recorded_artifact = str(identities.get("artifact", ""))
                if recorded_artifact:
                    fail(errors, recorded_artifact == report.get("artifact", {}).get("fingerprint"), f"{result['name']} artifact identity is stale")
    validate_artifact(project, report, errors)
    if args.strict:
        validate_export_provenance(report, errors)
    validate_screenshots(project, report, errors, args.strict)
    if errors:
        for error in errors:
            print(f"RELEASE REPORT: FAIL - {error}")
        return 1
    identity = "export provenance verified" if args.strict else "artifact and source fingerprints verified independently"
    print(f"RELEASE REPORT: PASS - schema {report['schema_version']}, {len(results)} gate(s), {identity}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
