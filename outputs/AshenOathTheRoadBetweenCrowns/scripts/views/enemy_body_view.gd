extends RefCounted
## enemy body view: scene-only responsibilities.

var _actor: CharacterBody3D

func _init(actor: CharacterBody3D) -> void:
	_actor = actor

func _build_body(color: Color) -> void:
	_actor.add_to_group("enemies")
	preload("res://scripts/views/combat_capsule_view.gd").install_enemy(_actor, _actor.enemy_id, _actor.is_boss)
	_actor.visual_root = Node3D.new()
	_actor.visual_root.name = "visual_root"
	_actor.add_child(_actor.visual_root)
	if not _actor.presentation_enabled:
		return
	if _actor._try_build_mapped_body():
		_actor.CharacterPresentation.apply_enemy(_actor, _actor._enemy_shadow_scale())
		return
	_actor.write_presentation_tag(_actor.visual_root, "enemy_visual_failure", true)
	push_error("Enemy visual role could not be built for '%s'; refusing primitive fallback" % _actor.enemy_id)

func _try_build_mapped_body() -> bool:
	_actor.asset_helper = _actor.AssetSpawnHelper.new()
	_actor.add_child(_actor.asset_helper)
	var mapped = null
	var uses_real_body: Variant = false
	var visual_source: String = _actor.visual_role_override if _actor.enemy_id == "bandit" and not _actor.visual_role_override.is_empty() else _actor.enemy_id
	var skeleton_family_source: Variant = false
	if _actor.enemy_id == "captain_senn":
		visual_source = "road_ranger_human"
		mapped = _actor.asset_helper.spawn_visual_role(visual_source, "characters", "captain_senn")
		uses_real_body = mapped != null
	if _actor.enemy_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bog_wretch", "gravebound_knight", "bell_eater", "rootbound_colossus", "ashwing", "halvern_boss", "white_hart_avatar"]:
		visual_source = {
			"ghoulkin": "ghoulkin_creature",
			"wychwood_stalker": "wychwood_stalker_creature",
			"wychwood_raider": "wychwood_raider_creature",
			"wychwood_brute": "wychwood_brute_creature",
			"bog_wretch": "bog_wretch_creature",
			"gravebound_knight": "gravebound_knight_creature",
			"bell_eater": "bell_eater_boss",
			"rootbound_colossus": "rootbound_colossus_boss",
			"ashwing": "ashwing_boss",
			"halvern_boss": "halvern_boss",
			"white_hart_avatar": "white_hart_boss",
		}.get(_actor.enemy_id, "ghoulkin_creature")
		if not _actor.visual_role_override.is_empty():
			visual_source = _actor.visual_role_override
		mapped = _actor.asset_helper.spawn_visual_role(visual_source, "enemies")
		skeleton_family_source = visual_source == "ghoulkin_skeleton"
		uses_real_body = mapped != null and not mapped.name.ends_with("_placeholder") and not skeleton_family_source
	if mapped == null:
		mapped = _actor.asset_helper.spawn_enemy(visual_source)
	if mapped == null or mapped.name.ends_with("_placeholder"):
		if mapped != null:
			mapped.queue_free()
		return false
	mapped.name = "%s_visual" % _actor.enemy_id
	_actor.write_presentation_tag(mapped, "monster_family_role", visual_source)
	_actor.write_presentation_tag(mapped, "monster_behavior_profile", _actor.behavior_profile)
	var design_body: Variant = bool(_actor.read_presentation_tag(mapped, "character_authored_silhouette", false))
	var native_design: Variant = str(_actor.read_presentation_tag(mapped, "character_animation_family", "")) == "design_pack_native"
	_actor.write_presentation_tag(_actor, "camera_subject_height", _actor.CharacterRoleSpec.target_height(visual_source) * _actor._mapped_enemy_scale().y)
	_actor.write_presentation_tag(_actor, "camera_subject_bounds", _actor.CharacterRoleSpec.encounter_camera_bounds(visual_source))
	_actor.asset_helper.apply_normalized_scale(mapped, _actor._mapped_enemy_scale().y)
	if _actor._is_wychwood_pack() and not design_body:
		var profile_scale: Vector3 = {
			"ghoulkin": Vector3(0.82, 1.0, 0.86),
			"wychwood_stalker": Vector3(0.70, 1.0, 0.78),
			"wychwood_raider": Vector3(0.90, 1.0, 0.88),
			"wychwood_brute": Vector3(1.12, 1.0, 1.04)
		}.get(_actor.enemy_id, Vector3.ONE)
		mapped.scale *= profile_scale
	if _actor._is_wychwood_pack() and not design_body:
		_actor._tint_authored_materials(mapped, {
			"ghoulkin": Color(0.58, 0.62, 0.55),
			"wychwood_stalker": Color(0.58, 0.48, 0.44),
			"wychwood_raider": Color(0.60, 0.58, 0.48),
			"wychwood_brute": Color(0.46, 0.52, 0.62),
		}.get(_actor.enemy_id, Color.WHITE))
	if _actor.is_boss and _actor.enemy_id not in ["white_hart_avatar", "captain_senn"] and not design_body:
		_actor._apply_boss_material(mapped)
	_actor.visual_root.add_child(mapped)
	if _actor._is_wychwood_pack():
		# Variant identity is carried by the imported skeleton, role material,
		# scale, locomotion profile, and attack spacing. Do not add detached
		# root-mounted anatomy on top of a valid animated body.
		_actor.write_presentation_tag(mapped, "monster_variant_profile", _actor.enemy_id)
	if _actor.is_boss and _actor.enemy_id not in ["white_hart_avatar", "captain_senn"] and not design_body:
		_actor._add_boss_silhouette()
	_actor.body_visual = _actor._find_first_mesh(mapped)
	_actor.base_body_scale = mapped.scale
	_actor.animation_driver = _actor.CharacterAnimationDriver.new()
	_actor.animation_driver.name = "CharacterAnimationDriver"
	mapped.add_child(_actor.animation_driver)
	if native_design:
		_actor.native_ambient_authored = bool(_actor.read_presentation_tag(mapped, "authored_creature_ambient", false))
		_actor.animation_driver.configure(mapped, {
			"idle":"Idle", "walk":"Walking", "run":"Running", "windup":"Windup",
			"attack":"Attack", "attack_heavy":"AttackHeavy", "hit":"HitReact", "death":"Death",
			"block":"Block", "dialogue":"Interact", "recovery":"Recovery"
		})
	elif skeleton_family_source:
		_actor._add_skeleton_impact_clip(mapped)
		_actor.animation_driver.configure(mapped, {
			"idle": "SkeletonArmature|Skeleton_Idle",
			"windup": "SkeletonArmature|Skeleton_Attack",
			"walk": "SkeletonArmature|Skeleton_Running",
			"run": "SkeletonArmature|Skeleton_Running",
			"attack": "SkeletonArmature|Skeleton_Attack",
			"hit": "recovery/Impact",
			"death": "SkeletonArmature|Skeleton_Death"
		})
	elif uses_real_body:
		if _actor.enemy_id == "captain_senn":
			_actor.animation_driver.configure(mapped, {"idle":"Idle", "walk":"Walk", "run":"Sprint", "windup":"Sword_Attack", "attack":"Sword_Attack", "hit":"Hit_Chest", "death":"Death01"})
		elif visual_source in ["ghoulkin_creature", "bell_eater_boss", "bog_wretch_creature"]:
			_actor.animation_driver.configure(mapped, {
				"idle":"Idle", "walk":"Walk", "walk_back":"Walk",
				"strafe":"Walk", "run":"Sprint", "windup":"Sword_Attack",
				"attack":"Sword_Attack", "hit":"Hit_Chest", "death":"Death01"
			})
		elif visual_source in ["wychwood_stalker_creature", "wychwood_raider_creature", "wychwood_brute_creature"]:
			_actor.animation_driver.configure(mapped, {
				"idle":"Idle", "walk":"Walk", "walk_back":"Walk", "strafe":"Walk",
				"run":"Run", "windup":"Weapon", "attack":"Punch",
				"hit":"HitReact", "death":"Death"
			})
		elif visual_source == "rootbound_colossus_boss":
			_actor.animation_driver.configure(mapped, {
				"idle":"Idle1_Action", "walk":"Walk1_Action", "walk_back":"Walk1_Action",
				"strafe":"Walk2_Action", "run":"Walk2_Action", "windup":"Roar_Action",
				"attack":"Punch_Action", "hit":"Damage_Action", "death":"Death_Action"
			})
		elif visual_source in ["ashwing_creature", "ashwing_boss"]:
			_actor.animation_driver.configure(mapped, {
				"idle":"DragonArmature|Dragon_Flying", "walk":"DragonArmature|Dragon_Flying",
				"walk_back":"DragonArmature|Dragon_Flying", "strafe":"DragonArmature|Dragon_Flying",
				"run":"DragonArmature|Dragon_Flying", "windup":"DragonArmature|Dragon_Attack",
				"attack":"DragonArmature|Dragon_Attack2", "hit":"DragonArmature|Dragon_Hit",
				"death":"DragonArmature|Dragon_Death"
			})
		elif visual_source in ["white_hart_avatar", "white_hart_boss"]:
			_actor.animation_driver.configure(mapped, {
				"idle": "Idle", "walk": "Walk", "walk_back": "Walk", "strafe": "Walk",
				"run": "Gallop", "windup": "Attack_Headbutt", "attack": "Attack_Headbutt",
				"hit": "Idle_HitReact1", "death": "Death"
			})
		elif visual_source == "gravebound_knight_creature":
			_actor.animation_driver.configure(mapped, {
				"idle": "SkeletonArmature|Skeleton_Idle", "walk": "SkeletonArmature|Skeleton_Running",
				"walk_back": "SkeletonArmature|Skeleton_Running", "strafe": "SkeletonArmature|Skeleton_Running",
				"run": "SkeletonArmature|Skeleton_Running", "windup": "SkeletonArmature|Skeleton_Attack",
				"attack": "SkeletonArmature|Skeleton_Attack", "hit": "SkeletonArmature|Skeleton_Attack",
				"death": "SkeletonArmature|Skeleton_Death"
			})
		elif visual_source == "halvern_boss":
			_actor.animation_driver.configure(mapped, {
				"idle": "Sword_Idle", "walk": "Walk", "walk_back": "Walk",
				"strafe": "Walk", "run": "Sprint", "windup": "Sword_Attack",
				"attack": "Sword_Attack", "hit": "Hit_Chest", "death": "Death01"
			})
		else:
			_actor.animation_driver.configure(mapped, {
				"idle": "Idle",
				"walk":"Walk", "walk_back":"Walk", "strafe":"Walk",
				"run":"Run", "windup":"Attack", "attack":"Attack",
				"hit":"RecieveHit", "death":"Death"
			})
	else:
		_actor.animation_driver.configure(mapped, {
			"idle": "Idle", "walk": "Walk", "run": "Run", "jump": "Jump_Idle",
			"windup": "Punch",
			"attack": "Punch", "hit": "HitReact", "death": "Death"
		})
	if not _actor.animation_driver.is_valid():
		var animation_report: Dictionary = _actor.animation_driver.get_contract_report()
		push_error("Enemy visual role '%s' has no valid idle animation: %s" % [_actor.enemy_id, animation_report.get("errors", [])])
		mapped.queue_free()
		return false
	# One active combat skeleton is sufficient for the 720p presentation;
	# keeping its updates off the crowded 60 Hz path avoids isolated attack
	# evaluation spikes on Intel/ANGLE without changing hit timing.
	_actor.animation_driver.set_update_rate_hz(12.0)
	_actor._ground_mapped_visual(mapped)
	mapped.position.y += _actor.CharacterRoleSpec.ground_offset(visual_source)
	if _actor.enemy_id in ["halvern_boss", "bandit", "captain_senn"] and not native_design:
		_actor._attach_humanoid_sword("Halvern" if _actor.enemy_id == "halvern_boss" else "Bandit")
		if _actor.enemy_id == "bandit" and visual_source == "bandit_tracker":
			_actor._attach_bandit_shield()
	elif _actor.enemy_id == "bell_eater" and not native_design:
		_actor._attach_bell_eater_harness(mapped)
	elif _actor.enemy_id == "rootbound_colossus" and not native_design:
		# The hunched chest surface sits well ahead of the imported chest pivot.
		_actor._attach_boss_identity_to_bone(mapped, "Chest", "RootboundHeartSocket", Vector3(0, 0, -1.48), true)
	elif _actor.enemy_id == "ashwing" and not native_design:
		var authored_basis: Variant = _actor.boss_visual_root.basis
		_actor._attach_boss_identity_to_bone(mapped, "Body", "AshwingHarnessSocket", Vector3.ZERO)
		_actor.boss_visual_root.basis = _actor.boss_visual_root.basis * authored_basis
	_actor._configure_attack_contact_bone()
	if native_design and not _actor._configure_native_attack_profile(mapped):
		mapped.queue_free()
		return false
	return true

