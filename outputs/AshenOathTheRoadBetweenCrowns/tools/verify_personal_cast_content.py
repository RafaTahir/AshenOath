"""Permanent authored-cast contracts; no saves, world, renderer or voice synthesis."""
from __future__ import annotations

from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import unittest

GAME = Path(__file__).resolve().parents[1]
PEOPLE = {"anwen", "tor", "mira", "rook", "nessa", "elna", "toma", "nera", "senn", "vale", "merrow", "edric"}
EXPRESSIONS = {"neutral", "warmth", "wry", "concerned", "suspicion", "guarded", "fear", "anger", "stern", "grieving", "relieved", "resolute"}
GESTURES = {"acknowledge", "nod", "disagree", "remember", "recall", "reassure", "guarded_listening", "offer", "explain", ""}


def read(name):
    return json.loads((GAME / "data" / name).read_text(encoding="utf-8-sig"))


def inputs():
    return (read("conversation_topics.json"), read("everyday_scenes.json"), read("cast_personal_performances.json"))


def validate(topics, scenes, performances):
    topics = [row for row in topics["topics"] if row["id"].startswith("life2_")]
    scenes = [row for row in scenes["scenes"] if row["id"].startswith("life2_")]
    assert Counter(row["id"].split("_")[1] for row in topics) == Counter({person: 2 for person in PEOPLE})
    assert Counter(row["id"].split("_")[1] for row in scenes) == Counter({person: 1 for person in PEOPLE})
    assert len({row["id"] for row in topics + scenes}) == 36
    expected = {}
    for row in topics + scenes:
        person = row["id"].split("_")[1]
        conditions = row.get("conditions", row.get("when", {}))
        for key in ("actions", "sets_flags", "rewards", "adjusts_values", "grants"):
            assert key not in row, (row["id"], key)
        if person == "senn": assert conditions.get("senn_fate") == "testimony"
        if person == "edric": assert conditions.get("edric_stance") == "cooperate"
        if person == "nera": assert conditions.get("escort_abandonment_acknowledged") is True
        if person in {"vale", "merrow"}: assert conditions.get("castle_discovered") is True
        if "lines" in row:
            assert not row["known_evidence"] and row["revision"] == "1"
            assert len(row["lines"]) == 6 and row["actor_ids"] and len(row["zones"]) == 1
            for index, line in enumerate(row["lines"]):
                assert line["speaker_id"] in {"player", row["speaker_id"]}
                expected[f"conversation_topic:{row['id']}:line:{index}"] = line["speaker_id"], line["text"]
        else:
            assert row["requested"] and len(row["actors"]) == 1 and len(row["turns"]) == 6
            assert row["offer_label"].strip() and row["personal_staging"].strip()
            if person == "merrow": assert row["requires_bound_prop"] == "cup" and row["action"] == "rest"
            for index, turn in enumerate(row["turns"]):
                assert len(turn) == 3 and turn[0] in ["player", *row["actors"]]
                expected[f"world_scene:{row['id']}:turn:{index}"] = turn[0], turn[2]
    assert set(performances["sources"]) == set(expected) and len(expected) == 216
    for key, (speaker, text) in expected.items():
        entry = performances["sources"][key]
        assert text.strip() == text and text
        assert entry["speaker_id"] == speaker and entry["text_sha256"] == hashlib.sha256(text.encode()).hexdigest(), key
        direction = entry["performance"]
        assert direction["emotion"] in EXPRESSIONS and direction["listener_emotion"] in EXPRESSIONS
        assert direction["gesture"] in GESTURES and direction["listener_gesture"] in GESTURES
        for control in ("body_gesture", "body_listener_gesture"):
            if control in direction:
                gesture = direction[control]
                assert gesture in {"drink", "lower_book"}
                actor = key.split("life2_", 1)[1].split("_", 1)[0]
                target = "player" if (speaker == "player") == (control == "body_gesture") else actor
                assert target == ("merrow" if gesture == "drink" else "vale"), (key, control, target)
        assert 0.08 <= direction["reaction_delay"] <= 0.45
    assert performances["sources"]["world_scene:life2_merrow_no_form:turn:3"]["performance"]["body_listener_gesture"] == "drink"
    return len(expected)


class PersonalCastContracts(unittest.TestCase):
    def test_all_twelve_cast_members(self):
        self.assertEqual(validate(*inputs()), 216)

    def reject(self, mutate):
        data = copy.deepcopy(inputs())
        mutate(*data)
        with self.assertRaises((AssertionError, KeyError)):
            validate(*data)

    def test_unavailable_senn_is_not_offered(self):
        self.reject(lambda t, s, p: next(row for row in s["scenes"] if row["id"] == "life2_senn_ask_again")["when"].clear())

    def test_stale_text_cannot_reuse_direction(self):
        self.reject(lambda t, s, p: next(row for row in t["topics"] if row["id"].startswith("life2_"))["lines"][0].update(text="An edited line."))

    def test_wrong_speaker_cannot_reuse_direction(self):
        self.reject(lambda t, s, p: next(iter(p["sources"].values())).update(speaker_id="white_hart"))

    def test_unknown_gesture_fails(self):
        self.reject(lambda t, s, p: next(iter(p["sources"].values()))["performance"].update(gesture="unsupported"))

    def test_merrow_requires_real_cup(self):
        self.reject(lambda t, s, p: next(row for row in s["scenes"] if row["id"] == "life2_merrow_no_form").pop("requires_bound_prop"))

    def test_body_cue_must_target_supported_actor(self):
        self.reject(lambda t, s, p: p["sources"]["world_scene:life2_merrow_no_form:turn:3"]["performance"].update(body_gesture="drink"))

    def test_unknown_body_cue_fails(self):
        self.reject(lambda t, s, p: next(iter(p["sources"].values()))["performance"].update(body_gesture="spin"))

    def test_personal_scene_cannot_award_quest_progress(self):
        self.reject(lambda t, s, p: next(row for row in s["scenes"] if row["id"].startswith("life2_")).update(rewards={"xp": 10}))


if __name__ == "__main__":
    unittest.main(verbosity=2)
