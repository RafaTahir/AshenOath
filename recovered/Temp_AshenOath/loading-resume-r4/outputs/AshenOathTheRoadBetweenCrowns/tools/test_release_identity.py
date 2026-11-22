#!/usr/bin/env python3
"""Exercise release identity and evidence ownership without Godot or browsers."""

from __future__ import annotations

import hashlib
import gzip
import json
import tempfile
from pathlib import Path
from unittest.mock import patch

from release_identity import HashCache, artifact_snapshot, harness_fingerprint, registry_fingerprint, runtime_fingerprint
from build_web_runtime_manifest import compress_wasm
from verify_release_report import gate_set_differences, valid_gate_identity, valid_owned_gate_result, validate_revision_identity, validate_worktree_state


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    scratch = Path("D:/Temp/AshenOath")
    scratch.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="release-identity-", dir=scratch) as directory:
        project = Path(directory)
        (project / "scripts").mkdir()
        (project / "tools").mkdir()
        (project / "scripts/game.gd").write_text("extends Node\n", encoding="utf-8")
        verifier = project / "tools/verify_fixture.py"
        verifier.write_text("print('PASS')\n", encoding="utf-8")
        registry = project / "RECOVERY_004_ISSUE_REGISTRY.json"
        registry.write_text('{"current_program":{"acceptance":{"X":"pending"}}}', encoding="utf-8")
        artifact = project / "artifact"
        artifact.mkdir()
        (artifact / "index.pck").write_bytes(b"one")
        wasm = artifact / "index.wasm"
        original_wasm = b"\x00asm" + bytes(10000)
        wasm.write_bytes(original_wasm)
        compress_wasm(wasm)
        encoded_wasm = wasm.read_bytes()
        assert gzip.decompress(encoded_wasm) == original_wasm
        compress_wasm(wasm)
        assert wasm.read_bytes() == encoded_wasm
        wasm.write_bytes(b"corrupt")
        try:
            compress_wasm(wasm)
        except ValueError:
            pass
        else:
            raise AssertionError("Invalid engine accepted")

        runtime_1 = runtime_fingerprint(project)
        harness_1 = harness_fingerprint(project)
        registry_1 = registry_fingerprint(project)
        artifact_1 = artifact_snapshot(artifact)["fingerprint"]

        registry.write_text('{"current_program":{"acceptance":{"X":"accepted"}}}', encoding="utf-8")
        assert runtime_fingerprint(project) == runtime_1
        assert harness_fingerprint(project) == harness_1
        assert registry_fingerprint(project) != registry_1

        verifier.write_text("print('CHANGED')\n", encoding="utf-8")
        assert runtime_fingerprint(project) == runtime_1
        assert harness_fingerprint(project) != harness_1

        probe = project / "tools/browser_preload.js"
        probe.write_text("window.probe = 1;\n", encoding="utf-8")
        harness_with_probe = harness_fingerprint(project)
        probe.write_text("window.probe = 2;\n", encoding="utf-8")
        assert harness_fingerprint(project) != harness_with_probe
        assert runtime_fingerprint(project) == runtime_1

        (project / "scripts/game.gd").write_text("extends Node\n# dirty same-HEAD change\n", encoding="utf-8")
        assert runtime_fingerprint(project) != runtime_1

        pack_manifest = project / "runtime_pack_manifest.json"
        pack_data = {"schema_version": 2, "release_id": "old", "packs": {"opening": {
            "url": "packs/opening.pck?sha256=old", "sha256": "old", "bytes": 10,
            "version": "old", "dependencies": ["base"], "status": "streamed_web_candidate",
        }}}
        pack_manifest.write_text(json.dumps(pack_data), encoding="utf-8")
        pack_source = runtime_fingerprint(project)
        pack_data["release_id"] = "new"
        pack_data["packs"]["opening"].update(url="packs/opening.pck?sha256=new", sha256="new", bytes=20, version="new")
        pack_manifest.write_text(json.dumps(pack_data), encoding="utf-8")
        assert runtime_fingerprint(project) == pack_source
        pack_data["packs"]["opening"]["dependencies"].append("characters")
        pack_manifest.write_text(json.dumps(pack_data), encoding="utf-8")
        assert runtime_fingerprint(project) != pack_source
        pack_data["packs"]["opening"]["dependencies"] = ["base"]
        pack_data["packs"]["opening"]["url"] = "https://different.example/opening.pck?sha256=new"
        pack_manifest.write_text(json.dumps(pack_data), encoding="utf-8")
        assert runtime_fingerprint(project) != pack_source

        for phase in ("candidate", "release", "final", "unknown"):
            errors = []
            validate_worktree_state({"release_phase": phase, "git_status": [" M scripts/game.gd"]}, errors, True)
            assert bool(errors) == (phase != "candidate")
        errors = []
        validate_worktree_state({"release_phase": "candidate"}, errors, True)
        assert errors

        base, committed = "1" * 40, "2" * 40
        candidate = {
            "source_commit": base,
            "runtime_content_fingerprint": runtime_fingerprint(project),
            "source_fingerprint": runtime_fingerprint(project),
            "test_harness_fingerprint": harness_fingerprint(project),
        }
        def ancestor_git(_repo: Path, *args: str) -> str:
            return "commit" if args[0] == "cat-file" else base

        with patch("verify_release_report.git_value", side_effect=ancestor_git):
            errors = []
            validate_revision_identity(candidate, project, committed, runtime_fingerprint(project), harness_fingerprint(project), errors)
            assert not errors, errors
            for changed_runtime, changed_harness in (("different", candidate["test_harness_fingerprint"]),
                                                      (candidate["runtime_content_fingerprint"], "different")):
                errors = []
                validate_revision_identity(candidate, project, committed, changed_runtime, changed_harness, errors)
                assert errors
            errors = []
            validate_revision_identity(candidate, project, "", candidate["runtime_content_fingerprint"], candidate["test_harness_fingerprint"], errors)
            assert errors
        with patch("verify_release_report.git_value", return_value=""):
            errors = []
            validate_revision_identity(candidate, project, committed, candidate["runtime_content_fingerprint"], candidate["test_harness_fingerprint"], errors)
            assert errors
        with patch("verify_release_report.git_value", side_effect=lambda _repo, *args: "commit" if args[0] == "cat-file" else committed):
            errors = []
            validate_revision_identity(candidate, project, committed, candidate["runtime_content_fingerprint"], candidate["test_harness_fingerprint"], errors)
            assert errors

        (artifact / "index.pck").write_bytes(b"two")
        assert artifact_snapshot(artifact)["fingerprint"] != artifact_1

        gate = {
            "protocol": "release-gate-v4",
            "contract": {"dependencies": [{"path": str(verifier), "sha256": sha(verifier)}]},
        }
        assert valid_gate_identity(gate)
        gate["contract"]["dependencies"][0]["sha256"] = "0" * 64
        assert not valid_gate_identity(gate)

        passed_process = {"process": {"owner": "release-runner", "exit_code": 0, "timed_out": False}}
        assert valid_owned_gate_result(passed_process)
        for process in (
            {"owner": "release-runner", "exit_code": 1, "timed_out": False},
            {"owner": "release-runner", "exit_code": 0, "timed_out": True},
            {"owner": "legacy-report", "exit_code": 0, "timed_out": False},
        ):
            assert not valid_owned_gate_result({"process": process})

        missing, duplicates = gate_set_differences(["one", "two"], [{"name": "one"}])
        assert missing == ["two"] and not duplicates
        missing, duplicates = gate_set_differences(["one"], [{"name": "one"}, {"name": "one"}])
        assert not missing and duplicates == ["one"]

        cache = HashCache()
        runtime_fingerprint(project, cache)
        first_count = len(cache._digests)
        runtime_fingerprint(project, cache)
        assert len(cache._digests) == first_count

    print("RELEASE IDENTITY: PASS (separate identities, generated pack metadata, dirty-source certification/clean promotion, ownership, missing gates, bounded hashing)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
