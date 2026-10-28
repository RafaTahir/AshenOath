extends SceneTree
## Numerical ownership/transform checks; no captures, journey, or save writes.
## Explicit fixture transforms are the oracle, independently of scene traversal.

const Silhouette = preload("res://scripts/systems/character_silhouette.gd")
const ROLE := "blacksmith_tor"
const BODY_SCALE := Vector3(1.3, 0.85, 1.1)
const CHEST_REST := Vector3(0, 1.4, 0)
const PELVIS_REST := Vector3(0, 0.8, 0)

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

class Motion extends Node:
	var dead := false
	var distance_suspended := false
	var current_speed_mps := 0.0
	var locomotion_state := "idle"
	var story_dialogue_active := false
	var life_modifier: Node
	func has_active_action() -> bool: return false

var checks := 0
var failures: Array[String] = []
var error_log := ErrorLog.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.add_logger(error_log)
	_verify_hierarchy(false)
	_verify_hierarchy(true)
	_verify_root_skeleton(false)
	_verify_root_skeleton(true)
	_verify_explicit_configuration()
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "no engine or script errors during binding verification")
	for error: String in error_log.errors:
		print("SILHOUETTE BINDINGS ENGINE ERROR: " + error)
	Silhouette._resources.clear()
	Silhouette._materials.clear()
	print("SILHOUETTE BINDINGS: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _skeleton() -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = "FixtureSkeleton"
	var names := ["Hips", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "upperarm_l", "upperarm_r", "hand_l"]
	var parents := [-1, 0, 1, 2, 3, 4, 3, 3, 6]
	var positions := [PELVIS_REST, Vector3(0, 0.2, 0), Vector3(0, 0.2, 0), Vector3(0, 0.2, 0), Vector3(0, 0.15, 0), Vector3(0, 0.15, 0), Vector3(-0.3, 0, 0), Vector3(0.3, 0, 0), Vector3(-0.35, -0.2, 0)]
	for name: String in names: skeleton.add_bone(name)
	for index in names.size():
		skeleton.set_bone_parent(index, int(parents[index]))
		skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, positions[index]))
	skeleton.reset_bone_poses()
	return skeleton

func _body_transform() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.1, 0.65, -0.2)) * Basis.from_scale(BODY_SCALE), Vector3(12, 3, -7))

func _fixture(in_tree: bool, root_skeleton: bool = false) -> Dictionary:
	var placement := Node3D.new()
	placement.transform = Transform3D(Basis(Vector3.UP, -0.9), Vector3(-40, 6, 30))
	var body: Node3D = _skeleton() if root_skeleton else Node3D.new()
	body.name = "Visual"
	body.transform = _body_transform()
	body.set_meta("character_region", "greyfen")
	placement.add_child(body)
	var skeleton := body as Skeleton3D
	var relative := Transform3D.IDENTITY
	if not root_skeleton:
		# A failed earlier search branch and a later skeleton must not affect the
		# selected branch's frame or receive equipment intended for this skeleton.
		var unrelated := Node3D.new()
		unrelated.transform = Transform3D(Basis.from_scale(Vector3(7, 8, 9)), Vector3(90, -30, 80))
		body.add_child(unrelated)
		unrelated.add_child(Node3D.new())
		var a := Node3D.new()
		var a_transform := Transform3D(Basis(Vector3.RIGHT, 0.3) * Basis.from_scale(Vector3(1.2, 1.5, 0.8)), Vector3(0.4, 0.2, -0.3))
		a.transform = a_transform
		body.add_child(a)
		var wrapper := Node.new()
		a.add_child(wrapper)
		var b := Node3D.new()
		var b_transform := Transform3D(Basis(Vector3.BACK, -0.4) * Basis.from_scale(Vector3(0.9, 1.1, 1.3)), Vector3(-0.2, 0.1, 0.5))
		b.transform = b_transform
		wrapper.add_child(b)
		skeleton = _skeleton()
		var skeleton_transform := Transform3D(Basis(Vector3.UP, 0.2) * Basis.from_scale(Vector3(1.1, 0.95, 0.85)), Vector3(0.1, -0.05, 0.2))
		skeleton.transform = skeleton_transform
		b.add_child(skeleton)
		relative = a_transform * b_transform * skeleton_transform
		var later := _skeleton()
		later.name = "LaterSkeleton"
		body.add_child(later)
	var motion := Motion.new()
	body.add_child(motion)
	skeleton.set_meta("character_motion_owner", weakref(motion))
	if in_tree: root.add_child(placement)
	return {"placement":placement, "body":body, "skeleton":skeleton, "motion":motion,
		"relative":relative, "frame":Transform3D(Basis.from_scale(BODY_SCALE), Vector3.ZERO) * relative}

