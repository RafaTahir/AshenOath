extends RefCounted

const WOOD := Color(0.27,0.18,0.11)
const LINEN := Color(0.61,0.58,0.46)
const IRON := Color(0.20,0.23,0.22)

static func rescue_passenger_visual(game: Object, role: String) -> PackedScene:
	# Share two idle mesh poses across the seven dependents and ferryman. The
	# ferry moves them as a group and the regular cast keeps its animation budget.
	var source: Node3D = game._make_role_visual(role,"characters",Vector3.ONE)
	if source == null:
		push_error("Required Open Road character visual is unavailable: "+role)
		return null
	game.zone_root.add_child(source)
	game._configure_npc_animation(source,"open_road_pose:"+role)
	var driver := source.get_node_or_null("CharacterAnimationDriver")
	if driver != null: driver.sample_pose()
	for skeleton: Skeleton3D in source.find_children("*","Skeleton3D",true,false):
		skeleton.force_update_all_bone_transforms()
	var posed := Node3D.new()
	var world_to_zone: Transform3D = game.zone_root.global_transform.affine_inverse()
	for original: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		if original.mesh == null or not original.is_visible_in_tree(): continue
		var part := MeshInstance3D.new()
		var baked := original.bake_mesh_from_current_skeleton_pose() if original.skin != null else null
		part.mesh = baked if baked != null else original.mesh
		part.transform = world_to_zone * original.global_transform
		part.layers = original.layers
		part.cast_shadow = original.cast_shadow
		for index in part.mesh.get_surface_count():
			part.set_surface_override_material(index,original.get_active_material(index))
		posed.add_child(part)
		part.owner = posed
	source.free()
	var packed := PackedScene.new()
	var valid := posed.get_child_count() > 0 and packed.pack(posed) == OK
	posed.free()
	if not valid:
		push_error("Required Open Road character mesh is unavailable: "+role)
		return null
	return packed

static func _table(host: Object, parent: Node3D, height: float = 0.8) -> void:
	for x in [-0.6,0.6]:
		for z in [-0.22,0.22]: _box(host,parent,Vector3(x,height*0.5,z),Vector3(0.09,height,0.09),WOOD)
	_box(host,parent,Vector3(0,height,0),Vector3(1.45,0.08,0.65),WOOD)

static func _bowl(host: Object, parent: Node3D, position: Vector3) -> void:
	var bowl := TorusMesh.new()
	bowl.inner_radius=0.07; bowl.outer_radius=0.115; bowl.rings=12; bowl.ring_segments=6
	_mesh(host,parent,bowl,position,WOOD.lightened(0.14))

static func _wheel(host: Object, parent: Node3D, position: Vector3) -> void:
	var rim := TorusMesh.new()
	rim.inner_radius=0.25; rim.outer_radius=0.30; rim.rings=16; rim.ring_segments=6
	_mesh(host,parent,rim,position,WOOD).rotation.z=PI*0.5

static func _box(host: Object, parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	return _mesh(host,parent,mesh,position,color)

static func _mesh(host: Object, parent: Node3D, mesh: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh
	node.position=position
	node.material_override=host._mat(color)
	parent.add_child(node)
	return node
