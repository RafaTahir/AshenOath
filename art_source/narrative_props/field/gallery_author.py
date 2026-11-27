"""Bake the mill accident, shore, first-aid bench and measurement horses.

From the repository root use Python 3 with NumPy, Pillow and Godot 4.6.3:
    python art_source/narrative_props/field/gallery_author.py --godot GODOT_BINARY
The editable stage and marker coordinates are in gallery.tscn and gallery.gd.
"""

from pathlib import Path
from collections import defaultdict
import argparse
import json
import math
import os
import random
import subprocess
import tempfile

import numpy as np
from PIL import Image


def unit(v):
    v = np.asarray(v, dtype=float)
    return v / max(np.linalg.norm(v), 1e-9)


class Piece:
    def __init__(self, seed):
        self.surfaces = defaultdict(lambda: dict(v=[], n=[], uv=[], idx=[]))
        self.random = random.Random(seed)

    def face(self, mat, points, uv, toward):
        points = np.asarray(points, dtype=float)
        normal = unit(np.cross(points[1] - points[0], points[2] - points[0]))
        if normal.dot(toward) < 0:
            points, uv, normal = points[::-1], uv[::-1], -normal
        if np.linalg.norm(normal) < 0.5:
            return
        g = self.surfaces[mat]
        start = len(g["v"]) // 3
        g["v"].extend(np.round(points, 5).flatten().tolist())
        g["n"].extend(np.tile(np.round(normal, 5), len(points)).tolist())
        g["uv"].extend(np.round(uv, 5).flatten().tolist())
        for i in range(1, len(points) - 1):
            g["idx"].extend([start, start + i + 1, start + i])

    def stock(self, mat, start, end, width, depth, ragged=0):
        """An adzed eight-sided squared timber; UV grain follows the shaft."""
        a, b = np.array(start), np.array(end)
        direction = unit(b - a)
        side = unit(np.cross(direction, (0, 1, 0) if abs(direction[1]) < .97 else (1, 0, 0)))
        up = np.cross(side, direction)
        w, d = width / 2, depth / 2
        bevel = min(w, d) * .20
        section = [(-w+bevel,-d),(w-bevel,-d),(w,-d+bevel),(w,d-bevel),
                   (w-bevel,d),(-w+bevel,d),(-w,d-bevel),(-w,-d+bevel)]
        near = [a + side*x + up*y for x,y in section]
        far = [b + side*x + up*y + direction*self.random.uniform(-ragged,ragged) for x,y in section]
        length = np.linalg.norm(b-a)
        for i in range(8):
            j = (i + 1) % 8
            wuv = np.linalg.norm(near[i]-near[j])/.4
            self.face(mat,[near[i],near[j],far[j],far[i]],[(0,0),(wuv,0),(wuv,length),(0,length)],
                      near[i]+near[j]-2*a)
        cap_uv = [(x/.4,y/.4) for x,y in section]
        self.face("break" if ragged else mat, near, cap_uv, -direction)
        self.face("break" if ragged else mat, far, cap_uv, direction)

    def tube(self, mat, points, radius, n=7, closed=False):
        points = np.asarray(points)
        rings = []
        for i, c in enumerate(points):
            d = unit(points[(i+1)%len(points)]-points[(i-1)%len(points)]) if closed else unit(
                points[min(i+1,len(points)-1)]-points[max(0,i-1)])
            side = unit(np.cross(d, (0,1,0) if abs(d[1]) < .94 else (1,0,0)))
            up = np.cross(d,side)
            rings.append([c + radius*(side*math.cos(j*math.tau/n)+up*math.sin(j*math.tau/n)) for j in range(n)])
        for i in range(len(points) if closed else len(points)-1):
            j = (i+1)%len(points)
            for k in range(n):
                l = (k+1)%n
                self.face(mat,[rings[i][k],rings[i][l],rings[j][l],rings[j][k]],
                          [(k/n,0),(l/n,0),(l/n,1),(k/n,1)],rings[i][k]-points[i])

    def stone(self, centre, size, height, twist=0):
        """Hammer-dressed stone, with sheared corners and a chipped wet face."""
        x,y,z = centre
        w,d = size[0]/2,size[1]/2
        plan = [(-w*.73,-d),(w*.71,-d),(w,-d*.64),(w,d*.78),
                (w*.83,d),(-w*.75,d),(-w,d*.7),(-w,-d*.79)]
        rings = []
        for level,scale in ((0, .92),(.16,1),(.80,1),(1,.88)):
            ring = []
            for u,v in plan:
                dx = (u*math.cos(twist)-v*math.sin(twist))*scale
                dz = (u*math.sin(twist)+v*math.cos(twist))*scale
                ring.append(np.array((x+dx,y+height*level+self.random.uniform(-.006,.006),z+dz)))
            rings.append(ring)
        for a,b in zip(rings,rings[1:]):
            for i in range(8):
                j=(i+1)%8
                points=[a[i],a[j],b[j],b[i]]
                uv=[((v[0]+v[2])/.65,v[1]/.65) for v in points]
                self.face("granite",points,uv,((a[i][0]-x),0,(a[i][2]-z)))
        self.face("granite",rings[-1],[(v[0]/.65,v[2]/.65) for v in rings[-1]],(0,1,0))

    def link(self, centre, tangent, half_width, half_length, twist):
        line = unit(tangent)
        side = unit(np.cross(line,(0,0,1) if abs(line[2])<.85 else (1,0,0)))
        across = side*math.cos(twist)+np.cross(line,side)*math.sin(twist)
        self.tube("iron", [np.array(centre)+across*(math.cos(i*math.tau/14)*half_width)
                           + line*(math.sin(i*math.tau/14)*half_length) for i in range(14)],.008,6,True)

    def wedge(self, centre, width, length, rise):
        x,y,z=centre
        points=np.array([[x-width/2,y,z],[x+width/2,y,z],[x+width/2,y,z+length],
                         [x-width/2,y,z+length],[x-width/2,y+rise,z],[x+width/2,y+rise,z]])
        for ids,normal in [([0,1,2,3],[0,-1,0]),([4,3,2,5],[0,1,0]),([0,4,5,1],[0,0,-1]),
                           ([0,3,4],[-1,0,0]),([1,5,2],[1,0,0])]:
            self.face("break",points[ids],[(points[i][0]*3,points[i][2]*3+points[i][1]) for i in ids],normal)


