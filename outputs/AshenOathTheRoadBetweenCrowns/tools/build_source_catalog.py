"""Generate the source-language localization artifact from authored content.

This is content generation, not a validator or a test. IDs are based on authored
record IDs and field locations, so edits to wording preserve translation keys.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = ["dialogue", "campaign_dialogue", "interaction_scenes", "quests", "story_campaign", "journal_people", "journal_work", "preparation_notes", "decision_contexts", "items", "upgrades", "vendors", "epilogues"]
TEXT_FIELDS = {"text", "name", "title", "description", "label", "greeting", "fallback_text", "result", "cost", "question", "stakes", "summary", "body", "subtitle", "intent", "promise", "player_intent", "preview", "immediate_result", "long_term_result", "journal_entry", "commitment", "uncertainty", "follow_through"}
STRINGS = {}

def identity(value, index):
    if isinstance(value, dict):
        for key in ("text_id", "choice_id", "id", "quest_id", "flag", "value"):
            if isinstance(value.get(key), (str, int)):
                return re.sub(r"[^a-zA-Z0-9_-]+", "_", str(value[key]))
    return str(index)

def walk(value, location, speaker=""):
    if isinstance(value, dict):
        speaker = value.get("speaker", speaker)
        for key, child in value.items():
            path = f"{location}.{key}"
            if key in TEXT_FIELDS and isinstance(child, str) and child.strip():
                STRINGS[path] = {"source": child, "text": child, "speaker": speaker, "context": location}
            else:
                walk(child, path, speaker)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            path = f"{location}.{identity(child, index)}"
            if location.endswith(".lines") and isinstance(child, str) and child.strip():
                STRINGS[path] = {"source": child, "text": child, "speaker": speaker, "context": location}
            else:
                walk(child, path, speaker)

for filename in FILES:
    path = ROOT / "data" / f"{filename}.json"
    if path.exists():
        walk(json.loads(path.read_text(encoding="utf-8-sig")), filename)

output = ROOT / "data" / "localization"
output.mkdir(parents=True, exist_ok=True)
(output / "en.json").write_text(json.dumps({"schema": 1, "locale": "en", "source_locale": "en", "font_policy": "Use runtime text, font fallback and scrollable layouts; add licensed font coverage before enabling a locale.", "strings": dict(sorted(STRINGS.items()))}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Generated English source catalog: {len(STRINGS)} text entries.")
