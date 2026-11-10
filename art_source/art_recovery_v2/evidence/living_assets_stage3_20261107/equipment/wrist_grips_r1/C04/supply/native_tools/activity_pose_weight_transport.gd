extends RefCounted

## Authoring-only: preserve actual Godot 4.6.3 uint16 skin weights across GLTF.
## The immutable source and raw carrier are never changed. No relaxed skin gate.
const SkinEquivalence = preload("activity_pose_skin_equivalence.gd")
const MAX_WEIGHT := 65535
const COMPONENT_BYTES := {5121:1,5123:2,5125:4,5126:4}
const TYPE_WIDTH := {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}

static func _fail(message: String, detail: Dictionary = {}) -> Dictionary:
	return {"verified":false,"error":message,"detail":detail}

static func _f32(value: float) -> float:
	return float(PackedFloat32Array([value])[0])

static func _normalize(values: Array) -> Array:
	var total := 0.0
	for value: float in values: total=_f32(total+value)
	var result: Array = []
	for value: float in values: result.append(_f32(value/total) if total>0.0 else value)
	return result

static func _pack(values: Array) -> Array:
	var result: Array = []
	for value: float in values: result.append(int(clampf(_f32(value*65535.0),0.0,65535.0)))
	return result

static func encode_q(quantized: Array) -> Dictionary:
	if quantized.size() not in [4,8]: return _fail("Expected four or eight skin weights")
	var sum := 0
	var nonzero: Array[int] = []
	var all_slots: Array[int] = []
	for index in quantized.size():
		var value: Variant = quantized[index]
		if typeof(value)!=TYPE_INT or value<0 or value>MAX_WEIGHT: return _fail("Invalid uint16 skin weight")
		sum+=int(value)
		all_slots.append(index)
		if value>0: nonzero.append(index)
	var deficit := MAX_WEIGHT-sum
	if deficit<0 or deficit>=quantized.size(): return _fail("No normalized representation inside original weight cells")
	for slots: Array in [nonzero,all_slots]:
		if slots.is_empty() or deficit>=slots.size(): continue
		var bump := float(deficit)/float(slots.size())
		var values: Array = []
		for index in quantized.size(): values.append(_f32((float(quantized[index])+(bump if index in slots else 0.0))/65535.0))
		if _pack(values)==quantized and _pack(_normalize(values))==quantized and _pack(_normalize(_normalize(values)))==quantized:
			return {"verified":true,"encoded":values,"retained_q":quantized.duplicate(),"normalization_passes_checked":2}
	return _fail("Float32 normalization cannot retain the exact original weight cells")

