extends RefCounted

## Authoring-only rigid geometry proof on disposable scenes. Triangle matching
## keeps complete channel/corner multiplicity and winding; it is not proximity.
## BoneAttachment3D.on_skeleton_update is public in pinned4.6.3 (cpp:366).
const POSITION_TOLERANCE := 0.0001
const FRAME_TOLERANCE := 0.0001
const LOCAL_TOLERANCE := 0.00001
const KEY_QUANTUM := 0.000001

static func _failure(message: String, detail: Dictionary = {}) -> Dictionary:
	return {"verified":false,"error":message,"detail":detail}

static func _point(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

static func finite_pose_sample(expected: Transform3D, actual: Transform3D, telemetry: Vector3 = Vector3.ZERO) -> bool:
	return expected.is_finite() and actual.is_finite() and telemetry.is_finite()

static func inventory_completeness(expected_paths: Array[String], skin_report: Dictionary, rigid_report: Dictionary) -> Dictionary:
	var expected := expected_paths.duplicate()
	var proved: Array[String] = []
	for report: Dictionary in [skin_report,rigid_report]:
		if not bool(report.get("verified",false)): return _failure("Visible inventory requires both geometry proofs")
		for mesh: Dictionary in report.get("meshes",[]):
			var path := str(mesh.get("original_path",""))
			if path.is_empty() or proved.has(path): return _failure("Visible geometry proof has an absent or duplicate mesh identity")
			proved.append(path)
	expected.sort();proved.sort()
	if expected.is_empty() or expected!=proved: return _failure("Retained-visible geometry is not completely covered",{"expected":expected,"proved":proved})
	return {"verified":true,"expected_paths":expected,"proved_paths":proved,"mesh_count":proved.size()}

static func _frame_error(a: Transform3D, b: Transform3D) -> float:
	if not a.is_finite() or not b.is_finite(): return INF
	var error := a.origin.distance_to(b.origin)
	for axis in 3: error=maxf(error,(a.basis[axis]-b.basis[axis]).length())
	return error

static func refresh_attachments(root: Node) -> Dictionary:
	var count := 0
	for node: Node in root.find_children("*","BoneAttachment3D",true,false):
		var socket := node as BoneAttachment3D
		var rig: Skeleton3D = socket.get_skeleton()
		if socket.override_pose or rig==null or socket.bone_idx<0 or socket.bone_idx>=rig.get_bone_count():
			return _failure("Cannot refresh an unresolved or overriding attachment: "+str(socket.name))
		# force_update_all_bone_transforms emits pose_updated, not the
		# skeleton_updated signal which normally updates attachments per frame.
		socket.on_skeleton_update()
		count+=1
	return {"verified":true,"attachments_refreshed":count}

static func _binding(mesh: MeshInstance3D, root: Node3D) -> Dictionary:
	var cursor: Node = mesh
	var local := Transform3D.IDENTITY
	var names: Array[String] = []
	while cursor!=root and cursor!=null and not cursor is BoneAttachment3D:
		if not cursor is Node3D: return _failure("Rigid geometry has a nonspatial ancestor")
		var spatial := cursor as Node3D
		if not spatial.transform.is_finite() or absf(spatial.transform.basis.determinant())<0.0000001:
			return _failure("Rigid geometry has an invalid local frame")
		local=spatial.transform*local
		names.push_front(str(spatial.name))
		cursor=cursor.get_parent()
	if cursor==null: return _failure("Rigid geometry is outside its retained scene")
	if cursor is BoneAttachment3D:
		var socket := cursor as BoneAttachment3D
		var rig: Skeleton3D = socket.get_skeleton()
		if socket.override_pose or rig==null or socket.bone_idx<0 or socket.bone_idx>=rig.get_bone_count():
			return _failure("Rigid prop has an unresolved or overriding bone attachment")
		if not root.is_ancestor_of(rig) and root!=rig: return _failure("Rigid attachment binds outside the retained scene")
		var bone := socket.bone_idx
		var lineage: Array[String] = []
		var ancestor := bone
		while ancestor>=0:
			lineage.push_front(str(rig.get_bone_name(ancestor)))
			ancestor=rig.get_bone_parent(ancestor)
		var label := "bone:"+"/".join(lineage)+"::"+"/".join(names)
		return {"verified":true,"identity":label,"kind":"bone","bone":bone,"bone_name":str(rig.get_bone_name(bone)),"rig":rig,"socket":socket,"local":local,"rest":rig.get_bone_global_rest(bone),"root":root}
	return {"verified":true,"identity":"scene::"+"/".join(names),"kind":"scene","local":local,"root":root}

static func _inventory(root: Node3D) -> Dictionary:
	if not is_instance_valid(root) or not root.global_transform.is_finite(): return _failure("Rigid scene root has a nonfinite actual global frame")
	var found: Dictionary = {}
	var all_instance_ids: Array[int] = []
	var nodes: Array[Node] = root.find_children("*","MeshInstance3D",true,false)
	if root is MeshInstance3D: nodes.push_front(root)
	for node: Node in nodes:
		var mesh := node as MeshInstance3D
		all_instance_ids.append(mesh.get_instance_id())
		if mesh.mesh==null: return _failure("Retained rigid inventory contains an empty mesh")
		var weighted := false
		var rigid := false
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var has_bones: bool = arrays[Mesh.ARRAY_BONES]!=null and arrays[Mesh.ARRAY_BONES].size()>0
			weighted=weighted or has_bones
			rigid=rigid or not has_bones
		if weighted and rigid: return _failure("Mixed rigid/weighted surfaces need an explicit separate proof: "+str(mesh.name))
		if weighted: continue
		if mesh.mesh.get_surface_count()==0 or mesh.mesh.get_blend_shape_count()!=0:
			return _failure("Rigid prop has no surfaces or unproved morph deformation: "+str(mesh.name))
		var binding := _binding(mesh,root)
		if not bool(binding.verified): return binding
		var identity := str(binding.identity)
		if found.has(identity): return _failure("Ambiguous rigid mesh/binding identity: "+identity)
		found[identity]={"mesh":mesh,"binding":binding}
	all_instance_ids.sort()
	return {"verified":true,"meshes":found,"all_instance_ids":all_instance_ids}

static func _geometry_signature(mesh: Mesh) -> String:
	var arrays: Array = [mesh.get_blend_shape_count()]
	for surface in mesh.get_surface_count():
		arrays.append([mesh.surface_get_primitive_type(surface),mesh.surface_get_arrays(surface)])
	return var_to_bytes(arrays).hex_encode().sha256_text()

static func _numbers(value: Variant) -> Array:
	match typeof(value):
		TYPE_FLOAT,TYPE_INT: return [float(value)]
		TYPE_VECTOR2: return [value.x,value.y]
		TYPE_VECTOR3: return [value.x,value.y,value.z]
		TYPE_COLOR: return [value.r,value.g,value.b,value.a]
	return []

static func _surface(mesh: MeshInstance3D, surface: int) -> Dictionary:
	if mesh.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:
		return _failure("Rigid carrier surface is not triangles")
	var arrays := mesh.mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty(): return _failure("Rigid carrier surface has no vertices")
	var channels: Array[int] = []
	var strides: Dictionary = {}
	for channel in range(Mesh.ARRAY_VERTEX,Mesh.ARRAY_INDEX):
		if arrays[channel]==null or arrays[channel].size()==0: continue
		if channel in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]: return _failure("Rigid surface unexpectedly contains skin arrays")
		if channel in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:
			return _failure("Rigid custom channels require an explicit transport contract")
		var stride := 4 if channel==Mesh.ARRAY_TANGENT else 1
		if arrays[channel].size()!=vertices.size()*stride: return _failure("Malformed rigid vertex channel: "+str(channel))
		channels.append(channel)
		strides[channel]=stride
	var keys: Array[String] = []
	var vertex_counts: Dictionary = {}
	for vertex in vertices.size():
		var tokens: Array[String] = []
		for channel: int in channels:
			tokens.append(str(channel))
			for offset in int(strides[channel]):
				var numbers := _numbers(arrays[channel][vertex*int(strides[channel])+offset])
				if numbers.is_empty(): return _failure("Unsupported rigid channel storage")
				for value: float in numbers:
					if not is_finite(value): return _failure("Nonfinite rigid vertex channel")
					tokens.append(str(roundi(value/KEY_QUANTUM)))
		var key := ",".join(tokens)
		keys.append(key)
		vertex_counts[key]=int(vertex_counts.get(key,0))+1
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	if indices.is_empty():
		indices.resize(vertices.size())
		for index in vertices.size(): indices[index]=index
	if indices.size()%3!=0: return _failure("Malformed rigid triangle indices")
	var triangles: Dictionary = {}
	for start in range(0,indices.size(),3):
		var corners: Array[int] = [indices[start],indices[start+1],indices[start+2]]
		for index: int in corners:
			if index<0 or index>=vertices.size(): return _failure("Rigid triangle references an absent vertex")
		var signature := ""
		var best: Array[int] = []
		for rotation in 3:
			var rotated: Array[int] = [corners[rotation],corners[(rotation+1)%3],corners[(rotation+2)%3]]
			var candidate := keys[rotated[0]]+";"+keys[rotated[1]]+";"+keys[rotated[2]]
			if best.is_empty() or candidate<signature:
				signature=candidate
				best=rotated
		if not triangles.has(signature): triangles[signature]=[]
		triangles[signature].append(best)
	return {"verified":true,"vertices":vertices,"vertex_counts":vertex_counts,"triangles":triangles,"channels":channels,"triangle_count":indices.size()/3}

