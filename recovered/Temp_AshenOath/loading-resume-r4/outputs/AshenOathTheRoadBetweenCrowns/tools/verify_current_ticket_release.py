"""Exercise current-ticket release blocking without building or running the game."""
import json
import tempfile
from pathlib import Path

from verify_release_report import current_registry_snapshot, validate_registry


def main():
    scratch = Path("D:/Temp/AshenOath")
    scratch.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ticket-release-", dir=scratch) as directory:
        project = Path(directory)
        path = project / "RECOVERY_004_ISSUE_REGISTRY.json"
        registry = {"schema_version": 1, "registry_id": "fixture",
                    "categories": [{"id": "historical", "status": "visually_rejected"}],
                    "current_program": {"acceptance": {
                        "QA-001": "pending", "CERT-001": "pending", "RELEASE-001": "pending"
                    }}}

        def check(status, blockers, phase="candidate"):
            registry["current_program"]["acceptance"]["QA-001"] = status
            path.write_text(json.dumps(registry), encoding="utf-8")
            snapshot, _, error = current_registry_snapshot(project)
            assert not error, error
            errors = []
            validate_registry(project, {"issue_registry": snapshot,
                                       "release_phase": phase,
                                       "release_blockers": blockers}, errors)
            return errors, snapshot

        candidate_tail = []
        for status in ("pending", "deferred", "visually_rejected", "blocked"):
            errors, _ = check(status, [])
            assert any("release blockers" in error for error in errors), (status, errors)
        pending = [{"id": "QA-001", "severity": "blocker", "status": "pending"}]
        errors, snapshot = check("pending", pending)
        assert not errors, errors  # Candidate excludes only CERT-001 and RELEASE-001.
        snapshot.pop("ticket_statuses")
        errors = []
        validate_registry(project, {"issue_registry": snapshot, "release_phase": "candidate", "release_blockers": pending}, errors)
        assert any("ticket acceptance" in error for error in errors), errors
        errors, _ = check("accepted", candidate_tail)
        assert not errors, errors
        release_blocker = [{"id": "CERT-001", "severity": "blocker", "status": "pending"}]
        errors, _ = check("accepted", release_blocker, "release")
        assert not errors, errors
        final_blockers = release_blocker + [{"id": "RELEASE-001", "severity": "blocker", "status": "pending"}]
        errors, _ = check("accepted", final_blockers, "final")
        assert not errors, errors
        for malformed in (None, {}, [], {"QA-001": True}):
            registry["current_program"]["acceptance"] = malformed
            path.write_text(json.dumps(registry), encoding="utf-8")
            assert current_registry_snapshot(project)[2]
        registry["current_program"]["acceptance"] = {"QA-001": "made-up"}
        path.write_text(json.dumps(registry), encoding="utf-8")
        assert "invalid statuses" in current_registry_snapshot(project)[2]
    print("CURRENT TICKET RELEASE: PASS (accepted enum, phase boundaries, historical categories, stale and malformed fixtures)")


if __name__ == "__main__":
    main()
