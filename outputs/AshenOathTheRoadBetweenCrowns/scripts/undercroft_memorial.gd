extends Node3D

const VarganDoor = preload("res://assets_external/environment/village/Vargan_door_Authored.res")
const WitnessRelief = preload("res://assets_external/environment/props/record_witness_relief.jpg")

var story_state: Node
var stone_material: StandardMaterial3D
var timber_material: StandardMaterial3D
var oath_inlay: MultiMeshInstance3D
var relief_material: StandardMaterial3D
var flame_material: StandardMaterial3D
var inscription: Label3D
var vigil: Node3D
var published_fate := "uninitialized"

func _ready() -> void:
	_build_memorial()
	story_state.changed.connect(_refresh)
	get_parent().child_entered_tree.connect(_on_room_child)
	_refresh()
	call_deferred("_dress_existing_doors")

func _exit_tree() -> void:
	if is_instance_valid(story_state) and story_state.changed.is_connected(_refresh):
		story_state.changed.disconnect(_refresh)
	var room := get_parent()
	if room != null and room.child_entered_tree.is_connected(_on_room_child):
		room.child_entered_tree.disconnect(_on_room_child)

func _build_memorial() -> void:
	# These stateful inlays cannot join the host's immutable decoration batch:
	# that batch publishes its original colors after the story state is applied.
	var strip := BoxMesh.new()
	strip.size = Vector3(0.08, 0.018, 4.0)
	var strips := MultiMesh.new()
	strips.transform_format = MultiMesh.TRANSFORM_3D
	strips.mesh = strip
	strips.instance_count = 3
	for index in range(3):
		strips.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3((index - 1) * 2.2, 0.135, -6.4)))
	oath_inlay = MultiMeshInstance3D.new()
	oath_inlay.name = "HalvernOathInlays"
	oath_inlay.multimesh = strips
	oath_inlay.material_override = StandardMaterial3D.new()
	oath_inlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(oath_inlay)
	relief_material = StandardMaterial3D.new()
	relief_material.albedo_texture = WitnessRelief
	relief_material.albedo_color = Color(0.80, 0.78, 0.71)
	relief_material.roughness = 0.94
	relief_material.emission_enabled = true
	relief_material.emission_texture = WitnessRelief
	relief_material.emission_energy_multiplier = 0.22
	var relief := MeshInstance3D.new()
	relief.name = "CarvedWitnesses"
	var face := QuadMesh.new()
	face.size = Vector2(6.40, 3.20)
	relief.mesh = face
	relief.material_override = relief_material
	relief.position = Vector3(0, 2.38, -13.84)
	relief.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(relief)
	inscription = Label3D.new()
	inscription.name = "HalvernMemorialInscription"
	inscription.font_size = 64
	inscription.pixel_size = 0.0043
	inscription.outline_size = 5
	inscription.position = Vector3(0, 4.27, -13.80)
	inscription.modulate = Color(0.81, 0.77, 0.65)
	add_child(inscription)
	vigil = Node3D.new()
	vigil.name = "WitnessVigil"
	add_child(vigil)
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.78, 0.69, 0.49)
	wax.roughness = 0.91
	flame_material = StandardMaterial3D.new()
	flame_material.albedo_color = Color(1.0, 0.72, 0.32)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.55, 0.13)
	flame_material.emission_energy_multiplier = 1.0
	var candle := CylinderMesh.new()
	candle.top_radius = 0.045
	candle.bottom_radius = 0.055
	candle.height = 0.25
	candle.radial_segments = 8
	var flame := SphereMesh.new()
	flame.radius = 0.04
	flame.height = 0.15
	flame.radial_segments = 8
	flame.rings = 4
	var positions := [-2.60, -1.60, -0.60, 0.60, 1.60, 2.60]
	for part in [[candle, wax, 0.875], [flame, flame_material, 1.075]]:
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = part[0]
		instances.instance_count = positions.size()
		for index in range(positions.size()):
			instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(positions[index], part[2], -13.83)))
		var node := MultiMeshInstance3D.new()
		node.multimesh = instances
		node.material_override = part[1]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vigil.add_child(node)

func _refresh() -> void:
	var fate := str(story_state.get_flag("halvern_fate", ""))
	if fate == published_fate:
		return
	published_fate = fate
	var peaceful := fate in ["witness", "released"]
	vigil.visible = peaceful
	relief_material.emission = Color(0.35, 0.24, 0.12) if peaceful else Color(0.11, 0.15, 0.22)
	inscription.text = str({
		"": "HALVERN - BOUND TO VARGAN",
		"witness": "HALVERN - A WITNESS, NOT A WEAPON",
		"released": "HALVERN - THE GRAVE OATH IS RELEASED",
		"destroyed": "HALVERN - THE OATH ENDS IN ASH",
		"defeated": "HALVERN - THE GRAVEKEEPER HAS FALLEN",
	}.get(fate, "HALVERN - THE GRAVE OATH HAS ENDED"))
	var tint := Color(0.59, 0.45, 0.24) if peaceful else (Color(0.19, 0.17, 0.15) if fate != "" else Color(0.31, 0.40, 0.58))
	(oath_inlay.material_override as StandardMaterial3D).albedo_color = tint
	set_meta("halvern_fate", fate)

func _on_room_child(child: Node) -> void:
	if str(child.name) in ["gate_record_hall", "gate_assembly"]:
		call_deferred("_dress_existing_doors")

func _dress_existing_doors() -> void:
	var room := get_parent()
	if room == null or room.is_queued_for_deletion():
		return
	for id in ["gate_record_hall", "gate_assembly"]:
		var area := room.get_node_or_null(NodePath(id)) as Node3D
		if area == null or not bool(area.get_meta("interior_door", false)) or area.has_node("UndercroftFittedDoor"):
			continue
		for old_name in ["InteriorDoorFrame", "InteriorDoor"]:
			var old := area.get_node_or_null(NodePath(old_name)) as MeshInstance3D
			if old != null:
				old.visible = false
		var door := MeshInstance3D.new()
		door.name = "UndercroftFittedDoor"
		door.mesh = VarganDoor
		door.set_surface_override_material(0, stone_material)
		door.set_surface_override_material(1, timber_material)
		door.rotation_degrees.y = 180.0 if id == "gate_record_hall" else 0.0
		door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		area.add_child(door)
