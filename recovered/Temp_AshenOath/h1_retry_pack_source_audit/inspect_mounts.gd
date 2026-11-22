extends SceneTree

func _initialize() -> void:
	var output := "D:/Temp/AshenOath/h1_retry_pack_source_audit/mounted_hashes.json"
	var paths := ["scripts/mobile_touch_controls.gdc","scripts/input_router.gdc","scripts/player_controller.gdc","scripts/hud/hud_input.gdc","scripts/hud/hud_lifecycle.gdc","scripts/systems/hud_coordinator.gdc","scripts/zone_runtime_coordinator.gdc"]
	var stages := []
	var baseline := {}
	for path: String in paths:
		baseline[path] = FileAccess.get_sha256("res://" + path)
	stages.append({"mount":"actual_root_index","hashes":baseline.duplicate()})
	for id: String in ["base","opening","opening_materials","adjacent","characters","monsters","campaign","audio","quality_materials"]:
		var pack := "D:/Temp/AO_H1_retry/.release-gate/hardening-stage1/runtime-packs/" + id + ".pck"
		assert(ProjectSettings.load_resource_pack(pack), "Cannot mount retained raw pack " + id)
		var hashes := {}
		for path: String in paths:
			hashes[path] = FileAccess.get_sha256("res://" + path)
		stages.append({"mount":id,"hashes":hashes.duplicate(),"matches_actual_root":hashes == baseline})
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(stages,"\t",true)+"\n")
	print("H1 MOUNTED SCRIPT HASH AUDIT: ", stages.size(), " map-only stages; output=",output)
	quit()
