"""Assemble genuine captures and exact file identities, without retouching them."""
import hashlib,json,argparse,struct,io
from pathlib import Path
from PIL import Image,ImageOps,ImageDraw,ImageFont
here=Path(__file__).resolve().parents[1]
repo=here.parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--revision',default='')
parser.add_argument('--model',default='C01_anwen_reconstruction_v002.blend')
parser.add_argument('--godot-dir',default='D:/Temp/AshenOath/art_recovery_v2/anwen_godot')
parser.add_argument('--asset-dir',default='anwen')
args=parser.parse_args()
godot=Path(args.godot_dir)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25)
evidence=(here/'evidence'/args.revision).resolve()
assert evidence.is_relative_to((here/'evidence').resolve())
evidence.mkdir(parents=True,exist_ok=True)
refs=repo/'art_source/design_pack_v1/AshenOath_Asset_Pack/images/characters/C01_Anwen.png'
before=repo/'art_source/design_pack_v1/exports/C01_anwen_draft.png'
after=evidence/'quarter.png' if args.revision else here/'exports/quarter.png'
sheet=Image.new('RGB',(1800,1120),'#292a2c');d=ImageDraw.Draw(sheet)
for i,(label,path) in enumerate([('SUPPLIED REFERENCE',refs),('BEFORE: REJECTED PROTOTYPE',before),('CURRENT REWORK: NOT ACCEPTED',after)]):
    d.text((i*600+12,20),label,font=font,fill='white')
    im=ImageOps.contain(Image.open(path).convert('RGB'),(580,1020))
    sheet.paste(im,(i*600+10+(580-im.width)//2,70+(1020-im.height)//2))
sheet.save(evidence/'anwen_comparison.jpg',quality=95)
turntable=evidence/'turntable' if args.revision else here/'exports/turntable'
for folder,target,duration in [(turntable,evidence/'blender_turntable.gif',100),
                                (godot,evidence/'godot_walk.gif',42)]:
    paths=sorted(folder.glob('walk_*.png' if folder==godot else '*.png'))
    if paths:
        frames=[ImageOps.contain(Image.open(p).convert('RGB'),(600,600)) for p in paths]
        frames[0].save(target,save_all=True,append_images=frames[1:],duration=duration,loop=0)
records={}
paths=([here/'models'/args.model]+list(evidence.glob('*.png')) if args.revision else list((here/'models').glob('*.blend'))+list((here/'exports').glob('*.png')))+list(godot.glob('*.png'))
if args.revision:
    paths += [p for p in (evidence/'godot_level').glob('*') if p.is_file()]
    staff_source=here/'models/C01_ash_staff_v002.blend'
    if staff_source.exists():paths.append(staff_source)
for path in paths:
    records[str(path)]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
asset_dir=(repo/'outputs/AshenOathTheRoadBetweenCrowns/art_review'/args.asset_dir).resolve()
assert asset_dir.is_relative_to((repo/'outputs/AshenOathTheRoadBetweenCrowns/art_review').resolve())
metrics={}
for glb in asset_dir.glob('*.glb'):
    raw=glb.read_bytes();size,kind=struct.unpack_from('<II',raw,12)
    assert kind==0x4e4f534a
    doc=json.loads(raw[20:20+size]);binary_offset=20+size
    binary=raw[binary_offset+8:]
    textures=[]
    for info in doc.get('images',[]):
        if 'bufferView' not in info:continue
        view=doc['bufferViews'][info['bufferView']];start=view.get('byteOffset',0)
        image=Image.open(io.BytesIO(binary[start:start+view['byteLength']]))
        textures.append({'name':info.get('name',''),'width':image.width,'height':image.height,'encoded_bytes':view['byteLength']})
    metrics[glb.name]={'triangles':sum(doc['accessors'][p['indices']]['count']//3 for m in doc.get('meshes',[]) for p in m['primitives'] if p.get('mode',4)==4),
        'meshes':len(doc.get('meshes',[])),'materials':len(doc.get('materials',[])),'joints':sum(len(s['joints']) for s in doc.get('skins',[])),
        'images':textures,'decoded_rgba8_image_bytes_no_mips':sum(t['width']*t['height']*4 for t in textures)}
for path in asset_dir.iterdir():
    if path.suffix not in ('.png','.glb'):continue
    records[str(path)]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(evidence/'identities.json').write_text(json.dumps({'status':'REWORK_NOT_ACCEPTED','review_derivative_not_production_candidate':True,'metrics':metrics,'files':records},indent=2))
print('EVIDENCE_RECORDED',evidence,flush=True)
