"""Exercise the novel's export selections without running Godot."""

import configparser
import json
from pathlib import Path
import tempfile
import unittest

from partition_novel_pack import FIELD_PACK_PATHS, FIELD_VIEW_DEPENDENCIES, TYPED_FIELD_RUNTIME, partition_novel_pack
from runtime_pack_validation import require_valid_pack_graph
from verify_web_preset_parity import filters, selected, selected_files


PROJECT = Path(__file__).resolve().parents[1]


class NovelPack(unittest.TestCase):
    def test_runtime_layer_requires_field_assets_even_when_all_are_missing(self):
        config = {"opening": {}}
        sections = {"Runtime Pack Opening": "opening"}
        manifest = {"pack_presets": {"opening": "Runtime Pack Opening"}, "packs": {"opening": {}}}
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            runtime = project / TYPED_FIELD_RUNTIME
            runtime.parent.mkdir(parents=True)
            runtime.touch()
            with self.assertRaisesRegex(ValueError, "Novel field resources missing") as caught:
                partition_novel_pack(project, config, sections, manifest)
        for paths in FIELD_PACK_PATHS.values():
            for path in paths:
                self.assertIn(path, str(caught.exception))
        self.assertEqual({"opening": {}}, config)
        self.assertEqual({"Runtime Pack Opening": "opening"}, sections)
        self.assertEqual({"opening": {}}, manifest["packs"])

    def test_stale_field_presets_restore_resource_selection_and_exact_inventory(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read_dict({
            "preset.0": {"name": '"Runtime Pack Opening"'},
            "preset.1": {"name": '"Runtime Pack Campaign"', "export_filter": '"resources"'},
            "preset.1.options": {"custom_template/debug": '""'},
        })
        sections = {"Runtime Pack Opening": "preset.0", "Runtime Pack Campaign": "preset.1"}
        manifest = {
            "pack_presets": {"opening": "Runtime Pack Opening", "campaign": "Runtime Pack Campaign"},
            "packs": {"base": {}, "opening": {}, "campaign": {}},
            "startup_dependencies": ["base", "opening"], "zone_dependencies": {"greyfen": ["base", "opening"]},
        }
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            for path in set().union(*FIELD_PACK_PATHS.values()):
                asset = project / path
                asset.parent.mkdir(parents=True, exist_ok=True)
                asset.touch()
            partition_novel_pack(project, config, sections, manifest)
            before = {section: dict(config[section]) for section in config.sections()}
            inventory_before = json.dumps(manifest, sort_keys=True)
            for pack_id in FIELD_PACK_PATHS:
                preset = config[sections[manifest["pack_presets"][pack_id]]]
                preset["export_filter"] = '"all_resources"'
                preset["export_files"] = 'PackedStringArray("res://assets/raw/source.blend")'
                preset["include_filter"] = '"assets/*"'
                preset["exclude_filter"] = json.dumps(",".join(sorted(filters(preset, "exclude_filter") | {"assets/*"})))
                record = manifest["packs"][pack_id]
                record["contents"].extend(["old_mill", "res://scripts/novel/field_cast.gd"])
                record["dependencies"] = ["opening"]
                record["required_at_startup"] = True
            partition_novel_pack(project, config, sections, manifest)
        self.assertEqual(before, {section: dict(config[section]) for section in config.sections()})
        self.assertEqual(inventory_before, json.dumps(manifest, sort_keys=True))
        for pack_id in FIELD_PACK_PATHS:
            self.assertEqual('"resources"', config[sections[manifest["pack_presets"][pack_id]]]["export_filter"])
        require_valid_pack_graph(manifest)

    def test_incomplete_field_closure_cannot_change_layout(self):
        config = {"opening": {}}
        sections = {"Runtime Pack Opening": "opening"}
        manifest = {"pack_presets": {"opening": "Runtime Pack Opening"}, "packs": {"opening": {}}}
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            field = project / "assets/narrative_props/field"
            field.mkdir(parents=True)
            (field / "willow.tscn").touch()
            with self.assertRaisesRegex(ValueError, "gallery_art.scn"):
                partition_novel_pack(project, config, sections, manifest)
        self.assertEqual({"opening": {}}, config)
        self.assertEqual({"Runtime Pack Opening": "opening"}, sections)
        self.assertEqual({"opening": {}}, manifest["packs"])

    def test_field_closures_have_unique_demand_owners_and_no_inherited_roots(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read(PROJECT / "export_presets.cfg", encoding="utf-8-sig")
        sections = {json.loads(config[s]["name"]): s for s in config.sections() if "name" in config[s]}
        manifest = json.loads((PROJECT / "runtime_pack_manifest.json").read_text(encoding="utf-8-sig"))
        campaign = sections["Runtime Pack Campaign"]
        options = dict(config[campaign + ".options"])
        field_paths = set().union(*FIELD_PACK_PATHS.values())
        self.assertEqual({"novel_field_willow": 13, "novel_field_gallery": 3, "novel_field_culvert": 10},
                         {pack: len(paths) for pack, paths in FIELD_PACK_PATHS.items()})
        self.assertEqual(26, len(field_paths))
        common = {f"data/novel/act_{act}.json" for act in range(1, 5)} | {
            "assets/narrative_props/library.json", "assets/narrative_props/crow/OrenPaintedCrow.tscn"}
        extras = {"assets/narrative_props/field/authoring_draft.tscn",
                  "assets/narrative_props/field/source.blend", "assets/narrative_props/field/unused.res"}
        helpers = {"scripts/novel/field_" + name + ".gd" for name in ("body_pose", "cast", "performances")}
        stale = "res://assets/narrative_props/field/willow.tscn"
        for section in sections.values():
            config[section]["export_files"] = "PackedStringArray(" + json.dumps(stale) + ")"
            config[section]["include_filter"] = json.dumps("assets/narrative_props/*")
            config[section]["exclude_filter"] = json.dumps("assets/narrative_props/*")
        config[campaign]["exclude_filter"] = json.dumps("assets/narrative_props/*,assets/*")
        for record in manifest["packs"].values():
            record.setdefault("contents", []).append(stale)
        field_ids = set(FIELD_PACK_PATHS)
        manifest["packs"]["opening"].setdefault("dependencies", []).extend(sorted(field_ids))
        manifest["startup_dependencies"].extend(sorted(field_ids))
        manifest["zone_dependencies"]["greyfen"].extend(sorted(field_ids))
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            for path in field_paths | common | extras | helpers | FIELD_VIEW_DEPENDENCIES | {TYPED_FIELD_RUNTIME}:
                asset = project / path
                asset.parent.mkdir(parents=True, exist_ok=True)
                asset.touch()
            partition_novel_pack(project, config, sections, manifest)
            config_before = {section: dict(config[section]) for section in config.sections()}
            manifest_before = json.dumps(manifest, sort_keys=True)
            sections_before = dict(sections)
            partition_novel_pack(project, config, sections, manifest)
        self.assertEqual(config_before, {section: dict(config[section]) for section in config.sections()})
        self.assertEqual(manifest_before, json.dumps(manifest, sort_keys=True))
        self.assertEqual(sections_before, sections)
        require_valid_pack_graph(manifest)
        for pack_id, paths in FIELD_PACK_PATHS.items():
            name = manifest["pack_presets"][pack_id]
            preset = config[sections[name]]
            expected = {"res://" + path for path in paths}
            self.assertEqual('"resources"', preset["export_filter"])
            self.assertEqual(expected, selected_files(preset), pack_id)
            self.assertEqual(set(), filters(preset, "include_filter"), pack_id)
            self.assertEqual(options, dict(config[sections[name] + ".options"]))
            self.assertEqual(expected, set(manifest["packs"][pack_id]["contents"]))
            self.assertEqual(["base"], manifest["packs"][pack_id]["dependencies"])
            self.assertFalse(manifest["packs"][pack_id]["required_at_startup"])
        for name, section in sections.items():
            for path in field_paths | common | extras | helpers | FIELD_VIEW_DEPENDENCIES:
                if path in field_paths:
                    owner = next(pack for pack, paths in FIELD_PACK_PATHS.items() if path in paths)
                    wanted = name == manifest["pack_presets"][owner]
                elif path in FIELD_VIEW_DEPENDENCIES:
                    wanted = name in {"Web Browser", "Web QA Browser"}
                else:
                    wanted = path in common and name == manifest["pack_presets"]["opening"]
                self.assertEqual(wanted, selected(config[section], "res://" + path), (name, path))
        self.assertFalse(field_ids.intersection(manifest["startup_dependencies"]))
        for zone, dependencies in manifest["zone_dependencies"].items():
            self.assertFalse(field_ids.intersection(dependencies), zone)
        for pack, record in manifest["packs"].items():
            self.assertFalse(field_ids.intersection(record.get("dependencies", [])), pack)
            if pack not in field_ids:
                self.assertFalse({"res://" + path for path in field_paths}.intersection(record.get("contents", [])), pack)

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
        catalog = "assets/narrative_props/library.json"
        props = {
            "assets/narrative_props/bell/ElnaBell.tscn",
            "assets/narrative_props/brace/tor_left_wrist_brace.tscn",
            "assets/narrative_props/crow/OrenPaintedCrow.tscn",
            "assets/narrative_props/crow/OrenWrappedCrow.tscn",
            "assets/narrative_props/strongbox/merrow_strongbox.tscn",
        }
        novel_paths = acts | props | {catalog}
        draft = "data/novel/authoring_draft.json"
        book = "books/AshenOath_The_Road_Between_Crowns.epub"
        root = config[sections["Web Browser"]]
        root["export_files"] = "PackedStringArray(" + ", ".join(map(json.dumps, sorted(
            selected_files(root) | {"res://assets/narrative_props/brace/tor_left_wrist_brace.tscn",
                                    "res://data/novel/act_1.json"}
        ))) + ")"
        root["include_filter"] = json.dumps(",".join(sorted(
            filters(root, "include_filter") | {"data/novel/*", "assets/narrative_props/*"}
        )))
        owner = config[sections[opening]]
        owner["include_filter"] = json.dumps(",".join(sorted(filters(owner, "include_filter") | {"data/*.json", "books/*"})))
        owner["exclude_filter"] = json.dumps(",".join(sorted(
            filters(owner, "exclude_filter") | {"data/novel/*", "assets/narrative_props/*"}
        )))
        manifest["packs"]["base"]["contents"].append("res://data/novel/act_1.json")
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            for path in novel_paths | {draft, book}:
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
                effective = {path for path in novel_paths | {draft, book}
                             if selected(config[section], "res://" + path)}
                self.assertEqual(novel_paths if name == opening else set(), effective)
        self.assertTrue(acts | {catalog} <= filters(owner, "include_filter"))
        self.assertTrue({"res://" + path for path in props} <= selected_files(owner))
        self.assertTrue({"res://" + path for path in novel_paths} <= set(contents_before))
        self.assertNotIn("res://data/novel/act_1.json", manifest["packs"]["base"]["contents"])
        self.assertIn("opening", manifest["startup_dependencies"])
        for zone, dependencies in manifest["zone_dependencies"].items():
            self.assertIn("opening", dependencies, zone)


if __name__ == "__main__":
    unittest.main()
