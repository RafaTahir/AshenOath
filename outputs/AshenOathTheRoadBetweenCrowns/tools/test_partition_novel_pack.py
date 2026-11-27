"""Exercise the novel's export selections without running Godot."""

import configparser
import json
from pathlib import Path
import tempfile
import unittest

from partition_novel_pack import partition_novel_pack
from verify_web_preset_parity import filters, selected, selected_files


PROJECT = Path(__file__).resolve().parents[1]


class NovelPack(unittest.TestCase):
    def test_partial_novel_cannot_produce_a_successful_layout(self):
        config = {"opening": {}}
        sections = {"Runtime Pack Opening": "opening"}
        manifest = {"pack_presets": {"opening": "Runtime Pack Opening"}, "packs": {"opening": {}}}
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            directory = project / "data/novel"
            directory.mkdir(parents=True)
            (directory / "act_1.json").write_text("{}", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "act_2.json"):
                partition_novel_pack(project, config, sections, manifest)
        self.assertEqual({"opening": {}}, config)
        self.assertEqual({"opening": {}}, manifest["packs"])

    def test_act_and_prop_roots_belong_only_to_opening_after_regeneration(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read(PROJECT / "export_presets.cfg", encoding="utf-8-sig")
        sections = {json.loads(config[s]["name"]): s for s in config.sections() if "name" in config[s]}
        manifest = json.loads((PROJECT / "runtime_pack_manifest.json").read_text(encoding="utf-8-sig"))
        opening = manifest["pack_presets"]["opening"]
        acts = {f"data/novel/act_{act}.json" for act in range(1, 5)}
        prop = "assets/narrative_props/ferry_rope.tscn"
        draft = "data/novel/authoring_draft.json"
        book = "books/AshenOath_The_Road_Between_Crowns.epub"
        root = config[sections["Web Browser"]]
        root["export_files"] = "PackedStringArray(" + ", ".join(map(json.dumps, sorted(
            selected_files(root) | {"res://" + prop, "res://data/novel/act_1.json"}
        ))) + ")"
        root["include_filter"] = json.dumps(",".join(sorted(filters(root, "include_filter") | {"data/novel/*"})))
        owner = config[sections[opening]]
        owner["include_filter"] = json.dumps(",".join(sorted(filters(owner, "include_filter") | {"data/*.json", "books/*"})))
        owner["exclude_filter"] = json.dumps(",".join(sorted(filters(owner, "exclude_filter") | {"data/novel/*"})))
        manifest["packs"]["base"]["contents"].append("res://data/novel/act_1.json")
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            for path in acts | {prop, draft, book}:
                asset = project / path
                asset.parent.mkdir(parents=True, exist_ok=True)
                asset.touch()
            partition_novel_pack(project, config, sections, manifest)
            before = {section: dict(config[section]) for section in sections.values()}
            contents_before = list(manifest["packs"]["opening"]["contents"])
            partition_novel_pack(project, config, sections, manifest)
            self.assertEqual(before, {section: dict(config[section]) for section in sections.values()})
            self.assertEqual(contents_before, manifest["packs"]["opening"]["contents"])
        for name, section in sections.items():
            with self.subTest(preset=name):
                effective = {path for path in acts | {prop, draft, book} if selected(config[section], "res://" + path)}
                self.assertEqual(acts | {prop} if name == opening else set(), effective)
        self.assertTrue(acts <= filters(owner, "include_filter"))
        self.assertIn("res://" + prop, selected_files(owner))
        self.assertTrue({"res://" + path for path in acts | {prop}} <= set(contents_before))
        self.assertNotIn("res://data/novel/act_1.json", manifest["packs"]["base"]["contents"])
        self.assertIn("opening", manifest["startup_dependencies"])
        for zone, dependencies in manifest["zone_dependencies"].items():
            self.assertIn("opening", dependencies, zone)


if __name__ == "__main__":
    unittest.main()
