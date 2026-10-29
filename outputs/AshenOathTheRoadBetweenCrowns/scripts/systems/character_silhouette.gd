extends SkeletonModifier3D

## One additive proportion owner, evaluated before work, gaze and hand solvers.
## SkeletonModifier3D restores the animation pose between evaluations; offsets
## never accumulate and shared skins/rests/meshes are never mutated.
const RoleSpec = preload("res://scripts/character_role_spec.gd")
const Palette = preload("res://scripts/systems/character_palette.gd")
const DIRECTORY := "res://assets/characters/silhouette/"
const LAYER_SPECS := {
	"apron_bib": {"mesh":"apron_bib", "socket":"chest", "offset":Vector3(0,0.02,0.17), "channel":"leather"},
	"apron_skirt": {"mesh":"apron_skirt", "socket":"pelvis", "offset":Vector3(0,0.04,0.18), "channel":"leather"},
	"smith_tool": {"scene":"res://assets/characters/forge_hammer.tscn", "socket":"pelvis", "offset":Vector3(0.30,-0.12,0.02), "rotation":Vector3(0,0,155)},
	"cloak": {"mesh":"cloak", "socket":"chest", "offset":Vector3(0,0.10,-0.15), "channel":"primary"},
	"mantle": {"mesh":"mantle", "socket":"chest", "offset":Vector3(0,0.12,-0.08), "channel":"secondary"},
	"satchel": {"mesh":"satchel", "socket":"pelvis", "offset":Vector3(0.27,-0.10,-0.02), "channel":"leather"},
	"hood": {"mesh":"hood", "socket":"head", "offset":Vector3(0,-0.02,-0.025), "channel":"secondary"},
	"helmet": {"mesh":"helmet", "socket":"head", "offset":Vector3(0,0.015,0), "channel":"metal"},
	"pauldron_left": {"mesh":"pauldron_left", "socket":"left_shoulder", "offset":Vector3(0,0.04,0), "channel":"metal"},
	"pauldron_right": {"mesh":"pauldron_right", "socket":"right_shoulder", "offset":Vector3(0,0.04,0), "channel":"metal"},
	"walking_stick": {"mesh":"walking_stick", "socket":"offhand", "offset":Vector3.ZERO, "channel":"leather"},
}
const SOCKETS := {
	"pelvis":["pelvis", "Hips", "hips", "DEF-hips"],
	"chest":["spine_03", "Chest", "chest", "Spine2", "spine_02"],
	"head":["Head", "head", "head_01", "DEF-head"],
	"neck":["neck_01", "Neck", "neck", "DEF-neck"],
	"left_shoulder":["upperarm_l", "UpperArm.L", "LeftArm", "arm_l"],
	"right_shoulder":["upperarm_r", "UpperArm.R", "RightArm", "arm_r"],
	"offhand":["hand_l", "LeftHand", "Hand.L", "Fist.L"],
}
static var _resources: Dictionary = {}
static var _materials: Dictionary = {}

var visual: Node3D
var motion: Node
var profile: Dictionary = {}
var spine_bones: Array[int] = []
var shoulders: Array[Dictionary] = []
var head := -1
var neck := -1
var chest := -1
var rest_weight := 1.0
var skeleton_frame := Transform3D.IDENTITY

