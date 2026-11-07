"""Collect runtime subtitle tuples without synthesis or executing game source."""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
import re

ROLE_BY_PERSON = {"kael": "player", "anwen": "sister_anwen"}


def source_identity(scene: str, entry: dict) -> str:
    return ("campaign_revision_2:" if entry.get("source_tag") == "campaign_revision_2" else "") + scene


def voice_directory(scene: str, default: str = "living_cast") -> str:
    return "community" if scene.startswith(("community:", "campaign_revision_2:")) else default


def read(game: Path, relative: str):
    return json.loads((game / relative).read_text(encoding="utf-8-sig"))


@lru_cache(maxsize=512)
def canonical_speaker(game: Path, speaker: str) -> str:
    cast = read(game, "data/design_pack_cast.json")
    key = speaker.strip().lower()
    return key if key in cast["cast"] else cast["legacy_cast"].get(key, key)


def role_for(game: Path, speaker: str, aliases: dict) -> str:
    person = canonical_speaker(game, speaker)
    return ROLE_BY_PERSON.get(person, aliases.get(person, aliases.get(speaker, person)))


def gd_literal(source: str, marker: str):
    """Read only JSON-shaped authored GDScript constants, never eval source."""
    start = source.index(marker) + len(marker)
    while source[start].isspace(): start += 1
    if source[start] not in "[{": raise ValueError(f"Expected authored dictionary/array after {marker}")
    stack, quoted, escaped = [], False, False
    for end in range(start, len(source)):
        char = source[end]
        if quoted:
            if escaped: escaped = False
            elif char == "\\": escaped = True
            elif char == '"': quoted = False
        elif char == '"': quoted = True
        elif char in "[{": stack.append(char)
        elif char in "]}":
            opening = stack.pop()
            if (opening, char) not in {("[", "]"), ("{", "}")}: raise ValueError(marker)
            if not stack:
                # GDScript permits a final comma; remove it only outside strings.
                raw = source[start:end + 1]
                return json.loads(re.sub(r',\s*(?=[}\]])(?=(?:[^"\\]*(?:\\.[^"\\]*)*"[^"\\]*(?:\\.[^"\\]*)*")*[^"\\]*(?:\\.[^"\\]*)*$)', '', raw))
    raise ValueError(f"Unterminated authored constant: {marker}")


