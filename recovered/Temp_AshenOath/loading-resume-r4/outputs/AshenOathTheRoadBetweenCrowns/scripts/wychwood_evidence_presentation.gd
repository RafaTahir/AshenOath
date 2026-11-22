extends RefCounted

const ROOT := "res://assets_external/environment/forest/"
const IDS := ["corpse", "black_feathers", "oren_token", "claw_marks", "tracks"]

static func apply(area: Node3D, id: String) -> bool:
	if id not in IDS:
		return false
	var resource := load(ROOT + "Wychwood_%s_Evidence.res" % id) as ArrayMesh
	if resource == null:
		push_error("Required Wychwood evidence is missing: " + id)
		return true
	var evidence := MeshInstance3D.new()
	evidence.name = "WychwoodInvestigationEvidence"
	evidence.mesh = resource
	evidence.position.y = 0.076
	evidence.set_meta("clue_identity", id)
	area.add_child(evidence)
	return true