static func apply(root: Node3D, role: String, seed: String = "") -> Dictionary:
	var binding := _skeleton_binding(root)
	var skeleton := binding.get("skeleton") as Skeleton3D
	# This system is a human role contract, not a new monster reshaping pass.
	if skeleton == null or _bone(skeleton, ["upperarm_l", "UpperArm.L", "LeftArm"]) < 0 or _bone(skeleton, ["spine_03", "Chest", "Spine2"]) < 0:
		return {}
	var family := str(root.get_meta("character_asset_family", ""))
	if role.contains("ghoul") or role.contains("wretch") or role.begins_with("wychwood_stalker") or role.begins_with("wychwood_raider") or role.begins_with("wychwood_brute") or role.contains("bell_eater") or role.contains("rootbound") or role.contains("ashwing") or role.contains("hart"):
		return {}
	if family.contains("monster"):
		return {}
	var modifier: SkeletonModifier3D = skeleton.get_node_or_null("CharacterSilhouette") as SkeletonModifier3D
	if modifier == null:
		modifier = load("res://scripts/systems/character_silhouette.gd").new()
		modifier.name = "CharacterSilhouette"
		skeleton.add_child(modifier)
		# Later modifiers solve their work/gaze against the proportioned body.
		skeleton.move_child(modifier, 0)
	modifier.configure(root, role, seed, skeleton, binding.frame)
	return root.get_meta("character_silhouette", {})

func configure(body: Node3D, role: String, seed: String, skeleton: Skeleton3D, skeleton_to_body: Transform3D) -> void:
	visual = body
	profile = RoleSpec.silhouette_for_role(role, seed)
	profile.shoulder_width = clampf(float(profile.shoulder_width), 0.85, 1.25)
	profile.head_scale = clampf(float(profile.head_scale), 0.88, 1.12)
	profile.torso_length = clampf(float(profile.torso_length), 0.92, 1.08)
	profile.hunch = clampf(float(profile.hunch), 0.0, 18.0)
	# Prepared destinations configure off-tree, before Godot binds get_skeleton().
	# The assembly supplies both the skeleton and its frame relative to the body.
	if skeleton == null:
		push_error("CharacterSilhouette configuration requires its Skeleton3D")
		return
	var motion_owner: Variant = skeleton.get_meta("character_motion_owner") if skeleton.has_meta("character_motion_owner") else null
	motion = motion_owner.get_ref() if motion_owner is WeakRef else null
	spine_bones.clear()
	shoulders.clear()
	for aliases: Array in [["spine_01", "Spine", "spine"], ["spine_02", "Spine1"], SOCKETS.chest]:
		var index := _bone(skeleton, aliases)
		if index >= 0 and index not in spine_bones:
			spine_bones.append(index)
	head = _bone(skeleton, SOCKETS.head)
	neck = _bone(skeleton, SOCKETS.neck)
	chest = _bone(skeleton, SOCKETS.chest)
	skeleton_frame = Transform3D(Basis.from_scale(body.scale), Vector3.ZERO) * skeleton_to_body
	var lateral := skeleton_frame.basis.inverse() * Vector3.RIGHT
	var center := skeleton_frame * skeleton.get_bone_global_rest(chest).origin
	for slot: String in ["left_shoulder", "right_shoulder"]:
		var index := _bone(skeleton, SOCKETS[slot])
		if index >= 0:
			var point := skeleton_frame * skeleton.get_bone_global_rest(index).origin
			shoulders.append({"bone":index, "offset":lateral * (point.x - center.x) * (float(profile.shoulder_width) - 1.0)})
	var palette := Palette.colors(role, seed, str(body.get_meta("character_region", "")))
	var requested_layers: Array[String] = []
	for requested: String in profile.layers:
		var names: Array = ["apron_bib", "apron_skirt"] if requested == "apron" else [requested]
		for layer: String in names:
			requested_layers.append(layer)
	# Reconfiguration must retire only this owner's obsolete attachments, including
	# the removed cleric hood/mantle on retained or serialized assemblies.
	for child in skeleton.get_children():
		if child.has_meta("silhouette_layer") and str(child.get_meta("silhouette_layer")) not in requested_layers:
			child.free()
	var layers: Array[String] = []
	for layer: String in requested_layers:
		if _attach_layer(skeleton, layer, palette):
			layers.append(layer)
	profile["layers_attached"] = layers
	profile["region"] = str(palette.region)
	profile["identity"] = str(palette.id)
	profile["bone_bindings"] = {"spine":spine_bones.duplicate(), "head":head, "neck":neck, "shoulders":shoulders.size()}
	body.set_meta("character_silhouette", profile.duplicate(true))
	body.set_meta("character_posture", str(profile.posture))
	# Body culling must not leave equipment floating at the requested 20 m check.
	for raw_mesh in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		mesh.visibility_range_end = maxf(mesh.visibility_range_end, 28.0) if mesh.visibility_range_end > 0.0 else 0.0
		if mesh.mesh != null and (mesh.skin != null or mesh.skeleton != NodePath("")):
			if not mesh.has_meta("silhouette_original_aabb"):
				mesh.set_meta("silhouette_original_aabb", mesh.custom_aabb)
			var bounds: AABB = mesh.get_meta("silhouette_original_aabb")
			if bounds.size == Vector3.ZERO:
				bounds = mesh.mesh.get_aabb()
			mesh.custom_aabb = bounds.grow(maxf(bounds.size.length() * 0.12, 0.15))