func _verify_hierarchy(in_tree: bool) -> void:
	var f := _fixture(in_tree)
	var label := "in-tree hierarchy" if in_tree else "off-tree hierarchy"
	var binding: Dictionary = Silhouette._skeleton_binding(f.body)
	_check(binding.get("skeleton") == f.skeleton, label + " selects the first descendant skeleton")
	_check(_same_transform(binding.frame, f.relative), label + " composes only explicit A * B * skeleton transforms across the plain Node wrapper")
	_verify_configuration(f, label, in_tree)
	_check(f.body.get_node("LaterSkeleton").get_node_or_null("CharacterSilhouette") == null, label + " leaves later skeletons untouched")
	f.placement.free()

func _verify_root_skeleton(in_tree: bool) -> void:
	var f := _fixture(in_tree, true)
	var label := "in-tree root skeleton" if in_tree else "off-tree root skeleton"
	var binding: Dictionary = Silhouette._skeleton_binding(f.body)
	_check(binding.get("skeleton") == f.body and _same_transform(binding.frame, Transform3D.IDENTITY), label + " has an identity relative frame")
	_verify_configuration(f, label, in_tree)
	f.placement.free()

func _verify_configuration(f: Dictionary, label: String, sample_pose: bool) -> void:
	var skeleton: Skeleton3D = f.skeleton
	var rest := _rests(skeleton)
	var contract: Dictionary = Silhouette.apply(f.body, ROLE, "binding_fixture")
	var modifier := skeleton.get_node_or_null("CharacterSilhouette") as SkeletonModifier3D
	_check(modifier != null, label + " installs a silhouette modifier")
	if modifier == null: return
	modifier.active = false
	_check(modifier.visual == f.body and modifier.motion == f.motion, label + " binds the supplied body and explicit motion owner")
	_check(_same_transform(modifier.skeleton_frame, f.frame), label + " preserves body scale while excluding body and ancestor translation/rotation")
	_check(contract.archetype == "blacksmith" and contract.shoulder_width == 1.25 and contract.head_scale == 0.98 and contract.torso_length == 0.92, label + " retains authored role proportions")
	_check(modifier.spine_bones == [1, 2, 3] and modifier.head == 5 and modifier.neck == 4 and modifier.chest == 3, label + " retains explicit anatomical bone bindings")
	_check(modifier.shoulders.size() == 2, label + " binds both shoulders")
	var chest_point: Vector3 = f.frame * CHEST_REST
	for shoulder: Dictionary in modifier.shoulders:
		var authored_point := Vector3(-0.3 if int(shoulder.bone) == 6 else 0.3, 1.4, 0)
		var spread: Vector3 = f.frame.basis * (shoulder.offset as Vector3)
		var expected_spread := Vector3(((f.frame as Transform3D) * authored_point).x - chest_point.x, 0, 0) * 0.25
		_check(spread.is_equal_approx(expected_spread), label + " shoulder offset preserves authored body-space width: " + str(shoulder.bone))
	_check(contract.layers_attached == ["apron_bib", "apron_skirt", "smith_tool"], label + " loads the real blacksmith layers")
	var before_layers := _layers(skeleton)
	_verify_equipment(f, label)
	if sample_pose:
		_verify_pose(modifier, skeleton, label)
	var repeated: Dictionary = Silhouette.apply(f.body, ROLE, "binding_fixture")
	_check(skeleton.get_node("CharacterSilhouette") == modifier and repeated == contract, label + " repeated apply preserves modifier and role contract")
	_check(_layers(skeleton) == before_layers, label + " repeated apply neither duplicates nor refits attached equipment")
	_check(_rests(skeleton) == rest, label + " configuration and pose sampling leave authored bone rests unchanged")

