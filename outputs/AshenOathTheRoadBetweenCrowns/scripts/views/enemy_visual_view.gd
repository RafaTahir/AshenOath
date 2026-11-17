extends RefCounted
## enemy visual view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _horror_material() -> StandardMaterial3D:
	var material: Variant = StandardMaterial3D.new()
	var texture_name: Variant = "ghoulkin_skin.jpg"
	if _actor.enemy_id == "wychwood_stalker": texture_name = "stalker_skin.jpg"
	elif _actor.enemy_id == "wychwood_brute": texture_name = "brute_skin.jpg"
	elif _actor.enemy_id == "wychwood_raider": texture_name = "ghoulkin_skin.jpg"
	material.albedo_texture = load("res://assets_external/textures/runtime/" + texture_name) as Texture2D
	material.albedo_color = Color(0.78, 0.80, 0.72)
	material.roughness = 0.76
	material.metallic = 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func _apply_boss_material(mapped: Node3D) -> void:
	if _actor.enemy_id in ["bell_eater", "rootbound_colossus", "halvern_boss"]:
		_actor._tint_authored_materials(mapped, {
			"bell_eater": Color(0.30, 0.18, 0.13),
			"rootbound_colossus": Color(0.42, 0.55, 0.38),
			"halvern_boss": Color(0.42, 0.45, 0.52),
		}.get(_actor.enemy_id, Color.WHITE))
		return
	var material: Variant = StandardMaterial3D.new()
	material.albedo_color = {
		"bell_eater": Color(0.13, 0.075, 0.055),
		"rootbound_colossus": Color(0.22, 0.33, 0.20),
		"ashwing": Color(0.30, 0.18, 0.14),
		"halvern_boss": Color(0.24, 0.26, 0.30),
	}.get(_actor.enemy_id, _actor.base_color)
	material.roughness = 0.82
	if _actor.enemy_id == "bell_eater":
		material.emission_enabled = true
		material.emission = Color(0.045, 0.010, 0.004)
		material.emission_energy_multiplier = 0.22
	elif _actor.enemy_id == "halvern_boss":
		material.emission_enabled = true
		material.emission = Color(0.055, 0.075, 0.12)
		material.emission_energy_multiplier = 0.32
	_actor._apply_material(mapped, material)

func _tint_authored_materials(root: Node, tint: Color) -> void:
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: Variant = raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_mesh: Variant = mesh_instance.mesh.duplicate(false) as Mesh
		if local_mesh == null:
			continue
		mesh_instance.mesh = local_mesh
		for surface_index in local_mesh.get_surface_count():
			var source_material: Variant = local_mesh.surface_get_material(surface_index) as StandardMaterial3D
			if source_material == null:
				continue
			var material: Variant = source_material.duplicate(false) as StandardMaterial3D
			material.albedo_color = Color(
				source_material.albedo_color.r * tint.r,
				source_material.albedo_color.g * tint.g,
				source_material.albedo_color.b * tint.b,
				source_material.albedo_color.a
			)
			material.roughness = maxf(source_material.roughness, 0.68)
			local_mesh.surface_set_material(surface_index, material)

func _add_boss_silhouette() -> void:
	_actor.boss_visual_root = Node3D.new()
	_actor.boss_visual_root.name = "BossIdentityLayer"
	_actor.write_presentation_tag(_actor.boss_visual_root, "boss_identity", _actor.enemy_id)
	_actor.boss_identity_base_scale = {
		"bell_eater": Vector3.ONE * 1.55,
		"rootbound_colossus": Vector3(1.45, 1.60, 1.45),
		"ashwing": Vector3(1.35, 1.22, 1.35),
	}.get(_actor.enemy_id, Vector3.ONE)
	_actor.boss_visual_root.scale = _actor.boss_identity_base_scale
	_actor.visual_root.add_child(_actor.boss_visual_root)
	if _actor.enemy_id == "bell_eater":
		# The imported body is the only anatomy. Earlier proxy torso/arm rods
		# floated beside it and made the boss look assembled from primitives.
		_actor._make_bell_eater_identity()
	elif _actor.enemy_id == "rootbound_colossus":
		_actor._make_rootbound_identity()
	elif _actor.enemy_id == "ashwing":
		# The imported dragon is complete anatomy. Identity comes from the
		# harness, ash core, and scorched wing roots, never duplicate body rods.
		_actor._make_ashwing_identity()
	elif _actor.enemy_id == "halvern_boss":
		_actor._make_halvern_identity()
	elif _actor.enemy_id == "white_hart_avatar":
		_actor._make_white_hart_identity()

