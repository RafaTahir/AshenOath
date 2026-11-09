"""Permanent layout fixtures: no engine, network, saves or large asset copies."""
import configparser
import fnmatch
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from partition_living_campaign_packs import COMMUNITY_FILES, BASE_STORY_FILES, SCENERY_FILES, COMPANION_FILES, STATION_OWNERS, STATIONS, partition_living_campaign_packs
from runtime_pack_validation import require_valid_pack_graph
from verify_web_preset_parity import validate_living_ownership


class DeferredOwnership(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ashen-living-layout-")
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name)
        paths = set(COMMUNITY_FILES) | BASE_STORY_FILES | SCENERY_FILES | COMPANION_FILES | {"scripts/campaign_revision.gd", "scripts/save_manager.gd", "data/quests.json", "data/story_campaign.json"}
        paths |= {STATIONS+"station_"+person+".scn" for person in STATION_OWNERS}
        paths |= {STATIONS+"station_"+person+"_00.res" for person in STATION_OWNERS}
        paths |= {STATIONS+"merrow_cup.scn", STATIONS+"merrow_cup_00.res"}
        paths |= {"assets_external/audio/voices/"+directory+"/delivered.ogg" for directory in ("living_cast", "community")}
        for relative in paths:
            path = self.project / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")
        self.voice_manifest = {"lines":[{"path":"res://assets_external/audio/voices/"+directory+"/delivered.ogg", "audio_bytes":7,
                                         "audio_sha256":hashlib.sha256(b"fixture").hexdigest()} for directory in ("living_cast","community")]}
        (self.project / "voice_production_manifest.json").write_text(json.dumps(self.voice_manifest), encoding="utf-8")
        self.config = configparser.ConfigParser(interpolation=None)
        self.sections = {}
        self.manifest = {"packs":{}, "pack_presets":{}, "startup_dependencies":["base", "opening", "actor_c01"],
                         "zone_dependencies":{zone:["base", "opening", "campaign"] for zone in ("lantern_reach", "hearthward", "hart_glade")}}
        packs = {"base":"Runtime Pack Base", "opening":"Runtime Pack Opening", "campaign":"Runtime Pack Campaign", "audio":"Runtime Pack Audio"}
        packs.update({owner:"Runtime Pack "+owner for owner in {*STATION_OWNERS.values(), "actor_c01", "actor_m13"}})
        for index, (pack, name) in enumerate(packs.items()):
            section = "preset."+str(index)
            self.sections[name] = section
            self.config[section] = {"name":json.dumps(name), "export_files":"PackedStringArray()",
                                    "include_filter":json.dumps("scripts/*,data/*,assets_external/audio/*,"+STATIONS+"*.scn,"+STATIONS+"*.res"), "exclude_filter":'""'}
            self.config[section+".options"] = {"variant/extensions_support":"false"}
            self.manifest["packs"][pack] = {"dependencies":[] if pack == "base" else ["base"]}
            self.manifest["pack_presets"][pack] = name

    def compile(self):
        partition_living_campaign_packs(self.project, self.config, self.sections, self.manifest)
        require_valid_pack_graph(self.manifest)

    def owns(self, pack, path):
        section = self.sections[self.manifest["pack_presets"][pack]]
        settings = self.config[section]
        filters = lambda key: json.loads(settings[key]).split(",")
        if any(fnmatch.fnmatchcase(path, pattern) for pattern in filters("exclude_filter") if pattern): return False
        selected = json.loads("["+settings["export_files"].removeprefix("PackedStringArray(").removesuffix(")")+"]")
        return "res://"+path in selected or any(fnmatch.fnmatchcase(path, pattern) for pattern in filters("include_filter") if pattern)

    def test_every_added_resource_has_exactly_one_owner(self):
        self.compile()
        for path, owner in self.manifest["community_resource_owners"].items():
            actual = [pack for pack in self.manifest["packs"] if self.owns(pack, path[6:])]
            self.assertEqual(actual, [owner], path)

    def test_expansion_does_not_join_startup_or_legacy_audio(self):
        self.compile()
        self.assertEqual(self.manifest["startup_dependencies"], ["base", "opening", "actor_c01"])
        for pack in ("base", "opening", "audio"):
            self.assertFalse(self.owns(pack, "assets_external/audio/voices/community/future.ogg"))
            self.assertFalse(self.owns(pack, "assets_external/audio/voices/living_cast/future.ogg"))
        for zone in ("lantern_reach", "hearthward"):
            self.assertIn("community", self.manifest["zone_dependencies"][zone])
        self.assertNotIn("community", self.manifest["zone_dependencies"]["hart_glade"])

    def test_deferred_code_depends_on_base_without_copying_it(self):
        self.compile()
        self.assertFalse(self.owns("community", "scripts/save_manager.gd"))
        self.assertTrue(self.owns("base", "scripts/save_manager.gd"))
        self.assertEqual(self.manifest["packs"]["community"]["dependencies"], ["base"])

    def test_authoring_story_is_not_an_exported_overlay_backdoor(self):
        self.compile()
        for pack in self.manifest["packs"]:
            self.assertFalse(self.owns(pack, "data/story_campaign.json"))
            self.assertEqual(self.owns(pack, "data/community_story_overlay.json"), pack == "community")
            self.assertEqual(self.owns(pack, "data/runtime_story_campaign.json"), pack == "base")

    def test_missing_authored_resource_rejects_layout(self):
        (self.project / STATIONS / "station_nera.scn").unlink()
        with self.assertRaisesRegex(ValueError, "station_nera"):
            self.compile()

    def test_companion_keeps_existing_m13_owner_and_inventory(self):
        self.compile()
        path = "res://" + next(iter(COMPANION_FILES))
        self.assertEqual(self.manifest["actor_resource_owners"][path], "actor_m13")
        self.assertIn(path, self.manifest["packs"]["actor_m13"]["contents"])
        self.assertNotIn(path, self.manifest["packs"]["opening"]["contents"])

    def test_missing_actor_owner_rejects_layout(self):
        self.manifest["pack_presets"].pop("actor_m13")
        with self.assertRaisesRegex(ValueError, "owner pack.*actor_m13"):
            self.compile()

    def test_manifest_does_not_retain_displaced_resource_claims(self):
        path = "res://" + STATIONS + "station_nera.scn"
        self.manifest["packs"]["opening"]["contents"] = [path, "greyfen"]
        self.manifest["actor_resource_owners"] = {path:"opening"}
        self.compile()
        self.assertNotIn(path, self.manifest["packs"]["opening"]["contents"])
        self.assertIn("greyfen", self.manifest["packs"]["opening"]["contents"])
        self.assertIn(path, self.manifest["packs"]["actor_c12"]["contents"])
        self.assertEqual(self.manifest["actor_resource_owners"][path], "actor_c12")

    def test_release_gate_rejects_duplicated_or_inventoried_wrong_owner(self):
        self.compile()
        owners = {pack:self.config[self.sections[name]] for pack, name in self.manifest["pack_presets"].items()}
        root = owners["base"]
        self.assertEqual(validate_living_ownership(self.manifest, owners, root, root), [])
        resource = "res://" + STATIONS + "station_nera.scn"
        self.manifest["packs"]["actor_c12"]["contents"].remove(resource)
        self.assertTrue(any("inventory omits" in error for error in validate_living_ownership(self.manifest, owners, root, root)))
        self.manifest["packs"]["actor_c12"]["contents"].append(resource)
        excluded = json.loads(owners["opening"]["exclude_filter"]).split(",")
        excluded.remove(resource[6:])
        owners["opening"]["exclude_filter"] = json.dumps(",".join(excluded))
        self.assertTrue(any("selected by" in error for error in validate_living_ownership(self.manifest, owners, root, root)))

    def test_empty_voice_pack_is_not_published(self):
        self.voice_manifest["lines"] = self.voice_manifest["lines"][:1]
        (self.project / "voice_production_manifest.json").write_text(json.dumps(self.voice_manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "community_voice has no delivered"):
            self.compile()

    def test_missing_or_corrupt_delivered_voice_rejects_layout(self):
        audio = self.project / "assets_external/audio/voices/community/delivered.ogg"
        audio.write_bytes(b"corrupt")
        with self.assertRaisesRegex(ValueError, "voice bytes differ"):
            self.compile()
        audio.unlink()
        with self.assertRaisesRegex(ValueError, "Missing deferred voice"):
            self.compile()

    def test_unreferenced_recordings_are_not_copied_into_voice_pack(self):
        stale = self.project / "assets_external/audio/voices/community/retired.ogg"
        stale.write_bytes(b"old")
        self.compile()
        self.assertFalse(self.owns("community_voice", stale.relative_to(self.project).as_posix()))

    def test_layout_is_idempotent(self):
        self.compile()
        snapshot = io.StringIO()
        self.config.write(snapshot)
        manifest = json.dumps(self.manifest, sort_keys=True)
        self.compile()
        second = io.StringIO()
        self.config.write(second)
        self.assertEqual(snapshot.getvalue(), second.getvalue())
        self.assertEqual(manifest, json.dumps(self.manifest, sort_keys=True))


if __name__ == "__main__":
    unittest.main(verbosity=2)
