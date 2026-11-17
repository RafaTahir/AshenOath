extends RefCounted
## player character view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _build_body() -> void:
	_actor.visual_root = Node3D.new()
	_actor.add_child(_actor.visual_root)
	preload("res://scripts/views/combat_capsule_view.gd").install_player(_actor)
	if not _actor.presentation_enabled:
		return
	if _actor._try_build_mapped_body():
		_actor.CharacterPresentation.apply_player(_actor, _actor.visual_root)
		_actor._add_beam_charge_visual()
		_actor._set_sword_sheathed(true)
		return

	# Required character roles never receive procedural anatomy. Keeping the
	# controller/collision shell alive makes the failure diagnosable without
	# shipping a faceless polygon as the player.
	_actor.write_presentation_tag(_actor.visual_root, "character_visual_failure", true)
	push_error("Player visual role could not be built; refusing primitive fallback")

func _add_beam_charge_visual() -> void:
	_actor.beam_charge_visual = MeshInstance3D.new()
	_actor.beam_charge_visual.name = "OathfireChargeSphere"
	_actor.beam_charge_visual.mesh = SphereMesh.new()
	_actor.beam_charge_visual.material_override = _actor._beam_material(Color(0.35, 0.88, 1.0, 0.92))
	_actor.beam_charge_visual.visible = false
	_actor.add_child(_actor.beam_charge_visual)
	var skeleton: Variant = _actor._find_skeleton(_actor.visual_root)
	_actor.beam_left_hand_glow = _actor._make_oathfire_hand("OathfireLeftHand", skeleton, ["LeftHand", "Hand.L", "Fist.L", "FistL", "lefthand", "leftwrist"], Vector3(-0.28, 1.22, -0.42))
	_actor.beam_right_hand_glow = _actor._make_oathfire_hand("OathfireRightHand", skeleton, ["RightHand", "Hand.R", "Weapon.R", "WeaponR", "Fist.R", "FistR", "righthand", "rightwrist"], Vector3(0.28, 1.22, -0.42))
	if skeleton != null:
		_actor.beam_left_arm_ik = _actor._make_arm_pose_ik(skeleton, "OathfireLeftArmPose", &"upperarm_l", &"hand_l")
		_actor.beam_right_arm_ik = _actor._make_arm_pose_ik(skeleton, "OathfireRightArmPose", &"upperarm_r", &"hand_r")
	_actor._build_sheathed_sword()
	_actor._build_bow_visual()
	_actor._ensure_equipment_loadout()

func _make_arm_pose_ik(skeleton: Skeleton3D, node_name: String, root_bone: StringName, tip_bone: StringName) -> SkeletonIK3D:
	if skeleton.find_bone(root_bone) < 0 or skeleton.find_bone(tip_bone) < 0:
		return null
	var solver: Variant = SkeletonIK3D.new()
	solver.name = node_name
	solver.root_bone = root_bone
	solver.tip_bone = tip_bone
	solver.override_tip_basis = false
	solver.max_iterations = 12
	skeleton.add_child(solver)
	return solver

func _make_oathfire_hand(node_name: String, skeleton: Skeleton3D, aliases: Array[String], fallback_position: Vector3) -> MeshInstance3D:
	var glow: Variant = MeshInstance3D.new()
	glow.name = node_name
	var mesh: Variant = SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.20
	glow.mesh = mesh
	glow.material_override = _actor._beam_material(Color(0.38, 0.82, 1.0, 0.58))
	glow.visible = false
	var socket_parent: Node3D = _actor.visual_root
	if skeleton != null:
		var hand_index: Variant = _actor._find_bone_index(skeleton, aliases)
		if hand_index < 0:
			var wants_left: Variant = node_name.contains("Left")
			for bone_index in range(skeleton.get_bone_count()):
				var bone_name: Variant = str(skeleton.get_bone_name(bone_index)).to_lower()
				var is_hand: Variant = bone_name.contains("hand") or bone_name.contains("wrist")
				var is_side: Variant = bone_name.contains("left") or bone_name.contains("_l") or bone_name.ends_with(".l") if wants_left else bone_name.contains("right") or bone_name.contains("_r") or bone_name.ends_with(".r")
				if is_hand and is_side:
					hand_index = bone_index
					break
		if hand_index >= 0:
			var attachment: Variant = BoneAttachment3D.new()
			attachment.name = "%sSocket" % node_name
			attachment.bone_idx = hand_index
			attachment.bone_name = skeleton.get_bone_name(hand_index)
			skeleton.add_child(attachment)
			# Imported rigs carry source-scale transforms on their skeleton. Cancel
			# that scale before adding the glow so a 20 cm hand effect cannot become
			# a multi-metre object or corrupt the rendered character bounds.
			socket_parent = _actor._create_equipment_space(attachment, "%sEquipmentSpace" % node_name)
			if node_name.contains("Left"):
				_actor.beam_left_hand_socket = attachment
			else:
				_actor.beam_right_hand_socket = attachment
	socket_parent.add_child(glow)
	if socket_parent == _actor.visual_root:
		glow.position = fallback_position
	return glow

