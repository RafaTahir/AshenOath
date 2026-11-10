"""Per-species retained controls for native ambient replacement clips.

Angles are deliberately small. Grounded locomotion and combat clips retain
their source curves; these recipes never move the actor root or collision.
"""
import math

REPLACED_CLIPS = ("Idle", "Investigate", "Feed", "Sleep")
PRIORITY = ("M15", "M16", "M17", "M18")
SPECIES = {
    "M01": ("ghoulkin", "Uneven shoulder release and searching head; grounded hands settle."),
    "M02": ("wychwood_stalker", "Neck scent check, alternating jaw tension and restrained shoulder readiness."),
    "M03": ("bog_wretch", "Slow wet-throat effort and weary head turn; no buoyant root bob."),
    "M04": ("gravebound_knight", "Heavy helmet survey and restrained armor-bearing shoulder settle."),
    "M05": ("bell_eater", "Asymmetric listening inclination and deliberate jawward head recovery."),
    "M06": ("rootbound_colossus", "Loaded root-arm flex and slow crown inspection without trunk translation."),
    "M07": ("ashwing", "Individual folded wing fingers loosen in sequence; hooked head watches the ground."),
    "M08": ("white_hart_avatar", "Three-neck-chain alertness, restrained antler turn and native feeding attention."),
    "M09": ("silt_maw", "Anterior substrate probe and a low sequential body-segment contraction."),
    "M10": ("millback", "Independent claw feelers test the silt while the shell and six support legs stay planted."),
    "M11": ("glassmoth", "Four wings breathe in opposed phases with separate fore/hind timing; feeding coil works."),
    "M12": ("knell_leech", "Anterior suction test followed by a delayed segment response, with root anchored."),
    "M13": ("hearthscale", "Low head check, jaw breath and a slow three-joint tail settle near warm masonry."),
    "M14": ("gallows_weaver", "Foreleg strand test, small cheliceral feeding motion and a stable six-leg support."),
    "M15": ("reed_choir", "Three connected bellows inflate in a staggered pressure call; feet remain still."),
    "M16": ("inkblind", "Independent retained antenna probes and paired brush-palps; no invented eyes or wings."),
    "M17": ("cairn_mother", "Independent eye stalk and lower feeler exploration, then a slow protective head retreat."),
    "M18": ("shroud_swimmer", "A travelling wave across each three-joint fin, with counter-phased unbarbed tail."),
    "M19": ("wychwood_raider", "Quick directional glance and a contained off-hand reset."),
    "M20": ("wychwood_brute", "Slow shoulder loading and a heavy, deliberate head survey."),
}


def pulse(phase, centre, width):
    d = abs(phase-centre)
    return 0.0 if d >= width else .5+.5*math.cos(math.pi*d/width)