func _animate_visuals(delta: float) -> void:
	if _actor.body_visual == null:
		return
	var moving_speed = Vector2(_actor.velocity.x, _actor.velocity.z).length()
	var movement_weight = clamp(moving_speed / max(_actor.move_speed, 0.1), 0.0, 1.0)
	if _actor.animation_driver != null and _actor.animation_driver.is_valid():
		if _actor.is_boss:
			if not _actor.animation_driver.character_root.has_meta("cast_viewer"):
				_actor.write_presentation_tag(_actor.animation_driver.character_root, "cast_viewer", _actor.player)
			var presence: Variant = "recovery" if _actor.attack_recovery_time > 0.0 else ("listening" if _actor.enemy_id == "bell_eater" else _actor.ambient_state)
			_actor.animation_driver.set_creature_presence(_actor.enemy_id, presence, 0.8 if movement_weight < 0.1 else 0.2)
		_actor._update_feedback_material()
		_actor._animate_boss_identity(delta)
		if _actor.windup_marker != null:
			_actor.windup_marker.visible = _actor.windup_time > 0.0
		return
	var bob = (0.018 + 0.022 * movement_weight) * sin(_actor.anim_phase)
	_actor.body_visual.position.y = lerp(_actor.body_visual.position.y, 0.62 + bob - 0.04 * movement_weight, 10.0 * delta)
	var target_scale = _actor.base_body_scale
	var root_target_x = 0.0
	var root_target_z = 0.0
	var root_target_y = 0.0
	if _actor.windup_time > 0.0:
		var windup_ratio = clamp(_actor.pending_attack_time / max(_actor._windup_duration(), 0.01), 0.0, 1.0)
		var charge = 1.0 - windup_ratio
		target_scale = Vector3(_actor.base_body_scale.x * (1.22 + charge * 0.12), _actor.base_body_scale.y * (0.70 - charge * 0.08), _actor.base_body_scale.z * (1.42 + charge * 0.16))
		root_target_x = -30.0 + 20.0 * charge
		root_target_y = 12.0 * sin(_actor.anim_phase * 1.4)
		root_target_z = 18.0 * sin(_actor.anim_phase * 1.8) + 12.0 * charge
	elif _actor.stagger_time > 0.0:
		target_scale = Vector3(_actor.base_body_scale.x * 0.78, _actor.base_body_scale.y * 1.18, _actor.base_body_scale.z * 0.82)
		root_target_x = 24.0
		root_target_y = -14.0
		root_target_z = -24.0
	elif _actor.attack_recovery_time > 0.0:
		target_scale = Vector3(_actor.base_body_scale.x * 1.08, _actor.base_body_scale.y * 0.82, _actor.base_body_scale.z * 1.26)
		root_target_x = 18.0
		root_target_z = 12.0
	else:
		root_target_x = -3.5 * movement_weight + 2.0 * sin(_actor.anim_phase * 0.7) * (1.0 - movement_weight)
		root_target_z = 4.0 * sin(_actor.anim_phase) * movement_weight
	_actor.body_visual.scale = _actor.body_visual.scale.lerp(target_scale, 9.0 * delta)
	if _actor.visual_root != null:
		_actor.visual_root.rotation_degrees.x = lerp(_actor.visual_root.rotation_degrees.x, root_target_x, 8.5 * delta)
		_actor.visual_root.rotation_degrees.y = lerp(_actor.visual_root.rotation_degrees.y, root_target_y, 7.5 * delta)
		_actor.visual_root.rotation_degrees.z = lerp(_actor.visual_root.rotation_degrees.z, root_target_z, 8.5 * delta)
	var mat = _actor.body_visual.material_override as StandardMaterial3D
	if mat != null:
		if _actor.windup_time > 0.0:
			mat.albedo_color = _actor.base_color.lerp(Color(0.95, 0.22, 0.10), 0.42 + 0.18 * sin(_actor.anim_phase * 8.0))
		elif _actor.stagger_time > 0.0:
			mat.albedo_color = _actor.base_color.lerp(Color(0.78, 0.78, 0.62), 0.55)
		elif _actor.hit_flash_time > 0.0:
			mat.albedo_color = Color(0.95, 0.82, 0.58)
		elif _actor.slowed_time > 0.0:
			mat.albedo_color = _actor.base_color.lerp(Color(0.45, 0.62, 0.80), 0.45)
		else:
			mat.albedo_color = _actor.base_color
	if _actor.windup_marker != null:
		_actor.windup_marker.visible = _actor.windup_time > 0.0
		var pulse = 0.92 + 0.16 * sin(_actor.anim_phase * 12.0)
		_actor.windup_marker.scale = _actor.windup_marker.scale.lerp(Vector3(0.85 * pulse, 0.012, 0.85 * pulse), 12.0 * delta)
	_actor._animate_boss_identity(delta)

