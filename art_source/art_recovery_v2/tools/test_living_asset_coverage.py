"""Selected-roster and receipt freshness regressions using disposable files only."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import build_living_equipment_coverage as equipment
import build_living_scenery_coverage as scenery
from living_asset_coverage import current_authored_units, current_scenery_units, flatten_environment, normalized_resources, native_motion_evidence
from living_coverage_freshness import refresh_review


def sha(data):
    return hashlib.sha256(data if isinstance(data,bytes) else data.encode()).hexdigest()


class RosterTests(unittest.TestCase):
    def group(self):
        return [{'id':'table','path':'res://assets_external/table.res','pack_owner':'opening'},
                {'id':'vargan_architecture','pack_owner':'campaign','build_tool':'res://tools/build_vargan.gd',
                 'assets':[{'variant':'gatehouse','path':'res://assets_external/gatehouse.res'},
                           {'variant':'tower','path':'res://assets_external/tower.res'}]}]

    def test_group_inherits_provenance_but_selected_pack_controls_owner(self):
        original=self.group();before=deepcopy(original)
        selected={'res://assets_external/table.res':['opening'],'res://assets_external/gatehouse.res':['campaign','shared']}
        rows=flatten_environment(original,selected)
        self.assertEqual([r['id'] for r in rows],['table','vargan_architecture_gatehouse'])
        gate=rows[1]
        self.assertEqual(gate['build_tool'],'res://tools/build_vargan.gd')
        self.assertEqual(gate['group_id'],'vargan_architecture')
        self.assertEqual(gate['declared_pack_owner'],'campaign')
        self.assertEqual(gate['pack_owners'],['campaign','shared'])
        self.assertIsNone(gate['pack_owner'])
        self.assertEqual(original,before)

    def test_unselected_group_members_never_expand_runtime_scope(self):
        self.assertEqual(flatten_environment(self.group(),{}),[])

    def test_direct_and_group_identity_and_path_collisions_fail(self):
        for change in ('identity','path'):
            rows=self.group()
            if change=='identity':rows[1]['assets'][0]['id']='table'
            else:rows[1]['assets'][0]['path']=rows[0]['path']
            with self.subTest(change=change),self.assertRaisesRegex(ValueError,'Duplicate'):
                flatten_environment(rows)

    def test_malformed_groups_and_resource_escapes_fail_even_unselected(self):
        bad=[{'id':'a','assets':[]},{'id':'a','assets':{}},{'id':'a','assets':[{'path':'res://a.res'}]},
             {'id':'a','assets':[{'variant':'b','assets':[],'path':'res://a.res'}]},
             {'id':'a','path':'res://../outside.res'},{'id':'a','path':'res://a//b.res'}]
        for row in bad:
            with self.subTest(row=row),self.assertRaises(ValueError):flatten_environment([row],{})

    def test_normalized_import_and_remap_aliases_merge_all_real_owners(self):
        packed={'assets/icons/icon.svg':['base'],'assets/icons/icon.svg.import':['opening'],
                'assets/icons/icon.svg.remap':['base'],'scripts/a.gd':['base']}
        before=deepcopy(packed)
        rows=normalized_resources(packed)
        self.assertEqual(len(rows),1)
        self.assertEqual(rows[0]['pack_owners'],['base','opening'])
        self.assertEqual(len(rows[0]['packed_paths']),3)
        self.assertEqual(rows[0]['path'],'res://assets/icons/icon.svg')
        self.assertEqual(packed,before)
        self.assertEqual(len(normalized_resources(packed,assets_only=False)),2)

    def test_missing_ownership_and_noncanonical_pack_paths_fail(self):
        for packed in ({'assets/a.res':[]},{'assets/../a.res':['base']},{'/assets/a.res':['base']}):
            with self.assertRaises(ValueError):normalized_resources(packed)


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.repo=Path(self.temp.name);self.game=self.repo/'outputs/AshenOathTheRoadBetweenCrowns'
        self.art=self.repo/'art_source/art_recovery_v2';self.game.mkdir(parents=True)

    def write(self,path,value):
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(value) if isinstance(value,(list,dict)) else value)
        return sha(path.read_bytes())

    def library(self):
        models=self.art/'models/living_cast_stage2_20261107'
        body=self.write(self.game/'body.glb','retained mesh')
        source=self.write(models/'C11/C11_life_review.glb','new motion')
        output=self.write(self.game/'life_C11.res','compiled library')
        self.write(models/'C11/source_verification.json',{'status':'source_contract_pass','review_glb_sha256':source,'retained_production_sha256':body})
        receipt=models/'library_compile_C11.json'
        self.write(receipt,{'status':'compiled','libraries':[{'asset':'C11','source':str(models/'C11/C11_life_review.glb'),
            'source_sha256':source,'path':'res://life_C11.res','sha256':output,'bytes':16,'model':'res://body.glb','model_sha256':body,'clips':{'Life_Work':{}}}]})
        runtime=self.write(self.game/'scripts/driver.gd','tested native owner')
        native=self.art/'evidence/living_cast_stage2_20261107/native_reviews/native_work_phase_20261110_r2/receipt.json'
        self.write(native,{'accepted':True,'scope':{'roles':'all_twelve_named_cast'},
            'input_sha256':{'life_C11.res':output,'scripts/driver.gd':runtime},'results':[{'fixture':'verify_living_cast_motion.gd',
            'accepted':True,'exit_code':0,'errors':[],'timeout':False,'command':['--motion-only','--skip-player']}]})
        return models,receipt,native

    def test_matching_receipts_establish_only_their_authored_native_scope(self):
        self.library();units,props=current_authored_units(self.repo,self.game)
        unit=units['C11']
        self.assertTrue(unit['authored'] and unit['native_verified'])
        self.assertIn('equipment matrix',unit['native_scope'])
        self.assertNotIn('visual_accepted',unit)
        self.assertFalse(props)

    def test_runtime_owner_change_drops_native_but_keeps_exact_authored_source(self):
        self.library();self.write(self.game/'scripts/driver.gd','changed owner')
        unit=current_authored_units(self.repo,self.game)[0]['C11']
        self.assertTrue(unit['authored']);self.assertFalse(unit['native_verified'])
        self.assertTrue(unit['native_test']['recorded_pass'])
        self.assertEqual(unit['native_test']['errors'][0]['path'],'res://scripts/driver.gd')

    def test_source_output_or_contract_change_cannot_reuse_compilation(self):
        for changed in ('source','output','contract'):
            models,_,_=self.library()
            paths={'source':models/'C11/C11_life_review.glb','output':self.game/'life_C11.res','contract':models/'C11/source_verification.json'}
            self.write(paths[changed],{} if changed=='contract' else 'changed bytes')
            unit=current_authored_units(self.repo,self.game)[0]['C11']
            with self.subTest(changed=changed):self.assertFalse(unit['authored'] or unit['native_verified'])

    def test_unrelated_or_partial_native_pass_cannot_certify_all_cast(self):
        _,_,native=self.library();data=json.loads(native.read_text())
        data['results'][0]['command']=['--motion-only','--skip-player','--roles=nessa']
        self.write(native,data)
        self.assertFalse(current_authored_units(self.repo,self.game)[0]['C11']['native_verified'])
        data['results'][0]['fixture']='verify_living_cast_lifecycle.gd';data['results'][0]['command']=[]
        self.write(native,data)
        self.assertFalse(native_motion_evidence(self.repo,self.game)['covers_named_cast'])

    def test_no_player_only_scope_cannot_certify_player(self):
        self.library()
        self.assertFalse(native_motion_evidence(self.repo,self.game)['covers_player'])

    def test_versioned_satchel_receipt_binds_current_bytes_without_rewriting_history(self):
        props=self.art/'models/living_cast_20261107/props'
        carrier=self.write(props/'rook_station_satchel.glb','retained carrier')
        output=self.write(self.game/'satchel.scn','current compiled scene')
        component=self.write(self.game/'body.res','retained component')
        historical={'path':'res://satchel.scn','sha256':sha('older compressed scene'),'source_sha256':carrier,
                    'resources':[{'path':'res://body.res','sha256':component}]}
        # The runtime basename identifies the satchel in the real receipt.
        scene=self.game/'rook_station_satchel.scn';scene.write_bytes((self.game/'satchel.scn').read_bytes())
        historical['path']='res://rook_station_satchel.scn'
        old_hash=self.write(props/'satchel_compile.json',historical)
        self.write(props/'satchel_authoring.json',{'carrier':str(props/'rook_station_satchel.glb'),'carrier_sha256':carrier})
        archive=self.art/'evidence/living_cast_stage2_20261107/retained_props/satchel_compiler_20261107_060919_r1'
        current=deepcopy(historical);current['sha256']=output
        receipt_hash=self.write(archive/'satchel_compile.json',current)
        self.write(archive/'archive_manifest.json',{'verified_exact_source_and_output_bytes':True,'recompiled':False,
            'files':[{'path':'satchel_compile.json','sha256':receipt_hash}],
            'historical_receipt':{'path':str((props/'satchel_compile.json').relative_to(self.repo)),'sha256':old_hash}})
        item=current_authored_units(self.repo,self.game)[1][0]
        self.assertTrue(item['authored']);self.assertFalse(item['native_verified'])
        self.assertEqual(sha((props/'satchel_compile.json').read_bytes()),old_hash)
        self.write(self.game/'body.res','changed component')
        self.assertFalse(current_authored_units(self.repo,self.game)[1][0]['authored'])

    def test_changed_level_performance_and_world_claims_move_to_history(self):
        old={'authored':True,'in_level_accepted':True,'performance_verified':True,'confirmed_world_usage':True,
             'verification_inputs':{'res://a.res':sha('old')}}
        new=refresh_review({'authored':False,'in_level_accepted':False,'performance_verified':False,'confirmed_world_usage':False},old,{'res://a.res':sha('new')})
        self.assertFalse(new['in_level_accepted'] or new['performance_verified'] or new['confirmed_world_usage'])
        self.assertTrue(new['review_history'][0]['review']['performance_verified'])

    def test_scenery_live_recipe_and_transport_changes_invalidate_current_compilation(self):
        folder=self.art/'models/living_assets_stage3_20261107/scenery/checkpoint_cloth'
        author={'blender_authored':True}
        for key in ('blend','carrier','raw_carrier','recipe','transport_helper','retained_input','retained_native','retained_receipt'):
            path=folder/(key+'.archive')
            author[key]=path.relative_to(self.art).as_posix()
            author[key+'_sha256']=self.write(path,'exact '+key)
        live={'recipe':self.art/'tools/author_living_world_parts.py',
              'transport_helper':self.art/'tools/living_world_gltf_transport.py'}
        for key,path in live.items():self.write(path,'exact '+key)
        author_path=folder/'authoring.json';author_hash=self.write(author_path,author)
        output_hash=self.write(self.game/'cloth.scn','compiled cloth')
        compiler_hash=self.write(self.game/'tools/build_living_world_blender.gd','compiler')
        geometry_hash=self.write(self.game/'tools/living_world_geometry_contract.gd','geometry')
        self.write(self.art/'evidence/living_assets_stage3_20261107/scenery/checkpoint_cloth_compile.json',
            {'path':'res://cloth.scn','sha256':output_hash,'authoring_receipt':str(author_path),
             'authoring_receipt_sha256':author_hash,'compiler_sha256':compiler_hash,
             'geometry_contract_sha256':geometry_hash,'blender_authored':True,
             'parts':[{'triangle_attribute_multiplicity_equivalent':True,'geometry_palette_equivalent':True,
                       'winding_normals_uvs_partitions_equivalent':True}]})
        current=current_scenery_units(self.repo,self.game)['road_checkpoint']
        self.assertTrue(current['authored'] and current['native_verified'])
        for key,path in live.items():
            with self.subTest(changed=key):
                self.write(path,'edited '+key)
                changed=current_scenery_units(self.repo,self.game)['road_checkpoint']
                self.assertFalse(changed['authored'] or changed['compiled'] or changed['native_verified'])
                self.assertEqual(changed['errors'][0]['path'],'repo://'+path.relative_to(self.repo).as_posix())
                self.assertEqual(sha(author_path.read_bytes()),author_hash)
                self.write(path,'exact '+key)

    def test_equipment_supply_is_current_addition_and_fallback_is_not_world_use(self):
        out=self.art/'evidence/living_assets_stage3_20261107'
        self.write(out/'retained_source_inventory.json',{'held_equipment_checklist':{'date':'frozen','assets':[
            {'id':'Vargan_spear','change':'retained spear'},{'id':'activity_bread','change':'retained bread'}]}})
        frozen=(out/'retained_source_inventory.json').read_bytes()
        self.write(out/'held_prop_contracts_20261110.json',{'actors':[{'asset':'C11','required_activity_prop_grips':['bread','supply'],'native_fit_accepted':False}]})
        self.write(self.game/'scripts/character_presentation.gd','_add_spear ScoredFlatbreadCrust HeldProps.vessel')
        with patch.object(equipment,'GAME',self.game),patch.object(equipment,'OUT',out):equipment.main()
        data=json.loads((out/'equipment_coverage.json').read_text())
        self.assertEqual([x['id'] for x in data['assets']],['Vargan_spear','activity_bread','activity_supply'])
        spear=data['assets'][0];supply=data['assets'][2]
        self.assertFalse(spear['confirmed_world_usage'] or spear['named_cast_runtime_reachable'])
        self.assertEqual(supply['required_actor_fits'],['C11'])
        self.assertFalse(supply['native_verified'] or supply['visual_accepted'] or supply['user_accepted'])
        self.assertEqual(data['coverage_counts']['required_named_actor_fits'],2)
        self.assertEqual((out/'retained_source_inventory.json').read_bytes(),frozen)

    def test_scenery_current_roster_expands_without_rewriting_frozen_inventory(self):
        evidence=self.art/'evidence/living_assets_stage3_20261107'
        baseline={'selected_authored_environment':[{'id':'table','path':'res://assets_external/table.res','sha256':sha('table'),'status':'old'}]}
        self.write(evidence/'retained_source_inventory.json',baseline)
        frozen=(evidence/'retained_source_inventory.json').read_bytes()
        records=RosterTests().group()+[{'id':'record_hall_witness_relief','path':'res://assets_external/relief.jpg','pack_owner':'campaign'}]
        self.write(self.game/'runtime_asset_manifest.json',{'authored_environment_derivatives':records})
        paths=['res://assets_external/table.res','res://assets_external/gatehouse.res','res://assets_external/relief.jpg']
        self.write(self.game/'release_reports/living_cast_20261107/asset_coverage.json',{'baseline':{'build_id':'frozen'},'runtime_asset_resources':[{'path':p,'pack_owners':['campaign']} for p in paths]})
        (self.game/'scripts').mkdir();(self.game/'tools').mkdir()
        with patch.object(scenery,'ART',self.art),patch.object(scenery,'GAME',self.game),patch.object(scenery,'EVIDENCE',evidence):scenery.main()
        data=json.loads((evidence/'scenery_coverage.json').read_text())
        self.assertEqual(data['coverage_counts']['selected_resources'],3)
        self.assertEqual(data['coverage_counts']['selected_artwork'],1)
        self.assertEqual(data['entries'][1]['id'],'vargan_architecture_gatehouse')
        self.assertFalse(any(row['authored'] or row['native_verified'] or row['visual_accepted'] for row in data['entries']))
        self.assertEqual((evidence/'retained_source_inventory.json').read_bytes(),frozen)


if __name__=='__main__':unittest.main()
