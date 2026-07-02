extends SceneTree

var failures: Array[String] = []
var game: Node = null

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("main scene failed to load")
		_finish()
		return
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _settle_frames(4)
	_check_greyfen_visible_quality()
	_check_player_locomotion_animation()
	_check_sword_animation()
	_check_wychwood_visible_quality()
	_finish()

func _check_greyfen_visible_quality() -> void:
	game.call("_load_zone", "greyfen", Vector3(0, 1, 7))
	await _settle_frames(4)
	_check_non_white_materials(game.zone_root, "greyfen")
	_check_house_presence()
	_check_route_clearance("greyfen")
	_check_cemetery_shell()

func _check_wychwood_visible_quality() -> void:
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _settle_frames(6)
	_check_non_white_materials(game.zone_root, "wychwood")
	_check_route_clearance("wychwood")
	_check_ghoulkin_material()

func _check_non_white_materials(root_node: Node, zone_id: String) -> void:
	for mesh in _collect_meshes(root_node):
		var key = _keyword_path(mesh)
		if not _is_required_visible_keyword(key):
			continue
		if _mesh_has_bad_material(mesh):
			_fail("%s visible mesh has bad white/default material: %s" % [zone_id, _node_path(mesh)])

func _check_house_presence() -> void:
	var valid_houses = 0
	for node in get_nodes_in_group("greyfen_house"):
		if not (node is Node3D):
			continue
		var pos = (node as Node3D).global_position
		if pos.z < -13.8 or pos.z > 13.8 or abs(pos.x) < 3.1:
			continue
		var has_roof = false
		var has_wall = false
		var bad_piece = false
		for mesh in _collect_meshes(node):
			var key = _keyword_path(mesh)
			if key.contains("roof"):
				has_roof = true
			if key.contains("wall") or key.contains("plaster"):
				has_wall = true
			if _mesh_has_bad_material(mesh):
				bad_piece = true
		if has_roof and has_wall and not bad_piece:
			valid_houses += 1
	if valid_houses < 3:
		_fail("Greyfen needs at least 3 valid non-white visible houses; found %d" % valid_houses)

func _check_cemetery_shell() -> void:
	var section = game.zone_root.find_child("GreyfenCemeterySection", true, false)
	if section == null:
		_fail("Greyfen cemetery section shell is missing")
		return
	for required_name in [
		"CemeteryEntry", "SisterAnwenCemeteryStage", "CemeteryEncounterStage",
		"CrowShrineStage", "RuinedCrowChapelBackWall", "RuinedCrowChapelRoof",
		"OssuarySealedDoor", "CemeteryNorthWall", "CemeterySouthWall", "CemeteryEastWall",
	]:
		if game.zone_root.find_child(required_name, true, false) == null:
			_fail("cemetery shell is missing required node: %s" % required_name)
	var chapel_wall = game.zone_root.find_child("RuinedCrowChapelBackWall", true, false)
	if chapel_wall != null and not _has_collision_shape(chapel_wall):
		_fail("ruined chapel wall has no collision")
	var entry = game.zone_root.find_child("CemeteryEntry", true, false)
	if entry is Node3D:
		var entry_pos = (entry as Node3D).global_position
		if entry_pos.x > 11.0 or entry_pos.z < 6.0 or entry_pos.z > 10.5:
			_fail("cemetery entry staging point is outside the accessible Greyfen approach")

func _has_collision_shape(node: Node) -> bool:
	if node is CollisionShape3D and (node as CollisionShape3D).shape != null:
		return true
	for child in node.get_children():
		if _has_collision_shape(child):
			return true
	return false

func _check_route_clearance(zone_id: String) -> void:
	for node in _collect_route_blockers(game.zone_root):
		var pos = _global_pos(node)
		if not _inside_route_corridor(zone_id, pos):
			continue
		var size = _approx_size(node)
		if size.x > 0.70 or size.z > 0.70:
			_fail("%s route blocker inside main corridor: %s at %s size %s" % [zone_id, _node_path(node), str(pos), str(size)])

