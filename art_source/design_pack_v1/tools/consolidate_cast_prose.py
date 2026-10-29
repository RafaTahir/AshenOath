"""One-time source migration of display names, never save/quest identifiers.

Run before reviewing the authored merged scenes. Capitalized names in prose
are replaced; lowercase compatibility keys, conditions and rewards stay intact.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3] / "outputs/AshenOathTheRoadBetweenCrowns"
NAMES = {"Maren":"Nera", "Jory":"Tor", "Iven":"Toma", "Edda":"Mira",
         "Dain":"Tor", "Ressa":"Elna", "Tavin":"Rook", "Lysa":"Vale",
         "Odran":"Toma", "Maelin":"Mira", "Oris":"Tor"}
PATTERN = re.compile(r"\b(" + "|".join(NAMES) + r")\b")
LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')
SCRIPTS = ["epilogue_resolver", "greyfen_village_details", "greyfen_life_controller",
           "greyfen_gathering", "saga_catalog", "saga_activities", "story_journal_model",
           "story_honor", "story_activity_director", "story_scene_direction",
           "story_world_scenes", "story_world_director"]


def prose(value):
    return PATTERN.sub(lambda match: NAMES[match.group()], value)


def values(value):
    if isinstance(value, str):
        return prose(value)
    if isinstance(value, list):
        return [values(item) for item in value]
    if isinstance(value, dict):
        return {key: values(item) for key, item in value.items()}
    return value


def literal(match):
    # Decode escaped newlines before matching a name at a new paragraph.
    try:
        original = json.loads(match.group())
        revised = prose(original)
        return json.dumps(revised, ensure_ascii=False) if original != revised else match.group()
    except json.JSONDecodeError:
        return prose(match.group())


def run():
    for name in SCRIPTS:
        path = ROOT / "scripts" / (name + ".gd")
        source = path.read_text(encoding="utf-8-sig")
        revised = LITERAL.sub(literal, source)
        if source != revised:
            path.write_text(revised, encoding="utf-8", newline="\n")
            print(path.relative_to(ROOT))
    for name in ("cast_life", "people_place_scenes", "regional_performances", "dialogue", "campaign_dialogue", "quests"):
        path = ROOT / "data" / (name + ".json")
        original = json.loads(path.read_text(encoding="utf-8-sig"))
        revised = values(original)
        if revised != original:
            path.write_text(json.dumps(revised, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(path.relative_to(ROOT))


if __name__ == "__main__":
    run()