func bind_motion(driver: Node) -> void:
	motion = driver

func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not is_instance_valid(visual):
		return
	# Fixed proportion offsets remain during actions; only the rest posture yields.
	for index: int in spine_bones:
		var position := skeleton.get_bone_pose_position(index)
		skeleton.set_bone_pose_position(index, position * float(profile.torso_length))
	for shoulder: Dictionary in shoulders:
		var index := int(shoulder.bone)
		var parent := skeleton.get_bone_parent(index)
		var frame := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var offset: Vector3 = frame.inverse() * (shoulder.offset as Vector3)
		skeleton.set_bone_pose_position(index, skeleton.get_bone_pose_position(index) + offset)
	if head >= 0:
		skeleton.set_bone_pose_scale(head, skeleton.get_bone_pose_scale(head) * float(profile.head_scale))
	var resting := true
	if is_instance_valid(motion):
		resting = not bool(motion.dead) and not bool(motion.distance_suspended) and not motion.has_active_action() and float(motion.current_speed_mps) < 0.08 and str(motion.locomotion_state) == "idle" and not bool(motion.story_dialogue_active)
		var life: Variant = motion.life_modifier
		if life != null and (str(life.activity) != "" or str(life.carried_activity) != ""):
			resting = false
		var stowed := skeleton.get_node_or_null("SilhouetteEquipment_smith_tool") as Node3D
		if stowed != null:
			# One visible hammer: the existing work solver owns the held tool.
			stowed.visible = life == null or str(life.tool_kind) != "hammer" or not is_instance_valid(life.tool) or not life.tool.visible
	rest_weight = move_toward(rest_weight, 1.0 if resting else 0.0, minf(delta, 0.1) * 5.0)
	if rest_weight < 0.001:
		return
	var posture: Dictionary = RoleSpec.POSTURES.get(str(profile.posture), RoleSpec.POSTURES.upright)
	var pitch := clampf(float(profile.hunch) + float(posture.spine), 0.0, 18.0)
	# Noble/upright extension is small and separate from the forward hunch limit.
	if float(profile.hunch) == 0.0:
		pitch = float(posture.spine)
	for index: int in spine_bones:
		_rotate(skeleton, index, Vector3.RIGHT, deg_to_rad(pitch) * rest_weight / maxf(spine_bones.size(), 1.0))
	_rotate(skeleton, neck, Vector3.RIGHT, deg_to_rad(float(posture.neck)) * rest_weight)
	_rotate(skeleton, chest, Vector3.FORWARD, deg_to_rad(float(posture.roll)) * rest_weight)

func _rotate(skeleton: Skeleton3D, index: int, axis: Vector3, angle: float) -> void:
	if index < 0 or absf(angle) < 0.00001:
		return
	var basis := skeleton_frame.basis * skeleton.get_bone_global_pose(index).basis
	var local_axis := (basis.inverse() * axis).normalized()
	skeleton.set_bone_pose_rotation(index, (skeleton.get_bone_pose_rotation(index) * Quaternion(local_axis, angle)).normalized())

