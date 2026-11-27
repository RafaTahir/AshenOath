"""Build the recovery under the willow and Mira's alder stretcher.

Run: python art_source/narrative_props/field/author_willow.py --godot GODOT_BINARY
Requires NumPy, Pillow and Godot 4.6.3. All dimensions are metres.
"""
import argparse
import json
from math import cos, sin, pi, exp
from pathlib import Path
import random
import subprocess
import tempfile

import numpy as np
from PIL import Image

TAU = 2*pi
MATERIALS = {
    "bark": (87, 75, 55), "alder": (128, 104, 72), "cut": (173, 145, 97),
    "granite": (93, 94, 84), "lichen": (139, 145, 99), "reed": (113, 111, 57),
    "leaf": (89, 107, 65), "rope": (167, 144, 96), "cloak": (63, 89, 87),
    "shawl": (115, 77, 55), "hem": (194, 153, 72), "boot": (90, 55, 36),
    "soil": (91, 78, 61), "coat": (82, 105, 116), "brass": (168, 137, 76),
    "linen": (151, 151, 124)
}
TILES = list(MATERIALS)


def unit(v):
    a = np.asarray(v, dtype=float)
    return a / max(np.linalg.norm(a), 1e-9)


def atlas(folder):
    rng = np.random.default_rng(3705)
    sz = 96
    x, y = np.meshgrid(np.arange(sz), np.arange(sz))
    result = np.zeros((4*sz, 4*sz, 3), dtype=np.uint8)
    for i, (name, color) in enumerate(MATERIALS.items()):
        noise = rng.normal(0, 3.2, (sz,sz))
        if name in ("bark","alder","cut"):
            if name == "cut":
                grain = 8*np.sin(np.hypot(x-27,y-46)*0.91)
            else:
                grain = 12*np.sin(x*0.75+np.sin(y*.07)*1.3) + 7*np.cos(x*0.23+np.sin(y*.045))
                grain -= 15*(np.cos(x*1.48 + np.sin(y*.1)) > .97)
        elif name in ("shawl","cloak","coat","linen","hem"):
            grain = 7*np.cos(x*pi/2)*np.cos(y*pi/2) + 4*np.sin((y+np.abs((x%20)-10))*.83)
        elif name == "rope":
            grain = 10*np.sin(x*.31-y*.64) + 6*np.sin(x*.89-y*1.76)
        elif name in ("granite","lichen","soil"):
            grain = 13*np.sin(x*.061+np.cos(y*.11)*1.6) + 8*np.sin(x*.24-y*.16)*np.cos(y*.34) + noise*.8
        else:
            grain = 5*np.sin(x*.19)*np.cos(y*.15)
        arr=np.array(color)[None,None,:]+(noise+grain)[:,:,None]
        row,col=divmod(i,4)
        result[sz*row:sz*(row+1),sz*col:sz*(col+1)] = np.clip(arr,0,255)
    Image.fromarray(result).save(folder/"palette.png")


