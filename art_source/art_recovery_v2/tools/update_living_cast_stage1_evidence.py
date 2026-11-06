"""Record authored candidates separately from runtime/user acceptance."""
import hashlib
import json
from pathlib import Path

REPO=Path(__file__).resolve().parents[3]
GAME=REPO/'outputs/AshenOathTheRoadBetweenCrowns'
MODELS=REPO/'art_source/art_recovery_v2/models/living_cast_20261107'
REPORTS=GAME/'release_reports/living_cast_20261107'
TOOLS=['author_living_cast_20261107.py','author_rook_station_satchel.py',
       'build_living_cast_coverage.py','export_living_cast_baseline.gd',
       'inspect_living_cast_rigs.py','inspect_living_cast_grips.py',
       'verify_living_cast_sources.py','verify_living_cast_reach.py',
       'update_living_cast_stage1_evidence.py']


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def relative(path):return path.relative_to(REPO).as_posix()
def read(path):return json.loads(path.read_text())


def main():
    ledger_path=REPORTS/'asset_coverage.json';ledger=read(ledger_path)
    compiled=read(MODELS/'library_compile_C01_C04_C03_C02.json')
    rows={row['id']:row for row in ledger['cast']}
    runtime_files=[]
    for record in compiled['libraries']:
        asset=record['asset'];folder=MODELS/asset
        source=read(folder/'authoring.json');checked=read(folder/'source_verification.json')
        output=GAME/record['path'][6:]
        if checked['status']!='source_contract_pass' or checked['review_glb_sha256']!=record['source_sha256'] or sha(Path(source['review_glb']))!=record['source_sha256'] or sha(output)!=record['sha256']:
            raise ValueError('Authored, verified and compiled bytes differ: '+asset)
        row=rows[asset];row['authored']=True
        old_hash=row.get('candidate_motion',{}).get('sha256')
        if old_hash and old_hash!=record['sha256']:row['runtime_verified']=False
        row['life_status']='authored_and_compiled_pending_runtime_review' if not row.get('runtime_verified') else row['life_status']
        row['geometry_status']='Production mesh, rest rig, root scale and collision dimensions retained unchanged.'
        row['candidate_motion']={key:record[key] for key in ['path','sha256','bytes','source_sha256']}
        packed_paths={entry['path'] for entry in ledger['runtime_asset_resources']}
        row['candidate_motion']['present_in_selected_export']=record['path'] in packed_paths
        row['source_review']={'work_apex_clay_reviewed':True,'native_clips':list(source['clips']),
            'source_contract_verified':True,'runtime_visual_acceptance':False}
        row['evidence']=[relative(folder/'authoring.json'),relative(folder/'source_verification.json'),
            relative(folder/'Life_Work_50.png'),relative(MODELS/'source_reach.json'),
            relative(MODELS/'library_compile_C01_C04_C03_C02.json')]
        if (folder/'palm_surface_inspection.json').exists():row['evidence'].append(relative(folder/'palm_surface_inspection.json'))
        row['notes']=['Five authored native clips: two idle variants, occupation, listening and speaking.',
            'Work contacts and source clay review do not assert in-game grip/garment or user acceptance.']
        runtime_files.append(output)
    prop=read(MODELS/'props/satchel_compile.json')
    prop_files=[GAME/prop['path'][6:]]+[GAME/item['path'][6:] for item in prop['resources']]
    if sha(prop_files[0])!=prop['sha256']:raise ValueError('Compiled satchel scene differs')
    for item,path in zip(prop['resources'],prop_files[1:]):
        if sha(path)!=item['sha256']:raise ValueError('Compiled satchel mesh differs')
    runtime_files+=prop_files
    ledger['compiled_additions']=[{'id':'rook_station_satchel','path':prop['path'],
        'sha256':prop['sha256'],'authored':True,'runtime_verified':False,'user_accepted':False,
        'present_in_selected_export':prop['path'] in packed_paths,
        'note':'Retained Bag-derived supported station prop; does not claim pickup/carried behavior.',
        'evidence':[relative(MODELS/'props/satchel_authoring.json'),relative(MODELS/'props/satchel_compile.json')]}]
    ledger.pop('compiled_additions_pending_export',None)
    ledger['stage1_authored_runtime_bytes']=sum(path.stat().st_size for path in runtime_files)
    ledger_path.write_text(json.dumps(ledger,indent=2)+'\n')
    files=[]
    for directory in [MODELS,REPO/'art_source/art_recovery_v2/evidence/living_cast_20261107']:
        files.extend(path for path in directory.rglob('*') if path.is_file() and path.suffix in {'.blend','.glb','.png','.json','.md'})
    files.extend(REPO/'art_source/art_recovery_v2/tools'/name for name in TOOLS)
    for name in ['build_living_cast_libraries.gd','build_living_cast_station_props.gd']:
        path=GAME/'tools'/name;files.append(path)
        if Path(str(path)+'.uid').exists():files.append(Path(str(path)+'.uid'))
    files.extend(runtime_files);files.append(ledger_path)
    entries=[]
    for path in sorted(set(files)):
        size=path.stat().st_size
        if size>=100*1024*1024:raise ValueError('Source file exceeds publication limit: '+str(path))
        entries.append({'path':relative(path),'bytes':size,'sha256':sha(path)})
    manifest={'scope':'asset-authoring agent Stage1 owned files only','files':entries,
        'manifest_path':relative(REPORTS/'stage1_asset_files.json'),
        'runtime_candidate_bytes':ledger['stage1_authored_runtime_bytes'],
        'source_art_in_web':False,'runtime_reviewed':False,'user_accepted':False,
        'notes':['Stage the listed files plus this manifest; exclude unrelated untracked art and .blend1 iteration backups.',
                 'Refresh after any final builder invocation that regenerates compiled resource bytes.']}
    (REPORTS/'stage1_asset_files.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(len(entries),'owned files plus manifest;',manifest['runtime_candidate_bytes'],'runtime candidate bytes')


if __name__=='__main__':main()
