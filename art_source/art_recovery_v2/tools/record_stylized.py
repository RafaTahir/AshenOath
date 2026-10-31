"""Record an authored candidate and assemble unretouched visual comparisons."""
import argparse
import hashlib
import json
import struct
import shutil
import io
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
GAME = REPO/'outputs/AshenOathTheRoadBetweenCrowns'
ORDER = ['C01','M01','M05','C04','C02','C03','C11','C05','C06','C12','C07',
         'C08','C09','C10','P01','M02','M19','M20','M03','M04','M06','M08',
         'M13','M07','M11','M09','M10','M12','M14','M15','M16','M17','M18']

def identity(path):
    return {'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

parser = argparse.ArgumentParser()
parser.add_argument('--id', required=True, choices=ORDER)
parser.add_argument('--source', required=True)
parser.add_argument('--runtime', required=True)
parser.add_argument('--notes', required=True)
parser.add_argument('--inspected', action='store_true')
parser.add_argument('--views', help='Existing actual source-render folder; images are copied, not retouched')
parser.add_argument('--cleanup-complete',action='store_true')
parser.add_argument('--rig-fitted',action='store_true')
args = parser.parse_args()
source, runtime = Path(args.source).resolve(), Path(args.runtime).resolve()
assert source.is_relative_to(ROOT/'models') and runtime.is_relative_to(GAME/'art_review')
assert source.is_file() and runtime.is_file()
data = runtime.read_bytes()
assert data[:4] == b'glTF'
length, kind = struct.unpack_from('<II', data, 12)
assert kind == 0x4e4f534a
document = json.loads(data[20:20+length])
binary = data[28+length:]
images = []
for item in document.get('images',[]):
    if 'bufferView' in item:
        view = document['bufferViews'][item['bufferView']]
        start = view.get('byteOffset',0)
        encoded = binary[start:start+view['byteLength']]
        with Image.open(io.BytesIO(encoded)) as picture:
            images.append({'name':item.get('name',''),'width':picture.width,'height':picture.height,'encoded_bytes':len(encoded)})
metrics = {'triangles':sum(document['accessors'][p['indices']]['count']//3
                         for m in document.get('meshes',[]) for p in m['primitives']
                         if p.get('mode',4)==4 and 'indices' in p),
           'meshes':len(document.get('meshes',[])),
           'materials':len(document.get('materials',[])),
           'joints':sum(len(s['joints']) for s in document.get('skins',[])),
           'embedded_animations':[a.get('name','') for a in document.get('animations',[])]}
metrics['embedded_images'] = images
metrics['decoded_rgba8_image_bytes_no_mips'] = sum(i['width']*i['height']*4 for i in images)
registry = json.loads((GAME/'data/design_pack_assets.json').read_text(encoding='utf-8'))
entry = registry['assets'][args.id]
ledger_path = ROOT/'stylized_roster.json'
ledger = json.loads(ledger_path.read_text()) if ledger_path.exists() else {
    'status':'unpublished_candidates_awaiting_user_review',
    'production_order': ORDER,
    'art_target':'grounded_stylized_best_effort_not_photorealistic',
    'user_accepted_count':0,
    'assets':[{'id':i, 'status':'queued', 'user_accepted':False} for i in ORDER]}
record = next(a for a in ledger['assets'] if a['id']==args.id)
record.update({'source_path':str(source), 'runtime_path':str(runtime),
               'destination_resource':entry['path'],
               'source':identity(source), 'runtime':identity(runtime), 'metrics':metrics,
               'status':'candidate_exported_awaiting_user',
               'authored':True, 'exported':True, 'integrated':False,
               'internally_inspected':args.inspected, 'user_accepted':False,
               'cleanup_complete':args.cleanup_complete,
               'rig_fitted':args.rig_fitted,
               'limitations':args.notes})
ledger['exported_count'] = sum(a.get('exported',False) for a in ledger['assets'])
temporary = ledger_path.with_suffix('.json.tmp')
temporary.write_text(json.dumps(ledger,indent=2)+'\n')
temporary.replace(ledger_path)
gate_path = ROOT/'quality_gate.json'
gate = json.loads(gate_path.read_text())
remaining = [a['id'] for a in ledger['assets'] if not a.get('exported',False)]
gate['current_slice'] = remaining[0] if remaining else 'combined_private_review'
gate['active_roster_record'] = 'stylized_roster.json'
review = gate.setdefault(args.id,{})
if 'historical_review_status' not in review:
    review['historical_review_status'] = review.get('status','not_previously_reviewed')
review['status'] = 'private_candidate_final_user_acceptance_pending'
review['user_accepted'] = False
review['active_candidate'] = {'source_path':str(source),'runtime_path':str(runtime),
                            'runtime_sha256':record['runtime']['sha256'],
                            'inspection_scope':'source-view inspection only; motion/build records remain separate',
                            'record':'stylized_roster.json'}
cleanup = ['C04','C02','C03','C11','C05','C06','C12','C07','C08','C09','C10','P01','M02','M04','M05','M20']
pending_cleanup = [i for i in cleanup if not next(a for a in ledger['assets'] if a['id']==i).get('cleanup_complete',False)]
ledger['pending_cleanup'] = pending_cleanup
pending_rig=[a['id'] for a in ledger['assets'] if a['id']!='C01' and a['id'][0] in ('C','P') and not a.get('rig_fitted',False)]
ledger['pending_rig_fit']=pending_rig
temporary = ledger_path.with_suffix('.json.tmp')
temporary.write_text(json.dumps(ledger,indent=2)+'\n')
temporary.replace(ledger_path)
gate['active_roster_summary'] = {'exported':ledger['exported_count'],'required':33,
                                'user_accepted':0,'production_published':False,
                                'next_asset':remaining[0] if remaining else None,
                                'pending_shared_cleanup':pending_cleanup}
gate['active_roster_summary']['pending_rig_fit']=pending_rig
gate['current_slice']=(remaining or pending_cleanup or pending_rig or ['combined_private_review'])[0]
temporary = gate_path.with_suffix('.json.tmp')
temporary.write_text(json.dumps(gate,indent=2)+'\n')
temporary.replace(gate_path)

folder = ROOT/'evidence/stylized'/args.id
folder.mkdir(parents=True, exist_ok=True)
views = Path(args.views).resolve() if args.views else runtime.parent
for name in ('front','side','rear','quarter'):
    possibilities = [views/(name+'.png'), views/(name+'_workbench_texture.png')]
    if name=='rear': possibilities.append(views/'back_workbench_texture.png')
    captured = next((p for p in possibilities if p.is_file()),None)
    if captured is not None and captured.resolve()!=(folder/(name+'.png')).resolve():
        shutil.copy2(captured, folder/(name+'.png'))
references = REPO/'art_source/design_pack_v1/AshenOath_Asset_Pack/images'
reference = next(iter(references.rglob(args.id+'_*.png')),None)
originals = REPO/'art_source/design_pack_v1/exports'
before = next(iter(originals.rglob(args.id+'_model.png')),None)
if args.id=='C01':
    before = originals/'C01_anwen_draft.png'
after = folder/'quarter.png'
if after.is_file():
    panels = [('SUPPLIED DESIGN',reference),('ORIGINAL PROTOTYPE',before),
              ('STYLIZED CANDIDATE - NOT ACCEPTED',after)]
    sheet = Image.new('RGB',(1440,690),'#25272a')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
    for i,(label,path) in enumerate(panels):
        draw.text((i*480+10,12),label,fill='white',font=font)
        if path is None or not path.is_file():
            draw.text((i*480+10,100),'No corresponding source view',fill='white',font=font)
            continue
        picture = ImageOps.contain(Image.open(path).convert('RGB'),(460,630))
        sheet.paste(picture,(i*480+10+(460-picture.width)//2,45+(630-picture.height)//2))
    sheet.save(folder/'comparison.jpg',quality=93)
print(json.dumps({'id':args.id,'exported_count':ledger['exported_count'],
                  'runtime':record['runtime'],'metrics':metrics},indent=2))