static func prepare(original_root: Node3D, imported_root: Node3D) -> Dictionary:
	var original := _inventory(original_root)
	var imported := _inventory(imported_root)
	if not bool(original.verified): return original
	if not bool(imported.verified): return imported
	var names: Array = original.meshes.keys()
	var other: Array = imported.meshes.keys()
	names.sort();other.sort()
	if names!=other: return _failure("Rigid mesh/ancestor/bone inventory changed",{"original":names,"imported":other})
	var pairs: Array[Dictionary] = []
	var report := {"verified":true,"method":"Complete vertex-channel and cyclic wound-triangle multiplicity; named binding/local frames; refreshed actual world corners","position_tolerance_m":POSITION_TOLERANCE,"frame_tolerance":FRAME_TOLERANCE,"meshes":[],"vertices_checked":0,"triangles_checked":0}
	for name: String in names:
		var first: Dictionary = original.meshes[name]
		var second: Dictionary = imported.meshes[name]
		var a: MeshInstance3D = first.mesh
		var b: MeshInstance3D = second.mesh
		first["resource"]=a.mesh
		second["resource"]=b.mesh
		first["geometry_sha256"]=_geometry_signature(a.mesh)
		second["geometry_sha256"]=_geometry_signature(b.mesh)
		if _frame_error(first.binding.local,second.binding.local)>LOCAL_TOLERANCE:
			return _failure("Rigid attachment-local frame changed: "+name)
		if str(first.binding.kind)=="bone" and _frame_error(first.binding.rest,second.binding.rest)>LOCAL_TOLERANCE:
			return _failure("Rigid bound bone rest changed: "+name)
		if a.mesh.get_surface_count()!=b.mesh.get_surface_count(): return _failure("Rigid surface inventory changed: "+name)
		var surfaces: Array[Dictionary] = []
		for surface in a.mesh.get_surface_count():
			var left := _surface(a,surface)
			var right := _surface(b,surface)
			if not bool(left.verified): return left
			if not bool(right.verified): return right
			if left.channels!=right.channels or left.vertex_counts!=right.vertex_counts:
				return _failure("Rigid vertex/channel multiplicity changed: "+name+"/"+str(surface))
			var signatures: Array = left.triangles.keys()
			var other_signatures: Array = right.triangles.keys()
			signatures.sort();other_signatures.sort()
			if signatures!=other_signatures: return _failure("Rigid wound triangle/channel inventory changed: "+name+"/"+str(surface))
			var points_a := PackedVector3Array()
			var points_b := PackedVector3Array()
			for signature: String in signatures:
				var from_triangles: Array = left.triangles[signature]
				var to_triangles: Array = right.triangles[signature]
				if from_triangles.size()!=to_triangles.size(): return _failure("Rigid wound triangle multiplicity changed: "+name)
				for triangle in from_triangles.size():
					for corner in 3:
						points_a.append(left.vertices[int(from_triangles[triangle][corner])])
						points_b.append(right.vertices[int(to_triangles[triangle][corner])])
			surfaces.append({"surface":surface,"a":points_a,"b":points_b})
			report.vertices_checked+=left.vertices.size()
			report.triangles_checked+=int(left.triangle_count)
		pairs.append({"identity":name,"a":first,"b":second,"surfaces":surfaces})
		report.meshes.append({"identity":name,"original_path":str(original_root.get_path_to(a)),"imported_path":str(imported_root.get_path_to(b)),"surfaces":surfaces.size(),"binding":str(first.binding.kind),"bone":first.binding.get("bone_name","")})
	return {"verified":true,"report":report,"_pairs":pairs,"_original_root":original_root,"_imported_root":imported_root,"_original_ids":original.all_instance_ids,"_imported_ids":imported.all_instance_ids}

