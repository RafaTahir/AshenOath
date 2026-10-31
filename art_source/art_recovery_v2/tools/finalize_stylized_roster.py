"""Record delivered private artifacts separately from visual/gameplay acceptance."""
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
BUILD=Path('D:/Temp/AshenOath/stylized_review')
ledger_path=ROOT/'stylized_roster.json'
ledger=json.loads(ledger_path.read_text())
if '--refresh-level-only' in sys.argv:
    record=json.loads((ROOT/'evidence/stylized/level/level_roster.json').read_text())
    assert record['journey_started'] is False and len(record['assets'])==33
    staged={row['id']:row for row in record['assets']}
    for row in ledger['assets']:
        assert staged[row['id']]['source_sha256']==row['runtime']['sha256']
        row['internal_art_inspection']['prepared_greyfen_views']=str(ROOT/'evidence/stylized/level'/row['id'])
        row['internal_art_inspection']['level_scope']=record['scope']
    ledger['delivery']['art_stage_limits']=['Actual Greyfen lighting with a staged turntable, not actual NPC placement or dialogue framing acceptance.',
        'Unclassified red/black background geometry is visible in the prepared-menu art stage; not attributed to a candidate or cleared as gameplay.']
    summary=json.loads((BUILD/'export/release_manifest.json').read_text())['size_summary']
    ledger['delivery']['initial_balanced_download_bytes']=summary['opening_required_balanced_potato']['transport_bytes']
    ledger['delivery']['initial_quality_download_bytes']=summary['opening_required_quality']['transport_bytes']
    ledger_path.write_text(json.dumps(ledger,indent=2)+'\n')
    gate_path=ROOT/'quality_gate.json'
    gate=json.loads(gate_path.read_text())
    gate['private_delivery']=ledger['delivery']
    gate_path.write_text(json.dumps(gate,indent=2)+'\n')
    print('Clear-street turntable records refreshed; no artifact or acceptance changed.')
    raise SystemExit(0)
if '--refresh-notes-only' in sys.argv:
    delivery=json.loads((BUILD/'private_review_build.json').read_text())
    ledger['delivery'].update(release_validation=delivery['strict_release_validation'],
                              budget_failures=delivery['budget_failures'],publication_authorized=False)
    replacements={
        'Actual Greyfen lighting not yet inspected.':'Prepared Greyfen art lighting is inspected; regional gameplay remains unverified.',
        'motion and user acceptance are separate and unverified.':'Sampled motion is not final motion/gameplay acceptance.',
        'Fusion/gameplay motion and user acceptance unverified.':'Fusion locomotion is art-sampled; gameplay and final user acceptance remain unverified.',
        'Studio preview inherited old C07 stamp, to be corrected in combined views.':'The historical Blender studio preview inherited a C07 stamp; current native boards are correctly labelled M04.',
        'Runtime shields need consolidation into shared assembly.':'Runtime shields are consolidated into one 20,000-triangle assembly; the detailed editable source is retained.',
        'no new species-specific clips, runtime integration, gameplay or user acceptance established.':'native/procedural state clips are retained; private integration/art inspection is not gameplay or user acceptance.',
    }
    for row in ledger['assets']:
        old=row.get('authoring_notes_at_export',row['limitations'])
        row.setdefault('authoring_notes_at_export',old)
        text=old.split(' Layered-apron waist contact observed')[0]
        for before,after in replacements.items():
            text=text.replace(before,after)
        repeated='Extended lower garments now blend into retained thigh/calf chains with four normalized influences; this is skinning, not cloth simulation or motion acceptance.'
        if text.count(repeated)>1:
            first=text.find(repeated)+len(repeated)
            text=text[:first]+text[first:].replace(' '+repeated,'')
        if row['id'] in ('C03','C04','C09','C11'):
            text+=' Material-ID isolation identified the apparent waist hole as a hand intersection. Existing locomotion pose ownership now supplies bounded garment clearance; raw clip-only previews do not include that fit. Work, dialogue and combat poses are excluded.'
        row['limitations']=text
    ledger_path.write_text(json.dumps(ledger,indent=2)+'\n')
    gate_path=ROOT/'quality_gate.json'
    gate=json.loads(gate_path.read_text())
    gate['private_delivery']=ledger['delivery']
    gate_path.write_text(json.dumps(gate,indent=2)+'\n')
    print('Current notes refreshed; export-time notes retained. No artifact or acceptance changed.')
    raise SystemExit(0)