func _animate_boss_identity(delta: float) -> void:
	if not _actor.is_boss or _actor.boss_visual_root == null:
		return
	_actor.boss_visual_time += delta
	var pulse: Variant = 1.0 + sin(_actor.boss_visual_time * 3.4) * 0.035
	if _actor.enemy_id == "bell_eater":
		# The torso bone owns the harness frame. Only its hanging clapper sways.
		var clapper: Variant = _actor.boss_visual_root.get_node_or_null("BellEaterClapper") as Node3D
		if clapper != null:
			var loosened: Variant = bool(_actor.read_presentation_tag(_actor, "living_road_rope_loose", false))
			clapper.position.x = sin(_actor.boss_visual_time * (11.0 if _actor.windup_time > 0.0 else 2.4)) * (0.009 if loosened else 0.025)
			clapper.rotation.z = 0.28 if loosened else 0.0
	elif _actor.enemy_id == "rootbound_colossus":
		# Chest animation owns the wound position; pulse the effect, not its frame.
		if _actor.boss_phase_sigil != null:
			_actor.boss_phase_sigil.scale = Vector3(0.8, 1.0, 0.35) * pulse
			var wound_material: Variant = _actor.boss_phase_sigil.material_override as StandardMaterial3D
			if wound_material != null:
				wound_material.emission_energy_multiplier = (0.65 if bool(_actor.read_presentation_tag(_actor, "living_road_heart_open", false)) else 0.18 + _actor.boss_phase * 0.12) * pulse
	elif _actor.enemy_id == "ashwing":
		# The body bone owns equipment motion, including flight and attack lean.
		if _actor.boss_phase_sigil != null:
			var phase_scale: Variant = [Vector3(1.0, 0.82, 0.70), Vector3(1.24, 1.0, 0.86), Vector3(1.52, 1.22, 1.0)][clampi(_actor.boss_phase - 1, 0, 2)] as Vector3
			_actor.boss_phase_sigil.scale = phase_scale * pulse
	elif _actor.enemy_id == "halvern_boss":
		_actor.boss_visual_root.rotation.y = sin(_actor.boss_visual_time * 0.8) * 0.025
		_actor.boss_visual_root.scale = _actor.boss_visual_root.scale.lerp(Vector3.ONE * (1.0 + sin(_actor.boss_visual_time * 2.0) * 0.012), minf(delta * 5.0, 1.0))
	elif _actor.enemy_id == "white_hart_avatar":
		_actor.boss_visual_root.rotation.y = sin(_actor.boss_visual_time * 0.92) * 0.035
		_actor.boss_visual_root.scale = _actor.boss_visual_root.scale.lerp(Vector3.ONE * (1.0 + sin(_actor.boss_visual_time * 2.6) * 0.022), minf(delta * 5.0, 1.0))

func apply_boss_phase_visual(next_phase: int) -> void:
	if not _actor.is_boss:
		return
	_actor.write_presentation_tag(_actor, "boss_phase", next_phase)
	if _actor.enemy_id == "bell_eater":
		_actor._apply_bell_eater_phase_visual(next_phase)
		return
	elif _actor.enemy_id == "ashwing":
		_actor._apply_ashwing_phase_visual(next_phase)
		return
	if _actor.boss_phase_sigil == null:
		return
	var material: Variant = _actor.boss_phase_sigil.material_override as StandardMaterial3D
	if material == null:
		return
	var color: Variant = {
		1: Color(0.62, 0.28, 0.14),
		2: Color(0.92, 0.46, 0.16),
		3: Color(1.0, 0.78, 0.22),
	}.get(next_phase, Color(0.82, 0.24, 0.14)) as Color
	if _actor.enemy_id == "rootbound_colossus":
		color = {
			1: Color(0.15, 0.38, 0.10),
			2: Color(0.24, 0.44, 0.12),
			3: Color(0.34, 0.52, 0.16),
		}.get(next_phase, Color(0.50, 0.88, 0.32)) as Color
	if _actor.enemy_id == "white_hart_avatar":
		color = {
			1: Color(0.38, 0.78, 0.62),
			2: Color(0.42, 0.72, 0.92),
			3: Color(0.82, 0.92, 0.66),
		}.get(next_phase, Color(0.52, 0.84, 0.72)) as Color
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = 0.72 + float(next_phase) * 0.28
	if _actor.enemy_id == "rootbound_colossus":
		material.emission_energy_multiplier = 0.18 + float(next_phase) * 0.12
	_actor.boss_phase_sigil.scale = Vector3(0.8, 1.0, 0.35) if _actor.enemy_id == "rootbound_colossus" else Vector3.ONE * (0.10 + float(next_phase) * 0.025)

