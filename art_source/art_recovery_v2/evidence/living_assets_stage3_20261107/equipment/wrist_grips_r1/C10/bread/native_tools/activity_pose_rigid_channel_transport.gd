extends RefCounted

## Authoring-only transport of the actual packed normal/tangent cells. Source
## geometry, raw/intermediate carriers and the strict native gate are unchanged.
const Accessors = preload("activity_pose_weight_transport.gd")
const Rigid = preload("activity_pose_rigid_equivalence.gd")
const CHANNELS := {Mesh.ARRAY_VERTEX:"POSITION",Mesh.ARRAY_NORMAL:"NORMAL",Mesh.ARRAY_TANGENT:"TANGENT",Mesh.ARRAY_COLOR:"COLOR_0",Mesh.ARRAY_TEX_UV:"TEXCOORD_0",Mesh.ARRAY_TEX_UV2:"TEXCOORD_1"}
const KINDS := {"POSITION":"VEC3","NORMAL":"VEC3","TANGENT":"VEC4","COLOR_0":"VEC4","TEXCOORD_0":"VEC2","TEXCOORD_1":"VEC2"}

static func _fail(message: String, detail: Dictionary = {}) -> Dictionary:
	return {"verified":false,"error":message,"detail":detail}

static func _f32(value: float) -> float:
	return float(PackedFloat32Array([value])[0])

static func _decode_coordinate(coordinate: Vector2, tangent: bool) -> Array:
	var sign_value := 1.0
	if tangent:
		coordinate.y=_f32(_f32(coordinate.y*2.0)-1.0)
		sign_value=1.0 if coordinate.y>=0.0 else -1.0
		coordinate.y=absf(coordinate.y)
	var vector := Vector3.octahedron_decode(coordinate)
	var result: Array = [vector.x,vector.y,vector.z]
	if tangent: result.append(sign_value)
	return result

static func decode_q(q: Array, tangent: bool = false) -> Array:
	return _decode_coordinate(Vector2(_f32(float(q[0])/65535.0),_f32(float(q[1])/65535.0)),tangent)

static func pack(values: Array, tangent: bool = false) -> Array:
	if values.size()!=(4 if tangent else 3): return []
	for value: Variant in values:
		if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)): return []
	var vector := Vector3(float(values[0]),float(values[1]),float(values[2]))
	if not vector.is_finite() or vector.length_squared()==0.0: return []
	var encoded := vector.octahedron_encode()
	if tangent:
		encoded.y=maxf(encoded.y,_f32(1.0/32767.0))
		encoded.y=_f32(_f32(encoded.y*0.5)+0.5)
		if float(values[3])<0.0: encoded.y=_f32(1.0-encoded.y)
	var result: Array = [int(clampf(_f32(encoded.x*65535.0),0.0,65535.0)),int(clampf(_f32(encoded.y*65535.0),0.0,65535.0))]
	# Pinned rendering_server.cpp646 reserves this compression-detection code.
	if tangent and result==[0,65535]: result[0]=65535
	return result

