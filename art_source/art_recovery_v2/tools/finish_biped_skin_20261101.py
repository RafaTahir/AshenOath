"""Remove inherited periodic skin albedo grain without touching animation data.

Run with the pinned ordinary Python, one --id at a time. A small background
Blender subprocess installs a fresh packed image in an editable v004 master.
The embedded runtime GLB is patched at one image bufferView only: no mesh,
joint, UV, weight, timing, sampled-pose or other image bytes are re-exported.
Canonical production resources and global ledgers are never written here.
"""
import argparse
import hashlib
import io
import json
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT.parents[1] / "outputs/AshenOathTheRoadBetweenCrowns"
BLENDER = Path("C:/Program Files/Blender Foundation/Blender 5.2/blender.exe")
BACKUP = Path("D:/Temp/AshenOath/skin_refinement_20261101/before")
MATERIALS = {"M01":"M01_PeatSkin", "M03":"M03_WaterloggedOliveHide",
             "M05":"M05_ClaySkin", "M19":"M19_OliveGreyHide",
             "M20":"M20_CharcoalOliveHide"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def identity(path):
    data = path.read_bytes()
    return {"bytes":len(data), "sha256":sha(data)}


def read_glb(path):
    data = path.read_bytes()
    magic,version,total = struct.unpack_from("<4sII",data)
    assert magic == b"glTF" and version == 2 and total == len(data)
    length,kind = struct.unpack_from("<II",data,12)
    assert kind == 0x4e4f534a
    binary_length,binary_kind = struct.unpack_from("<II",data,20+length)
    assert binary_kind == 0x004e4942
    return json.loads(data[20:20+length]), bytearray(data[28+length:28+length+binary_length])


def write_glb(path,document,binary):
    document["buffers"] = [{"byteLength":len(binary)}]
    encoded = json.dumps(document,separators=(",",":")).encode()
    encoded += b" " * (-len(encoded)%4)
    binary += b"\0" * (-len(binary)%4)
    result = struct.pack("<4sII",b"glTF",2,28+len(encoded)+len(binary))
    result += struct.pack("<II",len(encoded),0x4e4f534a)+encoded
    result += struct.pack("<II",len(binary),0x004e4942)+binary
    path.write_bytes(result)


def payload(document,binary,index):
    view = document["bufferViews"][index]
    start = view.get("byteOffset",0)
    return bytes(binary[start:start+view["byteLength"]])


def update_master(job_path):
    import bpy
    job = json.loads(job_path.read_text())
    source = Path(job["old_source"])
    assert identity(source)["sha256"] == job["old_source_sha256"]
    bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
    scene = bpy.context.scene
    assert scene.render.fps == 24, "Retain the corrected imported clip rate"
    actions = [action.name for action in bpy.data.actions]
    armatures = [ob for ob in bpy.data.objects if ob.type == "ARMATURE"]
    bones = [[bone.name for bone in ob.data.bones] for ob in armatures]
    material = bpy.data.materials.get(job["material"])
    assert material is not None and material.node_tree is not None
    principled = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    assert len(principled.inputs["Base Color"].links) == 1
    found=[]
    visited=set()
    def upstream(node):
        if node.name in visited:return
        visited.add(node.name)
        if node.type == "TEX_IMAGE":
            found.append(node)
            return
        for socket in node.inputs:
            for link in socket.links:upstream(link.from_node)
    upstream(principled.inputs["Base Color"].links[0].from_node)
    assert len(found) == 1, "Expected one skin albedo image behind retained color/vertex factors"
    image_node = found[0]
    original_image = image_node.image
    assert original_image is not None and tuple(original_image.size) == (256,256)
    # A loaded new datablock carries the exact freshly encoded PNG. Never copy
    # the old packed image: Blender otherwise may export its stale packed_file.
    fresh = bpy.data.images.load(job["new_png"],check_existing=False)
    fresh.name = job["id"] + "_Skin_Albedo_Debanded_v004"
    fresh.colorspace_settings.name = "sRGB"
    fresh.use_fake_user = True
    assert tuple(fresh.size) == (256,256)
    fresh.pack()
    assert fresh.packed_file is not None and sha(bytes(fresh.packed_file.data)) == job["new_png_sha256"]
    image_node.image = fresh
    scene["skin_albedo_finish_20261101"] = json.dumps({"scope":"Inherited diagonal albedo grain removed; same mean palette; no geometry/clip changes", "old_image":original_image.name, "new_image":fresh.name, "new_png_sha256":job["new_png_sha256"]})
    assert actions == [action.name for action in bpy.data.actions]
    assert bones == [[bone.name for bone in ob.data.bones] for ob in armatures]
    target = Path(job["new_source"])
    bpy.ops.wm.save_as_mainfile(filepath=str(target),compress=True)
    result = {"source_path":str(target),"source_sha256":identity(target)["sha256"],"packed_image_sha256":sha(bytes(fresh.packed_file.data)),"actions_preserved":actions,"bone_names_preserved":True,"fps":24}
    job_path.with_name("master_result.json").write_text(json.dumps(result,indent=2)+"\n")
    print("FRESH_SKIN_MASTER",job["id"],str(target),flush=True)


def finish(key):
    import numpy as np
    from PIL import Image
    receipt = ROOT / "evidence/refinement_20261101/bipeds" / key / "candidate.json"
    candidate = json.loads(receipt.read_text())
    assert not candidate.get("skin_albedo_finish_v004"), "This candidate already received the bounded skin finish"
    source = Path(candidate["source_path"])
    target = Path(candidate["runtime_path"])
    original = target.read_bytes()
    document,binary = read_glb(target)
    before_document = json.loads(json.dumps(document))
    before_binary = bytes(binary)
    assert len(document["buffers"]) == 1 and not document["buffers"][0].get("uri")
    material_index = next(i for i,m in enumerate(document["materials"]) if m["name"] == MATERIALS[key])
    material = document["materials"][material_index]
    texture_index = material["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    image_index = document["textures"][texture_index]["source"]
    image = document["images"][image_index]
    assert image["mimeType"] == "image/png" and "bufferView" in image
    image_view = image["bufferView"]
    old_png = payload(document,binary,image_view)
    old_image = Image.open(io.BytesIO(old_png)).convert("RGBA")
    assert old_image.size == (256,256)
    old_pixels = np.array(old_image,dtype=np.float64)
    assert np.all(old_pixels[:,:,3] == 255)
    mean = old_pixels[:,:,:3].mean(axis=(0,1))
    # Low-amplitude stationary filtered noise has no periodic directional
    # carrier. A single luminance field preserves the existing channel ratios.
    rng = np.random.default_rng(2026110100+int(key[1:]))
    noise = rng.standard_normal((256,256))
    fx = np.fft.fftfreq(256)[None,:]
    fy = np.fft.fftfreq(256)[:,None]
    filtered = np.fft.ifft2(np.fft.fft2(noise)*np.exp(-2*np.pi*np.pi*2.0**2*(fx*fx+fy*fy))).real
    filtered -= filtered.mean()
    filtered /= filtered.std()
    color = mean[None,None,:] + filtered[:,:,None] * (mean/mean.mean())[None,None,:] * .65
    new_pixels = np.empty((256,256,4),dtype=np.uint8)
    new_pixels[:,:,:3] = np.rint(np.clip(color,0,255)).astype(np.uint8)
    new_pixels[:,:,3] = 255
    new_mean = new_pixels[:,:,:3].mean(axis=(0,1))
    mean_delta = (new_mean-mean)/255
    assert float(np.max(np.abs(mean_delta))) <= 1/255
    directory = receipt.parent / "skin_finish_v004"
    directory.mkdir(parents=True,exist_ok=True)
    old_png_path = directory / (key+"_skin_albedo_before.png")
    new_png_path = directory / (key+"_skin_albedo_filtered.png")
    old_png_path.write_bytes(old_png)
    Image.fromarray(new_pixels,"RGBA").save(new_png_path,optimize=True)
    new_png = new_png_path.read_bytes()
    assert np.array_equal(np.array(Image.open(io.BytesIO(new_png)).convert("RGBA")),new_pixels)
    BACKUP.mkdir(parents=True,exist_ok=True)
    backup = BACKUP / (key+"_refined_before_skin_v004.glb")
    if backup.exists():assert backup.read_bytes() == original
    else:backup.write_bytes(original)
    new_source = source.with_name(key+"_refined_timing_skin_v004.blend")
    assert not new_source.exists(), "Preserve the existing skin-finish master"
    job = {"id":key,"material":MATERIALS[key],"old_source":str(source),"old_source_sha256":identity(source)["sha256"],"new_source":str(new_source),"new_png":str(new_png_path),"new_png_sha256":sha(new_png)}
    job_path = directory / "master_job.json"
    job_path.write_text(json.dumps(job,indent=2)+"\n")
    log = directory / "master_update.log"
    command = [str(BLENDER),"--background","--factory-startup","--python-exit-code","1","--python",str(Path(__file__).resolve()),"--","--id",key,"--update-master",str(job_path)]
    with log.open("w",encoding="utf-8") as stream:
        result = subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,timeout=240,creationflags=subprocess.CREATE_NO_WINDOW)
    if result.returncode:
        raise RuntimeError("Fresh packed-image source update failed; see "+str(log))
    master_result = json.loads(job_path.with_name("master_result.json").read_text())
    # Append one new image payload. No existing non-image bytes move or change;
    # the lossless shared-runtime compiler discards the unreferenced old bytes.
    binary += b"\0" * (-len(binary)%4)
    new_offset = len(binary)
    binary.extend(new_png)
    document["bufferViews"][image_view] = dict(document["bufferViews"][image_view],byteOffset=new_offset,byteLength=len(new_png))
    write_glb(target,document,binary)
    after,after_binary = read_glb(target)
    assert payload(after,after_binary,image_view) == new_png
    image_views = {img["bufferView"] for img in before_document["images"]}
    non_image_views = [i for i in range(len(before_document["bufferViews"])) if i not in image_views]
    for index in range(len(before_document["bufferViews"])):
        if index == image_view:continue
        assert before_document["bufferViews"][index] == after["bufferViews"][index]
        assert payload(before_document,before_binary,index) == payload(after,after_binary,index)
    for field in before_document:
        if field not in ("buffers","bufferViews"):
            assert before_document[field] == after[field], "Unexpected JSON change: "+field
    assert len(before_document["bufferViews"]) == len(after["bufferViews"])
    audit = {"id":key,"material":MATERIALS[key],"image_size":[256,256],"old_image_sha256":sha(old_png),"new_image_sha256":sha(new_png),"old_mean_rgb8":mean.tolist(),"new_mean_rgb8":new_mean.tolist(),"mean_rgb_delta_normalized":mean_delta.tolist(),"maximum_mean_channel_delta_rgb8":float(np.max(np.abs(new_mean-mean))),"noise":"Seeded Gaussian-filtered stationary luminance noise; 0.65 encoded-RGB-byte standard deviation; old channel ratios retained","old_runtime":dict(path=str(backup),**identity(backup)),"new_runtime":dict(path=str(target),**identity(target)),"old_source":str(source),"new_source":dict(path=str(new_source),**identity(new_source)),"non_image_buffer_views_preserved":len(non_image_views),"all_other_image_payloads_preserved":True,"all_geometry_skin_uv_node_accessor_and_animation_json_and_payloads_identical":True,"clips_preserved":[clip["name"] for clip in after.get("animations",[])],"native_visual_acceptance":"Pending main integration/import and fresh current-hash captures"}
    (directory/"skin_finish.json").write_text(json.dumps(audit,indent=2)+"\n")
    candidate["previous_skin_source"] = str(source)
    candidate["source_path"] = str(new_source)
    candidate["source_sha256"] = identity(new_source)["sha256"]
    candidate["runtime_sha256"] = identity(target)["sha256"]
    candidate["skin_albedo_finish_v004"] = audit
    candidate.setdefault("changes",[]).append("Removed inherited diagonal skin albedo lattice; retained mean palette with subtle filtered non-periodic grain. All geometry, skinning, UVs and clip bytes unchanged.")
    receipt.write_text(json.dumps(candidate,indent=2)+"\n")
    print(json.dumps({"id":key,"runtime_sha256":candidate["runtime_sha256"],"source_path":str(new_source),"mean_channel_delta_rgb8":audit["maximum_mean_channel_delta_rgb8"],"non_image_views_preserved":len(non_image_views),"clips":len(audit["clips_preserved"])}),flush=True)


def render_final_views(key):
    """Render current packed albedo without saving any scene/model changes."""
    import math
    import bpy
    from mathutils import Vector
    receipt = ROOT / "evidence/refinement_20261101/bipeds" / key / "candidate.json"
    candidate = json.loads(receipt.read_text())
    assert candidate.get("skin_albedo_finish_v004")
    source = Path(candidate["source_path"])
    before_sha = identity(source)["sha256"]
    assert before_sha == candidate["source_sha256"]
    bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
    scene = bpy.context.scene
    rig = next(ob for ob in scene.objects if ob.type == "ARMATURE")
    rig.data.pose_position = "POSE"
    if rig.animation_data:
        rig.animation_data.action = None
        for track in rig.animation_data.nla_tracks:track.mute = True
    idle = bpy.data.actions.get("Idle")
    assert idle is not None
    rig.animation_data.action = idle
    if hasattr(rig.animation_data,"action_slot") and idle.slots:
        rig.animation_data.action_slot = idle.slots[0]
    scene.frame_set(8)
    bpy.context.view_layer.update()
    meshes = [ob for ob in scene.objects if ob.type == "MESH" and ob.find_armature() == rig]
    assert meshes
    for ob in scene.objects:
        if ob.type == "MESH":ob.hide_render = ob not in meshes
    # Workbench TEXTURE uses the active image node. Explicitly choose the
    # Base Color branch, not a later-added normal/ORM texture node.
    materials = {material for ob in meshes for material in ob.data.materials if material}
    for material in materials:
        if not material.node_tree:continue
        principled = next((node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"),None)
        if not principled:continue
        found=[]
        visited=set()
        def upstream(node):
            if node.name in visited:return
            visited.add(node.name)
            if node.type == "TEX_IMAGE":found.append(node);return
            for socket in node.inputs:
                for link in socket.links:upstream(link.from_node)
        for link in principled.inputs["Base Color"].links:upstream(link.from_node)
        if found:
            for node in material.node_tree.nodes:node.select = False
            found[0].select = True
            material.node_tree.nodes.active = found[0]
    deps = bpy.context.evaluated_depsgraph_get()
    points=[]
    for ob in meshes:
        evaluated=ob.evaluated_get(deps)
        points.extend(evaluated.matrix_world@Vector(corner) for corner in evaluated.bound_box)
    low=Vector([min(point[i] for point in points) for i in range(3)])
    high=Vector([max(point[i] for point in points) for i in range(3)])
    center=(low+high)*.5
    height=high.z-low.z
    span=max(height,(high.x-low.x)/.8)*1.18
    scene.render.engine="BLENDER_WORKBENCH"
    scene.render.resolution_x,scene.render.resolution_y=480,600
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.film_transparent=False
    shade=scene.display.shading
    shade.light="STUDIO"
    shade.studio_light="paint.sl"
    shade.color_type="TEXTURE"
    shade.show_shadows=True
    shade.show_cavity=True
    shade.cavity_type="WORLD"
    shade.curvature_ridge_factor=1.0
    shade.curvature_valley_factor=.7
    shade.show_specular_highlight=True
    shade.background_type="WORLD"
    scene.world=bpy.data.worlds.new(key+"_FinalTextureReview")
    scene.world.color=(.045,.052,.06)
    scene.view_settings.view_transform="Standard"
    camera_data=bpy.data.cameras.new("FinalTextureReviewCamera")
    camera=bpy.data.objects.new("FinalTextureReviewCamera",camera_data)
    scene.collection.objects.link(camera)
    scene.camera=camera
    camera_data.type="ORTHO"
    camera_data.ortho_scale=span
    scene.render.use_stamp=True
    for prop in ("use_stamp_date","use_stamp_time","use_stamp_render_time","use_stamp_frame","use_stamp_filename","use_stamp_scene","use_stamp_camera"):
        setattr(scene.render,prop,False)
    scene.render.use_stamp_note=True
    scene.render.stamp_font_size=10
    scene.render.stamp_note_text=key+" | FINAL v004 SKIN | WORKBENCH TEXTURE | NOT PBR / GODOT"
    views={}
    for name,angle in (("front",0),("side",math.pi/2),("rear",math.pi),("quarter",.65)):
        camera.location=center+Vector((math.sin(angle)*height*4,-math.cos(angle)*height*4,height*.08))
        camera.rotation_euler=(center-camera.location).to_track_quat("-Z","Y").to_euler()
        target=receipt.parent/(name+".png")
        scene.render.filepath=str(target)
        bpy.ops.render.render(write_still=True)
        views[name]=str(target)
    assert identity(source)["sha256"] == before_sha, "Rendering changed the source file"
    candidate["final_source_views"]={"paths":views,"source_path":str(source),"source_sha256":before_sha,"renderer":"Blender Workbench TEXTURE / studio light; actual Base Color image nodes active; not PBR or Godot", "pose":"Retained Idle at frame 8 / 24 FPS; NLA muted for review only", "master_file_unchanged":True}
    receipt.write_text(json.dumps(candidate,indent=2)+"\n")
    print("FINAL_SOURCE_VIEWS",key,before_sha,flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--id",choices=sorted(MATERIALS))
    parser.add_argument("--update-master")
    parser.add_argument("--render-final-views",action="store_true")
    parser.add_argument("--render-final-all",action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else None)
    if args.render_final_all:
        for key in ("M01","M03","M05","M19","M20"):render_final_views(key)
    elif not args.id:parser.error("--id is required except for --render-final-all")
    elif args.render_final_views:render_final_views(args.id)
    elif args.update_master:update_master(Path(args.update_master))
    else:finish(args.id)


if __name__ == "__main__":
    main()
