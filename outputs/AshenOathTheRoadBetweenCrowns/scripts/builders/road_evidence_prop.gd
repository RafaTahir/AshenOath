extends RefCounted

const Api = preload("res://scripts/core/zone_construction_api.gd")

static func add(_host: Api, area: Node3D, scale_override: Vector3) -> void:
	var token_root := Node3D.new()
	token_root.name = "OrenTokenAndVarganWireVisual"
	token_root.scale = scale_override
	area.add_child(token_root)
	var token := MeshInstance3D.new()
	token.name = "OrenCompleteToken"
	token.mesh = load("res://assets_external/environment/village/CarvedCrowToken.res") as ArrayMesh
	token.position = Vector3(-0.055, 0.024, 0)
	token.rotation_degrees.y = -21.0
	token_root.add_child(token)
