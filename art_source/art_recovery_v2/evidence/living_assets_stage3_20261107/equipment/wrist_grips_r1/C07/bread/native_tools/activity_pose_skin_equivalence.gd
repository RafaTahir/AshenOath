extends RefCounted

## Authoring-only proof. No original/imported nodes or resources are mutated.
## Godot 4.6.3 Skeleton3D uploads global_pose * Skin.bind_pose (cpp line 402).
## The renderer applies weighted skin matrices in mesh-local coordinates.
const POSITION_TOLERANCE := 0.0001
const REST_TOLERANCE := 0.00001
const KEY_QUANTUM := 0.000001
const WEIGHT_TOLERANCE := 0.000001

static func _failure(message: String, detail: Dictionary = {}) -> Dictionary:
	return {"verified":false,"error":message,"detail":detail}

static func _point(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

static func _triangle_difference(first: Dictionary, second: Dictionary) -> Dictionary:
	for signature: String in first:
		if int(first[signature])!=int(second.get(signature,0)):
			return {"signature":signature,"original_multiplicity":first[signature],"imported_multiplicity":second.get(signature,0)}
	for signature: String in second:
		if not first.has(signature): return {"signature":signature,"original_multiplicity":0,"imported_multiplicity":second[signature]}
	return {}

static func _matrix_error(first: Transform3D, second: Transform3D) -> float:
	var value := first.origin.distance_to(second.origin)
	for axis in 3: value=maxf(value,(first.basis[axis]-second.basis[axis]).length())
	return value

static func _weighted_meshes(root: Node) -> Dictionary:
	var found: Dictionary = {}
	var nodes: Array[Node] = root.find_children("*","MeshInstance3D",true,false)
	if root is MeshInstance3D: nodes.push_front(root)
	for node: Node in nodes:
		var instance := node as MeshInstance3D
		if instance.mesh==null: return _failure("Visible retained mesh is null: "+str(instance.name))
		var weighted := false
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			weighted=weighted or (arrays[Mesh.ARRAY_BONES]!=null and arrays[Mesh.ARRAY_BONES].size()>0)
		if not weighted: continue
		var identity := str(instance.name)
		if found.has(identity): return _failure("Ambiguous skinned mesh identity: "+identity)
		if instance.skin==null: return _failure("Weighted mesh lacks an explicit retained Skin: "+identity)
		if instance.mesh.get_blend_shape_count()!=0:
			return _failure("Activity skin proof requires separate morph calibration: "+identity)
		var skeleton := instance.get_node_or_null(instance.skeleton) as Skeleton3D
		if skeleton==null: return _failure("Weighted mesh skeleton cannot resolve: "+identity)
		found[identity]={"mesh":instance,"skeleton":skeleton}
	return {"verified":true,"meshes":found}

static func _bindings(pair: Dictionary) -> Dictionary:
	var instance: MeshInstance3D = pair.mesh
	var skeleton: Skeleton3D = pair.skeleton
	var rows: Array[Dictionary] = []
	var names: Dictionary = {}
	for index in instance.skin.get_bind_count():
		var name := str(instance.skin.get_bind_name(index))
		var bone := skeleton.find_bone(name) if not name.is_empty() else instance.skin.get_bind_bone(index)
		if bone<0 or bone>=skeleton.get_bone_count(): return _failure("Unresolved retained skin bind: "+str(instance.name))
		name=str(skeleton.get_bone_name(bone))
		if names.has(name): return _failure("Duplicate named skin bind: "+name)
		var pose := instance.skin.get_bind_pose(index)
		if not pose.is_finite() or absf(pose.basis.determinant())<0.0000001: return _failure("Invalid skin inverse-bind frame: "+name)
		names[name]=index
		rows.append({"name":name,"bone":bone,"pose":pose})
	return {"verified":true,"rows":rows,"names":names}

static func _q(value: float) -> int:
	return roundi(value/KEY_QUANTUM)

static func _surface(instance: MeshInstance3D, index: int, bindings: Dictionary) -> Dictionary:
	if instance.mesh.surface_get_primitive_type(index)!=Mesh.PRIMITIVE_TRIANGLES:
		return _failure("Activity carrier has a non-triangle surface")
	var arrays := instance.mesh.surface_get_arrays(index)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if vertices.is_empty() or bones.size()!=weights.size() or bones.size()%vertices.size()!=0:
		return _failure("Malformed retained skin arrays")
	var stride := bones.size()/vertices.size()
	if stride not in [4,8]: return _failure("Unsupported retained influence count")
	var rows: Array[Dictionary] = []
	var keys: Array[String] = []
	var unique: Dictionary = {}
	var representative: Dictionary = {}
	var strongest: Dictionary = {}
	var extrema: Array[int] = [0,0,0,0,0,0]
	for vertex in vertices.size():
		var point := vertices[vertex]
		if not point.is_finite(): return _failure("Nonfinite retained vertex")
		var influences: Dictionary = {}
		var quantized_sum := 0
		for offset in stride:
			var slot := vertex*stride+offset
			var weight := float(weights[slot])
			if not is_finite(weight) or weight<0.0: return _failure("Invalid retained skin weight")
			var quantized := roundi(weight*65535.0)
			if quantized<0 or quantized>65535 or PackedFloat32Array([float(quantized)/65535.0])[0]!=weight:
				return _failure("Retained skin weight is not an exact uint16 readback")
			quantized_sum+=quantized
			if weight==0.0: continue
			var bind := int(bones[slot])
			if bind<0 or bind>=bindings.rows.size(): return _failure("Skin influence references an absent bind")
			var name := str(bindings.rows[bind].name)
			influences[name]=float(influences.get(name,0.0))+weight
			if not strongest.has(name) or weight>float(strongest[name].weight): strongest[name]={"weight":weight,"vertex":vertex}
		if 65535-quantized_sum<0 or 65535-quantized_sum>=stride:
			return _failure("Retained skin weights have no normalized quantization-cell representation")
		var labels: Array = influences.keys()
		labels.sort()
		var tokens: Array[String] = [str(_q(point.x)),str(_q(point.y)),str(_q(point.z))]
		for name: String in labels: tokens.append(name+":"+str(_q(float(influences[name]))))
		var key := "|".join(tokens)
		rows.append({"point":point,"influences":influences})
		keys.append(key)
		if not unique.has(key): unique[key]=vertex
		for axis in 3:
			if point[axis]<vertices[extrema[axis*2]][axis]: extrema[axis*2]=vertex
			if point[axis]>vertices[extrema[axis*2+1]][axis]: extrema[axis*2+1]=vertex
	for index_value in 65: representative[roundi(float(vertices.size()-1)*float(index_value)/64.0)]=true
	for index_value: int in extrema: representative[index_value]=true
	for item: Dictionary in strongest.values(): representative[int(item.vertex)]=true
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	if indices.is_empty():
		indices.resize(vertices.size())
		for vertex in vertices.size(): indices[vertex]=vertex
	if indices.size()%3!=0: return _failure("Malformed retained triangle index array")
	var triangles: Dictionary = {}
	for first in range(0,indices.size(),3):
		var corners: Array[String] = []
		for offset in 3:
			var vertex := int(indices[first+offset])
			if vertex<0 or vertex>=keys.size(): return _failure("Triangle references absent vertex")
			corners.append(keys[vertex])
		# Canonical cyclic ordering preserves winding and triangle multiplicity.
		var rotations: Array[String] = [corners[0]+";"+corners[1]+";"+corners[2],corners[1]+";"+corners[2]+";"+corners[0],corners[2]+";"+corners[0]+";"+corners[1]]
		rotations.sort()
		var triangle := rotations[0]
		triangles[triangle]=int(triangles.get(triangle,0))+1
	return {"verified":true,"rows":rows,"keys":keys,"unique":unique,"triangles":triangles,"representative":representative.keys(),"triangle_count":indices.size()/3}

static func prepare(original_root: Node, imported_root: Node) -> Dictionary:
	var original := _weighted_meshes(original_root)
	var imported := _weighted_meshes(imported_root)
	if not original.verified: return original
	if not imported.verified: return imported
	var names: Array = original.meshes.keys()
	var candidate_names: Array = imported.meshes.keys()
	names.sort();candidate_names.sort()
	if names.is_empty() or names!=candidate_names: return _failure("Skinned body/garment mesh identities changed")
	var pairs: Array[Dictionary] = []
	var report := {"verified":true,"method":"All rest vertices, named skin bindings, weights and wound triangle multiplicity; bounded representative world skin samples after actual native evaluation","position_tolerance_m":POSITION_TOLERANCE,"meshes":[],"vertices_checked":0,"triangles_checked":0,"representative_vertices":0}
	for name: String in names:
		var first: Dictionary = original.meshes[name]
		var second: Dictionary = imported.meshes[name]
		var a: MeshInstance3D = first.mesh
		var b: MeshInstance3D = second.mesh
		var binds_a := _bindings(first)
		var binds_b := _bindings(second)
		if not binds_a.verified: return binds_a
		if not binds_b.verified: return binds_b
		if a.mesh.get_surface_count()!=b.mesh.get_surface_count(): return _failure("Skinned mesh surface inventory changed: "+name)
		var bind_names: Array = binds_a.names.keys()
		var other_names: Array = binds_b.names.keys()
		bind_names.sort();other_names.sort()
		if bind_names!=other_names: return _failure("Named skin binding inventory changed: "+name)
		for bone_name: String in bind_names:
			var ba: Dictionary = binds_a.rows[int(binds_a.names[bone_name])]
			var bb: Dictionary = binds_b.rows[int(binds_b.names[bone_name])]
			var bind_error := _matrix_error(ba.pose,bb.pose)
			if bind_error>REST_TOLERANCE: return _failure("Skin inverse-bind changed: "+name+"/"+bone_name,{"maximum_matrix_component_error":bind_error,"tolerance":REST_TOLERANCE,"original_origin":_point(ba.pose.origin),"imported_origin":_point(bb.pose.origin)})
			var sa: Skeleton3D = first.skeleton
			var sb: Skeleton3D = second.skeleton
			var rest_error := _matrix_error(sa.get_bone_global_rest(int(ba.bone)),sb.get_bone_global_rest(int(bb.bone)))
			if rest_error>REST_TOLERANCE:
				return _failure("Bound bone rest changed: "+name+"/"+bone_name,{"maximum_matrix_component_error":rest_error,"tolerance":REST_TOLERANCE,"original_bone":ba.bone,"imported_bone":bb.bone})
		var surfaces: Array[Dictionary] = []
		var vertex_count := 0
		var triangle_count := 0
		var sample_count := 0
		for surface in a.mesh.get_surface_count():
			var data_a := _surface(a,surface,binds_a)
			var data_b := _surface(b,surface,binds_b)
			if not data_a.verified: return data_a
			if not data_b.verified: return data_b
			if data_a.triangles!=data_b.triangles: return _failure("Rest geometry/weights/wound triangle multiplicity changed: "+name+"/"+str(surface),_triangle_difference(data_a.triangles,data_b.triangles))
			if data_a.unique.size()!=data_b.unique.size(): return _failure("Rest skin vertex set changed: "+name,{"original_unique_vertices":data_a.unique.size(),"imported_unique_vertices":data_b.unique.size()})
			var samples: Array[Dictionary] = []
			for vertex in data_a.rows.size():
				var key := str(data_a["keys"][vertex])
				if not data_b.unique.has(key): return _failure("Imported rest vertex/weight is absent: "+name,{"original_vertex":vertex,"signature":key})
				var target := int(data_b.unique[key])
				var va: Dictionary = data_a.rows[vertex]
				var vb: Dictionary = data_b.rows[target]
				if va.point.distance_to(vb.point)>REST_TOLERANCE: return _failure("Rest vertex moved: "+name,{"original_vertex":vertex,"imported_vertex":target,"distance_m":va.point.distance_to(vb.point),"original":_point(va.point),"imported":_point(vb.point)})
				for joint: String in va.influences:
					if absf(float(va.influences[joint])-float(vb.influences.get(joint,-1.0)))>WEIGHT_TOLERANCE: return _failure("Named vertex weight changed: "+name,{"original_vertex":vertex,"imported_vertex":target,"bone":joint,"original_weight":va.influences[joint],"imported_weight":vb.influences.get(joint,-1.0)})
				if vertex in data_a.representative: samples.append({"a":va,"b":vb,"original_vertex":vertex,"imported_vertex":target})
			surfaces.append({"surface":surface,"samples":samples})
			vertex_count+=data_a.rows.size()
			triangle_count+=int(data_a.triangle_count)
			sample_count+=samples.size()
		pairs.append({"a":first,"b":second,"binds_a":binds_a,"binds_b":binds_b,"surfaces":surfaces})
		report.meshes.append({"name":name,"original_path":str(original_root.get_path_to(a)),"imported_path":str(imported_root.get_path_to(b)),"named_binds":bind_names.size(),"vertices":vertex_count,"triangles":triangle_count,"sample_vertices":sample_count})
		report.vertices_checked+=vertex_count
		report.triangles_checked+=triangle_count
		report.representative_vertices+=sample_count
	return {"verified":true,"report":report,"_pairs":pairs}

static func _frames(entry: Dictionary, bindings: Dictionary) -> Dictionary:
	var skeleton: Skeleton3D = entry.skeleton
	var result: Dictionary = {}
	for binding: Dictionary in bindings.rows:
		result[str(binding.name)]=skeleton.get_bone_global_pose(int(binding.bone))*binding.pose
	return result

static func _skin(vertex: Dictionary, frames: Dictionary, world: Transform3D) -> Vector3:
	var local := Vector3.ZERO
	for name: String in vertex.influences:
		local+=(frames[name]*vertex.point)*float(vertex.influences[name])
	return world*local

static func sample(prepared: Dictionary, include_original_probes: bool = false) -> Dictionary:
	if not bool(prepared.get("verified",false)) or not prepared.has("_pairs"): return _failure("Skin equivalence was not prepared")
	var result := {"verified":true,"vertices_sampled":0,"maximum_world_vertex_error_m":0.0,"position_tolerance_m":POSITION_TOLERANCE,"worst":{}}
	if include_original_probes:
		result["original_world_probes"]=[]
		result["probe_frame"]="Godot Y-up world metres in the retained identity placement wrapper"
	for pair: Dictionary in prepared._pairs:
		var a: MeshInstance3D = pair.a.mesh
		var b: MeshInstance3D = pair.b.mesh
		if not is_instance_valid(a) or not is_instance_valid(b): return _failure("Prepared skin instance was freed")
		var frames_a := _frames(pair.a,pair.binds_a)
		var frames_b := _frames(pair.b,pair.binds_b)
		for surface: Dictionary in pair.surfaces:
			for item: Dictionary in surface.samples:
				var first := _skin(item.a,frames_a,a.global_transform)
				var second := _skin(item.b,frames_b,b.global_transform)
				if not first.is_finite() or not second.is_finite(): return _failure("Actual skinned vertex became nonfinite")
				if include_original_probes:
					result.original_world_probes.append({"mesh":str(a.name),"surface":surface.surface,"vertex":item.original_vertex,"retained_rest_point":_point(item.a.point),"world_point":_point(first)})
				var error := first.distance_to(second)
				result.vertices_sampled+=1
				if error>float(result.maximum_world_vertex_error_m):
					result.maximum_world_vertex_error_m=error
					result.worst={"mesh":str(a.name),"surface":surface.surface,"original_vertex":item.original_vertex,"imported_vertex":item.imported_vertex,"original":[first.x,first.y,first.z],"imported":[second.x,second.y,second.z]}
	if float(result.maximum_world_vertex_error_m)>POSITION_TOLERANCE:
		result.verified=false
		result.error="World skinned vertex differs from actual runtime by more than 0.1 mm"
	return result
