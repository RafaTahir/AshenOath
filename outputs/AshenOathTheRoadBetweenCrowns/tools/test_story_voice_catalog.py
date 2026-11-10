"""Exact runtime voice coverage and canonical identity, without model imports."""
import collections
import hashlib
import json
import unittest

import natural_story_voices as voices
from story_voice_catalog import canonical_speaker, gd_literal, role_for, source_identity, voice_directory, expansion_captions


class VoiceCatalogContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cast = json.loads((voices.GAME / "data/voice_cast.json").read_text(encoding="utf-8-sig"))["roles"]
        cls.lines = list(voices.utterances(cls.cast))

    def test_all_new_personal_lines_are_collected_exactly(self):
        actual = {(who, text) for scene, who, text, role, direction in self.lines if "life2_" in scene}
        expected = set()
        for row in json.loads((voices.GAME / "data/conversation_topics.json").read_text(encoding="utf-8-sig"))["topics"]:
            if row["id"].startswith("life2_"):
                expected.update((line["speaker_id"], line["text"]) for line in row["lines"])
        for row in json.loads((voices.GAME / "data/everyday_scenes.json").read_text(encoding="utf-8-sig"))["scenes"]:
            if row["id"].startswith("life2_"):
                expected.update((turn[0], turn[2]) for turn in row["turns"])
        self.assertEqual(actual, expected)
        self.assertEqual(sum("life2_" in line[0] for line in self.lines), 216)

    def test_every_collected_identity_has_one_recipe(self):
        grouped = collections.defaultdict(set)
        for _, who, text, role, _ in self.lines:
            self.assertIn(role, self.cast)
            grouped[(canonical_speaker(voices.GAME, who), text)].add(role)
        self.assertTrue(all(len(recipes) == 1 for recipes in grouped.values()))

    def test_regional_aliases_keep_person_identity(self):
        self.assertEqual(canonical_speaker(voices.GAME, "saga_maren"), "nera")
        self.assertEqual(canonical_speaker(voices.GAME, "vargan_servant"), "nessa")
        self.assertEqual(role_for(voices.GAME, "saga_lysa", voices.ALIASES), "vale")
        self.assertNotEqual(self.cast["nessa"]["voices"], self.cast["nera"]["voices"])

    def test_speaker_and_subtitle_both_change_key(self):
        key = lambda speaker, text: hashlib.sha256((canonical_speaker(voices.GAME, speaker) + "|" + text).encode()).hexdigest()
        self.assertEqual(key("saga_maren", "Stay."), key("nera", "Stay."))
        self.assertNotEqual(key("nera", "Stay."), key("nessa", "Stay."))
        self.assertNotEqual(key("nera", "Stay."), key("nera", "Go."))

    def test_literal_reader_accepts_data_not_code(self):
        self.assertEqual(gd_literal('const X := {"text":"A comma, } stays spoken.",}', "const X :="), {"text":"A comma, } stays spoken."})
        with self.assertRaises(ValueError):
            gd_literal('const X := {"text": dangerous_function()}', "const X :=")

    def test_added_sources_include_world_and_regional_lines(self):
        self.assertTrue(any(row[0].startswith("world_scene:") for row in self.lines))
        self.assertTrue(any(row[0].startswith("regional:") for row in self.lines))
        self.assertTrue(any(row[0].startswith("opening_arrival:") for row in self.lines))

    def test_everyday_player_and_all_authored_routine_lines_are_covered(self):
        actual = {(canonical_speaker(voices.GAME, who), text) for _, who, text, _, _ in self.lines}
        self.assertIn(("kael", "What have you heard?"), actual)
        self.assertIn(("kael", "I was in your way. I'm sorry."), actual)
        for filename in ("cast_life.json", "community_cast_life.json"):
            data = json.loads((voices.GAME / "data" / filename).read_text(encoding="utf-8-sig"))
            for actors in data["zones"].values():
                for actor, row in actors.items():
                    if row.get("line"):
                        self.assertIn((canonical_speaker(voices.GAME, actor), row["line"]), actual)
        after = [row for row in self.lines if row[0].startswith("community:aftermath:")]
        self.assertEqual(len(after), 4)
        self.assertTrue(all(voice_directory(row[0]) == "community" for row in after))

    def test_release_baseline_does_not_hide_new_personal_lines(self):
        commit, keys, old_cast = voices.baseline_inventory("02d0341", self.cast)
        self.assertEqual(len(commit), 40)
        personal_sources = collections.defaultdict(list)
        for source, who, text, role, _ in self.lines:
            if "life2_" in source:
                personal_sources[source].append((source, canonical_speaker(voices.GAME, who), text) not in keys)
        self.assertEqual(len(personal_sources), 36)
        self.assertTrue(all(all(new_lines) for new_lines in personal_sources.values()))
        # An unchanged short reply can reuse its exact existing performance.
        self.assertTrue(any((who, text) == ("kael", "No.") for _, who, text in keys))
        self.assertEqual(old_cast["merrow"], self.cast["merrow"])
        self.assertNotEqual(old_cast.get("nessa"), self.cast["nessa"])

    def test_new_scene_reply_is_not_discarded_by_legacy_caption_deduplication(self):
        old = ("old_scene", "player", "No.", "player", "")
        new = ("world_scene:life2_fixture", "player", "No.", "player", "")
        ranked = voices.prioritize_required([old, new], {("old_scene", "kael", "No.")}, self.cast, self.cast)
        self.assertEqual(ranked[0], new)

    def test_expansion_recordings_have_deferred_ownership(self):
        source = source_identity("white_hart", {"source_tag":"campaign_revision_2"})
        self.assertEqual(voice_directory(source), "community")
        self.assertEqual(voice_directory("community:consent:anwen:yes"), "community")
        self.assertEqual(voice_directory("world_scene:life2_anwen"), "living_cast")
        self.assertEqual(source_identity("white_hart", {}), "white_hart")

    def test_expansion_captions_are_collected_without_a_cast_recipe(self):
        if not (voices.GAME / "data/community_campaign.json").exists(): self.skipTest("Dormant expansion not present")
        captions = list(expansion_captions(voices.GAME, voices.pages))
        self.assertEqual(sum(row["source_id"].startswith("community:ending:") for row in captions), 6)
        self.assertEqual(sum(":unattended:" in row["source_id"] for row in captions), 12)
        self.assertTrue(all(row["caption_only"] and row["speaker_id"] in {"narrator", "system"} and row["text"] for row in captions))

    def test_departure_requires_its_own_exact_voluntary_answers(self):
        community = json.loads((voices.GAME / "data/community_campaign.json").read_text(encoding="utf-8-sig"))
        offers = community.get("departure_offers", {})
        actual = {(source, speaker, text) for source, speaker, text, _, _ in self.lines}
        for person, entry in offers.items():
            self.assertIn((f"community:departure:{person}:question", entry["question_speaker_id"], entry["question"]), actual)
            for choice in ("yes", "no", "withdraw"):
                self.assertIn((f"community:departure:{person}:{choice}", entry["speaker_id"], entry[choice]), actual)


if __name__ == "__main__":
    unittest.main(verbosity=2)