static func encode_q(q: Array, tangent: bool = false) -> Dictionary:
	if q.size()!=2: return _fail("Expected exactly two original packed cells")
	for value: Variant in q:
		if typeof(value)!=TYPE_INT or int(value)<0 or int(value)>65535: return _fail("Invalid original uint16 channel cell")
	if tangent and q==[0,65535]: return _fail("Native tangent sanitation makes these exact cells unreachable")
	var sign_value := float(decode_q(q,true)[3]) if tangent else 0.0
	for x_offset: float in [0.5,0.25,0.75,0.125,0.875,0.0]:
		for y_offset: float in [0.5,0.25,0.75,0.125,0.875,0.0]:
			var coordinate := Vector2(_f32((float(q[0])+x_offset)/65535.0) if int(q[0])<65535 else 1.0,_f32((float(q[1])+y_offset)/65535.0) if int(q[1])<65535 else 1.0)
			var decoded := _decode_coordinate(coordinate,tangent)
			var oct_y := absf(_f32(_f32(coordinate.y*2.0)-1.0)) if tangent else coordinate.y
			# A folded boundary can erase negative zero. Probe that zero's
			# original octant only, requiring the same exact packed result.
			for epsilon: float in [0.0,0.000000003725290298461914,0.000000014901161193847656,0.000000059604644775390625]:
				var vector := Vector3(float(decoded[0]),float(decoded[1]),float(decoded[2]))
				if vector.x==0.0: vector.x=(-epsilon if coordinate.x<0.5 else epsilon)
				if vector.y==0.0: vector.y=(-epsilon if oct_y<0.5 else epsilon)
				vector=vector.normalized()
				var values: Array = [vector.x,vector.y,vector.z]
				if tangent: values.append(decoded[3])
				if tangent and float(values[3])!=sign_value: continue
				if pack(values,tangent)!=q: continue
				if not tangent:
					var normalized := vector.normalized()
					if pack([normalized.x,normalized.y,normalized.z])!=q: continue
				return {"verified":true,"encoded":values,"retained_q":q.duplicate(),"tangent":tangent,"sign":sign_value}
	return _fail("No proved float32 representative inside the original channel cells",{"q":q,"tangent":tangent})

static func _raw_signature(mesh: ArrayMesh) -> String:
	return var_to_bytes(mesh.get("_surfaces")).hex_encode().sha256_text()

static func _capture_surface(mesh: ArrayMesh, surface: int, raw: Dictionary) -> Dictionary:
	if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return _fail("Only retained rigid triangles are supported")
	var format := int(raw.get("format",0))
	if format&(Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES|Mesh.ARRAY_FLAG_USE_2D_VERTICES)!=0: return _fail("Packed vertex compression or2D needs a separate transport contract")
	var arrays := mesh.surface_get_arrays(surface)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var count := points.size()
	if count<=0 or int(raw.get("vertex_count",-1))!=count: return _fail("Rigid packed/readback vertex inventory differs")
	var normals: bool = arrays[Mesh.ARRAY_NORMAL]!=null and arrays[Mesh.ARRAY_NORMAL].size()>0
	var tangents: bool = arrays[Mesh.ARRAY_TANGENT]!=null and arrays[Mesh.ARRAY_TANGENT].size()>0
	if tangents and not normals: return _fail("Tangent-only packed layout is unsupported")
	var stride := (4 if normals else 0)+(4 if tangents else 0)
	var bytes: PackedByteArray = raw.get("vertex_data",PackedByteArray())
	if bytes.size()!=count*(12+stride): return _fail("Unexpected uncompressed rigid vertex byte layout")
	var attrs: Dictionary = {}
	for channel in range(Mesh.ARRAY_VERTEX,Mesh.ARRAY_INDEX):
		if arrays[channel]==null or arrays[channel].size()==0: continue
		if not CHANNELS.has(channel): return _fail("Unproved rigid attribute channel: "+str(channel))
		var channel_stride := 4 if channel==Mesh.ARRAY_TANGENT else 1
		if arrays[channel].size()!=count*channel_stride: return _fail("Malformed rigid attribute length")
		var rows: Array = []
		for vertex in count:
			var row: Array = []
			for within in channel_stride: row.append_array(Rigid._numbers(arrays[channel][vertex*channel_stride+within]))
			if row.size()!=int(Accessors.TYPE_WIDTH[KINDS[CHANNELS[channel]]]): return _fail("Unexpected retained attribute shape")
			for value: float in row:
				if not is_finite(value): return _fail("Nonfinite retained rigid channel")
			rows.append(row)
		attrs[CHANNELS[channel]]=rows
	var cells: Dictionary = {}
	for channel: String in ["NORMAL","TANGENT"]:
		if not attrs.has(channel): continue
		var tangent := channel=="TANGENT"
		var rows: Array = []
		for vertex in count:
			var at := count*12+vertex*stride+(4 if tangent else 0)
			var q: Array = [int(bytes.decode_u16(at)),int(bytes.decode_u16(at+2))]
			if decode_q(q,tangent)!=attrs[channel][vertex]: return _fail("Packed cells do not exactly reconstruct actual native readback",{"surface":surface,"vertex":vertex,"channel":channel})
			var encoded := encode_q(q,tangent)
			if not bool(encoded.verified): return encoded
			rows.append(q)
		cells[channel]=rows
	for vertex in count:
		for axis in 3:
			if float(bytes.decode_float(vertex*12+axis*4))!=float(attrs.POSITION[vertex][axis]): return _fail("Packed original position/order differs from readback")
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var indexed := not indices.is_empty()
	if not indexed:
		indices.resize(count)
		for vertex in count: indices[vertex]=vertex
	if indices.size()%3!=0: return _fail("Malformed original rigid triangle count")
	var exported_indices: Array = []
	for start in range(0,indices.size(),3):
		for offset: int in ([2,1,0] if indexed else [0,2,1]):
			var index := int(indices[start+offset])
			if index<0 or index>=count: return _fail("Original rigid triangle index escapes vertices")
			exported_indices.append(index)
	return {"verified":true,"attributes":attrs,"cells":cells,"indices":exported_indices,"original_had_indices":indexed,"format":format,"raw_surface_sha256":var_to_bytes(raw).hex_encode().sha256_text()}

