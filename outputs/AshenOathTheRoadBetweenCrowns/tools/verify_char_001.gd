extends SceneTree

var failures := 0

func _initialize() -> void:
	var packed = load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "Main scene is missing")
	if packed == null:
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(8)
	var kael = game.player
	var anwen = game.zone_root.find_child("sister_anwen", true, false)
	var life = game.zone_root.find_child("GreyfenLifeController", true, false)
	var villager = life.actors[0].node if life != null and not life.actors.is_empty() else null
	_wake_actor(kael)
	_wake_actor(anwen)
	_wake_actor(villager)
	await _frames(2)
	verify_actor(kael, "player_kael", 1.78, 0.08)
	verify_actor(anwen, "sister_anwen", 1.68, 0.08)
	verify_actor(villager, str(life.actors[0].id) if villager != null else "villager", 1.72, 0.16)
	check(_palette_signature(kael) != _palette_signature(anwen), "Kael and Anwen still share the same palette")
	check(_palette_signature(kael) != _palette_signature(villager), "Kael and the villager still share the same palette")

	game.call("_load_zone", "wychwood", Vector3(0, 0.9, 9))
	await _frames(8)
	check(game.active_enemies.size() == 5, "Wychwood five-enemy gate is missing")
	var ghoul = game.active_enemies[0] if not game.active_enemies.is_empty() else null
	_wake_actor(ghoul)
	await _frames(2)
	verify_actor(ghoul, "ghoulkin", 1.65, 0.18)
	if ghoul != null:
		check(ghoul.visual_root.find_children("*", "Skeleton3D", true, false).size() > 0, "Ghoulkin has no connected skeletal body")
		check(_has_active_animation(ghoul), "Ghoulkin has no active animation")
		check(not _has_forbidden_proxy(ghoul), "Ghoulkin contains proxy anatomy")

	print("CHAR-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _wake_actor(actor: Node) -> void:
	if actor == null:
		return
	var driver = actor.find_child("CharacterAnimationDriver", true, false)
	if driver != null:
		if driver.has_method("set_distance_suspended"):
			driver.set_distance_suspended(false)
		if driver.has_method("set_locomotion"):
			driver.set_locomotion(0.0, Vector3.ZERO, true)
		return
	for player in actor.find_children("*", "AnimationPlayer", true, false):
		for animation in player.get_animation_list():
			if str(animation).to_lower().contains("idle"):
				player.play(animation)
				return

func verify_actor(actor: Node, expected_profile: String, target_height: float, tolerance: float) -> void:
	check(actor != null, "%s actor is missing" % expected_profile)
	if actor == null:
		return
	check(actor.find_children("*", "Skeleton3D", true, false).size() > 0, "%s has no Skeleton3D" % expected_profile)
	check(actor.find_children("*", "MeshInstance3D", true, false).size() > 0, "%s has no visible mesh" % expected_profile)
	check(_has_active_animation(actor), "%s has no active animation" % expected_profile)
	check(not _has_forbidden_proxy(actor), "%s contains detached proxy anatomy" % expected_profile)
	var identity_root := _find_identity_root(actor)
	check(identity_root != null, "%s has no identity profile" % expected_profile)
	if identity_root != null:
		check(int(identity_root.get_meta("character_identity_surfaces", 0)) > 0, "%s has no identity material surfaces" % expected_profile)
		if not expected_profile.contains("ghoul"):
			check(int(identity_root.get_meta("character_face_surfaces", 0)) >= 2, "%s has no readable head/skin surface contract" % expected_profile)
	var rendered_bounds := _rendered_bounds(actor)
	var height := rendered_bounds.size.y
	check(absf(height - target_height) <= tolerance, "%s height %.2f is outside %.2f +/- %.2f" % [expected_profile, height, target_height, tolerance])
	# Imported humanoid rigs place the foot-bone origin at the ankle/instep,
	# not at the rendered sole. Grounding must therefore be judged from the
	# visible skinned bounds; keep the bone endpoint as diagnostic telemetry.
	var rendered_bottom := rendered_bounds.position.y
	check(rendered_bottom >= -0.06 and rendered_bottom <= maxf(0.12, tolerance), "%s rendered feet are not grounded (mesh bottom %.2f)" % [expected_profile, rendered_bottom])
	var leg_endpoint := _lowest_leg_endpoint(actor)
	if leg_endpoint < INF:
		print("CHAR-001 grounding telemetry: %s mesh_bottom=%.2f foot_bone=%.2f" % [expected_profile, rendered_bottom, leg_endpoint])

func _find_identity_root(node: Node) -> Node:
	if node.has_meta("character_identity_profile"):
		return node
	for child in node.get_children():
		var result := _find_identity_root(child)
		if result != null:
			return result
	return null

func _palette_signature(node: Node) -> String:
	if node == null:
		return ""
	var colors: Array[String] = []
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for index in range(mesh.mesh.get_surface_count()):
			var material = mesh.get_surface_override_material(index)
			if material is StandardMaterial3D:
				colors.append((material as StandardMaterial3D).albedo_color.to_html(false))
	colors.sort()
	return ",".join(colors)

func _has_active_animation(node: Node) -> bool:
	for player in node.find_children("*", "AnimationPlayer", true, false):
		if player.is_playing():
			return true
	return false

func _has_forbidden_proxy(node: Node) -> bool:
	var forbidden := ["faceplane", "eyeleft", "eyeright", "motion_arm", "motion_leg", "longarm", "clawleft", "clawright", "chestread", "bootread"]
	for child in node.find_children("*", "", true, false):
		var lowered := str(child.name).to_lower().replace("_", "")
		for token in forbidden:
			if lowered.contains(token.replace("_", "")):
				return true
	return false

func _rendered_bounds(node: Node) -> AABB:
	var bounds := AABB()
	var initialized := false
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null or not mesh.visible:
			continue
		var local: Transform3D = (node as Node3D).global_transform.affine_inverse() * mesh.global_transform
		var mesh_bounds: AABB = local * mesh.mesh.get_aabb()
		bounds = bounds.merge(mesh_bounds) if initialized else mesh_bounds
		initialized = true
	return bounds if initialized else AABB()

func _lowest_leg_endpoint(node: Node) -> float:
	var lowest := INF
	var actor_transform: Transform3D = (node as Node3D).global_transform.affine_inverse()
	for skeleton in node.find_children("*", "Skeleton3D", true, false):
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name := str(skeleton.get_bone_name(bone_index)).to_lower().replace(" ", "").replace("_", "")
			if not (bone_name.contains("foot") or bone_name.contains("toe") or bone_name.contains("downlegend")):
				continue
			var world_pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)
			lowest = minf(lowest, (actor_transform * world_pose).origin.y)
	return lowest

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
