extends SceneTree

const REQUIRED_BOOT_RESOURCES := [
	"res://assets_external/ui/greyfen_menu_runtime.jpg",
	"res://assets_external/environment/village/GreyfenWell_Authored.res",
	"res://assets_external/textures/runtime/timber_albedo.jpg",
	"res://assets_external/textures/runtime/wet_mud_albedo.jpg",
]
const REQUIRED_BOOT_SCRIPTS := [
	"res://scripts/hud.gd",
	"res://scripts/zones/river_section.gd",
]
const OPENING_PROP_ATLASES := ["Cloth", "Furniture", "Metal", "Props"]
const OPENING_PROP_CHANNELS := ["BaseColor", "Normal", "ORM"]
const OPENING_PROP_MODELS := ["Anvil", "Bucket_Wooden_1", "Book_Simplified_Single", "Axe_Bronze", "Barrel", "Crate_Metal", "Stall_Cart_Empty", "Torch_Metal", "Bookcase_2", "Chair_1", "Bench", "Table_Large", "WeaponStand", "Lantern_Wall"]

func _initialize() -> void:
	var failures: Array[String] = []
	var opening_pack := OS.get_environment("ASHEN_OPENING_PACK")
	if not opening_pack.is_empty() and not ProjectSettings.load_resource_pack(opening_pack):
		failures.append("cannot mount opening pack: " + opening_pack)
	for path in REQUIRED_BOOT_RESOURCES:
		if not ResourceLoader.exists(path):
			failures.append("missing boot resource: " + path)
	for path in REQUIRED_BOOT_SCRIPTS:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failures.append("invalid boot script: " + path)
	if not opening_pack.is_empty():
		for atlas in OPENING_PROP_ATLASES:
			for channel in OPENING_PROP_CHANNELS:
				var path := "res://assets_external/environment/props/T_Trim_%s_%s.png" % [atlas, channel]
				if not ResourceLoader.exists(path) or load(path) == null:
					failures.append("missing opening prop atlas: " + path)
		for model in OPENING_PROP_MODELS:
			var path := "res://assets_external/environment/props/%s.%s" % [model, "fbx" if model in ["Bucket_Wooden_1", "Book_Simplified_Single", "Axe_Bronze"] else "obj"]
			if not ResourceLoader.exists(path) or load(path) == null:
				failures.append("invalid opening prop model: " + path)
	for failure in failures:
		push_error(failure)
	print("WEB BOOTSTRAP PCK: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
