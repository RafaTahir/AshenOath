extends SceneTree

const SOURCE := "res://assets_external/environment/village/"
const MODULES := [
	"Wall_Plaster_Door_Flat.obj",
	"Wall_Plaster_Window_Wide_Flat.obj",
	"Wall_Plaster_Straight.obj",
	"Wall_Plaster_Straight_Base.obj",
	"Roof_RoundTiles_4x4.obj",
	"Roof_RoundTiles_8x10.obj",
	"Prop_Chimney.obj",
	"Wall_Arch.obj",
	"Wall_UnevenBrick_Straight.obj",
]
const PROP_MODULES := [
	"res://assets_external/environment/props/Stall_Cart_Empty.obj",
	"res://assets_external/environment/props/Stall_Empty.obj",
	"res://assets_external/environment/forest/Bush_Common.obj",
]

func _initialize() -> void:
	var helper = load("res://scripts/asset_spawn_helper.gd").new()
	var failed := false
	for file_name in MODULES:
		var path: String = SOURCE + str(file_name)
		var mesh: ArrayMesh = helper._load_obj_mesh(path)
		if mesh == null:
			print("WORLD-001 MODULE missing=%s" % file_name)
			failed = true
			continue
		var bounds := mesh.get_aabb()
		var imported := ResourceLoader.load(path) as ArrayMesh
		var native_surfaces := imported.get_surface_count() if imported != null else 0
		var material_names: Array[String] = []
		if imported != null:
			for surface_index in range(native_surfaces):
				var material := imported.surface_get_material(surface_index)
				material_names.append("%s:%s" % [imported.surface_get_name(surface_index), str(material.resource_name) if material != null else "<null>"])
		print("WORLD-001 MODULE %s origin=%s size=%s native_origin=%s native_size=%s runtime_surfaces=%d native_surfaces=%d materials=%s" % [file_name, bounds.position, bounds.size, imported.get_aabb().position if imported != null else Vector3.ZERO, imported.get_aabb().size if imported != null else Vector3.ZERO, mesh.get_surface_count(), native_surfaces, material_names])
	for path in PROP_MODULES:
		var mesh: ArrayMesh = helper._load_obj_mesh(path)
		if mesh == null:
			print("WORLD-001 MODULE missing=%s" % path)
			failed = true
			continue
		var bounds := mesh.get_aabb()
		var native := ResourceLoader.load(path) as ArrayMesh
		var triangles := 0
		if native != null:
			for surface_index in range(native.get_surface_count()):
				var arrays := native.surface_get_arrays(surface_index)
				triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		print("WORLD-001 PROP %s origin=%s size=%s native_size=%s triangles=%d surfaces=%d" % [path, bounds.position, bounds.size, native.get_aabb().size if native != null else Vector3.ZERO, triangles, mesh.get_surface_count()])
	helper.free()
	quit(1 if failed else 0)
