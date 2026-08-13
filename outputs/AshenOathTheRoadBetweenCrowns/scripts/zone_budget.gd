extends RefCounted

const LIMITS := {
	"nodes": 1350,
	"meshes": 420,
	"multimeshes": 48,
	# Shared humanoid composites intentionally contain a body skeleton and a
	# synchronized outfit skeleton. Keep the residency ceiling explicit while
	# enforcing the tighter visible-actor budget below.
	"skeletons": 20,
	"visible_skeletons": 10,
	"lights": 8,
	"transparent_surfaces": 72,
	"mesh_surfaces": 600,
}

static func capture(zone_root: Node) -> Dictionary:
	var result := {
		"nodes": 0,
		"meshes": 0,
		"multimeshes": 0,
		"multimesh_instances": 0,
		"skeletons": 0,
		"visible_skeletons": 0,
		"lights": 0,
		"transparent_surfaces": 0,
		"mesh_surfaces": 0,
		"null_material_surfaces": 0,
	}
	if zone_root == null:
		return result
	_collect(zone_root, result)
	return result

static func violations(snapshot: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in LIMITS:
		if int(snapshot.get(key, 0)) > int(LIMITS[key]):
			result.append("%s=%d exceeds %d" % [key, int(snapshot.get(key, 0)), int(LIMITS[key])])
	if int(snapshot.get("null_material_surfaces", 0)) > 0:
		result.append("null_material_surfaces=%d" % int(snapshot.null_material_surfaces))
	return result

static func _collect(node: Node, result: Dictionary, inherited_visible: bool = true) -> void:
	result.nodes = int(result.nodes) + 1
	var visible := inherited_visible and (not node is Node3D or (node as Node3D).visible)
	if node is Skeleton3D:
		result.skeletons = int(result.skeletons) + 1
		if visible:
			result.visible_skeletons = int(result.visible_skeletons) + 1
	elif node is Light3D:
		result.lights = int(result.lights) + 1
	elif node is MultiMeshInstance3D:
		var batch := node as MultiMeshInstance3D
		result.multimeshes = int(result.multimeshes) + 1
		if batch.multimesh != null:
			var visible_count := batch.multimesh.visible_instance_count
			if visible_count < 0:
				visible_count = batch.multimesh.instance_count
			result.multimesh_instances = int(result.multimesh_instances) + visible_count
			if batch.multimesh.mesh != null:
				_collect_mesh(batch.multimesh.mesh, batch.material_override, result)
	elif node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		result.meshes = int(result.meshes) + 1
		if mesh_instance.mesh != null:
			_collect_mesh_instance(mesh_instance, result)
	for child in node.get_children():
		_collect(child, result, visible)

static func _collect_mesh_instance(mesh_instance: MeshInstance3D, result: Dictionary) -> void:
	for surface in range(mesh_instance.mesh.get_surface_count()):
		var material: Material = mesh_instance.material_override
		if material == null:
			material = mesh_instance.get_surface_override_material(surface)
		if material == null:
			material = mesh_instance.mesh.surface_get_material(surface)
		_record_surface(material, result)

static func _collect_mesh(mesh: Mesh, override_material: Material, result: Dictionary) -> void:
	for surface in range(mesh.get_surface_count()):
		var material: Material = override_material
		if material == null:
			material = mesh.surface_get_material(surface)
		_record_surface(material, result)

static func _record_surface(material: Material, result: Dictionary) -> void:
	result.mesh_surfaces = int(result.mesh_surfaces) + 1
	if material == null:
		result.null_material_surfaces = int(result.null_material_surfaces) + 1
		return
	if material is BaseMaterial3D and (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		result.transparent_surfaces = int(result.transparent_surfaces) + 1
