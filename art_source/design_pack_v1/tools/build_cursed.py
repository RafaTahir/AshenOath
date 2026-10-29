"""Design-pack biped sculpts: six cursed bodies, the knight and Rootbound."""
import math
from mathutils import Vector
from creature_workshop import Creature, TAU


PROFILES={
    "M01":dict(name="Ghoulkin",height=1.63,shoulder=.35,hip=.22,belly=.20,
               head=.17,lean=.22,arm=.91,leg=.69,fingers=5,face="ghoul",hair=True,
               colors=["817C6D","ACA38A","B6B39C","242725","343832","55523E","9B805F","433A2F"]),
    "M02":dict(name="Wychwood_Stalker",height=1.60,shoulder=.32,hip=.18,belly=.13,
               head=.14,lean=.30,arm=1.02,leg=.73,fingers=4,face="stalker",hair=True,
               colors=["666B57","9E967D","A49D65","171D17","343B2E","35372B","867B54","433D2F"]),
    "M03":dict(name="Bog_Wretch",height=1.72,shoulder=.36,hip=.29,belly=.32,
               head=.22,lean=.29,arm=1.10,leg=.72,fingers=4,face="bog",hair=False,
               colors=["7B7354","A99B73","B98B3A","211F19","414539","4C503B","8A622C","4C3A29"]),
    "M04":dict(name="Gravebound_Knight",height=1.88,shoulder=.32,hip=.24,belly=.23,
               head=.14,lean=.025,arm=.78,leg=.94,fingers=5,face="helmet",hair=False,
               colors=["55534C","A59C81","888473","141615","555B5A","625E4B","97815B","514234"]),
    "M05":dict(name="Bell_Eater",height=3.8,shoulder=.78,hip=.54,belly=.52,
               head=.27,lean=.28,arm=1.87,leg=1.62,fingers=5,face="bell",hair=False,
               colors=["8B8274","A89B82","AAA58D","302C28","6D755B","4B4334","857046","54432F"]),
    "M06":dict(name="Rootbound_Colossus",height=4.4,shoulder=1.04,hip=.72,belly=.73,
               head=.36,lean=.25,arm=2.1,leg=1.68,fingers=4,face="root",hair=False,
               colors=["6B5941","9B9070","C59743","29251D","676551","4A5131","8D6336","413A2E"]),
    "M19":dict(name="Wychwood_Raider",height=1.86,shoulder=.42,hip=.24,belly=.17,
               head=.17,lean=.17,arm=1.02,leg=.87,fingers=4,face="raider",hair=True,
               colors=["78765B","B2A080","A88A4B","26281F","514B39","655035","8A7250","403B2D"]),
    "M20":dict(name="Wychwood_Brute",height=1.98,shoulder=.61,hip=.35,belly=.30,
               head=.24,lean=.18,arm=1.04,leg=.80,fingers=4,face="brute",hair=False,
               colors=["6D6C55","AA9E7D","B39B59","25271F","565140","54513B","8F7852","413C2F"]),
}


def chain(c,name,start,end,slack,mat=4,bone="Body",links=16,radius=.035):
    start,end=Vector(start),Vector(end)
    for i in range(links):
        t=i/(links-1)
        center=start.lerp(end,t)+Vector((0,0,-slack*math.sin(math.pi*t)))
        a=Vector((radius,0,0)) if i%2 else Vector((0,radius,0))
        b=Vector((0,0,radius*1.6))
        points=[center+a*math.cos(j*TAU/12)+b*math.sin(j*TAU/12) for j in range(13)]
        c.tube(name,points,[radius*.24]*13,mat,bone,sides=5)


def fingers(c,name,hand,count,width,length,bone,web=False,claw=.025):
    hand=Vector(hand)
    for i in range(count):
        lateral=(i-(count-1)/2)*width/count*1.5
        start=hand+Vector((lateral,-.015,0))
        end=start+Vector((lateral*.3,-length*.40,-length*(.8+.2*math.sin(i*math.pi/count))))
        mid=start.lerp(end,.55)+Vector((0,-length*.17,0))
        c.tube(name+str(i),[start,mid,end], [width/count*.36,width/count*.32,width/count*.21],0,bone,sides=10)
        c.fang("Claw",end,end+Vector((0,-claw,-claw*.4)),width/count*.23,1,bone)
        if web and i:
            previous=hand+Vector(((i-1-(count-1)/2)*width/count*1.5,-.015,0))
            c.mesh("FingerWeb",[tuple(hand),tuple(previous+Vector((0,-length*.15,-length*.5))),
                                tuple(start+Vector((0,-length*.15,-length*.5)))],[(0,1,2)],0,
                   [(0,0),(0,1),(1,1)],bone)


