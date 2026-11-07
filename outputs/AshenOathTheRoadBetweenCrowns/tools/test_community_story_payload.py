"""No engine: deferred text must reconstruct its exact authoring sources."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from community_story_payload import NEW_CHAPTERS, NEW_ENDINGS, split_scene, split_catalog, ending_payload
from prepare_runtime_dialogue import PROJECT, SOURCES, compile_dialogue


def read(name):
    return json.loads((PROJECT / "data" / name).read_text(encoding="utf-8-sig"))


class CommunityStoryPayloadTests(unittest.TestCase):
    def test_only_explicit_revision_rows_move_and_legacy_scenes_are_identical(self):
        moved = {}
        for source in SOURCES:
            for identity, scene in read(source).items():
                before = copy.deepcopy(scene)
                base, overlay = split_scene(scene)
                self.assertEqual(scene, before)
                if overlay is None:
                    self.assertEqual(base, scene)
                else:
                    moved[identity] = overlay
                    self.assertEqual(overlay, scene)
                    if base is not None:
                        for field in ("variants", "actions", "lines", "pages"):
                            self.assertFalse(any(isinstance(row, dict) and row.get("source_tag") == "campaign_revision_2" for row in base.get(field, [])))
        expected = {"white_hart"} | {f"aftermath_{kind}_{ending}" for kind in ("names", "work", "road") for ending in ("concord", "open_road")}
        self.assertEqual(set(moved), expected)
        hart, _ = split_scene(read("campaign_dialogue.json")["white_hart"])
        self.assertEqual([row["ending"] for row in hart["actions"]], ["expose", "free", "bind", "kill"])

    def test_name_alone_never_assigns_deferred_ownership(self):
        value = {"name": "Community", "greeting": "An ordinary existing line", "variants": [{"conditions": {"old_flag": True}, "lines": ["Kept"]}]}
        base, overlay = split_scene(value)
        self.assertEqual(base, value)
        self.assertIsNone(overlay)

    def test_catalog_retains_graph_order_and_small_identity_only(self):
        authored = read("story_campaign.json")
        base, overlay = split_catalog(authored)
        for field, key, new in (("chapters", "quest_id", NEW_CHAPTERS), ("endings", "id", NEW_ENDINGS)):
            self.assertEqual([row[key] for row in base[field]], [row[key] for row in authored[field]])
            additions = {row[key]: row for row in overlay[field]}
            restored = []
            for row in base[field]:
                if row[key] in new:
                    self.assertEqual(set(row), {key, "title", "campaign_revision"})
                restored.append(additions.get(row[key], row))
            self.assertEqual(restored, authored[field])

    def test_missing_revision_metadata_and_incomplete_endings_fail_closed(self):
        value = read("story_campaign.json")
        next(row for row in value["chapters"] if row["quest_id"] in NEW_CHAPTERS).pop("campaign_revision")
        with self.assertRaises(ValueError): split_catalog(value)
        for key in NEW_ENDINGS:
            value = read("community_campaign.json")
            value["ending_rituals"][key].pop()
            with self.assertRaises(ValueError): ending_payload(value)

    def test_compiler_is_idempotent_and_base_has_no_substantial_expansion_prose(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / "data").mkdir()
            for source in (*SOURCES, "story_campaign.json", "community_campaign.json"):
                (project / "data" / source).write_bytes((PROJECT / "data" / source).read_bytes())
            compile_dialogue(project)
            first = {path.relative_to(project).as_posix(): path.read_bytes() for path in (project / "data").rglob("*.json")}
            compile_dialogue(project)
            self.assertEqual(first, {path.relative_to(project).as_posix(): path.read_bytes() for path in (project / "data").rglob("*.json")})
            base = b"".join(path.read_bytes() for path in (project / "data/runtime_dialogue").glob("*.json")) + (project / "data/runtime_story_campaign.json").read_bytes()
            self.assertNotIn(b"campaign_revision_2", base)
            overlay = json.loads((project / "data/community_story_overlay.json").read_bytes())
            rituals, cards = ending_payload(read("community_campaign.json"))
            self.assertEqual(overlay["ending_rituals"], rituals)
            self.assertEqual(overlay["ending_cards"], cards)
            for ending in NEW_ENDINGS:
                self.assertNotIn(json.dumps(cards[ending])[1:-1].encode(), base)

    def test_compact_quest_definitions_keep_exact_runtime_objectives(self):
        for identity in NEW_CHAPTERS:
            row = read("quests.json")[identity]
            self.assertEqual(row["campaign_revision"], 2)
            self.assertEqual(len(row["objectives"]), 4)
            self.assertTrue(all(item["kind"] in ("activity", "choice") for item in row["objectives"]))
            self.assertNotIn("dialogue", row)


if __name__ == "__main__": unittest.main()