def assemble():
    base, load, shore, bench, measure, taut, slack = (Piece(i+1414) for i in range(7))
    # Three retaining courses collapse into the open relief cut. The two lowest
    # steps are wide enough for the rescued miller's shoulders.
    for i in range(7):
        x=-1.69+i*.48
        for j in range(2 if i in (0,1,5,6) else 1):
            base.stone((x+j*.08,j*.225,-2.15),(.47,.46),.235,.035*(i%3-1))
    base.stone((.90,.0,-.63),(.95,1.41),.235)
    base.stone((.93,.0,-1.57),(.9,.49),.36,-.045)
    base.stone((1.04,.31,-1.70),(.79,.42),.24,-.045)
    for i,(x,z) in enumerate([(-1.57,-1.43),(-1.41,-1.12),(.22,-1.09),(.38,-.64),(1.48,-.95),(1.32,-1.88)]):
        base.stone((x,0,z),(.30,.22),.13+.04*(i%3),.39*i)
    base.stock("oak_dark",(-1.27,0,-1.62),(-1.24,1.49,-1.52),.24,.25)
    base.stock("oak",(-1.66,.05,-1.79),(-1.27,1.30,-1.56),.12,.15)
    base.stock("oak_dark",(-1.47,1.44,-1.52),(-1.02,1.44,-1.52),.34,.10)
    # A lipped length of channel behind the steps catches the still-backlogged water.
    lane=[(-1.76,-1.96),(-1.3,-1.93),(-.82,-2.0),(-.19,-1.94),(.4,-1.93),(1.52,-2.01)]
    for (x,z),(u,v) in zip(lane,lane[1:]):
        base.face("water",[(x,.027,z),(u,.027,v),(u,.027,v+.60),(x,.027,z+.6)],
                  [(x*2,0),(u*2,0),(u*2,1),(x*2,1)],(0,1,0))
    for i in range(4):
        base.stock("oak_dark",(1.59,.09,-1.94+i*.32),(1.53,.28+i*.13,-1.74+i*.28),.11,.12,.055)
    # One service handrail survives. The far half ended in a split, not a neat saw cut.
    base.stock("oak_dark",(1.54,.18,-1.60),(1.50,1.15,-1.62),.09,.10)
    base.stock("oak",(1.51,1.08,-1.63),(1.53,.70,-.57),.105,.083,.048)
    # A single piece pivots about the surviving left corbel. Deck boards,
    # severed joists and the old iron strap move with the load.
    load.stock("oak_dark",(0,0,0),(2.72,0,0),.28,.31,.075)
    for i in range(9):
        x=i*.29+.11
        load.stock("oak",(x,.186,-.51),(x,.186,.18+math.sin(i)*.11),.278,.065,.012 if i<6 else .07)
    for x in [.30,1.50,2.24]:
        load.stock("oak_dark",(x,.055,-.59),(x,.055,-.03),.17,.17,.035)
    # The far tenon has torn along the grain. Leave long pale fibres in
    # profile at the broken end of the gallery, where the chain took it.
    for i in range(3):
        y=-.09+i*.063
        z=.035+i*.025
        start=(2.66,y,z)
        tip=(2.85+.07*i,y-.043,z+.023)
        load.face("break",[start,(2.68,y+.038,z),tip],[(0,0),(.11,0),(.035,.65)],(0,0,1))
        load.face("break",[start,tip,(2.65,y+.02,z-.04)],[(0,0),(.04,.65),(.15,0)],(0,-1,0))
    # Folded U-strap on the large sill with hand-forged rivet heads.
    for x in (.47,2.08):
        load.stock("iron",(x,-.133,.149),(x,.155,.149),.015,.080)
        load.stock("iron",(x,.155,-.14),(x,.155,.14),.078,.018)
        for y in (-.078,.10):
            load.tube("iron",[(x,y,.154),(x,y,.168)],.021)
    # The two groups show the retaining chain under different loads.
    for part,is_slack in [(taut,False),(slack,True)]:
        pts=[]
        for i in range(15):
            t=i/14
            if is_slack:
                pts.append(np.array((1.54+.32*math.sin(t*math.pi*.65),.99-.93*math.sin(t*math.pi*.5),-1.58+.66*t)))
            else:
                pts.append(np.array((1.54-.59*t,.99-.69*t-.08*math.sin(t*math.pi),-1.58+.80*t)))
        for i,point in enumerate(pts):
            tangent=pts[min(len(pts)-1,i+1)]-pts[max(0,i-1)]
            part.link(point,tangent,.036,.053,.22+(i%2)*1.25)
    # Two splayed shores and opposed pale wedges carry the weight after rescue.
    top=(1.10,1.119,-1.52)
    shore.stock("oak",(1.35,.05,-1.08),top,.14,.14)
    shore.stock("oak",(.81,.05,-1.95),top,.14,.14)
    shore.stock("oak_dark",(.73,1.126,-1.52),(1.43,1.126,-1.52),.24,.092)
    shore.wedge((1.03,1.169,-1.61),.28,.265,.069)
    shore.stock("oak_dark",(.72,.058,-1.97),(1.38,.058,-1.05),.22,.10)
    # The dressing bench has real, level support at 0.49 m. Splints rest at
    # the end inside a partly unwound bandage, clear of Tor's sitting position.
    for z in (-1.30,-1.10):
        bench.stock("oak",(-.94,.444,z),(.89,.444,z),.19,.092)
    for x in (-.73,.68):
        for z in (-1.12,-1.32):
            bench.stock("oak_dark",(x,.02,z),(x,.40,z),.102,.11)
    bench.stock("oak_dark",(-.80,.19,-1.22),(.74,.19,-1.22),.064,.09)
    for x in (.56,.65):
        bench.stock("break",(x,.507,-1.39),(x+.025,.507,-1.103),.041,.024)
    bench.tube("linen",[(.72,.546,-1.29),(.80,.546,-1.29)],.05,14)
    bench.face("linen",[(.77,.491,-1.28),(.86,.491,-1.28),(.86,.491,-1.12),(.77,.491,-1.12)],
               [(0,0),(1,0),(1,2),(0,2)],(0,1,0))
    # Tor cannot close the loop with one hand. The bag lies open below the
    # bench with the hammer put away and one loop trailing towards the floor.
    front=[(-.82,.03,-.91),(-.37,.03,-.91),(-.33,.245,-.92),(-.43,.28,-.94),(-.79,.27,-.94),(-.86,.20,-.92)]
    back=[(x,y,z-.21) for x,y,z in front]
    bench.face("leather",front,[(x*2,y*2) for x,y,z in front],(0,0,1))
    bench.face("leather",back,[(x*2,y*2) for x,y,z in back],(0,0,-1))
    for i,j in ((0,1),(1,2),(2,3),(4,5),(5,0)):
        bench.face("leather",[front[i],front[j],back[j],back[i]],[(0,0),(1,0),(1,1),(0,1)],
                   (front[i][0]+front[j][0]+1.19,front[i][1]+front[j][1]-.27,0))
    bench.stock("oak",(-.76,.264,-1.035),(-.31,.324,-1.005),.039,.035)
    bench.stock("iron",(-.76,.255,-1.10),(-.76,.255,-.972),.062,.063)
    bench.tube("leather",[(-.631,.267,-.938),(-.625,.221,-.901),(-.60,.087,-.876),(-.575,.105,-.875)],.013)
    # Measuring trestles, a replacement sill, an old strap with three cut
    # marks and a try-square, without putting a hammer back into Tor's hand.
    for x in (-.64,.65):
        for z in (-1.40,-.73):
            measure.stock("oak_dark",(x,.03,z),(x,.681,-1.06),.085,.1)
        measure.stock("oak",(x,.665,-1.34),(x,.665,-.83),.114,.082)
    measure.stock("break",(-.98,.79,-1.06),(.95,.79,-1.06),.20,.17)
    measure.stock("oak_dark",(-.67,.31,-1.05),(.69,.31,-1.05),.063,.11)
    measure.stock("iron",(.09,.886,-1.20),(.09,.886,-.940),.049,.014)
    measure.stock("oak_dark",(.052,.899,-.94),(.34,.899,-.94),.050,.03)
    for i in range(3):
        measure.stock("iron",(.43+.038*i,.877,-1.135),(.44+.038*i,.877,-1.060),.009,.004)
    return {"GalleryBank":base, "FallenLoad":load, "Shores":shore, "DressingBench":bench,
            "MarkingHorses":measure, "CaughtChain":taut, "FreedChain":slack}