def face(c,p,head):
    h=p["head"]; kind=p["face"]; head=Vector(head)
    if kind=="root":
        c.ellipsoid("KnottedHead",head,(h*1.35,h*.85,h),0,"Head",True,rough=.14)
        for side in (-1,1):
            pos=head+Vector((side*h*.49,-h*.74,h*.10))
            c.ellipsoid("RecessedKnot",pos,(h*.16,h*.05,h*.13),3,"Head",rough=.1)
        return
    c.ellipsoid("Cranium",head,(h*.94,h*.83,h*(.82 if kind=="bog" else 1.04)),0,"Head",True,rough=.035)
    muzzle=head+Vector((0,-h*.65,-h*.21))
    extended=kind in ("stalker","raider")
    c.ellipsoid("Muzzle",muzzle,(h*(.65 if extended else .82),h*(.82 if extended else .52),h*.43),0,"Head",True)
    c.ellipsoid("Jaw",muzzle+Vector((0,-h*.06,-h*.32)),(h*.73,h*.49,h*.28),0,"Jaw",False)
    mouth=[]
    for i in range(25):
        x=(i/24*2-1)*h*.69
        mouth.append(muzzle+Vector((x,-h*.43*(1-(x/(h*.84))**2),-h*.13)))
    c.tube("MouthRecess",mouth,[h*.026]*25,3,"Jaw",sides=8)
    for side in (-1,1):
        eye=head+Vector((side*h*.58,-h*.69,h*.15))
        c.eye(eye,h*(.10 if kind in ("bog","bell") else .14),"Head",2)
        c.tube("HeavyBrow",[eye+Vector((-h*.25,-h*.02,h*.15)),eye+Vector((0,-h*.08,h*.13)),
                            eye+Vector((h*.23,0,h*.05))],[h*.09,h*.12,h*.08],0,"Head",sides=12)
        ear=head+Vector((side*h*.91,.02,h*.13))
        if extended:
            c.crest("FoldedEar",ear,h*.55,h*.25,h*.1,"Head",0,(side,.2,.8))
        elif kind!="bog":
            c.ellipsoid("Ear",ear,(h*.22,h*.16,h*.29),0,"Head",rough=.025)
            c.ellipsoid("EarConcha",ear+Vector((0,-h*.12,0)),(h*.12,h*.035,h*.17),3,"Head")
        nostril=muzzle+Vector((side*h*.24,-h*(.76 if extended else .48),h*.17))
        c.ellipsoid("Nostril",nostril,(h*.09,h*.035,h*.065),3,"Head",rough=0)
        if kind=="brute":
            start=muzzle+Vector((side*h*.71,-h*.29,-h*.22))
            c.tube("LateralTusk",[start,start+Vector((side*h*.11,-h*.14,h*.11)),
                                  start+Vector((side*h*.20,-h*.10,h*.36))],
                   [h*.13,h*.09,.001],1,"Jaw",sides=10)
    for i in range(8):
        x=(i/7*2-1)*h*.53
        a=muzzle+Vector((x,-h*.46*(1-(x/(h*.85))**2),-h*.09))
        c.fang("MouthTooth",a,a+Vector((0,0,-h*.10)),h*.045,1,"Head")
    if kind=="bell":
        c.ellipsoid("ResonantThroat",head+Vector((0,h*.30,-h*.9)),(h*.75,h*.67,h*1.0),0,"Neck",True)
    if kind=="bog":
        c.ellipsoid("CollapsedBrow",head+Vector((0,-h*.42,h*.12)),(h*.94,h*.72,h*.47),0,"Head",True,rough=.05)
        for i in range(5):
            z=-h*(.55+i*.18)
            points=[head+Vector((h*.8*math.cos(a),-.04-h*.58*math.sin(a),z-.035*math.sin(a)))
                    for a in [j*math.pi/20 for j in range(21)]]
            c.tube("ThroatFold",points,[h*.034]*21,0,"Neck",sides=8,rough=.05)


