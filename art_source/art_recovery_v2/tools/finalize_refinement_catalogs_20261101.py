"""Refresh the exact current refinement identities and shared image costs."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];GAME=ROOT.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,j):p.write_text(json.dumps(j,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
ledger=read(ROOT/'stylized_roster.json');assert len(ledger['assets'])==33
for r in ledger['assets']:
    assert r.get('refinement_20261101'),r['id']
    assert sha(Path(r['source_path']))==r['source']['sha256']
    canonical=GAME/r['destination_resource'].removeprefix('res://')
    assert sha(canonical)==r['runtime']['sha256']
    for t in r['textures']:assert sha(GAME/t['runtime_path'].removeprefix('res://'))==t['sha256']
    for history in r.get('refinement_history',[]):
        availability={}
        for kind in ['source','runtime']:
            path=Path(history.get(kind+'_path',''))
            availability[kind]=path.is_file() and sha(path)==history.get(kind,{}).get('sha256')
        history['artifact_availability']=availability
        history['artifact_state']='intact' if all(availability.values()) else 'superseded_intermediate_bytes_not_retained'
textures={t['runtime_path']:t for r in ledger['assets'] for t in r['textures']}
compiled=sum(r['runtime']['bytes'] for r in ledger['assets'])+sum(t['bytes'] for t in textures.values())
embedded=0
for r in ledger['assets']:
    candidate=read(Path(r['refinement_20261101']['record']))
    embedded+=Path(candidate['runtime_path']).stat().st_size
ledger['shared_resource_costs']={'scope':'2026-11-01 final finishing exports; not process memory or complete Web payload',
 'embedded_finish_exports_bytes':embedded,'compiled_glbs_plus_unique_images_bytes':compiled,'saved_bytes':embedded-compiled,
 'unique_images':len(textures),'decoded_rgba8_images_no_mips_bytes':sum(t['width']*t['height']*4 for t in textures.values()),
 'not_process_memory_or_performance_measurement':True}
if 'resource_costs' in ledger:ledger.setdefault('historical_resource_costs_20261031',ledger['resource_costs'])
ledger['resource_costs']={'runtime_containers_bytes':sum(r['runtime']['bytes'] for r in ledger['assets']),
 'unique_encoded_images_bytes':sum(t['bytes'] for t in textures.values()),'unique_images':len(textures),
 'unique_rgba8_without_mips_estimate':sum(t['width']*t['height']*4 for t in textures.values()),
 'current_editable_blend_bytes':sum(Path(r['source_path']).stat().st_size for r in ledger['assets']),
 'triangles':sum(r['metrics']['triangles'] for r in ledger['assets']),'not_measured_process_or_gpu_memory':True}
ledger['current_refinement']={'id':'asset-refinement-20261101','authored':33,'integrated':33,'user_accepted':0,
 'scope':'retained 33-cast Blender finishing masters; scenery, held props, icons and effects recorded alongside',
 'evidence':'evidence/refinement_20261101','status':'native_and_package_verification_in_progress'}
write(ROOT/'stylized_roster.json',ledger)
design=read(GAME/'data/design_pack_assets.json');staff=GAME/design['staff']['path'].removeprefix('res://')
design['staff'].update(bytes=staff.stat().st_size,sha256=sha(staff),refinement_record=str(ROOT/'evidence/refinement_20261101/equipment/C01_ash_staff_refined_candidate.json'))
write(GAME/'data/design_pack_assets.json',design)
runtime=read(GAME/'runtime_asset_manifest.json');refreshed=[]
for role,record in runtime['roles'].items():
    for item in record.get('runtime_files',[]):
        path=GAME/str(item.get('path','')).removeprefix('res://')
        if not path.is_file():continue
        digest=sha(path)
        if item.get('sha256')!=digest or item.get('bytes')!=path.stat().st_size:
            item.update(bytes=path.stat().st_size,sha256=digest);refreshed.append({'role':role,'path':item['path']})
world_inventory=ROOT/'evidence/refinement_20261101/world_bakes/output_inventory.json'
world_refreshed=[]
if world_inventory.exists():
    worlds={r['path']:r for r in read(world_inventory)}
    for entry in runtime.get('authored_environment_derivatives',[]):
        current=worlds.get(entry.get('path'))
        if not current:continue
        if entry.get('sha256')!=current['sha256']:
            entry['refinement_20261101']={'previous_sha256':entry.get('sha256'),'evidence':'art_source/art_recovery_v2/evidence/refinement_20261101/world_bakes/receipt.json','regional_user_acceptance':False}
            entry['status']='refined_static_rebake_pending_regional_user_review'
            world_refreshed.append(entry['path'])
        entry.update(bytes=current['bytes'],sha256=current['sha256'])
        if current['class']=='ArrayMesh':entry.update(triangles=current['triangles'],surfaces=current['surfaces'])
write(GAME/'runtime_asset_manifest.json',runtime)
gate=read(ROOT/'quality_gate.json');gate['reason']='2026-11-01: user requested all visual game assets improved one by one and pushed; current direction retained. Publication authorization does not assert final visual/gameplay acceptance.'
gate['active_roster_summary'].update(authored=33,exported=33,private_integrated=33,required=33,user_accepted=0,next_asset=None)
gate['current_refinement']=ledger['current_refinement'];write(ROOT/'quality_gate.json',gate)
write(ROOT/'evidence/refinement_20261101/catalog_identity.json',{'cast_count':33,'shared_resource_costs':ledger['shared_resource_costs'],'refreshed_noncast_runtime_files':refreshed,'refreshed_world_derivatives':world_refreshed,'staff':design['staff'],'user_accepted':False})
print(json.dumps({'cast_count':33,'resources_bytes':compiled,'unique_images':len(textures),'refreshed_runtime_files':len(refreshed)}))
