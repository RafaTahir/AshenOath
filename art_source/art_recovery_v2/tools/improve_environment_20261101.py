"""Individually refine retained runtime scenery without changing its fitting box.

Run in background Blender 5.2. Originals and MTL bytes are preserved in evidence;
the authored per-asset mesh/normal changes are reproducible from that baseline.
This deliberately leaves atlas images, surface order and collisions untouched.
"""
import bpy
import bmesh
import json
import math
import hashlib
import shutil
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT.parents[1] / 'outputs/AshenOathTheRoadBetweenCrowns'
OUT = ROOT / 'evidence/refinement_20261101/environment'
MODELS = ROOT / 'models/refinement_20261101/environment'
OUT.mkdir(parents=True, exist_ok=True)
MODELS.mkdir(parents=True, exist_ok=True)

# Widths are proportions of each asset's own shortest non-zero dimension.
# Thin roof/facade sheets need a much smaller lip than solid furniture.
PROFILES = {
    'Anvil': (.012, 36, 'Soft forge-worn horn, heel and working-face arrises; broad planes retain weight.'),
    'Barrel': (.010, 42, 'Hoop and stave-rim edge catches; barrel facets retain their coopered construction.'),
    'Bench': (.017, 35, 'Worn seat edges and relieved trestle corners.'),
    'Bookcase_2': (.010, 42, 'Shelf lips and upright frame edges separate from book spines.'),
    'Chair_1': (.016, 35, 'Seat, back rail and leg arrises gain restrained hand-worn corners.'),
    'Crate_Metal': (.007, 42, 'Packing slats and reinforcing iron corners catch light separately.'),
    'Lantern_Wall': (.006, 48, 'Forged frame and cap edges read around retained glass panels.'),
    'Stall_Cart_Empty': (.009, 42, 'Cart bed, wheel joinery and stall frame corners retain atlas detail.'),
    'Table_Large': (.015, 35, 'Tabletop and leg corners soften while the supporting footprint stays fixed.'),
    'Torch_Metal': (.006, 48, 'Cup and iron-bracket edges distinguish the torch fitting.'),
    'WeaponStand': (.010, 42, 'Rack, foot and arm edges clarify the stored-equipment silhouette.'),
    'Balcony_Cross_Straight': (.016, 35, 'Cross-braced shrine timber has relieved beam ends and junction edges.'),
    'Door_1_Flat': (.006, 42, 'Door-leaf and surround arrises retain existing hinged surface ownership.'),
    'Prop_Chimney': (.010, 38, 'Chimney cap and exposed masonry corners catch grazing light.'),
    'Prop_WoodenFence_Single': (.022, 35, 'Fence posts and rails receive visibly worked timber edges.'),
    'Roof_2x4_RoundTile': (.003, 48, 'Roof eave and hard tile ends gain subtle edge separation.'),
    'Roof_RoundTiles_8x10': (.003, 48, 'Large roof eave and hard tile ends retain round tile profiles.'),
    'Wall_Arch': (.012, 38, 'Arch opening, pier arrises and masonry returns gain depth at grazing light.'),
    'Wall_Plaster_Door_Flat': (.006, 40, 'Doorway returns and plaster/timber corners gain a narrow reveal.'),
    'Wall_Plaster_Straight_Base': (.007, 40, 'Plaster base and supporting timber arrises gain a narrow reveal.'),
    'Wall_Plaster_Window_Wide_Flat': (.006, 40, 'Window reveal and supporting timber corners gain readable thickness.'),
    'Wall_UnevenBrick_Straight': (.018, 36, 'Exposed ruin/castle masonry edges soften without rounding whole stones.'),
    'Rock_Medium_1': (.010, 42, 'Restrained chipped arrises keep the broad rock facets.'),
    'RockPath_Round_Small_1': (.004, 48, 'Trail-stone edge transitions retain the existing walkable height.'),
    'TwistedTree_2': (0, 65, 'Angle-aware trunk normals join bark around bends; leaf cards stay flat.'),
    'TwistedTree_4': (0, 65, 'Angle-aware trunk normals join bark around bends; leaf cards stay flat.'),
    'CommonTree_5': (0, 60, 'Trunk branch normals blend within limbs; leaf cards stay flat.'),
    'Bush_Common': (0, 50, 'Gently cupped foliage cards catch light across leaf clusters; retain two-sided atlas UVs.'),
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def bounds(objects):
    points = [o.matrix_world @ Vector(v) for o in objects for v in o.bound_box]
    return [[min(p[a] for p in points) for a in range(3)],
            [max(p[a] for p in points) for a in range(3)]]

def triangles(objects):
    return sum(len(p.vertices)-2 for o in objects for p in o.data.polygons)

def views(objects, folder):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = 'BOTH'
    scene.display.shading.curvature_ridge_factor = 1.15
    scene.display.shading.curvature_valley_factor = 0.85
    scene.display.shading.background_type = 'WORLD'
    if scene.world is None:
        scene.world = bpy.data.worlds.new('InspectionWorld')
    scene.world.color = (.055, .065, .075)
    scene.render.resolution_x, scene.render.resolution_y = 480, 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    low, high = [Vector(x) for x in bounds(objects)]
    center = (low+high)*.5
    extent = max(high-low)
    camera_data = bpy.data.cameras.new('InspectionCamera')
    camera = bpy.data.objects.new('InspectionCamera', camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = extent * 1.48
    for name, angle in [('front',0), ('quarter',35), ('side',90), ('rear',180)]:
        a = math.radians(angle)
        camera.location = center + Vector((extent*2*math.sin(a), -extent*2*math.cos(a), extent*.72))
        camera.rotation_euler = (center-camera.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(folder / (name+'.png'))
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)

catalog = json.loads((GAME/'curated_runtime_assets.json').read_text())
roles = catalog['roles']['environment']
paths = sorted({v['path'] for v in roles.values()})
all_paths = list(paths)
selected = set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
if selected:
    paths = [p for p in paths if Path(p).stem in selected]
records = json.loads((OUT/'checklist.json').read_text())['assets'] if selected else []
for resource in paths:
    path = GAME / resource.removeprefix('res://')
    name = path.stem
    width_ratio, angle, change = PROFILES[name]
    folder = OUT/name
    folder.mkdir(exist_ok=True)
    baseline = folder / path.name
    if not baseline.exists():
        shutil.copy2(path, baseline)
    source_sha = sha(baseline)
    mtllibs = [x for x in baseline.read_text().splitlines() if x.startswith('mtllib ')]
    for line in mtllibs:
        for file in line.split()[1:]:
            original = path.parent/file
            if original.exists() and not (folder/file).exists():
                shutil.copy2(original, folder/file)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    # Import from the original directory so retained relative texture URIs resolve.
    # Restore the preserved original only for this import on a repeat run.
    current = path.read_bytes()
    path.write_bytes(baseline.read_bytes())
    try:
        bpy.ops.wm.obj_import(filepath=str(path), forward_axis='NEGATIVE_Z', up_axis='Y')
    finally:
        path.write_bytes(current)
    objects = [o for o in bpy.context.scene.objects if o.type=='MESH']
    before_bounds = bounds(objects)
    before_triangles = triangles(objects)
    before_slots = {o.name:[m.name if m else None for m in o.data.materials] for o in objects}
    for obj in objects:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        dimensions = [v for v in obj.dimensions if v > .0001]
        if name == 'Bush_Common':
            # The atlas is carried by separate leaf quads. A low centre fold
            # gives these cards a leaf-like light response without replacing
            # the authored foliage, expanding its silhouette or adding alpha.
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            bmesh.ops.poke(bm, faces=[f for f in bm.faces if len(f.verts)==4],
                           offset=.035, use_relative_offset=True, center_mode='MEAN_WEIGHTED')
            bm.to_mesh(obj.data)
            bm.free()
            obj.data.update()
        if width_ratio and dimensions:
            width = min(dimensions)*width_ratio
            bevel = obj.modifiers.new('Authored edge wear - '+name, 'BEVEL')
            bevel.width = width
            bevel.segments = 1
            bevel.limit_method = 'ANGLE'
            bevel.angle_limit = math.radians(angle)
            bevel.use_clamp_overlap = True
            bevel.harden_normals = True
            bevel.affect = 'EDGES'
            bpy.ops.object.modifier_apply(modifier=bevel.name)
        if name != 'Bush_Common':
            obj.data.set_sharp_from_angle(angle=math.radians(angle))
            for polygon in obj.data.polygons:
                polygon.use_smooth = True
            normal = obj.modifiers.new('Corner-weighted supporting planes', 'WEIGHTED_NORMAL')
            normal.keep_sharp = True
            normal.weight = 50
            bpy.ops.object.modifier_apply(modifier=normal.name)
        obj['refinement_source_sha256'] = source_sha
        obj['refinement_20261101'] = change
        obj.select_set(False)
    bpy.context.view_layer.update()
    after_bounds = bounds(objects)
    # Beveling an irregular rock can clip a lone extreme vertex. Restore only
    # the tiny AABB change so all existing fitted placement remains identical.
    before_min, before_max = [Vector(v) for v in before_bounds]
    after_min, after_max = [Vector(v) for v in after_bounds]
    if width_ratio:
        factor = Vector(tuple((before_max[a]-before_min[a]) / max(after_max[a]-after_min[a], 1e-9) for a in range(3)))
        for obj in objects:
            inverse = obj.matrix_world.inverted()
            for vertex in obj.data.vertices:
                vertex.co = inverse @ ((obj.matrix_world @ vertex.co-after_min)*factor+before_min)
            obj.data.update()
        bpy.context.view_layer.update()
        after_bounds = bounds(objects)
    drift = max(abs(before_bounds[i][j]-after_bounds[i][j]) for i in range(2) for j in range(3))
    if drift > .00002:
        raise RuntimeError(name+' fitting bounds changed: '+str(drift))
    bpy.ops.wm.save_as_mainfile(filepath=str(MODELS/(name+'.blend')), compress=True)
    for o in objects:
        o.select_set(True)
    temporary = folder/(name+'_refined.obj')
    bpy.ops.wm.obj_export(filepath=str(temporary), export_selected_objects=True,
                          forward_axis='NEGATIVE_Z', up_axis='Y', export_materials=True,
                          export_uv=True, export_normals=True, export_triangulated_mesh=True,
                          apply_modifiers=True)
    text = temporary.read_text()
    # Keep the original material library bytes and path, not Blender's rewritten MTL.
    text = '\n'.join(mtllibs)+'\n'+'\n'.join(x for x in text.splitlines() if not x.startswith('mtllib '))+'\n'
    def slot_order(data):
        return list(dict.fromkeys(x for x in data.splitlines() if x.startswith('usemtl ')))
    if slot_order(text) != slot_order(baseline.read_text()):
        raise RuntimeError(name+' material ownership/order changed: '+str(slot_order(text)))
    path.write_text(text, encoding='utf-8', newline='\n')
    record = {'resource':resource, 'roles':[k for k,v in roles.items() if v['path']==resource],
              'source_baseline':str(baseline), 'source_sha256':source_sha,
              'editable_source':str(MODELS/(name+'.blend')), 'runtime_sha256':sha(path),
              'change':change, 'before_triangles':before_triangles,
              'after_triangles':triangles(objects), 'bounds_drift':drift,
              'material_slots':before_slots, 'texture_pixels_changed':False,
              'collision_changed':False, 'user_accepted':False}
    views(objects, folder)
    (folder/'candidate.json').write_text(json.dumps(record,indent=2)+'\n')
    records = [r for r in records if r['resource'] != resource] + [record]
    records.sort(key=lambda r:r['resource'])
    (OUT/'checklist.json').write_text(json.dumps({'assets':records, 'complete':len(records)==len(all_paths)},indent=2)+'\n')
    print('REFINED',name,before_triangles,'->',record['after_triangles'],flush=True)
print('ENVIRONMENT COMPLETE',len(records),'assets',len(roles),'roles',flush=True)