def extra_utterances(game: Path, cast: dict, aliases: dict, pages):
    def emit(scene, who, text, direction=""):
        text = str(text).strip()
        if not text or who in {"", "narrator", "system", "unknown"}: return
        role = role_for(game, who, aliases)
        if role not in cast: raise ValueError(f"Uncast runtime speaker {who!r} in {scene}")
        yield scene, who, text, role, direction

    for source in ("people_place_scenes.json", "everyday_scenes.json"):
        catalog = read(game, "data/" + source)
        for scene in catalog.get("scenes", []):
            for variant in [scene, *scene.get("variants", [])]:
                for turn in variant.get("turns", []):
                    if not isinstance(turn, list) or len(turn) != 3:
                        raise ValueError(f"Malformed runtime world turn: {scene['id']}")
                    yield from emit(source_identity("world_scene:" + scene["id"], {**scene, **variant}), turn[0], turn[2], "everyday")

    everyday = read(game, "data/everyday_life.json")
    for person, lines in everyday.get("voices", {}).items():
        for kind, text in lines.items():
            yield from emit(f"everyday:{person}:{kind}", person, text, "everyday")
        yield from emit("everyday:social_menu", person, "A moment between jobs.", "everyday")
    for favour in everyday.get("favours", []):
        yield from emit("everyday:favour:" + favour["id"], favour["actor"], favour["reply"], "everyday")
    for rumour in everyday.get("rumours", []):
        yield from emit("everyday:rumour:" + rumour["id"], rumour["actor"], rumour["claim"], "everyday")

    everyday_source = (game / "scripts/everyday_life.gd").read_text(encoding="utf-8-sig")
    openings = gd_literal(everyday_source, "var openings :=")
    for kind, text in openings.items():
        yield from emit("everyday:player:" + kind, "player", text, "everyday")
    for index, literal in enumerate(re.findall(r'\bspeak\(actor,\s*("(?:[^"\\]|\\.)*")', everyday_source)):
        yield from emit(f"everyday:player:direct:{index}", "player", json.loads(literal), "everyday")

    # Regional routines use exact authored lines from these catalogs. Keep new
    # community barks deferred even when the same speaker lives in older zones.
    for filename, prefix in (("cast_life.json", "routine"), ("community_cast_life.json", "community:routine")):
        if not (game / "data" / filename).exists(): continue
        for zone, actors in read(game, "data/" + filename).get("zones", {}).items():
            for actor, definition in actors.items():
                def routine_lines(value, source):
                    if isinstance(value, dict):
                        for key, child in value.items():
                            if (key == "line" or key.endswith("_line")) and isinstance(child, str):
                                yield from emit(source + ":" + key, actor, child, "everyday")
                            elif isinstance(child, (dict, list)):
                                yield from routine_lines(child, source + ":" + key)
                    elif isinstance(value, list):
                        for index, child in enumerate(value):
                            yield from routine_lines(child, source + ":" + str(index))
                yield from routine_lines(definition, f"{prefix}:{zone}:{actor}")
    community_data = read(game, "data/community_campaign.json") if (game / "data/community_campaign.json").exists() else {}
    if community_data.get("ending_ambient"):
        for ending, entry in community_data["ending_ambient"].items():
            for actor in entry["speaker_ids"]:
                yield from emit(f"community:aftermath:{ending}:{actor}", actor, entry["text"], "everyday")
    else:
        consequences = (game / "scripts/village_consequence_routines.gd").read_text(encoding="utf-8-sig")
        ending_lines = gd_literal(consequences, "var lines :=")
        for ending in ("concord", "open_road"):
            if ending not in ending_lines: continue
            for actor in ("shrine_pilgrim", "quality_mourner"):
                yield from emit(f"community:aftermath:{ending}:{actor}", actor, ending_lines[ending], "everyday")

    saga_source = (game / "scripts/saga_catalog.gd").read_text(encoding="utf-8-sig")
    people = gd_literal(saga_source, "const PEOPLE :=")
    greetings = gd_literal(saga_source, "const GREETINGS :=")
    quests = gd_literal(saga_source, "const QUESTS :=")
    performance = read(game, "data/regional_performances.json")["quests"]
    for who, person in people.items():
        yield from emit("regional:greeting:" + who, who, person["line"])
        yield from emit("regional:return:" + who, who, greetings.get(who, person["line"]))
    for quest_id, quest in quests.items():
        authored = performance.get(quest_id, {})
        for key, dialogue in authored.items():
            if key == "dialogue" or key.startswith("dialogue_"):
                for step_id, lines in dialogue.items():
                    for who, text, direction in pages({"name": "Narrator", "lines": lines}):
                        yield from emit(f"regional:{quest_id}:{key}:{step_id}", who, text, direction)
        for step in quest["steps"]:
            if step[3] not in {"talk", "homecoming"}: continue
            # Without explicit per-speaker pages the runtime reads the exact
            # authored account under the present quest actor's identity.
            if not authored.get("dialogue", {}).get(step[0]):
                yield from emit(f"regional:{quest_id}:account:{step[0]}", quest.get("actor", "narrator"), authored.get("beats", {}).get(step[0], step[5]))
        for who, branches in authored.get("return_lines", {}).items():
            for outcome, text in branches.items():
                yield from emit(f"regional:{quest_id}:return:{outcome}", who, text)

    # These are generated by the runtime from finite authored components.
    activity = (game / "scripts/saga_activities.gd").read_text(encoding="utf-8-sig")
    maren = activity.split("func _maren_greeting()", 1)[1].split("\nfunc ", 1)[0]
    for literal in re.findall(r'\breturn\s+("(?:[^"\\]|\\.)*")', maren):
        yield from emit("regional:nera:return", "saga_maren", json.loads(literal))
    parting = re.search(r'var parting := ("(?:[^"\\]|\\.)*") if .*? else ("(?:[^"\\]|\\.)*")', maren)
    if parting is None: raise ValueError("Nera return composition changed; update the voice collector")
    quest = quests["side_escort_06"]
    endings = performance.get("side_escort_06", {}).get("outcomes", quest.get("outcomes", {}))
    for outcome, text in endings.items():
        closing = json.loads(parting.group(1 if outcome == "company" else 2))
        yield from emit("regional:nera:parting:" + outcome, "saga_maren", text + "\n\nNera: '" + closing + "'")

    direction_source = (game / "scripts/story_scene_direction.gd").read_text(encoding="utf-8-sig")
    arrival_source = direction_source.split("static func opening_arrival()", 1)[1].split("\nconst ", 1)[0]
    for line in gd_literal(arrival_source, "return"):
        yield from emit("opening_arrival:" + line["actor"], line["actor"], line["text"])

    # Expansion spoken rows must carry identity explicitly. Instructions,
    # public written records and UI labels stay text-led, not invented voices.
    community_path = game / "data/community_campaign.json"
    if community_path.exists():
        community = read(game, "data/community_campaign.json")
        for person, entry in community.get("participant_lines", {}).items():
            for zone in ["lantern_reach", "hearthward"]:
                if entry.get(zone):
                    yield from emit(f"community:participant:{person}:{zone}", entry["speaker_id"], entry[zone])
        offers = community.get("consent_offers", {})
        for person, entry in (offers.items() if isinstance(offers, dict) else ((row["actor"], row) for row in offers)):
            for kind in ["yes", "no", "withdraw"]:
                if entry.get(kind): yield from emit(f"community:consent:{person}:{kind}", entry["speaker_id"], entry[kind])
            if entry.get("question"):
                yield from emit(f"community:consent:{person}:question", entry["question_speaker_id"], entry["question"])
        def spoken_rows(value, source):
            if isinstance(value, dict):
                if "speaker_id" in value and "text" in value:
                    yield from emit(source, value["speaker_id"], value["text"], value.get("direction", ""))
                for key, child in value.items():
                    yield from spoken_rows(child, source + ":" + str(key))
            elif isinstance(value, list):
                for index, child in enumerate(value):
                    yield from spoken_rows(child, source + ":" + str(index))
        yield from spoken_rows(community, "community")


