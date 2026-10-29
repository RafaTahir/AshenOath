"""Anatomy-specific Blender authoring for the non-humanoid pack designs."""
import math
from mathutils import Vector
from creature_workshop import Creature, TAU


def curved(points,steps=18):
    result=[]
    for i in range(steps+1):
        t=i/steps
        work=[Vector(p) for p in points]
        while len(work)>1:
            work=[work[j].lerp(work[j+1],t) for j in range(len(work)-1)]
        result.append(work[0])
    return result


def leaf(c,name,root,tip,width,mat,bone,curve=.04):
    root,tip=Vector(root),Vector(tip)
    direction=(tip-root).normalized()
    side=direction.cross(Vector((0,0,1)))
    if side.length<.1: side=Vector((1,0,0))
    side.normalize()
    verts,faces,uv=[],[],[]
    for i in range(13):
        t=i/12
        center=root.lerp(tip,t)
        for j in range(9):
            u=j/8*2-1
            p=center+side*(width*math.sin(math.pi*t)*u)
            p.z+=curve*math.sin(math.pi*t)*(1-u*u)
            verts.append(tuple(p));uv.append((j/8,t))
            if i and j:
                k=i*9+j;faces.append((k-10,k-9,k,k-1))
    # Both faces are authored, avoiding reliance on disabled backface culling.
    faces+= [tuple(reversed(f)) for f in faces.copy()]
    return c.mesh(name,verts,faces,mat,uv,bone)


def antler(c,side,base):
    base=Vector(base)
    points=curved([base,base+Vector((side*.30,.08,.40)),base+Vector((side*.72,.40,.60)),
                   base+Vector((side*.83,.35,1.00))],24)
    c.tube("AntlerBeam",points,[.055*(1-i/27) for i in range(25)],1,"Head",sides=12,rough=.07)
    for i in (5,9,13,17,20):
        start=points[i]
        tip=start+Vector((side*(.12 if i<13 else -.04),-.28 if i%2 else .10,.45-.008*i))
        tine=curved([start,start+Vector((side*.08,0,.16)),tip],10)
        c.tube("AntlerTine",tine,[.030*(1-j/10)+.001 for j in range(11)],1,"Head",sides=9,rough=.05)


def hart():
    c=Creature("M08","White_Hart_Avatar","cervid_quadruped",
               ["D9D6C5","A39472","7E7862","252923","7B8174","B5B3A4","E2DFD0","787668"],3.6)
    c.bone("Pelvis",(0,.65,1.45),(0,.30,1.55),radius=.4)
    c.bone("Body",(0,.30,1.55),(0,-.53,1.65),"Pelvis",.4)
    c.bone("Neck",(0,-.52,1.65),(0,-.91,2.33),"Body",.24)
    c.bone("Head",(0,-.91,2.33),(0,-1.40,2.24),"Neck",.19)
    c.bone("Jaw",(0,-1.02,2.25),(0,-1.40,2.20),"Head",.12)
    c.ellipsoid("DeepChest",(0,-.34,1.55),(.31,.55,.41),0,None,True)
    c.ellipsoid("Barrel",(0,.18,1.52),(.32,.72,.32),0,None,True)
    c.ellipsoid("Haunch",(0,.69,1.49),(.32,.34,.36),0,None,True)
    c.tube("Neck",[(0,-.44,1.60),(0,-.68,1.92),(0,-.88,2.22),(0,-.96,2.37)],
           [(.28,.29),(.22,.25),(.16,.18),(.14,.15)],0,None,True,sides=28)
    c.ellipsoid("DeerCranium",(0,-1.0,2.32),(.16,.23,.19),0,"Head",True)
    c.tube("LongMuzzle",[(0,-1.08,2.31),(0,-1.34,2.23),(0,-1.49,2.22)],
           [(.13,.14),(.10,.10),(.085,.075)],0,"Head",True,sides=20)
    c.ellipsoid("Nose",(0,-1.50,2.23),(.09,.055,.065),3,"Head",rough=.02)
    c.ellipsoid("Underjaw",(0,-1.24,2.18),(.09,.22,.06),6,"Jaw",rough=.01)
    for side in (-1,1):
        c.eye((side*.135,-1.13,2.36),.034,"Head",3,axis=(side*.5,-.8,0))
        leaf(c,"Ear",(side*.12,-.91,2.43),(side*.43,-.81,2.66),.095,0,"Head",.045)
        leaf(c,"InnerEar",(side*.13,-.927,2.435),(side*.405,-.827,2.63),.067,5,"Head",.045)
        antler(c,side,(side*.11,-.87,2.49))
        for front in (True,False):
            if front:
                points=[(side*.27,-.44,1.52),(side*.26,-.43,.91),(side*.24,-.48,.24),(side*.24,-.54,.10)]
                radii=[.14,.072,.036,.055]
            else:
                points=[(side*.28,.65,1.48),(side*.27,.43,.95),(side*.27,.80,.53),(side*.25,.69,.10)]
                radii=[.20,.10,.052,.043]
            chain=c.limb(("Fore" if front else "Hind")+str(side),points,radii,
                         "Body" if front else "Pelvis",phase=(0 if side==1 else math.pi)+(math.pi if front else 0))
            foot=Vector(points[-1])
            for half in (-1,1):
                c.ellipsoid("ClovenHoof",foot+Vector((half*.032,-.025,-.04)),(.030,.095,.061),3,chain[-1],rings=8,sides=12,rough=.02)
    tail=[(0,.95,1.53),(0,1.10,1.35),(0,1.13,1.20)]
    c.limb("Tail",tail,[.075,.06,.018],"Pelvis",mat=0,core=False,kind="tail")
    for i in range(23):
        a=TAU*i/23
        c.crest("NeckRuff",(.19*math.sin(a),-.64+.20*math.cos(a),1.87),.17,.025,.012,"Neck",6,(0,.1,-1))
    return c


