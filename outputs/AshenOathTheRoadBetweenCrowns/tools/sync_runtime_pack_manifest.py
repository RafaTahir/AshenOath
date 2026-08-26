"""Copy verified external pack sizes and hashes into the runtime manifest."""

import argparse
import json
from pathlib import Path


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("candidates", type=Path)
    args = parser.parse_args()

    manifest = read_json(args.manifest)
    candidates = read_json(args.candidates)
    candidate_by_id = {str(item["id"]): item for item in candidates.get("packs", [])}
    failures = []

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
        if pack_id != "base":
            pack["bytes"] = size
            pack["sha256"] = digest

    if failures:
        for failure in failures:
            print(f"PACK MANIFEST: FAIL - {failure}")
        return 1

    project_candidates_data = dict(candidates)
    project_candidates_data["artifact_directory"] = "external_runtime_packs"
    candidate_text = json.dumps(project_candidates_data, indent=2) + "\n"
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
