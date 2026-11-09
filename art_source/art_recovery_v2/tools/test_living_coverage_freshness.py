"""Pure-data/temp-resource regressions: no native tools or ledger regeneration."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import build_living_cast_coverage as cast_generator
import build_living_equipment_coverage as equipment_generator
from build_living_cast_coverage import refresh_rows
from build_living_equipment_coverage import refresh_equipment
from living_coverage_freshness import preserve_removed, refresh_review, resource_inputs
from update_living_cast_stage1_evidence import authored_motion_review


def sha(value):
    return hashlib.sha256(value.encode()).hexdigest()


class FreshnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.game = Path(self.temp.name)
        self.paths = ['res://body.glb', 'res://prepared.scn', 'res://motion.res', 'res://driver.gd', 'res://prop.res']
        for path in self.paths:
            (self.game / path[6:]).write_text(path)
        self.selected = {'selected_export:release_manifest':sha('release'), 'selected_export:runtime_manifest':sha('runtime')}

    def cast(self):
        current = {'id':'C01', 'source':self.paths[0], 'source_sha256':sha(self.paths[0]),
                   'compiled_resources':[self.paths[1]], 'pack_owners':['actor_c01'],
                   'life_status':'queued', 'authored':False, 'runtime_verified':False, 'user_accepted':False}
        old = deepcopy(current)
        old.update({'life_status':'reviewed', 'authored':True, 'runtime_verified':True, 'user_accepted':True,
                    'candidate_motion':{'path':self.paths[2], 'sha256':sha(self.paths[2])},
                    'source_review':{'source_contract_verified':True, 'runtime_visual_acceptance':True,
                                     'work_apex_clay_reviewed':True},
                    'notes':['Independent artist note'], 'evidence':['before.png', 'after.png'],
                    'independent_audit':{'owner':'retained driver'}})
        old['verification_inputs'] = resource_inputs(self.game,self.paths[:3]) | self.selected
        return current, old

    def refresh_cast(self,current,old):
        return refresh_rows([current],[old],{'motion.res':['actor_c01']},self.selected,self.game)[0]

    def test_unchanged_exact_inputs_preserve_review_and_independent_annotation(self):
        current, old = self.cast()
        snapshot = deepcopy(old)
        row = self.refresh_cast(current,old)
        self.assertTrue(row['authored'] and row['runtime_verified'] and row['user_accepted'])
        self.assertEqual(row['independent_audit'],old['independent_audit'])
        self.assertEqual(row['notes'],old['notes'])
        self.assertTrue(row['candidate_motion']['present_in_selected_export'])
        self.assertEqual(old,snapshot)

    def test_changed_body_invalidates_current_acceptance_but_archives_evidence(self):
        current, old = self.cast()
        (self.game/'body.glb').write_text('new body')
        current['source_sha256'] = sha('new body')
        row = self.refresh_cast(current,old)
        self.assertFalse(any(row[key] for key in ['authored','runtime_verified','user_accepted']))
        self.assertFalse(row['source_review']['source_contract_verified'])
        self.assertEqual(row['review_history'][0]['review']['evidence'],old['evidence'])
        self.assertTrue(row['review_history'][0]['review']['user_accepted'])
        self.assertEqual(row['source_sha256'],sha('new body'))

    def test_changed_native_library_invalidates_with_unchanged_body(self):
        current, old = self.cast()
        (self.game/'motion.res').write_text('new clip')
        row = self.refresh_cast(current,old)
        self.assertFalse(row['runtime_verified'])
        self.assertIn('res://motion.res',row['evidence_freshness']['changed_inputs'])

    def test_changed_prepared_scene_invalidates_with_unchanged_body(self):
        current, old = self.cast()
        (self.game/'prepared.scn').write_text('new bindings')
        self.assertFalse(self.refresh_cast(current,old)['user_accepted'])

    def test_selected_export_change_invalidates_runtime_acceptance(self):
        current, old = self.cast()
        self.selected['selected_export:release_manifest'] = sha('other export')
        self.assertFalse(self.refresh_cast(current,old)['runtime_verified'])

    def test_legacy_acceptance_without_complete_input_binding_is_historical(self):
        current, old = self.cast()
        old.pop('verification_inputs')
        row = self.refresh_cast(current,old)
        self.assertFalse(row['user_accepted'])
        self.assertTrue(row['review_history'][0]['review']['user_accepted'])

    def test_repeated_refresh_neither_reaccepts_nor_duplicates_history(self):
        current, old = self.cast()
        (self.game/'motion.res').write_text('new clip')
        first = self.refresh_cast(current,old)
        second = self.refresh_cast(current,first)
        self.assertFalse(second['authored'] or second['runtime_verified'] or second['user_accepted'])
        self.assertEqual(second['review_history'],first['review_history'])

    def test_missing_resource_fails_closed_on_every_refresh(self):
        current, old = self.cast()
        (self.game/'motion.res').unlink()
        first = self.refresh_cast(current,old)
        second = self.refresh_cast(current,first)
        self.assertFalse(second['runtime_verified'])
        self.assertEqual(second['evidence_freshness']['unbound_inputs'],['res://motion.res'])
        self.assertEqual(second['review_history'],first['review_history'])

    def equipment(self):
        current = {'id':'activity_bread','runtime_reference':'res://driver.gd',
                   'runtime_source_sha256':sha('res://driver.gd'), 'assessment':'Generated status',
                   'current_visual_evidence':[], 'native_verified':False,'visual_accepted':False,'user_accepted':False}
        old = deepcopy(current)
        old.update({'native_verified':True,'visual_accepted':True,'user_accepted':True,
                    'current_visual_evidence':['real-level.png'], 'assessment':'Independent reviewer status',
                    'runtime_ownership_audit':{'owner':'Real hand socket','resources':['res://prop.res'],
                    'source_receipts':[{'path':'res://driver.gd','sha256':sha('res://driver.gd')}]}})
        old['verification_inputs']=resource_inputs(self.game,self.paths[3:])
        return current, old

    def test_equipment_unchanged_preserves_audit_and_current_capture(self):
        current, old = self.equipment()
        row=refresh_equipment([current],{'assets':[old]},self.game)[0]
        self.assertEqual(row['runtime_ownership_audit'],old['runtime_ownership_audit'])
        self.assertTrue(row['native_verified'] and row['visual_accepted'] and row['user_accepted'])
        self.assertEqual(row['current_visual_evidence'],['real-level.png'])
        self.assertEqual(row['assessment'],'Independent reviewer status')
        self.assertNotIn('review_history',row)

    def test_equipment_resource_change_archives_capture_and_keeps_audit(self):
        current, old = self.equipment()
        (self.game/'prop.res').write_text('changed mesh')
        row=refresh_equipment([current],{'assets':[old]},self.game)[0]
        self.assertEqual(row['runtime_ownership_audit'],old['runtime_ownership_audit'])
        self.assertFalse(row['native_verified'] or row['visual_accepted'] or row['user_accepted'])
        self.assertEqual(row['current_visual_evidence'],[])
        self.assertEqual(row['review_history'][0]['review']['current_visual_evidence'],['real-level.png'])

    def test_additional_audited_script_change_invalidates(self):
        current, old = self.equipment()
        old['runtime_ownership_audit']['source_receipts'].append({'path':'res://body.glb','sha256':sha('res://body.glb')})
        old['verification_inputs'].update(resource_inputs(self.game,['res://body.glb']))
        (self.game/'body.glb').write_text('different skin or owner')
        self.assertFalse(refresh_equipment([current],{'assets':[old]},self.game)[0]['native_verified'])

    def test_previously_verified_dependency_is_not_silently_dropped(self):
        current, old=self.equipment()
        old['verification_inputs'].update(resource_inputs(self.game,['res://motion.res']))
        self.assertTrue(refresh_equipment([current],{'assets':[old]},self.game)[0]['native_verified'])
        (self.game/'motion.res').write_text('changed closed-hand animation')
        self.assertFalse(refresh_equipment([current],{'assets':[old]},self.game)[0]['native_verified'])

    def test_cast_keeps_additional_verified_runtime_owner_inputs(self):
        current, old=self.cast()
        old['verification_inputs'].update(resource_inputs(self.game,['res://driver.gd']))
        self.assertTrue(self.refresh_cast(current,old)['runtime_verified'])
        (self.game/'driver.gd').write_text('changed contact owner')
        self.assertFalse(self.refresh_cast(current,old)['runtime_verified'])

    def test_removed_asset_keeps_independent_history_without_duplicate(self):
        _, old=self.equipment()
        first=preserve_removed([old],[],[])
        self.assertEqual(preserve_removed([old],[],first),[old])
        self.assertEqual(first[0]['runtime_ownership_audit'],old['runtime_ownership_audit'])

    def test_resource_escape_is_rejected(self):
        with self.assertRaises(ValueError):resource_inputs(self.game,['res://../outside.gd'])

    def test_authored_candidate_change_clears_runtime_user_but_records_new_authorship(self):
        _, old=self.cast()
        motion=deepcopy(old['candidate_motion']);motion['sha256']=sha('new clip')
        inputs=old['verification_inputs'] | {'res://motion.res':sha('new clip')}
        row=authored_motion_review(old,motion,['Life_Work'],['new-proof.json'],inputs)
        self.assertTrue(row['authored'] and row['source_review']['source_contract_verified'])
        self.assertFalse(row['runtime_verified'] or row['user_accepted'] or row['source_review']['runtime_visual_acceptance'])
        self.assertTrue(row['review_history'][0]['review']['user_accepted'])
        self.assertTrue(row['review_history'][0]['review']['source_review']['work_apex_clay_reviewed'])
        self.assertFalse(row['source_review']['work_apex_clay_reviewed'])
        self.assertEqual(row['evidence'],['new-proof.json'])

    def test_repeated_identical_authoring_keeps_current_review(self):
        _, old=self.cast()
        row=authored_motion_review(old,old['candidate_motion'],['Life_Work'],['new-proof.json'],old['verification_inputs'])
        again=authored_motion_review(row,row['candidate_motion'],['Life_Work'],['new-proof.json'],row['verification_inputs'])
        self.assertTrue(again['runtime_verified'] and again['user_accepted'] and again['source_review']['runtime_visual_acceptance'])
        self.assertTrue(again['source_review']['work_apex_clay_reviewed'])
        self.assertEqual(again['evidence'],['before.png','after.png','new-proof.json'])
        self.assertNotIn('review_history',again)
        self.assertIn('Independent artist note',again['notes'])

    def test_new_source_proof_does_not_assert_visual_review(self):
        current, old=self.cast()
        row=authored_motion_review(current,old['candidate_motion'],['Life_Work'],['source-proof.json'],old['verification_inputs'])
        again=authored_motion_review(row,row['candidate_motion'],['Life_Work'],['source-proof.json'],row['verification_inputs'])
        self.assertTrue(again['authored'] and again['source_review']['source_contract_verified'])
        self.assertFalse(again['source_review']['work_apex_clay_reviewed'])
        self.assertFalse(again['runtime_verified'] or again['user_accepted'])

    def test_repeated_changed_candidate_does_not_reassert_historical_clay_review(self):
        _, old=self.cast()
        motion=deepcopy(old['candidate_motion']);motion['sha256']=sha('new candidate')
        inputs=old['verification_inputs'] | {'res://motion.res':sha('new candidate')}
        row=authored_motion_review(old,motion,['Life_Work'],['new-proof.json'],inputs)
        again=authored_motion_review(row,motion,['Life_Work'],['new-proof.json'],inputs)
        self.assertFalse(again['source_review']['work_apex_clay_reviewed'])
        self.assertEqual(again['review_history'],row['review_history'])
        self.assertTrue(again['review_history'][0]['review']['source_review']['work_apex_clay_reviewed'])

    def test_unverified_legacy_audit_is_preserved_without_promoting_acceptance(self):
        current, old=self.equipment()
        old.pop('verification_inputs')
        for key in ['native_verified','visual_accepted','user_accepted']:old[key]=False
        old['current_visual_evidence']=[]
        row=refresh_equipment([current],{'assets':[old]},self.game)[0]
        self.assertFalse(row['native_verified'] or row['visual_accepted'] or row['user_accepted'])
        self.assertEqual(row['runtime_ownership_audit'],old['runtime_ownership_audit'])
        self.assertEqual(row['review_history'][0]['review']['assessment'],'Independent reviewer status')

    def test_equipment_generator_preserves_actual_document_and_audit_fields(self):
        scripts=self.game/'scripts';scripts.mkdir()
        (scripts/'character_presentation.gd').write_text('uses_fitted_anwen_staff')
        out=self.game/'reports';out.mkdir()
        baseline={'held_equipment_checklist':{'date':'retained-date','assets':[{'id':'C01_staff','change':'Original staff treatment'}]}}
        (out/'retained_source_inventory.json').write_text(json.dumps(baseline))
        old={'id':'C01_staff','runtime_ownership_audit':{'owner':'Exact socket audit','resources':['res://prop.res']},'native_verified':False}
        previous={'schema_version':1,'assets':[old],'ownership_audit_status':'Independently reviewed','independent_history':['Original note']}
        (out/'equipment_coverage.json').write_text(json.dumps(previous))
        with patch.object(equipment_generator,'GAME',self.game),patch.object(equipment_generator,'OUT',out):
            equipment_generator.main()
        result=json.loads((out/'equipment_coverage.json').read_text())
        self.assertEqual(result['ownership_audit_status'],previous['ownership_audit_status'])
        self.assertEqual(result['independent_history'],previous['independent_history'])
        self.assertEqual(result['assets'][0]['runtime_ownership_audit'],old['runtime_ownership_audit'])
        self.assertFalse(result['assets'][0]['native_verified'])

    def test_cast_generator_preserves_document_notes_addition_and_removed_history(self):
        repo=self.game/'repo';game=repo/'game';web=repo/'web'
        game.mkdir(parents=True);web.mkdir()
        (game/'data').mkdir()
        for name in ['body.glb','prepared.scn','table.scn','prop.res']:(game/name).write_text(name)
        paths=['prepared.scn','table.scn','prop.res']
        header=bytearray(40);header[:4]=b'GDPC';struct.pack_into('<I',header,4,3);struct.pack_into('<Q',header,32,40)
        data=bytes(header)+struct.pack('<I',len(paths))
        for path in paths:
            name=path.encode();data+=struct.pack('<I',len(name))+name+bytes(36)
        (web/'index.pck').write_bytes(data)
        release={'build_id':'synthetic','source':{'git_commit':'fixture'},'artifacts':[{'path':'index.pck','sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}]}
        (web/'release_manifest.json').write_text(json.dumps(release))
        (web/'runtime_pack_manifest.json').write_text('{}')
        (game/'data/design_pack_assets.json').write_text(json.dumps({'assets':{'C01':{'path':'res://body.glb'}}}))
        (game/'data/prepared_actors.json').write_text(json.dumps({'anwen':{'source':'res://body.glb','path':'res://prepared.scn'}}))
        (game/'runtime_asset_manifest.json').write_text(json.dumps({'roles':{'anwen':{'design_id':'C01'}},'authored_environment_derivatives':[{'id':'table','path':'res://table.scn'}]}))
        out=repo/'coverage.json'
        previous={'notes':['Independent capture restriction'],'cast':[{'id':'C01','authored':True,'runtime_verified':True,'user_accepted':True,'evidence':['old proof']}],
                  'environment':[{'id':'removed_table','audit':'Retain this review'}],
                  'compiled_additions':[{'id':'prop','path':'res://prop.res','authored':True,'user_accepted':True,'independent_audit':'Original prop proof'}],
                  'independent_history':['Earlier export']}
        out.write_text(json.dumps(previous))
        with patch.object(cast_generator,'REPO',repo),patch.object(cast_generator,'GAME',game),patch.object(cast_generator,'OUT',out):
            cast_generator.main()
        result=json.loads(out.read_text())
        self.assertIn('Independent capture restriction',result['notes'])
        self.assertEqual(result['independent_history'],previous['independent_history'])
        self.assertFalse(result['cast'][0]['user_accepted'])
        self.assertTrue(result['cast'][0]['review_history'][0]['review']['user_accepted'])
        self.assertEqual(result['removed_from_runtime_scope']['environment'],previous['environment'])
        self.assertEqual(result['compiled_additions'][0]['independent_audit'],'Original prop proof')
        self.assertFalse(result['compiled_additions'][0]['user_accepted'])


if __name__=='__main__':unittest.main()
