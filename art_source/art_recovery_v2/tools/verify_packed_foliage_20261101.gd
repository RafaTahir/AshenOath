extends SceneTree

const Helper = preload("res://scripts/asset_spawn_helper.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var marker := args.find("--pack-dir")
	if marker < 0 or marker + 1 >= args.size():
		push_error("Required decoded pack directory")
		quit(1)
		return
	for file in DirAccess.get_files_at(args[marker + 1]):
		if file.ends_with(".pck") and not ProjectSettings.load_resource_pack(args[marker + 1].path_join(file)):
			push_error("Cannot mount decoded pack: " + file)
			quit(1)
			return
	var helper := Helper.new()
	var leaf := StandardMaterial3D.new()
	leaf.resource_name = "Leaves_TwistedTree"
	leaf.albedo_texture = load("res://assets_external/environment/forest/Leaves_TwistedTree_C.png") as Texture2D
	var wood := StandardMaterial3D.new()
	wood.resource_name = "Bark_TwistedTree"
	wood.albedo_color = Color(0.27, 0.20, 0.15)
	# Even a bark surface sharing an RGBA atlas must stay opaque.
	wood.albedo_texture = leaf.albedo_texture
	var original := ArrayMesh.new()
	for index in 2:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP])
		original.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		original.surface_set_name(index, "Leaves_TwistedTree" if index == 0 else "Bark_TwistedTree")
		original.surface_set_material(index, leaf if index == 0 else wood)
	var first := MeshInstance3D.new()
	first.mesh = original
	var second := MeshInstance3D.new()
	second.mesh = original
	helper._apply_safe_materials(first, "res://assets_external/environment/forest/Bush_Common.obj")
	helper._apply_safe_materials(second, "res://assets_external/environment/forest/Bush_Common.obj")
	var repaired := first.mesh.surface_get_material(0) as StandardMaterial3D
	_check(first.mesh != original, "local mesh copy required")
	_check(first.mesh == second.mesh and first.mesh.get_rid() == second.mesh.get_rid(), "repeated spawns must share one repaired Mesh RID")
	_check(repaired != leaf and repaired.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "leaf alpha cutout required")
	_check(repaired.cull_mode == BaseMaterial3D.CULL_DISABLED, "leaf cards must remain two-sided")
	_check(repaired.albedo_texture == leaf.albedo_texture, "original atlas/mips must stay shared")
	_check(original.surface_get_material(0) == leaf and leaf.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "immutable leaf source must remain opaque/unmodified")
	_check(first.mesh.surface_get_material(1) == wood and wood.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "wood must remain opaque even with an alpha atlas")
	_check(helper._environment_foliage_cutout("res://assets_external/design_pack_v1/humans/C01_Anwen.glb", "Leaves_TwistedTree", leaf) == leaf, "character materials must be excluded")
	_check(helper.repaired_mesh_cache[original]["res://assets_external/environment/forest/Bush_Common.obj"] == first.mesh, "existing source/path mesh cache must own the variant")
	print("ENVIRONMENT FOLIAGE CUTOUT: ", "PASS" if failures.is_empty() else "FAIL", "; shared_mesh_rid=", first.mesh.get_rid(), "; failures=", failures)
	first.free()
	second.free()
	helper.free()
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