def ashwing():
    c=Creature("M07","Ashwing_Carrion_Drake","wyvern_two_wing_two_leg",
               ["57534B","9B8E70","A18D43","242521","494D47","463F37","87725D","5B4838"],4.8)
    c.bone("Pelvis",(0,.45,1.75),(0,.1,2.1),radius=.52)
    c.bone("Body",(0,.1,2.1),(0,-.44,2.8),"Pelvis",.65)
    c.bone("Neck",(0,-.44,2.8),(0,-.77,3.90),"Body",.28)
    c.bone("Head",(0,-.77,3.9),(0,-1.40,3.91),"Neck",.27)
    c.bone("Jaw",(0,-.82,3.76),(0,-1.39,3.75),"Head",.2)
    c.ellipsoid("KeelChest",(0,-.18,2.39),(.61,.68,.84),0,None,True)
    c.ellipsoid("Pelvis",(0,.48,1.78),(.52,.55,.5),0,None,True)
    c.tube("WatchfulNeck",[(0,-.38,2.65),(0,-.59,3.15),(0,-.72,3.65),(0,-.86,3.95)],
           [.36,.27,.23,.25],0,None,True,sides=28)
    c.ellipsoid("Cranium",(0,-.95,3.99),(.27,.37,.24),0,"Head",True)
    c.ellipsoid("ThroatPouch",(0,-.84,3.47),(.22,.20,.38),6,"Neck",rough=.03)
    c.tube("HookedBeak",[(0,-1.12,3.96),(0,-1.43,3.93),(0,-1.51,3.66)],
           [(.22,.14),(.14,.13),(.005,.005)],3,"Head",sides=16)
    c.ellipsoid("LowerBeak",(0,-1.15,3.76),(.18,.29,.075),1,"Jaw")
    tail=[(0,.73,1.83),(0,1.45,1.18),(0,2.28,.62),(0,3.08,.22),(0,3.60,.12)]
    c.limb("Tail",tail,[.37,.29,.19,.10,.005],"Pelvis",kind="tail")
    for side in (-1,1):
        c.eye((side*.235,-1.05,4.05),.061,"Head",2,(side*.5,-.8,0))
        leg=[(side*.43,.45,1.76),(side*.65,-.04,1.17),(side*.69,.43,.53),(side*.65,-.01,.16)]
        bones=c.limb("HindLeg"+str(side),leg,[.27,.19,.105,.085],"Pelvis",phase=0 if side==1 else math.pi)
        for toe in range(3):
            a=Vector(leg[-1])+Vector(((toe-1)*.11,-.04,0))
            end=a+Vector(((toe-1)*.08,-.40,-.04))
            c.tube("TalonedToe",[a,a.lerp(end,.55),end],[.055,.040,.022],0,bones[-1],sides=10)
            c.fang("Talon",end,end+Vector((0,-.13,-.06)),.035,3,bones[-1])
        wing=[(side*.47,-.22,2.78),(side*1.15,-.45,3.03),(side*2.14,-.60,3.52)]
        bones=c.limb("Wing"+str(side),wing,[.22,.14,.09],"Body",phase=0 if side==1 else math.pi,kind="wing")
        wrist=Vector(wing[-1])
        tips=[Vector((side*4.25,.15,3.68)),Vector((side*3.96,.98,2.95)),
              Vector((side*3.32,1.61,2.14)),Vector((side*2.27,1.88,1.62)),Vector((side*.70,.89,1.72))]
        fan=[wrist]+tips
        for j,tip in enumerate(tips[:-1]):
            bone=c.bone("WingFinger"+str(side)+"_"+str(j),wrist,tip,bones[-1],.07)
            points=curved([wrist,wrist.lerp(tip,.5)+Vector((0,-.07,.12)),tip],12)
            c.tube("WingFinger",points,[.065*(1-i/15) for i in range(13)],0,bone,sides=10)
        for j in range(len(tips)-1):
            verts,faces,uv=[],[],[]
            for row in range(17):
                t=row/16
                for col in range(13):
                    u=col/12
                    edge=tips[j].lerp(tips[j+1],u)
                    edge+=(wrist-edge)*(.17*math.sin(math.pi*u))
                    p=wrist.lerp(edge,t)
                    p.z-=.16*math.sin(math.pi*t)*math.sin(math.pi*u)
                    verts.append(tuple(p));uv.append((u,t))
                    if row and col:
                        k=row*13+col;faces.append((k-14,k-13,k,k-1))
            faces += [tuple(reversed(f)) for f in faces.copy()]
            c.mesh("LoadBearingWingMembrane",verts,faces,6,uv,bones[-1])
        c.fang("WingThumb",wrist,wrist+Vector((side*.12,-.08,.28)),.07,3,bones[-1])
    for row in range(15):
        z=2.02+row*.13
        for side in (-1,1):
            c.crest("NeckScale",(side*.16,-.22,z),.23,.07,.04,"Neck" if z>2.8 else "Body",0,(side*.3,.3,-1))
    for row in range(9):
        y=.55+row*.31
        z=1.9-row*.19
        c.crest("TailKeel",(0,y,z),.28,.12,.07,"Tail_"+str(min(3,row//3)),0,(0,1,.1))
    return c


def segmented(asset_id):
    leech=asset_id=="M12"
    name="Knell_Leech" if leech else "Silt_Maw"
    length=1.8 if leech else 3.2
    c=Creature(asset_id,name,"annelid_two_suckers" if leech else "limbless_burrower",
               ["554B43","B3A17F","817756","1D1B1A","48483B","6E6354","877360","4B4236"],length)
    c.bone("Body",(0,0,.22),(0,-.42,.22),radius=.25)
    c.bone("Head",(0,-length*.32,.24),(0,-length*.50,.26),"Body",.25)
    c.bone("Jaw",(0,-length*.42,.18),(0,-length*.53,.16),"Head",.15)
    bones=[]
    for i in range(6):
        a=(0,-length*.28+length*.13*i,.23)
        b=(0,-length*.15+length*.13*i,.23)
        bones.append(c.bone("Segment"+str(i),a,b,"Body" if not i else bones[-1],.24))
    c.limbs.append(dict(bones=bones,phase=0,kind="tail"))
    points=[];radii=[]
    for i in range(97):
        t=i/96
        x=.08*math.sin(t*TAU)*t
        points.append((x,-length*.40+length*.89*t,.22))
        width=(.28 if leech else .35)*(math.sin(math.pi*(.12+.84*t))**.55)
        width*=1+.048*math.sin(t*TAU*32)
        radii.append((width,width*(.70 if leech else .77)))
    c.tube("AnnulatedBody",points,radii,0,None,False,sides=36,rough=.017)
    if leech:
        for front in (True,False):
            y=-length*.43 if front else length*.49
            rad=.245 if front else .14
            verts,faces,uv=[],[],[]
            for row in range(10):
                t=row/9
                r=rad*(.20+.80*math.sin(t*math.pi/2))
                for j in range(41):
                    a=TAU*j/40
                    verts.append((r*math.cos(a),y+(.08*(1-t) if front else -.06*(1-t)),.24+r*.72*math.sin(a)))
                    uv.append((j/40,t))
                    if row and j:
                        k=row*41+j;faces.append((k-42,k-41,k,k-1))
            c.mesh("AnteriorSucker" if front else "PosteriorSucker",verts,faces,6,uv,"Head" if front else bones[-1])
            if front:
                c.ellipsoid("MouthDepth",(0,y+.055,.24),(.12,.025,.09),3,"Head")
                for row in range(3):
                    for j in range(22):
                        a=TAU*(j+row*.4)/22
                        radius=.10+row*.04
                        start=Vector((radius*math.cos(a),y+.025,.24+radius*.72*math.sin(a)))
                        end=Vector((radius*.72*math.cos(a),y+.04,.24+radius*.52*math.sin(a)))
                        c.fang("RadialTooth",start,end,.012,1,"Head")
    else:
        c.ellipsoid("ShovelHead",(0,-length*.39,.27),(.33,.30,.23),0,"Head")
        c.ellipsoid("JawPlate",(0,-length*.44,.16),(.30,.22,.105),1,"Jaw")
        for side in (-1,1):
            c.eye((side*.25,-length*.43,.39),.035,"Head",2,(side*.7,-.7,0))
            c.tube("NostrilFold",[(side*.06,-length*.47,.37),(side*.085,-length*.50,.28)], [.03,.045],0,"Head")
            c.ellipsoid("Nostril",(side*.07,-length*.49,.37),(.018,.025,.020),3,"Head")
        c.tube("MouthLine",[(-.26,-length*.46,.23),(0,-length*.51,.21),(.26,-length*.46,.23)], [.009]*3,3,"Jaw")
    return c


def arthropod(asset_id):
    spider=asset_id=="M14"; crab=asset_id=="M10"
    name="Gallows_Weaver" if spider else "Millback" if crab else "Inkblind"
    span=2.6 if spider else 2.4 if crab else 1.2
    c=Creature(asset_id,name,"arachnid_eight_leg" if spider else "crustacean_six_leg_two_claw" if crab else "insect_six_leg",
               ["5B5245","B29E7A","827550","1C1D1B","4B5050" if crab else "454137","5E5844","8C8167","3E3932"],span)
    scale=1 if spider or crab else .55
    c.bone("Body",(0,.10,.55*scale),(0,-.32,.55*scale),radius=.4*scale)
    c.bone("Head",(0,-.32,.55*scale),(0,-.61,.48*scale),"Body",.23*scale)
    c.bone("Jaw",(0,-.55,.43*scale),(0,-.73,.35*scale),"Head",.13*scale)
    c.ellipsoid("Abdomen",(0,.36*scale,.61*scale),(.40*scale,.62*scale,.43*scale),0,"Body",rough=.05)
    c.ellipsoid("Cephalothorax",(0,-.29*scale,.49*scale),(.31*scale,.39*scale,.24*scale),0,"Head",rough=.035)
    pairs=4 if spider else 3
    for side in (-1,1):
        for i in range(pairs):
            y=(-.37+i*.22)*scale
            reach=(1.2 if spider else 1.0)*scale
            sweep=(-.80+i*.52)*scale
            points=[(side*.23*scale,y,.53*scale),(side*.60*scale,y+sweep*.45,(.90 if spider else .60)*scale),
                    (side*reach,y+sweep,.10*scale)]
            width=(.045 if spider else .082)*scale
            bones=c.limb("Leg"+str(side)+"_"+str(i),points,[width,width*.75,width*.32],"Body",core=False,
                         phase=(i%2)*math.pi+(0 if side==1 else math.pi))
            for j,p in enumerate(points[:-1]):
                c.ellipsoid("ArticulatedJoint",p,(width*1.2,)*3,4,bones[j],rings=8,sides=12)
            if not spider:
                c.crest("PaddleFoot",Vector(points[-1])+Vector((0,0,.04*scale)),.17*scale,.075*scale,.025*scale,
                        bones[-1],4,(side*.2,-.2,-1))
            if spider:
                for j in range(9):
                    p=Vector(points[0]).lerp(Vector(points[1]),j/8)
                    c.fang("LegBristle",p,p+Vector((side*.06,.015,.025)),.004,5,bones[0])
        if crab:
            points=[(side*.24,-.36,.47),(side*.57,-.74,.41),(side*.48,-1.03,.34)]
            bones=c.limb("ClawArm"+str(side),points,[.13,.12,.10],"Head",core=False,kind="claw")
            c.ellipsoid("PincerPalm",(side*.49,-1.09,.34),(.18,.24,.16),4,bones[-1],rough=.03)
            for branch in (-1,1):
                start=(side*.49+branch*.10,-1.21,.34)
                c.tube("Pincer",[start,(side*.49+branch*.12,-1.38,.34),(side*.49+branch*.025,-1.51,.34)],
                       [.075,.056,.008],4,bones[-1],sides=12)
            stem=[(side*.18,-.52,.61),(side*.22,-.65,.74)]
            c.tube("EyeStalk",stem,[.035,.045],0,"Head")
            c.eye(stem[-1],.055,"Head",2)
        elif spider:
            c.tube("Chelicera",[(side*.13,-.60,.45),(side*.15,-.73,.32),(side*.06,-.77,.21)],
                   [.08,.05,.005],3,"Jaw",sides=14)
            for row in range(2):
                for j in range(2):
                    c.eye((side*(.055+j*.075),-.59+row*.035,.52+row*.10),.035 if row else .046,"Head",3)
            c.tube("Spinneret",[(side*.10,.85,.51),(side*.09,1.02,.46)],[.038,.021],0,"Body",sides=12)
        else:
            points=curved([(side*.08,-.29,.22),(side*.16,-.49,.23),(side*.30,-.77,.12)],20)
            c.tube("SegmentedAntenna",points,[.017*(1-j/24) for j in range(21)],4,"Head",sides=8)
            for j in range(28):
                x=side*(.08+.04*math.sin(j*2.4))
                start=Vector((x,-.31,.15+j*.001))
                c.tube("BrushPalp",[start,start+Vector((side*.025,-.11,-.025))],[.003,.0007],1,"Jaw",sides=4)
    if crab:
        c.ellipsoid("RidgedCarapace",(0,.06,.69),(.64,.71,.28),4,"Body",rough=.04,rings=18,sides=40)
        for i in range(11):
            y=-.47+i*.10
            c.tube("ShellGrowthRidge",[(-.45,y,.80),(0,y,.96),(.45,y,.80)],[.014]*3,1,"Body",sides=7)
    elif not spider:
        for i in range(6):
            c.ellipsoid("OverlappingElytron",(0,(.40-i*.17)*scale,.70*scale),(.42*scale,.20*scale,.16*scale),
                        4,"Body",rough=.045,rings=10,sides=24)
    else:
        for i in range(29):
            a=TAU*i/29
            c.crest("AbdomenSetae",(.37*math.sin(a),.36+.48*math.cos(a),.80),.12,.018,.008,"Body",5,(0,.2,.4))
    return c


def glassmoth():
    c=Creature("M11","Glassmoth","four_wing_six_leg_moth",
               ["6D6658","C3BAA0","8A805B","292823","51483C","A59D86","B3A78A","665640"],2.1)
    c.bone("Body",(0,.13,.49),(0,-.16,.58),radius=.16)
    c.bone("Head",(0,-.17,.59),(0,-.32,.61),"Body",.13)
    c.bone("Jaw",(0,-.28,.53),(0,-.35,.48),"Head",.06)
    c.ellipsoid("Thorax",(0,0,.55),(.17,.23,.20),0,"Body",rough=.06)
    c.ellipsoid("ScaledAbdomen",(0,.31,.40),(.15,.35,.15),1,"Body",rough=.07)
    c.ellipsoid("Head",(0,-.24,.61),(.13,.11,.12),0,"Head",rough=.03)
    for side in (-1,1):
        c.eye((side*.09,-.30,.65),.068,"Head",3,(side*.4,-1,0))
        antenna=curved([(side*.06,-.22,.71),(side*.16,-.35,.88),(side*.40,-.38,.88)],20)
        c.tube("AntennaSpine",antenna,[.008]*21,4,"Head",sides=6)
        for i in range(2,19):
            base=antenna[i]
            reach=.065*math.sin(math.pi*i/20)
            for sign in (-1,1):
                c.tube("AntennaComb",[base,base+Vector((side*.015,sign*reach,.01))],[.003,.001],1,"Head",sides=4)
        for i in range(3):
            points=[(side*.11,-.13+i*.12,.50),(side*.27,-.22+i*.12,.25),(side*.31,-.27+i*.12,.035)]
            c.limb("Leg"+str(side)+"_"+str(i),points,[.019,.014,.004],"Body",core=False,phase=math.pi*(i%2)+(0 if side==1 else math.pi))
        for rear in (False,True):
            root=Vector((side*.12,.10 if rear else -.04,.59))
            tip=Vector((side*(.86 if rear else 1.06),.63 if rear else -.49,.79 if rear else 1.19))
            name=("HindWing" if rear else "ForeWing")+str(side)
            bone=c.bone(name,root,tip,"Body",.13)
            c.limbs.append(dict(bones=[bone],phase=0 if side==1 else math.pi,kind="wing"))
            wing_width=.27 if rear else .31
            leaf(c,name,root,tip,wing_width,6,bone,.065)["thin_membrane"]=True
            direction=tip-root
            lateral=direction.cross(Vector((0,0,1))).normalized()
            c.tube("WingLeadingVein",curved([root,root.lerp(tip,.5)+lateral*wing_width,tip],22),[.006]*23,4,bone,sides=6)
            c.tube("WingTrailingVein",curved([root,root.lerp(tip,.5)-lateral*wing_width,tip],22),[.005]*23,4,bone,sides=6)
            for i in range(1,7):
                t=i/8
                center=root.lerp(tip,t)+Vector((0,0,.058*math.sin(math.pi*t)))
                for sign in (-1,1):
                    end=center+lateral*(wing_width*math.sin(math.pi*t)*sign)
                    c.tube("WingBranchVein",curved([root,center,end],12),[.003]*13,4,bone,sides=5)
    coil=[]
    for i in range(40):
        a=TAU*1.7*i/39;r=.035*(1-i/45)
        coil.append((r*math.cos(a),-.355,.50+r*math.sin(a)))
    c.tube("FeedingCoil",coil,[.006]*40,4,"Jaw",sides=6)
    for i in range(60):
        a=TAU*i/23
        c.crest("ThoraxFur",(.16*math.sin(a),.15*math.cos(a),.53+(i%5)*.025),.07,.012,.006,"Body",5,(0,.4,.2))
    return c


def ground_quadruped(asset_id):
    frog=asset_id=="M15"
    c=Creature(asset_id,"Reed_Choir" if frog else "Hearthscale","amphibian_four_limb" if frog else "reptile_four_limb",
               ["7A7650" if frog else "987348","C1AF80","AD8C3F","2B2B20","4F5148","656A42","BA9C59","514B35"],1.5 if frog else 2.7)
    c.bone("Body",(0,.19,.44),(0,-.30,.48),radius=.4)
    c.bone("Head",(0,-.30,.48),(0,-.67,.48),"Body",.26)
    c.bone("Jaw",(0,-.39,.32),(0,-.73,.31),"Head",.24)
    c.ellipsoid("Body",(0,.13,.40),(.50 if frog else .40,.56,.34),0,None,True)
    c.ellipsoid("BroadSkull",(0,-.43,.48),(.41 if frog else .29,.35,.23),0,"Head",True)
    c.ellipsoid("Throat",(0,-.39,.28),(.37 if frog else .25,.28,.22),1,"Jaw")
    for side in (-1,1):
        c.eye((side*(.31 if frog else .23),-.51,.64),.082 if frog else .049,"Head",2,(side*.4,-1,.1))
        c.ellipsoid("Nostril",(side*.17,-.72,.53),(.025,.011,.016),3,"Head")
        for rear in (False,True):
            if rear and frog:
                points=[(side*.35,.37,.40),(side*.67,.12,.34),(side*.49,.60,.15),(side*.63,.45,.04)]
                radii=[.23,.19,.085,.045]
            else:
                y=.45 if rear else -.31
                points=[(side*.30,y,.43),(side*.53,y+.14,.26),(side*.55,y-.07,.045)]
                radii=[.14,.105,.055]
            bones=c.limb(("Hind" if rear else "Fore")+str(side),points,radii,"Body",phase=(0 if side==1 else math.pi)+(math.pi if rear else 0))
            for j in range(4):
                start=Vector(points[-1])+Vector(((j-1.5)*.045,-.01,0))
                end=start+Vector(((j-1.5)*.035,-.13,-.012))
                c.tube("SplayedToe",[start,start.lerp(end,.55),end],[.024,.016,.008],0,bones[-1],sides=8)
                if not frog: c.fang("ToeClaw",end,end+Vector((0,-.045,-.01)),.012,1,bones[-1])
    c.tube("MouthCrease",[(-.30,-.65,.37),(0,-.76,.35),(.30,-.65,.37)],[.008]*3,3,"Jaw",sides=7)
    if frog:
        for i,x in enumerate((-.27,0,.27)):
            bone=c.bone("AirSac"+str(i),(x,.21,.64),(x,.21,1.0 if i==1 else .89),"Body",.13)
            c.ellipsoid("DorsalResonator",(x,.23,.79 if i!=1 else .86),(.17,.18,.27 if i==1 else .21),6,bone,rough=.025)
            for j in range(7):
                a=TAU*j/7
                c.tube("SacVein",curved([(x+.14*math.sin(a),.23+.14*math.cos(a),.66),
                                         (x+.16*math.sin(a),.23+.16*math.cos(a),.90),
                                         (x,.23,1.12 if i==1 else 1.0)],12),[.003]*13,1,bone,sides=5)
    else:
        tail=[(0,.57,.43),(0,1.07,.30),(0,1.56,.15),(0,1.95,.05)]
        c.limb("Tail",tail,[.25,.17,.08,.005],"Body",kind="tail")
        for row in range(12):
            y=-.60+row*.12
            for col in range(7):
                a=(col-3)*.25
                c.crest("OverlappingMineralScale",(.38*math.sin(a),y,.63+.14*math.cos(a)),.20,.085,.025,
                        "Head" if row<3 else "Body",4,(0,1,-.18))
        for row in range(8):
            c.crest("TailScale",(0,.72+row*.15,.53-row*.05),.22,.10-row*.009,.03,
                    "Tail_"+str(min(2,row//3)),4,(0,1,-.1))
    return c


def cairn_mother():
    c=Creature("M17","Cairn_Mother","gastropod_muscular_foot",
               ["666453","B5A47E","827B54","292D27","8C856D","62694A","A69D7E","514C3D"],3.5)
    c.bone("Body",(0,.12,.35),(0,-.75,.44),radius=.55)
    c.bone("Head",(0,-.75,.44),(0,-1.20,.56),"Body",.31)
    c.bone("Jaw",(0,-1.10,.36),(0,-1.37,.35),"Head",.17)
    c.ellipsoid("MuscularFoot",(0,.10,.22),(.61,1.64,.24),0,"Body",rough=.035)
    c.tube("HeadMantle",[(0,-.30,.35),(0,-.86,.42),(0,-1.26,.56)],
           [(.50,.35),(.41,.33),(.34,.30)],0,None,True,sides=32)
    c.ellipsoid("MantleCollar",(0,.20,.67),(.73,.96,.43),0,"Body",rough=.05)
    # A genuine expanding spiral shell, not a collection of floating rocks.
    points=[];radii=[]
    for i in range(121):
        t=i/120
        a=TAU*2.15*t
        r=.055+.66*t
        points.append((.09*math.sin(a*.4),.28+r*math.cos(a),1.02+r*math.sin(a)))
        radii.append((.075+.48*t,.065+.33*t))
    c.tube("SpiralShell",points,radii,4,"Body",sides=28,rough=.055)
    for i in range(48):
        a=TAU*i/19
        z=.75+(i%6)*.18
        x=.57*math.sin(a)
        y=.28+.67*math.cos(a)
        c.crest("MineralAccretion",(x,y,z),.26,.16,.035,"Body",1,(.2*math.sin(a),.2*math.cos(a),-.6))
    for side in (-1,1):
        for eye in (True,False):
            root=(side*.20,-1.13,.68 if eye else .42)
            tip=(side*(.46 if eye else .43),-1.36,.99 if eye else .36)
            bone=c.bone(("EyeStalk" if eye else "Feeler")+str(side),root,tip,"Head",.07)
            c.tube("RetractileStalk",curved([root,Vector(root).lerp(Vector(tip),.5)+Vector((0,0,.04)),tip],14),
                   [.065*(1-i/21) for i in range(15)],0,bone,sides=12)
            if eye: c.ellipsoid("StalkEye",tip,(.029,.034,.028),3,bone,rough=0)
    c.ellipsoid("MouthLip",(0,-1.43,.38),(.18,.08,.067),1,"Jaw")
    for i in range(60):
        a=TAU*i/60
        c.tube("FootMargin",[(.58*math.sin(a),.1+1.55*math.cos(a),.18),
                             (.65*math.sin(a+.012),.1+1.65*math.cos(a+.012),.08)], [.028,.018],1,"Body",sides=6)
    return c


def shroud_swimmer():
    c=Creature("M18","Shroud_Swimmer","freshwater_ray",
               ["958667","CFBE99","8E8259","2B2A23","5C5747","75694F","B4A27E","514735"],4.0)
    c.bone("Body",(0,.26,.16),(0,-.52,.18),radius=.45)
    c.bone("Head",(0,-.52,.18),(0,-.86,.17),"Body",.29)
    c.bone("Jaw",(0,-.61,.08),(0,-.80,.08),"Head",.14)
    for side in (-1,1):
        bones=[]
        for i in range(3):
            bones.append(c.bone("Fin"+str(side)+"_"+str(i),(side*i*.45,0,.16),
                                (side*(i+1)*.45,0,.14),"Body" if not i else bones[-1],.24))
        c.limbs.append(dict(bones=bones,phase=0 if side==1 else math.pi,kind="fin"))
    verts,faces,uv=[],[],[]
    for bottom in (False,True):
        for row in range(33):
            t=row/32
            y=-.94+1.92*t
            width=1.4*math.sin(math.pi*t)**.85
            for col in range(49):
                u=col/48*2-1
                x=u*width
                z=.14+(.12 if not bottom else -.09)*(1-u*u)*math.sin(math.pi*t)
                z+=.035*abs(u)**3*math.sin(t*TAU*1.5)
                verts.append((x,y,z));uv.append((col/48,t))
                if row and col:
                    k=len(verts)-1;f=(k-50,k-49,k,k-1)
                    faces.append(tuple(reversed(f)) if bottom else f)
    c.mesh("ContinuousRayDisc",verts,faces,0,uv,None)
    tail=[(0,.78,.16),(0,1.46,.11),(0,2.20,.07),(.16,2.92,.08)]
    c.limb("UnbarbedTail",tail,[.075,.045,.024,.002],"Body",core=False,kind="tail")
    for side in (-1,1):
        c.eye((side*.25,-.55,.27),.064,"Head",3,(0,-.1,1))
        c.ellipsoid("BreathingAperture",(side*.27,-.39,.25),(.055,.085,.014),3,"Head")
        for i in range(5):
            y=-.45+i*.095
            c.tube("VentralGill",[(side*.15,y,.045),(side*.30,y+.02,.055)], [.009]*2,3,"Body",sides=6)
    c.ellipsoid("VentralMouth",(0,-.65,.041),(.12,.045,.018),1,"Jaw",rough=.01)
    for i in range(140):
        a=i*2.39996
        r=math.sqrt((i+.5)/140)
        x=1.1*r*math.cos(a);y=.78*r*math.sin(a)
        width=1.4*math.sin(math.pi*(y+.94)/1.92)**.85
        if abs(x)>width*.90:continue
        z=.14+.12*(1-(x/width)**2)*math.sin(math.pi*(y+.94)/1.92)+.003
        c.ellipsoid("DorsalSpot",(x,y,z),(.018,.027,.003),5,None,rings=5,sides=8,rough=.08)
    return c


def build(asset_id,render=True):
    if asset_id=="M07":c=ashwing()
    elif asset_id=="M08":c=hart()
    elif asset_id in ("M09","M12"):c=segmented(asset_id)
    elif asset_id in ("M10","M14","M16"):c=arthropod(asset_id)
    elif asset_id=="M11":c=glassmoth()
    elif asset_id in ("M13","M15"):c=ground_quadruped(asset_id)
    elif asset_id=="M17":c=cairn_mother()
    elif asset_id=="M18":c=shroud_swimmer()
    else:raise ValueError("No authored creature "+asset_id)
    c.finish(render)