def bell_harness(c,p):
    s=p["height"]/3.8
    center=Vector((0,-.50*s,1.53*s))
    profile=[(0,.61),(.06,.64),(.15,.56),(.40,.45),(.74,.38),(.83,.30)]
    verts,faces,uv=[],[],[]
    for inner in (False,True):
        for row,(z,r) in enumerate(profile):
            for i in range(65):
                angle=TAU*i/64
                chip=.07*max(0,math.sin(angle*7+.2))**10 if row==0 else 0
                radius=(r-(.045 if inner else 0))*s
                verts.append(tuple(center+Vector((radius*math.cos(angle),radius*math.sin(angle),z*s+chip*s))))
                uv.append((i/64,row/5))
                if row and i:
                    j=len(verts)-1
                    f=(j-66,j-65,j,j-1)
                    faces.append(tuple(reversed(f)) if inner else f)
    n=6*65
    for i in range(64): faces.append((i,i+1,n+i+1,n+i))
    c.mesh("CrackedBronzeBell",verts,faces,4,uv,"Body")
    c.tube("BellClapper",[center+Vector((0,0,.6*s)),center+Vector((0,0,.05*s))],[.04*s]*2,4,"Body")
    c.ellipsoid("ClapperHead",center+Vector((0,0,.06*s)),(.11*s,.11*s,.13*s),4,"Body")
    for side in (-1,1):
        c.tube("LeatherHarness",[(side*.35*s,-.65*s,2.1*s),(side*.57*s,-.35*s,3.0*s),
                                 (side*.56*s,.24*s,3.05*s),(side*.39*s,.39*s,1.78*s)],
               [.065*s]*4,7,"Body",sides=8)
        chain(c,"HangingChain",(side*.51*s,-.65*s,2.1*s),(side*.91*s,-.25*s,1.1*s),.40*s,
              links=18,radius=.041*s)


def knight_armor(c,p,head):
    h=p["height"]
    # Dark openings belong to the closed helmet, not an exposed borrowed face.
    c.ellipsoid("ClosedHelm",Vector(head)+Vector((0,0,.015)),(.145,.14,.19),4,"Head",rough=.01)
    c.tube("HelmBrow",[(-.13,-.123,h-.20),(0,-.17,h-.19),(.13,-.123,h-.20)],
           [.018]*3,4,"Head",sides=8)
    c.tube("VisorEyeSlit",[(-.115,-.14,h-.225),(0,-.166,h-.23),(.115,-.14,h-.225)],
           [.009]*3,3,"Head",sides=6)
    c.tube("VisorNasalRidge",[(0,-.171,h-.19),(0,-.17,h-.39)],[.021,.013],4,"Head",sides=6)
    c.ellipsoid("Breastplate",(0,-.065,1.29),(.30,.20,.31),4,"Body",rough=.015)
    for side in (-1,1):
        for i in range(3):
            c.ellipsoid("LamedPauldron",(side*(.31+.024*i),.01,1.47-.055*i),
                        (.14,.18,.10),4,"Arm"+str(side)+"_0",rough=.02,rings=10,sides=20)
        c.ellipsoid("KneePlate",(side*.18,-.09,.55),(.10,.08,.11),4,"Leg"+str(side)+"_1")
        c.tube("ShinGreave",[(side*.18,.02,.14),(side*.18,-.01,.47)],[.085,.095],4,"Leg"+str(side)+"_1",sides=12)
        for strip in range(5):
            x=side*(.035+strip*.042)
            c.tube("FrayedLinen",[(x,-.20,1.16),(x*.95,-.22,.90),(x*1.4,-.19,.46-.035*(strip%3))],
                   [(.025,.006),(.022,.006),(.010,.004)],1,"Pelvis",sides=8,rough=.12)
    hand=c.bones[[b["name"] for b in c.bones].index("Arm-1_1")]["tail"]
    c.tube("SwordGrip",[hand+Vector((0,0,.07)),hand-Vector((0,0,.10))],[.025]*2,7,"Arm-1_1")
    c.tube("SwordCrossguard",[hand+Vector((-.12,0,-.11)),hand+Vector((.12,0,-.11))],[.017]*2,4,"Arm-1_1")
    a=hand+Vector((0,0,-.13))
    verts=[a+Vector((-.045,0,0)),a+Vector((.045,0,0)),a+Vector((0,-.014,-.38)),a+Vector((0,0,-.72))]
    c.mesh("SwordBlade",[tuple(v) for v in verts],[(0,1,2),(0,2,3),(1,3,2)],4,[(0,0),(1,0),(.5,.5),(.5,1)],"Arm-1_1")
    hand=c.bones[[b["name"] for b in c.bones].index("Arm1_1")]["tail"]
    verts=[hand+Vector((x,-.12,z)) for x,z in [(-.21,.47),(.21,.47),(.23,-.22),(0,-.52),(-.23,-.22)]]
    shield=c.mesh("TallShield",[tuple(v) for v in verts],[(0,1,2,3,4)],4,[(0,1),(1,1),(1,.3),(.5,0),(0,.3)],"Arm1_1")
    # The back and rim are explicit geometry, not a one-sided game shield.
    c.tube("ShieldRim",verts+[verts[0]],[.018]*6,1,"Arm1_1",sides=6)
    c.mesh("ShieldBack",[tuple(v+Vector((0,.025,0))) for v in verts],[(4,3,2,1,0)],7,
           [(0,1),(1,1),(1,.3),(.5,0),(0,.3)],"Arm1_1")


