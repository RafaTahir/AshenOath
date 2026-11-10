"""Compile deferred revision-two prose without changing authored identity."""
from copy import deepcopy

TAG = "campaign_revision_2"
NEW_CHAPTERS = ("main_empty_tables", "main_road_kept_open", "main_house_many_names", "main_what_we_promise")
NEW_ENDINGS = ("share", "depart")


def deferred(value):
    return isinstance(value, dict) and (value.get("source_tag") == TAG or value.get("campaign_revision") == 2)


def split_scene(scene):
    """None means the entire scene has deferred ownership; never infer by name."""
    if deferred(scene):
        return None, deepcopy(scene)
    base = deepcopy(scene)
    changed = False
    for field in ("variants", "actions", "lines", "pages"):
        if field in base:
            filtered = [row for row in base[field] if not deferred(row)]
            changed |= filtered != base[field]
            base[field] = filtered
    return base, deepcopy(scene) if changed else None


def split_catalog(catalog):
    base = deepcopy(catalog)
    overlay = {"chapters": [], "endings": []}
    for field, identity, expected in (("chapters", "quest_id", NEW_CHAPTERS), ("endings", "id", NEW_ENDINGS)):
        for index, row in enumerate(base[field]):
            if row.get(identity) not in expected:
                continue
            if not deferred(row):
                raise ValueError(f"new {field} row lacks explicit revision metadata: {row[identity]}")
            overlay[field].append(deepcopy(row))
            base[field][index] = {key: row[key] for key in (identity, "title", "campaign_revision")}
        if {row[identity] for row in overlay[field]} != set(expected):
            raise ValueError(f"deferred {field} do not match the complete expansion")
    return base, overlay


def ending_payload(community):
    rituals = deepcopy(community.get("ending_rituals", {}))
    cards = deepcopy(community.get("ending_cards", {}))
    if set(rituals) != set(NEW_ENDINGS) or set(cards) != set(NEW_ENDINGS):
        raise ValueError("both authored community endings require rituals and epilogue cards")
    for ending in NEW_ENDINGS:
        if len(rituals[ending]) != 3 or any(not isinstance(row, list) or len(row) != 2 or any(not isinstance(text, str) or not text.strip() for text in row) for row in rituals[ending]):
            raise ValueError(f"{ending} requires three authored [label, narrator text] steps")
        if not isinstance(cards[ending], str) or not cards[ending].strip():
            raise ValueError(f"{ending} requires an authored epilogue card")
    return rituals, cards


def ambient_payload(community):
    rows = deepcopy(community.get("ending_ambient", {}))
    if set(rows) != {"concord", "open_road"}:
        raise ValueError("both expanded outcomes require their authored ambient lines")
    for row in rows.values():
        if not isinstance(row, dict) or row.get("speaker_ids") != ["shrine_pilgrim", "quality_mourner"] or not isinstance(row.get("text"), str) or not row["text"].strip():
            raise ValueError("ending ambient text must identify its actual two runtime speakers")
    return rows