class Mesh:
    def __init__(self):
        self.data = {"v":[], "n":[], "uv":[], "idx":[]}

    def face(self, points, mat, uv=None, normal=None):
        v = np.asarray(points, dtype=float)
        n = unit(np.cross(v[1]-v[0],v[2]-v[0])) if normal is None else unit(normal)
        if np.linalg.norm(n) < .02:
            return
        if uv is None:
            uv = [(0,0),(1,0),(1,1),(0,1)][:len(v)]
        row,col=divmod(TILES.index(mat),4)
        first=len(self.data["v"])//3
        for pt,(u,t) in zip(v,uv):
            self.data["v"].extend(np.round(pt,5).tolist())
            self.data["n"].extend(np.round(n,5).tolist())
            self.data["uv"].extend([round((col+.015+.97*u)/4,6),round((row+.015+.97*t)/4,6)])
        for j in range(1,len(v)-1):
            self.data["idx"].extend([first, first+j+1, first+j])

    def grid(self, mat, fn, nx=16, nz=18):
        for i in range(nx):
            for j in range(nz):
                uv = [(i/nx,j/nz),(i/nx,(j+1)/nz),((i+1)/nx,(j+1)/nz),((i+1)/nx,j/nz)]
                self.face([fn(u,t) for u,t in uv],mat,uv)

    def tube(self, mat, path, widths, sides=8):
        path=np.asarray(path,dtype=float)
        widths=np.broadcast_to(widths,len(path))
        rings=[]
        reference = np.array([0.,1.,0.])
        for i,pt in enumerate(path):
            axis=unit(path[min(i+1,len(path)-1)]-path[max(0,i-1)])
            if abs(float(reference @ axis))>.94:
                reference=np.array([1.,0.,0.])
            side=unit(np.cross(axis,reference))
            up=unit(np.cross(axis,side))
            rings.append([pt+widths[i]*(side*cos(TAU*j/sides)+up*sin(TAU*j/sides)) for j in range(sides)])
        for i in range(len(path)-1):
            for j in range(sides):
                k=(j+1)%sides
                self.face([rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j]],mat,
                          [(j/sides,i/(len(path)-1)),((j+1)/sides,i/(len(path)-1)),
                           ((j+1)/sides,(i+1)/(len(path)-1)),(j/sides,(i+1)/(len(path)-1))])
        for ring,pt,sgn in [(rings[0],path[0],-1),(rings[-1],path[-1],1)]:
            for j in range(sides):
                self.face([pt,ring[j],ring[(j+sgn)%sides]], "cut" if mat=="alder" else mat)

    def blob(self, mat, c, scale, rings=6, sides=13, noise=0., seed=7):
        rng=random.Random(seed)
        c=np.array(c)
        bands=[]
        for j in range(rings+1):
            lat=-pi/2+.002+(pi-.004)*j/rings
            bands.append([c+np.array(scale)*(1+rng.uniform(-noise,noise))*np.array([cos(lat)*cos(TAU*i/sides),sin(lat),cos(lat)*sin(TAU*i/sides)]) for i in range(sides)])
        for i in range(sides):
            k=(i+1)%sides
            for j in range(rings):
                self.face([bands[j][i],bands[j+1][i],bands[j+1][k],bands[j][k]],mat,
                          [(i/sides,j/rings),(i/sides,(j+1)/rings),((i+1)/sides,(j+1)/rings),((i+1)/sides,j/rings)])

    def rope(self, path, radius=.012):
        self.tube("rope",path,radius,6)

    def band(self, cx, cy, z, rad, count=3):
        pts=[(cx+rad*cos(i*TAU/14),cy+rad*sin(i*TAU/14),z+i*.012/14) for i in range(14*count+1)]
        self.rope(pts,.0065)


def shoe(m, c, yaw=0, tipped=False):
    """A small turnshoe with a leather sole, hollow ankle and tied thong."""
    c=np.array(c)
    def at(x,y,z):
        if tipped: y,z = .55*y-.835*z,.835*y+.55*z
        return c+np.array([x*cos(yaw)+z*sin(yaw),y,-x*sin(yaw)+z*cos(yaw)])
    rings=[]
    for y,w,front,back in [(.005,.062,-.127,.09),(.024,.066,-.13,.092),(.052,.061,-.119,.087),(.079,.048,-.07,.082),(.118,.043,-.001,.078)]:
        rings.append([at(w*cos(TAU*j/16),y,(front+back)/2+(back-front)*sin(TAU*j/16)/2) for j in range(16)])
    for i in range(4):
        for j in range(16):
            k=(j+1)%16
            m.face([rings[i][j],rings[i+1][j],rings[i+1][k],rings[i][k]],"boot",[(j/16,0),(j/16,1),((j+1)/16,1),((j+1)/16,0)])
    for j in range(16):
        m.face([at(0,.004,-.018),rings[0][j],rings[0][(j+1)%16]],"boot")
    for sign in (-1,1):
        m.rope([at(sign*.035,.083,-.032),at(-sign*.023,.092,-.012),at(sign*.032,.10,.004)],.0032)
        m.rope([at(0,.10,-.005),at(sign*.035,.12,-.014),at(sign*.026,.126,-.028),at(0,.10,-.005),at(sign*.045,.081,-.046)],.003)


