#!/usr/bin/env python3
"""Static GDScript architecture ratchet; Python standard library only."""

from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import unittest


PROJECT = Path(__file__).resolve().parents[1]
BASELINE = Path(__file__).with_name("architecture_baseline.json")
NEW_DIRECTORIES = {"core", "models", "builders", "views"}
RATCHET_METRICS = (
    "lines", "untyped_funcs", "duck_meta_calls", "unseeded_rand_calls", "wallclock_calls",
)
REFLECTION = {"has_method", "call", "get_meta", "set_meta"}
RANDOM = {"randf", "randi", "randf_range", "randi_range"}
SCENE_TYPES = {
    "Node", "Node3D", "Control", "CanvasItem", "Camera3D", "CharacterBody3D",
    "SubViewport", "AnimationPlayer", "AnimationTree", "Node2D", "SceneTree",
}
MARKERS = re.compile(r"TODO|FIXME|HACK")


@dataclass(frozen=True)
class Token:
    value: str
    line: int
    kind: str = "symbol"


@dataclass(frozen=True)
class Function:
    name: str
    line: int
    untyped_parameters: tuple[Token, ...]
    typed_return: bool


@dataclass
class Analysis:
    metrics: dict
    tokens: list[Token]
    functions: list[Function]
    locations: dict[str, list[int]]


@dataclass(frozen=True, order=True)
class Diagnostic:
    path: str
    line: int
    rule: str
    message: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: {self.rule}: {self.message}"


def lex(text: str) -> list[Token]:
    """Keep string arguments and line numbers, but never tokenize their contents as code."""
    result: list[Token] = []
    i, line = 0, 1
    while i < len(text):
        char = text[i]
        if char.isspace() or char == "\ufeff":
            line += char == "\n"
            i += 1
        elif char == "#":
            end = text.find("\n", i)
            i = len(text) if end < 0 else end
        elif char in "\"'":
            delimiter = char * (3 if text.startswith(char * 3, i) else 1)
            start_line = line
            i += len(delimiter)
            start = i
            while i < len(text) and not text.startswith(delimiter, i):
                if text[i] == "\\" and i + 1 < len(text):
                    line += text[i + 1] == "\n"
                    i += 2
                else:
                    line += text[i] == "\n"
                    i += 1
            result.append(Token(text[start:i], start_line, "string"))
            i += len(delimiter)
        elif char.isalpha() or char == "_":
            start = i
            i += 1
            while i < len(text) and (text[i].isalnum() or text[i] == "_"):
                i += 1
            result.append(Token(text[start:i], line, "identifier"))
        else:
            value = text[i:i + 2] if text[i:i + 2] in {"->", ":="} else char
            result.append(Token(value, line))
            i += len(value)
    return result


def parameter_groups(tokens: list[Token]) -> list[list[Token]]:
    groups: list[list[Token]] = []
    current: list[Token] = []
    depth = 0
    for token in tokens:
        if token.kind == "symbol":
            if token.value == "," and depth == 0:
                if current:
                    groups.append(current)
                current = []
                continue
            depth += token.value in {"(", "[", "{"}
            depth -= token.value in {")", "]", "}"}
        current.append(token)
    if current:
        groups.append(current)
    return groups


def functions(tokens: list[Token]) -> list[Function]:
    result: list[Function] = []
    for index, token in enumerate(tokens):
        if token.kind != "identifier" or token.value != "func":
            continue
        cursor = index + 1
        name = "<lambda>"
        if cursor < len(tokens) and tokens[cursor].kind == "identifier":
            name = tokens[cursor].value
            cursor += 1
        if cursor >= len(tokens) or tokens[cursor].value != "(":
            result.append(Function(name, token.line, (), False))
            continue
        opening, depth = cursor, 1
        cursor += 1
        while cursor < len(tokens) and depth:
            if tokens[cursor].kind == "symbol":
                depth += tokens[cursor].value == "("
                depth -= tokens[cursor].value == ")"
            cursor += 1
        if depth:
            result.append(Function(name, token.line, (), False))
            continue
        parameters = parameter_groups(tokens[opening + 1:cursor - 1])
        untyped = tuple(group[0] for group in parameters if not (
            len(group) >= 3 and group[0].kind == "identifier"
            and group[1].value == ":" and group[2].kind == "identifier"
        ))
        typed_return = (cursor + 1 < len(tokens) and tokens[cursor].value == "->"
                        and tokens[cursor + 1].kind == "identifier")
        result.append(Function(name, token.line, untyped, typed_return))
    return result


