"""Compile lossless per-scene dialogue data for demand-driven runtime reads."""
import hashlib
import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
SOURCES = ("dialogue.json", "campaign_dialogue.json", "interaction_scenes.json")


def compile_dialogue():
    output = PROJECT / "data" / "runtime_dialogue"
    output.mkdir(parents=True, exist_ok=True)
    catalog = {}
    live_files = set()
    for source in SOURCES:
        definitions = json.loads((PROJECT / "data" / source).read_text(encoding="utf-8-sig"))
        entries = {}
        for scene_id, scene in definitions.items():
            name = hashlib.sha256((source + ":" + scene_id).encode()).hexdigest()[:24] + ".json"
            live_files.add(name)
            (output / name).write_text(json.dumps(scene, ensure_ascii=True, separators=(",", ":")) + "\n", encoding="utf-8")
            entries[scene_id] = {"path": "res://data/runtime_dialogue/" + name, "name": scene.get("name", "")}
        catalog["res://data/" + source] = entries
    for old in output.glob("*.json"):
        if old.name not in live_files:
            old.unlink() # Only compiler-owned outputs in this dedicated directory.
    (PROJECT / "data" / "runtime_dialogue_index.json").write_text(json.dumps(catalog, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Compiled {sum(len(entries) for entries in catalog.values())} lossless dialogue scenes")


if __name__ == "__main__":
    compile_dialogue()