func _check_player_locomotion_animation() -> void:
	game.call("_load_zone", "greyfen", Vector3(0, 1, 7))
	await _settle_frames(4)
	var player = game.player
	if player == null:
		_fail("player missing")
		return
	var before = _snapshot_interesting_transforms(player)
	player.velocity = Vector3(0, 0, -4.0)
	player.move_phase = 0.0
	for i in range(18):
		player.call("_animate_visuals", 0.016, Vector3(0, 0, -1), true)
	var after = _snapshot_interesting_transforms(player)
	if _transform_delta(before, after) < 0.08:
		_fail("player locomotion has no visible transform change")

func _check_sword_animation() -> void:
	var player = game.player
	if player == null:
		_fail("player missing for sword check")
		return
	var sword = player.find_child("visible_sword_root", true, false)
	if sword == null or not (sword is Node3D):
		_fail("visible_sword_root missing")
		return
	if not _attack_changes_sword(player, sword as Node3D, false):
		_fail("visible sword transform did not change enough during light attack")
	if not _attack_changes_sword(player, sword as Node3D, true):
		_fail("visible sword transform did not change enough during heavy attack")
	var blade = player.find_child("visible_sword_blade", true, false)
	if blade == null:
		_fail("visible_sword_blade missing; attack may be using hidden stick")
	var arc = player.find_child("visible_sword_slash_arc_root", true, false)
	if arc == null:
		_fail("visible_sword_slash_arc_root missing")

func _attack_changes_sword(player: Node, sword: Node3D, heavy: bool) -> bool:
	player.attack_anim_time = 0.52 if heavy else 0.34
	player.attack_anim_heavy = heavy
	var before = sword.global_transform
	var saw_arc = false
	var max_delta = 0.0
	for i in range(22):
		player.attack_anim_time = max(float(player.attack_anim_time) - 0.016, 0.0)
		player.call("_animate_visuals", 0.016, Vector3.ZERO, false)
		var arc = player.find_child("visible_sword_slash_arc_root", true, false)
		if arc != null and bool(arc.get("visible")):
			saw_arc = true
		var current = sword.global_transform
		max_delta = max(max_delta, _basis_delta(before.basis, current.basis) + before.origin.distance_to(current.origin))
	return max_delta >= (0.20 if heavy else 0.14) and saw_arc

func _check_ghoulkin_material() -> void:
	if game.active_enemies.is_empty():
		_fail("no active Ghoulkin enemies in Wychwood")
		return
	var found_ghoulkin = false
	for enemy in game.active_enemies:
		if enemy == null or str(enemy.get("enemy_id")) != "ghoulkin":
			continue
		found_ghoulkin = true
		var bad = false
		for mesh in _collect_meshes(enemy):
			if _mesh_has_bad_material(mesh):
				bad = true
				break
		if bad:
			_fail("Ghoulkin has a white/default visible material")
		var before = _snapshot_interesting_transforms(enemy)
		enemy.set("windup_time", 0.42)
		for i in range(10):
			if enemy.has_method("_animate_visuals"):
				enemy.call("_animate_visuals", 0.016)
		var after = _snapshot_interesting_transforms(enemy)
		if _transform_delta(before, after) < 0.01:
			_fail("Ghoulkin appears visually static during windup check")
	if not found_ghoulkin:
		_fail("no Ghoulkin found in active enemies")

