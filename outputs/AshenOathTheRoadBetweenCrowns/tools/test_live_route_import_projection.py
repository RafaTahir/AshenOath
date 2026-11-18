"""Disposable filesystem fixtures for import provenance; no engine launches."""
from pathlib import Path
import json
import struct
import tempfile
import unittest

from live_route_import_projection import STAFF, STAFF_IMAGES, native_staff_images, prepare_projection, validate_projection, validate_prepared_identity
from run_monster_vitality_capture import junction


class ImportProjectionEvidence(unittest.TestCase):
    def setUp(self):
        self.root = Path("D:/Temp/AO_MonsterVitality_20261118/pure_live_route_tests").resolve()
        self.root.mkdir(parents=True,exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=self.root,prefix="imports_")
        self.folder = Path(self.temporary.name).resolve()
        self.baseline, self.candidate = self.folder/"baseline", self.folder/"candidate"
        for project in (self.baseline,self.candidate):
            (project/"assets/ui").mkdir(parents=True)
            (project/".godot").mkdir()
        self.cache = self.folder/"shared_imported"
        self.cache.mkdir()
        junction(self.baseline/".godot/imported",self.cache)
        junction(self.candidate/".godot/imported",self.cache)
        self.receipt = self.folder/"projection.json"

    def tearDown(self):
        self.assertTrue(self.folder.resolve().is_relative_to(self.root))
        self.temporary.cleanup()

    def remap(self,name="font.ttf",existing=False,source=None,destination=None):
        for project in (self.baseline,self.candidate): (project/"assets/ui"/name).write_bytes(b"same genuine source bytes")
        artifact = name+".fixturedata"
        (self.cache/artifact).write_bytes(b"fixture imported bytes")
        text = '[remap]\nimporter="fixture"\ntype="FontFile"\npath="'+(destination or "res://.godot/imported/"+artifact)+'"\n\n[deps]\nsource_file="'+(source or "res://assets/ui/"+name)+'"\ndest_files=["'+(destination or "res://.godot/imported/"+artifact)+'"]\n'
        supplied = self.candidate/"assets/ui"/(name+".import")
        supplied.write_text(text)
        if existing: (self.baseline/"assets/ui"/(name+".import")).write_bytes(text.replace("\n","\r\n").encode())
        return supplied

    def prepare(self):
        return prepare_projection(self.baseline,self.candidate,self.receipt)

    def test_missing_remap_projects_identical_source_and_existing_bytes_stay_exact(self):
        supplied = self.remap()
        self.remap("retained.ttf",existing=True)
        retained = self.baseline/"assets/ui/retained.ttf.import"
        original = retained.read_bytes()
        receipt = self.prepare()
        self.assertEqual(receipt["projected_count"],1)
        self.assertEqual(receipt["retained_count"],1)
        self.assertEqual((self.baseline/"assets/ui/font.ttf.import").read_bytes(),supplied.read_bytes())
        self.assertEqual(retained.read_bytes(),original)
        validate_projection(receipt,self.baseline,self.candidate)

    def test_changed_source_fails_before_any_remap_write(self):
        self.remap()
        (self.baseline/"assets/ui/font.ttf").write_bytes(b"different genuine baseline")
        with self.assertRaises(ValueError): self.prepare()
        self.assertFalse((self.baseline/"assets/ui/font.ttf.import").exists())
        self.assertFalse(self.receipt.exists())

    def test_godot_duplicate_destination_declaration_stays_valid(self):
        supplied = self.remap()
        supplied.write_text(supplied.read_text().replace('dest_files=["res://.godot/imported/font.ttf.fixturedata"]',
            'dest_files=["res://.godot/imported/font.ttf.fixturedata", "res://.godot/imported/font.ttf.fixturedata"]'))
        receipt = self.prepare()
        self.assertEqual(len(receipt["entries"][0]["artifacts"]),2)
        validate_projection(receipt,self.baseline,self.candidate)

    def test_missing_required_source_remap_or_imported_artifact_fails_closed(self):
        (self.baseline/"assets/ui/font.ttf").write_bytes(b"required baseline font")
        with self.assertRaises(ValueError): self.prepare()
        self.remap()
        (self.cache/"font.ttf.fixturedata").unlink()
        with self.assertRaises((ValueError,FileNotFoundError)): self.prepare()

    def test_source_or_destination_escape_and_wrong_source_declaration_are_rejected(self):
        self.remap(destination="res://.godot/imported/../../outside.fixturedata")
        with self.assertRaises((ValueError,FileNotFoundError)): self.prepare()
        self.remap(source="res://assets/ui/other.ttf")
        with self.assertRaises(ValueError): self.prepare()
        self.remap(destination="res://assets/ui/font.ttf")
        with self.assertRaises(ValueError): self.prepare()

    def test_artifact_remap_and_source_tampering_invalidate_receipt(self):
        self.remap()
        receipt = self.prepare()
        for path in (self.cache/"font.ttf.fixturedata",self.baseline/"assets/ui/font.ttf.import",self.candidate/"assets/ui/font.ttf"):
            old = path.read_bytes()
            path.write_bytes(old+b"tamper")
            with self.subTest(path=path),self.assertRaises(ValueError): validate_projection(receipt,self.baseline,self.candidate)
            path.write_bytes(old)

    def test_new_candidate_resource_is_never_copied_into_baseline(self):
        self.remap()
        self.remap("candidate_only.ttf")
        (self.baseline/"assets/ui/candidate_only.ttf").unlink()
        receipt = self.prepare()
        self.assertEqual(receipt["skipped_candidate_only"],["assets/ui/candidate_only.ttf.import"])
        self.assertFalse((self.baseline/"assets/ui/candidate_only.ttf").exists())
        self.assertFalse((self.baseline/"assets/ui/candidate_only.ttf.import").exists())

    def test_distinct_artifact_cache_and_duplicate_receipt_are_rejected(self):
        self.remap()
        receipt = self.prepare()
        with self.assertRaises(ValueError): self.prepare()
        receipt["shared_imported_cache"] = str(self.folder/"different")
        with self.assertRaises(ValueError): validate_projection(receipt,self.baseline,self.candidate)

    def test_prepared_monster_proof_requires_all18_matching_scenes(self):
        with self.assertRaises(ValueError): validate_prepared_identity({"passed":True,"prepared_scenes":[]},self.baseline,self.candidate)

    def staff(self,external=False):
        binary,views,images = b"",[],[]
        for index,name in enumerate(sorted(STAFF_IMAGES)):
            pixels = b"\x89PNG\r\n\x1a\n"+bytes([index])*8
            views.append({"buffer":0,"byteOffset":len(binary),"byteLength":len(pixels)})
            images.append({"name":name,"mimeType":"image/png","bufferView":index})
            if external: images[-1]["uri"]="candidate_fallback.png"
            binary += pixels
            destination = self.candidate/Path(STAFF).with_name(Path(STAFF).stem+"_"+name+".png")
            destination.parent.mkdir(parents=True,exist_ok=True)
            destination.write_bytes(pixels)
        text = json.dumps({"bufferViews":views,"images":images}).encode()
        text += b" "*((-len(text))%4)
        raw = struct.pack("<4sII",b"glTF",2,12+8+len(text)+8+len(binary))+struct.pack("<II",len(text),0x4E4F534A)+text+struct.pack("<II",len(binary),0x004E4942)+binary
        for project in (self.baseline,self.candidate):
            source = project/STAFF
            source.parent.mkdir(parents=True,exist_ok=True)
            source.write_bytes(raw)

    def test_native_images_are_derived_from_baseline_glb_and_exactly_reproducible(self):
        self.staff()
        proof = native_staff_images(self.baseline,self.candidate,create=True)
        self.assertEqual(len(proof["images"]),4)
        self.assertEqual(native_staff_images(self.baseline,self.candidate),proof)
        image = self.baseline/proof["images"][0]["resource"]
        image.write_bytes(b"different existing baseline bytes")
        with self.assertRaises(ValueError): native_staff_images(self.baseline,self.candidate,create=True)
        self.assertEqual(image.read_bytes(),b"different existing baseline bytes")

    def test_external_image_uris_or_different_source_and_cached_image_are_rejected(self):
        self.staff(external=True)
        with self.assertRaises(ValueError): native_staff_images(self.baseline,self.candidate,create=True)
        self.staff()
        (self.candidate/STAFF).write_bytes(b"different source")
        with self.assertRaises(ValueError): native_staff_images(self.baseline,self.candidate,create=True)
        self.staff()
        image = next((self.candidate/Path(STAFF).parent).glob("*.png"))
        image.write_bytes(b"different cached external image")
        with self.assertRaises(ValueError): native_staff_images(self.baseline,self.candidate,create=True)
        self.assertFalse(list((self.baseline/Path(STAFF).parent).glob("*.png")))

    def test_prior_projection_origin_is_retained_without_reclassifying_generated_remaps(self):
        self.remap()
        prior = self.prepare()
        self.remap("additional.ttf")
        updated = prepare_projection(self.baseline,self.candidate,self.folder/"next.json",self.receipt)
        self.assertEqual(updated["prior_projected_count"],1)
        self.assertEqual(updated["projected_count"],1)
        self.assertEqual(updated["retained_count"],0)
        self.assertEqual(json.loads(self.receipt.read_text()),prior)
        validate_projection(updated,self.baseline,self.candidate)



if __name__ == "__main__": unittest.main()
