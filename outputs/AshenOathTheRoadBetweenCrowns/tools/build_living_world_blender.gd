extends SceneTree

const GeometryContract = preload("res://tools/living_world_geometry_contract.gd")

## Compile only the reviewed Blender exports; the existing world owner animates
## these inline meshes. Immutable archived native scenes are equivalence inputs;
## repeated compilation must never treat its own output as a fresh baseline.
const IDS := ["checkpoint_cloth", "marsh_reeds", "hart_ferns", "ash_mill_wheel"]
const COUNTS := {"checkpoint_cloth":2,"marsh_reeds":5,"hart_ferns":6,"ash_mill_wheel":1}
const OUTPUT := "res://assets_external/environment_prepared/living_world/"

func _initialize() -> void:
	call_deferred("_run")

func _named(node: Node, name_value: String, found: Array[Node]) -> void:
	if str(node.name) == name_value:
		found.append(node)
	for child: Node in node.get_children():
		_named(child,name_value,found)

func _find(node: Node, name_value: String) -> Node:
	var found: Array[Node]=[]
	_named(node,name_value,found)
	return found[0] if found.size()==1 else null

func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children(): count+=_mesh_count(child)
	return count

func _relative(node: Node3D, root_node: Node3D) -> Transform3D:
	var value := node.transform
	var ancestor := node.get_parent()
	while ancestor != null and ancestor != root_node:
		if ancestor is Node3D:
			value = (ancestor as Node3D).transform * value
		ancestor = ancestor.get_parent()
	return value

func _point_key(point: Vector3) -> String:
	return "%d,%d,%d" % [roundi(point.x * 10000.0), roundi(point.y * 10000.0), roundi(point.z * 10000.0)]

func _geometry(mesh: Mesh, transform: Transform3D) -> Array[String]:
	var signatures: Array[String] = []
	# Native extraction and GLTF import both produce ArrayMesh. Primitive type
	# is an ArrayMesh API, not a public method of the generic Mesh resource.
	if not mesh is ArrayMesh: return signatures
	var array_mesh := mesh as ArrayMesh
	for surface: int in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: return []
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=[]
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices=arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		if array_mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES or count==0 or count%3!=0: return []
		for index: int in range(0,count,3):
			var points: Array[String]=[]
			for corner: int in range(3):
				var slot := indices[index+corner] if not indices.is_empty() else index+corner
				if slot<0 or slot>=vertices.size() or not vertices[slot].is_finite(): return []
				points.append(_point_key(transform*vertices[slot]))
			# Cyclic rotations preserve winding; sorting the three points would
			# wrongly accept flipped faces. Surface identity retains materials.
			var cycles := [";".join(points),";".join([points[1],points[2],points[0]]),";".join([points[2],points[0],points[1]])]
			cycles.sort()
			signatures.append(str(surface)+":"+str(cycles[0]))
	signatures.sort()
	return signatures

func _colors(mesh: Mesh, transform: Transform3D) -> Array[String]:
	var signatures: Dictionary = {}
	for surface: int in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_COLOR] is PackedColorArray or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
			return []
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if colors.size() != vertices.size() or normals.size()!=vertices.size() or uvs.size()!=vertices.size():
			return []
		for index: int in range(vertices.size()):
			var color := colors[index]
			if not vertices[index].is_finite() or not normals[index].is_finite() or not uvs[index].is_finite() or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a): return []
			var normal := (transform.basis.inverse().transposed()*normals[index]).normalized()
			var key := str(surface)+":"+_point_key(transform * vertices[index]) + ":"+_point_key(normal)+":%d,%d,%d,%d" % [roundi(color.r * 10000.0), roundi(color.g * 10000.0), roundi(color.b * 10000.0), roundi(color.a * 10000.0)]
			key += ":%d,%d" % [roundi(uvs[index].x*10000.0),roundi(uvs[index].y*10000.0)]
			signatures[key] = true
	var result: Array[String] = []
	result.assign(signatures.keys())
	result.sort()
	return result

func _run() -> void:
	if "--verify-contract" in OS.get_cmdline_user_args():
		_verify_contract()
		return
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var art := repository.path_join("art_source/art_recovery_v2")
	var requested: Array[String] = []
	var arguments := OS.get_cmdline_user_args()
	var selected := arguments.find("--asset")
	if selected >= 0 and selected + 1 < arguments.size():
		requested.append(arguments[selected + 1])
	else:
		requested.assign(IDS)
	for identity: String in requested:
		var error := _compile(identity, art)
		if not error.is_empty():
			push_error(error)
			quit(1)
			return
	quit(0)