static func capture(root: Node3D) -> Dictionary:
	var version := Engine.get_version_info()
	if int(version.major)!=4 or int(version.minor)!=6 or int(version.patch)!=3: return _fail("Rigid channel transport requires pinned Godot4.6.3")
	var inventory := Rigid._inventory(root)
	if not bool(inventory.verified): return inventory
	var manifest := {"schema_version":1,"engine_version":"4.6.3","meshes":{}}
	var sources: Array[Dictionary] = []
	var report := {"verified":true,"meshes":0,"vertices":0,"packed_channels":0,"native_reimport_verified":false}
	for identity: String in inventory.meshes:
		var entry: Dictionary = inventory.meshes[identity]
		var instance: MeshInstance3D = entry.mesh
		var name := str(instance.name)
		if manifest.meshes.has(name) or not instance.mesh is ArrayMesh: return _fail("Rigid mesh identity is ambiguous or has no actual packed ArrayMesh")
		var mesh := instance.mesh as ArrayMesh
		var raw: Array = mesh.get("_surfaces")
		if raw.size()!=mesh.get_surface_count(): return _fail("Packed surface inventory differs")
		var surfaces: Array = []
		for surface in raw.size():
			var captured := _capture_surface(mesh,surface,raw[surface])
			if not bool(captured.verified): return captured
			surfaces.append(captured)
			report.vertices+=captured.attributes.POSITION.size()
			report.packed_channels+=captured.cells.size()*captured.attributes.POSITION.size()
		manifest.meshes[name]={"identity":identity,"original_path":str(root.get_path_to(instance)),"surfaces":surfaces,"raw_sha256":_raw_signature(mesh)}
		sources.append({"identity":identity,"node":instance,"resource":mesh,"raw_sha256":_raw_signature(mesh),"geometry_sha256":Rigid._geometry_signature(mesh)})
		report.meshes+=1
	return {"verified":true,"manifest":manifest,"report":report,"_root":root,"_sources":sources,"_ids":inventory.all_instance_ids,"_manifest_sha256":JSON.stringify(manifest).sha256_text()}

static func validate_capture(captured: Dictionary) -> Dictionary:
	if not bool(captured.get("verified",false)) or JSON.stringify(captured.get("manifest",{})).sha256_text()!=str(captured.get("_manifest_sha256","")): return _fail("Captured channel manifest mutated")
	if not is_instance_valid(captured.get("_root")): return _fail("Captured source root expired")
	var inventory := Rigid._inventory(captured._root)
	if not bool(inventory.verified) or inventory.all_instance_ids!=captured._ids or inventory.meshes.size()!=captured._sources.size(): return _fail("Captured rigid source inventory changed")
	for source: Dictionary in captured._sources:
		if not is_instance_valid(source.node) or not inventory.meshes.has(source.identity) or inventory.meshes[source.identity].mesh!=source.node or source.node.mesh!=source.resource: return _fail("Captured rigid resource/binding changed")
		if _raw_signature(source.resource)!=str(source.raw_sha256) or Rigid._geometry_signature(source.resource)!=str(source.geometry_sha256): return _fail("Captured source packed geometry changed")
	return {"verified":true}

