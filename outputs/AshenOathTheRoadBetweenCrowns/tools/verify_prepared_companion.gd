extends SceneTree

## Compares the actual raw import with the separately prepared companion root.
## No enemy normalization, game world, saves, or locomotion simulation is used.
const RAW := "res://assets_external/design_pack_v1/creatures/M13_Hearthscale.glb"
const PREPARED := "res://assets_external/characters_prepared/companions/bracken.scn"
const Care = preload("res://scripts/companion_pose.gd")
const Companion = preload("res://scripts/companion_controller.gd")
var failures: Array[String] = []
var checks := 0
var measurements: Array[Dictionary] = []

class IsolatedCompanion extends Companion:
	func _physics_process(_delta: float) -> void: pass
	func refresh_presence() -> void: pass

class SavedState extends RefCounted:
	var flags: Dictionary = {}
	func get_flag(key: String, fallback: Variant = null) -> Variant: return flags.get(key, fallback)
	func set_flag(key: String, value: Variant) -> void: flags[key] = value

class SavedZones extends RefCounted:
	func _normalize_zone(value: String) -> String: return value

class Host extends Node3D:
	var zone_root := Node3D.new()
	var story_state := SavedState.new()
	var save_manager := SavedZones.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw_source := load(RAW) as PackedScene
	var prepared_source := load(PREPARED) as PackedScene
	_check(raw_source != null and prepared_source != null, "raw and prepared Hearthscale companion resources exist")
	if raw_source == null or prepared_source == null:
		_finish()
		return
	var raw := raw_source.instantiate() as Node3D
	var prepared := prepared_source.instantiate() as Node3D
	root.add_child(raw)
	root.add_child(prepared)
	var contract: Dictionary = prepared.get_meta("companion_contract", {})
	_check(int(contract.get("schema_version", 0)) == 1, "prepared root carries the companion-specific contract")
	_check(str(contract.get("source_path", "")) == RAW and str(contract.get("source_sha256", "")) == FileAccess.get_sha256(RAW), "prepared receipt matches the exact current raw body")
	_check(contract.get("raw_root_transform") is Transform3D and raw.transform.is_equal_approx(contract.raw_root_transform), "prepared contract records the actual unnormalized root transform")
	_compare_nodes(raw, prepared)
	var original := _binding(raw)
	var candidate := _binding(prepared)
	if original.is_empty() or candidate.is_empty():
		raw.free()
		prepared.free()
		_finish()
		return
	_check(str(contract.get("animation_player_path", "")) == str(prepared.get_path_to(candidate.player)), "prepared player path resolves without changing the animation root")
	_check(str(contract.get("skeleton_path", "")) == str(prepared.get_path_to(candidate.skeleton)), "prepared care skeleton path is exact")
	_check(contract.get("clips", {}) == candidate.clips and original.clips == candidate.clips, "native Idle/Walking clip identities are unchanged")
	_check(contract.get("care_bones", {}) == candidate.care_bones and original.care_bones == candidate.care_bones, "actual Head/Neck/Tail care bindings are unchanged")
	for key: String in original.clips:
		_compare_animation(original.player.get_animation(original.clips[key]), candidate.player.get_animation(candidate.clips[key]), key)
	# Reproduce the existing controller's assignments exactly. Retaining the
	# root origin matters: a normalized enemy scene would fail these samples.
	for visual: Node3D in [raw, prepared]:
		visual.rotation.y = PI
		visual.scale = Vector3.ONE * 0.62
	for binding: Dictionary in [original, candidate]:
		binding.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var care := Care.new()
		care.name = "BrackenCarePose"
		care.configure(binding.skeleton)
		binding.skeleton.add_child(care)
		care.active = false
		binding["care"] = care
	for key: String in ["idle", "walk"]:
		var duration: float = original.player.get_animation(original.clips[key]).length
		for phase: float in [0.0, 0.125, 0.5, 0.875]:
			for action: String in ["", "pet", "feed", "rest", "sniff"]:
				for binding: Dictionary in [original, candidate]:
					binding.player.play(binding.clips[key])
					binding.player.seek(duration * phase, true)
					if action != "":
						binding.care.pose(action, 3.0)
						binding.care.elapsed = 0.9
						binding.care._process_modification()
					binding.skeleton.force_update_all_bone_transforms()
				_compare_sample(original, candidate, key, phase, action)
	raw.free()
	prepared.free()
	if "--visual-only" not in OS.get_cmdline_user_args(): _verify_runtime()
	_finish()

