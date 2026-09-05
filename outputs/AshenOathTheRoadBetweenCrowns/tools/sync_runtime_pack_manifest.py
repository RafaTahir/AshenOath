"""Copy verified external pack sizes and hashes into the runtime manifest."""

import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def git_value(path: Path, *args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(path), *args], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("candidates", type=Path)
    parser.add_argument("--build-id", default="")
    parser.add_argument("--source-commit", default="")
    parser.add_argument(
        "--embed-opening",
        action="store_true",
        help="mark the opening pack as embedded in the root Web PCK",
    )
    args = parser.parse_args()

    manifest = read_json(args.manifest)
    candidates = read_json(args.candidates)
    candidate_by_id = {str(item["id"]): item for item in candidates.get("packs", [])}
    failures = []
    project = args.manifest.resolve().parent
    repo_root = project.parent.parent
    source_commit = args.source_commit or git_value(repo_root, "rev-parse", "HEAD")
    build_id = args.build_id or f"dev-{source_commit[:12] if source_commit else 'local'}"
    generated_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    for pack_id, pack in manifest.get("packs", {}).items():
        candidate = candidate_by_id.get(str(pack_id))
        if candidate is None:
            failures.append(f"missing candidate record: {pack_id}")
            continue
        artifact = str(candidate.get("artifact", ""))
        digest = str(candidate.get("sha256", "")).lower()
        size = int(candidate.get("bytes", 0))
        if len(digest) != 64 or size <= 0 or not artifact:
            failures.append(f"invalid candidate record: {pack_id}")
            continue
        pack["candidate_artifact"] = artifact
        pack["candidate_bytes"] = size
        pack["candidate_sha256"] = digest
        pack["version"] = build_id
        if pack_id == "base":
            # The base pack is embedded in the production root PCK. Its
            # standalone export remains a useful source candidate, but it is
            # not the artifact mounted by the browser. Keep that provenance
            # explicit so release tooling never compares the root PCK against
            # the unrelated standalone candidate hash.
            pack["embedded_artifact"] = "index.pck"
            pack["embedded_source_artifact"] = artifact
            pack["embedded_source_bytes"] = size
            pack["embedded_source_sha256"] = digest
            pack["embedded_source_kind"] = "standalone_pack_candidate"
        elif pack_id == "opening" and args.embed_opening:
            # The opening candidate is still built and hash-checked, but its
            # resources are exported with the root PCK so New Game does not
            # wait for a second network download before Greyfen is playable.
            pack["bytes"] = 0
            pack["sha256"] = ""
            pack["url"] = ""
            pack["status"] = "embedded_opening_current_pck"
        elif pack_id != "base":
            pack["bytes"] = size
            pack["sha256"] = digest
            pack["url"] = f"packs/{pack_id}.pck?v={build_id}"
            pack["status"] = "streamed_web_candidate"

    if failures:
        for failure in failures:
            print(f"PACK MANIFEST: FAIL - {failure}")
        return 1

    project_candidates_data = dict(candidates)
    project_candidates_data["artifact_directory"] = "external_runtime_packs"
    project_candidates_data["build_id"] = build_id
    project_candidates_data["generated_from_commit"] = source_commit
    project_candidates_data["generated_at_utc"] = generated_at
    candidate_text = json.dumps(project_candidates_data, indent=2) + "\n"
    manifest["release_id"] = build_id
    manifest["build_id"] = build_id
    manifest["generated_from_commit"] = source_commit
    manifest["generated_at_utc"] = generated_at
    manifest["artifact_policy"] = (
        "opening_embedded_external_campaign"
        if args.embed_opening
        else "external_runtime_packs"
    )
    manifest["total_bytes"] = sum(int(pack.get("bytes", 0)) for pack in manifest.get("packs", {}).values())
    args.manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    # Keep the project-local QA record aligned with the external artifacts. The
    # runtime uses runtime_pack_manifest.json; this copy is for offline gates
    # and keeps its documented candidate_manifest path truthful.
    project_candidates = args.manifest.parent / "runtime_pack_candidates.json"
    project_candidates.write_text(candidate_text, encoding="utf-8")
    print(
        "PACK MANIFEST: PASS - synced "
        f"{len(candidate_by_id)} pack records from {args.candidates}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
