"""Author C01's grounded-stylized revision from retained editable geometry."""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / 'design_pack_v1/tools'))
import build_anwen as shared

bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'models/C01_anwen_retained_v043.blend'))
rig = bpy.data.objects['C01_Anwen_Rig']
head = bpy.data.objects['Anwen_MatureFace_Neck']
for bone in rig.pose.bones:
    bone.rotation_mode = 'QUATERNION'
    bone.rotation_quaternion = (1, 0, 0, 0)

# Keep earlier sources on disk; only this new source discards obsolete groom parts.
root = bpy.data.objects['Anwen_Hair_v004_FittedRoots']
for obj in list(bpy.data.objects):
    if obj != root and obj.name.startswith('Anwen_Hair_'):
        bpy.data.objects.remove(obj, do_unlink=True)
    elif obj.name.startswith('Anwen_Brow_v019_'):
        bpy.data.objects.remove(obj, do_unlink=True)

hair = shared.material('C01_Sculpted_Ash_Hair', (.145, .132, .111), .84)
root.data.materials.clear()
root.data.materials.append(hair)
for polygon in root.data.polygons:
    polygon.use_smooth = True
for v in root.data.vertices:
    p = v.co
    # Break the straight helmet rim with an asymmetric side part and temples.
    if p.y < -.025:
        t = max(0, min(1, (1.765 - p.z) / .10))
        p.z += .009 * t * math.exp(-((p.x + .014) / .037) ** 2)
        p.y += .003 * t
    if p.z > 1.735:
        p.z -= .006 * math.exp(-((p.x+.014)/.009)**2)

def lock(name, centres, widths, depth, material=hair):
    verts, faces, uv = [], [], []
    sides = 8
    for i, xyz in enumerate(centres):
        p = Vector(xyz)
        tangent = Vector(centres[min(i+1, len(centres)-1)]) - Vector(centres[max(i-1, 0)])
        tangent.normalize()
        outward = Vector((p.x, p.y, (p.z - 1.68) * .8)).normalized()
        lateral = tangent.cross(outward).normalized()
        normal = lateral.cross(tangent).normalized()
        if normal.dot(outward) < 0:
            normal.negate()
        for j in range(sides):
            angle = math.tau * j / sides
            verts.append(tuple(p + lateral * widths[i] * math.cos(angle)
                               + normal * depth * math.sin(angle)))
            uv.append((j / sides, i / max(1, len(centres)-1)))
            if i:
                a = i*sides+j
                faces.append((a, i*sides+(j+1)%sides,
                              (i-1)*sides+(j+1)%sides, a-sides))
    faces.extend([tuple(reversed(range(sides))),
                  tuple((len(centres)-1)*sides+j for j in range(sides))])
    obj = shared.mesh_object(name, verts, faces, material, uv)
    shared.bind(obj, rig, lambda p: {'Head': 1})
    return obj

# Broad, closed locks are intentional sculpted forms, not dense hair cards.
for side in (-1, 1):
    for index in range(6):
        f = index / 5
        centres, widths = [], []
        for step in range(17):
            t = step / 16
            a = -.95 + 2.65*t
            x = side * (.012 + .066*f) * (1 - .58*t) + .004*math.sin(t*math.pi)
            y = .006 + .089*math.sin(a)
            z = 1.687 + .112*math.cos(a) - .016*f - .026*t*t
            centres.append((x, y, z))
            widths.append((.008 + .004*f) * (.35 + .65*math.sin(math.pi*(.10+.85*t))))
        lock(f'Anwen_Hair_Stylized_Sweep_{side}_{index}', centres, widths, .0045)

# An asymmetric low coiled bun with an identifiable pinned silhouette.
for band in range(3):
    centres, widths = [], []
    for step in range(33):
        t = step/32
        a = math.tau*t + band*.75
        r = .031 - band*.006
        centres.append((-.005 + r*math.cos(a), .091 + .012*math.sin(a)*math.sin(a),
                        1.664 + r*.83*math.sin(a) + band*.004))
        widths.append(.008 * (.85 + .15*math.cos(a*3)))
    lock(f'Anwen_Hair_Stylized_LowCoil_{band}', centres, widths, .006)
