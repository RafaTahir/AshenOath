extends SceneTree

## Rebase retained mug geometry through the actual imported native sip hand.
## Full actor/Blender carriers remain authoring-only; only one inline scene ships.
const OUTPUT := "res://assets_external/environment_prepared/living_cast/merrow_cup.scn"

func _initialize() -> void:
	call_deferred("_compile")

func _find(node: Node, name_or_class: String) -> Node:
	if str(node.name) == name_or_class or node.is_class(name_or_class):
		return node
	for child: Node in node.get_children():
		var result := _find(child, name_or_class)
		if result != null:
			return result
	return null

func _meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child, result)

func _import(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state) as Node3D

func _point(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[2]), -float(values[1]))

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _compile() -> void:
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var models := repository.path_join("art_source/art_recovery_v2/models/living_cast_stage2_20261107")
	var folder := models.path_join("props")
	var receipt_path := folder.path_join("merrow_cup_calibration.json")
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	var cup_path := folder.path_join("merrow_cup_world.glb")
	if not receipt is Dictionary or not bool(receipt.get("grip_verified", false)) or not bool(receipt.get("rim_calibrated", false)) or str(receipt.get("carrier_sha256", "")) != FileAccess.get_sha256(cup_path):
		_fail("Missing or stale retained Merrow cup calibration")
		return
	for source: Dictionary in receipt.sources:
		if FileAccess.get_sha256(str(source.resource)) != str(source.sha256):
			_fail("Retained cup source changed: " + str(source.resource))
			return
	var actor_path := models.path_join("C10/C10_life_review.glb")
	var actor_receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(models.path_join("C10/authoring.json")))
	if not actor_receipt is Dictionary or str(actor_receipt.get("review_glb_sha256", "")) != FileAccess.get_sha256(actor_path) or str(actor_receipt.get("baseline_sha256", "")) != str(receipt.baseline_sha256):
		_fail("Cup calibration and native Merrow clips no longer share exact retained inputs")
		return
	var clearance_path := models.path_join("C10/source_cup_clearance.json")
	var clearance: Variant = JSON.parse_string(FileAccess.get_file_as_string(clearance_path))
	if not clearance is Dictionary or not bool(clearance.get("source_trajectory_clear", false)) or not bool(clearance.get("full_trajectory_sampled", false)) or str(clearance.get("actor_carrier_sha256", "")) != FileAccess.get_sha256(actor_path) or str(clearance.get("cup_carrier_sha256", "")) != FileAccess.get_sha256(cup_path):
		_fail("Retained cup requires current full-cycle hand/cup/face source clearance")
		return
	var calibration_hash := FileAccess.get_sha256(receipt_path)
	var calibration_archive := folder.path_join("receipts/merrow_cup_calibration_" + calibration_hash + ".json")
	DirAccess.make_dir_recursive_absolute(calibration_archive.get_base_dir())
	if FileAccess.file_exists(calibration_archive):
		if FileAccess.get_sha256(calibration_archive) != calibration_hash:
			_fail("Retained cup calibration archive collision")
			return
	else:
		var archive := FileAccess.open(calibration_archive, FileAccess.WRITE)
		if archive == null:
			_fail("Cannot preserve exact cup calibration input")
			return
		archive.store_buffer(FileAccess.get_file_as_bytes(receipt_path))
		archive.close()
	var actor := _import(actor_path)
	var cup := _import(cup_path)
	if actor == null or cup == null:
		_fail("Cannot import Merrow native actor/cup carriers")
		return
	root.add_child(actor)
	root.add_child(cup)
	var skeleton := _find(actor, "Skeleton3D") as Skeleton3D
	var player := _find(actor, "AnimationPlayer") as AnimationPlayer
	var grip := _find(cup, "ActualHandleGrip") as Node3D
	var rim := _find(cup, "ActualDrinkingRim") as Node3D
	var library := load("res://assets_external/characters_prepared/animations/life_C10.res") as AnimationLibrary
	if skeleton == null or player == null or grip == null or rim == null or library == null or not player.has_animation("Life_Drink") or not player.has_animation("Life_Cup_Hold"):
		_fail("Retained cup requires actual native Drink/Hold clips and measured markers")
		return
	if str(library.get_meta("source_sha256", "")) != FileAccess.get_sha256(actor_path):
		_fail("Merrow palm library is stale relative to the actual native carrier")
		return
	var bone := skeleton.find_bone("hand_r")
	if bone < 0 or not library.has_meta("contact_probes"):
		_fail("Retained cup requires its real right-hand palm binding")
		return
	player.play("Life_Drink")
	player.seek(2.0, true)
	player.advance(0.0)
	skeleton.force_update_all_bone_transforms()
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	var expected := _point(receipt.poses.sip.wrist_world_blender)
	var scale := hand.basis.get_scale().abs()
	var normalized := hand.basis
	for axis in 3:
		normalized[axis] = normalized[axis].normalized()
	var shear := maxf(absf(normalized.x.dot(normalized.y)), maxf(absf(normalized.x.dot(normalized.z)), absf(normalized.y.dot(normalized.z))))
	if not scale.is_finite() or minf(scale.x, minf(scale.y, scale.z)) <= 0.0 or shear > 0.0001 or hand.origin.distance_to(expected) > 0.002 or maxf(scale.x, maxf(scale.y, scale.z))-minf(scale.x, minf(scale.y, scale.z)) > 0.0001:
		_fail("Native cup hand frame differs from source calibration")
		return
	# The closed mug grip has a different evaluated palm patch from the open
	# Work hands. Rebind its independently sampled skin point through Drink.
	var actual_skin := _point(receipt.poses.sip.actual_palm_world_blender)
	var palm := hand.affine_inverse() * actual_skin
	var grip_residual := (hand * palm).distance_to(grip.global_position)
	var lip := _point(receipt.actual_lip.world_blender)
	var rim_residual := rim.global_position.distance_to(lip)
	if not palm.is_finite() or grip_residual > 0.002 or rim_residual > 0.004:
		_fail("Actual retained cup handle/rim contact failed native import")
		return
	var head_bone := skeleton.find_bone("Head")
	if head_bone < 0:
		_fail("Retained cup lip probe has no native Head binding")
		return
	var head_pose := skeleton.global_transform * skeleton.get_bone_global_pose(head_bone)
	var lip_point := head_pose.affine_inverse() * lip
	if not lip_point.is_finite() or lip_point.length() > 0.4:
		_fail("Retained mouth surface does not bind to the actual native head frame")
		return
	var lip_probe := {"bone": "Head", "point": lip_point}
	var grip_probe := {"bone": "hand_r", "point": palm}
	var unscaled_hand := Transform3D(hand.basis.orthonormalized(), hand.origin)
	var scene := Node3D.new()
	scene.name = "MerrowRetainedCup"
	var meshes: Array[MeshInstance3D] = []
	_meshes(cup, meshes)
	for source_mesh: MeshInstance3D in meshes:
		if not source_mesh.mesh is ArrayMesh:
			_fail("Retained cup contains unprepared geometry")
			return
		var part := MeshInstance3D.new()
		part.name = source_mesh.name
		part.mesh = source_mesh.mesh
		part.transform = unscaled_hand.affine_inverse() * source_mesh.global_transform
		scene.add_child(part)
		part.owner = scene
	for marker: Node3D in [grip, rim]:
		var point := Marker3D.new()
		point.name = marker.name
		point.transform = unscaled_hand.affine_inverse() * marker.global_transform
		scene.add_child(point)
		point.owner = scene
	scene.set_meta("story_prop_kind", "cup")
	scene.set_meta("grip_bone", "hand_r")
	scene.set_meta("grip_verified", true)
	scene.set_meta("source_sha256", FileAccess.get_sha256(cup_path))
	scene.set_meta("lip_probe", lip_probe)
	scene.set_meta("grip_probe", grip_probe)
	scene.set_meta("actor_source_sha256", FileAccess.get_sha256(actor_path))
	scene.set_meta("actor_model_sha256", str(actor_receipt.production_sha256))
	scene.set_meta("native_grip_residual", grip_residual)
	scene.set_meta("native_rim_residual", rim_residual)
	var packed := PackedScene.new()
	if packed.pack(scene) != OK:
		_fail("Cannot pack retained cup scene")
		return
	# Runtime checks resource metadata before binding an action-owned prop.
	packed.set_meta("story_prop_kind", "cup")
	packed.set_meta("grip_bone", "hand_r")
	packed.set_meta("grip_verified", true)
	packed.set_meta("source_sha256", FileAccess.get_sha256(cup_path))
	packed.set_meta("lip_probe", lip_probe)
	packed.set_meta("grip_probe", grip_probe)
	packed.set_meta("actor_source_sha256", FileAccess.get_sha256(actor_path))
	packed.set_meta("actor_model_sha256", str(actor_receipt.production_sha256))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS) != OK:
		_fail("Cannot save retained cup scene")
		return
	var report := {"path": OUTPUT, "sha256": FileAccess.get_sha256(OUTPUT),
		"source_sha256": FileAccess.get_sha256(cup_path), "grip_bone": "hand_r",
		"calibration_sha256": calibration_hash, "calibration_archive": calibration_archive,
		"source_clearance_sha256": FileAccess.get_sha256(clearance_path),
		"compiler_sha256": FileAccess.get_sha256("res://tools/build_merrow_cup.gd"),
		"native_hand_residual": hand.origin.distance_to(expected), "native_palm_residual": grip_residual,
		"actual_rim_to_lip_residual": rim_residual, "inline_mesh_count": meshes.size(),
		"lip_probe": lip_probe, "grip_probe":grip_probe, "actor_source_sha256": FileAccess.get_sha256(actor_path),
		"source_coordinate_conversion": "rebased through actual imported Drink hand orthonormal frame",
		"source_full_motion_clearance_verified": true,
		"native_full_motion_clearance_verified": false, "visual_accepted": false, "user_accepted": false}
	var file := FileAccess.open(folder.path_join("merrow_cup_compile.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot record retained cup compilation")
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	scene.free()
	actor.free()
	cup.free()
	print("MERROW_CUP_COMPILED ", OUTPUT)
	quit(0)
