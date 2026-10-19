extends RefCounted

const BINDINGS := "character_expected_materials"

static func capture(root: Node3D, source: String) -> bool:
	var bindings: Array[Dictionary] = []
	var errors: Array[String] = []
	var atlas_required := source.to_lower().ends_with("_atlas.gltf")
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or str(mesh.name).to_lower().contains("shadow"):
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(surface)
			var path := str(root.get_path_to(mesh))
			if material == null or (atlas_required and not _textured(material)):
				errors.append("%s %s[%d]: required authored material/atlas is missing" % [source, path, surface])
				continue
			bindings.append({
				"mesh": path, "surface": surface, "material": material,
				"texture": material.albedo_texture.resource_path if _textured(material) else "",
			})
	if bindings.is_empty():
		errors.append("%s: no authored character material bindings" % source)
	root.set_meta(BINDINGS, bindings)
	root.set_meta("character_atlas_required", atlas_required)
	root.set_meta("character_material_errors", errors)
	root.set_meta("character_material_bindings_valid", errors.is_empty())
	return errors.is_empty()

static func restore(root: Node3D) -> bool:
	if not root.has_meta(BINDINGS):
		var owners := _owners(root)
		if owners.is_empty():
			return false
		var restored := true
		for owner in owners:
			restored = restore(owner) and restored
		return restored
	var errors: Array[String] = []
	var restored_meshes: Dictionary = {}
	for binding in root.get_meta(BINDINGS):
		var mesh := root.get_node_or_null(NodePath(str(binding.mesh))) as MeshInstance3D
		var material := binding.material as Material
		var surface := int(binding.surface)
		if mesh == null or mesh.mesh == null or surface < 0 or surface >= mesh.mesh.get_surface_count():
			errors.append("%s[%d]: authored mesh surface is missing" % [str(binding.mesh), surface])
			continue
		var atlas_required := bool(root.get_meta("character_atlas_required", false))
		if material == null or (atlas_required and not _textured(material)):
			var effective := mesh.get_active_material(surface)
			if effective != null and (not atlas_required or _textured(effective)):
				material = effective
			elif material is BaseMaterial3D:
				var texture_path := str(binding.get("texture", ""))
				var texture := load(texture_path) as Texture2D if not texture_path.is_empty() else null
				if texture != null:
					material = material.duplicate() as BaseMaterial3D
					material.albedo_texture = texture
		if material == null or (atlas_required and not _textured(material)):
			errors.append("%s[%d]: authored material/atlas %s is missing" % [str(binding.mesh), surface, str(binding.get("texture", ""))])
			continue
		if not restored_meshes.has(mesh):
			mesh.material_override = null
			restored_meshes[mesh] = true
		if mesh.get_active_material(surface) != material:
			# Restore this instance, never rewrite the shared base mesh. A stale
			# whole-body override must not mask the authored per-surface bindings.
			mesh.set_surface_override_material(surface, material)
	if root.get_meta(BINDINGS).is_empty():
		errors.append("No authored character material bindings")
	root.set_meta("character_material_errors", errors)
	root.set_meta("character_material_bindings_valid", errors.is_empty())
	return errors.is_empty()

static func descriptors(root: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for binding in root.get_meta(BINDINGS, []):
		var material := binding.material as BaseMaterial3D
		result.append({
			"mesh": str(binding.mesh), "surface": int(binding.surface),
			"texture": material.albedo_texture.resource_path if material != null and material.albedo_texture != null else "",
		})
	return result

static func has_textured_identity(root: Node) -> bool:
	var found := false
	var owners := _owners(root)
	if not owners.is_empty():
		# Bindings identify the original body. Later attached sword, keepsake
		# and quiver meshes legitimately use untextured materials of their own.
		for owner in owners:
			for binding in owner.get_meta(BINDINGS):
				var mesh := owner.get_node_or_null(NodePath(str(binding.mesh))) as MeshInstance3D
				if mesh == null or mesh.mesh == null or not _textured(mesh.get_active_material(int(binding.surface))):
					return false
				found = true
		return found
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null or str(mesh.name).to_lower().contains("shadow"):
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			if not _textured(mesh.get_active_material(surface)):
				return false
			found = true
	return found

static func _owners(root: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if root is Node3D and root.has_meta(BINDINGS):
		result.append(root)
		return result
	for child in root.find_children("*", "Node3D", true, false):
		if child.has_meta(BINDINGS):
			result.append(child)
	return result

static func _textured(material: Material) -> bool:
	return material is BaseMaterial3D and material.albedo_texture != null