func _configure_native_attack_profile(mapped: Node3D) -> bool:
	var source: Variant = str(_actor.read_presentation_tag(mapped, "prepared_actor_source", _actor.read_presentation_tag(mapped, "runtime_asset_path", "")))
	var clip: StringName = _actor.animation_driver.get_clip_for_state("attack")
	var animation: Animation = _actor.animation_driver.get_animation_player().get_animation(clip)
	if animation != null:
		_actor.native_attack_profile = _actor.NativeAttackProfiles.for_source(source, str(clip), animation.length)
	if _actor.native_attack_profile.is_empty():
		push_error("Native attack timing is missing or stale: %s (%s; %s)" % [_actor.enemy_id, source, clip])
		return false
	return true

func _ground_mapped_visual(mapped: Node3D) -> void:
	var state: Variant = {"initialized": false, "bounds": AABB()}
	_actor._accumulate_visual_bounds(mapped, Transform3D.IDENTITY, state)
	if bool(state.initialized):
		var bounds: AABB = state.bounds
		mapped.position.y -= bounds.position.y
		_actor.write_presentation_tag(_actor, "camera_subject_height", maxf(float(_actor.read_presentation_tag(_actor, "camera_subject_height", 1.9)), bounds.size.y))

func _accumulate_visual_bounds(node: Node, parent_transform: Transform3D, state: Dictionary) -> void:
	var current_transform: Variant = parent_transform
	if node is Node3D and node != _actor.visual_root:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance: Variant = node as MeshInstance3D
		if mesh_instance.mesh != null and (mesh_instance.skin != null or mesh_instance.skeleton != NodePath("")):
			var mesh_bounds: AABB = current_transform * _actor._posed_mesh_bounds(mesh_instance)
			state.bounds = (state.bounds as AABB).merge(mesh_bounds) if bool(state.initialized) else mesh_bounds
			state.initialized = true
	for child in node.get_children():
		_actor._accumulate_visual_bounds(child, current_transform, state)

