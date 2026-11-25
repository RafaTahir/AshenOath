extends SceneTree
## Bake the equipped variant against the prepared M04. All four mesh LODs use
## the original vertex, material-slot, skin and normal layout. Only indices change.

const SOURCE := "res://assets_external/characters_prepared/monsters/5da1537a47b82ffbd14adf0d.scn"
const OUTPUT := "res://assets/characters/gravebound_reaped_armour.res"
const SWORD := AABB(Vector3(-0.72, 1.4, -0.23), Vector3(0.05, 0.176, 1.085))

func _initialize() -> void:
	var source: Node = load(SOURCE).instantiate()
	var part := source.find_child("M04_FittedArmourAssembly", true, false) as MeshInstance3D
	var ok := part != null and bake(part)
	source.free()
	quit(0 if ok else 1)

func bake(part: MeshInstance3D) -> bool:
	var mesh := part.mesh as ArrayMesh
	if mesh.get_surface_count() != 2 or mesh.surface_get_name(0) != "M04_PittedIron" or mesh.surface_get_name(1) != "M04_FuneraryLinen":
		return false
	var surface := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = surface[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = surface[Mesh.ARRAY_WEIGHTS]
	var blade := PackedByteArray()
	blade.resize(verts.size())
	var stride := bones.size() / verts.size()
	for i in verts.size():
		var first := i * stride
		if SWORD.has_point(verts[i]) and part.skin.get_bind_name(bones[first]) == &"hand_r" and weights[first] > 0.999:
			blade[i] = 1
	if blade.count(1) != 1121:
		push_error("Expected exactly the connected sword island in the retained mesh, got %d vertices" % blade.count(1))
		return false
	var surfaces: Array = mesh.get("_surfaces").duplicate(true)
	var iron: Dictionary = surfaces[0]
	if iron.vertex_count > 65535 or iron.index_data.size() != 2 * int(iron.index_count):
		return false
	var stripped := strip_faces(iron.index_data, blade)
	if stripped.is_empty() or iron.index_data.size() - stripped.size() != 532 * 6:
		push_error("Embedded sword topology changed")
		return false
	iron.index_data = stripped
	iron.index_count = stripped.size() / 2
	for i in range(1, iron.lods.size(), 2):
		var lod := strip_faces(iron.lods[i], blade)
		if lod.is_empty() or lod.size() == iron.lods[i].size(): return false
		iron.lods[i] = lod
	for record: Dictionary in surfaces:
		record.erase("material")
	var armour := ArrayMesh.new()
	armour.set("_surfaces", surfaces)
	armour.resource_name = "Gravebound armour with free sword hand"
	return ResourceSaver.save(armour, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK

func strip_faces(indices: PackedByteArray, blade: PackedByteArray) -> PackedByteArray:
	var kept := PackedByteArray()
	for base in range(0, indices.size(), 6):
		var a := blade[indices.decode_u16(base)]
		var b := blade[indices.decode_u16(base + 2)]
		var c := blade[indices.decode_u16(base + 4)]
		if a != b or b != c:
			push_error("Sword shares a triangle with retained armour")
			return PackedByteArray()
		if a == 0:
			kept.append_array(indices.slice(base, base + 6))
	return kept
