extends RefCounted

const HARL := preload("res://assets_external/environment/village/Cemetery_grave_harl_Authored.res")
const CHILD := preload("res://assets_external/environment/village/Cemetery_grave_child_Authored.res")
const SOLDIER := preload("res://assets_external/environment/village/Cemetery_grave_soldier_Authored.res")
const DISTURBED_SOIL := preload("res://assets_external/environment/village/Cemetery_disturbed_soil_Authored.res")

static func add_disturbed_soil(parent: Node3D, position: Vector3, material: Material) -> void:
	var soil := MeshInstance3D.new()
	soil.name = "RoadCrowsGraveyardDisturbedSoil"
	soil.mesh = DISTURBED_SOIL
	soil.material_override = material
	soil.position = position
	parent.add_child(soil)

static func apply(area: Node3D, id: String) -> bool:
	if id in ["chapel_door", "chapel_names"]:
		area.set_meta("external_clue_visual", "CrowChapelAuthoredArchitecture")
		return true
	var mesh: ArrayMesh = null
	match id:
		"grave_harl", "grave_bell": mesh = HARL
		"grave_child": mesh = CHILD
		"grave_soldier": mesh = SOLDIER
	if mesh == null:
		return false
	var memorial := MeshInstance3D.new()
	memorial.name = "CemeteryMemorialEvidence"
	memorial.mesh = mesh
	# The existing court road top is 0.0475m. Its unchanged Area3D stays at ground.
	memorial.position.y = 0.048
	memorial.set_meta("clue_identity", id)
	area.add_child(memorial)
	return true
