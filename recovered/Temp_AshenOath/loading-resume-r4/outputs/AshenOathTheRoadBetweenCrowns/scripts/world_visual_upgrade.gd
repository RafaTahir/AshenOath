extends RefCounted

const FEATURE_NAMES := [
	"SculptedGround", "CrownedRoad", "EmbeddedCobble", "DeepWheelRuts", "RainPuddles", "RoadErosion", "PlayerFootprints", "EnemyTracks", "CobbleMoss", "FoundationBlend",
	"WindGrass", "ResponsiveGrass", "ForestUnderstory", "TreeVariation", "MovingCanopy", "ExposedRoots", "FallenLogs", "TrunkMoss", "DisturbedBrush", "ForestSilhouette",
	"DuskSun", "MoonTransition", "LayeredClouds", "DistanceFog", "GroundMist", "AshPollen", "RainRipples", "WindTransition", "DistantLightning", "ZoneAtmosphere",
	"TimberFrames", "DamagedRoofs", "HingedDoors", "WindowShutters", "InteriorWindows", "ChimneySmoke", "HangingSigns", "WallTools", "FirewoodSupplies", "BuildingWeathering",
	"LanternFlicker", "ForgeEmbers", "BlacksmithCycle", "NoticePapers", "WindCloth", "CartWheels", "BarrelContents", "WaterTrough", "VillageCrows", "BrokenCrates",
	"ShrineCandles", "CandleWax", "IncenseSmoke", "ShrineBlessing", "VariedGraves", "DisturbedGraves", "SwingingBell", "RuinedChapel", "OssuaryDoor", "CemeteryCrows",
	"MaterialSeparation", "RoleClothing", "HandAttachments", "CloakMotion", "HeadLook", "EyeLine", "NpcSchedules", "WorkPoses", "DialogueIdle", "FootGrounding",
	"EnemyMaterials", "EnemySilhouettes", "GroundEmergence", "WindupTrails", "SwordArcs", "ImpactSparks", "BloodAshDecals", "ParryFlash", "DeathSettling", "EncounterResidue",
	"ShoulderFraming", "CameraDamping", "SprintFov", "IdleBreathing", "LandingResponse", "CameraCollision", "ShrineFraming", "GateFraming", "CombatFraming", "ImpactShake",
	"WarmColdContrast", "LightCulling", "ContactShadows", "QualityShadows", "InteractionPrompts", "EnemyHealthRead", "ObjectiveFlourish", "LoadingArtwork", "QualityComparison", "OpeningComposition"
]

