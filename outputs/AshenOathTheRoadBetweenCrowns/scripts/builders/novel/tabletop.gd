extends RefCounted

## Small working objects are attached only to the currently actionable stations.
## The older everyday pack is streamed. The native counterparts below also
## appear in the prologue, before regional art has been mounted.
const WOOD := Color(0.34,0.20,0.11)
const PAPER := Color(0.77,0.70,0.51)
const IRON := Color(0.23,0.24,0.21)
const LINEN := Color(0.54,0.49,0.40)
const PAINT := Color(0.13,0.16,0.17)
const RED := Color(0.53,0.12,0.09)
static var materials: Dictionary = {}
static var prop_library: Dictionary = {}

static func keepsake(id: String, variant: String = "") -> PackedScene:
	if prop_library.is_empty():
		const PATH := "res://assets/narrative_props/library.json"
		if not FileAccess.file_exists(PATH): return null
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if source is Dictionary: prop_library = source
	var entry: Dictionary = prop_library.get(id,{})
	var path := str(entry.get("variants",{}).get(variant,entry.get("default","")))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	return ResourceLoader.load(path) as PackedScene

static func dress(parent: Node3D, kind: String, height: float = 0.0) -> Node3D:
	var stand := Node3D.new()
	stand.name = "Workpiece"
	parent.add_child(stand)
	stand.position.y = height
	match kind:
		"spoon":
			box(stand,Vector3(0,0.25,0),Vector3(0.70,0.50,0.38),WOOD.darkened(0.27))
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var center := Vector3(-0.052,0.51,0)
			for i in 16:
				var a := TAU*float(i)/16.0
				var b := TAU*float(i+1)/16.0
				surface.add_vertex(center)
				surface.add_vertex(center+Vector3(cos(a)*0.052,0.014,sin(a)*0.038))
				surface.add_vertex(center+Vector3(cos(b)*0.052,0.014,sin(b)*0.038))
			surface.generate_normals()
			var bowl := MeshInstance3D.new()
			bowl.mesh=surface.commit()
			stand.add_child(bowl)
			var handle := box(stand,Vector3(0.11,0.523,0),Vector3(0.22,0.014,0.020),WOOD.lightened(0.27))
			bowl.material_override=handle.material_override
		"seed_bed":
			box(stand,Vector3(0,0.05,0),Vector3(0.78,0.10,0.44),Color("#544438"))
			for i in 5:
				var stem := box(stand,Vector3(-0.31+0.15*i,0.14,0.08*(i%2)),Vector3(0.020,0.13,0.020),Color("#626a40"))
				for side in [-1,1]:
					box(stem,Vector3(side*0.041,0.025,0),Vector3(0.10,0.022,0.041),Color("#869357")).rotation.z=side*0.35
		"bound_wheel":
			var rim := TorusMesh.new()
			rim.inner_radius = 0.38
			rim.outer_radius = 0.43
			var wheel := part(stand,rim,Vector3(0,0.44,0),WOOD)
			wheel.rotation = Vector3(PI/2,0,0.19)
			for i in 5:
				box(wheel,Vector3.ZERO,Vector3(0.77,0.032,0.033),WOOD).rotation.y = i*PI/5
			for i in 3:
				box(wheel,Vector3(0.24+i*0.025,0,0),Vector3(0.018,0.058,0.06),LINEN)
		"child_pan":
			var pan := CylinderMesh.new()
			pan.top_radius = 0.14
			pan.bottom_radius = 0.11
			pan.height = 0.12
			part(stand,pan,Vector3(0,0.07,0),IRON)
			box(stand,Vector3(0.23,0.10,0),Vector3(0.23,0.026,0.035),WOOD)
		"barred_gate":
			for side in [-1,1]:
				box(stand,Vector3(side*0.61,0.63,0),Vector3(0.14,1.26,0.14),WOOD)
			for i in 5:
				box(stand,Vector3(-0.45+i*0.22,0.49,0),Vector3(0.19,0.98,0.05),WOOD)
			box(stand,Vector3(0,0.70,0.08),Vector3(1.43,0.092,0.09),IRON)
		"kept_crow":
			var token := keepsake("oren_crow","wrapped")
			if token != null:
				box(stand,Vector3(0,0.14,0),Vector3(0.41,0.28,0.35),WOOD)
				var model := token.instantiate() as Node3D
				stand.add_child(model)
				model.position.y = 0.29
		"bell", "strongbox", "crow":
			var prop := keepsake("elna_bell" if kind=="bell" else ("oren_crow" if kind=="crow" else "merrow_strongbox"),"cemetery" if kind=="bell" else "")
			if prop != null: stand.add_child(prop.instantiate())
		"ledger", "order", "copy", "petition":
			box(stand,Vector3(0,0.15,0),Vector3(0.78,0.30,0.47),WOOD)
			box(stand,Vector3(0,0.32,0),Vector3(0.53,0.05,0.33),PAINT)
			for i in 4:
				box(stand,Vector3(-0.10+0.07*i,0.35,0),Vector3(0.22,0.009,0.24),PAPER).rotation.y = -0.08*i
			box(stand,Vector3(0.17,0.36,0),Vector3(0.023,0.016,0.24),RED)
		"frame", "door", "sill", "ladder":
			for side in [-1,1]:
				box(stand,Vector3(side*0.35,0.12,0),Vector3(0.10,0.12,1.42),WOOD)
			for i in 4: box(stand,Vector3(0,0.18,-0.5+i*0.32),Vector3(0.73,0.055,0.19),LINEN if kind=="frame" else WOOD)
		"bolts", "wire", "pin", "nail":
			box(stand,Vector3(0,0.14,0),Vector3(0.55,0.28,0.42),WOOD)
			for i in 2:
				var bent := TorusMesh.new()
				bent.inner_radius = 0.048
				bent.outer_radius = 0.062
				bent.rings = 12
				bent.ring_segments = 5
				part(stand,bent,Vector3(0.11*i-0.05,0.30,0),IRON)
		"shoe", "linen", "shawl", "load", "bedding":
			for i in 3:
				var bundle := box(stand,Vector3(0,0.07+i*0.115,0),Vector3(0.50-i*0.018,0.13,0.35),LINEN if i!=1 else PAPER)
				bundle.rotation.y = 0.065*i
			box(stand,Vector3(0,0.34,0),Vector3(0.035,0.018,0.35),RED)
		"post", "line", "strop", "signal":
			box(stand,Vector3(0,0.38,0),Vector3(0.11,0.76,0.12),WOOD)
			for i in 3:
				box(stand,Vector3(0,0.62+i*0.031,0),Vector3(0.14,0.023,0.15),PAPER)
			box(stand,Vector3(0.12,0.59,0),Vector3(0.21,0.19,0.018),RED)
		"tray", "meal", "bucket", "water":
			var bowl := CylinderMesh.new()
			bowl.top_radius = 0.23
			bowl.bottom_radius = 0.14
			bowl.height = 0.23
			bowl.radial_segments = 16
			part(stand,bowl,Vector3(0,0.12,0),IRON)
			var surface := CylinderMesh.new()
			surface.top_radius = 0.207
			surface.bottom_radius = 0.207
			surface.height = 0.008
			part(stand,surface,Vector3(0,0.239,0),Color(0.45,0.34,0.17) if kind=="meal" else Color(0.27,0.43,0.45))
	return stand

## The household barrel stays locked. The old bench gives at the pried corner.
static func loosen_chest(workpiece: Node3D, fraction: float) -> void:
	if workpiece == null or workpiece.get_child_count()==0: return
	var chest := workpiece.get_child(0)
	var hinge := chest.get_node_or_null("LidHinge") as Node3D
	if hinge == null: return
	hinge.rotation.z = -0.16 * clampf(fraction,0,1)
	hinge.position.y = 0.218 + 0.04 * clampf(fraction,0,1)

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return part(parent,mesh,pos,color)

static func part(parent: Node3D, mesh: PrimitiveMesh, pos: Vector3, color: Color) -> MeshInstance3D:
	if not materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.88
		materials[color] = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = materials[color]
	node.position = pos
	parent.add_child(node)
	return node
