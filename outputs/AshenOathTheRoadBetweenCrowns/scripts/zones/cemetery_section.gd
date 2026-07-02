extends RefCounted


func build(parent: Node3D, context: Dictionary) -> void:
	var host: Node = context.get("host")
	var origin: Vector3 = context.get("origin", Vector3.ZERO)
	if host == null or parent == null:
		return

	var section = Node3D.new()
	section.name = "GreyfenCemeterySection"
	section.position = origin
	section.add_to_group("cemetery_section")
	parent.add_child(section)

	_add_marker(section, "CemeteryEntry", Vector3(-4.3, 0, -0.6))
	_add_marker(section, "SisterAnwenCemeteryStage", Vector3(-3.2, 0, -1.7))
	_add_marker(section, "CemeteryEncounterStage", Vector3(0.3, 0, 0.1))
	_add_marker(section, "CrowShrineStage", Vector3(2.0, 0, -2.5))

	host.call("_make_road", origin + Vector3(-4.1, 0.021, -0.6), Vector3(8.2, 0.045, 2.4), Color(0.13, 0.115, 0.09))
	host.call("_make_road", origin + Vector3(0.0, 0.022, -0.6), Vector3(7.8, 0.045, 7.8), Color(0.105, 0.10, 0.085))

	# Three walls bound the court while the west side remains a readable entrance.
	host.call("_make_prop_box", "CemeteryNorthWall", origin + Vector3(0, 0.48, -4.2), Vector3(8.2, 0.96, 0.42), Color(0.17, 0.18, 0.17))
	host.call("_make_prop_box", "CemeterySouthWall", origin + Vector3(0, 0.48, 3.0), Vector3(8.2, 0.96, 0.42), Color(0.17, 0.18, 0.17))
	host.call("_make_prop_box", "CemeteryEastWall", origin + Vector3(4.0, 0.48, -0.6), Vector3(0.42, 0.96, 7.6), Color(0.16, 0.17, 0.16))
	for z in [-3.35, 2.15]:
		host.call("_make_prop_box", "CemeteryGatePost", origin + Vector3(-4.0, 1.15, z), Vector3(0.55, 2.3, 0.55), Color(0.19, 0.19, 0.18))

	_build_chapel(host, origin + Vector3(2.35, 0, -0.55))
	_build_graves(host, origin)
	host.call("_make_fog_sheet", origin + Vector3(0, 0.48, -0.5), Vector3(7.6, 0.7, 6.8), Color(0.15, 0.17, 0.16, 0.10))
	host.call("_make_light", "CemeteryChapelGlow", origin + Vector3(1.7, 2.7, -0.6), Color(0.54, 0.66, 0.52), 1.35)


func _build_chapel(host: Node, pos: Vector3) -> void:
	host.call("_make_prop_box", "RuinedCrowChapelFloor", pos + Vector3(0, 0.10, 0), Vector3(3.0, 0.20, 3.9), Color(0.13, 0.13, 0.12))
	host.call("_make_prop_box", "RuinedCrowChapelBackWall", pos + Vector3(1.35, 1.65, 0), Vector3(0.42, 3.3, 3.9), Color(0.24, 0.24, 0.22))
	host.call("_make_prop_box", "RuinedCrowChapelNorthWall", pos + Vector3(0, 1.35, -1.75), Vector3(2.7, 2.7, 0.38), Color(0.22, 0.22, 0.20))
	host.call("_make_prop_box", "RuinedCrowChapelSouthWall", pos + Vector3(0.35, 1.05, 1.75), Vector3(2.0, 2.1, 0.38), Color(0.21, 0.21, 0.19))
	host.call("_make_prop_box", "RuinedCrowChapelRoof", pos + Vector3(0.55, 3.15, 0), Vector3(1.75, 0.28, 4.15), Color(0.11, 0.105, 0.095))
	host.call("_make_prop_box", "OssuarySealedDoor", pos + Vector3(1.10, 0.85, 0), Vector3(0.12, 1.70, 1.15), Color(0.085, 0.075, 0.06))
	host.call("_make_prop_box", "CrowChapelAltar", pos + Vector3(0.55, 0.55, 0), Vector3(0.75, 1.1, 1.35), Color(0.18, 0.18, 0.16))


func _build_graves(host: Node, origin: Vector3) -> void:
	for offset in [
		Vector3(-2.4, 0, -2.8), Vector3(-0.9, 0, -2.7),
		Vector3(-2.5, 0, 1.3), Vector3(-0.9, 0, 1.4),
	]:
		host.call("_make_gravestone", origin + offset)
	for offset in [Vector3(-3.25, 0, -3.35), Vector3(-3.1, 0, 2.15), Vector3(0.2, 0, 2.35)]:
		host.call("_make_rubble", origin + offset)


func _add_marker(parent: Node3D, marker_name: String, local_position: Vector3) -> void:
	var marker = Marker3D.new()
	marker.name = marker_name
	marker.position = local_position
	parent.add_child(marker)
