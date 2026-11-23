extends RefCounted

const Api = preload("res://scripts/core/zone_construction_api.gd")

static func add(host: Api, area: Node3D, scale_override: Vector3) -> void:
	var token_root: Variant = Node3D.new()
	token_root.name = "OrenTokenAndVarganWireVisual"
	token_root.scale = scale_override
	area.add_child(token_root)
	var token: Variant = MeshInstance3D.new()
	token.name = "OrenCompleteToken"
	var token_mesh: Variant = BoxMesh.new()
	token_mesh.size = Vector3(0.28, 0.07, 0.38)
	token.mesh = token_mesh
	token.position = Vector3(-0.12, 0.12, 0.0)
	token.rotation_degrees = Vector3(0.0, -24.0, 8.0)
	token.material_override = host._mat(Color(0.48, 0.30, 0.12))
	token_root.add_child(token)
	var wire: Variant = MeshInstance3D.new()
	wire.name = "VarganBindingWire"
	var wire_mesh: Variant = TorusMesh.new()
	wire_mesh.inner_radius = 0.07
	wire_mesh.outer_radius = 0.09
	wire_mesh.rings = 8
	wire_mesh.ring_segments = 6
	wire.mesh = wire_mesh
	wire.position = Vector3(0.12, 0.15, 0.05)
	wire.rotation_degrees = Vector3(78.0, 12.0, 14.0)
	var wire_material: Variant = host._mat(Color(0.13, 0.13, 0.12))
	wire_material.metallic = 0.55
	wire_material.roughness = 0.48
	wire.material_override = wire_material
	token_root.add_child(wire)