func _verify_equipment(f: Dictionary, label: String) -> void:
	var skeleton: Skeleton3D = f.skeleton
	var frame: Transform3D = f.frame
	var chest := frame * Transform3D(Basis.IDENTITY, CHEST_REST)
	var pelvis := frame * Transform3D(Basis.IDENTITY, PELVIS_REST)
	var bib := skeleton.get_node_or_null("SilhouetteEquipment_apron_bib/FittedLayer") as Node3D
	var skirt := skeleton.get_node_or_null("SilhouetteEquipment_apron_skirt/FittedLayer") as Node3D
	var hammer := skeleton.get_node_or_null("SilhouetteEquipment_smith_tool/FittedLayer") as Node3D
	_check(bib != null and skirt != null and hammer != null, label + " attaches all fitted pivots")
	if bib == null or skirt == null or hammer == null: return
	var fitted_bib := chest * bib.transform
	var fitted_skirt := pelvis * skirt.transform
	var fitted_hammer := pelvis * hammer.transform
	_check(fitted_bib.origin.is_equal_approx(chest.origin + Vector3(0, 0.02, 0.17)) and fitted_skirt.origin.is_equal_approx(pelvis.origin + Vector3(0, 0.04, 0.18)), label + " apron offsets remain in authored body-space metres")
	var bib_height := maxf(chest.origin.y - pelvis.origin.y + 0.02, 0.25) / 0.31
	_check(fitted_bib.basis.is_equal_approx(Basis.from_scale(Vector3(1.25, bib_height, 1))) and fitted_skirt.basis.is_equal_approx(Basis.IDENTITY), label + " apron fitting preserves authored width, height and orientation")
	_check(fitted_hammer.origin.is_equal_approx(pelvis.origin + Vector3(0.30, -0.12, 0.02)) and fitted_hammer.basis.is_equal_approx(Basis(Vector3.BACK, deg_to_rad(155.0))), label + " real hammer scene retains its authored offset and rotation")
	var bib_mesh := bib.get_node_or_null("RoleShape_apron_bib") as MeshInstance3D
	_check(bib_mesh != null and bib_mesh.mesh != null and bib_mesh.material_override is StandardMaterial3D and bib_mesh.visibility_range_end == 28.0, label + " fitted OBJ layer retains its material and visibility contract")
	_check(hammer.get_node_or_null("ForgeHammer/Handle") is MeshInstance3D and hammer.get_node_or_null("ForgeHammer/ForgedHead") is MeshInstance3D, label + " fitted tool is the actual authored hammer scene")

func _verify_pose(modifier: SkeletonModifier3D, skeleton: Skeleton3D, label: String) -> void:
	_check(modifier.get_skeleton() == skeleton, label + " runtime modifier binds the same injected skeleton")
	skeleton.reset_bone_poses()
	modifier._process_modification_with_delta(0.0)
	for index in [1, 2, 3]:
		_check(skeleton.get_bone_pose_position(index).is_equal_approx(Vector3(0, 0.184, 0)), label + " sampled torso keeps the authored 0.92 proportion: " + str(index))
	_check(skeleton.get_bone_pose_scale(5).is_equal_approx(Vector3.ONE * 0.98), label + " sampled head keeps the authored 0.98 scale")
	for shoulder: Dictionary in modifier.shoulders:
		var original := Vector3(-0.3 if int(shoulder.bone) == 6 else 0.3, 0, 0)
		_check(skeleton.get_bone_pose_position(int(shoulder.bone)).is_equal_approx(original + (shoulder.offset as Vector3)), label + " sampled shoulder applies the fitted offset once: " + str(shoulder.bone))
	var sampled := _poses(skeleton)
	skeleton.reset_bone_poses()
	modifier._process_modification_with_delta(0.0)
	_check(_poses(skeleton) == sampled, label + " resampling a restored animation pose does not accumulate offsets")

func _verify_explicit_configuration() -> void:
	var f := _fixture(false)
	var modifier := Silhouette.new()
	# An unattached modifier has no ancestor to discover; configuration relies
	# on the explicit skeleton and frame supplied by the assembly.
	modifier.configure(f.body, "villager_human", "binding_fixture", f.skeleton, f.relative)
	_check(modifier.visual == f.body and modifier.motion == f.motion and modifier.chest == 3 and modifier.head == 5, "unparented configuration consumes the explicitly injected skeleton")
	_check(_same_transform(modifier.skeleton_frame, f.frame), "unparented configuration consumes the explicitly injected frame")
	_check(modifier.profile.layers_attached.is_empty(), "explicit generic-human configuration does not invent equipment")
	modifier.free()
	f.placement.free()

func _layers(skeleton: Skeleton3D) -> Dictionary:
	var result := {}
	for child in skeleton.get_children():
		if child is BoneAttachment3D and child.has_meta("silhouette_layer"):
			var pivot := child.get_node("FittedLayer") as Node3D
			result[str(child.name)] = [child.get_instance_id(), pivot.transform, child.bone_idx, pivot.get_child_count()]
	return result

func _rests(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index in skeleton.get_bone_count(): result.append(skeleton.get_bone_rest(index))
	return result

func _poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index in skeleton.get_bone_count(): result.append(skeleton.get_bone_pose(index))
	return result

func _same_transform(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.is_equal_approx(b.origin) and a.basis.is_equal_approx(b.basis)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)
