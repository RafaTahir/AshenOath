"""Small release-tool fixtures; never export, run Godot, or contact a server."""
import configparser
import fnmatch
import gzip
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import build_web_runtime_manifest as builder
import prepare_runtime_pack_layout as layout
import verify_web_preset_parity as parity
from deployment_policy import POLICY, size_summary
from runtime_pack_artifacts import artifact_plan, copy_runtime_pack_artifacts, copy_shell_assets
from runtime_pack_validation import validate_pack_graph
from prepared_forest_tree_layout import SOURCES as FOREST_SOURCES
from web_release_contract import effective_headers, hosting_errors, hud_identity_errors

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]


class Fixture(unittest.TestCase):
    def setUp(self):
        temp_root = Path("D:/Temp/AshenOath")
        temp_root.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="release-tools-", dir=temp_root)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def pack_manifest(self, ids=("opening", "opening_materials", "adjacent", "future_region")):
        packs = {"base": {"status": "embedded_current_pck", "version": "fixture", "url": "", "sha256": "", "bytes": 0, "dependencies": []}}
        source = self.root / "native-packs"
        source.mkdir(exist_ok=True)
        for pack_id in ids:
            payload = b"GDPCfixture:" + pack_id.encode()
            digest = hashlib.sha256(payload).hexdigest()
            (source / (pack_id + ".pck")).write_bytes(payload)
            packs[pack_id] = {"status": "streamed_web_candidate", "version": "fixture", "url": f"packs/{pack_id}.pck?sha256={digest}", "sha256": digest,
                              "cache_key": digest, "bytes": len(payload), "dependencies": ["base"]}
        return {"packs": packs}, source

    def package(self):
        manifest, source = self.pack_manifest(("opening", "quality_materials"))
        manifest.update(release_id="fixture", generated_from_commit="0" * 40,
                        max_deployment_bytes=POLICY["max_deployment_bytes"], deployment_policy_id=POLICY["id"])
        export = self.root / "export"
        export.mkdir()
        copy_runtime_pack_artifacts(export, manifest, source)
        for path in (export / "packs").glob("*.pck"):
            path.write_bytes(gzip.compress(path.read_bytes()))
        (export / "index.pck").write_bytes(gzip.compress(b"GDPCroot"))
        (export / "index.wasm").write_bytes(gzip.compress(b"\x00asmfixture"))
        (export / "index.js").write_text("// fixture", encoding="utf-8")
        (export / "index.html").write_text('const SHELL_BUILD_ID = "fixture"; const RUNTIME_PACK_CONTRACT = "fixture";', encoding="utf-8")
        runtime_path = export / "runtime_pack_manifest.json"
        runtime_path.write_text(json.dumps(manifest), encoding="utf-8")
        release = builder.build_manifest(export, runtime_path, "0" * 40)
        (export / "release_manifest.json").write_text(json.dumps(release), encoding="utf-8")
        return export, manifest, release

    def preset_project(self):
        project = self.root / "project"
        (project / "data").mkdir(parents=True, exist_ok=True)
        for relative in ["export_presets.cfg", "runtime_pack_manifest.json", "runtime_asset_manifest.json",
                         "curated_asset_manifest.json", "curated_runtime_assets.json", "visual_upgrade_manifest.json", "data/prepared_actors.json",
                         "data/design_pack_assets.json", "data/environment_material_dependencies.json",
                         "data/environment_export_retirements.json",
                         "data/zone_actor_requirements.json", "data/design_pack_ecology.json"]:
            source = PROJECT / relative
            if source.is_file():
                shutil.copyfile(source, project / relative)
        return project