def covered_boy(m):
    """The shawl follows head, shoulders, bent knees and the weight of a twelve-year-old."""
    knots=[0,.045,.135,.213,.255,.34,.46,.58,.72,.83,.94,1]
    widths=[.022,.091,.112,.088,.116,.172,.183,.159,.163,.144,.073,.043]
    heights=[.035,.144,.205,.105,.165,.235,.216,.135,.222,.174,.095,.055]
    def cloth(u,t):
        z=.39+1.28*t
        w=float(np.interp(t,knots,widths))
        h=float(np.interp(t,knots,heights))
        center=-.04+.073*sin(t*pi*1.5)+.036*sin(t*pi*2.9)
        a=(u*2-1)
        skirt=w+.028*(.4+.6*sin(pi*t))
        base=-.063
        fold=.013*sin(a*10+t*5)*sin(pi*u)*sin(pi*t)+.008*sin(a*24-t*12)*sin(pi*t)
        return (center+a*skirt,base+h*max(0,1-abs(a)**1.65)**.57+fold,z+.018*sin(a*3.5)*sin(pi*t))
    m.grid("shawl",cloth,20,40)
    # The wet shawl crosses the shoulders and folds once over the near knee.
    # Its yellow selvedge follows the weight instead of encircling the boy.
    def lap(u,t):
        root=.43+.26*sin(t*pi*1.15)-.21*t
        local=root+u*(.96-root)
        along=.17+.75*t+.06*u*(1-t)
        x,y,z=cloth(local,along)
        return x,y+.004+.009*(1-u)*sin(pi*t)+.002*sin(t*36+u*5),z
    m.grid("shawl",lap,11,35)
    def selvedge(u,t):
        x,y,z=lap(.020+.097*u,t)
        return x,y+.001,z
    m.grid("hem",selvedge,2,34)
    m.tube("shawl",[lap(0,t) for t in np.linspace(0,1,29)],.006,5)
    for lo,hi,material in [(.067,.094,"hem"),(.104,.115,"hem")]:
        def edge(u,t,lo=lo,hi=hi):
            x,y,z=cloth(lo+(hi-lo)*u,t)
            return x,y+.0009,z
        m.grid(material,edge,2,34)
    # Fold below the hem so silhouettes stay closed at road-camera height.
    for edge_u in (0,1):
        def under(u,t,eu=edge_u):
            x,y,z=cloth(eu,t)
            return x*(1-u*.12),y-.008*u,z
        m.grid("shawl",under,1,28)
    # Cover the top of the shod ankle where the shawl gives way at the foot.
    m.blob("linen",(.006,-.005,1.625),(.038,.056,.073),5,10)
    shoe(m,(.007,-.069,1.69),yaw=pi-.17)


def frame():
    m=Mesh()
    for sign in (-1,1):
        p=[(sign*(.255+.012*sin(t*TAU)),.012*sin(t*pi),-.08+t*2.34) for t in np.linspace(0,1,14)]
        m.tube("alder",p,[.029+.004*sin(t*pi) for t in np.linspace(0,1,14)],9)
        for z in (.32,.47,1.71,1.86):
            m.band(sign*(.255+.012*sin((z+.08)/2.34*TAU)),.011*sin(pi*z/2.26),z,.031,3)
    def cloak(u,t):
        a=2*u-1
        z=.24+1.64*t+.024*cos(u*7+.7)*(.8 if t<.04 or t>.95 else .25)
        sag=-.10*(1-a*a)
        y=.014+sag+(.007*cos(u*31+t*5)+.009*cos(t*25-u*4))*sin(pi*u)
        return (.268*a,y,z)
    m.grid("cloak",cloak,20,24)
    for sign in (-1,1):
        def over(u,t,sgn=sign):
            a=u*pi*1.30
            return sgn*(.254+.032*sin(a)),.005+.032*cos(a),.24+1.64*t+.012*sin(t*13)
        m.grid("cloak",over,5,22)
    return m