static func capture(original_root: Node) -> Dictionary:
	var version := Engine.get_version_info()
	if int(version.major)!=4 or int(version.minor)!=6 or int(version.patch)!=3: return _fail("Weight transport requires the pinned Godot 4.6.3 engine")
	var found := SkinEquivalence._weighted_meshes(original_root)
	if not bool(found.get("verified",false)): return found
	var manifest := {"schema_version":1,"engine_version":"4.6.3","meshes":{}}
	var report := {"verified":true,"meshes":0,"vertices":0,"influences":0,"maximum_deficit":0,"native_verified":false}
	for name: String in found.meshes:
		var entry: Dictionary = found.meshes[name]
		var instance: MeshInstance3D = entry.mesh
		var bindings := SkinEquivalence._bindings(entry)
		if not bool(bindings.get("verified",false)): return bindings
		var surfaces: Array[Dictionary] = []
		for surface in instance.mesh.get_surface_count():
			if instance.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return _fail("Non-triangle weighted surface")
			var arrays := instance.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			if points.is_empty() or weights.size()!=bones.size() or weights.size()%points.size()!=0: return _fail("Invalid retained skin arrays")
			var stride := weights.size()/points.size()
			if stride not in [4,8]: return _fail("Unsupported retained skin stride")
			var vertices: Array[Dictionary] = []
			for vertex in points.size():
				if not points[vertex].is_finite(): return _fail("Nonfinite retained vertex")
				var q: Array = []
				var joints: Array[String] = []
				var sum := 0
				for offset in stride:
					var slot := vertex*stride+offset
					var weight := float(weights[slot])
					if not is_finite(weight) or weight<0.0 or weight>1.0: return _fail("Invalid original skin weight")
					var value := roundi(weight*65535.0)
					if _f32(float(value)/65535.0)!=weight: return _fail("Original weight is not native uint16 readback")
					var bind := int(bones[slot])
					if bind<0 or bind>=bindings.rows.size(): return _fail("Original weight has an unresolved bind")
					q.append(value);sum+=value
					joints.append(str(bindings.rows[bind].name))
				var encoded := encode_q(q)
				if not bool(encoded.get("verified",false)): return _fail(str(encoded.error),{"mesh":name,"surface":surface,"vertex":vertex,"q":q})
				vertices.append({"position":[points[vertex].x,points[vertex].y,points[vertex].z],"joints":joints,"q":q})
				report.maximum_deficit=maxi(report.maximum_deficit,MAX_WEIGHT-sum)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var had_indices := not indices.is_empty()
			if indices.is_empty():
				indices.resize(points.size())
				for vertex in points.size(): indices[vertex]=vertex
			if indices.size()%3!=0: return _fail("Malformed original triangle indices")
			var gltf_indices: Array[int] = []
			for start in range(0,indices.size(),3):
				for offset in ([2,1,0] if had_indices else [0,2,1]):
					var index := int(indices[start+offset])
					if index<0 or index>=points.size(): return _fail("Original triangle index out of range")
					gltf_indices.append(index)
			surfaces.append({"vertices":vertices,"indices":gltf_indices,"stride":stride,"original_had_indices":had_indices})
			report.vertices+=points.size();report.influences+=weights.size()
		manifest.meshes[name]={"original_path":str(original_root.get_path_to(instance)),"surfaces":surfaces}
		report.meshes+=1
	if manifest.meshes.is_empty(): return _fail("No actual weighted meshes were captured")
	return {"verified":true,"manifest":manifest,"report":report}

static func _integer(value: Variant) -> bool:
	return (typeof(value)==TYPE_INT or typeof(value)==TYPE_FLOAT) and is_finite(float(value)) and float(value)>=0.0 and float(value)==floorf(float(value))

static func _descriptor(document: Dictionary, index: Variant, binary_length: int) -> Dictionary:
	var accessors: Array = document.get("accessors",[])
	if not _integer(index) or int(index)>=accessors.size(): return _fail("Accessor identity is absent")
	var accessor: Dictionary = accessors[int(index)]
	if not _integer(accessor.get("componentType",-1)) or not _integer(accessor.get("bufferView",-1)): return _fail("Invalid accessor component/view identity")
	var component := int(accessor.get("componentType",-1))
	var kind := str(accessor.get("type",""))
	if not COMPONENT_BYTES.has(component) or not TYPE_WIDTH.has(kind) or accessor.has("sparse"): return _fail("Unsupported skin transport accessor")
	var views: Array = document.get("bufferViews",[])
	var view_index := int(accessor.get("bufferView",-1))
	if view_index<0 or view_index>=views.size(): return _fail("Accessor buffer view absent")
	var view: Dictionary = views[view_index]
	var width := int(COMPONENT_BYTES[component])*int(TYPE_WIDTH[kind])
	for value: Variant in [accessor.get("count",-1),accessor.get("byteOffset",0),view.get("byteOffset",0),view.get("byteLength",-1),view.get("byteStride",width)]:
		if not _integer(value): return _fail("Invalid accessor bounds")
	var count := int(accessor.count)
	var local := int(accessor.get("byteOffset",0))
	var start := int(view.get("byteOffset",0))+local
	var stride := int(view.get("byteStride",width))
	var length := int(view.byteLength)
	if int(view.get("buffer",0))!=0 or count<=0 or stride<width or stride%int(COMPONENT_BYTES[component])!=0 or start%int(COMPONENT_BYTES[component])!=0:
		return _fail("Invalid accessor format")
	if local+(count-1)*stride+width>length or int(view.get("byteOffset",0))+length>binary_length: return _fail("Accessor escapes declared bytes")
	return {"verified":true,"start":start,"end":start+(count-1)*stride+width,"stride":stride,"width":width,"count":count,"component":component,"kind":kind,"normalized":bool(accessor.get("normalized",false))}

