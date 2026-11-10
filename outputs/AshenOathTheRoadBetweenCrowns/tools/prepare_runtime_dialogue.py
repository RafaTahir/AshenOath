"""Compile lossless per-scene dialogue data for demand-driven runtime reads."""
import hashlib
import json
from pathlib import Path
from community_story_payload import split_scene, split_catalog, ending_payload, ambient_payload

PROJECT = Path(__file__).resolve().parent.parent
SOURCES = ("dialogue.json", "campaign_dialogue.json", "interaction_scenes.json")


def compile_dialogue(project=PROJECT):
    output = project / "data" / "runtime_dialogue"
    output.mkdir(parents=True, exist_ok=True)
    catalog = {}
    live_files = set()
    overlay = {"version": 1, "scenes": {}}
    for source in SOURCES:
        definitions = json.loads((project / "data" / source).read_text(encoding="utf-8-sig"))
        entries = {}
        for scene_id, scene in definitions.items():
            base, deferred = split_scene(scene)
            if deferred is not None:
                if scene_id in overlay["scenes"]:
                    raise ValueError("ambiguous deferred scene identity: " + scene_id)
                overlay["scenes"][scene_id] = deferred
            if base is None:
                continue
            name = hashlib.sha256((source + ":" + scene_id).encode()).hexdigest()[:24] + ".json"
            live_files.add(name)
            (output / name).write_text(json.dumps(base, ensure_ascii=True, separators=(",", ":")) + "\n", encoding="utf-8")
            entries[scene_id] = {"path": "res://data/runtime_dialogue/" + name, "name": scene.get("name", "")}
        catalog["res://data/" + source] = entries
    for old in output.glob("*.json"):
        if old.name not in live_files:
            old.unlink() # Only compiler-owned outputs in this dedicated directory.
    authored = json.loads((project / "data/story_campaign.json").read_text(encoding="utf-8-sig"))
    base_catalog, overlay["catalog"] = split_catalog(authored)
    community = json.loads((project / "data/community_campaign.json").read_text(encoding="utf-8-sig"))
    overlay["ending_rituals"], overlay["ending_cards"] = ending_payload(community)
    overlay["ending_ambient"] = ambient_payload(community)
    for path, value in (("runtime_dialogue_index.json", catalog), ("runtime_story_campaign.json", base_catalog), ("community_story_overlay.json", overlay)):
        (project / "data" / path).write_text(json.dumps(value, ensure_ascii=True, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Compiled {sum(len(entries) for entries in catalog.values())} base scenes and {len(overlay['scenes'])} deferred scene projections")


if __name__ == "__main__":
    compile_dialogue()