def lift_cloth():
    """Doubled corners of a short underfold give Mira a whole-hand purchase."""
    m=Mesh()
    m.grid("cloak",lambda u,t:((u-.5)*.38,-.056+.014*cos(u*TAU),.36+t*.39),8,8)
    for side in (-1,1):
        points=[(side*.15,-.046,.68),(side*.17,.085,.54),
                (side*.15,.248,.40),(side*.132,.303,.35),
                (side*.128,.320,.29),(side*.129,.296,.238),
                (side*.144,.166,.30),(side*.155,.067,.36),
                (side*.155,-.052,.42)]
        def fold(u,t):
            at = t*(len(points)-1)
            idx=min(len(points)-2,int(at))
            point=np.array(points[idx])+(at-idx)*(np.array(points[idx+1])-points[idx])
            width=.041+.012*abs(t-.5)*2
            point[0] += (u-.5)*width
            point[1] += .004*sin(pi*u)
            return point
        m.grid("cloak",fold,4,24)
        m.tube("cloak",[fold(.04,t) for t in np.linspace(0,1,28)],.003,5)
    return m


def bank():
    m=Mesh()
    rng=random.Random(714)
    m.blob("granite",(-.57,.35,-.30),(.39,.61,.32),7,11,.09)
    for i in range(18):
        t=rng.uniform(.1,pi)
        h=rng.uniform(.42,.88)
        x=-.57+.29*cos(t); z=-.30+.26*sin(t)
        m.blob("lichen",(x,h,z),(.044,.016,.036),3,6,.13)
    # The low hollow is open on its front side so the shawl remains identifiable.
    x,z=1.61,-2.90
    trunk=[(x-.12,-.1,z+.12),(x,.18,z),(x+.08,.59,z+.03),(x+.24,.97,z-.04),
           (x+.31,1.33,z-.12),(x+.22,1.65,z-.31),(x+.25,1.90,z-.50)]
    m.tube("bark",trunk,[.24,.245,.19,.163,.127,.077,.022],12)
    for j,(dx,dz) in enumerate([(-.88,.48),(-.63,-.4),(.48,.38),(.3,-.75),(-.33,.96)]):
        m.tube("bark",[(x+.07,.54,z),(x+.21*dx,.23,z+.2*dz),(x+.53*dx,.11,z+.60*dz),(x+dx,-.02,z+dz)], [.12,.14,.084,.025],8)
    bough=[trunk[3],(x-.14,1.16,z+.10),(x-.55,1.11,z+.19),(x-.90,.99,z+.23),(x-1.14,1.10,z+.28)]
    m.tube("bark",bough,[.098,.079,.059,.035,.011],9)
    shoe(m,(x-.69,.94,z+.20),yaw=-.55,tipped=True)
    m.rope([(x-.65,1.055,z+.24),(x-.70,1.099,z+.21),(x-.74,1.08,z+.18)],.004)
    for j in range(22):
        b=np.array(bough[rng.randrange(1,5)]) if j<12 else np.array(trunk[rng.randrange(4,7)])
        direction=rng.uniform(0,TAU)
        ps=[b,b+(.20*cos(direction),.077,.18*sin(direction)),
            b+(.35*cos(direction),-.22-rng.random()*.14,.29*sin(direction)),
            b+(.42*cos(direction),-.46-rng.random()*.17,.38*sin(direction))]
        m.tube("bark",ps,[.009,.006,.004,.0017],4)
        for k in range(3,9):
            t=k/9
            pos=(1-t)*np.array(ps[1])+t*np.array(ps[3])
            sg=(-1)**k
            tip=pos+np.array([.075*sg,-.102,.018*cos(direction)])
            rib=(pos+tip)/2+np.array([0,.011,.012])
            m.face([pos,rib+(.013,.002,-.011),tip,rib+(-.014,0,.01)],"leaf")
    for i in range(27):
        cx=x+rng.uniform(-.28,.72);cz=z+rng.uniform(-.57,.11);h=rng.uniform(.32,.89)
        m.tube("reed",[(cx,-.02,cz),(cx+.018,h*.70,cz),(cx+.072,h,cz+.018)],[.011,.007,.003],5)
        if i%3==0:m.blob("bark",(cx+.064,h*.94,cz+.013),(.015,.065,.012),4,7,.05)
    return m


