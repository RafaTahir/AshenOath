extends SceneTree

const AFFECTED := [
	"village/T_WoodTrim_BaseColor.png", "village/T_WoodTrim_Roughness.png",
	"village/T_WoodTrim_Normal.png", "forest/Leaves_TwistedTree_C.png",
	"forest/Bark_TwistedTree.png", "forest/Bark_TwistedTree_Normal.png",
	"forest/Bark_NormalTree.png", "forest/Bark_NormalTree_Normal.png",
	"forest/Leaves_NormalTree_C.png", "forest/Rocks_Diffuse.png",
]
var failures: Array[String] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Expected Web artifact directory and isolated scratch directory")
		quit(2)
		return
	var scratch := args[1].simplify_path()
	if not scratch.replace("\\", "/").begins_with("D:/Temp/AshenOath/"):
		push_error("Pack check scratch must remain under D:/Temp/AshenOath")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(scratch)
	if not ProjectSettings.globalize_path("res://").replace("\\", "/").begins_with("D:/Temp/AshenOath/"):
		push_error("Run this check from an isolated scratch project, not the source checkout")
		quit(2)
		return
	for relative in ["index.pck", "packs/opening.pck"]:
		var bytes := FileAccess.get_file_as_bytes(args[0].path_join(relative))
		if bytes.size() > 2 and bytes[0] == 0x1f and bytes[1] == 0x8b:
			bytes = bytes.decompress_dynamic(268435456, FileAccess.COMPRESSION_GZIP)
		var decoded := scratch.path_join(relative.get_file())
		var file := FileAccess.open(decoded, FileAccess.WRITE)
		if file == null or bytes.is_empty():
			_fail("Cannot decode " + relative)
			continue
		file.store_buffer(bytes)
		file.close()
		if not ProjectSettings.load_resource_pack(decoded, false):
			_fail("Cannot mount " + relative)
	var paths: Array[String] = []
	for relative in AFFECTED:
		paths.append("res://assets_external/environment/" + relative)
	var ledger_path := "res://data/environment_material_dependencies.json"
	if not FileAccess.file_exists(ledger_path):
		_fail("Exported environment dependency ledger is missing")
	else:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ledger_path))
		if not parsed is Dictionary or parsed.get("schema_version", 0) != 1:
			_fail("Invalid exported environment dependency ledger")
		else:
			var records: Dictionary = parsed.get("textures", {})
			for path in paths:
				if not records.has(path):
					_fail("Known affected texture omitted from ledger: " + path)
			for path: String in records:
				if records[path].get("owner", "") == "opening" and path not in paths:
					paths.append(path)
	for path in paths:
		var imported := FileAccess.file_exists(path + ".import")
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		var valid := texture != null and texture.get_width() > 0 and texture.get_height() > 0
		print("ENVIRONMENT_TEXTURE path=%s import=%s texture=%s" % [path, imported, valid])
		if not imported or not valid:
			_fail("Missing imported texture: " + path)
	print("ENVIRONMENT PACK CLOSURE: %s (%d textures, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", paths.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)
