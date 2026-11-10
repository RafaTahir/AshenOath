"""Author small, supported work props in Blender; never modify retained inputs.

Coordinates in the contract and receipts are Godot metres. Review cameras and
the neutral support plane are created only after the source/carrier are saved.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from living_cast_stage2_profiles import PROFILES

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "models/living_cast_stage2_20261107/props"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def xyz(point):
    return Vector((point[0], -point[2], point[1]))


def material(name, color, roughness=.85):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    return mat


def box(name, centre, size, mat, parent):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(centre))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


def mesh(name, points, faces, mat, parent):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(p) for p in points], [], faces)
    data.materials.append(mat)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    return obj


def retain_obj(game, filename, name, centre, size, mat, parent, provenance, lay_cloth=False):
    source = game / "assets_external/environment/props" / filename
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=str(source), forward_axis="NEGATIVE_Z", up_axis="Y")
    objects = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    if not objects:
        raise ValueError("Retained prop has no mesh: " + str(source))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    points = [Vector((v.co.x, -v.co.z, v.co.y)) if lay_cloth else v.co.copy()
              for v in obj.data.vertices]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    dimensions = Vector((size[0], size[2], size[1]))
    if min(high-low) < 1e-7:
        raise ValueError("Cannot normalize a flat retained prop: " + filename)
    for vertex, point in zip(obj.data.vertices, points):
        vertex.co = Vector(tuple((point[i]-low[i])/(high[i]-low[i])*dimensions[i]
                                 for i in range(3))) - dimensions/2
        if lay_cloth:
            # Preserve the retained outer fitting box while replacing the
            # ruler-straight long hem with a small inward linen irregularity.
            u = vertex.co.x/dimensions.x+.5
            edge = (abs(vertex.co.y)/(dimensions.y*.5))**3
            inset = .004*(.5+.5*math.sin(u*math.pi*5))*math.sin(math.pi*u)**2*edge
            vertex.co.y -= math.copysign(inset, vertex.co.y)
            vertex.co.z -= .0015*math.sin(math.pi*u)**2*edge*(vertex.co.z/dimensions.z+.5)
    obj.location = xyz(centre)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.material_index = 0
    obj.parent = parent
    provenance.append({"resource": "res://assets_external/environment/props/" + filename,
                       "source": str(source), "sha256": sha(source), "retained_vertices": len(obj.data.vertices),
                       "change": "Retained silhouette normalized to supported workstation dimensions; authored palette."})
    return obj


def ribbon(name, points, width, thickness, mat, parent):
    vertices, faces = [], []
    for p in points:
        vertices.extend([(p[0], p[1]+dy, p[2]+dz) for dy, dz in
                         [(-thickness/2, -width/2), (-thickness/2, width/2),
                          (thickness/2, width/2), (thickness/2, -width/2)]])
    for index in range(len(points)-1):
        for side in range(4):
            faces.append((index*4+side, index*4+(side+1)%4,
                          (index+1)*4+(side+1)%4, (index+1)*4+side))
    faces.extend([(3, 2, 1, 0), tuple((len(points)-1)*4+i for i in range(4))])
    return mesh(name, vertices, faces, mat, parent)


def flattened_dough(mat, parent):
    # A flat kneading plateau gives both measured palm markers real material
    # at exactly .020m, while the irregular outer lip remains visibly dough.
    points, faces = [], []
    count = 24
    for radius, height in ((1.0, .009), (.82, .020)):
        for i in range(count):
            angle = math.tau*i/count
            wobble = 1 + .035*math.sin(angle*3)
            points.append((math.cos(angle)*.22*radius*wobble, height,
                           -.025+math.sin(angle)*.06*radius))
    for i in range(count):
        faces.append((i, (i+1)%count, count+(i+1)%count, count+i))
    faces.extend([tuple(range(count-1, -1, -1)), tuple(range(count, count*2))])
    return mesh("WorkContactPart", points, faces, mat, parent)


def folded_linen(mat, parent):
    points, faces = [], []
    xs = sorted(set([-.20+.40*i/12 for i in range(13)] + [-.12, .12]))
    zs = sorted(set([-.14+.17*i/15 for i in range(16)] + [0.0]))
    columns, rows = len(xs), len(zs)
    for z in zs:
        for x in xs:
            # The smoothing ridge at z=0 is exactly the .020m palm surface;
            # shallow cloth wrinkles taper away from that contact line.
            y = .012 + .008*math.exp(-(z/.022)**2)
            y += .0028*math.sin((x+.20)*math.pi*5)*math.sin(math.pi*z/.14)**2
            away_from_contact = 1-math.exp(-(z/.012)**2)
            y += .004*math.exp(-((x-.15)/.045)**2-((z+.115)/.025)**2)*away_from_contact
            # A broken corner crease and gently uneven long edges make the
            # layer read as folded cloth; exact x=±.12,z=0 hand ridges stay put.
            edge = (abs(x)/.20)**4
            fitted_x = x-math.copysign(.003*(.5+.5*math.sin(z*63))*edge*away_from_contact, x)
            fitted_z = z
            if z < -.115:
                fitted_z += .003*(.5+.5*math.sin((x+.2)*37))*((-.115-z)/.025)**2
            points.append((fitted_x, y, fitted_z))
    for row in range(rows-1):
        for column in range(columns-1):
            a = row*columns+column
            faces.append((a, a+1, a+columns+1, a+columns))
    obj = mesh("WorkContactPart", points, faces, mat, parent)
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new("ActualFoldedLinenThickness", "SOLIDIFY")
    modifier.thickness = .0012
    modifier.offset = -1
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_task_press(part, identity):
    """Authored material response with fixed hand-contact patches, no new owner."""
    if identity not in ('nessa', 'elna'):
        return {}
    # Source geometry is already rebased around the supported part pivot.
    # Leave both z=0 hand ridges fixed throughout the shape interpolation.
    if identity == 'elna':
        for vertex in part.data.vertices:
            point = vertex.co + part.location
            godot_z = -point.y
            fold = max(0.0, min(1.0, (-godot_z-.025)/.115))
            vertex.co.z += .028*math.sin(fold*math.pi/2)**2
    part.shape_key_add(name='Basis')
    press = part.shape_key_add(name='TaskPress')
    for vertex in press.data:
        point = vertex.co + part.location
        if identity == 'nessa':
            point.x *= 1.07
            point.y = .025 + (point.y-.025)*1.10
            if point.z < .015:
                point.z = max(.008, point.z-.001)
        else:
            godot_z = -point.y
            fold = max(0.0, min(1.0, (-godot_z-.025)/.115))
            amount = math.sin(fold*math.pi/2)**2
            point.z -= .025*amount
            point.y -= .009*amount
        vertex.co = point-part.location
    press.value = 0.0
    states = {}
    for name in ('Basis','TaskPress'):
        points = [v.co+part.location for v in part.data.shape_keys.key_blocks[name].data]
        states[name] = {'min_godot':[min(p.x for p in points),min(p.z for p in points),-max(p.y for p in points)],
                        'max_godot':[max(p.x for p in points),max(p.z for p in points),-min(p.y for p in points)]}
    return {'name':'TaskPress','neutral_weight':0.0,'contact_weight':1.0,
            'purpose':'Spread supported dough around fixed palm patches' if identity=='nessa' else 'Settle the loose folded edge around the fixed smoothing ridge',
            'geometry_bounds':states,'grip_patch_height_preserved':True}


def snapshot_recipe():
    files = [Path(__file__), Path(__file__).with_name('living_cast_stage2_profiles.py')]
    digests = {path.name:sha(path) for path in files}
    identity = hashlib.sha256(json.dumps(digests, sort_keys=True).encode()).hexdigest()
    folder = OUT/'recipes'/identity[:16]
    folder.mkdir(parents=True, exist_ok=True)
    for path in files:
        target = folder/path.name
        if target.exists() and sha(target) != digests[path.name]:
            raise ValueError('Prop recipe snapshot collision')
        if not target.exists():
            target.write_bytes(path.read_bytes())
    return {'sha256':identity, 'files':[{'name':name, 'path':str((folder/name).relative_to(ROOT)),
            'sha256':digest} for name,digest in digests.items()]}


def marker(name, point, parent):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = xyz(point)
    obj.parent = parent
    return obj


def build(identity, game, render):
    asset, profile = next((key, value) for key, value in PROFILES.items() if value["identity"] == identity)
    if not profile["contact_required"]:
        raise ValueError("Senn's survey sequence has no invented contact prop")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    root = bpy.data.objects.new("Station_" + identity.title(), None)
    bpy.context.scene.collection.objects.link(root)
    mats = {
        "wood": material("RetainedWeatheredTimber", (.18, .105, .055)),
        "paper": material("WarmWornParchment", (.48, .40, .27)),
        "ink": material("FadedGraphite", (.055, .047, .035)),
        "cloth": material("ElnaRepairedLinen", (.19, .12, .18)),
        "leather": material("WeatheredFreightLeather", (.09, .052, .028)),
        "soil": material("SeedBedEarth", (.075, .044, .025)),
        "green": material("SeedlingSage", (.16, .23, .075)),
        "dough": material("UnbakedOatDough", (.47, .36, .20)),
        "wax": material("DispatchOxbloodWax", (.24, .035, .028), .65),
    }
    sources = []
    if identity == "nessa":
        box("SupportedKneadingBoard", (0, .004, -.10), (.54, .008, .28), mats["wood"], root)
        part = flattened_dough(mats["dough"], root)
        for x in (-.23, .23):
            box("BoardEndGrain", (x, .0048, -.10), (.006, .002, .26), mats["ink"], root)
    elif identity == "elna":
        retain_obj(game, "Banner_1_Cloth.obj", "RetainedFoldedCloth", (0, .007, -.085),
                   (.48, .014, .24), mats["cloth"], root, sources, lay_cloth=True)
        part = folded_linen(mats["cloth"], root)
    elif identity == "toma":
        retain_obj(game, "Crate_Wooden.obj", "RetainedSeedTray", (0, .006, -.10),
                   (.50, .012, .28), mats["wood"], root, sources)
        part = box("WorkContactPart", (0, .018, -.085), (.43, .004, .23), mats["soil"], root)
        for x in (-.235, .235):
            box("TraySide", (x, .023, -.10), (.022, .034, .28), mats["wood"], root)
        box("TrayBack", (0, .023, -.23), (.49, .034, .022), mats["wood"], root)
        for x in (-.15, -.05, .05, .15):
            mesh("SeedlingLeaf", [(x, .02, -.14), (x-.018, .047, -.158), (x, .058, -.165),
                                  (x+.018, .043, -.148)], [(0, 1, 2, 3), (3, 2, 1, 0)], mats["green"], root)
    elif identity == "nera":
        retain_obj(game, "Crate_Wooden.obj", "RetainedReliefCrate", (0, .0375, -.08),
                   (.50, .075, .24), mats["wood"], root, sources)
        part = ribbon("WorkContactPart", [(-.24, .055, 0), (-.22, .098, 0),
                      (-.12, .098, 0), (0, .098, 0), (.12, .098, 0), (.22, .098, 0), (.24, .055, 0)],
                      .024, .004, mats["leather"], root)
        box("AttachedBuckle", (0, .102, 0), (.036, .006, .032), mats["ink"], root)
    elif identity == "vale":
        retain_obj(game, "Book_7.obj", "RetainedLedgerBinding", (0, .008, -.09),
                   (.46, .016, .25), mats["leather"], root, sources)
        part = box("WorkContactPart", (0, .018, -.085), (.42, .004, .22), mats["paper"], root)
        box("LedgerFold", (0, .0202, -.085), (.003, .0004, .21), mats["ink"], root)
        for x in (-.11, .11):
            for z in (-.16, -.13, -.10, -.07, -.04):
                box("LedgerInkLine", (x, .0203, z), (.15, .0004, .0015), mats["ink"], part)
    elif identity == "merrow":
        box("ReceiptBacking", (0, .006, -.10), (.49, .012, .26), mats["wood"], root)
        part = box("WorkContactPart", (0, .018, -.085), (.44, .004, .22), mats["paper"], root)
        for x in (-.12, .12):
            for z in (-.15, -.12, -.09, -.06):
                box("ReceiptInkLine", (x, .0203, z), (.15, .0004, .0015), mats["ink"], part)
        box("ReceiptDivide", (0, .0203, -.085), (.002, .0005, .22), mats["wood"], part)
    elif identity == "edric":
        retain_obj(game, "Scroll_1.obj", "RetainedDispatchRoll", (0, .018, -.17),
                   (.40, .036, .08), mats["paper"], root, sources)
        part = box("WorkContactPart", (0, .018, -.06), (.41, .004, .16), mats["paper"], root)
        # A shallow wax wafer occupies the actual right-hand contact point.
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=.026, depth=.002, location=xyz((.12, .019, 0)))
        seal = bpy.context.object
        seal.name = "DispatchSeal"
        seal.data.materials.append(mats["wax"])
        seal.parent = part
        for z in (-.11, -.085, -.06):
            box("DispatchInkLine", (-.03, .0203, z), (.26, .0004, .0015), mats["ink"], part)
    else:
        raise ValueError(identity)
    # Every generated child initially used root coordinates. Preserve its
    # current world transform while assigning an actual contact-part parent.
    for obj in list(bpy.context.scene.objects):
        if obj.parent == part:
            obj.location -= part.location
    height = .10 if identity == "nera" else .02
    grips = {"GripLeft": [-.12, height, 0], "GripRight": [.12, height, 0]}
    for name, point in grips.items():
        marker(name, point, root)
    root["stationary_supported_prop"] = True
    root["actor_identity"] = identity
    part["contact_response"] = profile["contact_response"]
    part["contact_amount"] = profile["contact_amount"]
    # Put the effect pivot on the contact plane: compression does not cause a
    # supported prop to rise from its table or translate as if it were held.
    pivot = xyz((0, 0, -.06))
    delta = pivot - part.location
    for vertex in part.data.vertices:
        vertex.co -= delta
    for child in part.children:
        child.location -= delta
    part.location = pivot
    contact_shape = add_task_press(part, identity)
    if contact_shape:
        part['contact_response'] = 'morph'
        part['contact_shape'] = 'TaskPress'
        part['contact_neutral_weight'] = 0.0
        part['contact_target_weight'] = 1.0
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    triangles = sum(len(p.vertices)-2 for obj in meshes for p in obj.data.polygons)
    if triangles > 6000:
        raise ValueError(identity + " prop exceeded 6000 triangles")
    OUT.mkdir(parents=True, exist_ok=True)
    # Retained OBJ trim materials are replaced above. Remove their unused
    # nodes/images rather than retaining broken, unused external texture paths.
    for unused in list(bpy.data.materials):
        if unused.users == 0:
            bpy.data.materials.remove(unused)
    for unused in list(bpy.data.images):
        if unused.users == 0:
            bpy.data.images.remove(unused)
    for image in bpy.data.images:
        if image.source == "FILE" and not image.packed_file:
            image.pack()
    blend = OUT / ("station_" + identity + ".blend")
    carrier = OUT / ("station_" + identity + ".glb")
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(carrier), export_format="GLB", use_selection=True,
                              export_animations=False, export_yup=True, export_extras=True)
    receipt = {
        "schema_version": 1, "asset": asset, "identity": identity, "sources": sources,
        "authoring_tool_sha256": sha(__file__), "blend_sha256": sha(blend), "carrier_sha256": sha(carrier),
        "recipe_snapshot": snapshot_recipe(),
        "blender_version": bpy.app.version_string, "triangles": triangles,
        "grips_godot": grips, "surface_height": height,
        "prop_root_actor_relative_godot": [0, 1, -.40],
        "support_near_limit_godot_z": .04, "contact_part": "WorkContactPart",
        "contact_response": 'morph' if contact_shape else profile["contact_response"], "contact_amount": profile["contact_amount"],
        "contact_shape": contact_shape,
        "runtime_resource": profile["runtime_prop"], "source_geometry_authored": True,
        "geometry_contact_verified": False, "native_grips_verified": False, "user_accepted": False,
        "notes": ["Actual supported contact geometry; no pickup or carried transition is claimed.",
                  "New work surfaces/details supplement the retained source shapes where listed."]}
    (OUT / ("station_" + identity + "_authoring.json")).write_text(json.dumps(receipt, indent=2) + "\n")
    if render:
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.render.resolution_x = 720
        scene.render.resolution_y = 600
        scene.render.resolution_percentage = 100
        scene.display.shading.color_type = "MATERIAL"
        scene.display.shading.show_cavity = True
        if scene.world is None:
            scene.world = bpy.data.worlds.new("ReviewWorld")
        scene.world.color = (.11, .11, .11)
        bpy.ops.object.camera_add(location=(.6, -.8, .65))
        camera = bpy.context.object
        camera.rotation_euler = (Vector((0, .08, .03))-camera.location).to_track_quat("-Z", "Y").to_euler()
        camera.data.type = "ORTHO"
        camera.data.ortho_scale = .72
        scene.camera = camera
        scene.render.filepath = str(OUT / ("station_" + identity + "_review.png"))
        bpy.ops.render.render(write_still=True)
        if contact_shape:
            part.data.shape_keys.key_blocks['TaskPress'].value = 1.0
            scene.render.filepath = str(OUT / ("station_" + identity + "_pressed_review.png"))
            bpy.ops.render.render(write_still=True)
            part.data.shape_keys.key_blocks['TaskPress'].value = 0.0
    print("STAGE2_PROP_AUTHORED", identity, triangles, flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--identity", required=True, choices=[p["identity"] for p in PROFILES.values() if p["contact_required"]])
    parser.add_argument("--source-game", required=True, type=Path)
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--art-root", type=Path, default=ROOT)
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    ROOT = args.art_root
    OUT = ROOT/'models/living_cast_stage2_20261107/props'
    build(args.identity, args.source_game, args.render)
