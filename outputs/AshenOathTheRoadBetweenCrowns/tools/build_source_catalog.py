"""Generate the source-language localization artifact from authored content.

This is content generation, not a validator or a test. IDs are based on authored
record IDs and field locations, so edits to wording preserve translation keys.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = ["dialogue", "campaign_dialogue", "interaction_scenes", "conversation_topics", "quests", "story_campaign", "journal_people", "journal_work", "journal_evidence_details", "preparation_notes", "decision_contexts", "items", "upgrades", "vendors", "epilogues"]
TEXT_FIELDS = {"text", "name", "title", "description", "label", "greeting", "fallback_text", "result", "cost", "question", "stakes", "summary", "body", "subtitle", "intent", "promise", "player_intent", "preview", "immediate_result", "long_term_result", "journal_entry", "commitment", "uncertainty", "follow_through", "source"}

def identity(value, index):
    if isinstance(value, dict):
        for key in ("text_id", "choice_id", "id", "quest_id", "flag", "value"):
            if isinstance(value.get(key), (str, int)):
                return re.sub(r"[^a-zA-Z0-9_-]+", "_", str(value[key]))
    return str(index)

def catalogs(project=ROOT):
    base, community = {}, {}

    def add(path, text, speaker, location, deferred):
        (community if deferred else base)[path] = {"source": text, "text": text, "speaker": speaker, "context": location}

    def walk(value, location, speaker="", deferred=False):
        if isinstance(value, dict):
            speaker = value.get("speaker", speaker)
            deferred |= value.get("source_tag") == "campaign_revision_2" or value.get("campaign_revision") == 2
            for key, child in value.items():
                path = f"{location}.{key}"
                if key in TEXT_FIELDS and isinstance(child, str) and child.strip():
                    add(path, child, speaker, location, deferred)
                else:
                    walk(child, path, speaker, deferred)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                path = f"{location}.{identity(child, index)}"
                if location.endswith(".lines") and isinstance(child, str) and child.strip():
                    add(path, child, speaker, location, deferred)
                else:
                    walk(child, path, speaker, deferred)

    for filename in FILES:
        path = project / "data" / f"{filename}.json"
        if path.exists(): walk(json.loads(path.read_text(encoding="utf-8-sig")), filename)
    path = project / "data/community_campaign.json"
    if path.exists():
        value = json.loads(path.read_text(encoding="utf-8-sig"))
        walk(value, "community_campaign", deferred=True)
        for ending, rows in value.get("ending_rituals", {}).items():
            for index, row in enumerate(rows):
                context = f"community_campaign.ending_rituals.{ending}.{index}"
                add(context+".label", row[0], "narrator", context, True)
                add(context+".text", row[1], "narrator", context, True)
        for ending, text in value.get("ending_cards", {}).items():
            add("community_campaign.ending_cards."+ending, text, "narrator", "community_campaign.ending_cards", True)
    return base, community


def generate(project=ROOT):
    base, community = catalogs(project)
    output = project / "data/localization"
    output.mkdir(parents=True, exist_ok=True)
    for name, strings in (("en.json", base), ("community_en.json", community)):
        (output / name).write_text(json.dumps({"schema": 1, "locale": "en", "source_locale": "en", "font_policy": "Use runtime text, font fallback and scrollable layouts; add licensed font coverage before enabling a locale.", "strings": dict(sorted(strings.items()))}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated English source catalogs: {len(base)} base and {len(community)} deferred entries.")


if __name__ == "__main__": generate()
