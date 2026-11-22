extends "D:/Temp/AshenOath/static_scene_ownership_20260927/single_publication_candidate.gd"

const SharedFamily = preload("D:/Temp/AshenOath/static_scene_ownership_20260927/static_material_family.gd")
var renderer_family := SharedFamily.new()
var prepared_geometry: Dictionary = {}
var renderer_meshes: Dictionary = {}

func _flush_environment_batches() -> void:
	super._flush_environment_batches()
	if zone_root != null:
		_bind_static_renderers(zone_root, zone_root)

func _bind_static_renderers(node: Node, zone: Node3D) -> void:
	if node != zone and (node.get_script() != null or node is CollisionObject3D and not node is StaticBody3D or node is Skeleton3D or node is AnimationMixer):
		return
	if node.name == "LivingRiverSection" or bool(node.get_meta("night_only_geometry", false)):
		return
	if node is GeometryInstance3D and not prepared_geometry.has(node.get_instance_id()):
		if node.material_override is ShaderMaterial or node is MeshInstance3D and node.skin != null:
			return
		if node is MeshInstance3D and node.mesh != null:
			if node.material_override != null:
				node.material_override = renderer_family.convert(node.material_override)
			else:
				for surface in node.mesh.get_surface_count():
					var source: Material = node.get_surface_override_material(surface)
					if source == null:
						source = node.mesh.surface_get_material(surface)
					node.set_surface_override_material(surface, renderer_family.convert(source))
			prepared_geometry[node.get_instance_id()] = true
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			if node.material_override != null:
				node.material_override = renderer_family.convert(node.material_override)
			else:
				var source: Mesh = node.multimesh.mesh
				if not renderer_meshes.has(source):
					var copy := source.duplicate(false) as Mesh
					for surface in copy.get_surface_count():
						copy.surface_set_material(surface, renderer_family.convert(source.surface_get_material(surface)))
					renderer_meshes[source] = copy
				node.multimesh.mesh = renderer_meshes[source]
			prepared_geometry[node.get_instance_id()] = true
	for child in node.get_children():
		_bind_static_renderers(child, zone)

func _warm_final_static_meshes(prepared: Node3D) -> Dictionary:
	print("SHARED_STATIC_BINDINGS %s" % JSON.stringify({"geometry": prepared_geometry.size(), "mesh_copies": renderer_meshes.size(), "material_adapters": renderer_family.materials.size(), "shader_families": renderer_family.shaders.size(), "unsupported": renderer_family.failures}))
	if not renderer_family.failures.is_empty():
		push_error("Full-game shader family has unsupported material features")
	return await super._warm_final_static_meshes(prepared)

func finalize_resource_shutdown() -> void:
	renderer_family.clear()
	prepared_geometry.clear()
	renderer_meshes.clear()
	super.finalize_resource_shutdown()