def calls(tokens: list[Token]):
    for index, token in enumerate(tokens[:-1]):
        if token.kind != "identifier" or tokens[index + 1].value != "(":
            continue
        if index and tokens[index - 1].value == "func":
            continue
        yield index, token


def analyze(text: str) -> Analysis:
    tokens = lex(text)
    signatures = functions(tokens)
    locations: dict[str, list[int]] = {name: [] for name in RATCHET_METRICS}
    for signature in signatures:
        if signature.untyped_parameters or not signature.typed_return:
            locations["untyped_funcs"].append(signature.line)
    for index, token in calls(tokens):
        if token.value in REFLECTION:
            locations["duck_meta_calls"].append(token.line)
        if token.value in RANDOM and (not index or tokens[index - 1].value != "."):
            locations["unseeded_rand_calls"].append(token.line)
        if (token.value.startswith("get_ticks_") and index >= 2
                and [t.value for t in tokens[index - 2:index]] == ["Time", "."]):
            locations["wallclock_calls"].append(token.line)
    proxies = [f.name for f in signatures if f.name in {"_get", "_set"}]
    metrics = {name: len(locations[name]) for name in RATCHET_METRICS}
    metrics["lines"] = len(text.splitlines())
    metrics["has_dynamic_get_set"] = bool(proxies)
    # A bool alone would miss adding _set to an existing _get owner (or inner class).
    metrics["dynamic_get_set_funcs"] = sorted(proxies)
    return Analysis(metrics, tokens, signatures, locations)


def check_source(path: str, text: str, baseline: dict | None) -> list[Diagnostic]:
    source = analyze(text)
    parts = PurePosixPath(path).parts
    strict = len(parts) >= 3 and parts[0] == "scripts" and parts[1] in NEW_DIRECTORIES
    model = strict and parts[1] == "models"
    errors: list[Diagnostic] = []

    def report(line: int, rule: str, message: str) -> None:
        errors.append(Diagnostic(path, line, rule, message))

    for index, token in calls(source.tokens):
        if token.value == "get_node":
            argument = index + 2
            if argument < len(source.tokens) and source.tokens[argument].value == "^":
                argument += 1
            if (argument < len(source.tokens) and source.tokens[argument].kind == "string"
                    and source.tokens[argument].value.startswith("..")):
                report(token.line, "parent-node", "get_node parent traversal is forbidden")
        if strict and token.value in REFLECTION:
            report(token.line, "new-reflection", f"{token.value}() is forbidden in new modules")
        if model and token.value in RANDOM | {"get_tree"}:
            report(token.line, "model-scene-free", f"{token.value}() is forbidden in models")
    if strict:
        if source.metrics["lines"] > 400:
            report(401, "new-lines", f"{source.metrics['lines']} lines exceeds 400")
        for signature in source.functions:
            for parameter in signature.untyped_parameters:
                report(parameter.line, "new-parameter-type", f"{signature.name}: type parameter {parameter.value}")
            if not signature.typed_return:
                report(signature.line, "new-return-type", f"{signature.name}: explicit -> ReturnType required")
            if signature.name in {"_get", "_set"}:
                report(signature.line, "new-dynamic-proxy", f"{signature.name}() is forbidden")
        for line, value in enumerate(text.splitlines(), 1):
            for match in MARKERS.finditer(value):
                report(line, "new-debt-marker", f"{match.group()} is forbidden")
    if model:
        for signature in source.functions:
            if signature.name in RANDOM | {"get_tree"}:
                report(signature.line, "model-scene-free", f"{signature.name}() is forbidden in models")
        for token in source.tokens:
            if token.kind == "identifier" and token.value in SCENE_TYPES | {"direct_space_state"}:
                report(token.line, "model-scene-free", f"{token.value} is a scene dependency")
        for index, token in enumerate(source.tokens[:-2]):
            if (token.kind == "identifier" and token.value == "Time"
                    and source.tokens[index + 1].value == "."
                    and source.tokens[index + 2].value.startswith("get_ticks_")):
                report(token.line, "model-scene-free", "Time.get_ticks_* is forbidden in models")
    if baseline is None:
        if not strict:
            report(1, "legacy-unbaselined", "new modules must use core/, models/, builders/ or views/")
        return sorted(set(errors))
    for name in RATCHET_METRICS:
        actual, allowed = source.metrics[name], baseline[name]
        if actual > allowed:
            locations = source.locations[name]
            line = allowed + 1 if name == "lines" else locations[min(allowed, len(locations) - 1)]
            report(line, f"legacy-{name}", f"{actual} exceeds baseline {allowed}")
    allowed_proxies = Counter(baseline["dynamic_get_set_funcs"])
    seen: Counter[str] = Counter()
    for signature in source.functions:
        if signature.name in {"_get", "_set"}:
            seen[signature.name] += 1
            if seen[signature.name] > allowed_proxies[signature.name]:
                report(signature.line, "legacy-dynamic-proxy", f"new {signature.name}() proxy")
    return sorted(set(errors))


