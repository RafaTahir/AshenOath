#!/usr/bin/env python3
"""Prevent stale diagnostic realm IDs from reaching real world construction."""
import json
from pathlib import Path
import tempfile
import unittest

from run_monster_vitality_capture import PROJECT, target_preflight


class CaptureTargetTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="ashen_monster_targets_")
        self.addCleanup(self.directory.cleanup)
        self.project = Path(self.directory.name)
        for relative in ("scripts/zone_composition_router.gd", "tools/capture_monster_vitality.gd", "data/design_pack_ecology.json"):
            path = self.project / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((PROJECT / relative).read_bytes())
        self.profiles = json.loads((PROJECT / "data/monster_material_profiles.json").read_bytes())

    def test_current_twenty_species_use_registered_realms(self):
        result = target_preflight(self.project, self.profiles)
        self.assertEqual(len(result["assets"]), 20)
        self.assertEqual(result["assets"]["M03"]["zone"], "wychwood")
        self.assertEqual(result["assets"]["M05"]["zone"], "greyfen")

    def test_rejects_review_reproduction_standalone_cemetery(self):
        path = self.project / "tools/capture_monster_vitality.gd"
        source = path.read_text(encoding="utf-8")
        source = source.replace('"role":"bell_eater", "zone":"greyfen"', '"role":"bell_eater", "zone":"cemetery"')
        path.write_text(source, encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "M05 / cemetery"):
            target_preflight(self.project, self.profiles)

    def test_rejects_unregistered_ecology_realm(self):
        path = self.project / "data/design_pack_ecology.json"
        data = json.loads(path.read_bytes())
        data["sightings"][0]["zone"] = "unknown_marsh"
        path.write_text(json.dumps(data), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unknown_marsh"):
            target_preflight(self.project, self.profiles)

    def test_rejects_unreadable_authoritative_registry(self):
        path = self.project / "scripts/zone_composition_router.gd"
        path.write_text("extends RefCounted\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "authoritative literal zone registry"):
            target_preflight(self.project, self.profiles)


if __name__ == "__main__":
    unittest.main()