for side in (-1, 1):
    lock(f'Anwen_Hair_Stylized_Temple_{side}',
         [(side*.065, -.064, 1.741), (side*.080, -.040, 1.725),
          (side*.082, -.013, 1.696), (side*.066, .025, 1.677),
          (side*.031, .083, 1.663)], [.009, .012, .012, .009, .003], .004)

# Retain the garment's topology and cloth surface, reshape its broad cape
# into a narrower, asymmetrically wrapped shoulder garment.
cape = bpy.data.objects['Anwen_v034_cape']
for v in cape.data.vertices:
    p = v.co
    lower = max(0, min(1, (1.47-p.z)/.205))
    p.x *= 1 - .24*lower
    front = max(0, min(1, (-p.y+.015)/.15))
    p.z += lower * (.052*(p.x/.27) - .017*front)
    p.y *= 1 + .06*front
cape.name = 'Anwen_Diagonal_Wrapped_Shawl'
cape['authored_change'] = 'Fitted asymmetric lower edge; retained licensed garment topology'

cloth = bpy.data.materials['Anwen_Ash_Wool_Shawl']
# A folded inner lap continues the wrap around the neck rather than a new hood.
verts, faces, uv = [], [], []
for row in range(5):
    v = row/4
    for col in range(65):
        a = math.tau*col/64
        front = max(0, math.cos(a))
        z = 1.489 - v*(.055 + .032*front) + .009*math.sin(a+.5)*v
        rx = .076 + .037*v
        ry = .068 + .047*v
        verts.append((rx*math.sin(a), -.006-ry*math.cos(a), z))
        uv.append((col/64, v))
        if row and col:
            k = row*65+col
            faces.append((k-66,k-65,k,k-1))
lap = shared.mesh_object('Anwen_Diagonal_Wrap_InnerLap', verts, faces, cloth, uv)
shared.bind(lap, rig, lambda p: {'spine_03': .75, 'neck_01': .25})
solid = lap.modifiers.new('Folded wool thickness', 'SOLIDIFY')
solid.thickness = .003

# Broad age landmarks; no painted wrinkles or wholesale replacement face.
key = head.shape_key_add(name='C01_GroundedStylized_MaturePlanes', from_mix=False)
key.value = 1
for point, basis in zip(key.data, head.data.shape_keys.key_blocks[0].data):
    x, y, z = basis.co
    front = max(0, min(1, (-y-.015)/.065))
    cheek = math.exp(-((abs(x)-.048)/.025)**2 - ((z-1.632)/.023)**2)*front
    jaw = math.exp(-((z-1.582)/.024)**2)*front
    eye = math.exp(-((abs(x)-.030)/.022)**2 - ((z-1.655)/.009)**2)*front
    point.co.x += math.copysign(.0025*cheek + .0015*jaw, x)
    point.co.y += .0013*eye

# A relaxed presentation pose; the exporter restores the original rest frame.
for side, sign in (('l', 1), ('r', -1)):
    bone = rig.pose.bones['upperarm_'+side]
    target = rig.data.bones[bone.name].matrix_local.to_3x3().inverted() @ Vector((sign*.40,0,-.9165))
    bone.rotation_quaternion = Vector((0,1,0)).rotation_difference(target.normalized())
bpy.context.view_layer.update()
rig['art_status'] = 'GROUNDED_STYLIZED_CANDIDATE_AWAITING_USER'
rig['production_policy'] = 'Best-effort complete roster; no per-asset numerical approval lock'
bpy.ops.file.pack_all()
path = ROOT/'models/C01_anwen_stylized_v044.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 6
scene.render.resolution_x = 480
scene.render.resolution_y = 600
scene.render.resolution_percentage = 100
out = ROOT/'evidence/stylized/C01'
out.mkdir(parents=True, exist_ok=True)
camera = scene.camera
camera.data.type = 'ORTHO'
for name, position, target, scale in [
    ('front',(0,-4,1.3),(0,0,.94),2.12),
    ('side',(4,0,1.3),(0,0,.94),2.12),
    ('rear',(0,4,1.3),(0,0,.94),2.12),
    ('quarter',(2,-4,1.5),(0,0,.94),2.12),
    ('face',(.35,-2,1.72),(0,0,1.67),.38),
]:
    camera.location = position
    camera.rotation_euler = (Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale = scale
    scene.render.filepath = str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
print('C01_STYLIZED_AUTHORED', str(path), flush=True)
