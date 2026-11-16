#!/usr/bin/env python3
"""Standard-library schema/reference checks for authored JSON and script resources."""
from __future__ import annotations

import json
import math
from pathlib import Path
import re
import subprocess
import sys

from check_architecture import lex

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
PREFIX = PROJECT.relative_to(REPO).as_posix() + "/"


def unique_object(pairs: list[tuple[str, object]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def invalid_constant(value: str) -> None:
    raise ValueError(f"non-finite JSON number {value}")


def finite_float(value: str) -> float:
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f"non-finite JSON number {value}")
    return result


def read_json(path: Path) -> dict | list:
    value = json.loads(path.read_text(encoding="utf-8-sig"),
                       object_pairs_hook=unique_object, parse_constant=invalid_constant,
                       parse_float=finite_float)
    if not isinstance(value, (dict, list)):
        raise ValueError("data root must be an object or array")
    return value


def literal_dictionary(source: str, name: str) -> dict:
    """Parse a JSON-compatible constant, tokenizing away GDScript comments first."""
    tokens = lex(source)
    for index, token in enumerate(tokens):
        if token.kind != "identifier" or token.value != "const":
            continue
        if tokens[index + 1].value != name:
            continue
        opening = next(i for i in range(index + 2, len(tokens)) if tokens[i].value == "{")
        depth = 0
        parts: list[str] = []
        for current in tokens[opening:]:
            parts.append(json.dumps(current.value) if current.kind == "string" else current.value)
            if current.kind == "symbol":
                depth += current.value == "{"
                depth -= current.value == "}"
            if depth == 0:
                return json.loads("".join(parts), object_pairs_hook=unique_object)
    raise ValueError(f"required constant {name} was not found")


def check_json(errors: list[str]) -> tuple[int, int]:
    documents: dict = {}
    for path in sorted((PROJECT / "data").glob("*.json")):
        try:
            documents[path.stem] = read_json(path)
        except (ValueError, OSError) as exc:
            errors.append(f"{path.relative_to(PROJECT)}: {exc}")
    items, vendors, quests = (documents.get(name, {}) for name in ("items", "vendors", "quests"))
    for name, value in (("items", items), ("vendors", vendors), ("quests", quests)):
        if not isinstance(value, dict) or not value:
            errors.append(f"data/{name}.json: expected a nonempty definition map")
            return len(documents), 0
    references = 0

    def item_ref(value: object, where: str) -> None:
        nonlocal references
        references += 1
        if not isinstance(value, str) or value not in items:
            errors.append(f"{where}: unknown item {value!r}")

    for item_id, item in items.items():
        if not isinstance(item, dict) or not all(isinstance(item.get(k), str) and item[k] for k in ("name", "type")):
            errors.append(f"data/items.json:{item_id}: requires name/type strings")
    for vendor_id, vendor in vendors.items():
        if not isinstance(vendor, dict) or not isinstance(vendor.get("stock"), list):
            errors.append(f"data/vendors.json:{vendor_id}: requires stock array")
            continue
        seen: set[str] = set()
        for entry in vendor["stock"]:
            where = f"data/vendors.json:{vendor_id}"
            if not isinstance(entry, dict):
                errors.append(f"{where}: stock entry must be an object")
                continue
            item_id = entry.get("item_id")
            item_ref(item_id, where)
            if isinstance(item_id, str):
                if item_id in seen:
                    errors.append(f"{where}: duplicate stock item {item_id}")
                seen.add(item_id)
            for field, minimum in (("price", 0), ("cap", 1)):
                value = entry.get(field)
                if type(value) is not int or value < minimum:
                    errors.append(f"{where}:{item_id}: {field} must be an integer >= {minimum}")
            if entry.get("requires_quest") and entry["requires_quest"] not in quests:
                errors.append(f"{where}: unknown required quest {entry['requires_quest']}")
    for quest_id, quest in quests.items():
        where = f"data/quests.json:{quest_id}"
        if not isinstance(quest, dict) or not isinstance(quest.get("objectives"), list) or not isinstance(quest.get("title"), str):
            errors.append(f"{where}: requires title and objectives array")
            continue
        seen: set[str] = set()
        for objective in quest["objectives"]:
            if not isinstance(objective, dict):
                errors.append(f"{where}: objective must be an object")
                continue
            objective_id = objective.get("id")
            if not isinstance(objective_id, str) or not objective_id or objective_id in seen:
                errors.append(f"{where}: missing/duplicate objective id {objective_id!r}")
            else:
                seen.add(objective_id)
            if not isinstance(objective.get("text"), str):
                errors.append(f"{where}:{objective_id}: requires text")
            if "optional" in objective and type(objective["optional"]) is not bool:
                errors.append(f"{where}:{objective_id}: optional must be boolean")
        unlocks = quest.get("unlocks", [])
        if not isinstance(unlocks, list):
            errors.append(f"{where}: unlocks must be an array")
        else:
            for next_id in unlocks:
                if not isinstance(next_id, str) or next_id not in quests:
                    errors.append(f"{where}: unknown unlocked quest {next_id!r}")

        def quest_items(value: object, location: str) -> None:
            if isinstance(value, dict):
                for key, child in value.items():
                    if key == "item_id":
                        item_ref(child, location)
                    elif key == "items" and isinstance(child, dict):
                        for reward_id in child:
                            item_ref(reward_id, location)
                    else:
                        quest_items(child, location + "." + key)
            elif isinstance(value, list):
                for child in value:
                    quest_items(child, location)

        quest_items(quest, where)
    model = PROJECT / "scripts/models/vendor_economy_model.gd"
    try:
        buyback = literal_dictionary(model.read_text(encoding="utf-8"), "BUYBACK")
        for vendor_id, offers in buyback.items():
            if vendor_id not in vendors or not isinstance(offers, dict):
                errors.append(f"{model.name}: invalid buyback vendor {vendor_id}")
                continue
            for item_id in offers:
                item_ref(item_id, f"{model.name}:BUYBACK:{vendor_id}")
    except (ValueError, OSError, StopIteration) as exc:
        errors.append(f"{model.name}: {exc}")
    return len(documents), references


def source_files() -> dict[str, str]:
    tracked = subprocess.run(["git", "ls-files", "-z", "--", PREFIX], cwd=REPO,
                             check=True, capture_output=True).stdout.decode().split("\0")
    index = PROJECT / "docs/archive/phase5-index.json"
    moved = {entry["original_path"] for entry in read_json(index)["moved"]} if index.is_file() else set()
    paths = {path for path in tracked if path.endswith((".gd", ".tscn")) and "/docs/archive/" not in path and path not in moved}
    for suffix in ("*.gd", "*.tscn"):
        for path in PROJECT.rglob(suffix):
            if ".godot" not in path.parts and "/docs/archive/" not in path.as_posix():
                paths.add(path.relative_to(REPO).as_posix())
    result: dict[str, str] = {}
    for name in sorted(paths):
        path = REPO / name
        if path.is_file():
            result[name] = path.read_text(encoding="utf-8-sig")
        else:
            # Sparse checkouts still validate tracked scenes outside the working set.
            content = subprocess.run(["git", "show", ":" + name], cwd=REPO, check=True, capture_output=True)
            result[name] = content.stdout.decode("utf-8-sig")
    return result


def check_scripts(errors: list[str]) -> tuple[int, int]:
    sources = source_files()
    checked = 0
    for name, source in sources.items():
        for token in lex(source):
            value = token.value
            if token.kind != "string" or not value.startswith("res://scripts/") or not value.endswith(".gd"):
                continue
            # Formatted resource paths need runtime arguments; they are not static preloads.
            if any(marker in value for marker in ("%", "{", "*")):
                continue
            checked += 1
            target = PREFIX + value.removeprefix("res://")
            if target not in sources:
                errors.append(f"{name}:{token.line}: missing or case-mismatched script {value}")
    return len(sources), checked


def main() -> int:
    errors: list[str] = []
    documents, items = check_json(errors)
    sources, scripts = check_scripts(errors)
    for error in errors:
        print(error, file=sys.stderr)
    print(f"CONTENT {'FAIL' if errors else 'PASS'}: {documents} JSON documents; "
          f"{items} item references; {sources} active GDScript/scenes; {scripts} static script references")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