def channels(asset, clip, phase):
    """Return explicit bone rotations and morph values for a normalized cycle."""
    factor = {"Idle": .55, "Investigate": 1.0, "Feed": .8, "Sleep": .22}[clip]
    cycle = math.sin(math.tau*phase)
    # Every channel closes exactly, rather than wrapping a non-integral sine.
    beat = pulse(phase, .50, .38)
    left = pulse(phase, .28, .25)
    right = pulse(phase, .72, .25)
    rotations, morphs = [], {}

    def turn(name, axis, amount):
        rotations.append((name, axis, amount*factor))

    if asset in ("M01", "M03", "M04", "M05", "M19", "M20"):
        amount = {"M01": .09, "M03": .055, "M04": .035, "M05": .12, "M19": .10, "M20": .045}[asset]
        turn("Head", "Z", amount*(left-right))
        turn("neck_01", "X", (.045 if asset in ("M03", "M05") else .018)*beat)
        turn("clavicle_l", "Y", amount*.35*left)
        turn("clavicle_r", "Y", -amount*.25*right)
    elif asset == "M02":
        turn("Neck", "Z", .07*(left-right))
        turn("Head", "X", -.06*beat)
        turn("Jaw1", "X", .045*beat if clip == "Feed" else .012*cycle)
        turn("Jaw2", "X", -.025*beat if clip == "Feed" else -.008*cycle)
        turn("Shoulder.R", "Y", -.025*right)
    elif asset == "M06":
        turn("Neck", "Z", .035*(left-right))
        turn("Head", "X", .045*beat)
        turn("Arm1_1", "X", .025*left)
        turn("Arm-1_1", "X", .025*right)
    elif asset == "M07":
        turn("Neck", "Z", .06*(left-right))
        turn("Head", "X", .07*beat)
        for side in (1, -1):
            turn("Wing"+str(side)+"_1", "Y", side*.025*cycle)
            for index in range(4):
                turn("WingFinger"+str(side)+"_"+str(index), "Z",
                     side*.045*math.sin(math.tau*phase+index*.5)*math.sin(math.pi*phase)**2)
    elif asset == "M08":
        for index, amount in ((1, .025), (2, .035), (3, .045)):
            turn("Neck"+str(index), "Z", amount*(left-right))
        turn("Head", "X", (.12 if clip == "Feed" else .035)*beat)
        turn("Tail2", "Z", .035*cycle)
    elif asset in ("M09", "M12"):
        turn("Head", "Z", (.045 if asset == "M09" else .025)*(left-right))
        turn("Jaw", "X", (.06 if clip == "Feed" else .018)*beat)
        for index in range(6):
            turn("Segment"+str(index), "Z", (.018 if asset == "M09" else .025)*
                 math.sin(math.tau*phase-index*.65)*math.sin(math.pi*phase)**2)
    elif asset == "M10":
        for side in (1, -1):
            turn("ClawArm"+str(side)+"_0", "Z", side*.045*(left if side == 1 else right))
            turn("ClawArm"+str(side)+"_1", "X", -.06*(left if side == 1 else right))
        turn("Head", "X", .025*beat)
    elif asset == "M11":
        for side in (1, -1):
            turn("ForeWing"+str(side), "Y", side*.12*cycle)
            turn("HindWing"+str(side), "Y", side*.10*math.sin(math.tau*phase+.6)*math.sin(math.pi*phase)**2)
        turn("Head", "X", .04*beat)
        turn("Jaw", "X", .07*beat if clip == "Feed" else .012*cycle)
    elif asset == "M13":
        turn("Head", "Z", .055*(left-right))
        turn("Jaw", "X", .025*beat)
        for index in range(3):
            turn("Tail_"+str(index), "Z", .035*math.sin(math.tau*phase-index*.45)*math.sin(math.pi*phase)**2)
    elif asset == "M14":
        for side in (1, -1):
            turn("Leg"+str(side)+"_0_0", "X", -.07*(left if side == 1 else right))
            turn("Leg"+str(side)+"_0_1", "X", .09*(left if side == 1 else right))
        turn("Jaw", "X", .04*beat if clip == "Feed" else .01*beat)
    elif asset == "M15":
        for index, centre in enumerate((.25, .50, .75)):
            morphs["Sac"+str(index)+"_Inflate"] = (.68 if clip in ("Idle", "Feed") else .25)*pulse(phase, centre, .22)*factor
        turn("Jaw", "X", .03*beat)
        turn("Head", "Z", .025*(left-right))
    elif asset == "M16":
        morphs["AntennaProbe_L"] = left*factor
        morphs["AntennaProbe_R"] = right*factor
        morphs["BrushFeed_L"] = pulse(phase, .38, .22)*factor if clip == "Feed" else .12*beat*factor
        morphs["BrushFeed_R"] = pulse(phase, .61, .22)*factor if clip == "Feed" else .12*beat*factor
        turn("Head", "Z", .025*(left-right))
        turn("Jaw", "X", .035*beat if clip == "Feed" else .008*cycle)
    elif asset == "M17":
        for side in (1, -1):
            turn("EyeStalk"+str(side), "Z", side*.15*(left if side == 1 else right))
            turn("Feeler"+str(side), "Z", side*.10*(right if side == 1 else left))
            turn("EyeStalk"+str(side), "X", .045*beat)
        turn("Head", "X", -.045*beat if clip == "Sleep" else .025*beat)
        turn("Jaw", "X", .035*beat if clip == "Feed" else .008*cycle)
    elif asset == "M18":
        for side in (1, -1):
            for index in range(3):
                wave = math.sin(math.tau*phase-index*.85)
                turn("Fin"+str(side)+"_"+str(index), "Y", side*(.07+index*.025)*wave*math.sin(math.pi*phase)**2)
        for index in range(3):
            turn("UnbarbedTail_"+str(index), "Z", -.04*math.sin(math.tau*phase-index*.5)*math.sin(math.pi*phase)**2)
        turn("Head", "X", .018*beat)
    else:
        raise ValueError("Unknown retained species: "+asset)
    return rotations, morphs
