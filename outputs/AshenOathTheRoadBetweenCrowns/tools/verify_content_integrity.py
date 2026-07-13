#!/usr/bin/env python3
"""Validate authored quest, dialogue, and literal runtime content references."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


KNOWN_ACTION_TYPES = {
    "complete_objective",
    "ending",
    "give_ingredients",
    "resolve_side_quest",
    "start_quest",
    "story_choice",
}


def load_json(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"{path.name}: cannot parse JSON: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path.name}: root must be an object")
        return {}
    return value


def iter_actions(entry: dict[str, Any]):
    for action in entry.get("actions", []):
        yield action
    for variant in entry.get("variants", []):
        for action in variant.get("actions", []):
            yield action


def validate_reference(
    source: str,
    quest_id: Any,
    objective_id: Any,
    objectives: dict[str, set[str]],
    errors: list[str],
) -> None:
    quest = str(quest_id or "")
    objective = str(objective_id or "")
    if quest not in objectives:
        errors.append(f"{source}: unknown quest '{quest}'")
    elif objective not in objectives[quest]:
        errors.append(f"{source}: unknown objective '{quest}.{objective}'")


def validate_dialogues(
    project: Path,
    objectives: dict[str, set[str]],
    errors: list[str],
) -> int:
    action_count = 0
    for relative in ("data/dialogue.json", "data/campaign_dialogue.json"):
        entries = load_json(project / relative, errors)
        for dialogue_id, entry in entries.items():
            if not isinstance(entry, dict):
                errors.append(f"{relative}:{dialogue_id}: entry must be an object")
                continue
            for index, action in enumerate(iter_actions(entry)):
                action_count += 1
                source = f"{relative}:{dialogue_id}:action[{index}]"
                if not isinstance(action, dict):
                    errors.append(f"{source}: action must be an object")
                    continue
                action_type = str(action.get("type", ""))
                if action_type not in KNOWN_ACTION_TYPES:
                    errors.append(f"{source}: unsupported action type '{action_type}'")
                if action_type in {"start_quest", "resolve_side_quest"}:
                    quest_id = str(action.get("quest", ""))
                    if quest_id not in objectives:
                        errors.append(f"{source}: unknown quest '{quest_id}'")
                if "quest" in action and "objective" in action:
                    validate_reference(
                        source,
                        action["quest"],
                        action["objective"],
                        objectives,
                        errors,
                    )
                for completion_index, completion in enumerate(action.get("completes", [])):
                    validate_reference(
                        f"{source}:completes[{completion_index}]",
                        completion.get("quest"),
                        completion.get("objective"),
                        objectives,
                        errors,
                    )
    return action_count


def validate_runtime_literals(
    project: Path,
    objectives: dict[str, set[str]],
    errors: list[str],
) -> int:
    game_path = project / "scripts/game.gd"
    source = game_path.read_text(encoding="utf-8")
    references: list[tuple[str, str, str, int]] = []
    method_pattern = re.compile(
        r"quests\.(complete_objective|complete_evidence|is_objective_done)"
        r'\("([^"]+)",\s*"([^"]+)"\)'
    )
    for match in method_pattern.finditer(source):
        references.append(
            (
                match.group(2),
                match.group(3),
                match.group(1),
                source.count("\n", 0, match.start()) + 1,
            )
        )
    clue_pattern = re.compile(
        r'_make_clue\([^\n]*?"([^"]+)",\s*"([^"]+)"\s*,\s*Color'
    )
    for match in clue_pattern.finditer(source):
        references.append(
            (
                match.group(1),
                match.group(2),
                "_make_clue",
                source.count("\n", 0, match.start()) + 1,
            )
        )
    for quest_id, objective_id, method, line in references:
        validate_reference(
            f"scripts/game.gd:{line}:{method}",
            quest_id,
            objective_id,
            objectives,
            errors,
        )
    return len(references)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "project",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    parser.add_argument("--json-report", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    errors: list[str] = []
    quests = load_json(project / "data/quests.json", errors)
    objectives: dict[str, set[str]] = {}
    objective_count = 0
    for quest_id, quest in quests.items():
        if not isinstance(quest, dict):
            errors.append(f"data/quests.json:{quest_id}: quest must be an object")
            continue
        ids = [str(item.get("id", "")) for item in quest.get("objectives", [])]
        if "" in ids:
            errors.append(f"data/quests.json:{quest_id}: objective id cannot be empty")
        if len(ids) != len(set(ids)):
            errors.append(f"data/quests.json:{quest_id}: duplicate objective id")
        objectives[quest_id] = set(ids)
        objective_count += len(ids)
    for quest_id, quest in quests.items():
        if not isinstance(quest, dict):
            continue
        for unlocked_id in quest.get("unlocks", []):
            if unlocked_id not in objectives:
                errors.append(
                    f"data/quests.json:{quest_id}: unknown unlock '{unlocked_id}'"
                )
    action_count = validate_dialogues(project, objectives, errors)
    literal_count = validate_runtime_literals(project, objectives, errors)
    report = {
        "status": "fail" if errors else "pass",
        "quest_count": len(objectives),
        "objective_count": objective_count,
        "dialogue_action_count": action_count,
        "runtime_literal_reference_count": literal_count,
        "errors": errors,
    }
    if args.json_report:
        args.json_report.parent.mkdir(parents=True, exist_ok=True)
        args.json_report.write_text(json.dumps(report, indent=2), encoding="utf-8")
    if errors:
        for error in errors:
            print(f"CONTENT ERROR: {error}")
        print(f"CONTENT INTEGRITY: FAIL ({len(errors)})")
        return 1
    print(
        "CONTENT INTEGRITY: PASS "
        f"({len(objectives)} quests, {objective_count} objectives, "
        f"{action_count} dialogue actions, {literal_count} runtime references)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