func _test_mesh(order: PackedInt32Array, color: Color=Color.WHITE, normal: Vector3=Vector3.BACK, include_colors: bool=true, uv_offset: Vector2=Vector2.ZERO) -> ArrayMesh:
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([normal,normal,normal])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO+uv_offset,Vector2.RIGHT+uv_offset,Vector2.UP+uv_offset])
	arrays[Mesh.ARRAY_INDEX]=order
	if include_colors: arrays[Mesh.ARRAY_COLOR]=PackedColorArray([color,color,color])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _verify_contract() -> void:
	# Small in-memory fixture: no authored assets, world, renderer or filesystem.
	var original := _test_mesh(PackedInt32Array([0,1,2]))
	var rotated := _test_mesh(PackedInt32Array([1,2,0]))
	var flipped := _test_mesh(PackedInt32Array([0,2,1]))
	var different_color := _test_mesh(PackedInt32Array([0,1,2]),Color(0.2,0.3,0.4))
	var different_normal := _test_mesh(PackedInt32Array([0,1,2]),Color.WHITE,Vector3.FORWARD)
	var missing_colors := _test_mesh(PackedInt32Array([0,1,2]),Color.WHITE,Vector3.BACK,false)
	var different_uv := _test_mesh(PackedInt32Array([0,1,2]),Color.WHITE,Vector3.BACK,true,Vector2(.01,0))
	var geometry := _geometry(original,Transform3D.IDENTITY)
	var palette := _colors(original,Transform3D.IDENTITY)
	var checks: Array[bool]=[
		geometry.size()==1,
		geometry==_geometry(rotated,Transform3D.IDENTITY),
		geometry!=_geometry(flipped,Transform3D.IDENTITY),
		geometry!=_geometry(original,Transform3D(Basis.IDENTITY,Vector3(0.01,0,0))),
		palette.size()==3,
		palette!=_colors(different_color,Transform3D.IDENTITY),
		palette!=_colors(different_normal,Transform3D.IDENTITY),
		_colors(missing_colors,Transform3D.IDENTITY).is_empty(),
		palette!=_colors(different_uv,Transform3D.IDENTITY),
	]
	var tree := Node3D.new()
	var support := Node3D.new()
	support.name="Support"
	support.position=Vector3(1,2,3)
	tree.add_child(support)
	var child := MeshInstance3D.new()
	child.name="Geometry"
	child.mesh=original
	support.add_child(child)
	checks.append(_relative(child,tree).origin.is_equal_approx(support.position) and _mesh_count(tree)==1)
	var second := Node3D.new()
	tree.add_child(second)
	var duplicate := Node3D.new()
	duplicate.name="Geometry"
	second.add_child(duplicate)
	checks.append(_find(tree,"Geometry")==null)
	tree.free()
	var success := true
	for index: int in range(checks.size()):
		if not checks[index]:
			push_error("Scenery geometry/provenance contract check failed: "+str(index+1))
			success=false
	print("SCENERY_BLENDER_CONTRACT: ","PASS" if success else "FAIL"," checks=",checks.size()," authored_assets=none")
	quit(0 if success else 1)