func _apply_bell_eater_phase_visual(next_phase: int) -> void:
	if _actor.boss_visual_root == null:
		return
	var bell: Variant = _actor.boss_visual_root.get_node_or_null("BellEaterChestBell") as MeshInstance3D
	var clapper: Variant = _actor.boss_visual_root.get_node_or_null("BellEaterClapper") as MeshInstance3D
	var links: Variant = _actor.boss_visual_root.get_node_or_null("BellEaterHarnessLinks") as MultiMeshInstance3D
	var phase: Variant = clampi(next_phase, 1, 3)
	if links != null:
		links.multimesh.visible_instance_count = [12, 6, 0][phase - 1]
	if clapper != null:
		clapper.visible = phase < 3
	if bell != null and bell.mesh != null:
		var material: Variant = bell.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		material.emission_enabled = phase > 1
		material.emission = Color(0.80, 0.24, 0.045)
		material.emission_energy_multiplier = [0.0, 0.55, 1.1][phase - 1]
		bell.material_override = material

func _apply_ashwing_phase_visual(next_phase: int) -> void:
	if _actor.boss_visual_root == null:
		return
	var harness: Variant = _actor.boss_visual_root.get_node_or_null("AshwingBurntHarness") as MeshInstance3D
	var core: Variant = _actor.boss_visual_root.get_node_or_null("AshwingAshCore") as MeshInstance3D
	if harness != null:
		harness.visible = next_phase < 3
		harness.scale = Vector3(1.36, 0.52, 0.86) if next_phase == 1 else Vector3(1.54, 0.42, 1.02)
	if core != null:
		var core_color: Variant = [Color(0.25, 0.07, 0.01), Color(0.36, 0.11, 0.018), Color(0.48, 0.18, 0.035)][clampi(next_phase - 1, 0, 2)] as Color
		core.material_override = _actor._emissive_boss_material(core_color, [0.20, 0.35, 0.50][clampi(next_phase - 1, 0, 2)])
		core.scale = [Vector3(1.0, 0.82, 0.70), Vector3(1.24, 1.0, 0.86), Vector3(1.52, 1.22, 1.0)][clampi(next_phase - 1, 0, 2)] as Vector3
	var body_material: Variant = _actor.body_visual.material_override as StandardMaterial3D if _actor.body_visual != null else null
	if body_material != null:
		body_material.albedo_color = [Color(0.30, 0.18, 0.14), Color(0.26, 0.105, 0.07), Color(0.16, 0.055, 0.035)][clampi(next_phase - 1, 0, 2)] as Color
		body_material.emission_enabled = next_phase > 1
		body_material.emission = Color(0.12, 0.025, 0.008) if next_phase == 2 else Color(0.18, 0.045, 0.012)
		body_material.emission_energy_multiplier = 0.06 if next_phase == 2 else (0.14 if next_phase == 3 else 0.0)

func _update_feedback_material() -> void:
	var mat = _actor.body_visual.material_override as StandardMaterial3D
	if mat == null:
		return
	if _actor.windup_time > 0.0:
		mat.albedo_color = _actor.base_color.lerp(Color(0.95, 0.22, 0.10), 0.48)
	elif _actor.stagger_time > 0.0 or _actor.hit_flash_time > 0.0:
		mat.albedo_color = Color(0.95, 0.82, 0.58)
	else:
		mat.albedo_color = _actor.base_color

func _show_windup_marker() -> void:
	if _actor.windup_marker == null:
		_actor.windup_marker = _actor.CombatFeedback.warning_marker(_actor, _actor)
	if _actor.windup_marker != null:
		if _actor.is_boss:
			var attack_id: String = _actor._boss_attack_id()
			_actor.CombatFeedback.configure_boss_warning(_actor.windup_marker, attack_id, _actor._boss_attack_radius(attack_id))
		_actor.windup_marker.visible = true

func _hide_windup_marker() -> void:
	if _actor.windup_marker != null:
		_actor.windup_marker.visible = false

func _mat(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