def expansion_captions(game: Path, pages=None):
    """Inventory exact authored caption pages without assigning a cast voice."""
    path = game / "data/community_campaign.json"
    if not path.exists(): return
    community = read(game, "data/community_campaign.json")
    for chapter_id, chapter in community.get("chapters", {}).items():
        for kind in ("summary", "stakes"):
            if chapter.get(kind):
                yield {"source_id":f"community:chapter:{chapter_id}:{kind}", "speaker_id":"narrator", "text":chapter[kind], "caption_only":True}
    for person, text in community.get("public_accounts", {}).items():
        if not isinstance(text, str): raise ValueError("Public account caption schema changed")
        yield {"source_id":f"community:public_account:{person}", "speaker_id":"narrator", "text":text, "caption_only":True}
    steps = community.get("ending_rituals", {})
    if not steps:
        source = (game / "scripts/covenant_resolution.gd").read_text(encoding="utf-8-sig")
        steps = gd_literal(source, "const STEPS :=")
    for action in ("share", "depart"):
        for index, step in enumerate(steps[action]):
            yield {"source_id":f"community:ending:{action}:{index}", "speaker_id":"narrator", "text":step[1], "caption_only":True}
    for action, text in community.get("ending_cards", {}).items():
        if action not in {"share", "depart"} or not isinstance(text, str): raise ValueError("Malformed community ending card")
        yield {"source_id":f"community:ending_card:{action}", "speaker_id":"narrator", "text":text, "caption_only":True}
    if pages is not None:
        for source_file in ("dialogue.json", "campaign_dialogue.json", "interaction_scenes.json"):
            for scene_id, base in read(game, "data/"+source_file).items():
                for index, entry in enumerate([base, *[{**base, **variant} for variant in base.get("variants", [])]]):
                    if entry.get("source_tag") != "campaign_revision_2": continue
                    for who, text, _ in pages(entry):
                        if who in {"narrator", "system"}:
                            yield {"source_id":f"campaign_revision_2:{source_file}:{scene_id}:{index}", "speaker_id":who, "text":text, "caption_only":True}
                    for page_index, page in enumerate(entry.get("unattended_pages", [])):
                        if page.get("speaker_id") != "narrator": raise ValueError("Unavailable cast fallback must be an authored narrator caption")
                        yield {"source_id":f"campaign_revision_2:{scene_id}:unattended:{page_index}", "speaker_id":"narrator", "text":page["text"], "caption_only":True}
