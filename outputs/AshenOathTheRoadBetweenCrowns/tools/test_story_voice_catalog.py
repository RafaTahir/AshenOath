"""Exact runtime voice coverage and canonical identity, without model imports."""
import collections
import hashlib
import json
import unittest

import natural_story_voices as voices
from story_voice_catalog import canonical_speaker, gd_literal, role_for, source_identity, voice_directory


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

    def test_expansion_recordings_have_deferred_ownership(self):
        source = source_identity("white_hart", {"source_tag":"campaign_revision_2"})
        self.assertEqual(voice_directory(source), "community")
        self.assertEqual(voice_directory("community:consent:anwen:yes"), "community")
        self.assertEqual(voice_directory("world_scene:life2_anwen"), "living_cast")
        self.assertEqual(source_identity("white_hart", {}), "white_hart")


if __name__ == "__main__":
    unittest.main(verbosity=2)