def bake(godot, output):
    # Share the existing weathered oak, iron and stone appearance of Sella's gate.
    import importlib.util
    gate = Path(__file__).resolve().parents[1] / "prologue/gate_author.py"
    spec = importlib.util.spec_from_file_location("ashen_gate_materials", gate)
    materials = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(materials)
    with tempfile.TemporaryDirectory(prefix="ashen-gallery-") as name:
        folder = Path(name)
        (folder / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Gallery mesh bake"\n')
        materials.make_textures(folder)
        with Image.open(folder/"oak.png") as texture:
            a=np.asarray(texture).astype(float)
        for tag,base,contrast in [("break",(155,122,84),.65),("linen",(186,175,146),.16),
                                  ("water",(55,73,69),.22),("leather",(91,61,42),.42)]:
            brightness=(a.mean(axis=2)-a.mean())*contrast
            Image.fromarray(np.uint8(np.clip(np.array(base)+brightness[:,:,None],0,255))).save(folder/(tag+".png"))
        (folder/"granite.png").write_bytes((folder/"stone.png").read_bytes())
        data={name:piece.surfaces for name,piece in assemble().items()}
        (folder/"gallery.json").write_text(json.dumps(data,separators=(",",":")))
        cmd=[str(godot),"--headless","--path",str(folder),"--audio-driver","Dummy","--script",
             str(Path(__file__).with_name("gallery_bake.gd")),"--",str(folder),str(output.resolve())]
        subprocess.run(cmd,check=True,creationflags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0)


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",required=True,type=Path)
    parser.add_argument("--output",type=Path,default=Path(__file__).resolve().parents[3]/
                        "outputs/AshenOathTheRoadBetweenCrowns/assets/narrative_props/field/gallery_art.scn")
    args=parser.parse_args()
    bake(args.godot,args.output)
