extends SceneTree

const Contract = preload("res://living_world_geometry_contract.gd")
const IDS := ["marsh_reeds"]

func _initialize() -> void:
	call_deferred("_run")

func _find(node: Node, wanted: String) -> MeshInstance3D:
	if str(node.name) == wanted and node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var result := _find(child, wanted)
		if result != null: return result
	return null

func _frame(node: Node3D, host: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null and parent != host:
		if parent is Node3D: result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result

func _import(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK: return null
	return document.generate_scene(state) as Node3D

func _rows(node: MeshInstance3D, host: Node3D) -> Dictionary:
	var roles: Dictionary = {}
	for surface: int in range(node.mesh.get_surface_count()): roles[surface] = str(surface)
	return Contract.triangles(node.mesh as ArrayMesh, _frame(node, host), roles)

func _distance(a: Dictionary, b: Dictionary, rotation: int) -> Dictionary:
	var result := {"position":0.0,"normal":0.0,"uv":0.0,"color":0.0}
	for corner: int in range(3):
		var other := (corner + rotation) % 3
		result.position = maxf(result.position, (a.v[corner] as Vector3).distance_to(b.v[other]))
		result.normal = maxf(result.normal, (a.n[corner] as Vector3).distance_to(b.n[other]))
		result.uv = maxf(result.uv, (a.u[corner] as Vector2).distance_to(b.u[other]))
		var ac: Color = a.c[corner]
		var bc: Color = b.c[other]
		result.color = maxf(result.color, maxf(maxf(absf(ac.r-bc.r),absf(ac.g-bc.g)),maxf(absf(ac.b-bc.b),absf(ac.a-bc.a))))
	return result

func _serial(row: Dictionary) -> Dictionary:
	var result := {"role":row.role,"v":[],"n":[],"u":[],"c":[]}
	for index: int in range(3):
		var vertex: Vector3 = row.v[index]
		var normal: Vector3 = row.n[index]
		var uv: Vector2 = row.u[index]
		var color: Color = row.c[index]
		result.v.append([vertex.x,vertex.y,vertex.z])
		result.n.append([normal.x,normal.y,normal.z])
		result.u.append([uv.x,uv.y])
		result.c.append([color.r,color.g,color.b,color.a])
	return result

func _compare(a: Array, b: Array) -> Dictionary:
	var result: Dictionary = Contract.compare(a,b)
	var maximum := {"position":0.0,"normal":0.0,"uv":0.0,"color":0.0}
	var first: Dictionary = {}
	for row: Dictionary in a:
		var best_score := INF
		var best: Dictionary = {}
		var best_row: Dictionary = {}
		var best_rotation := 0
		var nearest_reversed_position := INF
		for candidate: Dictionary in b:
			if row.role != candidate.role: continue
			var reversed := {"role":candidate.role}
			for channel: String in ["v","n","u","c"]:
				reversed[channel] = [candidate[channel][0],candidate[channel][2],candidate[channel][1]]
			for rotation: int in range(3):
				var delta := _distance(row,candidate,rotation)
				nearest_reversed_position = minf(nearest_reversed_position,float(_distance(row,reversed,rotation).position))
				# Position is authoritative for correspondence; attributes break
				# ties between coincident faces. This diagnoses, never accepts.
				var score: float = delta.position * 1000000.0 + delta.normal + delta.uv + delta.color
				if score < best_score:
					best_score = score
					best = delta
					best_row = candidate
					best_rotation = rotation
		if best.is_empty(): continue
		for key: String in maximum: maximum[key] = maxf(maximum[key],best[key])
		if first.is_empty() and (best.position > Contract.POSITION_EPS or best.normal > Contract.ATTRIBUTE_EPS or best.uv > Contract.ATTRIBUTE_EPS or best.color > Contract.ATTRIBUTE_EPS):
			first = {"delta":best,"rotation":best_rotation,"same_material_role":row.role==best_row.role,
				"winding":"cyclic rotations only","nearest_reversed_position_error":nearest_reversed_position,
				"retained":_serial(row),"candidate":_serial(best_row)}
	result["nearest_wound_triangle_maximum_errors"] = maximum
	result["first_channel_failure"] = first
	return result

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		push_error("Expected art root and output JSON")
		quit(1)
		return
	var art := arguments[0]
	var report := {"kind":"read_only_native_transport_diagnostic","acceptance":false,"parts":{}}
	for identity: String in IDS:
		var receipt_path := art.path_join("models/living_assets_stage3_20261107/scenery").path_join(identity).path_join("authoring.json")
		var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
		var packed := load(art.path_join(receipt.retained_native)) as PackedScene
		if packed == null:
			push_error("Cannot load retained scene: " + identity)
			quit(1)
			return
		var baseline := packed.instantiate() as Node3D
		var retained := _import(art.path_join(receipt.retained_input))
		var authored := _import(art.path_join(receipt.carrier))
		if baseline == null or retained == null or authored == null:
			if baseline != null: baseline.free()
			if retained != null: retained.free()
			if authored != null: authored.free()
			push_error("Cannot instantiate input: " + identity)
			quit(1)
			return
		for part: Dictionary in receipt.parts:
			if part.node != "MarshReeds_0": continue
			var a := _rows(_find(baseline,part.node),baseline)
			var b := _rows(_find(retained,part.node),retained)
			var c := _rows(_find(authored,part.export_mesh),authored)
			report.parts[part.node] = {
				"counts":[a.rows.size(),b.rows.size(),c.rows.size()],
				"row_errors":[a.error,b.error,c.error],
				"native_to_retained_glb":_compare(a.rows,b.rows),
				"native_to_blender_glb":_compare(a.rows,c.rows),
				"retained_glb_to_blender_glb":_compare(b.rows,c.rows),
			}
		baseline.free()
		retained.free()
		authored.free()
	var file := FileAccess.open(arguments[1],FileAccess.WRITE)
	if file == null:
		push_error("Cannot write diagnostic output")
		quit(1)
		return
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	print("SCENERY_NATIVE_TRANSPORT_DIAGNOSTIC COMPLETE parts=",report.parts.size()," acceptance=false")
	quit(0)