def validate_baseline(value: object) -> dict:
    if not isinstance(value, dict) or value.get("schema_version") != 1 or value.get("scan_root") != "scripts":
        raise ValueError("expected schema_version 1 and scan_root scripts; regenerate explicitly")
    files = value.get("files")
    if not isinstance(files, dict) or not files:
        raise ValueError("baseline files must be a nonempty object")
    for path, metrics in files.items():
        pure = PurePosixPath(path)
        if (pure.is_absolute() or ".." in pure.parts or "\\" in path
                or not path.startswith("scripts/") or not path.endswith(".gd")):
            raise ValueError(f"invalid baseline path: {path}")
        if not isinstance(metrics, dict):
            raise ValueError(f"invalid metrics: {path}")
        for name in RATCHET_METRICS:
            if type(metrics.get(name)) is not int or metrics[name] < 0:
                raise ValueError(f"invalid {name}: {path}")
        proxies = metrics.get("dynamic_get_set_funcs")
        if (not isinstance(proxies, list) or any(p not in {"_get", "_set"} for p in proxies)
                or type(metrics.get("has_dynamic_get_set")) is not bool
                or metrics["has_dynamic_get_set"] != bool(proxies)):
            raise ValueError(f"invalid dynamic proxy inventory: {path}")
    return files


def scan() -> dict[str, str]:
    return {path.relative_to(PROJECT).as_posix(): path.read_text(encoding="utf-8-sig")
            for path in sorted((PROJECT / "scripts").rglob("*.gd"))}


def write_baseline(sources: dict[str, str]) -> None:
    try:
        commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=PROJECT, check=True,
                                capture_output=True, text=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        commit = None
    value = {
        "schema_version": 1, "scan_root": "scripts", "source_commit": commit,
        "definitions": {
            "lines": "Physical splitlines count, including blank/comment lines.",
            "untyped_funcs": "Named functions or lambdas missing any parameter type or explicit return type.",
            "duck_meta_calls": "Executable has_method/call/get_meta/set_meta calls; excludes definitions/comments/strings.",
            "unseeded_rand_calls": "Global randf/randi/randf_range/randi_range calls; not owned RNG methods.",
            "wallclock_calls": "Executable Time.get_ticks_* calls.",
            "has_dynamic_get_set": "Presence of _get/_set definitions; companion inventory prevents new proxies.",
        },
        "files": {path: analyze(text).metrics for path, text in sources.items()},
    }
    validate_baseline(value)
    BASELINE.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"ARCHITECTURE BASELINE WRITTEN: {len(sources)} files; {sum(m['lines'] for m in value['files'].values())} lines")