static func _read_accessor(document: Dictionary, binary: PackedByteArray, index: Variant, kind: String, component: int = -1) -> Dictionary:
	var descriptor := _descriptor(document,index,binary.size())
	if not bool(descriptor.get("verified",false)): return descriptor
	if descriptor.kind!=kind or descriptor.normalized or (component>=0 and descriptor.component!=component): return _fail("Unexpected skin accessor format")
	var rows: Array = []
	for row in int(descriptor.count):
		var values: Array = []
		for slot in int(TYPE_WIDTH[kind]):
			var at := int(descriptor.start)+row*int(descriptor.stride)+slot*int(COMPONENT_BYTES[descriptor.component])
			var value: Variant
			match int(descriptor.component):
				5121: value=int(binary[at])
				5123: value=int(binary.decode_u16(at))
				5125: value=int(binary.decode_u32(at))
				5126: value=float(binary.decode_float(at))
			if not is_finite(float(value)): return _fail("Nonfinite skin accessor value")
			values.append(value)
		rows.append(values)
	descriptor["rows"]=rows
	return descriptor

static func patch(raw_glb_path: String, corrected_glb_path: String, manifest: Dictionary) -> Dictionary:
	if raw_glb_path==corrected_glb_path or FileAccess.file_exists(corrected_glb_path): return _fail("Corrected carrier must be a new distinct file")
	if manifest.get("schema_version",0)!=1 or manifest.get("engine_version","")!="4.6.3" or not manifest.get("meshes",{}) is Dictionary: return _fail("Invalid original skin manifest")
	var raw := FileAccess.get_file_as_bytes(raw_glb_path)
	if raw.size()<28 or raw.decode_u32(0)!=0x46546c67 or raw.decode_u32(4)!=2 or raw.decode_u32(8)!=raw.size(): return _fail("Invalid raw GLB header")
	var json_length := int(raw.decode_u32(12))
	var bin_header := 20+json_length
	if json_length%4!=0 or bin_header+8>raw.size() or raw.decode_u32(16)!=0x4e4f534a or raw.decode_u32(bin_header+4)!=0x004e4942: return _fail("Expected JSON and BIN GLB chunks")
	var bin_length := int(raw.decode_u32(bin_header))
	var bin_start := bin_header+8
	if bin_length%4!=0 or bin_start+bin_length!=raw.size(): return _fail("Invalid raw BIN bounds")
	var parsed: Variant = JSON.parse_string(raw.slice(20,bin_header).get_string_from_utf8())
	if not parsed is Dictionary: return _fail("Invalid raw GLB JSON")
	var document: Dictionary = parsed
	if document.get("asset",{}).get("version","")!="2.0": return _fail("Unsupported GLTF version")
	var buffers: Array = document.get("buffers",[])
	if buffers.size()!=1 or buffers[0].has("uri") or not _integer(buffers[0].get("byteLength",-1)): return _fail("Expected one embedded skin buffer")
	var declared := int(buffers[0].byteLength)
	if declared>bin_length or bin_length-declared>3: return _fail("Invalid declared BIN length")
	var binary := raw.slice(bin_start,bin_start+declared)
	var nodes: Array = document.get("nodes",[])
	var meshes: Array = document.get("meshes",[])
	var skins: Array = document.get("skins",[])
	var found: Dictionary = {}
	var edits: Dictionary = {}
	var weight_accessors: Dictionary = {}
	var report := {"verified":true,"method":"Original uint16 cells; explicit mesh/vertex/joint/winding identity; two F32 normalization passes","vertices":0,"influences":0,"changed_weight_bytes":0,"original_zero_slots":0,"literal_zero_slots_encoded_positive":0,"native_verified":false,"blender_skin_verified":false}
	for node: Dictionary in nodes:
		if not node.has("skin") or not node.has("mesh"): continue
		var name := str(node.get("name",""))
		if not manifest.meshes.has(name) or found.has(name): return _fail("Unexpected or ambiguous weighted mesh: "+name)
		found[name]=true
		if not _integer(node.mesh) or not _integer(node.skin): return _fail("Invalid actual mesh/skin identity")
		var mesh_index := int(node.mesh)
		var skin_index := int(node.skin)
		if mesh_index<0 or mesh_index>=meshes.size() or skin_index<0 or skin_index>=skins.size(): return _fail("Missing actual mesh/skin")
		var joint_nodes: Array = skins[skin_index].get("joints",[])
		var joint_names: Array[String] = []
		for joint: Variant in joint_nodes:
			if not _integer(joint) or int(joint)>=nodes.size(): return _fail("Invalid skin joint identity")
			var bone_name := str(nodes[int(joint)].get("name",""))
			if bone_name.is_empty() or bone_name in joint_names: return _fail("Ambiguous named skin joint")
			joint_names.append(bone_name)
		var surfaces: Array = manifest.meshes[name].surfaces
		var primitives: Array = meshes[mesh_index].get("primitives",[])
		if surfaces.size()!=primitives.size(): return _fail("Weighted surface count changed")
		for surface in surfaces.size():
			var source: Dictionary = surfaces[surface]
			var primitive: Dictionary = primitives[surface]
			var attrs: Dictionary = primitive.get("attributes",{})
			if int(primitive.get("mode",4))!=4 or primitive.has("targets"): return _fail("Unexpected weighted primitive mode/morph")
			var points := _read_accessor(document,binary,attrs.get("POSITION",-1),"VEC3",5126)
			var indices := _read_accessor(document,binary,primitive.get("indices",-1),"SCALAR")
			if not bool(points.get("verified",false)): return points
			if not bool(indices.get("verified",false)) or int(indices.component) not in [5121,5123,5125]: return _fail("Invalid exported triangle indices")
			if points.rows.size()!=source.vertices.size() or indices.rows.size()!=source.indices.size(): return _fail("Exported vertex/index inventory changed")
			for index in source.indices.size():
				if int(indices.rows[index][0])!=int(source.indices[index]): return _fail("Exported wound triangle/index order changed",{"mesh":name,"surface":surface,"index":index})
			var groups := int(source.stride)/4
			if groups not in [1,2] or (groups==1 and (attrs.has("WEIGHTS_1") or attrs.has("JOINTS_1"))): return _fail("Exported influence stride changed")
			var weights: Array[Dictionary] = []
			var joints: Array[Dictionary] = []
			for group in groups:
				if not _integer(attrs.get("WEIGHTS_"+str(group),-1)): return _fail("Invalid weight accessor identity")
				var weight_id := int(attrs.get("WEIGHTS_"+str(group),-1))
				var weight := _read_accessor(document,binary,weight_id,"VEC4",5126)
				var joint := _read_accessor(document,binary,attrs.get("JOINTS_"+str(group),-1),"VEC4")
				if not bool(weight.get("verified",false)): return weight
				if not bool(joint.get("verified",false)) or int(joint.component) not in [5121,5123]: return _fail("Invalid joint accessor")
				if weight.rows.size()!=points.rows.size() or joint.rows.size()!=points.rows.size(): return _fail("Influence vertex count differs")
				if weight_accessors.has(weight_id): return _fail("Shared weight accessor is ambiguous")
				weight_accessors[weight_id]=weight
				weights.append(weight);joints.append(joint)
			for vertex: int in source.vertices.size():
				var retained: Dictionary = source.vertices[vertex]
				for axis in 3:
					if absf(float(points.rows[vertex][axis])-float(retained.position[axis]))>0.000001: return _fail("Exported rest position/order changed",{"mesh":name,"surface":surface,"vertex":vertex})
				var q: Array = []
				for value: Variant in retained.q:
					if not _integer(value): return _fail("Invalid retained q manifest")
					q.append(int(value))
				var encoded := encode_q(q)
				if not bool(encoded.get("verified",false)): return encoded
				if q.size()!=int(source.stride) or retained.joints.size()!=q.size(): return _fail("Retained influence slot count differs")
				var original_weights: Array = []
				for value: int in q: original_weights.append(_f32(float(value)/65535.0))
				var expected_raw := _normalize(original_weights)
				for slot: int in q.size():
					var group: int = slot/4
					var within: int = slot%4
					var joint := int(joints[group].rows[vertex][within])
					if joint<0 or joint>=joint_names.size() or joint_names[joint]!=str(retained.joints[slot]): return _fail("Exported joint slot/order changed",{"mesh":name,"surface":surface,"vertex":vertex,"slot":slot})
					if float(weights[group].rows[vertex][within])!=float(expected_raw[slot]): return _fail("Raw GLTF weight is not the pinned export of the original readback",{"mesh":name,"surface":surface,"vertex":vertex,"slot":slot,"expected":expected_raw[slot],"actual":weights[group].rows[vertex][within]})
					var at: int = int(weights[group].start)+vertex*int(weights[group].stride)+within*4
					if edits.has(at): return _fail("Overlapping weight edits")
					edits[at]=float(encoded.encoded[slot])
					if q[slot]==0:
						report.original_zero_slots+=1
						if float(encoded.encoded[slot])>0.0: report.literal_zero_slots_encoded_positive+=1
				report.vertices+=1;report.influences+=q.size()
	if found.size()!=manifest.meshes.size() or found.is_empty(): return _fail("Captured weighted mesh inventory is incomplete")
	# No other semantic attribute, skin bind or animation may alias patched bytes.
	for index in document.get("accessors",[]).size():
		if weight_accessors.has(index): continue
		var descriptor := _descriptor(document,index,declared)
		if not bool(descriptor.get("verified",false)): return descriptor
		for weight: Dictionary in weight_accessors.values():
			if int(descriptor.start)<int(weight.end) and int(weight.start)<int(descriptor.end): return _fail("Weight bytes overlap a non-weight accessor")
	var corrected := raw.duplicate()
	for at: int in edits:
		corrected.encode_float(bin_start+at,float(edits[at]))
		for byte in 4:
			if corrected[bin_start+at+byte]!=raw[bin_start+at+byte]: report.changed_weight_bytes+=1
	if FileAccess.get_file_as_bytes(raw_glb_path)!=raw: return _fail("Raw carrier changed during transport proof")
	if FileAccess.file_exists(corrected_glb_path): return _fail("Corrected carrier appeared during proof; preserving it")
	var output := FileAccess.open(corrected_glb_path,FileAccess.WRITE)
	if output==null: return _fail("Cannot create corrected authoring carrier")
	output.store_buffer(corrected)
	output.close()
	if FileAccess.get_file_as_bytes(corrected_glb_path)!=corrected: return _fail("Corrected carrier write did not retain proved bytes")
	report["raw_sha256"]=FileAccess.get_sha256(raw_glb_path)
	report["corrected_sha256"]=FileAccess.get_sha256(corrected_glb_path)
	report["manifest_sha256"]=JSON.stringify(manifest).sha256_text()
	report["only_existing_weight_bytes_changed"]=true
	return report
