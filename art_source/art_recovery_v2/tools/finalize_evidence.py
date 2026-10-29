"""Assemble genuine captures and exact file identities, without retouching them."""
import hashlib,json
from pathlib import Path
from PIL import Image,ImageOps,ImageDraw,ImageFont
here=Path(__file__).resolve().parents[1]
repo=here.parents[1]
godot=Path('D:/Temp/AshenOath/art_recovery_v2/anwen_godot')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25)
evidence=here/'evidence';evidence.mkdir(exist_ok=True)
refs=repo/'art_source/design_pack_v1/AshenOath_Asset_Pack/images/characters/C01_Anwen.png'
before=repo/'art_source/design_pack_v1/exports/C01_anwen_draft.png'
after=here/'exports/quarter.png'
sheet=Image.new('RGB',(1800,1120),'#292a2c');d=ImageDraw.Draw(sheet)
for i,(label,path) in enumerate([('SUPPLIED REFERENCE',refs),('BEFORE: REJECTED PROTOTYPE',before),('CURRENT REWORK: NOT ACCEPTED',after)]):
    d.text((i*600+12,20),label,font=font,fill='white')
    im=ImageOps.contain(Image.open(path).convert('RGB'),(580,1020))
    sheet.paste(im,(i*600+10+(580-im.width)//2,70+(1020-im.height)//2))
sheet.save(evidence/'anwen_comparison.jpg',quality=95)
for folder,target,duration in [(here/'exports/turntable',evidence/'blender_turntable.gif',100),
                                (godot,evidence/'godot_walk.gif',83)]:
    paths=sorted(folder.glob('walk_*.png' if folder==godot else '*.png'))
    if paths:
        frames=[ImageOps.contain(Image.open(p).convert('RGB'),(600,600)) for p in paths]
        frames[0].save(target,save_all=True,append_images=frames[1:],duration=duration,loop=0)
records={}
paths=list((here/'models').glob('*.blend'))+list((here/'exports').glob('*.png'))+list(godot.glob('*.png'))
for path in paths:
    records[str(path)]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
glb=repo/'outputs/AshenOathTheRoadBetweenCrowns/art_review/anwen/anwen_review.glb'
if glb.exists():records[str(glb)]={'bytes':glb.stat().st_size,'sha256':hashlib.sha256(glb.read_bytes()).hexdigest()}
(evidence/'identities.json').write_text(json.dumps({'status':'REWORK_NOT_ACCEPTED','files':records},indent=2))