func _binding(visual: Node3D) -> Dictionary:
	var player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		var skeletons := visual.find_children("*", "Skeleton3D", true, false)
		skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	_check(player != null and skeleton != null, str(visual.name) + " retains the current animation player and skeleton")
	if player == null or skeleton == null: return {}
	var clips: Dictionary = {}
	for key: String in ["idle", "walk"]:
		var suffix := "Idle" if key == "idle" else "Walking"
		var matches: Array[String] = []
		for clip: StringName in player.get_animation_list():
			if str(clip).get_file() == suffix: matches.append(str(clip))
		_check(matches.size() == 1, str(visual.name) + " resolves one native " + suffix + " clip")
		if matches.size() != 1: return {}
		clips[key] = matches[0]
	var care := Care.new()
	care.configure(skeleton)
	_check(care.head >= 0 and care.tail >= 0, str(visual.name) + " resolves the actual Hearthscale head and tail care bones")
	# The retained M13 has no Neck bone. The existing modifier skips that
	# optional channel; the derivative must preserve absence, not invent a rig.
	var bones := {"head":str(skeleton.get_bone_name(care.head)) if care.head >= 0 else "", "neck":str(skeleton.get_bone_name(care.neck)) if care.neck >= 0 else "", "tail":str(skeleton.get_bone_name(care.tail)) if care.tail >= 0 else ""}
	care.free()
	return {"visual":visual, "player":player, "skeleton":skeleton, "clips":clips, "care_bones":bones}

func _compare_nodes(original: Node, candidate: Node) -> void:
	_check(original.get_class() == candidate.get_class(), "node class retained: " + str(original.name))
	if original is Node3D and candidate is Node3D:
		_check(original.transform.is_equal_approx(candidate.transform), "raw local transform retained: " + str(original.name))
	if original is AnimationPlayer and candidate is AnimationPlayer:
		_check(original.root_node == candidate.root_node and original.root_motion_track == candidate.root_motion_track, "animation root and root-motion setting retained")
	if original is Skeleton3D and candidate is Skeleton3D:
		_check(original.get_bone_count() == candidate.get_bone_count(), "native bone count retained")
		for index in mini(original.get_bone_count(), candidate.get_bone_count()):
			_check(original.get_bone_name(index) == candidate.get_bone_name(index) and original.get_bone_parent(index) == candidate.get_bone_parent(index), "native bone hierarchy retained: " + str(index))
			_check(original.get_bone_rest(index).is_equal_approx(candidate.get_bone_rest(index)), "native bone rest retained: " + str(index))
	if original is MeshInstance3D and candidate is MeshInstance3D:
		_check(original.mesh != null and candidate.mesh != null, "actual mesh retained: " + str(original.name))
		if original.mesh != null and candidate.mesh != null:
			_check(original.mesh.get_faces() == candidate.mesh.get_faces(), "actual rendered triangles retained: " + str(original.name))
			_check(original.get_aabb().is_equal_approx(candidate.get_aabb()), "actual mesh bounds retained: " + str(original.name))
			_check(original.mesh.get_surface_count() == candidate.mesh.get_surface_count(), "actual mesh surfaces retained: " + str(original.name))
			for surface in mini(original.mesh.get_surface_count(), candidate.mesh.get_surface_count()):
				var first: Array = original.mesh.surface_get_arrays(surface)
				var second: Array = candidate.mesh.surface_get_arrays(surface)
				_check(first[Mesh.ARRAY_BONES] == second[Mesh.ARRAY_BONES] and first[Mesh.ARRAY_WEIGHTS] == second[Mesh.ARRAY_WEIGHTS], "actual skinning weights retained: " + str(original.name) + "/" + str(surface))
		_check(original.skeleton == candidate.skeleton, "mesh skeleton path retained: " + str(original.name))
		_check((original.skin == null) == (candidate.skin == null), "mesh bind resource retained: " + str(original.name))
		if original.skin != null and candidate.skin != null:
			_check(original.skin.get_bind_count() == candidate.skin.get_bind_count(), "skin bind count retained: " + str(original.name))
			for index in mini(original.skin.get_bind_count(), candidate.skin.get_bind_count()):
				_check(original.skin.get_bind_name(index) == candidate.skin.get_bind_name(index) and original.skin.get_bind_bone(index) == candidate.skin.get_bind_bone(index) and original.skin.get_bind_pose(index).is_equal_approx(candidate.skin.get_bind_pose(index)), "skin bind retained: " + str(original.name) + "/" + str(index))
	_check(original.get_child_count() == candidate.get_child_count(), "raw hierarchy retained: " + str(original.name))
	for index in mini(original.get_child_count(), candidate.get_child_count()):
		_check(original.get_child(index).name == candidate.get_child(index).name, "child identity retained at " + str(original.name) + "/" + str(index))
		_compare_nodes(original.get_child(index), candidate.get_child(index))

