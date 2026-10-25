"""Shared deployment budget; transport size is not decoded runtime memory."""

import json
from pathlib import Path


POLICY_PATH = Path(__file__).resolve().parents[1] / "data" / "deployment_policy.json"
POLICY = json.loads(POLICY_PATH.read_text(encoding="utf-8-sig"))


def check_budget(total_bytes: int) -> list[str]:
    maximum = POLICY["max_deployment_bytes"]
    if total_bytes < 0 or total_bytes >= maximum:
        raise ValueError(f"Complete Web directory is {total_bytes} bytes; must be below {maximum} ({POLICY['id']})")
    if total_bytes >= POLICY["warning_deployment_bytes"]:
        return [f"Web package is {total_bytes} bytes: above the {POLICY['warning_deployment_bytes']}-byte warning threshold"]
    return []


def check_file_size(relative: str, size: int) -> None:
    if size >= POLICY["max_git_file_bytes"]:
        raise ValueError(f"Git file must be below {POLICY['max_git_file_bytes']} bytes: {relative} ({size})")


def size_summary(records: list[dict], runtime: dict) -> dict:
    by_path = {item["path"]: item for item in records}
    from urllib.parse import urlsplit

    def opening(quality: bool) -> dict:
        paths = {path for path in by_path if not path.startswith("packs/")}
        visited = set()

        def include(pack_id: str) -> None:
            if pack_id in visited:
                return
            visited.add(pack_id)
            pack = runtime["packs"][pack_id]
            for dependency in pack.get("dependencies", []):
                include(dependency)
            if pack.get("url"):
                paths.add(urlsplit(pack["url"]).path)

        for pack_id in (["base", "opening", "quality_materials"] if quality else ["base", "opening"]):
            include(pack_id)
        return {"paths": sorted(paths), "transport_bytes": sum(by_path[path]["bytes"] for path in paths)}

    return {
        "transport_artifact_bytes": sum(item["bytes"] for item in records),
        "decoded_artifact_bytes": sum(item.get("decoded_bytes", item["bytes"]) for item in records),
        "opening_required_balanced_potato": opening(False),
        "opening_required_quality": opening(True),
        "note": "Opening dependency totals exclude the release manifest and optional background downloads; not measured network traffic or runtime memory.",
        "runtime_memory_bytes": None,
    }
