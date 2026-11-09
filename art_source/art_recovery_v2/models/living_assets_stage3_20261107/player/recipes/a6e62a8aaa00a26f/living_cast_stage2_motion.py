"""Purposeful native motion recipes on the retained Stage2 skeletons.

Exact station contacts are baked against measured palm surfaces. This module
never changes a rest transform, actor scale, physics root or planted foot.
"""
import json
import math
import bpy
from mathutils import Matrix, Quaternion, Vector

from living_cast_stage2_profiles import PROFILES


def relax_work_fingers(rig, side, weight):
    for finger, spread in [('index',-.025),('middle',0),('ring',.020),('pinky',.040)]:
        for joint in range(1,4):
            bone = rig.pose.bones[f'{finger}_{joint:02d}_{side}']
            relaxed = Quaternion((1,0,0), -.030 if joint>1 else 0.0)
            if joint == 1:
                relaxed = Quaternion((0,0,1), spread*(-1 if side=='r' else 1)) @ relaxed
            bone.rotation_quaternion = bone.rotation_quaternion.slerp(relaxed,weight)
    # Thumb rest geometry is abducted out of the palm plane. Neutral local
    # rotations alone therefore still point the thumb through a work surface.
    # Uncurl its joints, then place the retained chain alongside the palm.
    for joint in range(1,4):
        thumb = rig.pose.bones[f'thumb_{joint:02d}_{side}']
        thumb.rotation_quaternion = thumb.rotation_quaternion.slerp(Quaternion(),weight)
    bpy.context.view_layer.update()
    hand = rig.pose.bones['hand_'+side]
    thumb = rig.pose.bones['thumb_01_'+side]
    tip = rig.pose.bones['thumb_03_'+side].tail.copy()
    hand_inverse = hand.matrix.inverted()
    start = hand_inverse @ thumb.head
    end = hand_inverse @ tip
    middle = hand_inverse @ rig.pose.bones['middle_01_'+side].head
    target = end.copy()
    lift = .070 if middle.y > .10 else .040
    target.x = start.x - (lift if side == 'l' else -lift)
    current = tip-thumb.head
    desired = hand.matrix.to_3x3() @ (target-start)
    rotation = Quaternion().slerp(current.rotation_difference(desired),weight)
    position, orientation, scale = thumb.matrix.decompose()
    thumb.matrix = Matrix.LocRotScale(position, rotation @ orientation, scale)
    bpy.context.view_layer.update()


def smoothstep(start, end, value):
    amount = max(0.0, min(1.0, (value-start)/(end-start)))
    return amount*amount*(3.0-2.0*amount)


def supported_hand_path(phase, sign, contact_goal):
    """Raise in front of the body, cross above the edge, then touch/retract."""
    mirrored = phase if phase <= .5 else 1.0-phase
    raise_goal = Vector((sign*.22, .16, max(1.16,contact_goal[2]+.14)))
    hover_goal = Vector((contact_goal[0], contact_goal[1], raise_goal.z))
    if mirrored < .20:
        return raise_goal, smoothstep(.02,.20,mirrored)
    if mirrored < .36:
        return raise_goal.lerp(hover_goal,smoothstep(.20,.36,mirrored)), 1.0
    return hover_goal.lerp(Vector(contact_goal),smoothstep(.36,.50,mirrored)), 1.0