func _posed_mesh_bounds(instance: MeshInstance3D) -> AABB:
	var skeleton: Variant = instance.get_node_or_null(instance.skeleton) as Skeleton3D
	var skin: Variant = instance.skin
	if skeleton == null or skin == null:
		return instance.mesh.get_aabb()
	var transforms: Array[Transform3D] = []
	for bind in range(skin.get_bind_count()):
		var bone: Variant = skin.get_bind_bone(bind)
		if skin.get_bind_name(bind) != StringName():
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		if bone < 0 or bone >= skeleton.get_bone_count():
			return instance.mesh.get_aabb()
		transforms.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	var initialized: Variant = false
	var bounds: Variant = AABB()
	for surface in range(instance.mesh.get_surface_count()):
		var arrays: Variant = instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var influences: int = bones.size() / vertices.size() if bones != null and not vertices.is_empty() else 0
		for vertex in range(vertices.size()):
			var point: Variant = vertices[vertex]
			if influences > 0:
				point = Vector3.ZERO
				for influence in range(influences):
					var index: Variant = vertex * influences + influence
					if weights[index] > 0.0:
						point += (transforms[bones[index]] * vertices[vertex]) * weights[index]
			bounds = bounds.expand(point) if initialized else AABB(point, Vector3.ZERO)
			initialized = true
	return bounds if initialized else instance.mesh.get_aabb()

