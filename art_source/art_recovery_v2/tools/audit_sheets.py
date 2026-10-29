"""Lay out unaltered reference/render evidence; never generates model artwork."""
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageFont
root=Path(__file__).resolve().parents[3]
base=root/'art_source/design_pack_v1/AshenOath_Asset_Pack/images'
out=Path('D:/Temp/AshenOath/art_recovery_v2/audit')
refs={p.stem[:3]:p for p in base.rglob('*.png')}
ids=sorted(refs)+['P01']
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22)
for start in range(0,len(ids),4):
    sheet=Image.new('RGB',(1920,1440),'#27292b')
    draw=ImageDraw.Draw(sheet)
    for row,id in enumerate(ids[start:start+4]):
        y=row*360
        draw.text((8,y+6),id+' - REFERENCE | GODOT REAR / SIDE / FRONT / REAR 3/4',font=font,fill='white')
        paths=[refs.get(id)]+[out/(id+'_'+v+'.png') for v in ('front','side','rear','quarter')]
        for col,path in enumerate(paths):
            if not path or not path.exists(): continue
            box=(600,320) if col==0 else (320,320)
            img=ImageOps.contain(Image.open(path).convert('RGB'),box)
            x=0 if col==0 else 600+(col-1)*330
            sheet.paste(img,(x+(box[0]-img.width)//2,y+38))
    sheet.save(out/f'sheet_{start//4+1:02}.jpg',quality=94)
