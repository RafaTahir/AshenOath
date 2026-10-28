extends SceneTree
## Immutable current-runtime baseline and numerical replacement acceptance.
## No world, quest, save, renderer, physics stepping, or gameplay writes.
## --capture refuses overwrite; default mode compares current live mappings.

const Enemy = preload("res://scripts/enemy_ai.gd")
const RoleSpec = preload("res://scripts/character_role_spec.gd")
const BASELINE := "res://.release-gate/spectral-monsters/baseline.json"
const REPORT := "res://.release-gate/spectral-monsters/runtime-report.json"
const FIXTURE := "res://tools/fixtures/spectral_runtime_baseline.json.gz"
const IDS := ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bog_wretch", "gravebound_knight", "bell_eater", "rootbound_colossus", "ashwing", "white_hart_avatar"]
const ROLES := ["ghoulkin_creature", "wychwood_stalker_creature", "wychwood_raider_creature", "wychwood_brute_creature", "bog_wretch_creature", "gravebound_knight_creature", "bell_eater_boss", "rootbound_colossus_boss", "ashwing_boss", "white_hart_boss"]
const TARGETS := [
	"res://assets_external/characters_universal/runtime/spectral/Ghoulkin_Spectral_Atlas.gltf",
	"res://assets_external/enemies/spectral/Stalker_Spectral.gltf",
	"res://assets_external/enemies/spectral/Raider_Spectral.gltf",
	"res://assets_external/enemies/spectral/Brute_Spectral.gltf",
	"res://assets_external/characters_universal/runtime/spectral/BogWretch_Spectral_Atlas.gltf",
	"res://assets_external/enemies/spectral/Gravebound_Spectral.gltf",
	"res://assets_external/characters_universal/runtime/spectral/BellEater_Spectral_Atlas.gltf",
	"res://assets_external/enemies/spectral/Rootbound_Spectral.gltf",
	"res://assets_external/enemies/spectral/Ashwing_Spectral.gltf",
	"res://assets_external/enemies/spectral/WhiteHart_Spectral.gltf",
]
const STATES := ["idle", "walk", "run", "windup", "attack", "hit", "death"]
const PHASES := [0.0, 0.25, 0.5, 0.75, 0.95]
const LOCKED_FILES := ["res://data/enemies.json", "res://scripts/enemy_ai.gd", "res://scripts/character_role_spec.gd", "res://scripts/boss_encounter.gd", "res://scripts/story_encounter_director.gd", "res://scripts/saga_encounters.gd", "res://scripts/story_state.gd", "res://scripts/character_animation_driver.gd", "res://scripts/systems/character_animation_graph.gd"]

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

var checks := 0
var failures: Array[String] = []
var error_log := ErrorLog.new()

func _initialize() -> void: call_deferred("_run")

func _baseline() -> Dictionary:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline="):
			return JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--baseline=")))
	return JSON.parse_string(FileAccess.get_file_as_string(BASELINE) if FileAccess.file_exists(BASELINE) else FileAccess.get_file_as_bytes(FIXTURE).decompress_dynamic(67108864, FileAccess.COMPRESSION_GZIP).get_string_from_utf8())

