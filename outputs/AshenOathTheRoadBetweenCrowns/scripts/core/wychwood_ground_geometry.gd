extends RefCounted

const Prepared = preload("res://scripts/prepared_zone_geometry.gd")
const Bridge = preload("res://scripts/bridge_surface_contract.gd")
const WIDTH := 44.0
const DEPTH := 34.0
const RIVER_SPAN := 3.4

static func ground_specs() -> Array[Array]:
	var half_depth := DEPTH * 0.5
	var side_width := maxf((WIDTH - Bridge.DECK_WIDTH) * 0.5, 0.1)
	var side_center := Bridge.DECK_WIDTH * 0.5 + side_width * 0.5
	var bank_edge := RIVER_SPAN * 0.5
	var bank_depth := half_depth - bank_edge
	var support_half := Bridge.bridge_length(RIVER_SPAN) * 0.5 + Bridge.APPROACH_LENGTH
	var corridor_depth := maxf(half_depth - support_half, 0.0)
	return [
		[Vector3(-side_center,-0.08,-half_depth+bank_depth*0.5), Vector3(side_width,0.16,bank_depth)],
		[Vector3(side_center,-0.08,-half_depth+bank_depth*0.5), Vector3(side_width,0.16,bank_depth)],
		[Vector3(-side_center,-0.08,bank_edge+bank_depth*0.5), Vector3(side_width,0.16,bank_depth)],
		[Vector3(side_center,-0.08,bank_edge+bank_depth*0.5), Vector3(side_width,0.16,bank_depth)],
		[Vector3(0,-0.08,-half_depth+corridor_depth*0.5), Vector3(Bridge.DECK_WIDTH,0.16,corridor_depth)],
		[Vector3(0,-0.08,support_half+corridor_depth*0.5), Vector3(Bridge.DECK_WIDTH,0.16,corridor_depth)],
	]

static func ground_id(size: Vector3, origin: Vector3) -> String:
	return "wychwood_ground_" + Prepared.geometry_key(size, origin)

static func ground_mesh(size: Vector3, origin: Vector3) -> ArrayMesh:
	return Prepared.mesh(ground_id(size, origin))

static func resource_paths() -> Array[String]:
	var paths: Array[String] = []
	for spec: Array in ground_specs():
		paths.append(Prepared.ROOT + ground_id(spec[1], spec[0]) + ".res")
	return paths