func _try_build_mapped_body() -> bool:
	_actor.asset_helper = _actor.AssetSpawnHelper.new()
	_actor.add_child(_actor.asset_helper)
	var mapped: Node3D = null
	if (_actor.asset_helper != null) and (_actor.asset_helper != null) and _actor.asset_helper.has_visual_role("player_human"):
		mapped = _actor.asset_helper.spawn_visual_role("player_human", "characters")
	if mapped == null or mapped.name.ends_with("_placeholder"):
		if mapped != null:
			mapped.queue_free()
		mapped = _actor.asset_helper.spawn_character("player_kael")
	if mapped == null or mapped.name.ends_with("_placeholder"):
		if mapped != null:
			mapped.queue_free()
		return false
	mapped.name = "player_kael_visual"
	_actor.visual_root.add_child(mapped)
	_actor._mapped_body = mapped
	var imported_sword: Variant = mapped.find_child("Warrior_Sword", true, false) as Node3D
	if imported_sword != null:
		imported_sword.visible = false
	_actor.rig_sword_visual = _actor._attach_rig_sword(mapped)
	if _actor.rig_sword_visual != null:
		# Oathblade geometry is authored along local -Y. Keep the contact
		# contract on that same axis so the damage sweep and the rendered blade
		# cannot diverge into the old detached-pole presentation.
		_actor._configure_blade_markers(_actor.rig_sword_visual, Vector3(0, -0.08, 0), Vector3(0, -1.04, 0), true)
		# Establish the authored ready pose before the first physics tick. Capture
		# tools and dialogue staging can sample the rig before _animate_visuals runs;
		# leaving the imported hand axis untouched makes the sword read as a pole.
		_actor._update_sword_equipment_pose(0.0, 0.0, 0.0, false, false)
	_actor.body_visual = _actor._find_first_mesh(mapped)
	_actor.CharacterMaterialBindings.restore(mapped)
	_actor._apply_visible_material_fallbacks(mapped, _actor._mat(Color(0.18, 0.20, 0.18)), true)
	if _actor.body_visual != null and _actor.body_visual.material_override is StandardMaterial3D:
		_actor.body_base_color = (_actor.body_visual.material_override as StandardMaterial3D).albedo_color
	_actor.animation_driver = _actor.CharacterAnimationDriver.new()
	_actor.animation_driver.forward_only_locomotion = true
	_actor.animation_driver.name = "CharacterAnimationDriver"
	mapped.add_child(_actor.animation_driver)
	var animated: bool = bool(_actor.animation_driver.configure(mapped, _actor._animation_map_for_visual(mapped)))
	if not animated:
		if _actor.rig_sword_visual == null:
			_actor._add_mapped_weapon_visuals()
	else:
		_actor.animation_driver.set_update_rate_hz(30.0)
		_actor.animation_driver.set_external_tick(true)
		var foot_rig: Skeleton3D = _actor.animation_driver.get_skeleton()
		if foot_rig != null and foot_rig.get_node_or_null("GroundedFeet") == null:
			var grounding: Variant = load("res://scripts/grounded_feet_modifier.gd").new()
			grounding.name = "GroundedFeet"
			foot_rig.add_child(grounding)
			grounding.configure(_actor, foot_rig)
		if _actor.animation_driver.has_signal("locomotion_step") and not _actor.animation_driver.locomotion_step.is_connected(_actor._on_animation_locomotion_step):
			_actor.animation_driver.locomotion_step.connect(_actor._on_animation_locomotion_step)
			_actor.animation_step_signal_bound = true
		_actor._add_slash_arc_visuals()
	return true

