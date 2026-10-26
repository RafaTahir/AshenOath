"""Regression coverage for authored companion choices and rejected bad content."""

from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from verify_content_integrity import iter_actions, validate_dialogues


PROJECT = Path(__file__).resolve().parents[1]


class CompanionChoiceContractTests(unittest.TestCase):
    def setUp(self) -> None:
        dialogue = json.loads((PROJECT / "data/dialogue.json").read_text())
        self.rescue = dialogue["bracken_rescue"]
        quests = json.loads((PROJECT / "data/quests.json").read_text())
        self.objectives = {
            quest_id: {item["id"] for item in quest.get("objectives", [])}
            for quest_id, quest in quests.items()
        }

    def validate(self, entry: dict) -> tuple[int, list[str]]:
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            (project / "data").mkdir()
            (project / "data/dialogue.json").write_text(
                json.dumps({"bracken_rescue": entry})
            )
            (project / "data/campaign_dialogue.json").write_text("{}")
            errors: list[str] = []
            count = validate_dialogues(project, self.objectives, errors)
            return count, errors

    def test_all_authored_rescue_and_care_variants_are_valid(self) -> None:
        count, errors = self.validate(self.rescue)
        self.assertEqual(count, 8)
        self.assertEqual(errors, [])
        # Actor identity must still be supplied by runtime dialogue staging.
        for action in iter_actions(self.rescue):
            self.assertNotIn("companion_actor_instance", action)

    def test_missing_unknown_and_non_string_operations_are_rejected(self) -> None:
        for operation in (None, "", "relese", ["calm"], {"step": "calm"}, 1):
            with self.subTest(operation=operation):
                entry = copy.deepcopy(self.rescue)
                action = entry["actions"][0]
                if operation is None:
                    action.pop("companion_action")
                else:
                    action["companion_action"] = operation
                count, errors = self.validate(entry)
                self.assertEqual(count, 8)
                self.assertEqual(len(errors), 1)
                self.assertIn("unsupported companion_action", errors[0])

    def test_variant_operations_are_checked(self) -> None:
        entry = copy.deepcopy(self.rescue)
        entry["variants"][0]["actions"][1]["companion_action"] = "fead"
        _, errors = self.validate(entry)
        self.assertEqual(len(errors), 1)
        self.assertIn("unsupported companion_action", errors[0])

    def test_unknown_action_types_still_fail(self) -> None:
        entry = copy.deepcopy(self.rescue)
        entry["actions"][0]["type"] = "companion_choise"
        _, errors = self.validate(entry)
        self.assertEqual(len(errors), 1)
        self.assertIn("unsupported action type", errors[0])

    def test_companion_choices_retain_quest_reference_validation(self) -> None:
        entry = copy.deepcopy(self.rescue)
        entry["actions"][0].update({
            "quest": "side_bracken_rescue",
            "objective": "missing_objective",
            "completes": [{"quest": "missing_quest", "objective": "calm_hound"}],
        })
        _, errors = self.validate(entry)
        self.assertEqual(len(errors), 2)
        self.assertTrue(any("unknown objective" in error for error in errors))
        self.assertTrue(any("unknown quest" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
