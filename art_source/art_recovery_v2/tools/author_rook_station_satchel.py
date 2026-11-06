"""Retain Bag.obj as a supported supplies satchel with an attached cinch tie."""
import hashlib
import json
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
SOURCE = REPO / 'outputs/AshenOathTheRoadBetweenCrowns/assets_external/environment/props/Bag.obj'
OUT = ROOT / 'models/living_cast_20261107/props'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def material(name, color):
    value=bpy.data.materials.new(name);value.diffuse_color=(*color,1)
    value.use_nodes=True
    shader=value.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=.88
    return value


def ribbon(name, points, mat, width=.012, depth=.004):
    vertices=[];faces=[]
    for p in points:
        # The retained strip lies across the satchel mouth; a narrow rectangular
        # cross-section reads as leather rather than a disconnected rope.
        vertices.extend([(p[0]+x,p[1],p[2]+z) for x,z in
                         [(-width/2,-depth/2),(width/2,-depth/2),(width/2,depth/2),(-width/2,depth/2)]])
    for i in range(len(points)-1):
        for k in range(4):
            faces.append((i*4+k,i*4+(k+1)%4,(i+1)*4+(k+1)%4,(i+1)*4+k))
    faces.extend([(3,2,1,0),tuple((len(points)-1)*4+k for k in range(4))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.materials.append(mat)
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
    return obj


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=str(SOURCE),forward_axis='NEGATIVE_Z',up_axis='Y')
    bodies=[o for o in bpy.context.scene.objects if o.type=='MESH']
    if not bodies:
        raise ValueError('Retained Bag.obj has no geometry')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bodies:obj.select_set(True)
    bpy.context.view_layer.objects.active=bodies[0]
    if len(bodies)>1:bpy.ops.object.join()
    body=bpy.context.object;body.name='SatchelBody'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    # Turn the source's width across the work table, then normalize its retained
    # silhouette to the approved .18 depth / .32 width / .16 body height.
    points=[Vector((-v.co.y,v.co.x,v.co.z)) for v in body.data.vertices]
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    span=high-low;size=Vector((.18,.32,.16))
    for vertex,p in zip(body.data.vertices,points):
        vertex.co=Vector(tuple((p[i]-low[i])/span[i]*size[i] for i in range(3)))-Vector((.09,.16,0))
    body.data.materials.clear();body.data.materials.append(material('RetainedSatchelLeather',(.115,.067,.038)))
    for polygon in body.data.polygons:polygon.material_index=0
    strap_mat=material('WeatheredCinchLeather',(.065,.038,.022))
    anchors=[]
    for sign in [-1,1]:
        desired=Vector((-.06,sign*.11,.075))
        point=min((v.co.copy() for v in body.data.vertices),key=lambda p:(p-desired).length)
        # The strip ends penetrate the measured retained surface by 2mm, so
        # the tie cannot float detached from a guessed bounding-box corner.
        point.x+=.002;anchors.append(point)
    strap=ribbon('SatchelStrap',[anchors[0],(-.075,-.105,.145),(-.08,-.10,.18),
        (-.08,-.05,.184),(-.08,0,.184),(-.08,.05,.184),(-.08,.10,.18),
        (-.075,.105,.145),anchors[1]],strap_mat)
    knot_mat=material('CinchTieEdge',(.17,.105,.06))
    knot=ribbon('SatchelKnot',[(-.08,-.025,.18),(-.071,-.014,.191),(-.083,0,.185),(-.089,.014,.192),(-.08,.025,.18)],knot_mat,.018,.006)
    # Knot origin sits on the real tie so the existing controller's small
    # contact compression remains local rather than moving the whole prop.
    knot.location=Vector((-.08,0,.18))
    for vertex in knot.data.vertices:vertex.co-=knot.location
    root=bpy.data.objects.new('RookStationSatchel',None);bpy.context.scene.collection.objects.link(root)
    for obj in (body,strap,knot):obj.parent=root
    for side,y in [('Left',.10),('Right',-.10)]:
        marker=bpy.data.objects.new('Grip'+side,None);bpy.context.scene.collection.objects.link(marker)
        marker.location=(-.08,y,.18);marker.parent=root
    triangles=sum(len(poly.vertices)-2 for obj in (body,strap,knot) for poly in obj.data.polygons)
    if triangles>6000:raise ValueError('Satchel exceeds retained prop triangle budget')
    for image in bpy.data.images:
        if image.source=='FILE' and not image.packed_file:image.pack()
    blend=OUT/'rook_station_satchel.blend';carrier=OUT/'rook_station_satchel.glb'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(carrier),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
    report={'source':str(SOURCE),'source_sha256':sha(SOURCE),'blend':str(blend),'blend_sha256':sha(blend),
            'carrier':str(carrier),'carrier_sha256':sha(carrier),'blender_version':bpy.app.version_string,
            'triangles':triangles,'body_bounds_godot':{'minimum':[-.09,0,-.16],'size':[.18,.16,.32]},
            'grips_godot':{'GripLeft':[-.08,.18,-.10],'GripRight':[-.08,.18,.10]},
            'knot_node':'SatchelKnot','authored':True,'runtime_verified':False,'user_accepted':False,
            'notes':['Retained Bag.obj body silhouette normalized to the supported workstation footprint.',
                     'Attached leather strap and separate rigid knot are authored additions; no pickup or carried behavior is claimed.']}
    (OUT/'satchel_authoring.json').write_text(json.dumps(report,indent=2)+'\n')
    scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH'
    scene.render.resolution_x=720;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.display.shading.color_type='MATERIAL';scene.display.shading.show_cavity=True
    if scene.world is None:scene.world=bpy.data.worlds.new('ReviewWorld')
    scene.world.color=(.12,.12,.12)
    bpy.ops.object.camera_add(location=(-.55,-.65,.55));camera=bpy.context.object
    camera.rotation_euler=(Vector((0,0,.08))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=.55;scene.camera=camera
    scene.render.filepath=str(OUT/'rook_station_satchel_review.png');bpy.ops.render.render(write_still=True)
    print('ROOK_STATION_SATCHEL_AUTHORED',triangles,flush=True)


if __name__=='__main__':main()
