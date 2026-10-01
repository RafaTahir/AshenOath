"""Snapshot existing recovery evidence without running or approving any gate."""
from __future__ import annotations

import hashlib
import json
import uuid
import argparse
from datetime import datetime, timezone
from pathlib import Path

from release_identity import artifact_snapshot as release_artifact_snapshot, harness_fingerprint
from verify_release_report import current_registry_snapshot, git_value, source_fingerprint


def artifact_snapshot(directory: Path) -> dict:
    identity = release_artifact_snapshot(directory)
    pck = next((item for item in identity["files"] if item["path"] == "index.pck"), None)
    return {
        "directory": str(directory),
        "fingerprint": identity["fingerprint"],
        "total_bytes": identity["total_bytes"],
        "files": identity["files"],
        "pck_sha256": str(pck["sha256"]) if pck else "",
        "max_bytes": 100 * 1024 * 1024,
    }


def snapshot(project: Path) -> dict:
    registry_path = project / "RECOVERY_004_ISSUE_REGISTRY.json"
    raw = registry_path.read_bytes()
    program = json.loads(raw)["current_program"]
    registry, registry_digest, registry_error = current_registry_snapshot(project)
    if registry is None:
        raise RuntimeError(f"issue registry is unreadable: {registry_error or 'unknown error'}")
    artifact_directory = project.parent / ".release-gate/AshenOath_QA"
    if not artifact_directory.is_dir():
        raise RuntimeError(f"current QA artifact is missing: {artifact_directory}")
    performance = {
        "status": "failed_native_diagnostic_not_acceptance",
        "current_full_native_log": "D:/Temp/AshenOath/perf_gate_reuse_full_native.log",
        "current_full_greyfen_hydration_average_fps": 48.97,
        "current_full_greyfen_hydration_one_percent_low_fps": 20.90,
        "current_draw_disabled_log": "D:/Temp/AshenOath/perf_current_draw_disabled_20260925.log",
        "current_draw_disabled_hydration_average_fps": 58.85,
        "current_draw_disabled_hydration_one_percent_low_fps": 15.62,
        "current_draw_disabled_draw_calls": 0,
        "greyfen_bank_candidate_log": "D:/Temp/AshenOath/pres001_bank_candidate_perf.log",
        "greyfen_bank_candidate_hydration_average_fps": 57.53,
        "greyfen_bank_candidate_hydration_one_percent_low_fps": 29.95,
        "greyfen_bank_candidate_status": "failed_targeted_native_not_acceptance",
        "rejected_publication_ab_logs": [
            "D:/Temp/AshenOath/perf_publication_ab_a1.log",
            "D:/Temp/AshenOath/perf_publication_ab_b1.log",
            "D:/Temp/AshenOath/perf_publication_ab_a2.log",
            "D:/Temp/AshenOath/perf_publication_ab_b2.log",
        ],
        "visible_repeat_log": "D:/Temp/AshenOath/perf_visible_discriminant_20260924.log",
        "viewport_discriminant_log": "D:/Temp/AshenOath/perf_viewport_discriminant_20260924.log",
        "visibility_revisit_log": "D:/Temp/AshenOath/perf_visibility_revisit_20260924.log",
        "offscreen_prewarm_log": "D:/Temp/AshenOath/perf_offscreen_prewarm_20260924_v2.log",
        "persistent_batch_trial_log": "D:/Temp/AshenOath/perf_persistent_pool_first_native.log",
        "visible_hydration_one_percent_low_fps": [13.71, 22.62],
        "first_visible_frame_ms_after_suspended_hydration": [165.5, 179.7],
        "stable_scene_revisit_first_visible_ms": 19.08,
        "offscreen_prewarm_hydration_one_percent_low_fps": 20.33,
        "persistent_batch_trial_one_percent_low_fps": [11.55, 15.29],
    }
    evidence = []
    for name in (
        "animation_timer_rate.log", "animation_timer_motion.log",
        "prepared_audio_source_resolution.log", "prepared_audio_runtime.log",
        "greyfen_timer_serial_perf.log", "greyfen_crow_budget_perf.log",
        "greyfen_combined_readiness_perf.log", "material_headed_chrome.json",
        "moving_opening_hydration_cleanup.log", "material_prewarm_retirement_preloaded.log",
        "incremental_lighting.log", "incremental_lighting_game_parser.log",
        "greyfen_incremental_lighting_perf.log",
        "night_pool_state.log", "night_pool_batch.log", "night_pool_capture.log",
        "star_material_isolation.log", "star_validator_regression.log",
        "sky_state_final.log", "sky_stars_final.log", "sky_final_capture.log",
        "back_sword_parser.log", "back_sword_capture.log", "back_sword_placement.log",
        "guard_pose_capture.log", "guard_input_draw_capture.log",
        "blade_contact_distance.log", "blade_strike_window.log", "blade_game_parser.log",
        "animated_blade_contact_settled.log",
        "animation_rate_ownership_final.log", "animated_blade_final.log",
        "shared_animation_after_rate.log", "animation_timer_after_rate.log",
        "animation_rate_steps.log", "parry_requires_contact.log",
        "enemy_contact_bone.log",
        "enemy_contact_probe_units_final.log", "enemy_attack_probe_corrected.log",
        "enemy_timed_contact_final.log", "parry_after_enemy_timing.log",
        "enemy_contact_rate_matrix_final.log",
        "rendered_enemy_parry_guard.log",
        "rendered_enemy_impact_settled.log",
        "enemy_cpu_grounded_matrix.log", "enemy_cpu_gpu_bounds.log",
        "enemy_all_posed_bounds.log",
        "held_guard_contact.log",
        "front_guard_contract.log",
        "guard_release_matrix.log",
        "dialogue_coordinator_native_v1.log",
        "combat_vfx_coordinator_native_v3.log",
        "combat_vfx_oath_render_v1.log",
        "interaction_visibility_native_v1.log",
        "architecture_anwen_focus_v2.log",
        "quest_hud_coordinator_native_v1.log",
        "architecture_objective_runtime_v1.log",
        "architecture_residency_unit_v1.log",
        "architecture_transition_parse_v2.log",
        "architecture_lifecycle_v1.log",
        "architecture_rollback_before_v1.log",
        "architecture_rollback_after_v2.log",
        "architecture_opening_final_v1.log",
        "arch002_touch_unit_context_v1.log",
        "arch002_life_unit_final_v2.log",
        "arch002_life_logic_v1.log",
        "arch002_life_graphical_v1.log",
        "arch002_mobile_context_v2.log",
        "arch002_opening_final_v1.log",
        "edric_render_warmup_v1.log",
        "edric_compelled_foreground_v1.log",
    ):
        path = Path("D:/Temp/AshenOath") / name
        item = {"path": str(path), "exists": path.is_file(),
                "acceptance": "not_inferred_from_file_presence"}
        if path.is_file():
            data = path.read_bytes()
            item.update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                        modified_at=datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat())
        evidence.append(item)
    for path in (
        Path("D:/Temp/AshenOath/handoff_checkpoint/load001_character_material_budget_native_v2.log"),
        Path("D:/Temp/AshenOath/handoff_checkpoint/res001_startup_finalize_v86.log"),
        Path("D:/Temp/AshenOath/handoff_checkpoint/res001_engine004_verbose_v86.log"),
        Path("D:/Temp/AshenOath/handoff_checkpoint/spat001_contract_v2.log"),
        Path("D:/Temp/AshenOath/handoff_checkpoint/spat001_river.log"),
        Path("D:/Temp/AshenOath/handoff_checkpoint/spat001_navigation.log"),
        Path("D:/Temp/AshenOath/handoff_checkpoint/spat002_recovery_v3.log"),
        Path("D:/Temp/AshenOath/handoff_checkpoint/spat002_deferred_restore.log"),
        Path("D:/Temp/AshenOath/handoff_checkpoint/spat002_navigation.log"),
        Path("D:/Temp/AshenOath/recovery004_character_budget_v86/chrome_opening_v86.json"),
        Path("D:/Temp/AshenOath/recovery004_catalog_v83/edge_opening_v83.json"),
        Path("D:/Temp/AshenOath/ui001_chrome_allpages.json"),
        Path("D:/Temp/AshenOath/ui001_edge_allpages.json"),
        Path("D:/Temp/AshenOath/save001_chrome_clicksave.json"),
        Path("D:/Temp/AshenOath/save001_edge_clicksave.json"),
        Path("D:/Temp/AshenOath/save001_chrome_auto45.json"),
        Path("D:/Temp/AshenOath/save001_edge_auto45.json"),
        Path("D:/Temp/AshenOath/perf_visible_discriminant_20260924.log"),
        Path("D:/Temp/AshenOath/perf_viewport_discriminant_20260924.log"),
        Path("D:/Temp/AshenOath/perf_visibility_revisit_20260924.log"),
        Path("D:/Temp/AshenOath/perf_offscreen_prewarm_20260924_v2.log"),
        Path("D:/Temp/AshenOath/perf_persistent_pool_first_native.log"),
        Path("D:/Temp/AshenOath/perf_gate_reuse_full_native.log"),
        Path("D:/Temp/AshenOath/perf_current_draw_disabled_20260925.log"),
        Path("D:/Temp/AshenOath/pres001_layer_owner_20260925.log"),
        Path("D:/Temp/AshenOath/pres001_layer_owner_20260925/greyfen_bank_candidate.png"),
        Path("D:/Temp/AshenOath/pres001_bank_candidate_water.log"),
        Path("D:/Temp/AshenOath/pres001_bank_candidate_perf.log"),
        Path("D:/Temp/AshenOath/perf_tree_batch_greyfen.log"),
        Path("D:/Temp/AshenOath/perf_publication_ab_a1.log"),
        Path("D:/Temp/AshenOath/perf_publication_ab_b1.log"),
        Path("D:/Temp/AshenOath/perf_publication_ab_a2.log"),
        Path("D:/Temp/AshenOath/perf_publication_ab_b2.log"),
        Path("D:/Temp/AshenOath/opening_real_input_native_v8.log"),
        Path("D:/Temp/AshenOath/opening_real_input_native_v15.log"),
        Path("D:/Temp/AshenOath/cemetery_continue_v6.log"),
        Path("D:/Temp/AshenOath/grouped_focus_unit_v2.log"),
        Path("D:/Temp/AshenOath/quest_focus_regression.log"),
        Path("D:/Temp/AshenOath/cemetery_stage_regression.log"),
        Path("D:/Temp/AshenOath/cemetery_ambush_native_v2.log"),
        Path("D:/Temp/AshenOath/cemetery_chapel_native_v2.log"),
        Path("D:/Temp/AshenOath/cemetery_shrine_native_v2.log"),
        Path("D:/Temp/AshenOath/cemetery_shrine_input_v2.log"),
        Path("D:/Temp/AshenOath/quest_completion_checkpoint_v2.log"),
        Path("D:/Temp/AshenOath/cemetery_shrine_checkpoint_fixed.log"),
        Path("D:/Temp/AshenOath/teeth_mira_focus_diagnostic.log"),
        Path("D:/Temp/AshenOath/teeth_chapel_native_v2.log"),
        Path("D:/Temp/AshenOath/anwen_dialogue_stage_v1.log"),
        Path("D:/Temp/AshenOath/quest_runtime_after_mira.log"),
        Path("D:/Temp/AshenOath/grouped_focus_after_mira.log"),
        Path("D:/Temp/AshenOath/opening_real_input_native_return_diag.log"),
        Path("D:/Temp/AshenOath/audio001_wood_verifier_clean.log"),
        Path("D:/Temp/AshenOath/audio001_wood_graphical.log"),
        Path("D:/Temp/AshenOath/audio001_loop_import.log"),
        Path("D:/Temp/AshenOath/audio001_loop_runtime.log"),
        Path("D:/Temp/AshenOath/audio001_loop_graphical.log"),
        Path("D:/Temp/AshenOath/audio001_loop_import_repeat.log"),
        Path("D:/Temp/AshenOath/world002_archive_capture_20260924.log"),
    ):
        item = {"path": str(path), "exists": path.is_file(),
                "acceptance": "not_inferred_from_file_presence"}
        if path.is_file():
            data = path.read_bytes()
            item.update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                        modified_at=datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat())
        evidence.append(item)
    ticket_blockers = [
        item for item in registry["ticket_statuses"]
        if item["status"] != "accepted" and item["id"] not in {"CERT-001", "RELEASE-001"}
    ]
    release_blockers = sorted(ticket_blockers, key=lambda item: item["id"])
    commit = git_value(project.parent.parent, "rev-parse", "HEAD")
    fingerprint = source_fingerprint(project)
    harness = harness_fingerprint(project)
    observed_at = datetime.now(timezone.utc).isoformat()
    artifact = artifact_snapshot(artifact_directory)
    pck = artifact_directory / "index.pck"
    runtime_sources = (
        project / "scripts/zones/castle_vargan_section.gd",
        project / "scripts/game.gd",
        project / "scripts/audio_manager.gd",
        project / "assets_external/audio/authored/wood_step.ogg",
    )
    artifact["source_alignment"] = (
        "stale_after_runtime_source_change"
        if any(path.stat().st_mtime > pck.stat().st_mtime for path in runtime_sources)
        else "unproven_without_export_source_fingerprint"
    )
    browser_reports = (
        Path("D:/Temp/AshenOath/ui001_chrome_allpages.json"),
        Path("D:/Temp/AshenOath/ui001_edge_allpages.json"),
        Path("D:/Temp/AshenOath/save001_chrome_clicksave.json"),
        Path("D:/Temp/AshenOath/save001_edge_clicksave.json"),
        Path("D:/Temp/AshenOath/save001_chrome_auto45.json"),
        Path("D:/Temp/AshenOath/save001_edge_auto45.json"),
    )
    results = []
    for path in browser_reports:
        if not path.is_file():
            raise RuntimeError(f"required current browser evidence is missing: {path}")
        browser_report = json.loads(path.read_text(encoding="utf-8"))
        if browser_report.get("status") != "pass":
            raise RuntimeError(f"current browser evidence is not passing: {path}")
        results.append({"name": path.stem, "status": "pass", "log": str(path), "warnings": [], "failure": ""})
    return {
        "schema_version": 4,
        "report_id": uuid.uuid4().hex,
        "release_id": "recovery004-current-qa-observation",
        "kind": "recovery_observation_not_release_acceptance",
        "release_phase": "candidate",
        "status": "partial-pass",
        "started_at": observed_at,
        "finished_at": observed_at,
        "observed_at": observed_at,
        "source_commit": commit,
        "source_branch": git_value(project, "branch", "--show-current"),
        "source_fingerprint": fingerprint,
        "runtime_content_fingerprint": fingerprint,
        "test_harness_fingerprint": harness,
        "registry_fingerprint": registry_digest,
        "execution_fingerprint": hashlib.sha256(b"recovery-observation-v4").hexdigest(),
        "verification_revision": {
            "source_commit": commit,
            "runtime_content_fingerprint": fingerprint,
            "test_harness_fingerprint": harness,
            "execution_fingerprint": hashlib.sha256(b"recovery-observation-v4").hexdigest(),
            "registry_sha256": registry_digest,
        },
        "registry_sha256": registry_digest,
        "dirty": bool(git_value(project, "status", "--porcelain")),
        "git_status": [line for line in git_value(project.parent.parent, "status", "--porcelain").splitlines() if line],
        "mode": "targeted-recovery-observation",
        "requested_gate": "REL-TRUTH-001",
        "project": str(project),
        "artifact": artifact,
        "issue_registry": registry,
        "release_blockers": release_blockers,
        "results": results,
        "screenshots": {},
        "ticket_acceptance": program["acceptance"],
        "partial_evidence": program.get("partial_evidence", {}),
        "evidence_files": evidence,
        "native_greyfen_performance": performance,
        "blockers": [
            f"{ticket}: {program['closure'][ticket]['current_blocker']}"
            for ticket, status in program["acceptance"].items()
            if status != "accepted" and ticket in program["closure"]
        ],
        "historical_release_report": "release_reports/latest.json",
        "historical_report_policy": "Preserved unchanged; its previous partial-pass is not current release approval.",
        "failure": "Release blocked by the current issue-registry snapshot; this report certifies evidence identity only.",
        "next_action": program["closure"]["PERF-001"]["next_action"],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = project / "release_reports/current_recovery.json"
    output.write_text(json.dumps(snapshot(project), indent=2) + "\n", encoding="utf-8")
    print(f"NO-GO snapshot written: {output}; no gates executed or approved")