class ArchitectureTests(unittest.TestCase):
    def rules(self, text: str, path: str = "scripts/core/example.gd", baseline=None) -> set[str]:
        return {error.rule for error in check_source(path, text, baseline)}

    def test_valid_typed_modules(self):
        source = '''extends RefCounted
func apply(
    values: Dictionary[String, Array[int]] = {"tuple": [1, 2]},
    node_name: String = "Node3D .call( get_meta( randf( Time.get_ticks_usec()",
) -> Array[int]:
    var mapped: Callable = func(value: int) -> int: return value + 1
    return values.get(node_name, [])
'''
        for directory in sorted(NEW_DIRECTORIES):
            with self.subTest(directory=directory):
                self.assertFalse(self.rules(source, f"scripts/{directory}/valid.gd"))

    def test_line_limit(self):
        self.assertFalse(self.rules("# fine\n" * 400))
        self.assertIn("new-lines", self.rules("# long\n" * 401))

    def test_parameter_annotations(self):
        for signature in ['func f(value) -> void:', 'func f(value = {"x": 1}) -> void:',
                          'func f(value := 1) -> void:', 'var cb = func(value) -> int: return 1']:
            with self.subTest(signature=signature):
                self.assertIn("new-parameter-type", self.rules(signature))

    def test_return_annotations(self):
        for signature in ['func f():', 'func f(value: int):', 'var cb = func(): return 1', 'func f() ->:']:
            with self.subTest(signature=signature):
                self.assertIn("new-return-type", self.rules(signature))

    def test_reflection(self):
        for call in ['other.has_method("run")', 'other . call\n("run")',
                     'get_meta("id")', 'other.set_meta("id", 1)', 'has_method("x")', 'call("x")']:
            with self.subTest(call=call):
                self.assertIn("new-reflection", self.rules(call))

    def test_debt_markers(self):
        for marker in ["TODO", "FIXME", "HACK"]:
            with self.subTest(marker=marker):
                self.assertIn("new-debt-marker", self.rules(f"# {marker}: unfinished\n"))
                self.assertIn("new-debt-marker", self.rules(f'const NOTE: String = "{marker}"'))
                self.assertIn("new-debt-marker", self.rules(f"# {marker}_later\n"))

    def test_dynamic_proxies(self):
        for name in ["_get", "_set"]:
            with self.subTest(name=name):
                self.assertIn("new-dynamic-proxy", self.rules(f"func {name}() -> void: pass"))

    def test_parent_node_global_rule(self):
        for text in ['get_node("..")', "self.get_node('../Sibling')", 'get_node(^"../A")',
                     'get_node # comment\n ("../A")', "get_node('''../A''')"]:
            for path in ["scripts/legacy.gd", "scripts/views/valid.gd"]:
                with self.subTest(text=text, path=path):
                    self.assertIn("parent-node", self.rules(text, path, analyze(text).metrics))
        self.assertNotIn("parent-node", self.rules('get_node("Child")'))

    def test_model_scene_types(self):
        for name in sorted(SCENE_TYPES | {"direct_space_state"}):
            with self.subTest(name=name):
                self.assertIn("model-scene-free", self.rules(f"var value: {name}", "scripts/models/data.gd"))

    def test_model_runtime_calls(self):
        for expression in ["get_tree()", "Time.get_ticks_msec()", "Time.get_ticks_usec()",
                           "var clock: Callable = Time.get_ticks_usec",
                           *[f"{name}()" for name in sorted(RANDOM)], "rng.randf()",
                           "func get_tree() -> void: pass", "func randf() -> float: return 0.0"]:
            with self.subTest(expression=expression):
                self.assertIn("model-scene-free", self.rules(expression, "scripts/models/data.gd"))

    def test_code_not_comments_or_strings(self):
        text = '''# func fake(value): other.call("x"); randf(); Time.get_ticks_usec()
const EXAMPLE: String = "get_node(\\"..\\")"
var text: String = """func _get(value):
other.has_method('f'); randi(); Time.get_ticks_msec()
"""
func valid(value: int) -> void: pass
'''
        metrics = analyze(text).metrics
        for name in RATCHET_METRICS[1:]:
            self.assertEqual(metrics[name], 0, name)
        self.assertFalse(metrics["has_dynamic_get_set"])
        self.assertFalse(self.rules(text))

    def test_owned_rng_and_wallclock_counts(self):
        text = "\n".join(["randf()", "randi()", "randf_range(0, 1)", "randi_range(0, 1)",
                          "rng.randf()", "rng.randi()", "Time . get_ticks_usec ()", "timer.get_ticks_msec()"])
        self.assertEqual(analyze(text).metrics["unseeded_rand_calls"], 4)
        self.assertEqual(analyze(text).metrics["wallclock_calls"], 1)
        self.assertFalse(self.rules("var rng: RandomNumberGenerator\nfunc sample() -> float: return rng.randf()"))

    def test_legacy_ratchet_every_metric(self):
        baseline = analyze("").metrics
        for metric, text in {
            "lines": "# addition", "untyped_funcs": "func untyped(value): pass",
            "duck_meta_calls": 'value.call("x")', "unseeded_rand_calls": "randf()",
            "wallclock_calls": "Time.get_ticks_usec()",
        }.items():
            with self.subTest(metric=metric):
                self.assertIn(f"legacy-{metric}", self.rules(text, "scripts/legacy.gd", baseline))

    def test_legacy_proxy_addition_to_existing_proxy(self):
        old = "func _get(key): return null\n"
        new = old + "func _set(key, value): return false\n"
        self.assertIn("legacy-dynamic-proxy", self.rules(new, "scripts/legacy.gd", analyze(old).metrics))
        self.assertIn("legacy-dynamic-proxy", self.rules(old, "scripts/legacy.gd", analyze("").metrics))

    def test_legacy_unchanged_and_reductions(self):
        old = 'func run(value):\n    other.call("x")\n    return randf()\n'
        baseline = analyze(old).metrics
        self.assertFalse(self.rules(old, "scripts/legacy.gd", baseline))
        self.assertFalse(self.rules("func run(value: int) -> int: return value\n", "scripts/legacy.gd", baseline))

    def test_new_legacy_file_cannot_escape(self):
        self.assertIn("legacy-unbaselined", self.rules("", "scripts/untracked_legacy.gd"))
        self.assertFalse(self.rules("extends RefCounted\n", "scripts/models/nested/model.gd"))

    def test_bom_crlf_multiline_defaults(self):
        text = '\ufefffunc f(\r\n    value: Array[int] = [1, 2],\r\n) -> void:\r\n    pass\r\n'
        self.assertEqual(analyze(text).metrics["lines"], 4)
        self.assertFalse(self.rules(text))

    def test_signatures_are_not_calls(self):
        metrics = analyze("func call(value: String) -> void: pass\nfunc randf() -> float: return 0.0").metrics
        self.assertEqual(metrics["duck_meta_calls"], 0)
        self.assertEqual(metrics["unseeded_rand_calls"], 0)

    def test_baseline_validation(self):
        good = {"schema_version": 1, "scan_root": "scripts", "files": {"scripts/old.gd": analyze("").metrics}}
        self.assertEqual(len(validate_baseline(good)), 1)
        for field, value in [("lines", -1), ("untyped_funcs", True), ("has_dynamic_get_set", 1),
                             ("dynamic_get_set_funcs", ["_unknown"])]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                bad = json.loads(json.dumps(good))
                bad["files"]["scripts/old.gd"][field] = value
                validate_baseline(bad)
        with self.assertRaises(ValueError):
            validate_baseline({**good, "schema_version": 2})

    def test_diagnostic_format_and_location(self):
        errors = check_source("scripts/views/example.gd", "# first\n\nfunc f(value): pass", None)
        self.assertTrue(any(str(e).startswith("scripts/views/example.gd:3: new-parameter-type:") for e in errors))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--write-baseline", action="store_true", help="explicitly snapshot current per-file debt")
    modes.add_argument("--self-test", action="store_true", help="run static checker unit tests; no Godot execution")
    arguments = parser.parse_args(argv)
    if arguments.self_test:
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(ArchitectureTests)
        return 0 if unittest.TextTestRunner(verbosity=1).run(suite).wasSuccessful() else 1
    try:
        sources = scan()
        if not sources:
            raise ValueError("no scripts/**/*.gd files found")
        if arguments.write_baseline:
            write_baseline(sources)
            return 0
        files = validate_baseline(json.loads(BASELINE.read_text(encoding="utf-8")))
        errors = [error for path, text in sources.items() for error in check_source(path, text, files.get(path))]
    except (OSError, UnicodeError, ValueError, TypeError) as error:
        print(f"tools/architecture_baseline.json:1: baseline-config: {error}", file=sys.stderr)
        return 2
    for error in sorted(errors):
        print(error)
    if errors:
        print(f"ARCHITECTURE FAIL: {len(errors)} violation(s) in {len(sources)} files")
        return 1
    print(f"ARCHITECTURE PASS: {len(sources)} files; no ratchet or module-boundary violations")
    return 0


if __name__ == "__main__":
    sys.exit(main())
