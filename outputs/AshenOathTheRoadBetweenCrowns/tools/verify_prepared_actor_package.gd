extends SceneTree

## Resource-only export regression. Run from an empty project with --pack-dir.
## Loads and instantiates actor resources without a world, playback or gameplay.
var failures: Array[String] = []

func _initialize() -> void:
	# Contact calibration must be available before any external pack mounts.
	var profile_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/native_attack_profiles.json")) if FileAccess.file_exists("res://data/native_attack_profiles.json") else null
	_check(profile_data is Dictionary and profile_data.get("profiles", {}).size() == 20, "Base pack must own all twenty native contact profiles")
	var args := OS.get_cmdline_user_args()
	var index := args.find("--pack-dir")
	if index < 0 or index + 1 >= args.size():
		push_error("Required: --pack-dir <directory of decoded candidate PCKs>")
		quit(1)
		return
	var directory := args[index + 1]
	var mounted := 0
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".pck") and file != "base.pck":
			_check(ProjectSettings.load_resource_pack(directory.path_join(file)), "Cannot mount " + file)
			mounted += 1
	_check(mounted >= 9, "Expected all nine decoded runtime pack candidates")
	if not failures.is_empty():
		_finish(0, 0)
		return
	_verify_resource_dependencies("res://")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
	_check(parsed is Dictionary, "Prepared actor catalog is missing or invalid")
	var database_script = load("res://scripts/asset_database.gd")
	var helper_script = load("res://scripts/asset_spawn_helper.gd")
	var bindings_script = load("res://scripts/character_material_bindings.gd")
	_check(database_script is Script and database_script.can_instantiate(), "Packed asset database script is missing or invalid")
	_check(helper_script is Script and helper_script.can_instantiate(), "Packed asset helper script is missing or invalid")
	_check(bindings_script is Script and bindings_script.can_instantiate(), "Packed material binding script is missing or invalid")
	if not failures.is_empty():
		_finish(0, 0)
		return
	var catalog: Dictionary = parsed
	var database = database_script.new()
	database.reload()
	var helper = helper_script.new()
	helper.setup(database)
	var seen := {}
	var omitted := {}
	for record: Dictionary in catalog.values():
		var source := str(record.source)
		if not source.begins_with("res://assets_external/design_pack_v1/"):
			continue
		var path := str(record.path)
		_check(ResourceLoader.exists(path), "Compiled scene missing: " + path)
		if not ResourceLoader.exists(source):
			omitted[source] = true
			_check(record.get("source_scene_dependencies", [source]).is_empty(), "Omitted a required source: " + source)
		var role := str(record.role)
		for roles: Dictionary in database.manifest.get("roles", {}).values():
			if roles.has(role):
				_check(database.has_asset_for_role(role), "Curated lookup requires omitted source: " + role)
		for roles: Dictionary in database.visual_upgrade.get("roles", {}).values():
			if roles.has(role):
				_check(database.has_visual_asset_for_role(role), "Visual lookup requires omitted source: " + role)
		if seen.has(path):
			continue
		seen[path] = true
		# Exercise actual selection/instantiation without gameplay proportion
		# acceptance. Check serialized material restoration explicitly below.
		var actor: Node3D = helper._spawn_from_entry({"path":source}, role, "resource_check")
		_check(actor != null, "Compiled actor failed to instantiate: " + role)
		if actor != null:
			_check(str(actor.get_meta("prepared_actor_source", "")) == source, "Actor used authored-source recovery: " + role)
			_check(bool(bindings_script.restore(actor)), "Compiled actor materials could not be restored: " + role)
			_check(bool(actor.get_meta("character_material_bindings_valid", false)), "Compiled actor material failed: " + role)
			actor.free()
	_check(omitted.size() >= 32, "Standalone source scenes were not excluded from the package")
	_verify_companion_body()
	# The arrow is a dynamic held/quiver/projectile load. A script string alone
	# cannot make Godot include it in an exported pack.
	_check(load("res://assets/characters/kael_arrow.glb") is PackedScene, "Opening pack omitted the authored hunting arrow")
	helper.clear_runtime_caches()
	helper.free()
	database.free()
	_finish(seen.size(), omitted.size())

func _verify_companion_body() -> void:
	var script := load("res://scripts/companion_controller.gd") as Script
	var path := str(script.get_script_constant_map().get("BODY_PATH", "")) if script != null else ""
	var body := load(path) as PackedScene if not path.is_empty() else null
	_check(body != null and body.can_instantiate(), "Packed companion body is missing: " + path)
	if body != null and path.begins_with("res://assets_external/characters_prepared/"):
		var contract: Variant = body.get_meta("companion_contract", {})
		_check(contract is Dictionary and int(contract.get("schema_version", 0)) == 1, "Prepared companion body lost its raw-root contract")

func _verify_resource_dependencies(directory: String) -> void:
	var files := DirAccess.open(directory)
	if files == null:
		_check(false, "Cannot inspect packed directory: " + directory)
		return
	files.include_hidden = true
	files.list_dir_begin()
	var file := files.get_next()
	while not file.is_empty():
		var path := directory.path_join(file)
		if files.current_is_dir():
			_verify_resource_dependencies(path)
		elif path.get_extension() in ["res", "tres", "scn", "tscn", "glb", "gltf"]:
			for encoded: String in ResourceLoader.get_dependencies(path):
				var dependency := ""
				for component: String in encoded.split("::"):
					if component.begins_with("res://"):
						dependency = component
						break
				if dependency.is_empty() and encoded.begins_with("uid://"):
					var uid := ResourceUID.text_to_id(encoded.get_slice("::", 0))
					if ResourceUID.has_id(uid):
						dependency = ResourceUID.get_id_path(uid)
				_check(not dependency.is_empty() and ResourceLoader.exists(dependency), "Missing packed dependency: %s -> %s" % [path, encoded])
		file = files.get_next()
	files.list_dir_end()

func _check(valid: bool, message: String) -> void:
	if not valid:
		failures.append(message)

func _finish(scenes: int, omitted: int) -> void:
	for failure in failures:
		push_error(failure)
	print("PREPARED ACTOR PACKAGE: %s (%d compiled scenes; %d omitted source scenes; no gameplay)" % ["PASS" if failures.is_empty() else "FAIL", scenes, omitted])
	quit(0 if failures.is_empty() else 1)