func _attach_layer(skeleton: Skeleton3D, layer: String, palette: Dictionary) -> bool:
	var name := "SilhouetteEquipment_" + layer
	if skeleton.get_node_or_null(name) != null:
		return true
	# The cleric already has one authoritative hand-held staff. Do not add a second.
	if layer == "walking_stick" and (visual.find_child("AnwenStaffSocket", true, false) != null or visual.find_child("OccupationEquipmentSocket", true, false) != null):
		return true
	var definition: Dictionary = LAYER_SPECS[layer]
	var socket := str(definition.socket)
	var index := _bone(skeleton, SOCKETS[socket])
	if index < 0:
		push_error("Silhouette socket missing: %s / %s" % [str(profile.archetype), socket])
		return false
	var path := str(definition.get("scene", DIRECTORY + str(definition.get("mesh", "")) + ".obj"))
	if not _resources.has(path):
		_resources[path] = load(path)
	var resource: Resource = _resources[path]
	if resource == null:
		push_error("Silhouette asset missing: " + path)
		return false
	var attachment := BoneAttachment3D.new()
	attachment.name = name
	attachment.bone_name = skeleton.get_bone_name(index)
	attachment.bone_idx = index
	skeleton.add_child(attachment)
	var pivot := Node3D.new()
	pivot.name = "FittedLayer"
	attachment.add_child(pivot)
	var rest := skeleton_frame * skeleton.get_bone_global_rest(index)
	var point := rest.origin + (definition.offset as Vector3)
	var orientation := Basis.from_euler((definition.get("rotation", Vector3.ZERO) as Vector3) * PI / 180.0)
	var factor := Vector3.ONE
	if socket == "chest":
		factor.x = float(profile.shoulder_width)
	if layer == "apron_bib":
		var pelvis_index := _bone(skeleton, SOCKETS.pelvis)
		if pelvis_index >= 0:
			var waist := (skeleton_frame * skeleton.get_bone_global_rest(pelvis_index)).origin
			factor.y = maxf(rest.origin.y - waist.y + 0.02, 0.25) / 0.31
	# Fit in metres through the actual rest frame, not an unbounded global inverse.
	pivot.transform = rest.affine_inverse() * Transform3D(orientation.scaled(factor), point)
	if resource is PackedScene:
		pivot.add_child((resource as PackedScene).instantiate())
	elif resource is Mesh:
		var piece := MeshInstance3D.new()
		piece.name = "RoleShape_" + layer
		piece.mesh = resource as Mesh
		piece.material_override = _material(palette, str(definition.get("channel", "primary")))
		piece.visibility_range_end = 28.0
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(piece)
	else:
		attachment.free()
		push_error("Silhouette asset is not a mesh or scene: " + path)
		return false
	attachment.set_meta("silhouette_layer", layer)
	return true

static func _material(palette: Dictionary, channel: String) -> StandardMaterial3D:
	var color: Color = palette[channel]
	var key := channel + color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.57 if channel == "metal" else 0.90
		material.metallic = 0.45 if channel == "metal" else 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = material
	return _materials[key]

static func _bone(skeleton: Skeleton3D, aliases: Array) -> int:
	for alias: String in aliases:
		var index := skeleton.find_bone(alias)
		if index >= 0:
			return index
	return -1

static func _skeleton_binding(node: Node) -> Dictionary:
	if node is Skeleton3D:
		return {"skeleton":node, "frame":Transform3D.IDENTITY}
	for child in node.get_children():
		var found := _skeleton_binding(child)
		if not found.is_empty():
			# Compose only the selected descendant path, excluding the visual root.
			# Local transforms also work before tree entry and across plain Nodes.
			if child is Node3D:
				found.frame = (child as Node3D).transform * (found.frame as Transform3D)
			return found
	return {}
