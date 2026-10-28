#!/usr/bin/env python3
"""Render imported monster sources with Blender Cycles CPU, without changing assets.

Run with ordinary Python; this file launches Blender with the same arguments.
Only reference PNG/JSON files under .release-gate/spectral-monsters are written.
Example:
  python tools/render_spectral_monsters.py --output ../../.release-gate/spectral-monsters/baseline.png
  python tools/render_spectral_monsters.py --sources res://path/one.gltf res://path/two.glb --output ../../.release-gate/spectral-monsters/new.png

This is a studio source comparison, not a Godot gameplay or performance test.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys


PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
OUTPUT_ROOT = REPO / ".release-gate" / "spectral-monsters"
DEFAULT_SOURCES = [
    "res://assets_external/characters_universal/runtime/Ghoulkin_Authored_Atlas.gltf",
    "res://assets_external/enemies/ultimate_monsters/Demon.gltf",
    "res://assets_external/enemies/ultimate_monsters/Orc.gltf",
    "res://assets_external/enemies/ultimate_monsters/BlueDemon.gltf",
]


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", nargs="+", default=DEFAULT_SOURCES)
    parser.add_argument("--output", default=str(OUTPUT_ROOT / "opening-source-baseline.png"))
    parser.add_argument("--blender", default="/usr/bin/blender")
    parser.add_argument("--samples", type=int, default=32)
    parser.add_argument("--width", type=int, default=1600)
    parser.add_argument("--height", type=int, default=700)
    parser.add_argument("--threads", type=int, default=8)
    parser.add_argument("--title", default="OPENING MONSTERS | SOURCE REFERENCE")
    args = parser.parse_args(argv)
    args.output = Path(args.output).expanduser().resolve()
    if not args.output.is_relative_to(OUTPUT_ROOT.resolve()) or args.output.suffix.lower() != ".png":
        parser.error("--output must be a PNG under .release-gate/spectral-monsters/")
    args.sources = [
        (PROJECT / source[6:]).resolve() if source.startswith("res://") else Path(source).expanduser().resolve()
        for source in args.sources
    ]
    for source in args.sources:
        if not source.is_file() or source.suffix.lower() not in {".gltf", ".glb"}:
            parser.error(f"Expected existing GLTF/GLB source: {source}")
    if len(args.sources) > 8 or min(args.samples, args.width, args.height, args.threads) < 1:
        parser.error("Use 1–8 sources and positive render dimensions, samples and threads")
    return args


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def launch(args: argparse.Namespace) -> int:
    command = [
        args.blender, "--background", "--factory-startup", "--threads", str(args.threads),
        "--python-exit-code", "1", "--python", str(Path(__file__).resolve()), "--",
        "--sources", *(str(path) for path in args.sources), "--output", str(args.output),
        "--samples", str(args.samples), "--width", str(args.width), "--height", str(args.height),
        "--threads", str(args.threads), "--title", args.title,
    ]
    environment = os.environ.copy()
    environment["BLENDER_USER_RESOURCES"] = str(OUTPUT_ROOT / ".blender-user")
    environment["XDG_CACHE_HOME"] = str(OUTPUT_ROOT / ".cache")
    environment["XDG_CONFIG_HOME"] = str(OUTPUT_ROOT / ".config")
    return subprocess.run(command, check=False, cwd=REPO, env=environment).returncode


def render(args: argparse.Namespace) -> None:
    import bpy
    import _cycles
    from mathutils import Matrix, Vector

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = args.samples
    denoise = bool(getattr(_cycles, "with_openimagedenoise", False))
    scene.cycles.use_denoising = denoise
    if not denoise:
        print("REFERENCE NOTE: this Blender build lacks OpenImageDenoise; rendering CPU samples without denoising", flush=True)
    scene.cycles.max_bounces = 6
    scene.render.threads_mode = "FIXED"
    scene.render.threads = args.threads
    scene.render.resolution_x = args.width
    scene.render.resolution_y = args.height
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.render.fps = 24
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.exposure = 0.4
    scene.world = bpy.data.worlds.new("Neutral studio world")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.12, 0.15, 0.19, 1.0)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.32

    def aim(obj, target):
        obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()

    def bounds(objects):
        graph = bpy.context.evaluated_depsgraph_get()
        points = []
        for obj in objects:
            if obj.type != "MESH" or obj.hide_render:
                continue
            evaluated = obj.evaluated_get(graph)
            mesh = evaluated.to_mesh()
            try:
                points.extend(evaluated.matrix_world @ vertex.co for vertex in mesh.vertices)
            finally:
                evaluated.to_mesh_clear()
        if not points:
            raise ValueError("Imported source has no visible mesh")
        return Vector(tuple(min(point[axis] for point in points) for axis in range(3))), Vector(tuple(max(point[axis] for point in points) for axis in range(3)))

    def is_idle(name):
        return bool(re.match(r"^idle(?:[._-]\d+)?$", name, re.IGNORECASE))

    imported = []
    for source in args.sources:
        before_objects = set(bpy.data.objects)
        before_actions = set(bpy.data.actions)
        source_hash = digest(source)
        bpy.ops.import_scene.gltf(filepath=str(source))
        # glTF import creates hidden custom bone-display meshes (Icosphere).
        # They are not rendered anatomy and must not enlarge the actor's bounds.
        objects = [
            obj for obj in bpy.data.objects
            if obj not in before_objects and obj.name in scene.objects
            and (obj.type != "MESH" or obj.visible_get())
        ]
        actions = [action for action in bpy.data.actions if action not in before_actions]
        selections = []
        for obj in objects:
            if obj.type in {"LIGHT", "CAMERA"}:
                obj.hide_render = True
            animation = obj.animation_data
            if animation is None:
                continue
            idle_action = None
            for track in animation.nla_tracks:
                if obj.type == "ARMATURE" and is_idle(track.name) and len(track.strips) == 1:
                    idle_action = track.strips[0].action
                track.mute = True
            if idle_action is None and obj.type == "ARMATURE":
                idle_action = next((action for action in actions if is_idle(action.name)), None)
            animation.action = idle_action
            if idle_action is not None:
                selections.append({"object": obj.name, "action": idle_action.name, "frame": 8})
            elif obj.type == "ARMATURE":
                # Clearing imported action selection ensures the fallback is the
                # actual authored rest pose, not a random first death/attack clip.
                obj.data.pose_position = "REST"
        wrapper = bpy.data.objects.new(f"Reference_{source.stem}", None)
        scene.collection.objects.link(wrapper)
        for obj in objects:
            if obj.parent not in objects:
                world = obj.matrix_world.copy()
                obj.parent = wrapper
                obj.matrix_world = world
        imported.append({"source": source, "hash": source_hash, "objects": objects, "wrapper": wrapper, "idle": selections})

    scene.frame_set(8)
    bpy.context.view_layer.update()
    records = []
    height = 2.8
    spacing = 3.55
    for index, item in enumerate(imported):
        minimum, maximum = bounds(item["objects"])
        source_height = maximum.z - minimum.z
        if source_height <= 0.00001:
            raise ValueError(f"Degenerate source height: {item['source']}")
        scale = height / source_height
        x = (index - (len(imported) - 1) / 2.0) * spacing
        center = (minimum + maximum) * 0.5
        item["wrapper"].matrix_world = (
            Matrix.Translation((x, 0, -minimum.z * scale))
            @ Matrix.Rotation(math.radians(-22), 4, "Z")
            @ Matrix.Scale(scale, 4)
            @ Matrix.Translation((-center.x, -center.y, 0))
        )
        records.append({
            "source": str(item["source"].relative_to(PROJECT)) if item["source"].is_relative_to(PROJECT) else str(item["source"]),
            "sha256": item["hash"], "pose": "imported Idle" if item["idle"] else "source rest pose (no native Idle selected)",
            "idle_bindings": item["idle"], "source_height": source_height, "display_height": height,
            "display_scale": scale, "display_x": x,
            "rig_bones": [len(obj.data.bones) for obj in item["objects"] if obj.type == "ARMATURE"],
        })
        print("REFERENCE SOURCE: " + json.dumps(records[-1]), flush=True)
    bpy.context.view_layer.update()
    for item, record in zip(imported, records):
        minimum, maximum = bounds(item["objects"])
        if abs(minimum.z) > 0.0001 or abs(maximum.z - minimum.z - height) > 0.0001:
            raise ValueError(f"Reference grounding/height failed for {item['source']}")
        record["grounded_bounds"] = {"min": list(minimum), "max": list(maximum)}

    floor_material = bpy.data.materials.new("Studio slate")
    floor_material.diffuse_color = (0.025, 0.035, 0.047, 1)
    floor_material.use_nodes = True
    floor_bsdf = floor_material.node_tree.nodes.get("Principled BSDF")
    floor_bsdf.inputs["Base Color"].default_value = (0.025, 0.035, 0.047, 1)
    floor_bsdf.inputs["Roughness"].default_value = 0.8
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.015))
    bpy.context.object.name = "Studio ground (not an asset)"
    bpy.context.object.data.materials.append(floor_material)

    for name, location, power, size, color in [
        ("Soft key", (-3, -5, 7), 1750, 5, (1.0, 0.86, 0.72)),
        ("Cool fill", (6, -3, 5), 1300, 5, (0.70, 0.84, 1.0)),
        ("Silhouette rim", (0, 4, 7), 2200, 6, (0.66, 0.81, 1.0)),
    ]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.shape, data.size, data.color = power, "DISK", size, color
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        light.location = location
        aim(light, (0, 0, 1.3))

    camera_data = bpy.data.cameras.new("Comparison camera")
    camera = bpy.data.objects.new("Comparison camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0, -18, 6.1)
    aim(camera, (0, 0, 1.3))
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(5.5, spacing * len(imported) + 0.7)
    scene.camera = camera

    text_material = bpy.data.materials.new("Reference annotation")
    text_material.use_nodes = True
    nodes = text_material.node_tree.nodes
    nodes.clear()
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (0.65, 0.76, 0.88, 1)
    emission.inputs["Strength"].default_value = 1.0
    output = nodes.new("ShaderNodeOutputMaterial")
    text_material.node_tree.links.new(emission.outputs[0], output.inputs[0])

    def text(body, location, size):
        curve = bpy.data.curves.new("Reference caption", "FONT")
        curve.body, curve.size, curve.align_x, curve.align_y = body, size, "CENTER", "CENTER"
        obj = bpy.data.objects.new("Reference caption", curve)
        scene.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = camera.rotation_euler
        curve.materials.append(text_material)

    for item, record in zip(imported, records):
        name = item["source"].stem.replace("_Authored_Atlas", "").replace("_", " ")
        text(name, (record["display_x"], -1.8, 0.25), 0.21)
        text("IMPORTED IDLE" if item["idle"] else "SOURCE REST POSE", (record["display_x"], -2.0, 0.05), 0.115)
    text(args.title, (0, 0, 4.1), 0.22)
    text("Equal display height  |  Original source materials  |  Cycles CPU studio reference", (0, 0, 3.8), 0.13)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(args.output)
    bpy.ops.render.render(write_still=True)
    for item in imported:
        if digest(item["source"]) != item["hash"]:
            raise RuntimeError(f"Source unexpectedly changed during rendering: {item['source']}")
    receipt = {
        "renderer": "Blender Cycles CPU", "blender_version": bpy.app.version_string,
        "samples": args.samples, "denoise": denoise, "size": [args.width, args.height],
        "source_materials_preserved": True, "sources": records,
        "display": "Grounded equal-height studio comparison; not gameplay scale, lighting or runtime performance evidence",
        "output": str(args.output), "output_sha256": digest(args.output),
    }
    args.output.with_suffix(".json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("REFERENCE RENDER COMPLETE: " + str(args.output), flush=True)


if __name__ == "__main__":
    options = arguments()
    try:
        import bpy  # noqa: F401
    except ImportError:
        raise SystemExit(launch(options))
    render(options)