def apply(rig, asset, clip, phase, helpers):
    turn, pulse, palm_goal, hand_goal = [helpers[key] for key in ("turn", "pulse", "palm_goal", "hand_goal")]
    profile = PROFILES[asset]
    strength = profile["scale"]
    breath = math.sin(phase * math.tau)
    turn(rig, "spine_02", (1, 0, 0), .007 * strength * breath)
    turn(rig, "spine_03", (1, 0, 0), -.003 * strength * breath)
    if clip == "Life_Idle_A":
        turn(rig, "clavicle_l", (0, 1, 0), .008 * strength * breath)
        turn(rig, "clavicle_r", (0, 1, 0), -.008 * strength * breath)
        if asset in ("C08", "C07"):
            turn(rig, "Head", (0, 0, 1), .012 * math.sin(phase * math.tau) * strength)
        elif asset in ("C11", "C10"):
            turn(rig, "spine_01", (0, 0, 1), .008 * math.sin(phase * math.tau) * strength)
        return

    if clip == "Life_Idle_B":
        beat = pulse(phase, .5, .34)
        if asset == "C11":
            # A brief glance at the flour-bearing palm, followed by a relaxed
            # finger flex. This does not claim unmeasured apron contact.
            relax_work_fingers(rig, 'r', .75*beat)
            palm_goal(rig, asset, 'r', (.25,.24,1.07), beat, normal_goal=(0,-.15,1))
            turn(rig, "Head", (1, 0, 0), .055 * beat)
            turn(rig, "spine_03", (0, 0, 1), -.025 * beat)
        elif asset == "C05":
            turn(rig, "upperarm_l", (1, 0, 0), -.20 * beat)
            turn(rig, "lowerarm_l", (1, 0, 0), -.43 * beat)
            turn(rig, "hand_l", (0, 0, 1), .13 * beat)
            turn(rig, "Head", (1, 0, 0), .025 * beat)
        elif asset == "C06":
            turn(rig, "upperarm_r", (1, 0, 0), -.17 * beat)
            turn(rig, "lowerarm_r", (1, 0, 0), -.35 * beat)
            turn(rig, "hand_r", (0, 1, 0), .17 * math.sin(phase * math.tau * 2) * beat)
            turn(rig, "Head", (0, 0, 1), -.04 * beat)
        elif asset == "C12":
            turn(rig, "upperarm_l", (1, 0, 0), -.18 * beat)
            turn(rig, "lowerarm_l", (1, 0, 0), -.36 * beat)
            turn(rig, "clavicle_r", (0, 1, 0), -.035 * beat)
            turn(rig, "Head", (0, 0, 1), -.065 * beat)
        elif asset == "C07":
            turn(rig, "clavicle_l", (0, 1, 0), .07 * beat)
            turn(rig, "upperarm_l", (0, 1, 0), .05 * beat)
            turn(rig, "spine_03", (0, 0, 1), -.025 * beat)
            turn(rig, "Head", (0, 0, 1), -.05 * beat)
        elif asset == "C09":
            turn(rig, "upperarm_r", (1, 0, 0), -.18 * beat)
            turn(rig, "lowerarm_r", (1, 0, 0), -.39 * beat)
            turn(rig, "hand_r", (0, 0, 1), .10 * beat)
            turn(rig, "Head", (1, 0, 0), -.025 * beat)
        elif asset == "C10":
            turn(rig, "upperarm_l", (1, 0, 0), -.16 * beat)
            turn(rig, "lowerarm_l", (1, 0, 0), -.30 * beat)
            turn(rig, "hand_l", (0, 0, 1), .14 * beat)
            turn(rig, "spine_03", (0, 0, 1), .035 * beat)
        else:
            turn(rig, "upperarm_r", (1, 0, 0), -.17 * beat)
            turn(rig, "lowerarm_r", (1, 0, 0), -.47 * beat)
            turn(rig, "hand_r", (0, 0, 1), -.09 * beat)
            turn(rig, "Head", (0, 0, 1), .018 * beat)
        return

    if clip in ("Life_Work", "Life_Settle_Ledger"):
        if asset == "C07":
            left = pulse(phase, .28, .26)
            right = pulse(phase, .70, .25)
            turn(rig, "spine_03", (0, 0, 1), .09 * left - .075 * right)
            turn(rig, "Head", (0, 0, 1), .18 * left - .15 * right)
            turn(rig, "Head", (1, 0, 0), -.018 * left + .025 * right)
            turn(rig, "clavicle_r", (0, 1, 0), -.025 * right)
            return
        contact = pulse(phase, .50, .31)
        approach = pulse(phase, .23, .23)
        release = pulse(phase, .76, .23)
        for bone, value in zip(("spine_01", "spine_02", "spine_03"), profile["lean"]):
            turn(rig, bone, (1, 0, 0), value * contact)
        turn(rig, "Head", (1, 0, 0), profile["counter_head"] * contact)
        if asset == "C11":
            # Ease the retained asymmetric standing stance into a balanced
            # two-palm press; the pelvis and both feet stay in their native pose.
            shoulders = rig.matrix_world.to_3x3() @ (rig.pose.bones['upperarm_r'].head-rig.pose.bones['upperarm_l'].head)
            turn(rig, 'spine_01', (0, 0, 1), -math.atan2(shoulders.y, shoulders.x)*.70*contact)
            turn(rig, 'spine_02', (0, 1, 0), -math.atan2(shoulders.z, shoulders.x)*.70*contact)
        if clip == "Life_Settle_Ledger":
            turn(rig, "Head", (0, 0, 1), -.035 * contact)
        # The lead-in is actor-specific and large enough to read at gameplay
        # distance; its pulse is zero at the calibrated contact moment.
        leading_side = "l" if asset == "C05" else "r"
        turn(rig, "lowerarm_" + leading_side, (1, 0, 0),
             (-.48 if clip == "Life_Settle_Ledger" else -.28) * approach)
        if asset in ("C11", "C12"):
            turn(rig, "lowerarm_l", (1, 0, 0), -.24 * approach)
        elif asset == "C06":
            turn(rig, "hand_r", (0, 1, 0), .13 * approach)
        elif asset == "C10":
            turn(rig, "upperarm_r", (0, 1, 0), -.09 * approach)
        for side, sign in (("l", -1), ("r", 1)):
            turn(rig, "upperarm_" + side, (1, 0, 0), -.25 * contact)
            turn(rig, "lowerarm_" + side, (1, 0, 0), -.40 * contact)
            turn(rig, "hand_" + side, (0, 0, 1), sign * .09 * contact)
            goal = list(profile["palm_goals_lateral_forward_height"][side])
            if asset == "C11":
                goal[0] += sign * .025 * release
                goal[2] += .045 * approach
            elif asset == "C05":
                if side == "r":
                    goal[0] += .055 * approach - .025 * release
                    goal[1] += .020 * release
            elif asset == "C06":
                goal[1] += (.035 if side == "r" else -.02) * approach
                goal[2] += .055 * approach
            elif asset == "C12":
                goal[0] += sign * .025 * release
                goal[2] += .025 * approach
            elif asset == "C09":
                if side == "r":
                    goal[0] += .04 * approach - .03 * release
                    goal[1] += .035 * release
            elif asset == "C10":
                if side == "r":
                    goal[0] += .06 * approach - .04 * release
                    goal[2] += .08 * approach
            elif asset == "C08":
                if side == "r":
                    goal[2] += .06 * approach
                turn(rig, "Head", (0, 0, 1), -.02 * approach)
            # All approach/release contributions vanish at phase .50; the
            # principal contact is the measured physical marker exactly.
            flat = asset != 'C12'
            goal, hand_weight = supported_hand_path(phase,sign,goal)
            if flat:
                # Release the native idle's closed fingers into a modestly
                # spread palm. Finger locations/scales/rests are unchanged.
                relax_work_fingers(rig, side, hand_weight)
            palm_goal(rig, asset, side, goal, hand_weight, flat=flat)
        return

    if clip == "Life_Listen":
        beat = pulse(phase, .56, .25)
        nod = {"C11": .045, "C05": .025, "C06": .035, "C12": .038,
               "C07": .018, "C09": .026, "C10": .032, "C08": .018}[asset]
        turn(rig, "Head", (1, 0, 0), nod * beat)
        turn(rig, "spine_03", (1, 0, 0), .015 * beat * strength)
        if asset in ("C05", "C09", "C10"):
            turn(rig, "Head", (0, 0, 1), .027 * beat)
        if asset == "C11":
            turn(rig, "clavicle_l", (0, 1, 0), .022 * beat)
        return

    if clip == "Life_Speak":
        beat = pulse(phase, .43, .31)
        second = pulse(phase, .72, .20)
        side = "l" if asset == "C05" else "r"
        amount = {"C11": .30, "C05": .16, "C06": .23, "C12": .30,
                  "C07": .14, "C09": .18, "C10": .21, "C08": .16}[asset]
        turn(rig, "upperarm_" + side, (1, 0, 0), -amount * beat)
        turn(rig, "lowerarm_" + side, (1, 0, 0), -(amount + .12) * beat)
        turn(rig, "hand_" + side, (0, 0, 1), (-.14 if side == "r" else .11) * beat)
        turn(rig, "spine_03", (0, 0, 1), .018 * beat * strength)
        relax_work_fingers(rig, side, .85*beat)
        gesture_goals = {'C11':(.30,.30,1.11),'C05':(-.25,.22,1.08),'C06':(.31,.27,1.13),
                         'C12':(.32,.33,1.18),'C07':(.26,.23,1.12),'C09':(.27,.25,1.12),
                         'C10':(.29,.28,1.19),'C08':(.28,.25,1.20)}
        palm_goal(rig, asset, side, gesture_goals[asset], beat, normal_goal=(0,-.15,1))
        if asset == "C11":
            turn(rig, "upperarm_l", (1, 0, 0), -.12 * second)
            turn(rig, "lowerarm_l", (1, 0, 0), -.20 * second)
        elif asset == "C12":
            turn(rig, "upperarm_r", (0, 1, 0), -.07 * beat)
        elif asset == "C09":
            turn(rig, "hand_r", (0, 1, 0), .07 * second)
        return

    if clip in ("Life_Cup_Hold", "Life_Drink"):
        # Native cup geometry/calibration must exist first; no guessed wrist
        # target is allowed to masquerade as a verified lip or handle contact.
        path = helpers["models"] / "props/merrow_cup_calibration.json"
        calibration = json.loads(path.read_text())
        if not calibration.get("grip_verified") or not calibration.get("rim_calibrated"):
            raise ValueError("Merrow cup needs measured retained handle/rim calibration")
        for bone_name, values in calibration['finger_rotations_blender_wxyz'].items():
            rig.pose.bones[bone_name].rotation_quaternion = Quaternion(values)
        bpy.context.view_layer.update()
        beat = pulse(phase, .50, .37) if clip == "Life_Drink" else 0.0
        hold_goal = Vector(calibration["hold_wrist_goal_lateral_forward_height"])
        sip_goal = Vector(calibration["wrist_goal_lateral_forward_height"])
        hand_goal(rig, "r", hold_goal.lerp(sip_goal, beat), 1.0,
                  calibration["elbow_hint_world_blender"])
        hand = rig.pose.bones["hand_r"]
        hold_rotation = Quaternion(calibration["hold_wrist_rotation_blender_wxyz"])
        sip_rotation = Quaternion(calibration["wrist_rotation_blender_wxyz"])
        target_rotation = hold_rotation.slerp(sip_rotation, beat)
        position, rotation, scale = hand.matrix.decompose()
        hand.matrix = Matrix.LocRotScale(position, target_rotation, scale)
        turn(rig, "Head", (1, 0, 0), -.035 * beat)
        turn(rig, "clavicle_l", (0, 1, 0), .012*pulse(phase, .55, .28))
        return
    raise ValueError("Unimplemented authored clip: " + clip)