func _compare_animation(original: Animation, candidate: Animation, kind: String) -> void:
	_check(is_equal_approx(original.length, candidate.length) and original.get_track_count() == candidate.get_track_count(), kind + " duration and native track count retained")
	for track in mini(original.get_track_count(), candidate.get_track_count()):
		_check(original.track_get_path(track) == candidate.track_get_path(track) and original.track_get_type(track) == candidate.track_get_type(track) and original.track_get_interpolation_type(track) == candidate.track_get_interpolation_type(track), kind + " track binding retained: " + str(track))
		_check(original.track_get_key_count(track) == candidate.track_get_key_count(track), kind + " native key count retained: " + str(track))
		for key in mini(original.track_get_key_count(track), candidate.track_get_key_count(track)):
			_check(is_equal_approx(original.track_get_key_time(track,key), candidate.track_get_key_time(track,key)) and original.track_get_key_value(track,key) == candidate.track_get_key_value(track,key), kind + " native key retained: " + str(track) + "/" + str(key))

func _compare_sample(original: Dictionary, candidate: Dictionary, clip: String, phase: float, action: String) -> void:
	var worst := 0.0
	for index in mini(original.skeleton.get_bone_count(), candidate.skeleton.get_bone_count()):
		var first: Transform3D = original.skeleton.global_transform * original.skeleton.get_bone_global_pose(index)
		var second: Transform3D = candidate.skeleton.global_transform * candidate.skeleton.get_bone_global_pose(index)
		worst = maxf(worst, first.origin.distance_to(second.origin))
		_check(first.is_equal_approx(second), "%s %.3f %s retains actual world bone %s" % [clip,phase,action,original.skeleton.get_bone_name(index)])
	measurements.append({"clip":clip,"phase":phase,"care":action,"max_world_bone_error":worst})

func _verify_runtime() -> void:
	_check(Companion.BODY_PATH == PREPARED, "actual controller uses the separately verified companion derivative")
	if Companion.BODY_PATH != PREPARED: return
	var host := Host.new()
	root.add_child(host)
	host.add_child(host.zone_root)
	var companion := IsolatedCompanion.new()
	companion.game = host
	companion.zone_id = "hearthward"
	host.zone_root.add_child(companion)
	_check(companion.visual != null and companion.animation_player != null and companion.care_pose != null, "actual controller binds prepared body, clips and care owner")
	var shapes: Array[Node] = companion.find_children("*", "CollisionShape3D", false, false)
	_check(shapes.size() == 1, "actual companion retains one body collision shape")
	if shapes.size() == 1:
		var capsule := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D
		_check(capsule != null and is_equal_approx(capsule.radius, 0.24) and is_equal_approx(capsule.height, 0.7) and (shapes[0] as Node3D).position.is_equal_approx(Vector3(0,0.35,0)), "body capsule radius, height and floor clearance are unchanged")
	_check(companion.collision_layer == 0 and companion.collision_mask == 1 and is_equal_approx(companion.floor_snap_length, 0.3) and is_equal_approx(Companion.CLEARANCE, 0.55), "collision masks, snap and travel clearance are unchanged")
	if companion.animation_player != null:
		companion.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for key: String in ["idle", "walk"]:
			_check(companion.animation_player.has_animation(companion.clips[key]) and companion.animation_player.get_animation(companion.clips[key]).loop_mode == Animation.LOOP_LINEAR, "actual " + key + " mapping loops as before")
		for speed: float in [0.0, 0.08, 0.09, 1.7, 5.0]:
			companion._set_animation(speed)
			_check(str(companion.animation_player.current_animation) == str(companion.clips.walk if speed > 0.08 else companion.clips.idle), "actual movement threshold retains its clip at speed " + str(speed))
			_check(is_equal_approx(companion.animation_player.speed_scale, clampf(speed / 1.7, 0.55, 2.0) if speed > 0.08 else 1.0), "actual walking rate is unchanged at speed " + str(speed))
	if companion.care_pose != null:
		var rig: Skeleton3D = companion.care_pose.get_skeleton()
		var head := int(companion.care_pose.head)
		_check(head >= 0, "actual care contact binds the retained head")
		if head >= 0:
			var point := rig.global_transform * rig.get_bone_global_pose(head).origin
			_check(companion.care_contact_point("pet").is_equal_approx(point + Vector3.UP*0.05) and companion.care_contact_point("feed").is_equal_approx(point - Vector3.UP*0.03), "Kael's pet/feed target retains the actual head contact offsets")
	companion.adopted = true
	companion.placement_pending = false
	companion.command = "wait"
	companion.last_safe_position = Vector3(2.5,0.2,-4)
	companion.capture_state()
	var saved := Companion.saved_travel(host)
	_check(saved.command == "wait" and saved.zone == "hearthward" and saved.position.is_equal_approx(companion.last_safe_position), "prepared presentation preserves companion travel save round-trip")
	host.free()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _finish() -> void:
	for failure: String in failures: printerr("PREPARED COMPANION: " + failure)
	print("PREPARED COMPANION: " + JSON.stringify({"status":"pass" if failures.is_empty() else "fail","checks":checks,"samples":measurements,"raw":RAW,"prepared":PREPARED,"runtime_checked":"--visual-only" not in OS.get_cmdline_user_args()}))
	quit(0 if failures.is_empty() else 1)