func _compile(identity: String, art: String) -> String:
	if identity not in IDS:
		return "Unknown Blender scenery assembly: " + identity
	var folder := art.path_join("models/living_assets_stage3_20261107/scenery").path_join(identity)
	var receipt_path := folder.path_join("authoring.json")
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	if not receipt is Dictionary or receipt.get("schema_version")!=2 or receipt.get("asset")!=identity or receipt.get("blender_authored")!=true:
		return "Missing authored Blender scenery receipt: " + identity
	if not receipt.get("parts") is Array or receipt.parts.size()!=int(COUNTS[identity]) or not receipt.get("source_hashes") is Dictionary or receipt.source_hashes.is_empty():
		return "Malformed authored Blender scenery contract: "+identity
	var paths: Dictionary={}
	for key: String in ["blend","carrier","recipe","retained_input","retained_native","retained_receipt"]:
		var relative := str(receipt.get(key,"")).replace("\\","/")
		var source := art.path_join(relative).simplify_path()
		var digest := str(receipt.get(key+"_sha256",""))
		if relative.is_empty() or relative.is_absolute_path() or not source.begins_with(art + "/") or digest.length()!=64 or not FileAccess.file_exists(source) or FileAccess.get_sha256(source)!=digest:
			return "Blender scenery provenance changed: " + identity + "/" + key
		paths[key]=source
	var retained: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(paths.retained_receipt)))
	if not retained is Dictionary or retained.get("schema_version")!=2 or retained.get("asset")!=identity or retained.get("source_hashes")!=receipt.source_hashes or retained.get("carrier_sha256")!=receipt.retained_input_sha256 or retained.get("native_baseline_sha256")!=receipt.retained_native_sha256 or not retained.get("parts") is Array:
		return "Archived native baseline identity differs from Blender authoring: "+identity
	var native_parts: Dictionary={}
	for part: Variant in retained.parts:
		if not part is Dictionary or str(part.get("node",""))=="" or native_parts.has(str(part.node)): return "Invalid archived retained part identity: "+identity
		native_parts[str(part.node)]=part
	if native_parts.size()!=int(COUNTS[identity]): return "Archived baseline part count changed: "+identity
	var authored_names: Dictionary={}
	for part: Variant in receipt.parts:
		if not part is Dictionary or not native_parts.has(str(part.get("node",""))) or authored_names.has(str(part.node)):
			return "Authored scenery mesh identities changed: "+identity
		authored_names[str(part.node)]=true
		var recorded: Dictionary=native_parts[str(part.node)]
		var pivot: Variant=part.get("pivot_godot")
		if not pivot is Array or pivot.size()!=3: return "Malformed authored support pivot: "+str(part.node)
		for value: Variant in pivot:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):
				return "Nonfinite authored support pivot: "+str(part.node)
		for field: String in ["kind","pivot_godot","geometry_sha256","triangles","sources"]:
			if part.get(field)!=recorded.get(field): return "Authored scenery changed retained contract: "+str(part.node)+"/"+field
		if str(part.get("export_mesh",""))!=str(part.node)+"_Geometry" or str(part.get("support_node",""))!=str(part.node):
			return "Authored mesh/support names differ from the explicit contract: "+str(part.node)
	for source: String in receipt.source_hashes:
		if not source.begins_with("res://") or str(receipt.source_hashes[source]).length()!=64 or not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != str(receipt.source_hashes[source]):
			return "Retained scenery builder/source changed: " + source
	var output := OUTPUT + identity + ".scn"
	var baseline_resource := ResourceLoader.load(str(paths.retained_native),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if baseline_resource==null: return "Archived native baseline cannot load: "+identity
	var baseline := baseline_resource.instantiate() as Node3D
	if baseline==null: return "Archived native baseline has no Node3D root: "+identity
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(str(paths.carrier), state)
	if error != OK:
		baseline.free()
		return "Cannot import authored Blender scenery: " + identity
	var imported := document.generate_scene(state) as Node3D
	if imported==null:
		baseline.free()
		return "Authored Blender scene could not instantiate: "+identity
	if _mesh_count(imported)!=int(COUNTS[identity]) or baseline.get_child_count()!=int(COUNTS[identity]):
		baseline.free(); imported.free()
		return "Blender/native scenery contains unexpected mesh parts: "+identity
	var final_scene := Node3D.new()
	final_scene.name = baseline.name
	var reports: Array[Dictionary] = []
	var failure := ""
	for part: Dictionary in receipt.parts:
		var original := _find(baseline, str(part.node)) as MeshInstance3D
		var authored := _find(imported, str(part.export_mesh)) as MeshInstance3D
		if original == null or authored == null or original.mesh == null or authored.mesh == null:
			failure = "Missing exact retained/Blender mesh binding: " + str(part.node)
			break
		var authored_transform := _relative(authored, imported)
		var original_transform := _relative(original, baseline)
		if not authored_transform.is_finite() or not original_transform.is_finite() or absf(authored_transform.basis.determinant())<0.00000001 or absf(original_transform.basis.determinant())<0.00000001:
			failure="Nonfinite or singular retained mesh frame: "+str(part.node)
			break
		var geometry := _geometry(original.mesh,original_transform)
		if geometry.is_empty() or _geometry(authored.mesh, authored_transform).is_empty():
			failure = "Blender export changed retained triangle geometry: " + str(part.node)
			break
		var colors := _colors(original.mesh, original_transform)
		if colors.is_empty() or _colors(authored.mesh, authored_transform).is_empty():
			failure = "Blender export changed retained vertex palette, normals or UVs: " + str(part.node)
			break
		var roles: Dictionary = {}
		for surface: int in range(original.mesh.get_surface_count()): roles[surface] = str(surface)
		# Compare complete corners with a metric tolerance. Rounded-cell equality
		# alone can reject harmless float noise either side of a cell boundary.
		var original_rows: Dictionary = GeometryContract.triangles(original.mesh as ArrayMesh,original_transform,roles)
		var authored_rows: Dictionary = GeometryContract.triangles(authored.mesh as ArrayMesh,authored_transform,roles)
		if not original_rows.error.is_empty() or not authored_rows.error.is_empty() or not GeometryContract.compare(original_rows.rows,authored_rows.rows).passed:
			failure = "Blender export changed retained triangle-corner attributes or multiplicity: " + str(part.node)
			break
		var expected_pivot := Vector3(float(part.pivot_godot[0]), float(part.pivot_godot[1]), float(part.pivot_godot[2]))
		var support := _find(imported, str(part.support_node)) as Node3D
		if support == null or _relative(support, imported).origin.distance_to(expected_pivot) > 0.00001:
			failure = "Blender support pivot changed: " + str(part.node)
			break
		var mesh_transform := original_transform.affine_inverse() * authored_transform
		if not mesh_transform.is_equal_approx(Transform3D.IDENTITY):
			failure = "Blender mesh must retain its support-local frame: " + str(part.node)
			break
		var compiled := MeshInstance3D.new()
		compiled.name = original.name
		compiled.transform = original.transform
		compiled.mesh = authored.mesh.duplicate(true)
		if compiled.mesh.get_surface_count() != original.mesh.get_surface_count():
			compiled.free()
			failure = "Blender export changed retained material partitions: " + str(part.node)
			break
		# Interchange preserves geometry/colors; retain the exact game material
		# settings, including two-sided foliage and the current roughness.
		for surface: int in range(compiled.mesh.get_surface_count()):
			var material := original.mesh.surface_get_material(surface)
			compiled.mesh.surface_set_material(surface, material.duplicate(true) if material != null else null)
			(compiled.mesh as ArrayMesh).surface_set_name(surface,(original.mesh as ArrayMesh).surface_get_name(surface))
		compiled.cast_shadow = original.cast_shadow
		for key: StringName in original.get_meta_list():
			compiled.set_meta(key, original.get_meta(key))
		compiled.set_meta("blender_source_sha256", str(receipt.carrier_sha256))
		final_scene.add_child(compiled)
		compiled.owner = final_scene
		reports.append({"node": str(compiled.name), "retained_triangles": compiled.mesh.get_faces().size() / 3,
			"geometry_palette_equivalent": true, "winding_normals_uvs_partitions_equivalent":true, "triangle_attribute_multiplicity_equivalent":true, "maximum_quantization_metres": 0.0001,
			"pivot_error_metres": _relative(support, imported).origin.distance_to(expected_pivot)})
	if failure.is_empty() and reports.size() != baseline.get_child_count():
		failure = "Blender scenery assembly changed the retained part count: " + identity
	if not failure.is_empty():
		final_scene.free()
		imported.free()
		baseline.free()
		return failure
	for key: StringName in baseline.get_meta_list():
		final_scene.set_meta(key, baseline.get_meta(key))
	final_scene.set_meta("blender_authored", true)
	final_scene.set_meta("blender_source_sha256", str(receipt.carrier_sha256))
	var packed := PackedScene.new()
	error = packed.pack(final_scene)
	if error == OK:
		error = ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES)
	final_scene.free()
	imported.free()
	baseline.free()
	if error != OK:
		return "Cannot save compiled Blender scenery: " + identity
	var report_path := art.path_join("evidence/living_assets_stage3_20261107/scenery").path_join(identity + "_compile.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		return "Cannot save compiled Blender scenery receipt: " + identity
	file.store_string(JSON.stringify({"schema_version": 1, "asset": identity, "path": output,
		"sha256": FileAccess.get_sha256(output), "bytes": FileAccess.get_file_as_bytes(output).size(),
		"blender_authored": true, "authoring_receipt": receipt_path, "authoring_receipt_sha256": FileAccess.get_sha256(receipt_path),
		"source_hashes": receipt.source_hashes, "carrier_sha256": receipt.carrier_sha256,
		"retained_native_sha256":receipt.retained_native_sha256,"retained_receipt_sha256":receipt.retained_receipt_sha256,
		"compiler_sha256": FileAccess.get_sha256("res://tools/build_living_world_blender.gd"),
		"geometry_contract_sha256":FileAccess.get_sha256("res://tools/living_world_geometry_contract.gd"),
		"parts": reports, "dependencies": ResourceLoader.get_dependencies(output),
		"runtime_reviewed": false, "user_accepted": false}, "\t") + "\n")
	file.close()
	print("LIVING_WORLD_BLENDER_COMPILED ", identity, " parts=", reports.size())
	return ""
