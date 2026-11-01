extends SceneTree

## One source per invocation; writes only the explicitly requested record.
## No world, save, combat decisions or mutable authored animation resources.
const Helper = preload("res://scripts/asset_spawn_helper.gd")
const Driver = preload("res://scripts/character_animation_driver.gd")
const Enemy = preload("res://scripts/enemy_ai.gd")
const Profiles = preload("res://scripts/native_attack_profiles.gd")
const SELECTIONS := {
	"M01": ["ghoulkin", "ghoulkin_creature"], "M02": ["wychwood_stalker", "wychwood_stalker_creature"],
	"M03": ["bog_wretch", "bog_wretch_creature"], "M04": ["gravebound_knight", "gravebound_knight_creature"],
	"M05": ["bell_eater", "bell_eater_boss"], "M06": ["rootbound_colossus", "rootbound_colossus_boss"],
	"M07": ["ashwing", "ashwing_boss"], "M08": ["white_hart_avatar", "white_hart_boss"],
	"M09": ["silt_maw", "silt_maw"], "M10": ["millback", "millback"],
	"M11": ["glassmoth", "glassmoth"], "M12": ["knell_leech", "knell_leech"],
	"M13": ["hearthscale", "hearthscale"], "M14": ["gallows_weaver", "gallows_weaver"],
	"M15": ["reed_choir", "reed_choir"], "M16": ["inkblind", "inkblind"],
	"M17": ["cairn_mother", "cairn_mother"], "M18": ["shroud_swimmer", "shroud_swimmer"],
	"M19": ["wychwood_raider", "wychwood_raider_creature"], "M20": ["wychwood_brute", "wychwood_brute_creature"],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var id := ""
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--id="): id = argument.trim_prefix("--id=")
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not SELECTIONS.has(id) or output.is_empty():
		_fail("Required: --id=M01..M20 --output=<explicit record.json>")
		return
	var assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Profiles.ASSETS))
	var record: Dictionary = assets.assets[id]
	var source := str(record.path)
	if FileAccess.get_sha256(source) != str(record.sha256):
		_fail("Canonical source hash differs from the asset ledger: " + id)
		return
	var helper := Helper.new()
	helper.building_prepared_assets = true
	root.add_child(helper)
	var actor := Enemy.new()
	actor.enemy_id = str(SELECTIONS[id][0])
	actor.set_physics_process(false)
	root.add_child(actor)
	var visual: Node3D = helper._spawn_from_entry({"path": source}, str(SELECTIONS[id][1]), "enemies")
	if visual == null:
		_fail("Cannot instantiate exact calibration source: " + id)
		return
	helper.apply_normalized_scale(visual, actor._mapped_enemy_scale().y)
	actor.add_child(visual)
	actor._ground_mapped_visual(visual)
	var driver := Driver.new()
	visual.add_child(driver)
	if not driver.configure(visual, {"idle":"Idle", "attack":"Attack"}):
		_fail("Cannot bind authored Attack: " + id)
		return
	actor.animation_driver = driver
	actor._configure_attack_contact_bone()
	var skeleton: Skeleton3D = driver.get_skeleton()
	var clip: StringName = driver.get_clip_for_state("attack")
	var player: AnimationPlayer = driver.get_animation_player()
	var animation := player.get_animation(clip)
	if actor.attack_contact_bone < 0 or driver._bound_bone_tracks(clip) == 0 or not _probe_has_tracks(animation, skeleton, actor.attack_contact_bone):
		_fail("Attack has no enabled transform track on the actual contact probe ancestry: " + id)
		return
	# Sample the retained clip directly, with every additive pose owner disabled.
	# The gameplay graph/clock is tested separately; no blend or idle drift enters
	# this source calibration and no imported Animation resource is modified.
	driver.set_external_tick(true)
	driver.animation_graph.tree.active = false
	for modifier in skeleton.get_children():
		if modifier is SkeletonModifier3D: modifier.active = false
	player.active = true
	player.play(clip, 0.0)
	var seconds := animation.length
	var window := Vector2(0.28, 0.70) if id in Profiles.UAL_IDS else Vector2(0, 1)
	var samples: Array[Dictionary] = []
	var begin := window.x * seconds
	var end := window.y * seconds
	for index in range(int(ceil((end - begin) * 120.0)) + 1):
		var time := minf(begin + float(index) / 120.0, end)
		player.seek(time, true)
		player.advance(0.0)
		var point: Vector3 = actor._attack_contact_point()
		if not point.is_finite():
			_fail("Nonfinite authored contact probe: " + id)
			return
		samples.append({"seconds": time, "point": point})
	var timing := Profiles.choose_fraction(id, seconds, samples)
	if timing.is_empty():
		_fail("Cannot calibrate finite Attack samples: " + id)
		return
	var offset: Vector3 = actor.attack_contact_local_offset
	timing.merge({"id":id, "source":source, "source_sha256":str(record.sha256), "clip":str(clip), "duration_seconds":seconds,
		"probe_bone":str(skeleton.get_bone_name(actor.attack_contact_bone)), "probe_offset":[offset.x,offset.y,offset.z],
		"calibration_enemy":str(SELECTIONS[id][0]), "calibration_role":str(SELECTIONS[id][1]),
		"sampling_hz":120, "sample_window":[window.x,window.y], "sample_count":samples.size(), "policy":Profiles.POLICY}, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write the requested calibration record: " + output)
		return
	file.store_string(JSON.stringify(timing, "\t", true) + "\n")
	file.close()
	print("NATIVE ATTACK CALIBRATION ", id, " f=", timing.contact_fraction, " method=", timing.method, " output=", output)
	actor.free()
	helper.clear_runtime_caches()
	helper.free()
	quit(0)

func _probe_has_tracks(animation: Animation, skeleton: Skeleton3D, probe: int) -> bool:
	var ancestors: Array[String] = []
	while probe >= 0:
		ancestors.append(str(skeleton.get_bone_name(probe)))
		probe = skeleton.get_bone_parent(probe)
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		if animation.track_is_enabled(track) and animation.track_get_key_count(track) > 0 and animation.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D] and path.get_subname_count() > 0 and str(path.get_subname(0)) in ancestors:
			return true
	return false

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
