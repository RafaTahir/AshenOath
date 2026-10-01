extends SceneTree

class Helper extends "res://scripts/asset_spawn_helper.gd":
	var fallback_requests := 0
	func _fallback_material_for_path(path: String) -> StandardMaterial3D:
		fallback_requests += 1
		return super._fallback_material_for_path(path)

func _initialize() -> void:
	var helper := Helper.new()
	var source := ArrayMesh.new()
	var box := BoxMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	var valid := StandardMaterial3D.new()
	valid.albedo_color = Color(0.2, 0.3, 0.4)
	source.surface_set_material(0, valid)
	var first := MeshInstance3D.new()
	first.mesh = source
	helper._apply_safe_materials(first, "res://scripts/material_cache_probe.obj")
	var passed := helper.fallback_requests == 0 and first.mesh == source
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	helper._apply_safe_materials(first, "res://scripts/material_cache_probe.obj")
	var second := MeshInstance3D.new()
	second.mesh = source
	helper._apply_safe_materials(second, "res://scripts/material_cache_probe.obj")
	passed = passed and first.mesh == second.mesh and first.mesh != source
	passed = passed and source.surface_get_material(1) == null
	passed = passed and first.mesh.surface_get_material(0).albedo_color == valid.albedo_color
	passed = passed and first.mesh.surface_get_material(1) != null and helper.fallback_requests == 1
	passed = passed and first.mesh.surface_get_material(0) == valid
	passed = passed and first.mesh.surface_get_arrays(0) == source.surface_get_arrays(0)
	var overridden := MeshInstance3D.new()
	overridden.mesh = source
	var red := StandardMaterial3D.new()
	red.albedo_color = Color.RED
	overridden.set_surface_override_material(0, red)
	overridden.set_surface_override_material(1, valid)
	helper._apply_safe_materials(overridden, "res://scripts/material_cache_probe.obj")
	passed = passed and overridden.mesh.surface_get_material(0) == red and overridden.mesh.surface_get_material(1) == valid
	passed = passed and overridden.get_surface_override_material(0) == null and overridden.get_surface_override_material(1) == null
	passed = passed and helper.fallback_requests == 1 and source.surface_get_material(0) == valid and source.surface_get_material(1) == null
	var white_override := StandardMaterial3D.new()
	var another := MeshInstance3D.new()
	another.mesh = source
	another.set_surface_override_material(0, white_override)
	another.set_surface_override_material(1, valid)
	helper._apply_safe_materials(another, "res://scripts/material_cache_probe.obj")
	passed = passed and another.mesh != overridden.mesh and another.mesh.surface_get_material(0) == white_override
	passed = passed and overridden.mesh.surface_get_material(0) == red and first.mesh.surface_get_material(0).albedo_color == valid.albedo_color
	helper._apply_safe_materials(another, "res://scripts/material_cache_probe.obj")
	passed = passed and another.mesh.surface_get_material(0) == white_override and helper.fallback_requests == 1
	helper.clear_runtime_caches()
	passed = passed and helper.repaired_mesh_cache.is_empty()
	first.free()
	second.free()
	overridden.free()
	another.free()
	helper.free()
	print("CACHED MATERIALS: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