receipt=json.loads((BUILD/'private_review_build.json').read_text())
assert receipt['publication_authorized'] is False
catalog=json.loads((BUILD/'project/data/prepared_actors.json').read_text())
level={}
for directory in ('level','level_garment'):
    path=ROOT/'evidence/stylized'/directory/'level_roster.json'
    if not path.is_file():
        continue
    record=json.loads(path.read_text())
    assert record['journey_started'] is False
    for row in record['assets']:
        level[row['id']]=(directory,row)
images={}
for row in ledger['assets']:
    key=row['id']
    raw=Path(row['runtime_path'])
    assert hashlib.sha256(raw.read_bytes()).hexdigest()==row['runtime']['sha256']
    assert hashlib.sha256(Path(row['source_path']).read_bytes()).hexdigest()==row['source']['sha256']
    native=json.loads((ROOT/'evidence/stylized'/key/'godot/review.json').read_text())
    assert native['asset_sha256']==row['runtime']['sha256']
    if key in ('C03','C04','C09','C11'):
        assert native['owned_locomotion'] is True
    directory,staged=level[key]
    assert staged['source_sha256']==row['runtime']['sha256']
    prepared=[r['path'] for r in catalog.values() if r['source']==row['destination_resource']]
    assert prepared
    textures=[]
    for item in row.get('textures',[]):
        path=Path(item['source_path'])
        assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256']
        with Image.open(path) as image:
            data={'path':str(path),'width':image.width,'height':image.height,
                  'encoded_bytes':path.stat().st_size,'rgba8_no_mips_estimate':image.width*image.height*4}
        images[str(path)]=data
        textures.append(data)
    row['metrics']['external_image_resources']=textures
    row['metrics']['decoded_rgba8_image_bytes_no_mips']=sum(i['rgba8_no_mips_estimate'] for i in textures)
    row.update(integrated=True,integration_scope='private_source_snapshot_only',production_integrated=False,
               internally_inspected=True,user_accepted=False,status='private_candidate_delivered_awaiting_user')
    row['private_integration']={'project':str(BUILD/'project'),'prepared_resources':sorted(set(prepared)),
                                'compiled':True,'combined_build_id':receipt['build_id']}
    row['internal_art_inspection']={'neutral_views':True,'walk_cycle_samples':12,
        'action_midpoints':native['action_midpoint_views'],'owned_garment_locomotion':native.get('owned_locomotion',False),
        'prepared_greyfen_views':str(ROOT/'evidence/stylized'/directory/key),
        'scope':'Source views, isolated native poses and prepared art staging; not regional encounter, gameplay, performance or final visual acceptance'}
ledger.update(status='private_roster_and_review_build_delivered_awaiting_user',authored_count=33,
              exported_count=33,private_integrated_count=33,internally_inspected_count=33,user_accepted_count=0)
ledger['delivery']={'build_receipt':str(BUILD/'private_review_build.json'),'build_id':receipt['build_id'],
                   'package_bytes':receipt['total_bytes'],'publication_authorized':False,
                   'user_accepted':False,'gameplay_acceptance':'unverified',
                   'index':str(ROOT/'evidence/stylized/index.html')}
ledger['resource_costs']={'runtime_containers_bytes':sum(r['runtime']['bytes'] for r in ledger['assets']),
    'unique_encoded_images_bytes':sum(i['encoded_bytes'] for i in images.values()),'unique_images':len(images),
    'unique_rgba8_without_mips_estimate':sum(i['rgba8_no_mips_estimate'] for i in images.values()),
    'current_editable_blend_bytes':sum(r['source']['bytes'] for r in ledger['assets']),
    'triangles':sum(r['metrics']['triangles'] for r in ledger['assets']),
    'not_measured_process_or_gpu_memory':True}
ledger_path.write_text(json.dumps(ledger,indent=2)+'\n')
gate_path=ROOT/'quality_gate.json'
gate=json.loads(gate_path.read_text())
gate.update(status='production_hold',current_slice='private_roster_delivered_awaiting_user',
            current_reason='Combined private candidates delivered; final user visual/gameplay acceptance is still required.')
gate['active_roster_summary'].update(authored=33,exported=33,private_integrated=33,internally_inspected=33,
                                    user_accepted=0,production_published=False,next_asset=None)
gate['private_delivery']=ledger['delivery']
for row in ledger['assets']:
    item=gate.setdefault(row['id'],{})
    item.update(status='private_candidate_delivered_awaiting_user',user_accepted=False)
    item['active_candidate']['inspection_scope']=row['internal_art_inspection']['scope']
gate_path.write_text(json.dumps(gate,indent=2)+'\n')
print(json.dumps({'assets':33,'user_accepted':0,'delivery':ledger['delivery'],'costs':ledger['resource_costs']},indent=2))