func _animation_map_for_visual(mapped: Node3D) -> Dictionary:
	var family: Variant = str(_actor.read_presentation_tag(mapped, "character_animation_family", "")).to_lower()
	if family.contains("warrior"):
		return {
			"idle": "Idle", "walk": "Walk", "walk_back": "Walk_Back", "strafe": "Walk", "run": "Run", "run_back": "Run_Back",
			"jump": "Roll", "attack_light": "Sword_Attack", "attack_heavy": "Sword_Attack2",
			"dodge": "Roll", "parry": "Idle_Weapon", "beam_cast": "Idle_Weapon",
			"hit": "RecieveHit", "death": "Death"
		}
	if family.contains("cleric"):
		return {
			"idle": "Idle", "walk": "Walk", "walk_back": "Walk_Back", "strafe": "Walk", "run": "Run", "run_back": "Run_Back",
			"jump": "Run", "attack_light": "Staff_Attack", "attack_heavy": "Staff_Attack",
			"dodge": "Run", "parry": "Idle_Weapon", "beam_cast": "Spell1",
			"hit": "RecieveHit", "death": "Death"
		}
	if family.contains("rogue"):
		return {
			"idle": "Idle", "walk": "Walk", "walk_back": "Walk_Back", "strafe": "Walk", "run": "Run", "run_back": "Run_Back",
			"jump": "Roll", "attack_light": "Dagger_Attack", "attack_heavy": "Dagger_Attack2",
			"dodge": "Roll", "parry": "Attacking_Idle", "beam_cast": "Attacking_Idle",
			"hit": "RecieveHit", "death": "Death"
		}
	if family.contains("monk"):
		return {
			"idle": "Idle", "walk": "Walk", "walk_back": "Walk_Back", "strafe": "Walk", "run": "Run", "run_back": "Run_Back",
			"jump": "Roll", "attack_light": "Attack", "attack_heavy": "Attack2",
			"dodge": "Roll", "parry": "Idle_Attacking", "beam_cast": "Idle_Attacking",
			"hit": "RecieveHit", "death": "Death"
		}
	return {
		"idle": "Idle", "walk": "Walk", "walk_back": "Walk_Back", "strafe": "Walk", "run": "Sprint", "run_back": "Run_Back",
		"jump": "Jump_Start", "attack_light": "Sword_Attack", "attack_heavy": "Sword_Attack_RM",
		"dodge": "Roll", "parry": "Sword_Idle", "beam_cast": "Spell_Simple_Idle",
		"hit": "Hit_Chest", "death": "Death01"
	}

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found: Variant = _actor._find_skeleton(child)
		if found != null:
			return found
	return null

func _find_bone_index(skeleton: Skeleton3D, aliases: Array[String]) -> int:
	for alias in aliases:
		var exact: Variant = skeleton.find_bone(alias)
		if exact >= 0:
			return exact
	for bone_index in range(skeleton.get_bone_count()):
		var normalized: Variant = str(skeleton.get_bone_name(bone_index)).to_lower().replace("_", "").replace(".", "").replace(" ", "")
		for alias in aliases:
			var wanted: Variant = alias.to_lower().replace("_", "").replace(".", "").replace(" ", "")
			if normalized.contains(wanted):
				return bone_index
	return -1

func _find_first_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		var found = _actor._find_first_mesh(child)
		if found != null:
			return found
	return null

func _mat(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _metal_mat(color: Color) -> StandardMaterial3D:
	var material = _actor._mat(color)
	material.metallic = 0.38
	material.roughness = 0.48
	return material

func _trail_mat(color: Color) -> StandardMaterial3D:
	var material = _actor._mat(color)
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.76, 0.42)
	material.emission_energy_multiplier = 0.24
	return material

func _beam_material(color: Color) -> StandardMaterial3D:
	var material = _actor._trail_mat(color)
	material.emission = Color(0.25, 0.82, 1.0)
	material.emission_energy_multiplier = 2.2
	return material

func _apply_visible_material_fallbacks(root: Node, fallback: Material, required: bool = false) -> void:
	if root is MeshInstance3D:
		var mesh_instance = root as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				if mesh_instance.get_active_material(surface) == null:
					if required:
						push_error("Required Kael material is missing: %s[%d]" % [str(mesh_instance.name), surface])
					else:
						mesh_instance.set_surface_override_material(surface, fallback)
	for child in root.get_children():
		_actor._apply_visible_material_fallbacks(child, fallback, required)

func _mesh_needs_visible_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override != null:
		return _actor._is_bad_white_material(mesh_instance.material_override)
	if mesh_instance.mesh == null:
		return true
	var saw_material = false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material = mesh_instance.get_active_material(surface_index)
		if material == null:
			continue
		saw_material = true
	return not saw_material

func _is_bad_white_material(material: Material) -> bool:
	if material == null:
		return true
	if material is StandardMaterial3D:
		var standard = material as StandardMaterial3D
		var color = standard.albedo_color
		return standard.albedo_texture == null and color.r > 0.85 and color.g > 0.85 and color.b > 0.85
	return false