def build(asset_id,render=True):
    p=PROFILES[asset_id]
    c=Creature(asset_id,p["name"],"cursed_biped",p["colors"],p["height"])
    height=p["height"]; hip=p["leg"]; shoulder=height-p["head"]*1.5
    body_y=p["lean"]*.15
    c.bone("Pelvis",(0,.06,hip),(0,body_y,hip+.20),radius=p["hip"])
    c.bone("Body",(0,body_y,hip+.20),(0,-p["lean"]*.4,shoulder),"Pelvis",p["shoulder"]*.7)
    head=(0,-p["lean"]-p["head"]*.2,height-p["head"])
    c.bone("Neck",(0,-p["lean"]*.4,shoulder),head,"Body",p["head"]*.7)
    c.bone("Head",head,Vector(head)+Vector((0,-p["head"],p["head"]*.2)),"Neck",p["head"])
    c.bone("Jaw",Vector(head)+Vector((0,-p["head"]*.1,-p["head"]*.3)),
           Vector(head)+Vector((0,-p["head"]*.9,-p["head"]*.35)),"Head",p["head"]*.4)
    c.ellipsoid("Pelvis",(0,.05,hip),(p["hip"],p["belly"]*.8,height*.15),0,None,True)
    c.ellipsoid("Abdomen",(0,-.02,hip+height*.15),(p["belly"],p["belly"]*.80,height*.18),0,None,True)
    c.ellipsoid("Ribcage",(0,-p["lean"]*.22,shoulder-height*.12),
                (p["shoulder"]*.82,p["shoulder"]*.55,height*.19),0,None,True)
    c.tube("NeckTendons",[(0,-p["lean"]*.2,shoulder-height*.10),head],
           [p["head"]*.76,p["head"]*.61],0,None,True,sides=22)
    for side in (-1,1):
        shoulder_p=(side*p["shoulder"],0,shoulder-.05*height)
        elbow=(side*(p["shoulder"]+.10*height),-.01*height,shoulder-p["arm"]*.52)
        wrist=(side*(p["shoulder"]+.13*height),-.10*height,shoulder-p["arm"])
        arm_r=p["shoulder"]*(.27 if asset_id=="M02" else .36)
        arm=c.limb("Arm"+str(side),[shoulder_p,elbow,wrist],[arm_r,arm_r*.72,arm_r*.47],
                   "Body",phase=0 if side==1 else math.pi,kind="arm")
        c.ellipsoid("Deltoid",shoulder_p,(arm_r*1.06,arm_r*1.05,arm_r*1.25),0,None,True)
        c.ellipsoid("Palm",Vector(wrist)+Vector((0,-.02,-arm_r*.3)),(arm_r*.66,arm_r*.43,arm_r*.85),0,arm[-1])
        fingers(c,"Finger",Vector(wrist)-Vector((0,0,arm_r*.6)),p["fingers"],arm_r*1.1,
                arm_r*(1.8 if asset_id=="M03" else 1.2),arm[-1],asset_id=="M03",arm_r*(.8 if asset_id in ("M02","M19") else .22))
        knee=(side*p["hip"]*.84,-.10*height,hip*.55)
        ankle=(side*p["hip"]*.98,.02, .12*height)
        leg=c.limb("Leg"+str(side),[(side*p["hip"]*.65,.07,hip),knee,ankle],
                   [p["hip"]*.66,p["hip"]*.45,p["hip"]*.30],"Pelvis",phase=math.pi if side==1 else 0)
        foot=(ankle[0],-.10*height,.065*height)
        c.ellipsoid("Foot",foot,(p["hip"]*.45,height*.125,height*.065),0,leg[-1],rough=.025)
        for toe in range(4):
            x=foot[0]+(toe-1.5)*p["hip"]*.19
            c.tube("Toe",[(x,-.12*height,.06*height),(x,-.20*height,.045*height)],
                   [p["hip"]*.12,p["hip"]*.10],0,leg[-1],sides=10)
            c.fang("Toenail",(x,-.20*height,.05*height),(x,-.224*height,.034*height),p["hip"]*.09,1,leg[-1])
    if asset_id=="M04": knight_armor(c,p,head)
    else: face(c,p,head)
    if p["hair"]:
        for row in range(12):
            t=row/11
            for i in range(7):
                x=(i-3)*p["shoulder"]*.16
                z=shoulder+(height-shoulder)*.20-t*height*.35
                radius=p["shoulder"]*.55
                y=-p["lean"]*.22+radius*math.sqrt(max(.05,1-(x/(p["shoulder"]*.82))**2))
                if z < shoulder-height*.25:
                    y=p["belly"]*.72
                start=Vector((x,y-.012,z))
                c.tube("RoughMane",[start,start+Vector((.008*math.sin(i+row),.018,-height*.025)),
                                     start+Vector((.012*math.sin(i+row),.01,-height*.06))],
                       [height*.012,height*.009,.001],5,"Body",sides=7)
    if asset_id=="M03":
        core=(0,-p["belly"]*.93,shoulder-.25*height)
        c.ellipsoid("MemoryCore",core,(.10,.06,.13),6,"Body",rough=.04)
        for i in range(11):
            side=-1 if i%2 else 1
            x=side*(.09+.025*(i%5))
            c.tube("RootLigature",[(x,.18,shoulder-.15),(x*1.7,-.12,shoulder-.28),
                                  (x*.25,-.37,shoulder-.45),(x,-.29,shoulder-.69)],
                   [.014,.017,.009,.003],5,"Body",sides=7,rough=.12)
        for i in range(36):
            x=math.sin(i*2.4)*.30
            top=Vector((x,.17+.035*math.cos(i),1.42-.018*(i%7)))
            c.tube("PeatReeds",[top,top+Vector((.035*math.sin(i),.045,-.22)),
                                 top+Vector((.055*math.sin(i),.05,-.42-.018*(i%5)))],
                   [.008,.006,.0015],7,"Body",sides=6,rough=.2)
    if asset_id=="M05": bell_harness(c,p)
    if asset_id=="M06":
        for row in range(12):
            z=.95+row*.24
            for side in (-1,1):
                for layer in range(3):
                    x=side*(.11+layer*.20)
                    y=-.49+abs(x)*.12
                    c.crest("BarkPlate",(x,y,z),.39,.14,.07,"Body",1,(side*.15,-.08,-1))
        for i in range(22):
            a=TAU*i/22
            points=[(.55*math.sin(a),.3*math.cos(a),.22),(.75*math.sin(a+.08),.48*math.cos(a),.10),
                    (.90*math.sin(a+.2),.69*math.cos(a),.035)]
            c.tube("ButtressRoot",points,[.10,.07,.005],0,"Pelvis",sides=10,rough=.13)
        c.tube("LivingCore",[(0,-.61,1.9),(0,-.63,2.7),(0,-.5,3.1)],
               [(.10,.035),(.13,.04),(.045,.03)],2,"Body",sides=12)
    c.finish(render)
