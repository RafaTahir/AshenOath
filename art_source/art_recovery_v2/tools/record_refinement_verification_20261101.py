"""Record exact art evidence without turning it into user/gameplay approval."""
import hashlib,json,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];GAME=ROOT.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
def read(p):return json.loads(p.read_text())
def write(p,j):p.write_text(json.dumps(j,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
ledger=read(ROOT/'stylized_roster.json');gate=read(ROOT/'quality_gate.json')
level_path=ROOT/'evidence/refinement_20261101/level/level_roster.json';level=read(level_path)
assert not level['journey_started'] and len(level['assets'])==33
staged={r['id']:r for r in level['assets']};records=[]
for row in ledger['assets']:
    key=row['id'];native_path=ROOT/'evidence/refinement_20261101/native'/key/'review.json';native=read(native_path)
    assert native['asset_sha256']==row['runtime']['sha256'] and native['authored_material_contract']
    record=staged[key];assert record['source_sha256']==row['runtime']['sha256']
    prepared=GAME/record['prepared'].removeprefix('res://')
    assert sha(prepared)==record['prepared_sha256'],key+' prepared scene changed since art staging'
    row.setdefault('previous_internal_art_inspection',row.get('internal_art_inspection',{}))
    row['internal_art_inspection']={'scope':'Final 2026-11-01 source views, isolated native materials/clip samples, prepared Greyfen art turntable; not gameplay/user acceptance',
       'native_record':str(native_path),'prepared_greyfen_record':str(level_path),'runtime_sha256':row['runtime']['sha256'],'prepared_sha256':record['prepared_sha256'],'user_accepted':False}
    row['internally_inspected']=True
    row['refinement_20261101'].update(native_inspected=True,prepared_art_staged=True)
    candidate_path=Path(row['refinement_20261101']['record']);candidate=read(candidate_path)
    candidate.update(compiled_runtime_path=row['runtime_path'],published_resource_path=row['destination_resource'],
       embedded_export_scope='Local review intermediate; the editable master and losslessly shared compiled runtime are retained for delivery')
    write(candidate_path,candidate)
    for history in row.get('refinement_history',[]):
        history['availability_scope']='Local authoring workspace; intermediate exports may be untracked. Oldest retained production baseline is recorded separately.'
    records.append({'id':key,'runtime_sha256':row['runtime']['sha256'],'native_record':str(native_path),'prepared':record['prepared'],'prepared_sha256':record['prepared_sha256']})
ledger['current_refinement'].update(status='native_and_prepared_art_verified_package_pending',native_inspected=33,prepared_art_staged=33,journey_started=False)
gate['current_refinement']=ledger['current_refinement'];gate['active_roster_summary']['internally_inspected']=33
write(ROOT/'stylized_roster.json',ledger);write(ROOT/'quality_gate.json',gate)
write(ROOT/'evidence/refinement_20261101/verification.json',{'status':'art_source_native_and_prepared_hashes_verified','assets':records,'journey_started':False,'user_accepted':False,'gameplay_performance_acceptance':False})

document=ROOT/'REFINEMENT_20261101.md'
if document.exists():
    lines=document.read_text(encoding='utf-8-sig').splitlines()
    by_id={r['id']:r for r in ledger['assets']}
    for i,line in enumerate(lines):
        for key,row in by_id.items():
            if not line.startswith('| '+key+' '):continue
            parts=line.split('|')
            source=Path(row['source_path']).relative_to(ROOT).as_posix()
            candidate=Path(os.path.relpath(row['refinement_20261101']['record'],ROOT)).as_posix()
            parts[3]=f' [source]({source}) · [candidate]({candidate}) · [native](evidence/refinement_20261101/native/{key}/review.json) '
            if key in ['M01','M03','M05','M19','M20'] and 'Debanded' not in parts[2]:parts[2]=parts[2].rstrip()+' Debanded skin retains its original mean palette. '
            if key=='M18' and 'seated' not in parts[2].lower():parts[2]=parts[2].rstrip()+' Eye rims, spiracles and mouth are seated against the disc. '
            lines[i]='|'.join(parts)
    text='\n'.join(lines)+'\n'
    text=text.replace('Authoring and the first native art pass cover all 33 bodies. Later finishing bytes still need matching native captures: five skin-albedo repairs, M04 material readability and M18 presentation. Exact final native validation, production packaging and Git publication are **pending main**. The task authorizes eventual push; this note adds no approval stop. User visual acceptance remains unrecorded.',
       'All 33 bodies have final SHA-matched native material/motion captures and prepared Greyfen art staging. Five inherited skin-albedo patterns, M04 iron readability and M18 surface contact have been repaired and recaptured. Production packaging and Git publication remain pending below. The user authorized push; no candidate is marked user-accepted.')
    text=text.replace('Pending finishing updates and main reconciliation','Passed: all 33 current runtime and prepared actor identities')
    text=text.replace('Links below are its snapshot at writing; the five skin sources and M18 may advance during final finishing. **The roster remains authoritative.**','Links below identify the final finishing masters. **The roster remains authoritative.**')
    text=text.replace('Five skin-albedo repairs, M04 readability and M18 presentation are still being reconciled into exact current evidence.','Those finishing corrections are now SHA-matched in the final native evidence.')
    text=text.replace('Main will finish SHA-matched recaptures, refresh catalog/dependency ownership, package under existing byte limits, record final size/source QA, then record development/main commits and the Git-triggered publication receipt. Existing publication authorization remains in force.',
       'Source/native/prepared art checks and catalog/dependency ownership are complete. Packaging and publication are recorded below after their exact byte/hash and Git checks. Existing publication authorization remains in force.')
    document.write_text(text,encoding='utf-8')
print('Verified 33 final native and prepared actor identities; user acceptance remains unrecorded.')
