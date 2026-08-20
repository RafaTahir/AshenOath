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

func configure(root: Node3D, role: String) -> bool:
	character_root = root
	role_id = role
	eye_meshes.clear()
	brow_meshes.clear()
	base_eye_scales.clear()
	base_eye_positions.clear()
	native_face_surface_count = 0
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var token := str(mesh.name).to_lower()
		var surface_count: int = mesh.mesh.get_surface_count()
		if token.contains("head") or token.contains("face") or token.contains("skin") or token.contains("body") or token.contains("skull") or token.contains("jaw") or token.contains("mouth") or token.contains("teeth"):
			native_face_surface_count += surface_count
		if token.contains("eye") and not token.contains("brow"):
			eye_meshes.append(mesh)
			base_eye_scales[mesh] = mesh.scale
			base_eye_positions[mesh] = mesh.position
		elif token.contains("brow"):
			brow_meshes.append(mesh)
	valid = not eye_meshes.is_empty() or native_face_surface_count > 0
	next_blink = 1.8 + float(absi(role_id.hash()) % 180) / 100.0
	set_process(valid)
	return valid

func _process(delta: float) -> void:
	if not valid or character_root == null:
		return
	update_accumulator += delta
	if update_accumulator < (0.10 if role_id in ["sister_anwen", "mira", "rook"] else 0.12):
		return
	var step := update_accumulator
	update_accumulator = 0.0
	if focus_target == null or not is_instance_valid(focus_target):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0] is Node3D:
			focus_target = players[0] as Node3D
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
		"native_face_surface_count": native_face_surface_count,
		"native_eye_mesh_count": eye_meshes.size(),
		"native_brow_mesh_count": brow_meshes.size(),
		"synthetic_geometry_created": false,
		"blink_enabled": not eye_meshes.is_empty(),
		"eye_focus_enabled": not eye_meshes.is_empty(),
	}

func set_focus_target(target: Node3D) -> void:
	focus_target = target
