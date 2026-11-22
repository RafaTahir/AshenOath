from __future__ import annotations

import sys

from pipeline_common import MANIFEST_PATH, ROLE_MAPPING_PATH, read_json, utc_now, write_json

REQUIRED_ROLES = {
    "characters": [
        "player_kael",
        "mira_herbalist",
        "sister_anwen",
        "lord_edric",
        "rook_smuggler",
        "blacksmith_tor",
        "widow_elna",
        "generic_villager_01",
        "generic_villager_02",
    ],
    "enemies": ["ghoulkin", "bog_wretch", "gravebound_knight", "wychwood_stalker", "white_hart_avatar", "bandit"],
    "environment": [
        "greyfen_house",
        "tavern",
        "shrine",
        "blacksmith_shop",
        "cemetery_gravestone",
        "forest_tree",
        "forest_rock",
        "forest_bush",
        "ruins_wall",
        "ruins_pillar",
        "barrel",
        "crate",
        "cart",
        "fence",
        "torch",
    ],
    "animations": [
        "idle",
        "walk",
        "run",
        "sprint",
        "dodge_roll",
        "light_attack",
        "heavy_attack",
        "block",
        "hit_reaction",
        "death",
        "npc_idle",
    ],
    "audio": [
        "sword_swing",
        "sword_impact",
        "footstep_grass",
        "footstep_stone",
        "monster_growl",
        "forest_ambience",
        "village_ambience",
        "ruins_ambience",
        "ui_click",
        "music_loop",
    ],
}

ROLE_HINTS = {
    "player_kael": ["hunter", "hero", "adventurer", "male", "character"],
    "mira_herbalist": ["herbalist", "witch", "female", "villager"],
    "sister_anwen": ["priest", "cleric", "nun", "female", "robe"],
    "lord_edric": ["noble", "lord", "king", "male"],
    "rook_smuggler": ["rogue", "bandit", "thief", "smuggler"],
    "blacksmith_tor": ["blacksmith", "smith", "worker"],
    "widow_elna": ["widow", "old", "female", "villager"],
    "generic_villager_01": ["villager", "peasant", "civilian"],
    "generic_villager_02": ["villager", "peasant", "civilian"],
    "ghoulkin": ["ghoul", "zombie", "undead", "monster"],
    "bog_wretch": ["bog", "swamp", "troll", "orc", "monster"],
    "gravebound_knight": ["knight", "skeleton", "armor", "undead"],
    "wychwood_stalker": ["wolf", "beast", "stalker", "creature"],
    "white_hart_avatar": ["deer", "stag", "hart", "spirit"],
    "bandit": ["bandit", "rogue", "thief"],
    "greyfen_house": ["house", "hut", "cottage"],
    "tavern": ["tavern", "inn"],
    "shrine": ["shrine", "altar", "temple"],
    "blacksmith_shop": ["blacksmith", "forge", "smith"],
    "cemetery_gravestone": ["grave", "tomb", "cemetery"],
    "forest_tree": ["tree"],
    "forest_rock": ["rock", "stone"],
    "forest_bush": ["bush", "shrub"],
    "ruins_wall": ["wall", "ruin"],
    "ruins_pillar": ["pillar", "column"],
    "barrel": ["barrel"],
    "crate": ["crate", "box"],
    "cart": ["cart", "wagon"],
    "fence": ["fence"],
    "torch": ["torch", "lamp"],
    "sword_swing": ["swing", "whoosh", "sword"],
    "sword_impact": ["impact", "hit", "metal"],
    "footstep_grass": ["footstep", "grass"],
    "footstep_stone": ["footstep", "stone"],
    "monster_growl": ["growl", "monster"],
    "forest_ambience": ["forest", "ambience"],
    "village_ambience": ["village", "town", "ambience"],
    "ruins_ambience": ["ruin", "cave", "ambience"],
    "ui_click": ["click", "ui"],
    "music_loop": ["music", "loop"],
}


def score(asset: dict, role: str) -> int:
    hay = " ".join(
        [
            asset.get("file_name", ""),
            asset.get("relative_path", ""),
            asset.get("category", ""),
            asset.get("likely_use", ""),
        ]
    ).lower()
    points = 0
    for token in ROLE_HINTS.get(role, [role]):
        if token in hay:
            points += 10
    for part in role.split("_"):
        if part and part in hay:
            points += 3
    if asset.get("extension") in {".glb", ".gltf"}:
        points += 2
    return points


def choose_asset(candidates: list, role: str):
    ranked = sorted(candidates, key=lambda asset: score(asset, role), reverse=True)
    if ranked and score(ranked[0], role) > 0:
        return ranked[0]
    return None


def main() -> int:
    manifest = read_json(MANIFEST_PATH, {})
    mapping = {"generated_at": utc_now(), "roles": {}}
    bucket_by_group = {
        "characters": manifest.get("characters", []) or manifest.get("models", []),
        "enemies": manifest.get("enemies", []) or manifest.get("models", []),
        "environment": manifest.get("environment", []) or manifest.get("models", []),
        "animations": manifest.get("animations", []),
        "audio": manifest.get("audio", []),
    }

    for group, roles in REQUIRED_ROLES.items():
        mapping["roles"][group] = {}
        candidates = bucket_by_group.get(group, [])
        for role in roles:
            asset = choose_asset(candidates, role)
            if asset:
                mapping["roles"][group][role] = {
                    "status": "suggested",
                    "asset_id": asset["id"],
                    "path": asset["relative_path"],
                    "file_name": asset["file_name"],
                    "source_pack": asset.get("source_pack", ""),
                    "license": asset.get("license", ""),
                    "confidence": score(asset, role),
                    "notes": "Review before final use.",
                }
            else:
                mapping["roles"][group][role] = {
                    "status": "missing",
                    "asset_id": "",
                    "path": "",
                    "file_name": "",
                    "source_pack": "",
                    "license": "",
                    "confidence": 0,
                    "notes": "No likely asset found.",
                }

    write_json(ROLE_MAPPING_PATH, mapping)
    print(f"Wrote {ROLE_MAPPING_PATH.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