func _collect_meshes(root_node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		result.append(root_node)
	for child in root_node.get_children():
		result.append_array(_collect_meshes(child))
	return result

func _collect_route_blockers(root_node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if _is_route_blocker_keyword(_keyword_path(root_node)):
		result.append(root_node)
	for child in root_node.get_children():
		result.append_array(_collect_route_blockers(child))
	return result

func _is_required_visible_keyword(key: String) -> bool:
	for word in ["rock", "stone", "rubble", "tree", "trunk", "leaf", "leaves", "crown", "roof", "house", "wall", "plaster", "grave", "fence", "shrine", "player", "sister", "npc", "villager", "ghoulkin", "roadcrows", "feather", "charm", "token", "blood", "mud", "track", "claw", "cloth"]:
		if key.contains(word):
			return true
	return false

func _is_route_blocker_keyword(key: String) -> bool:
	for word in ["tree", "trunk", "rubble", "rock", "house", "fence", "cart", "barrel", "crate", "deadfall"]:
		if key.contains(word):
			return true
	return false

func _inside_route_corridor(zone_id: String, pos: Vector3) -> bool:
	if zone_id == "greyfen":
		if abs(pos.x) < 2.75 and pos.z > -15.2 and pos.z < 12.8:
			return true
		if pos.x > 1.3 and pos.x < 6.8 and pos.z > -8.5 and pos.z < -3.8:
			return true
	elif zone_id == "wychwood":
		if abs(pos.x) < 3.0 and pos.z > -13.0 and pos.z < 14.0:
			return true
		if abs(pos.x) < 4.1 and pos.z > -9.6 and pos.z < -3.1:
			return true
	return false

func _mesh_has_bad_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override != null:
		return _is_bad_white_material(mesh_instance.material_override)
	if mesh_instance.mesh == null:
		return true
	var saw_material = false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material = mesh_instance.mesh.surface_get_material(surface_index)
		if material == null:
			continue
		saw_material = true
		if _is_bad_white_material(material):
			return true
	return not saw_material

func _is_bad_white_material(material: Material) -> bool:
	if material == null:
		return true
	if material is StandardMaterial3D:
		var standard = material as StandardMaterial3D
		var color = standard.albedo_color
		return standard.albedo_texture == null and color.r > 0.85 and color.g > 0.85 and color.b > 0.85
	return false

func _approx_size(node: Node) -> Vector3:
	if node is MeshInstance3D:
		var mesh_node = node as MeshInstance3D
		if mesh_node.mesh != null:
			var aabb = mesh_node.mesh.get_aabb()
			return aabb.size * mesh_node.global_transform.basis.get_scale().abs()
	if node is CollisionShape3D:
		var shape = (node as CollisionShape3D).shape
		if shape is BoxShape3D:
			return (shape as BoxShape3D).size
		if shape is SphereShape3D:
			var radius = (shape as SphereShape3D).radius
			return Vector3.ONE * radius * 2.0
	return Vector3.ZERO

func _global_pos(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).global_position
	return Vector3(999, 999, 999)

func _snapshot_interesting_transforms(root_node: Node) -> Dictionary:
	var snapshot = {}
	_snapshot_recursive(root_node, snapshot)
	return snapshot

func _snapshot_recursive(node: Node, snapshot: Dictionary) -> void:
	if node is Node3D:
		var key = _node_path(node)
		var lower = key.to_lower()
		if lower.contains("visual") or lower.contains("sword") or lower.contains("arm") or lower.contains("leg") or lower.contains("cloak") or lower.contains("ghoul"):
			snapshot[key] = (node as Node3D).transform
	for child in node.get_children():
		_snapshot_recursive(child, snapshot)

func _transform_delta(before: Dictionary, after: Dictionary) -> float:
	var total = 0.0
	for key in before.keys():
		if not after.has(key):
			continue
		var a: Transform3D = before[key]
		var b: Transform3D = after[key]
		total += a.origin.distance_to(b.origin)
		total += _basis_delta(a.basis, b.basis)
	return total

func _basis_delta(a: Basis, b: Basis) -> float:
	return a.x.distance_to(b.x) + a.y.distance_to(b.y) + a.z.distance_to(b.z)

func _keyword_path(node: Node) -> String:
	return _node_path(node).to_lower()

func _node_path(node: Node) -> String:
	var parts: Array[String] = []
	var current: Node = node
	while current != null:
		parts.append(String(current.name))
		current = current.get_parent()
	parts.reverse()
	var text = ""
	for part in parts:
		text += "/" + part
	return text

func _settle_frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	if not failures.is_empty():
		print("visible quality verification failed:")
		for failure in failures:
			print("- %s" % failure)
		quit(1)
		return
	print("visible quality verification complete")
	quit()