func build(parent: Node3D, zone: String, quality: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual100_%s" % zone.capitalize()
	root.set_meta("visual_100_count", 100)
	parent.add_child(root)
	var range_start := 0 if zone == "greyfen" else 10
	var range_end := 100 if zone == "greyfen" else 100
	for index in range(range_start, range_end):
		if not _belongs_in_zone(index, zone):
			continue
		if quality == "potato" and index % 3 == 1:
			_make_feature_marker(root, index)
			continue
		_make_feature(root, index, zone, quality)
	return root

func _belongs_in_zone(index: int, zone: String) -> bool:
	if index < 10 or index in range(30, 70) or index >= 90:
		return zone == "greyfen"
	return zone == "wychwood"

func _make_feature_marker(parent: Node3D, index: int) -> void:
	var marker := Node3D.new()
	marker.name = "Visual100Feature_%03d_%s_PotatoFallback" % [index + 1, FEATURE_NAMES[index]]
	marker.set_meta("feature_id", index + 1)
	marker.set_meta("potato_fallback", true)
	parent.add_child(marker)

func _make_feature(parent: Node3D, index: int, zone: String, quality: String) -> void:
	var feature := Node3D.new()
	feature.name = "Visual100Feature_%03d_%s" % [index + 1, FEATURE_NAMES[index]]
	feature.set_meta("feature_id", index + 1)
	feature.set_meta("feature_name", FEATURE_NAMES[index])
	feature.position = _feature_position(index, zone)
	parent.add_child(feature)
	var palette := _feature_color(index, zone)
	match int(index / 10):
		0: _terrain_feature(feature, index, palette)
		1: _vegetation_feature(feature, index, palette, quality)
		2: _atmosphere_feature(feature, index, palette)
		3: _architecture_feature(feature, index, palette)
		4: _village_prop_feature(feature, index, palette)
		5: _sacred_feature(feature, index, palette)
		6: _character_stage_feature(feature, index, palette)
		7: _combat_feature(feature, index, palette)
		8: _camera_landmark_feature(feature, index, palette)
		_: _finish_feature(feature, index, palette)

func _feature_position(index: int, zone: String) -> Vector3:
	var local := index % 10
	if zone == "greyfen":
		var anchors := [Vector3(-14,0,11), Vector3(-9,0,5), Vector3(-6,0,-6), Vector3(6,0,-9), Vector3(10,0,4), Vector3(14,0,9)]
		var anchor: Vector3 = anchors[int(index / 10) % anchors.size()]
		return anchor + Vector3((local % 3) * 1.1 - 1.1, 0, int(local / 3) * 0.9 - 0.9)
	if index in range(80, 90):
		var frame_side := -1.0 if local % 2 == 0 else 1.0
		return Vector3(frame_side * (9.2 + (local % 3) * 0.65), 0, 11.0 - float(local) * 2.1)
	var side := -1.0 if local % 2 == 0 else 1.0
	return Vector3(side * (4.8 + (local % 3) * 1.15), 0, 12.0 - float(index % 30) * 0.78)

func _feature_color(index: int, zone: String) -> Color:
	if zone == "wychwood":
		return [Color(0.055,0.12,0.07), Color(0.09,0.16,0.11), Color(0.16,0.20,0.15), Color(0.12,0.08,0.05)][index % 4]
	return [Color(0.26,0.18,0.10), Color(0.15,0.22,0.13), Color(0.34,0.30,0.22), Color(0.42,0.18,0.08)][index % 4]

func _terrain_feature(root: Node3D, index: int, color: Color) -> void:
	_add_box(root, Vector3(0,0.035,0), Vector3(1.6 + index%3,0.07,0.55 + index%2), color.darkened(0.25))
	for i in range(3):
		_add_stone(root, Vector3(-0.55+i*0.5,0.10,0), Vector3(0.28,0.10,0.22), color.lightened(i*0.05))

func _vegetation_feature(root: Node3D, index: int, color: Color, quality: String) -> void:
	var count := 3 if quality == "balanced" else 5
	for i in range(count):
		var stem := _add_box(root, Vector3((i-count/2.0)*0.18,0.28,0), Vector3(0.055,0.56+0.08*(i%2),0.055), color.lightened(0.08*i))
		stem.set_meta("motion_type", "wind")
		stem.set_meta("motion_phase", float(i) * 0.7 + index)
		stem.set_meta("motion_amount", 4.0 + i)

func _atmosphere_feature(root: Node3D, index: int, color: Color) -> void:
	var plane := _add_box(root, Vector3(0,0.65,0), Vector3(2.8,0.08,0.75), Color(color.r,color.g,color.b,0.22), true)
	plane.set_meta("motion_type", "wind")
	plane.set_meta("motion_phase", float(index))
	var mote := _add_sphere(root, Vector3(0,1.15,0), Vector3(0.10,0.10,0.10), color.lightened(0.55), true)
	mote.set_meta("motion_type", "bird")
	mote.set_meta("motion_phase", float(index))

func _architecture_feature(root: Node3D, index: int, color: Color) -> void:
	_add_box(root, Vector3(0,0.75,0), Vector3(1.7,1.5,0.18), color)
	_add_box(root, Vector3(-0.62,0.85,-0.12), Vector3(0.12,1.55,0.12), Color(0.10,0.055,0.028))
	_add_box(root, Vector3(0.62,0.85,-0.12), Vector3(0.12,1.55,0.12), Color(0.10,0.055,0.028))
	var accent := _add_box(root, Vector3(0,1.25,-0.16), Vector3(0.65,0.34,0.04), Color(0.95,0.48,0.16), true)
	if index in [32,33,36]:
		accent.set_meta("motion_type", "wind")
		accent.set_meta("motion_amount", 2.0)

func _village_prop_feature(root: Node3D, index: int, color: Color) -> void:
	_add_box(root, Vector3(0,0.42,0), Vector3(0.72,0.84,0.55), color.darkened(0.2))
	var moving := _add_box(root, Vector3(0,0.95,-0.08), Vector3(0.55,0.18,0.08), color.lightened(0.22), index in [40,41])
	moving.set_meta("motion_type", "flame" if index in [40,41] else ("wheel" if index == 45 else "wind"))
	moving.set_meta("motion_phase", float(index))

func _sacred_feature(root: Node3D, index: int, color: Color) -> void:
	_add_stone(root, Vector3(0,0.48,0), Vector3(0.66,0.96,0.30), color.lightened(0.18))
	var glow := _add_sphere(root, Vector3(0,1.08,-0.22), Vector3(0.14,0.22,0.10), Color(0.72,0.86,0.58), true)
	glow.set_meta("motion_type", "flame")
	glow.set_meta("motion_phase", float(index))
	if index in [56,59]:
		var wing := _add_box(root, Vector3(0,1.55,0), Vector3(0.85,0.05,0.18), Color(0.02,0.02,0.025))
		wing.set_meta("motion_type", "bird")

func _character_stage_feature(root: Node3D, index: int, color: Color) -> void:
	_add_box(root, Vector3(0,0.025,0), Vector3(1.15,0.05,0.75), Color(0.025,0.020,0.016,0.65), true)
	_add_box(root, Vector3(0.42,0.22,0), Vector3(0.20,0.44,0.18), color)
	_add_box(root, Vector3(-0.38,0.14,0), Vector3(0.48,0.28,0.30), color.darkened(0.2))

func _combat_feature(root: Node3D, index: int, color: Color) -> void:
	var ring := _add_cylinder(root, Vector3(0,0.05,0), Vector3(0.85,0.025,0.85), color.lightened(0.35), true)
	ring.set_meta("motion_type", "flame")
	for i in range(3):
		var shard := _add_box(root, Vector3(-0.35+i*0.35,0.35,0), Vector3(0.08,0.65,0.08), color.lightened(i*0.12), index in [74,75,77])
		shard.rotation_degrees.z = -28.0 + i*28.0

func _camera_landmark_feature(root: Node3D, index: int, color: Color) -> void:
	_add_box(root, Vector3(0,0.48,0), Vector3(0.10,0.96,0.10), color.darkened(0.25))
	_add_box(root, Vector3(0,0.84,0), Vector3(0.42,0.07,0.07), color)
	var beacon := _add_sphere(root, Vector3(0,1.0,0), Vector3(0.07,0.10,0.07), color.lightened(0.55), true)
	beacon.set_meta("motion_type", "flame")

func _finish_feature(root: Node3D, index: int, color: Color) -> void:
	_add_cylinder(root, Vector3(0,0.04,0), Vector3(0.95,0.035,0.95), Color(color.r,color.g,color.b,0.40), true)
	for i in range(3):
		var marker := _add_sphere(root, Vector3(-0.4+i*0.4,0.35+0.15*i,0), Vector3(0.12,0.12,0.12), color.lightened(0.25*i), true)
		marker.set_meta("motion_type", "bird" if index == 99 else "flame")
		marker.set_meta("motion_phase", float(index+i))

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; node.mesh = mesh; node.position = pos; node.material_override = _material(color, emissive); parent.add_child(node); return node

func _add_stone(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var mesh := SphereMesh.new(); node.mesh = mesh; node.position = pos; node.scale = size; node.material_override = _material(color, false); parent.add_child(node); return node

func _add_sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.mesh = SphereMesh.new(); node.position = pos; node.scale = size; node.material_override = _material(color, emissive); parent.add_child(node); return node

func _add_cylinder(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var mesh := CylinderMesh.new(); mesh.top_radius = 0.5; mesh.bottom_radius = 0.5; mesh.height = 0.1; node.mesh = mesh; node.position = pos; node.scale = size; node.material_override = _material(color, emissive); parent.add_child(node); return node

func _material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.82
	if color.a < 0.99: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive: material.emission_enabled = true; material.emission = Color(color.r,color.g,color.b); material.emission_energy_multiplier = 0.55
	return material
