extends Node

## Lightweight native-face presentation layer.
## It only animates imported eye meshes that already belong to the character
## asset. It never creates face cards, eye boxes, hair meshes, or other anatomy.

var character_root: Node3D
var role_id := ""
var eye_meshes: Array[MeshInstance3D] = []
var brow_meshes: Array[MeshInstance3D] = []
var base_eye_scales: Dictionary = {}
var base_eye_positions: Dictionary = {}
var native_face_surface_count := 0
var update_accumulator := 0.0
var blink_remaining := 0.0
var next_blink := 2.4
var focus_target: Node3D
var look_offset := 0.0
var valid := false
var update_timer: Timer
var update_interval := 0.12
var distance_suspended := false
var focus_refresh_remaining := 0.0

const NATIVE_MONSTER_ROLES := [
	"ghoulkin",
	"wychwood_stalker",
	"wychwood_raider",
	"wychwood_brute",
	"bog_wretch",
	"gravebound_knight",
	"bell_eater",
	"rootbound_colossus",
	"ashwing",
	"halvern_boss",
	"white_hart_avatar",
]

func configure(root: Node3D, role: String) -> bool:
	character_root = root
	role_id = role
	eye_meshes.clear()
	brow_meshes.clear()
	base_eye_scales.clear()
	base_eye_positions.clear()
	native_face_surface_count = 0
	focus_refresh_remaining = 0.0
	var approved_complete_family := (
		str(root.get_meta("character_asset_family", "")) in ["quaternius_animated_humanoid", "quaternius_ranger"]
		or role_id in NATIVE_MONSTER_ROLES
	)
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var token := str(mesh.name).to_lower()
		var surface_count: int = mesh.mesh.get_surface_count()
		var material_token := ""
		for surface_index in range(surface_count):
			var material = mesh.get_surface_override_material(surface_index)
			if material == null:
				material = mesh.mesh.surface_get_material(surface_index)
			material_token += " %s" % str(material.resource_name).to_lower() if material != null else ""
		var face_token := "%s %s" % [token, material_token]
		if face_token.contains("head") or face_token.contains("face") or face_token.contains("skin") or face_token.contains("body") or face_token.contains("skull") or face_token.contains("jaw") or face_token.contains("mouth") or face_token.contains("teeth") or face_token.contains("eye") or face_token.contains("brow") or (approved_complete_family and (mesh.skin != null or mesh.skeleton != NodePath(""))) or (role_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "ghoulkin_skeleton"] and face_token.contains("skeleton")):
			native_face_surface_count += surface_count
		if token.contains("eye") and not token.contains("brow"):
			eye_meshes.append(mesh)
			base_eye_scales[mesh] = mesh.scale
			base_eye_positions[mesh] = mesh.position
		elif token.contains("brow"):
			brow_meshes.append(mesh)
	valid = not eye_meshes.is_empty() or native_face_surface_count > 0
	next_blink = 1.8 + float(absi(role_id.hash()) % 180) / 100.0
	update_interval = 0.10 if role_id in ["sister_anwen", "mira", "rook"] else 0.12
	if update_timer == null:
		update_timer = Timer.new()
		update_timer.name = "CharacterFaceTick"
		update_timer.one_shot = false
		update_timer.process_callback = Timer.TIMER_PROCESS_IDLE
		update_timer.timeout.connect(_on_update_timer_timeout)
		add_child(update_timer)
	update_timer.wait_time = update_interval
	if valid:
		var phase_delay := float(absi((role_id + str(root.get_instance_id())).hash()) % 1000) / 1000.0 * update_interval
		if is_inside_tree():
			update_timer.start(update_interval + phase_delay)
		else:
			call_deferred("_start_update_timer", update_interval + phase_delay)
	return valid

func _start_update_timer(delay: float) -> void:
	if update_timer != null and valid and is_inside_tree():
		update_timer.start(delay)

func _on_update_timer_timeout() -> void:
	if not valid or character_root == null:
		return
	if distance_suspended:
		return
	var step := update_interval
	if focus_target == null or not is_instance_valid(focus_target):
		focus_refresh_remaining -= step
		if focus_refresh_remaining <= 0.0:
			focus_refresh_remaining = 0.75
			var player_node := get_tree().get_first_node_in_group("player") as Node3D
			focus_target = player_node
	if focus_target != null:
		var to_target := focus_target.global_position + Vector3.UP * 1.18 - character_root.global_position - Vector3.UP * 1.35
		to_target.y = 0.0
		if to_target.length_squared() > 0.04 and to_target.length() < 10.0:
			var local_target := character_root.global_transform.basis.inverse() * to_target.normalized()
			look_offset = lerpf(look_offset, clampf(local_target.x, -1.0, 1.0), 1.0 - exp(-7.0 * step))
			_apply_eye_look()
	else:
		look_offset = lerpf(look_offset, 0.0, 1.0 - exp(-4.0 * step))
		_apply_eye_look()
	if blink_remaining > 0.0:
		blink_remaining = maxf(blink_remaining - step, 0.0)
		var blink_progress := 1.0 - blink_remaining / 0.14
		var closure := sin(blink_progress * PI)
		_apply_blink(closure)
	else:
		next_blink -= step
		_apply_blink(0.0)
		if next_blink <= 0.0:
			blink_remaining = 0.14
			next_blink = 2.2 + float(absi((role_id + str(Time.get_ticks_msec())).hash()) % 220) / 100.0

func set_distance_suspended(suspended: bool) -> void:
	distance_suspended = suspended
	if update_timer != null:
		update_timer.paused = suspended

func _apply_eye_look() -> void:
	for mesh in eye_meshes:
		if not is_instance_valid(mesh):
			continue
		var base: Vector3 = base_eye_positions.get(mesh, mesh.position)
		mesh.position = base + Vector3.RIGHT * look_offset * 0.006

func _apply_blink(closure: float) -> void:
	for mesh in eye_meshes:
		if not is_instance_valid(mesh):
			continue
		var base: Vector3 = base_eye_scales.get(mesh, mesh.scale)
		mesh.scale = Vector3(base.x, lerpf(base.y, maxf(base.y * 0.12, 0.001), closure), base.z)

func get_contract_report() -> Dictionary:
	return {
		"valid": valid,
		"role": role_id,
		"contract_kind": "monster_native_anatomy" if role_id in NATIVE_MONSTER_ROLES else "human_native_face",
		"native_face_surface_count": native_face_surface_count,
		"native_eye_mesh_count": eye_meshes.size(),
		"native_brow_mesh_count": brow_meshes.size(),
		"synthetic_geometry_created": false,
		"blink_enabled": not eye_meshes.is_empty(),
		"eye_focus_enabled": not eye_meshes.is_empty(),
	}

func set_focus_target(target: Node3D) -> void:
	focus_target = target
	focus_refresh_remaining = 0.75
