"""Author soft-ended brow fibres for the existing fitted brow surfaces."""
from pathlib import Path
from PIL import Image,ImageDraw
import random,math,argparse
parser=argparse.ArgumentParser()
parser.add_argument('--output',default='evidence/anwen_v014')
parser.add_argument('--density',type=int,default=410)
args=parser.parse_args()
here=Path(__file__).resolve().parents[1]
out=(here/args.output).resolve()
assert out.is_relative_to(here)
out.mkdir(parents=True,exist_ok=True)
rng=random.Random(514);s=3
im=Image.new('RGBA',(512*s,128*s),(0,0,0,0))
for hair in range(args.density):
    x=rng.uniform(0,510);t=x/512
    root=rng.uniform(55,122);height=rng.uniform(25,65)
    dx=6+30*t;shade=rng.uniform(.65,1.3)
    color=tuple(int(c*shade) for c in (98,77,56))
    points=[]
    layer=Image.new('RGBA',im.size,(0,0,0,0));draw=ImageDraw.Draw(layer)
    for i in range(12):
        u=i/11
        points.append(((x+dx*u)*s,(root-height*u+4*u*u)*s))
    for i,(a,b) in enumerate(zip(points,points[1:])):
        alpha=int(245*(1-i/12)*min(1,3*t+.25)*min(1,(1-t)*5+.15))
        draw.line([a,b],fill=(*color,alpha),width=max(1,int(rng.uniform(.6,1.1)*s)))
    im=Image.alpha_composite(im,layer)
im.resize((512,128),Image.Resampling.LANCZOS).save(out/'Anwen_Brow_Fibers.png')
print(out/'Anwen_Brow_Fibers.png')
