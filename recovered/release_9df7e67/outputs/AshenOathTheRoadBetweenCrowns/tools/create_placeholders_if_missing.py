from __future__ import annotations

import sys

from pipeline_common import ROLE_MAPPING_PATH, read_json, utc_now, write_json


def placeholder_type_for(group: str) -> str:
    if group == "audio":
        return "silent_audio_required"
    if group == "textures":
        return "flat_material_required"
    return "primitive_scene_required"


def main() -> int:
    mapping = read_json(ROLE_MAPPING_PATH, {"generated_at": utc_now(), "roles": {}})
    roles = mapping.setdefault("roles", {})
    missing_count = 0

    for group, group_roles in roles.items():
        for role, entry in group_roles.items():
            if entry.get("status") == "missing" or not entry.get("path"):
                entry["status"] = "placeholder"
                entry["placeholder_type"] = placeholder_type_for(group)
                entry["path"] = ""
                entry["notes"] = "Placeholder required until a real asset is assigned."
                missing_count += 1

    mapping["placeholders_updated_at"] = utc_now()
    write_json(ROLE_MAPPING_PATH, mapping)
    print(f"Updated {ROLE_MAPPING_PATH.name}; placeholders={missing_count}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