func _run() -> void:
	OS.add_logger(error_log)
	var packed := "--packed-candidate" in OS.get_cmdline_user_args()
	if packed:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_pack_manifest.json"))
		for spec: Dictionary in manifest.packs.values():
			if str(spec.get("url", "")).is_empty(): continue
			_check(ProjectSettings.load_resource_pack(ProjectSettings.globalize_path("res://packs/" + str(spec.candidate_artifact)), false), "mount declared candidate pack")
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture and FileAccess.file_exists(BASELINE):
		_check(false, "immutable baseline already exists; refusing overwrite")
		_finish()
		return
	if not capture and not packed and not FileAccess.file_exists(BASELINE) and not FileAccess.file_exists(FIXTURE):
		_check(false, "capture the original live mappings before comparison")
		_finish()
		return
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var record := {"schema_version":1, "kind":"actual_spawn_rig_contact_baseline", "phases":PHASES, "states":STATES, "locked_files":{}, "actors":{}}
	if not packed:
		for path: String in LOCKED_FILES:
			record.locked_files[path] = FileAccess.get_sha256(path)
	else:
		record["scope"] = "packed actor contracts; source implementation hashes checked before export"
	for index in IDS.size():
		record.actors[IDS[index]] = _snapshot(IDS[index], ROLES[index], definitions[IDS[index]])
		await process_frame
	if not capture:
		var baseline: Dictionary = _baseline()
		if not packed:
			_check(record.locked_files == baseline.locked_files, "combat, profiles, encounter and save implementation hashes unchanged")
		for id: String in IDS:
			_compare_actor(id, baseline.actors.get(id, {}), record.actors.get(id, {}))
			var expected: String = str(baseline.actors[id].source) if "--baseline-self-check" in OS.get_cmdline_user_args() else TARGETS[IDS.find(id)]
			_check(str(record.actors[id].get("source", "")) == expected, id + " resolves the expected live source " + expected)
	_check(error_log.errors.is_empty(), "no engine or script errors while sampling actual actors")
	if failures.is_empty():
		_write(BASELINE if capture else REPORT, record)
		print("SPECTRAL MONSTERS %s: %s" % ["BASELINE" if capture else "REPORT", BASELINE if capture else REPORT])
	elif not capture:
		_write(REPORT.trim_suffix(".json") + ".failed.json", record)
	_finish()

func _snapshot(id: String, role: String, definition: Dictionary) -> Dictionary:
	var stage := Node3D.new()
	root.add_child(stage)
	var target := Node3D.new()
	stage.add_child(target)
	target.position = Vector3(0, 0, -10)
	var actor := Enemy.new()
	stage.add_child(actor)
	actor.setup(id, definition, target)
	actor.set_physics_process(false)
	actor.set_process(false)
	var driver = actor.animation_driver
	_check(driver != null and driver.is_valid(), id + " valid real animation driver")
	if driver == null or not driver.is_valid():
		stage.free()
		return {}
	driver.set_external_tick(true)
	driver.set_process(false)
	driver.set_physics_process(false)
	if driver.manual_tick_timer != null: driver.manual_tick_timer.stop()
	var mapped := actor.visual_root.get_node(id + "_visual") as Node3D
	var skeleton: Skeleton3D = driver.get_skeleton()
	var skeletons := mapped.find_children("*", "Skeleton3D", true, false)
	_check(skeletons.size() == (2 if id == "ashwing" else 1), id + " retains existing skeleton count")
	_check(actor.attack_contact_bone >= 0, id + " uses a bone contact")
	var entry := {"role":role, "source":str(mapped.get_meta("runtime_asset_path", mapped.get_meta("prepared_actor_source", ""))),
		"definition":definition, "role_spec":_plain(RoleSpec.for_role(role)), "bone_count":skeleton.get_bone_count(),
		"bones":[], "other_skeletons":[], "skeleton_count":skeletons.size(), "skins":[], "clips":{}, "contacts":{}, "poses":{}, "collisions":[],
		"mapped_transform":_plain(mapped.transform), "skeleton_transform":_plain(skeleton.global_transform),
		"source_bounds":_plain(mapped.get_meta("character_source_bounds", AABB())),
		"normalization_scale":float(mapped.get_meta("character_normalization_scale", 0.0)),
		"contact_bone":skeleton.get_bone_name(actor.attack_contact_bone) if actor.attack_contact_bone >= 0 else "",
		"contact_offset":_plain(actor.attack_contact_local_offset), "windup_duration":actor._windup_duration(),
		"root_motion_disabled":driver.root_motion_disabled, "mesh_budget":{}}
	# Direct manifest resolution avoids relying on optional diagnostic metadata.
	entry.source = str(actor.asset_helper.database.get_visual_asset_for_role(role).get("path", ""))
	for index in skeleton.get_bone_count():
		entry.bones.append({"name":skeleton.get_bone_name(index), "parent":skeleton.get_bone_parent(index), "rest":_plain(skeleton.get_bone_rest(index))})
	for extra: Skeleton3D in skeletons:
		if extra == skeleton: continue
		var extra_bones: Array = []
		for index in extra.get_bone_count():
			extra_bones.append({"name":extra.get_bone_name(index), "parent":extra.get_bone_parent(index), "rest":_plain(extra.get_bone_rest(index))})
		entry.other_skeletons.append({"transform":_plain(extra.global_transform), "bones":extra_bones})
	for child in actor.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			entry.collisions.append({"height":child.shape.height, "radius":child.shape.radius, "transform":_plain(child.transform)})
	entry.mesh_budget = _mesh_budget(mapped, skeleton, entry.skins, id)
	var player: AnimationPlayer = driver.get_animation_player()
	# Disable the graph only for exact native-clip phase probes. The real setup,
	# role mapping, normalization, contact selection and grounding already ran.
	driver.animation_graph.tree.active = false
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.active = true
	for state: String in STATES:
		var clip: StringName = driver.get_clip_for_state(state)
		_check(clip != StringName() and player.has_animation(clip), id + " resolves " + state)
		if clip == StringName() or not player.has_animation(clip): continue
		var animation: Animation = player.get_animation(clip)
		entry.clips[state] = {"name":str(clip), "length":animation.length, "loop":animation.loop_mode}
		var points: Array = []
		var poses: Array = []
		for phase: float in PHASES:
			skeleton.reset_bone_poses()
			player.play(clip, 0.0)
			player.seek(animation.length * phase, true, true)
			skeleton.force_update_all_bone_transforms()
			var point: Vector3 = actor._attack_contact_point()
			_check(point.is_finite(), id + " finite " + state + " contact at " + str(phase))
			points.append(_plain(point))
			# All bone poses also cover the FBX-to-glTF conversion where binary
			# sampler equality across different source formats is not meaningful.
			var pose: Array = []
			for index in skeleton.get_bone_count(): pose.append(_plain(skeleton.get_bone_pose(index)))
			poses.append(pose)
		entry.contacts[state] = points
		entry.poses[state] = poses
	var windup_points: Array = entry.contacts.get("windup", [])
	var spread := 0.0
	for point: Array in windup_points:
		for other: Array in windup_points:
			spread = maxf(spread, Vector3(point[0], point[1], point[2]).distance_to(Vector3(other[0], other[1], other[2])))
	_check(spread > 0.0001, id + " actual sampled windup contact moves (not an inactive-player rest pose)")
	entry.windup_contact_spread = spread
	player.stop()
	_check(bool(entry.root_motion_disabled), id + " physics retains root-motion ownership")
	print("SPECTRAL PROBE %s bones=%d contact=%s triangles=%d surfaces=%d" % [id, entry.bone_count, entry.contact_bone, entry.mesh_budget.triangles, entry.mesh_budget.surfaces])
	actor.asset_helper.clear_runtime_caches()
	stage.free()
	return entry

