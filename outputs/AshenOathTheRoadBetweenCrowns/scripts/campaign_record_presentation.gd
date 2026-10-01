extends RefCounted

const PATH := "res://assets_external/environment/props/CampaignRecord_%s_Authored.res"
const CLUES := ["register_rook", "register_mira", "miller_record"]

static func apply(area: Node3D, id: String) -> bool:
	if not CLUES.has(id):
		return false
	var identity := "mill_pending" if id == "miller_record" else id
	var record := make_visual(identity)
	if record == null:
		push_error("Required campaign record unavailable: " + identity)
		return true
	area.add_child(record)
	area.set_meta("external_clue_visual", identity)
	return true

static func make_visual(identity: String) -> MeshInstance3D:
	var mesh := load(PATH % identity) as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 2:
		return null
	var visual := MeshInstance3D.new()
	visual.name = "CampaignRecord_%s" % identity
	visual.mesh = mesh
	visual.set_meta("clue_identity", identity)
	return visual
