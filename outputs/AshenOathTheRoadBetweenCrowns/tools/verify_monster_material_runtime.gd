extends SceneTree
## Source-isolated material ownership/PBR regression; no world or save access.
const Palette = preload("res://scripts/monster_material_palette.gd")
const Bindings = preload("res://scripts/character_material_bindings.gd")
var errors: Array[String] = []
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func _run() -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Palette.PROFILE_PATH)).assets
	var known_materials: Dictionary = {}
	for asset_id: String in profiles:
		var profile: Dictionary = profiles[asset_id]
		var source := str(profile.source)
		var packed := load(source) as PackedScene
		_check(packed != null, asset_id + ": source load")
		if packed == null:
			continue
		var actor := packed.instantiate() as Node3D
		root.add_child(actor)
		var originals: Array[Dictionary] = []
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface) as BaseMaterial3D
				_check(material != null, asset_id + ": original PBR")
				if material == null:
					continue
				originals.append({"mesh": mesh, "surface": surface, "material": material,
					"albedo": material.albedo_color, "geometry": mesh.mesh, "skin": mesh.skin,
					"transform": mesh.transform})
		_check(Palette.prepare(actor, source), asset_id + ": palette binds")
		_check(Bindings.capture(actor, source), asset_id + ": binding capture")
		var variants: Array[Material] = []
		for entry in originals:
			var mesh := entry.mesh as MeshInstance3D
			var native := entry.material as BaseMaterial3D
			var material := mesh.get_active_material(int(entry.surface)) as ShaderMaterial
			_check(material != null, asset_id + ": shader variant " + native.resource_name)
			if material == null:
				continue
			variants.append(material)
			known_materials[asset_id + "/" + native.resource_name] = true
			_check(mesh.mesh == entry.geometry and mesh.skin == entry.skin and mesh.transform == entry.transform, asset_id + ": unchanged mesh/skin/frame")
			_check(native.albedo_color == entry.albedo, asset_id + ": immutable shared native")
			_check(Bindings.texture_for(material) == native.albedo_texture, asset_id + ": retained atlas")
			_check(material.get_shader_parameter("authored_tint") == native.albedo_color, asset_id + ": retained alpha/tint")
			_check(material.get_shader_parameter("authored_normal") == native.normal_texture, asset_id + ": retained normal texture")
			_check(is_equal_approx(float(material.get_shader_parameter("authored_normal_scale")), native.normal_scale), asset_id + ": retained normal scale")
			_check(is_equal_approx(float(material.get_shader_parameter("authored_specular")), native.metallic_specular), asset_id + ": retained specular/IOR response")
			_check(is_equal_approx(float(material.get_shader_parameter("authored_clearcoat")), native.clearcoat if native.clearcoat_enabled else 0.0), asset_id + ": retained wet shell clearcoat")
			_check(is_equal_approx(float(material.get_shader_parameter("authored_clearcoat_roughness")), native.clearcoat_roughness), asset_id + ": retained clearcoat roughness")
			var alpha := native.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
			_check(material.shader == (Palette.TRANSLUCENT if alpha else (Palette.COATED if native.clearcoat_enabled else Palette.OPAQUE)), asset_id + ": native transparency/clearcoat pipeline")
			if native is StandardMaterial3D:
				_check(material.get_shader_parameter("authored_roughness_map") == native.roughness_texture, asset_id + ": retained roughness map")
				_check(material.get_shader_parameter("authored_metallic_map") == native.metallic_texture, asset_id + ": retained metallic map")
			elif native is ORMMaterial3D:
				_check(material.get_shader_parameter("authored_roughness_map") == native.orm_texture, asset_id + ": retained ORM")
		_check(Palette.prepare(actor, source), asset_id + ": idempotent rebind")
		for index in originals.size():
			if index < variants.size():
				_check(originals[index].mesh.get_active_material(int(originals[index].surface)) == variants[index], asset_id + ": no repeated material allocations")
		if not originals.is_empty():
			var first: Dictionary = originals[0]
			first.mesh.material_override = null
			first.mesh.set_surface_override_material(int(first.surface), null)
			_check(Palette.prepare(actor, source), asset_id + ": revision metadata cannot hide restored native surface")
			if not variants.is_empty():
				_check(first.mesh.get_active_material(int(first.surface)) == variants[0], asset_id + ": palette reclaims restored native atlas")
			# A working native atlas remains authoritative; deliberately remove it
			# to exercise the existing owner's actual recovery path.
			var broken := StandardMaterial3D.new()
			first.mesh.material_override = broken
			_check(Bindings.restore(actor), asset_id + ": ownership restoration")
			if not variants.is_empty():
				_check(first.mesh.get_active_material(int(first.surface)) == variants[0], asset_id + ": restore pigment variant")
		rows.append({"asset": asset_id, "surfaces": originals.size(), "source": source})
		actor.free()
	_check(profiles.size() == 20 and rows.size() == 20, "all twenty native species")
	_check(known_materials.size() == 43, "all 43 authored material identities")
	Palette.clear_material_cache()
	_check(Palette._variants.is_empty(), "streamed-zone material cache releases deferred texture references")
	var result := {"kind": "monster_material_runtime_contract", "passed": errors.is_empty(),
		"asset_count": rows.size(), "material_identities": known_materials.size(),
		"world_loaded": false, "visual_acceptance": false, "assets": rows, "errors": errors}
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)