func _mesh_budget(mapped: Node3D, skeleton: Skeleton3D, skins: Array, id: String) -> Dictionary:
	var result := {"triangles":0, "surfaces":0, "meshes":0, "skinned_meshes":0, "max_texture_side":0, "transparent_surfaces":0}
	var skin_keys: Dictionary = {}
	for node in mapped.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null: continue
		result.meshes += 1
		if instance.skin != null:
			result.skinned_meshes += 1
			var mesh_skeleton := instance.get_node_or_null(instance.skeleton) as Skeleton3D
			_check(mesh_skeleton != null, id + " explicit mesh skeleton binding")
			if mesh_skeleton == null: mesh_skeleton = skeleton
			var binds: Array = []
			for bind in instance.skin.get_bind_count():
				var bone := instance.skin.get_bind_bone(bind)
				var name := str(instance.skin.get_bind_name(bind))
				if not name.is_empty(): bone = mesh_skeleton.find_bone(name)
				_check(bone >= 0 and bone < mesh_skeleton.get_bone_count(), id + " valid skin bind")
				if bone >= 0 and bone < mesh_skeleton.get_bone_count():
					binds.append({"name":mesh_skeleton.get_bone_name(bone), "pose":_plain(instance.skin.get_bind_pose(bind))})
			var key := JSON.stringify(binds)
			if not skin_keys.has(key):
				skin_keys[key] = true
				skins.append(binds)
		for surface in instance.mesh.get_surface_count():
			result.surfaces += 1
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			result.triangles += int(indices.size() / 3) if indices != null and indices.size() > 0 else int(vertices.size() / 3)
			for vertex: Vector3 in vertices:
				if not vertex.is_finite(): _check(false, id + " finite mesh vertex")
			if instance.skin != null:
				var bones = arrays[Mesh.ARRAY_BONES]
				var weights = arrays[Mesh.ARRAY_WEIGHTS]
				_check(bones != null and weights != null and bones.size() == weights.size() and bones.size() in [vertices.size() * 4, vertices.size() * 8], id + " valid per-vertex skin arrays")
				if weights != null and vertices.size() > 0:
					var stride := int(weights.size() / vertices.size())
					var valid_weights := true
					for vertex in vertices.size():
						var total := 0.0
						for slot in stride:
							var offset := vertex * stride + slot
							var weight := float(weights[offset])
							total += weight
							valid_weights = valid_weights and is_finite(weight) and weight >= 0.0 and (weight == 0.0 or (int(bones[offset]) >= 0 and int(bones[offset]) < instance.skin.get_bind_count()))
						valid_weights = valid_weights and absf(total - 1.0) < 0.002
					_check(valid_weights, id + " normalized finite skin weights")
			var material := instance.get_active_material(surface)
			_check(material != null, id + " authored surface material")
			if material is BaseMaterial3D:
				if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: result.transparent_surfaces += 1
				for texture in [material.albedo_texture, material.normal_texture, material.roughness_texture, material.metallic_texture, material.emission_texture]:
					if texture != null: result.max_texture_side = maxi(result.max_texture_side, maxi(texture.get_width(), texture.get_height()))
	return result