func _mapped_enemy_scale() -> Vector3:
	if _actor.enemy_id == "bog_wretch":
		return Vector3(1.25, 1.25, 1.25)
	if _actor.enemy_id == "white_hart_avatar":
		# white_hart_boss is normalized to its 3.60 m focal role. Do not shrink
		# the Wolf source back to a small avatar at the spectacle distance.
		return Vector3.ONE
	if _actor.enemy_id == "bell_eater":
		# bell_eater_boss is normalized to its full 3.80 m focal-creature
		# contract; do not apply a second multiplicative scale here.
		return Vector3.ONE
	if _actor.enemy_id == "rootbound_colossus":
		# rootbound_colossus_boss is normalized to its full 4.40 m role.
		return Vector3.ONE
	if _actor.enemy_id == "ashwing":
		# ashwing_boss is normalized to its full 4.80 m flying-creature role.
		return Vector3.ONE
	if _actor.enemy_id == "halvern_boss":
		return Vector3(1.04, 1.04, 1.04)
	if _actor.enemy_id == "ghoulkin":
		return Vector3.ONE * 0.95
	if _actor.enemy_id == "wychwood_stalker":
		return Vector3(0.92, 0.96, 0.92)
	if _actor.enemy_id == "wychwood_raider":
		return Vector3.ONE
	if _actor.enemy_id == "wychwood_brute":
		return Vector3(1.08, 1.04, 1.08)
	if _actor.enemy_id == "bandit":
		return Vector3(0.95, 0.95, 0.95)
	return Vector3.ONE

