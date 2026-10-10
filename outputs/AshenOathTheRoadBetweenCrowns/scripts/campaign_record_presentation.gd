extends RefCounted

const PATH := "res://assets_external/environment/props/CampaignRecord_%s_Authored.res"
const CLUES := ["register_rook", "register_mira", "miller_record"]

static func apply(area: Node3D, id: String) -> bool:
	if id in ["vargan_gate_notice", "vargan_supply_cart", "vargan_mile_marker", "vargan_iron_binding"]:
		_make_castle_record(area, id)
		return true
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

static func _make_castle_record(area: Node3D, id: String) -> void:
	area.set_meta("external_clue_visual", id)
	if id == "vargan_gate_notice":
		var board := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.72, 0.84, 0.07)
		board.mesh = mesh
		board.position.y = 1.12
		var timber := StandardMaterial3D.new()
		timber.albedo_color = Color(0.22, 0.14, 0.09)
		board.material_override = timber
		area.add_child(board)
		var post := MeshInstance3D.new()
		var pole := BoxMesh.new()
		pole.size = Vector3(0.09, 1.5, 0.09)
		post.mesh = pole
		post.position.y = 0.75
		post.material_override = timber
		area.add_child(post)
		var paper := make_visual("register_mira")
		if paper != null:
			paper.position = Vector3(0, 1.0, 0.07)
			paper.rotation.x = PI * 0.5
			area.add_child(paper)
	elif id == "vargan_iron_binding":
		var wire := MeshInstance3D.new()
		var loop := TorusMesh.new()
		loop.inner_radius = 0.16
		loop.outer_radius = 0.19
		loop.rings = 12
		loop.ring_segments = 6
		wire.mesh = loop
		wire.position.y = 0.04
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.13, 0.12, 0.11)
		iron.metallic = 0.65
		wire.material_override = iron
		area.add_child(wire)
	else:
		var record := make_visual("register_rook")
		if record != null:
			record.position.y = 0.08
			area.add_child(record)

static func make_visual(identity: String) -> MeshInstance3D:
	var mesh := load(PATH % identity) as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 2:
		return null
	var visual := MeshInstance3D.new()
	visual.name = "CampaignRecord_%s" % identity
	visual.mesh = mesh
	visual.set_meta("clue_identity", identity)
	return visual
