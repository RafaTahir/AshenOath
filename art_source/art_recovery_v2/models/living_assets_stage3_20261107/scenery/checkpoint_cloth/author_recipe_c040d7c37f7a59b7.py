"""Retain editable Blender support pivots for the four living scenery assemblies.

The native retained-part export is an input, not the final asset. This recipe
builds a separate support-rooted hierarchy, preserves actual world geometry and
materials, and exports the Blender-authored assembly for native compilation.
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import shutil
import sys

COUNTS={'checkpoint_cloth':2,'marsh_reeds':5,'hart_ferns':6,'ash_mill_wheel':1}
IDS=tuple(COUNTS)


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def art_root(path=None):
    if path is not None:return Path(path).resolve(strict=True)
    for ancestor in Path(__file__).resolve().parents:
        if ancestor.name=='art_recovery_v2' and (ancestor/'tools').is_dir():return ancestor
    raise ValueError('Specify --art-root for a recipe outside the retained art tree')


def beneath(root,value):
    path=(root/str(value).replace('\\','/')).resolve(strict=True)
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError('Scenery provenance must remain inside the art root: '+str(value))
    return path


def validate_parts(identity,parts):
    if identity not in COUNTS or not isinstance(parts,list) or len(parts)!=COUNTS[identity]:
        raise ValueError('Retained scenery part count changed: '+identity)
    prefix={'checkpoint_cloth':'CheckpointCloth_','marsh_reeds':'MarshReeds_','hart_ferns':'HartFern_'}
    expected={prefix[identity]+str(i) for i in range(COUNTS[identity])} if identity in prefix else {'AshMillWaterwheel'}
    names=[row.get('node') for row in parts]
    if len(set(names))!=len(names) or set(names)!=expected:
        raise ValueError('Retained scenery mesh identities changed: '+identity)
    kind='cloth' if identity=='checkpoint_cloth' else 'mill_wheel' if identity=='ash_mill_wheel' else 'foliage'
    for row in parts:
        point=row.get('pivot_godot')
        if row.get('kind')!=kind or not isinstance(point,list) or len(point)!=3 or any(type(v) not in (int,float) or not math.isfinite(v) for v in point):
            raise ValueError('Invalid retained support pivot: '+str(row.get('node')))
        if not isinstance(row.get('triangles'),(int,float)) or row['triangles']<=0:
            raise ValueError('Empty retained mesh: '+row['node'])
    if identity=='ash_mill_wheel' and max(abs(a-b) for a,b in zip(parts[0]['pivot_godot'],[-4.42,1.55,1.80]))>0.00001:
        raise ValueError('Retained waterwheel axle changed')


def validate_baseline(identity,root,inputs=None):
    evidence=root/'evidence/living_assets_stage3_20261107/scenery'
    baseline_path=evidence/(identity+'_baseline.json')
    archived=None
    if inputs is not None:
        archived=json.loads(beneath(root,inputs).read_text(encoding='utf-8-sig'))
        if archived.get('schema_version')!=2 or archived.get('asset')!=identity:
            raise ValueError('Archived authoring input belongs to a different scenery asset')
        baseline_path=beneath(root,archived['retained_receipt'])
        if sha(baseline_path)!=archived.get('retained_receipt_sha256'):
            raise ValueError('Archived baseline receipt bytes changed')
    baseline=json.loads(baseline_path.read_text(encoding='utf-8-sig'))
    if baseline.get('schema_version')!=2 or baseline.get('asset')!=identity:
        raise ValueError('Fresh immutable native baseline receipt is required: '+identity)
    validate_parts(identity,baseline.get('parts'))
    carrier=beneath(root,archived['retained_input'] if archived else baseline['carrier'])
    native=beneath(root,archived['retained_native'] if archived else baseline['native_baseline'])
    if sha(carrier)!=baseline.get('carrier_sha256') or sha(native)!=baseline.get('native_baseline_sha256'):
        raise ValueError('Retained scenery inputs no longer match their receipt')
    if archived and (sha(carrier)!=archived.get('retained_input_sha256') or sha(native)!=archived.get('retained_native_sha256')):
        raise ValueError('Archived scenery inputs differ from their authoring receipt')
    game=root.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
    sources=baseline.get('source_hashes')
    if not isinstance(sources,dict) or not sources:raise ValueError('Retained scenery requires source hashes')
    for source,digest in sources.items():
        if not source.startswith('res://'):raise ValueError('Unknown retained source path: '+source)
        source_path=(game/source[6:]).resolve(strict=True)
        if not source_path.is_relative_to(game.resolve()) or sha(source_path)!=digest:
            raise ValueError('Retained scenery source changed: '+source)
    return baseline,baseline_path,carrier,native


def archive(source,folder,prefix):
    target=folder/(prefix+sha(source)[:16]+source.suffix)
    if target.exists() and sha(target)!=sha(source):raise ValueError('Scenery archive hash collision: '+str(target))
    if not target.exists():shutil.copyfile(source,target)
    return target


def preserve_previous(folder,root):
    previous=folder/'authoring.json'
    if not previous.exists():return
    receipt=json.loads(previous.read_text(encoding='utf-8-sig'))
    for key in ('blend','carrier','recipe','retained_input','retained_native','retained_receipt'):
        if key not in receipt or sha(beneath(root,receipt[key]))!=receipt.get(key+'_sha256'):
            raise ValueError('Existing authoring changed; preserve and review it before rebaking: '+key)
    for key in ('transport_helper','raw_carrier'):
        if key in receipt and sha(beneath(root,receipt[key]))!=receipt.get(key+'_sha256'):
            raise ValueError('Existing extended authoring provenance changed: '+key)
    archive(previous,folder,'authoring_history_')


def retained_transport(root,folder,inputs):
    current=(root/'tools/author_living_world_parts.py').resolve()
    if inputs is None and Path(__file__).resolve()!=current:
        raise ValueError('An archived recipe requires --inputs so its exact archived helper is selected')
    if inputs is not None:
        receipt=json.loads(beneath(root,inputs).read_text(encoding='utf-8-sig'))
        helper=beneath(root,receipt.get('transport_helper',''))
        if sha(helper)!=receipt.get('transport_helper_sha256'):
            raise ValueError('Archived scenery transport helper changed')
    else:helper=root/'tools/living_world_gltf_transport.py'
    retained=archive(helper,folder,'transport_helper_')
    name='living_world_transport_'+sha(retained)[:16]
    spec=importlib.util.spec_from_file_location(name,retained)
    module=importlib.util.module_from_spec(spec)
    sys.modules[name]=module
    spec.loader.exec_module(module)
    return module,retained


def rebuild_retained_corners(obj,source,bpy):
    """Keep coincident/reverse faces and float channels in the editable mesh."""
    old=obj.data
    positions=source['positions'];indices=source['indices']
    if sorted(set(indices))!=list(range(len(positions))):
        raise ValueError('Retained scenery has unreferenced vertices; review its import mapping')
    if len(old.vertices)!=len(positions):
        raise ValueError('Blender import changed retained vertex identity: '+obj.name)
    converted=[(p[0],-p[2],p[1]) for p in positions]
    mapping_error=max(math.dist(tuple(vertex.co),point) for vertex,point in zip(old.vertices,converted))
    if not math.isfinite(mapping_error) or mapping_error>1e-6:
        raise ValueError('Blender import changed retained vertex order/frame: '+obj.name)
    if len(old.materials)!=1 or len(old.color_attributes)!=1:
        raise ValueError('Retained scenery requires its exact single material/color binding: '+obj.name)
    color_name=old.color_attributes[0].name
    mesh=bpy.data.meshes.new(obj.name+'_RetainedTriangleCorners')
    corners=[converted[index] for index in indices]
    faces=[tuple(range(start,start+3)) for start in range(0,len(indices),3)]
    mesh.from_pydata(corners,[],faces)
    mesh.materials.append(old.materials[0])
    mesh.update()
    if len(mesh.vertices)!=len(indices) or len(mesh.polygons)*3!=len(indices):
        raise ValueError('Editable Blender mesh changed the retained triangle multiset')
    for polygon in mesh.polygons:polygon.use_smooth=True
    # Preview normals may be internally packed by Blender. The explicit raw
    # float attribute is the audited interchange source, in glTF local axes.
    normals=[source['normals'][index] for index in indices]
    mesh.normals_split_custom_set_from_vertices([(n[0],-n[2],n[1]) for n in normals])
    normal_layer=mesh.attributes.new(name='_AO_RETAINED_NORMAL',type='FLOAT_VECTOR',domain='POINT')
    normal_layer.data.foreach_set('vector',[value for normal in normals for value in normal])
    color_layer=mesh.color_attributes.new(name=color_name,type='FLOAT_COLOR',domain='POINT')
    colors=[source['colors'][index] for index in indices]
    color_layer.data.foreach_set('color',[value for color in colors for value in color])
    mesh.color_attributes.active_color_index=0
    mesh.color_attributes.render_color_index=0
    uv_layer=mesh.uv_layers.new(name='UVMap')
    uv_layer.uv.foreach_set('vector',[value for index in indices for value in (source['uvs'][index][0],1.0-source['uvs'][index][1])])
    color_error=max(abs(float(color_layer.data[i].color[j])-colors[i][j]) for i in range(len(colors)) for j in range(4))
    normal_error=max(abs(float(normal_layer.data[i].vector[j])-normals[i][j]) for i in range(len(normals)) for j in range(3))
    if max(color_error,normal_error)>1e-7:
        raise ValueError('Editable float channels changed retained source values')
    obj.data=mesh
    if old.users==0:bpy.data.meshes.remove(old)
    return {'editable_triangle_corners':len(indices),'editable_triangles':len(faces),'color_storage':'FLOAT_COLOR',
            'normal_storage':'_AO_RETAINED_NORMAL/FLOAT_VECTOR/glTF-local','import_vertex_mapping_error':mapping_error,
            'maximum_float_color_error':color_error,'maximum_float_normal_error':normal_error}


def main(identity,root_path,inputs=None):
    baseline,baseline_path,carrier,native=validate_baseline(identity,root_path,inputs)
    folder=root_path/'models/living_assets_stage3_20261107/scenery'/identity
    folder.mkdir(parents=True,exist_ok=True)
    preserve_previous(folder,root_path)
    retained=archive(carrier,folder,'retained_')
    retained_native=archive(native,folder,'retained_native_')
    retained_receipt=archive(baseline_path,folder,'retained_receipt_')
    recipe=archive(Path(__file__).resolve(),folder,'author_recipe_')
    transport,transport_helper=retained_transport(root_path,folder,inputs)
    source_parts=transport.read_retained_parts(retained,{row['node'] for row in baseline['parts']})
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    if bpy.ops.import_scene.gltf(filepath=str(retained),merge_vertices=False)!={'FINISHED'}:raise ValueError('Retained scenery import did not finish')
    root=bpy.data.objects.new(identity+'_BlenderAssembly',None)
    bpy.context.scene.collection.objects.link(root)
    root['retained_art_direction']=True
    root['runtime_motion_owner']='WorldPropController'
    root['source_only_independent_tickers']=0
    parts=[]
    selected=[root]
    for record in baseline['parts']:
        name=record['node']
        obj=bpy.data.objects.get(name)
        if obj is None or obj.type!='MESH':
            raise ValueError('Exact retained scenery mesh binding is missing: '+name)
        editable_channels=rebuild_retained_corners(obj,source_parts[name],bpy)
        old_world=obj.matrix_world.copy()
        before=[old_world @ vertex.co for vertex in obj.data.vertices]
        if not before:raise ValueError('Empty retained scenery mesh: '+name)
        point=record['pivot_godot']
        pivot=Vector((point[0],-point[2],point[1]))
        obj.name=name+'_Geometry'
        support=bpy.data.objects.new(name,None)
        bpy.context.scene.collection.objects.link(support)
        support.parent=root
        support.location=pivot
        support.empty_display_type='ARROWS'
        support.empty_display_size=.16
        support['world_prop_kind']=record['kind']
        support['world_prop_verified_pivot']=True
        if record['kind']=='mill_wheel':
            support['world_prop_spin_axis_godot']=[1.,0.,0.]
            support['world_prop_nominal_spin_speed']=.45
            support['world_prop_flow_required']=True
        bpy.context.view_layer.update()
        obj.parent=support
        obj.matrix_world=old_world
        bpy.context.view_layer.update()
        after=[obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
        maximum=max((a-b).length for a,b in zip(before,after))
        if not math.isfinite(maximum) or maximum>1e-5:raise ValueError('Support reparenting moved retained scenery: '+name)
        heights=[point.z-pivot.z for point in after]
        if record['kind']=='cloth' and max(heights)>.0001:
            raise ValueError('Cloth is not rooted at its upper support')
        if record['kind']=='foliage' and min(heights)<-.0001:
            raise ValueError('Foliage moved beneath its original ground support')
        selected.extend((support,obj))
        parts.append({**record,**editable_channels,'export_mesh':obj.name,'support_node':support.name,
                      'maximum_retained_world_vertex_error':maximum,
                      'vertices':len(obj.data.vertices),
                      'world_bounds_blender':{'min':[min(p[i] for p in after) for i in range(3)],
                                             'max':[max(p[i] for p in after) for i in range(3)]}})
    if len([obj for obj in bpy.data.objects if obj.type=='MESH'])!=COUNTS[identity]:
        raise ValueError('Imported scenery contains an unexpected mesh')
    for image in bpy.data.images:
        if image.source=='FILE' and not image.packed_file:image.pack()
    version=1
    while any((folder/(identity+'_living_v%03d'%version+suffix)).exists() for suffix in ('.blend','.glb')):version+=1
    blend=folder/(identity+'_living_v%03d.blend'%version)
    exported=folder/(identity+'_living_v%03d.glb'%version)
    if bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)!={'FINISHED'}:raise ValueError('Editable Blender source did not save')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in selected:obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    if bpy.ops.export_scene.gltf(filepath=str(exported),export_format='GLB',use_selection=True,
                                export_animations=False,export_yup=True,export_extras=True,export_attributes=True)!={'FINISHED'}:
        raise ValueError('Blender scenery carrier did not export')
    raw_carrier=exported.with_name(exported.stem+'_blender_raw.glb')
    if raw_carrier.exists():raise ValueError('Preserve the previous raw Blender carrier before retrying')
    shutil.copyfile(exported,raw_carrier)
    normal_transport=transport.bind_retained_normals(exported,source_parts)
    receipt={'schema_version':2,'asset':identity,'blender_version':bpy.app.version_string,
             'source_hashes':baseline['source_hashes'],'parts':parts,'normal_transport':normal_transport,
             'blender_authored':True,'native_verified':False,'visual_accepted':False,'user_accepted':False}
    for key,path in [('retained_input',retained),('retained_native',retained_native),('retained_receipt',retained_receipt),
                     ('blend',blend),('carrier',exported),('recipe',recipe),('transport_helper',transport_helper),('raw_carrier',raw_carrier)]:
        receipt[key]=path.relative_to(root_path).as_posix()
        receipt[key+'_sha256']=sha(path)
    temporary=folder/'authoring.pending.json'
    if temporary.exists():raise ValueError('Preserve pending authoring receipt before retrying')
    temporary.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    temporary.replace(folder/'authoring.json')
    print('LIVING_WORLD_BLENDER_AUTHORED',identity,'parts',len(parts),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset',required=True,choices=IDS)
    parser.add_argument('--art-root',type=Path)
    parser.add_argument('--inputs',type=Path,help='reproduce the exact retained inputs of an archived/current authoring.json')
    parser.add_argument('--validate-only',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else None)
    root_path=art_root(args.art_root)
    if args.validate_only:
        validate_baseline(args.asset,root_path,args.inputs)
        print('LIVING_WORLD_BASELINE_VALIDATED',args.asset,'blender_started=false')
    else:main(args.asset,root_path,args.inputs)