static func _expected_frame(binding: Dictionary) -> Transform3D:
	if str(binding.kind)=="bone":
		var rig: Skeleton3D = binding.rig
		return rig.global_transform*rig.get_bone_global_pose(int(binding.bone))*binding.local
	var scene: Node3D = binding.root
	return scene.global_transform*binding.local

static func sample(prepared: Dictionary) -> Dictionary:
	if not bool(prepared.get("verified",false)) or not prepared.has("_pairs"): return _failure("Rigid equivalence was not prepared")
	for side: String in ["original","imported"]:
		var scene: Node3D = prepared["_"+side+"_root"]
		var current := _inventory(scene)
		if not bool(current.verified): return current
		if current.all_instance_ids!=prepared["_"+side+"_ids"]: return _failure("Retained mesh instance inventory changed after rigid preparation")
	var result := {"verified":true,"corners_sampled":0,"maximum_world_vertex_error_m":0.0,"maximum_frame_error":0.0,"position_tolerance_m":POSITION_TOLERANCE,"worst":{}}
	for pair: Dictionary in prepared._pairs:
		var a: MeshInstance3D = pair.a.mesh
		var b: MeshInstance3D = pair.b.mesh
		if not is_instance_valid(a) or not is_instance_valid(b): return _failure("Rigid geometry disappeared during sampling")
		for entry: Dictionary in [pair.a,pair.b]:
			var mesh: MeshInstance3D = entry.mesh
			if mesh.mesh!=entry.resource or _geometry_signature(mesh.mesh)!=str(entry.geometry_sha256):
				return _failure("Rigid mesh resource or exact surface arrays changed during sampling")
			var binding := _binding(mesh,entry.binding.root)
			if not bool(binding.verified) or str(binding.identity)!=str(entry.binding.identity): return _failure("Rigid binding changed during sampling")
			var frame_error := _frame_error(mesh.global_transform,_expected_frame(entry.binding))
			result.maximum_frame_error=maxf(float(result.maximum_frame_error),frame_error)
			if frame_error>FRAME_TOLERANCE: return _failure("Rigid actual attachment frame is stale or changed",{"identity":pair.identity,"actual_frame_error":frame_error})
		var pair_frame_error := _frame_error(a.global_transform,b.global_transform)
		result.maximum_frame_error=maxf(float(result.maximum_frame_error),pair_frame_error)
		if pair_frame_error>FRAME_TOLERANCE: return _failure("Rigid actual world frame differs",{"identity":pair.identity,"actual_frame_error":pair_frame_error})
		for surface: Dictionary in pair.surfaces:
			for corner in surface.a.size():
				var expected: Vector3 = a.global_transform*surface.a[corner]
				var actual: Vector3 = b.global_transform*surface.b[corner]
				if not expected.is_finite() or not actual.is_finite(): return _failure("Rigid sampled world corner is nonfinite")
				var error := expected.distance_to(actual)
				if error>float(result.maximum_world_vertex_error_m):
					result.maximum_world_vertex_error_m=error
					result.worst={"identity":pair.identity,"surface":surface.surface,"corner":corner,"original":_point(expected),"imported":_point(actual)}
				result.corners_sampled+=1
	result.verified=float(result.maximum_world_vertex_error_m)<=POSITION_TOLERANCE
	if not bool(result.verified): result["error"]="Actual rigid world geometry differs after import"
	return result