def safety(tied):
    m=Mesh()
    cx,cz=-.57,-.30
    if tied:
        pts=[(cx+.34*cos(t),.31+.018*t,cz+.29*sin(t)) for t in np.linspace(0,pi*2.50,44)]
        pts.extend([(-.19,.35,-.18),(.23,.26,-.40),(.61,.19,-.73),(.91,.11,-1.05),(1.18,.03,-1.46)])
        m.rope(pts,.014)
        m.rope([pts[0],(-.18,.30,-.35),(-.18,.34,-.39),(-.22,.25,-.46),(-.18,.08,-.48)],.013)
    else:
        pts=[(-.29+.19*cos(t),.026+.001*t,.35+.137*sin(t)) for t in np.linspace(0,TAU*2.55,56)]
        pts.extend([(-.49,.033,.43),(-.60,.02,.41),(-.67,.023,.48)])
        m.rope(pts,.014)
    return m


def rests(porch):
    m=Mesh()
    for z in (-.49,.70):
        if porch:
            for x in (-.46,.46):
                m.tube("alder",[(x,.015,z),(x*.87,.23,z)],[.037,.04],8)
            m.tube("alder",[(-.52,.22,z),(.52,.22,z)],.039,9)
        else:
            m.tube("bark",[(-.48,.11,z),(.02,.107,z+.025),(.50,.111,z+.009)],[.115,.119,.108],12)
    if not porch:
        m.grid("linen",lambda u,t:(.65+u*.43,.019+.014*cos(u*13+t*11),.20+t*.38),7,7)
        for x,z in ((.79,.30),(.94,.43)):
            m.blob("lichen",(x,.072,z),(.041,.061,.04),5,10,.04)
            m.tube("bark",[(x,.125,z),(x+.009,.15,z)],.004,5)
        m.blob("cut",(.97,.07,.27),(.088,.052,.048),4,10,.12)
    return m


def graves():
    m=Mesh()
    # The existing aftermath owns the flowers once the spellings are checked.
    for j,(x,z) in enumerate([(-1.05,-.61),(-.16,-.71),(.66,-.65)]):
        length=(.83,.84,.65)[j]
        m.blob("soil",(x,.016,z),(.33,.105,length),6,13,.07,7+j)
        m.blob("granite",(x,.25,z-length+.04),(.19,.28,.07),5,10,.09,24+j)
    def coat(u,t):
        a=u*2-1
        return .67+a*(.096+.045*t),.14+.053*(1-a*a)+.014*sin(a*6+t*8),-.15+t*.44
    m.grid("coat",coat,9,12)
    for i in range(3):
        m.blob("brass",(.68,.188,-.09+i*.09),(.009 if i<2 else .014,.004,.009 if i<2 else .014),3,8)
    return m


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output",type=Path,default=Path(__file__).resolve().parents[3]/"outputs/AshenOathTheRoadBetweenCrowns/assets/narrative_props/field")
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    parts={"bank":bank(),"loose":safety(False),"rigged":safety(True),"frame":frame(),"rest":rests(False),"porch":rests(True),"graves":graves(),"lift_cloth":lift_cloth()}
    shawl=Mesh()
    covered_boy(shawl)
    parts["oren"]=shawl
    with tempfile.TemporaryDirectory() as tmp:
        q=Path(tmp)
        (q/"project.godot").write_text('config_version=5\n[application]\nconfig/name="Willow art bake"\n')
        atlas(q)
        for name,mesh in parts.items():
            (q/(name+".json")).write_text(json.dumps(mesh.data,separators=(",",":")))
        subprocess.run([args.godot,"--headless","--path",str(q),"--script",str(Path(__file__).with_name("willow_bake.gd")),"--",str(q),str(args.output.resolve())],check=True)


if __name__=="__main__":
    main()