static func patch(input_path: String, output_path: String, manifest: Dictionary) -> Dictionary:
	if input_path==output_path or FileAccess.file_exists(output_path): return _fail("Channel-corrected carrier must be a new file")
	if manifest.get("schema_version",0)!=1 or manifest.get("engine_version","")!="4.6.3" or not manifest.get("meshes") is Dictionary: return _fail("Invalid original rigid channel manifest")
	var raw := FileAccess.get_file_as_bytes(input_path)
	if raw.size()<28 or raw.decode_u32(0)!=0x46546c67 or raw.decode_u32(4)!=2 or raw.decode_u32(8)!=raw.size(): return _fail("Invalid channel input GLB")
	var json_size := int(raw.decode_u32(12))
	var bin_header := 20+json_size
	if json_size%4!=0 or bin_header+8>raw.size() or raw.decode_u32(16)!=0x4e4f534a or raw.decode_u32(bin_header+4)!=0x004e4942: return _fail("Expected exact JSON/BIN chunks")
	var bin_size := int(raw.decode_u32(bin_header))
	var bin_start := bin_header+8
	if bin_size%4!=0 or bin_start+bin_size!=raw.size(): return _fail("Malformed channel BIN bounds")
	var parsed: Variant = JSON.parse_string(raw.slice(20,bin_header).get_string_from_utf8())
	if not parsed is Dictionary: return _fail("Invalid channel GLTF document")
	var doc: Dictionary = parsed
	var buffers: Array = doc.get("buffers",[])
	if doc.get("asset",{}).get("version","")!="2.0" or buffers.size()!=1 or buffers[0].has("uri") or not Accessors._integer(buffers[0].get("byteLength",-1)): return _fail("Expected one embedded channel buffer")
	var declared := int(buffers[0].byteLength)
	if declared>bin_size or bin_size-declared>3: return _fail("Invalid declared channel buffer bounds")
	var binary := raw.slice(bin_start,bin_start+declared)
	var meshes: Array = doc.get("meshes",[])
	var found: Dictionary = {}
	var edits: Dictionary = {}
	var patched: Dictionary = {}
	var report := {"verified":true,"method":"Exact retained u16 normal/tangent cells; complete original channels, ordered vertices and wound corners; F32 re-packing proof","vertices":0,"vectors":0,"changed_bytes":0,"native_reimport_verified":false,"grip_verified":false,"body_clearance_verified":false}
	for node: Dictionary in doc.get("nodes",[]):
		if not node.has("mesh") or node.has("skin"): continue
		var name := str(node.get("name",""))
		if not manifest.meshes.has(name) or found.has(name) or not Accessors._integer(node.mesh) or int(node.mesh)>=meshes.size(): return _fail("Unexpected or ambiguous rigid node identity: "+name)
		found[name]=true
		var primitives: Array = meshes[int(node.mesh)].get("primitives",[])
		var surfaces: Array = manifest.meshes[name].surfaces
		if primitives.size()!=surfaces.size(): return _fail("Rigid surface inventory changed")
		for surface in surfaces.size():
			var source: Dictionary = surfaces[surface]
			var primitive: Dictionary = primitives[surface]
			if int(primitive.get("mode",4))!=4 or primitive.has("targets"): return _fail("Unsupported rigid primitive/morph")
			var attrs: Dictionary = primitive.get("attributes",{})
			var names: Array = attrs.keys()
			var expected_names: Array = source.attributes.keys()
			names.sort();expected_names.sort()
			if names!=expected_names: return _fail("Complete rigid attribute inventory changed")
			var indices := Accessors._read_accessor(doc,binary,primitive.get("indices",-1),"SCALAR")
			if not bool(indices.verified) or int(indices.component) not in [5121,5123,5125] or indices.rows.size()!=source.indices.size(): return _fail("Rigid wound index inventory changed")
			for index in source.indices.size():
				if int(indices.rows[index][0])!=int(source.indices[index]): return _fail("Rigid wound corner/vertex order changed")
			for channel: String in names:
				if not KINDS.has(channel): return _fail("Unsupported rigid attribute semantic")
				var accessor := Accessors._read_accessor(doc,binary,attrs[channel],KINDS[channel],5126)
				if not bool(accessor.verified): return accessor
				var original: Array = source.attributes[channel]
				if accessor.rows.size()!=original.size(): return _fail("Rigid channel vertex count changed")
				var is_patched := channel in ["NORMAL","TANGENT"]
				if is_patched:
					if patched.has(int(attrs[channel])): return _fail("Shared rigid channel accessor is ambiguous")
					patched[int(attrs[channel])]=accessor
				for vertex in original.size():
					var expected: Array = original[vertex].duplicate()
					for value: Variant in expected:
						if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)): return _fail("Invalid retained channel manifest value")
					if channel=="NORMAL":
						var normal := Vector3(float(expected[0]),float(expected[1]),float(expected[2])).normalized()
						expected=[normal.x,normal.y,normal.z]
					if accessor.rows[vertex]!=expected: return _fail("Raw rigid channel is not the exact pinned export of source",{"mesh":name,"surface":surface,"channel":channel,"vertex":vertex})
					if not is_patched: continue
					if not source.cells.has(channel) or source.cells[channel].size()!=original.size(): return _fail("Original packed channel inventory missing")
					var q: Array = []
					for value: Variant in source.cells[channel][vertex]:
						if not Accessors._integer(value) or int(value)>65535: return _fail("Invalid exact original packed channel cell")
						q.append(int(value))
					var encoded := encode_q(q,channel=="TANGENT")
					if not bool(encoded.verified): return encoded
					if decode_q(q,channel=="TANGENT")!=original[vertex]: return _fail("Original packed cells/readback identity differs")
					for axis in encoded.encoded.size():
						var at: int = int(accessor.start)+vertex*int(accessor.stride)+axis*4
						if edits.has(at): return _fail("Overlapping rigid channel edit")
						edits[at]=float(encoded.encoded[axis])
					report.vectors+=1
			report.vertices+=source.attributes.POSITION.size()
	if found.size()!=manifest.meshes.size(): return _fail("Captured rigid inventory is incomplete")
	# Conservative bounding intervals also reject semantic aliasing in an
	# interleaved view; an unsupported layout must not silently modify skin/UVs.
	for index in doc.get("accessors",[]).size():
		var descriptor := Accessors._descriptor(doc,index,declared)
		if not bool(descriptor.verified): return descriptor
		for patch_index: int in patched:
			if index==patch_index: continue
			var other: Dictionary = patched[patch_index]
			if int(descriptor.start)<int(other.end) and int(other.start)<int(descriptor.end): return _fail("Rigid patch bytes overlap another accessor")
	var output := raw.duplicate()
	for at: int in edits:
		output.encode_float(bin_start+at,float(edits[at]))
		for byte in 4:
			if output[bin_start+at+byte]!=raw[bin_start+at+byte]: report.changed_bytes+=1
	if FileAccess.get_file_as_bytes(input_path)!=raw or FileAccess.file_exists(output_path): return _fail("Channel source/output changed during proof")
	var file := FileAccess.open(output_path,FileAccess.WRITE)
	if file==null: return _fail("Cannot create new channel-corrected carrier")
	file.store_buffer(output);file.close()
	if FileAccess.get_file_as_bytes(output_path)!=output: return _fail("Channel output did not retain proved bytes")
	report.merge({"input_sha256":FileAccess.get_sha256(input_path),"corrected_sha256":FileAccess.get_sha256(output_path),"manifest_sha256":JSON.stringify(manifest).sha256_text(),"only_existing_normal_tangent_bytes_changed":true,"rigid_meshes":found.size()})
	return report
