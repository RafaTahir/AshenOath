"""Author a deterministic strand/alpha texture for the fitted 3D hair cards."""
from pathlib import Path
from PIL import Image,ImageDraw
import random,math

OUT=Path(__file__).resolve().parents[1]/'evidence/anwen_v007'
OUT.mkdir(parents=True,exist_ok=True)
rng=random.Random(199)
scale=3;width=1024;height=2048
image=Image.new('RGBA',(width*scale,height*scale),(0,0,0,0))
draw=ImageDraw.Draw(image)
for tile in range(4):
    for strand in range(170):
        root=rng.uniform(5,251)
        phase=rng.uniform(0,math.tau);bend=rng.uniform(-14,14)
        start=rng.uniform(0,.045);end=rng.uniform(.82,1.02)
        shade=rng.uniform(.50,1)
        if rng.random()<.12:shade=1.12
        rgb=tuple(int(c*shade) for c in (157,150,135))
        points=[]
        for i in range(80):
            t=start+(end-start)*i/79
            x=root+math.sin(t*4.5+phase)*3+bend*t*t
            y=t*(height-1)
            points.append(((tile*256+x)*scale,y*scale))
        for i,(a,b) in enumerate(zip(points,points[1:])):
            t=i/78
            alpha=int(230*min(1,t*15+.25)*min(1,(1-t)*11))
            draw.line([a,b],fill=(*rgb,alpha),width=max(1,int(rng.uniform(.55,.95)*scale)))
image.resize((width,height),Image.Resampling.LANCZOS).save(OUT/'Anwen_Authored_AshStrands.png')
print(OUT/'Anwen_Authored_AshStrands.png')