class GraphValidation(Fixture):
    def test_diamond_and_embedded_dependencies_are_valid(self):
        graph = {"packs": {"base": {}, "a": {"dependencies": ["base"]}, "b": {"dependencies": ["base"]},
                           "leaf": {"dependencies": ["a", "b"]}}}
        self.assertEqual([], validate_pack_graph(graph))

    def test_malformed_unknown_and_cycles_are_rejected(self):
        for graph, message in [([], "must be an object"), ({"packs": []}, "packs object"),
                               ({"packs": {"a": {"dependencies": "a"}}}, "list of pack IDs"),
                               ({"packs": {"a": {"dependencies": [4]}}}, "list of pack IDs"),
                               ({"packs": {"a": {"dependencies": ["missing"]}}}, "unknown dependency"),
                               ({"packs": {"a": {"dependencies": ["a"]}}}, "a -> a"),
                               ({"packs": {"base": {"dependencies": ["opening"]}, "opening": {"dependencies": ["base"]}}}, "base -> opening -> base")]:
            with self.subTest(graph=graph):
                self.assertIn(message, "; ".join(validate_pack_graph(graph)))

    def test_valid_package_inspection_passes(self):
        export, _manifest, _release = self.package()
        self.assertEqual("fixture", builder.inspect_packaged_export(export)["build_id"])

    def test_package_inspector_rejects_hash_valid_cyclic_graph(self):
        export, manifest, release = self.package()
        manifest["packs"]["base"]["dependencies"] = ["opening"]
        runtime = export / "runtime_pack_manifest.json"
        runtime.write_text(json.dumps(manifest), encoding="utf-8")
        record = next(item for item in release["artifacts"] if item["path"] == "runtime_pack_manifest.json")
        previous_bytes = record["bytes"]
        record.update(bytes=runtime.stat().st_size, sha256=hashlib.sha256(runtime.read_bytes()).hexdigest())
        release["runtime_pack_manifest"] = record
        release["artifacts_total_bytes"] += record["bytes"] - previous_bytes
        next(pack for pack in release["packs"] if pack["id"] == "base")["dependencies"] = ["opening"]
        release["size_summary"] = size_summary(release["artifacts"], manifest)
        (export / "release_manifest.json").write_text(json.dumps(release), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "cyclic"):
            builder.inspect_packaged_export(export)

    def test_builder_rejects_cycle_before_changing_shell(self):
        export, manifest, _release = self.package()
        manifest["packs"]["base"]["dependencies"] = ["opening"]
        runtime = export / "runtime_pack_manifest.json"
        runtime.write_text(json.dumps(manifest), encoding="utf-8")
        shell_before = (export / "index.html").read_bytes()
        with self.assertRaisesRegex(ValueError, "cyclic"):
            builder.build_manifest(export, runtime, "0" * 40)
        self.assertEqual(shell_before, (export / "index.html").read_bytes())

    def test_sync_rejects_cycle_before_writing_manifest_or_candidate(self):
        manifest = self.root / "runtime_pack_manifest.json"
        manifest.write_text(json.dumps({"packs": {"base": {"dependencies": ["base"]}}}), encoding="utf-8")
        before = manifest.read_bytes()
        result = subprocess.run([sys.executable, "-B", str(PROJECT / "tools/sync_runtime_pack_manifest.py"), str(manifest), str(self.root / "missing-candidates.json")], capture_output=True, timeout=20)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("cyclic", result.stderr.decode(errors="replace"))
        self.assertEqual(before, manifest.read_bytes())
        self.assertFalse((self.root / "runtime_pack_candidates.json").exists())

    def test_runtime_validator_reports_malformed_graph_and_numeric_fields_without_traceback(self):
        manifest = {"max_deployment_bytes": "invalid", "packs": {"base": {"dependencies": {}, "bytes": "invalid"}}}
        (self.root / "runtime_pack_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        result = subprocess.run([sys.executable, "-B", str(PROJECT / "tools/verify_runtime_packs.py"), str(self.root)], capture_output=True, timeout=20)
        self.assertEqual(1, result.returncode)
        self.assertIn("list of pack IDs", result.stdout.decode(errors="replace"))
        self.assertNotIn("Traceback", result.stderr.decode(errors="replace"))

    def test_layout_invalid_generated_graph_leaves_both_outputs_untouched(self):
        project = self.preset_project()
        actors = json.loads((project / "data/prepared_actors.json").read_text(encoding="utf-8"))
        # Use only inputs necessary for the layout calculation; the fixture does
        # not load or modify the shared authored/imported assets.
        for actor in actors.values():
            actor["resource_dependencies"] = []
            actor["material_bindings"] = {}
            actor["animation_resources"] = []
        (project / "data/prepared_actors.json").write_text(json.dumps(actors), encoding="utf-8")
        (project / "data/environment_material_dependencies.json").write_text('{"textures":{}}', encoding="utf-8")
        runtime_assets = json.loads((project / "runtime_asset_manifest.json").read_text(encoding="utf-8"))
        for record in runtime_assets["roles"].values():
            for resource in record.get("runtime_files", []):
                if resource["path"].endswith((".png", ".jpg", ".jpeg", ".webp")):
                    target = project / resource["path"].removeprefix("res://")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.touch()
        runtime_path = project / "runtime_pack_manifest.json"
        runtime = json.loads(runtime_path.read_text(encoding="utf-8"))
        runtime["packs"]["base"]["dependencies"] = ["opening"]
        runtime_path.write_text(json.dumps(runtime), encoding="utf-8")
        before = [(path, path.read_bytes()) for path in [runtime_path, project / "export_presets.cfg"]]
        with patch.object(layout, "PROJECT", project), patch.object(layout, "prepared_source_exclusions", return_value=set()), patch.object(layout, "load_prepared_forest_trees", return_value={}):
            with self.assertRaisesRegex(ValueError, "cyclic"):
                layout.compile_layout()
        for path, content in before:
            self.assertEqual(content, path.read_bytes())


class ForestLayout(Fixture):
    def test_prepared_tree_owner_and_raw_exclusions_survive_full_layout_compilation(self):
        project = self.preset_project()
        actors_path = project / "data/prepared_actors.json"
        actors = json.loads(actors_path.read_text(encoding="utf-8"))
        for actor in actors.values():
            actor.update(resource_dependencies=[], material_bindings=[], animation_resources=[])
        actors_path.write_text(json.dumps(actors), encoding="utf-8")
        (project / "data/environment_material_dependencies.json").write_text('{"textures":{}}', encoding="utf-8")
        runtime_assets = json.loads((project / "runtime_asset_manifest.json").read_text(encoding="utf-8"))
        for record in runtime_assets["roles"].values():
            for resource in record.get("runtime_files", []):
                if resource["path"].endswith((".png", ".jpg", ".jpeg", ".webp")):
                    target = project / resource["path"].removeprefix("res://")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.touch()
        forest = {source: {"path": prepared} for source, prepared in FOREST_SOURCES.items()}
        with patch.object(layout, "PROJECT", project), patch.object(layout, "prepared_source_exclusions", return_value=set()), patch.object(layout, "load_prepared_forest_trees", return_value=forest):
            layout.compile_layout()
        config = configparser.ConfigParser(interpolation=None)
        config.read(project / "export_presets.cfg", encoding="utf-8")
        for section in config.sections():
            if "name" not in config[section]:
                continue
            name = json.loads(config[section]["name"])
            selected = set(layout.selected_files(config[section]["export_files"]))
            excluded = json.loads(config[section]["exclude_filter"]).split(",")
            for source, prepared in FOREST_SOURCES.items():
                self.assertNotIn(source, selected)
                self.assertTrue(any(fnmatch.fnmatchcase(source.removeprefix("res://"), pattern) for pattern in excluded), (name, source))
                if name == "Runtime Pack Opening":
                    self.assertIn(prepared, selected)
                    self.assertFalse(any(fnmatch.fnmatchcase(prepared.removeprefix("res://"), pattern) for pattern in excluded))
                else:
                    self.assertNotIn(prepared, selected)
                    self.assertTrue(any(fnmatch.fnmatchcase(prepared.removeprefix("res://"), pattern) for pattern in excluded))
            if name in layout.ROOT_NAMES:
                self.assertIn("data/prepared_forest_trees.json", json.loads(config[section]["include_filter"]).split(","))
        RetirementPolicy.assert_retired(self, config)


class RetirementPolicy(Fixture):
    def policy(self):
        return json.loads((PROJECT / layout.ENVIRONMENT_RETIREMENTS).read_text(encoding="utf-8"))

    def assert_retired(self, config):
        policy = json.loads((PROJECT / layout.ENVIRONMENT_RETIREMENTS).read_text(encoding="utf-8"))
        for section in config.sections():
            if "name" not in config[section]:
                continue
            values = config[section]
            name = json.loads(values["name"])
            for source in policy["retired_source_roots"]:
                self.assertNotIn(source, layout.selected_files(values["export_files"]), name)
                self.assertNotIn(source.removeprefix("res://"), parity.filters(values, "include_filter"), name)
                self.assertFalse(parity.selected(values, source), (name, source))
            if name == "Runtime Pack Opening":
                for path in policy["required_authored_roots"]:
                    self.assertTrue(parity.selected(values, path), path)

    def test_regenerated_presets_keep_authored_houses_and_no_retired_import_roots(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read(PROJECT / "export_presets.cfg", encoding="utf-8-sig")
        sections = {json.loads(config[s]["name"]): s for s in config.sections() if "name" in config[s]}
        # Presets are generated from the integration checkout's compiled inputs;
        # apply the source policy in memory without rewriting tracked presets.
        layout.retire_environment_export_roots(PROJECT, config, sections)
        self.assert_retired(config)
        for path in self.policy()["retired_source_roots"] + self.policy()["required_authored_roots"]:
            self.assertTrue((PROJECT / path.removeprefix("res://")).is_file(), path)
        anchor = (PROJECT / "scripts/runtime_asset_anchor.gd").read_text(encoding="utf-8")
        for source in self.policy()["retired_source_roots"]:
            self.assertNotIn(source, anchor)
        self.assertIn('preload("res://assets_external/animations/AnimationLibrary_Godot_Opening.tres")', anchor)

    def test_obsolete_common_tree_does_not_hide_prepared_tree_or_shared_textures(self):
        retired_tree = "res://assets_external/environment/forest/CommonTree_1.obj"
        prepared_tree = "res://assets_external/environment/prepared/forest_tree_CommonTree_5.res"
        texture = "res://assets_external/environment/forest/Bark_NormalTree_Normal.png"
        self.assertIn(retired_tree, self.policy()["retired_source_roots"])
        self.assertNotIn("res://assets_external/environment/forest/CommonTree_5.obj", self.policy()["retired_source_roots"])
        config = configparser.ConfigParser(interpolation=None)
        config.read(PROJECT / "export_presets.cfg", encoding="utf-8-sig")
        sections = {json.loads(config[s]["name"]): s for s in config.sections() if "name" in config[s]}
        opening = config[sections["Runtime Pack Opening"]]
        opening["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(p) for p in (retired_tree, prepared_tree, texture)) + ")"
        opening["include_filter"] = json.dumps("assets_external/environment/forest/*.obj")
        opening["exclude_filter"] = '""'
        layout.retire_environment_export_roots(PROJECT, config, sections)
        self.assertFalse(parity.selected(opening, retired_tree))
        self.assertTrue(parity.selected(opening, prepared_tree))
        self.assertTrue(parity.selected(opening, texture))

    def test_exact_and_wildcard_reintroductions_are_retired_without_texture_blacklist(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read(PROJECT / "export_presets.cfg", encoding="utf-8-sig")
        sections = {json.loads(config[s]["name"]): s for s in config.sections() if "name" in config[s]}
        opening = config[sections["Runtime Pack Opening"]]
        sources = set(self.policy()["retired_source_roots"])
        textures = {"res://assets_external/environment/village/T_" + stem + "_Normal.png"
                    for stem in ("Plaster", "WoodTrim", "UnevenBrick", "Brick", "RockTrim")}
        opening["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(p) for p in sorted(sources | textures)) + ")"
        opening["include_filter"] = json.dumps(",".join(["assets_external/environment/village/*.obj", *(p.removeprefix("res://") for p in sources)]))
        opening["exclude_filter"] = '""'
        layout.retire_environment_export_roots(PROJECT, config, sections)
        self.assert_retired(config)
        for texture in textures:
            self.assertTrue(parity.selected(opening, texture), texture)

    def test_policy_rejects_accidental_texture_retirement_before_mutation(self):
        project = self.preset_project()
        path = project / layout.ENVIRONMENT_RETIREMENTS
        policy = self.policy()
        policy["retired_source_roots"] = ["res://assets_external/environment/village/T_Plaster_Normal.png"]
        path.write_text(json.dumps(policy), encoding="utf-8")
        config = configparser.ConfigParser(interpolation=None)
        config.read(project / "export_presets.cfg", encoding="utf-8-sig")
        sections = {json.loads(config[s]["name"]): s for s in config.sections() if "name" in config[s]}
        before = {name: dict(config[section]) for name, section in sections.items()}
        with self.assertRaisesRegex(ValueError, "retirement policy"):
            layout.retire_environment_export_roots(project, config, sections)
        self.assertEqual(before, {name: dict(config[section]) for name, section in sections.items()})


class ArtifactCopy(Fixture):
    def test_manifest_copy_includes_split_and_future_packs_but_not_embedded_base(self):
        manifest, source = self.pack_manifest()
        export = self.root / "custom-output"
        copy_runtime_pack_artifacts(export, manifest, source)
        self.assertEqual({"opening.pck", "opening_materials.pck", "adjacent.pck", "future_region.pck"},
                         {path.name for path in (export / "packs").iterdir()})
        self.assertFalse((export / "packs/base.pck").exists())

    def test_missing_corrupt_or_wrong_hash_input_does_not_copy_partial_output(self):
        for kind in ["missing", "corrupt", "hash"]:
            with self.subTest(kind=kind):
                manifest, source = self.pack_manifest()
                path = source / "future_region.pck"
                if kind == "missing":
                    path.unlink()
                else:
                    path.write_bytes(b"broken" if kind == "corrupt" else b"GDPCwrong")
                export = self.root / kind
                with self.assertRaises((OSError, ValueError)):
                    copy_runtime_pack_artifacts(export, manifest, source)
                self.assertFalse(export.exists())

    def test_unsafe_source_and_destination_paths_are_rejected(self):
        for path in ["../outside.pck", "packs/%2e%2e/outside.pck", "/packs/opening.pck", "https://elsewhere.invalid/packs/opening.pck", "packs/C:/outside.pck"]:
            manifest, source = self.pack_manifest()
            manifest["packs"]["opening"]["url"] = path
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "inside exported packs"):
                artifact_plan(manifest, source)
        manifest, source = self.pack_manifest()
        manifest["packs"]["opening"]["candidate_artifact"] = "../outside.pck"
        with self.assertRaisesRegex(ValueError, "escapes pack directory"):
            artifact_plan(manifest, source)

    def test_gzip_source_is_validated_as_decoded_bytes(self):
        manifest, source = self.pack_manifest(("opening",))
        path = source / "opening.pck"
        path.write_bytes(gzip.compress(path.read_bytes()))
        self.assertEqual(1, len(artifact_plan(manifest, source)))

    def test_required_shell_asset_is_copied_and_missing_asset_fails(self):
        project, export = self.root / "project", self.root / "export"
        export.mkdir()
        with self.assertRaisesRegex(ValueError, "shell asset is missing"):
            copy_shell_assets(export, project)
        image = project / "assets_external/ui/greyfen_menu_stylized.png"
        image.parent.mkdir(parents=True)
        image.write_bytes(b"fixture image")
        copy_shell_assets(export, project)
        self.assertEqual(image.read_bytes(), (export / "menu-background.png").read_bytes())

    @unittest.skipUnless(os.name == "nt", "Windows batch failure propagation")
    def test_batch_child_failure_returns_nonzero_without_export_or_source_write(self):
        stub = self.root / "powershell.cmd"
        stub.write_text("@exit /b 7\n", encoding="ascii")
        godot = self.root / "godot.cmd"
        godot.write_text("@exit /b 9\n", encoding="ascii")
        env = dict(os.environ, PATH=str(self.root) + os.pathsep + os.environ["PATH"], GODOT_BIN=str(godot),
                   ASHEN_OATH_PACK_DIRECTORY=str(self.root / "packs"), ASHEN_OATH_WEB_DIRECTORY=str(self.root / "export"))
        env.pop("ASHEN_OATH_REUSE_PACKS", None)
        self.assertEqual(stub.resolve(), Path(shutil.which("powershell", path=env["PATH"])).resolve())
        runtime = PROJECT / "runtime_pack_manifest.json"
        before = runtime.read_bytes()
        result = subprocess.run(["cmd", "/d", "/c", str(PROJECT / "Export_Web_Build.bat")], env=env, capture_output=True, timeout=20)
        self.assertNotEqual(0, result.returncode, result.stdout.decode(errors="replace"))
        self.assertEqual(before, runtime.read_bytes())
        self.assertFalse((self.root / "export").exists())


class WebContracts(Fixture):
    def test_current_separate_header_rules_combine_and_queries_do_not_change_policy(self):
        config = json.loads((REPO / "vercel.json").read_text(encoding="utf-8"))
        self.assertEqual([], hosting_errors(config))
        headers = effective_headers(config, "/index.pck?fixture=1")
        self.assertEqual("gzip", headers["content-encoding"])
        self.assertIn("must-revalidate", headers["cache-control"])

    def test_later_header_overrides_and_bad_encoding_are_rejected(self):
        config = json.loads((REPO / "vercel.json").read_text(encoding="utf-8"))
        config["headers"].append({"source": "/index.pck", "headers": [{"key": "CACHE-CONTROL", "value": "immutable"}, {"key": "Content-Encoding", "value": "identity"}]})
        errors = "; ".join(hosting_errors(config))
        self.assertIn("no-cache", errors)
        self.assertIn("gzip", errors)

    def test_wrong_runtime_policy_and_host_output_are_rejected(self):
        config = json.loads((REPO / "vercel.json").read_text(encoding="utf-8"))
        config["headers"] = [rule for rule in config["headers"] if rule["source"] != "/packs/(.*)"]
        config["outputDirectory"] = "other"
        errors = "; ".join(hosting_errors(config))
        self.assertIn("immutable", errors)
        self.assertIn("tracked web/", errors)

    def hud_project(self):
        project = self.root / "hud-project"
        (project / "scripts/hud").mkdir(parents=True)
        for name in ["hud_state.gd", "hud_api.gd", "hud_component.gd", "menu_panel.gd"]:
            shutil.copyfile(PROJECT / "scripts/hud" / name, project / "scripts/hud" / name)
        return project

    def test_current_hud_identity_needs_no_ticket_or_hostname(self):
        self.assertEqual([], hud_identity_errors(self.hud_project()))

    def test_missing_inconsistent_or_unrendered_hud_label_fails(self):
        project = self.hud_project()
        state = project / "scripts/hud/hud_state.gd"
        state.write_text('const MENU_BUILD_LABEL = ""\n', encoding="utf-8")
        self.assertIn("missing", "; ".join(hud_identity_errors(project)))
        state.write_text('const MENU_BUILD_LABEL = "ASHEN OATH OTHER"\n', encoding="utf-8")
        self.assertIn("disagree", "; ".join(hud_identity_errors(project)))
        (project / "scripts/hud/menu_panel.gd").write_text("# no menu label\n", encoding="utf-8")
        self.assertIn("does not render", "; ".join(hud_identity_errors(project)))

    def test_current_catalog_preset_parity_passes(self):
        runtime = json.loads((PROJECT / "runtime_pack_manifest.json").read_text(encoding="utf-8-sig"))
        actors = json.loads((PROJECT / "data/prepared_actors.json").read_text(encoding="utf-8-sig"))
        self.assertTrue(any(runtime["actor_resource_owners"][actor["path"]] != actor["owner"] for actor in actors.values()),
                        "Fixture must exercise delivery ownership differing from compilation batches")
        parity.validate(PROJECT / "export_presets.cfg")

    def test_extra_qa_resource_missing_duplicate_actor_or_missing_quality_maps_fails(self):
        for kind, name in [("qa", "Web QA Browser"), ("actor", "Runtime Pack Opening"),
                           ("duplicate", "Runtime Pack Characters"), ("quality", "Runtime Pack Quality Materials")]:
            project = self.preset_project()
            config = configparser.ConfigParser(interpolation=None)
            config.read(project / "export_presets.cfg", encoding="utf-8-sig")
            presets = {section.get("name", "").strip('"'): section for section in config.values()}
            section = presets[name]
            runtime = json.loads((project / "runtime_pack_manifest.json").read_text(encoding="utf-8"))
            actor = next(iter(json.loads((project / "data/prepared_actors.json").read_text(encoding="utf-8")).values()))
            resource = actor["path"]
            if kind == "qa":
                patterns = json.loads(section["include_filter"]) + ",assets/qa_extra/*"
            elif kind == "duplicate":
                selected = parity.selected_files(section) | {resource}
                section["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(path) for path in sorted(selected)) + ")"
                relative = resource.removeprefix("res://")
                exclusions = [pattern for pattern in parity.filters(section, "exclude_filter")
                              if not fnmatch.fnmatchcase(relative, pattern)]
                section["exclude_filter"] = json.dumps(",".join(sorted(exclusions)))
                patterns = json.loads(section["include_filter"])
            elif kind == "quality":
                patterns = ",".join(pattern for pattern in json.loads(section["include_filter"]).split(",") if "*_normal.jpg" not in pattern)
            else:
                owner = runtime["actor_resource_owners"][resource]
                section = presets[runtime["pack_presets"][owner]]
                selected = parity.selected_files(section) - {resource}
                section["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(path) for path in sorted(selected)) + ")"
                patterns = json.loads(section["include_filter"])
            section["include_filter"] = json.dumps(patterns)
            with (project / "export_presets.cfg").open("w", encoding="utf-8") as output:
                config.write(output, space_around_delimiters=False)
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, "QA includes extra|missing current prepared actor|duplicates|Quality pack lacks"):
                parity.validate(project / "export_presets.cfg")

    def test_explicit_actor_registry_cannot_omit_or_name_unknown_owner(self):
        for owner in (None, "missing_actor_pack"):
            project = self.preset_project()
            path = project / "runtime_pack_manifest.json"
            runtime = json.loads(path.read_text(encoding="utf-8"))
            actor = next(iter(json.loads((project / "data/prepared_actors.json").read_text(encoding="utf-8")).values()))
            if owner is None:
                runtime["actor_resource_owners"].pop(actor["path"])
            else:
                runtime["actor_resource_owners"][actor["path"]] = owner
            path.write_text(json.dumps(runtime), encoding="utf-8")
            with self.subTest(owner=owner), self.assertRaisesRegex(ValueError, "prepared actor"):
                parity.validate(project / "export_presets.cfg")


if __name__ == "__main__":
    unittest.main()