func _compare_actor(id: String, old: Dictionary, current: Dictionary) -> void:
	_check(not old.is_empty() and not current.is_empty(), id + " complete snapshots")
	if old.is_empty() or current.is_empty(): return
	for key in ["definition", "role_spec", "bone_count", "skeleton_count", "contact_bone", "root_motion_disabled"]:
		_check(_same(old[key], current[key], 0.000001), id + " unchanged " + key)
	for key in ["bones", "other_skeletons", "skins", "clips", "collisions", "contact_offset", "windup_duration"]:
		_check(_same(old[key], current[key], 0.0001), id + " preserved " + key)
	for key in ["mapped_transform", "skeleton_transform", "source_bounds"]:
		_check(_same(old[key], current[key], 0.0001), id + " preserved normalization/grounding " + key)
	# Baked sources encode part of their scale in node transforms. The authored
	# interchange can factor that scale differently; the complete world matrices
	# and every contact/pose above and below remain the physical contract.
	_check(is_finite(float(current.normalization_scale)) and float(current.normalization_scale) > 0.0, id + " finite positive normalization factor")
	_check(_same(old.contacts, current.contacts, 0.002), id + " world contact trajectory within 2 mm at every clip phase")
	_check(_same(old.poses, current.poses, 0.0002), id + " sampled complete skeleton poses unchanged")
	var ceiling := 20000 if id == "gravebound_knight" else (24000 if bool(current.definition.get("boss", false)) else 18000)
	_check(int(current.mesh_budget.triangles) <= ceiling, id + " measured triangle ceiling " + str(ceiling))
	_check(int(current.mesh_budget.surfaces) <= int(old.mesh_budget.surfaces) + 4, id + " bounded additional spectral surfaces (at most four)")
	_check(int(current.mesh_budget.max_texture_side) <= maxi(1024, int(old.mesh_budget.max_texture_side)), id + " texture dimensions do not grow beyond baseline/1K")

func _same(a, b, tolerance: float) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a) - float(b)) <= tolerance
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _same(a[i], b[i], tolerance): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key], tolerance): return false
		return true
	return a == b

func _plain(value):
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Transform3D: return [_plain(value.basis.x), _plain(value.basis.y), _plain(value.basis.z), _plain(value.origin)]
	if value is AABB: return {"position":_plain(value.position), "size":_plain(value.size)}
	if value is Dictionary:
		var result := {}
		for key in value: result[str(key)] = _plain(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_plain(item))
		return result
	return value

func _write(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "write verification artifact " + path)
	if file != null: file.store_string(JSON.stringify(data, "\t") + "\n")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("SPECTRAL FAILURE: " + message)

func _finish() -> void:
	OS.remove_logger(error_log)
	for error: String in error_log.errors: print("SPECTRAL ENGINE ERROR: " + error)
	print("SPECTRAL MONSTERS: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() and error_log.errors.is_empty() else "FAIL", checks, failures.size() + error_log.errors.size()])
	quit(0 if failures.is_empty() and error_log.errors.is_empty() else 1)
