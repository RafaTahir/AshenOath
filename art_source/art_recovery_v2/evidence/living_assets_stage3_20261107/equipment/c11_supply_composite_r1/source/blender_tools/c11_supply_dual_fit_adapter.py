"""Retain both native C11 owners for one shared supply clearance candidate."""
from collections import Counter
from pathlib import Path

from inspect_c11_route_carrier import load_contract as load_route_contract
from inspect_living_activity_carrier import check_mesh_inventory, check_topology, digest, require

IDLE = "Authoring_Carry_Idle"
ROUTE = "Authoring_Carry_Scheduler_Route"
EXPECTED = {IDLE: 301, ROUTE: 959}


def compare_body_contract(standing, standing_plans, route, route_plans):
    for key in ("retained_skin_manifest_sha256", "retained_rigid_channels_sha256", "normalized_visual_frame",
                "skeleton_frame", "retained_visible_mesh_paths", "retained_animation_fingerprints"):
        require(standing[key] == route[key], "Retained standing and route body contract differs: " + key)
    require(len(standing_plans) == 1 and set(standing_plans) == set(route_plans), "C11 body inventories differ")
    name, = standing_plans
    for key in ("rows", "faces", "joint_names", "joint_parents", "joint_worlds", "world"):
        require(standing_plans[name][key] == route_plans[name][key], "Standing and route mesh binding differs: " + key)


def route_visibility(clip):
    samples = clip["hand_samples"]
    require(clip["clip"] == ROUTE and clip["frames"] == len(samples) == 1081, "Native route inventory changed")
    require(all(type(row["prop_visible"]) is bool for row in samples), "Native visibility must be explicit on all route frames")
    visible = [index for index, row in enumerate(samples) if row["prop_visible"]]
    require(visible == [*range(121, 784), *range(785, 1081)], "Native route visibility boundaries changed")
    early = [index for index in visible if samples[index]["pose_weight"] < .95]
    require(not early and all(samples[index]["pose_weight"] == 1.0 for index in visible), "An early native socket became visible")
    require(sum(samples[index]["speed_mps"] > .05 for index in visible) == 663, "Visible route movement coverage changed")
    return {"native_frames": len(samples), "visible_frames": len(visible), "visible_departure_ramp_frames": len(early),
            "first_visible_frame": visible[0], "arrival_visible_frame": 785}


def checked_route_inputs(args, standing, standing_plans, blender_version, read_json):
    route, _, plans, paths = load_route_contract(args.route_receipt)
    compare_body_contract(standing, standing_plans, route, plans)
    proof = read_json(args.route_blender_proof)
    require(proof["verified"] is True and proof["blender_version"] == blender_version and
            Counter(row["clip"] for row in proof["samples"]) == Counter({ROUTE: 5}),
            "All five actual Blender route fidelity phases are required")
    require(proof["source_sha256"].get(str(paths["carrier"])) == digest(paths["carrier"]), "Route proof binds a different carrier")
    for name, expected in proof["source_sha256"].items():
        require(Path(name).is_file() and digest(name) == expected, "Route import proof input changed: " + name)
    row, = route["clips"]
    frozen = {str(path): digest(path) for path in (args.route_blender_proof, *paths.values(), Path(__file__))}
    return row, plans, paths, frozen, route_visibility(row)


def import_route_actor(bpy, scene, paths, plans, options, standing_objects, standing_faces):
    old_names = {obj: obj.name for obj in standing_objects}
    for index, obj in enumerate(standing_objects):
        obj.name = f"C11_StandingReview_{index:02d}"
    before = set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(paths["carrier"]), **options)
    objects = [obj for obj in scene.objects if obj not in before]
    meshes = {obj.name: obj for obj in objects if obj.type == "MESH"}
    check_mesh_inventory(list(meshes), plans)
    name, = plans
    body = meshes[name]
    require(len(body.modifiers) == 1 and body.modifiers[0].type == "ARMATURE", "Actual route armature owner changed")
    rig = body.modifiers[0].object
    require(rig and rig.pose.bones.get("hand_r"), "Actual route right hand is missing")
    faces = [tuple(poly.vertices) for poly in body.data.polygons]
    check_topology(plans[name], faces)
    require(faces == standing_faces and len(body.data.vertices) == len(plans[name]["rows"]),
            "Standing and actual route do not share the same wound triangle identities")
    return (objects, body, rig), old_names


def remove_route_actor(bpy, route_actor, standing_names):
    for obj in route_actor[0]:
        bpy.data.objects.remove(obj, do_unlink=True)
    for obj, name in standing_names.items():
        obj.name = name
        require(obj.name == name, "Standing review object name could not be restored")
