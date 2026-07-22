extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "Main scene missing")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await settle(5)

	var player = game.player
	check(player != null, "Player missing")
	check(player.has_signal("blade_contact_requested"), "Player lacks authoritative blade-contact signal")
	check(player.rig_sword_visual != null, "Kael has no drawn sword visual")
	check(player.rig_sword_visual.name == "KaelOathblade", "Kael is still using the ambiguous imported sword instead of the controlled Oathblade")
	check(player.sword_attachment != null and player.sword_equipment_pivot != null, "Kael's Oathblade lacks its hand socket or equipment pivot")
	check(_has_bone_attachment_ancestor(player.rig_sword_visual), "Kael's drawn sword is not attached to a skeleton bone")
	var sword_bounds := _visible_rendered_bounds(player.rig_sword_visual)
	check(sword_bounds.size.length_squared() > 0.0001, "Kael's drawn sword has no visible rendered mesh")
	check(maxf(sword_bounds.size.x, maxf(sword_bounds.size.y, sword_bounds.size.z)) >= 0.75, "Kael's rendered sword is too small to read in gameplay")
	check(_has_readable_sword_material(player.rig_sword_visual), "Kael's rendered sword is too dark or lacks a readable material")
	check(player.find_child("BladeContactBase", true, false) != null, "Sword hilt contact marker missing")
	check(player.find_child("BladeContactTip", true, false) != null, "Sword tip contact marker missing")
	var segment: Dictionary = player.get_blade_world_segment()
	var blade_base: Vector3 = segment.get("base", Vector3.ZERO)
	var blade_tip: Vector3 = segment.get("tip", Vector3.ZERO)
	check(blade_base.distance_to(blade_tip) > 0.75, "Measured blade segment is too short")
	player.call("_update_sword_equipment_pose", 0.0, 0.0, 0.0, false, false)
	var idle_segment: Dictionary = player.get_blade_world_segment()
	var idle_base: Vector3 = idle_segment.get("base", Vector3.ZERO)
	var idle_tip: Vector3 = idle_segment.get("tip", Vector3.ZERO)
	check(idle_tip.y < idle_base.y - 0.45, "Ready sword still points upward like a pole")
	player.call("_update_sword_equipment_pose", 1.0, 0.0, 0.0, false, true)
	var light_windup_tip: Vector3 = player.get_blade_world_segment().get("tip", Vector3.ZERO)
	player.call("_update_sword_equipment_pose", 1.0, 1.0, 0.0, false, true)
	var light_strike_tip: Vector3 = player.get_blade_world_segment().get("tip", Vector3.ZERO)
	check(light_windup_tip.distance_to(light_strike_tip) >= 0.85, "Light attack does not sweep the rendered blade through a readable arc")
	check(absf(light_windup_tip.x - light_strike_tip.x) >= 0.55, "Light attack lacks visible lateral blade travel")
	player.call("_update_sword_equipment_pose", 1.0, 0.0, 0.0, true, true)
	var heavy_windup_tip: Vector3 = player.get_blade_world_segment().get("tip", Vector3.ZERO)
	player.call("_update_sword_equipment_pose", 1.0, 1.0, 0.0, true, true)
	var heavy_strike_tip: Vector3 = player.get_blade_world_segment().get("tip", Vector3.ZERO)
	check(heavy_windup_tip.distance_to(heavy_strike_tip) >= 0.90, "Heavy attack does not drive the rendered blade from overhead into its strike")
	check(heavy_windup_tip.y - heavy_strike_tip.y >= 0.75, "Heavy attack lacks visible vertical blade travel")
	player.call("_update_sword_equipment_pose", 0.0, 0.0, 0.0, false, false)
	check(blade_tip.distance_to(player.global_position) < 2.5, "Measured blade tip is detached from Kael")
	var light_clip: StringName = player.animation_driver.get_clip_for_state("attack_light")
	var heavy_clip: StringName = player.animation_driver.get_clip_for_state("attack_heavy")
	check(light_clip != StringName() and heavy_clip != StringName(), "Light or heavy attack clip is unresolved")
	check(light_clip != heavy_clip, "Light and heavy attacks resolve to the same visible animation")
	var light_motion: float = _sample_blade_motion(player, light_clip)
	var heavy_motion: float = _sample_blade_motion(player, heavy_clip)
	check(light_motion >= 0.14, "Light attack clip does not visibly move Kael's arm")
	check(heavy_motion >= 0.14, "Heavy attack clip does not visibly move Kael's arm")

	game.call("_load_zone", "wychwood", Vector3(0, 1, -4))
	await settle(5)
	check(not game.active_enemies.is_empty(), "Wychwood combat pack missing")
	if not game.active_enemies.is_empty():
		var enemy = game.active_enemies[0]
		enemy.set_encounter_active(true)
		enemy.set_physics_process(false)
		player.set_physics_process(false)
		segment = player.get_blade_world_segment()
		blade_base = segment.get("base", player.global_position + Vector3(0, 1, 0))
		blade_tip = segment.get("tip", blade_base)
		var sweep_center := blade_base.lerp(blade_tip, 0.72)
		enemy.global_position = Vector3(sweep_center.x, player.global_position.y, sweep_center.z)
		var health_before: float = enemy.health_component.health
		var contact := {
			"base": blade_base, "tip": blade_tip,
			"previous_base": blade_base, "previous_tip": blade_tip,
			"damage": 24.0, "reach": 2.0, "heavy": false
		}
		var result: Dictionary = game.combat.resolve_player_blade_contact(player, [enemy], contact, "")
		check(bool(result.get("hit", false)), "Blade sweep did not hit an enemy intersecting the sword")
		check(enemy.health_component.health < health_before, "Blade contact did not apply damage")
		var damage_after_hit: float = enemy.health_component.health
		var miss_offset := Vector3(3.2, 0, 0)
		contact.base = blade_base + miss_offset
		contact.tip = blade_tip + miss_offset
		contact.previous_base = contact.base
		contact.previous_tip = contact.tip
		result = game.combat.resolve_player_blade_contact(player, [enemy], contact, "")
		check(not bool(result.get("hit", false)), "Off-target blade sweep incorrectly used the old radius hit")
		check(is_equal_approx(enemy.health_component.health, damage_after_hit), "Missed sweep applied damage")

		var contact_state := {"count": 0}
		player.blade_contact_requested.connect(func(_contact: Dictionary): contact_state.count += 1)
		player.attack_anim_time = 0.16
		player.call("_begin_blade_attack", 24.0, 2.0, false)
		player.call("_update_blade_contact")
		player.call("_update_blade_contact")
		check(int(contact_state.count) == 1, "One sword attack did not emit exactly one contact event")

		var parry_state := {"position": Vector3.ZERO, "resolved": false}
		enemy.attack_resolved.connect(func(_enemy: Node, parried: bool, position: Vector3):
			parry_state.resolved = parried
			parry_state.position = position
		)
		enemy.global_position = player.global_position + Vector3(0, 0, -1.0)
		player.parry_window = 0.24
		enemy.call("_resolve_attack")
		check(bool(parry_state.resolved), "Timed parry did not resolve through enemy contact")
		var resolved_parry_position: Vector3 = parry_state.position
		check(resolved_parry_position.distance_to(player.global_position + Vector3(0, 1.0, 0)) < 1.2, "Parry contact point is detached from the weapons")
		check(enemy.stagger_time >= 1.0, "Parry did not stagger the attacker")

	print("COMBAT-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func settle(count: int) -> void:
	for _index in range(count):
		await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _has_bone_attachment_ancestor(node: Node) -> bool:
	var ancestor := node
	while ancestor != null:
		if ancestor is BoneAttachment3D:
			return true
		ancestor = ancestor.get_parent()
	return false

func _visible_rendered_bounds(node: Node) -> AABB:
	var bounds := AABB()
	var found := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var rendered: AABB = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		bounds = bounds.merge(rendered) if found else rendered
		found = true
	return bounds if found else AABB()

func _has_readable_sword_material(node: Node) -> bool:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or not mesh_instance.visible:
			continue
		var material := mesh_instance.material_override as StandardMaterial3D
		if material != null and material.albedo_color.get_luminance() >= 0.35:
			return true
	return false

func _sample_blade_motion(player, clip: StringName) -> float:
	var animation_player := player.animation_driver.get_animation_player() as AnimationPlayer
	var skeleton := player.animation_driver.get_skeleton() as Skeleton3D
	if animation_player == null or skeleton == null or not animation_player.has_animation(clip):
		return 0.0
	var wrist_index := skeleton.find_bone("Wrist.R")
	if wrist_index < 0:
		return 0.0
	var animation := animation_player.get_animation(clip)
	animation_player.play(clip, 0.0)
	animation_player.seek(minf(animation.length * 0.10, animation.length), true)
	skeleton.force_update_all_bone_transforms()
	var start: Transform3D = skeleton.get_bone_global_pose(wrist_index)
	animation_player.seek(minf(animation.length * 0.58, animation.length), true)
	skeleton.force_update_all_bone_transforms()
	var finish: Transform3D = skeleton.get_bone_global_pose(wrist_index)
	var motion := start.origin.distance_to(finish.origin)
	motion += start.basis.x.distance_to(finish.basis.x)
	motion += start.basis.y.distance_to(finish.basis.y)
	return motion
