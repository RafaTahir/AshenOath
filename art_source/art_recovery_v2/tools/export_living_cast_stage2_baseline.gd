extends SceneTree

## Export exact retained prepared actors and their real Idle as authoring input.
## This is a bounded, explicit tool; source-only inspection never invokes it.
const IDS := ["C11", "C05", "C06", "C12", "C07", "C09", "C10", "C08"]
const FUSION = preload("res://scripts/character_animation_fusion.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://").path_join("../../art_source/art_recovery_v2/evidence/living_cast_stage2_20261107").simplify_path()
	var requested: Array[String] = []
	var args := OS.get_cmdline_user_args()
	var selected := args.find("--asset")
	if selected >= 0 and selected + 1 < args.size():
		requested.append(args[selected + 1])
	else:
		requested.assign(IDS)
	DirAccess.make_dir_recursive_absolute(output)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
	for id: String in requested:
		if id not in IDS:
			push_error("Unknown Stage2 actor: " + id)
			quit(1)
			return
		var path := ""
		var source := ""
		for key: String in catalog:
			if ("/" + id + "_") in str(catalog[key].source):
				path = str(catalog[key].path)
				source = str(catalog[key].source)
				break
		if path.is_empty() or not ResourceLoader.exists(path):
			push_error("Missing retained prepared actor: " + id)
			quit(1)
			return
		var destination := output.path_join(id + "_baseline.glb")
		var receipt_path := output.path_join(id + "_baseline.json")
		if FileAccess.file_exists(destination) and FileAccess.file_exists(receipt_path):
			var prior: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
			if prior is Dictionary and str(prior.get("production_sha256", "")) == FileAccess.get_sha256(source) and str(prior.get("baseline_sha256", "")) == FileAccess.get_sha256(destination) and str(prior.get("prepared_sha256", "")) == FileAccess.get_sha256(path):
				print("STAGE2_BASELINE_RETAINED ", id)
				continue
			push_error("Existing Stage2 baseline no longer matches retained sources: " + id)
			quit(1)
			return
		var actor := (load(path) as PackedScene).instantiate()
		var player := FUSION.attach_shared_library(actor)
		if player == null or not player.has_animation("Idle"):
			push_error("Missing real retained Idle: " + id)
			quit(1)
			return
		for library_name: StringName in player.get_animation_library_list():
			var library := player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
			for clip: StringName in library.get_animation_list():
				if clip != &"Idle":
					library.remove_animation(clip)
			player.remove_animation_library(library_name)
			player.add_animation_library(library_name, library)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_scene(actor, state)
		if error == OK:
			error = document.write_to_filesystem(state, destination)
		actor.free()
		if error != OK:
			push_error("Cannot export Stage2 baseline: %s (%d)" % [id, error])
			quit(1)
			return
		var receipt := FileAccess.open(receipt_path, FileAccess.WRITE)
		if receipt == null:
			push_error("Cannot record Stage2 baseline: " + id)
			quit(1)
			return
		receipt.store_string(JSON.stringify({"asset": id, "production_resource": source,
			"production_sha256": FileAccess.get_sha256(source), "prepared_resource": path,
			"prepared_sha256": FileAccess.get_sha256(path), "baseline_sha256": FileAccess.get_sha256(destination),
			"engine_version": Engine.get_version_info(), "runtime_verified": false}, "\t") + "\n")
		print("STAGE2_BASELINE_EXPORTED ", id)
	quit(0)