func _enemy_shadow_scale() -> Vector3:
	if _actor.enemy_id == "bog_wretch":
		return Vector3(1.05, 0.014, 0.72)
	if _actor.enemy_id == "white_hart_avatar":
		return Vector3(1.25, 0.014, 0.85)
	if _actor.enemy_id == "rootbound_colossus":
		return Vector3(1.42, 0.014, 0.98)
	if _actor.enemy_id in ["bell_eater", "ashwing"]:
		return Vector3(1.18, 0.014, 0.88)
	if _actor.enemy_id == "halvern_boss":
		return Vector3(0.90, 0.014, 0.62)
	if _actor._is_wychwood_pack():
		return Vector3(0.88, 0.014, 0.62)
	return Vector3(0.82, 0.014, 0.58)

func setup(id: String, definition: Dictionary, target: Node3D) -> void:
	_actor.enemy_id = id
	_actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	_actor.floor_snap_length = 0.34
	_actor.floor_stop_on_slope = true
	_actor.display_name = definition.get("name", id)
	_actor.damage = float(definition.get("damage", 10.0))
	_actor.move_speed = float(definition.get("speed", 2.0))
	_actor.base_damage = _actor.damage
	_actor.base_move_speed = _actor.move_speed
	_actor.attack_range = float(definition.get("attack_range", 1.5))
	_actor.sense_range = float(definition.get("sense_range", 10.0))
	_actor.tag = definition.get("tag", "beast")
	_actor.weakness = definition.get("weakness", "")
	_actor.memory_rule = str(definition.get("memory_rule", ""))
	_actor.motivation = str(definition.get("motivation", ""))
	_actor.is_boss = bool(definition.get("boss", false))
	_actor.player = target
	# Some diagnostic and streaming callers configure the actor before attaching
	# it to the active scene. Reading global_position in that state emits an
	# engine error and can poison an otherwise valid runtime check.
	_actor.home_position = _actor.global_position if _actor.is_inside_tree() else _actor.position
	_actor.presence_home_yaw = _actor.rotation.y
	_actor.health_component = _actor.HealthComponent.new()
	_actor.add_child(_actor.health_component)
	_actor.health_component.configure(float(definition.get("health", 60.0)))
	_actor.health_component.changed.connect(_actor._on_health_changed)
	_actor.health_component.died.connect(_actor._on_died)
	_actor.base_color = Color(definition.get("color", "#665544"))
	_actor.behavior_profile = str(definition.get("behavior_profile", {
		"wychwood_stalker":"flanker", "wychwood_raider":"feinter",
		"wychwood_brute":"brute", "ghoulkin":"skirmisher"
	}.get(_actor.enemy_id, "direct")))
	_actor.perception_memory_duration = float(definition.get("perception_memory", 2.5))
	_actor.preferred_distance = float(definition.get("preferred_distance", {
		"flanker":2.65, "feinter":2.30, "brute":2.05, "skirmisher":2.40
	}.get(_actor.behavior_profile, 2.15)))
	_actor.approach_angle_degrees = float(definition.get("approach_angle", {
		"flanker":68.0, "feinter":34.0, "brute":0.0, "skirmisher":24.0
	}.get(_actor.behavior_profile, 0.0)))
	_actor.contact_radius = float(definition.get("contact_radius", 0.78 if _actor.behavior_profile == "brute" else 0.68))
	_actor.combat_rng = _actor.SeededRng.new((_actor.enemy_id + str(_actor.home_position)).hash())
	_actor.flank_sign = -1.0 if _actor.combat_rng.chance(0.5) else 1.0
	_actor._build_body(_actor.base_color)
	_actor.write_presentation_tag(_actor, "memory_rule", _actor.memory_rule)
	_actor.write_presentation_tag(_actor, "motivation", _actor.motivation)
