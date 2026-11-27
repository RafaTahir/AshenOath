extends RefCounted

const Api = preload("res://scripts/core/zone_construction_api.gd")

static func add(_host: Api, area: Node3D, scale_override: Vector3) -> void:
	var token_root := Node3D.new()
	token_root.name = "OrenTokenAndVarganWireVisual"
	token_root.scale = scale_override
	area.add_child(token_root)
	if _host.story_state.get_flag("novel_edition",0) == 1:
		var scene := preload("res://scripts/novel/tabletop.gd").keepsake("oren_crow","recovered")
		if scene != null:
			token_root.scale = Vector3.ONE
			var crow := scene.instantiate() as Node3D
			crow.position = Vector3(-0.055,0.072,0)
			crow.rotation_degrees = Vector3(-60,-21,0)
			token_root.add_child(crow)
			return
	var token := MeshInstance3D.new()
	token.name = "OrenCompleteToken"
	token.mesh = load("res://assets_external/environment/village/CarvedCrowToken.res") as ArrayMesh
	token.position = Vector3(-0.055, 0.024, 0)
	token.rotation_degrees.y = -21.0
	token_root.add_child(token)
