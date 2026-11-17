extends RefCounted
const Api = preload("res://scripts/core/zone_construction_api.gd")
const Scope = preload("res://scripts/core/zone_instance_scope.gd")
var _host: Api
var _scope: Scope
func _init(host: Api, scope: Scope) -> void:
	_host = host
	_scope = scope
func _make_torch(pos: Vector3) -> void:
	_host._make_prop_box("TorchPost", pos + Vector3(0, 0.85, 0), Vector3(0.13, 1.7, 0.13), Color(0.10, 0.06, 0.035))
	var flame = MeshInstance3D.new()
	var flame_mesh: Variant = SphereMesh.new()
	flame_mesh.radial_segments = 5
	flame_mesh.rings = 3
	flame.mesh = flame_mesh
	flame.scale = Vector3(0.10, 0.18, 0.10)
	flame.position = pos + Vector3(0, 1.75, 0)
	flame.material_override = _host._emissive_mat(Color(1.0, 0.45, 0.14), 1.4)
	_host.write_construction_tag(flame, "world_prop_kind", "flame")
	_host.write_construction_tag(flame, "world_prop_id", "torch_flame")
	_scope.zone_root.add_child(flame)
	_host._make_light("BanditWarmLantern" if _scope.zone_id == "bandit_road" else "TorchLight", pos + Vector3(0, 1.8, 0), Color(1.0, 0.45, 0.16), 1.45)
func _make_village_dressing() -> void:
	for item in [
		["barrel", Vector3(-4.0, 0, 3.4), 0.56, -8.0],
		["barrel", Vector3(-4.8, 0, 4.1), 0.48, 15.0],
		["crate", Vector3(-7.3, 0, 4.9), 0.64, 25.0],
		["crate", Vector3(11.1, 0, -2.7), 0.72, -18.0],
		["barrel", Vector3(10.7, 0, 2.9), 0.58, 18.0],
		["forest_rock", Vector3(8.6, 0, -11.7), 0.55, 0.0],
		["forest_rock", Vector3(-4.8, 0, -12.4), 0.52, 0.0],
		["crate", Vector3(5.5, 0, -6.9), 0.46, -12.0],
		["barrel", Vector3(7.2, 0, -6.4), 0.46, 10.0]
	]:
		_host._make_loose_role(str(item[0]), item[1], Vector3.ONE * float(item[2]), float(item[3]))
	for pos in [Vector3(-3.8, 0, -6.0), Vector3(3.9, 0, -9.2), Vector3(-4.4, 0, -13.0)]:
		_host._make_rubble(pos)
func _make_greyfen_first_impression_dressing(stage: String = "") -> void:
	var stages: Variant = ["ruts", "lanterns", "shrine", "story", "crows"]
	if stage != "" and stage not in stages:
		push_error("Unknown Greyfen first-impression stage: " + stage)
		return
	var marker: Variant = _scope.zone_root.find_child("GreyfenFirstImpressionDressing", true, false)
	if marker == null:
		marker = Node3D.new()
		marker.name = "GreyfenFirstImpressionDressing"
		_scope.zone_root.add_child(marker)
	for part in stages:
		if (stage != "" and stage != part) or bool(_host.read_construction_tag(marker, "built_" + part, false)):
			continue
		match part:
			"ruts": _host._make_road_ruts()
			"lanterns": _host._make_lantern_rhythm()
			"shrine": _host._make_shrine_approach()
			"story": _host._make_village_story_clusters()
			"crows": _host._make_crow_silhouettes()
		_host.write_construction_tag(marker, "built_" + part, true)
	for part in stages:
		if not bool(_host.read_construction_tag(marker, "built_" + part, false)):
			return
	_host.write_construction_tag(marker, "first_impression_complete", true)
func _make_quality_greyfen_overhaul() -> void:
	if str(_host.settings.settings.get("quality_preset", "balanced")) != "quality":
		return
	var marker = Node3D.new()
	marker.name = "QualityGreyfenVisualOverhaul"
	_scope.zone_root.add_child(marker)
	for z in [-13.0, -10.5, -8.0, -5.5, -3.0, -0.5, 2.0, 4.5, 7.0, 9.5, 12.0]:
		_host._make_visual_box("QualityWetRoadSheen", Vector3(_host._scene_randf_range(-0.45, 0.45), 0.058, z), Vector3(_host._scene_randf_range(0.55, 1.35), 0.012, _host._scene_randf_range(0.42, 1.15)), Color(0.045, 0.037, 0.030))
		_host._make_visual_box("QualityRoadLeafLitter", Vector3(_host._scene_randf_range(-1.9, 1.9), 0.066, z + _host._scene_randf_range(-0.75, 0.75)), Vector3(_host._scene_randf_range(0.18, 0.55), 0.012, _host._scene_randf_range(0.08, 0.20)), Color(0.12, 0.060, 0.030))
	for pos in [Vector3(-5.8,0,2.5), Vector3(-7.0,0,-3.2), Vector3(7.2,0,-0.2), Vector3(9.8,0,1.8), Vector3(-10.0,0,8.8), Vector3(11.2,0,-7.4)]:
		_host._make_quality_survival_cluster(pos)
	for pos in [Vector3(4.0,0,-6.0), Vector3(5.2,0,-4.5), Vector3(7.5,0,-7.2), Vector3(6.8,0,-5.8)]:
		_host._make_fake_light_pool("QualityShrineCandlePool", pos + Vector3(0, 0.038, 0), Vector3(1.05, 0.016, 0.64), Color(0.34, 0.19, 0.07))
	for pos in [Vector3(-3.2,0,-12.5), Vector3(3.4,0,-11.6), Vector3(-3.6,0,-9.2), Vector3(3.2,0,-7.8), Vector3(-3.1,0,-4.8), Vector3(3.5,0,-2.0)]:
		_host._make_visual_box("QualityRoadEdgeWeeds", pos + Vector3(0, 0.15, 0), Vector3(0.12, _host._scene_randf_range(0.26, 0.46), 0.08), Color(0.060, 0.120, 0.055))
	_host._make_light("QualityShrineWarmth", Vector3(5.5, 2.7, -5.9), Color(1.0, 0.50, 0.20), 1.2)
	_host._make_light("QualityVillageColdEdge", Vector3(-10.0, 3.8, -8.0), Color(0.22, 0.32, 0.46), 1.1)
func _make_spawn_composition() -> void:
	var marker = Node3D.new()
	marker.name = "GreyfenSpawnComposition"
	marker.position = Vector3(0, 0, 7)
	_scope.zone_root.add_child(marker)
	_host._make_light("SpawnWarmRead", Vector3(-2.6, 2.8, 5.7), Color(1.0, 0.42, 0.16), 1.0)
	_host._make_light("SpawnCoolBackplate", Vector3(1.8, 3.5, 0.4), Color(0.30, 0.36, 0.50), 1.4)
	_host._make_fog_sheet(Vector3(0, 0.8, 0.8), Vector3(10.0, 0.7, 3.2), Color(0.13, 0.15, 0.16, 0.07))
	_host._make_fake_light_pool("SpawnLanternPool", Vector3(-2.55, 0.035, 5.6), Vector3(1.9, 0.025, 1.25), Color(0.42, 0.20, 0.075))
	for pos in [Vector3(-3.1, 0, 4.2), Vector3(3.0, 0, 3.4), Vector3(-2.9, 0, 0.2), Vector3(2.9, 0, -1.5)]:
		_host._make_path_stone(pos, 0.22)
	_host._make_lantern_post(Vector3(-2.8, 0, 5.7), false, true)
	_host._make_lantern_post(Vector3(2.65, 0, 1.5), false, false)
	_host._make_firewood_stack(Vector3(-5.1, 0, 5.2), 18.0)
	_host._make_broken_fence_run(Vector3(4.7, 0, 5.8), false)
func _make_notice_board(pos: Vector3) -> void:
	_host._make_prop_box("NoticePost", pos + Vector3(-0.55, 0.7, 0), Vector3(0.16, 1.4, 0.16), Color(0.14, 0.08, 0.045))
	_host._make_prop_box("NoticePost", pos + Vector3(0.55, 0.7, 0), Vector3(0.16, 1.4, 0.16), Color(0.14, 0.08, 0.045))
	_host._make_prop_box("NoticeBoard", pos + Vector3(0, 1.25, 0), Vector3(1.55, 0.9, 0.12), Color(0.28, 0.16, 0.08))
	_host._make_world_prop_anchor("notice_board", "notice_board", pos, "evidence_report")
func _make_wychwood_gate_scene(pos: Vector3) -> void:
	for offset in [-2.25, 2.25]:
		_host._make_torch(pos + Vector3(offset, 0, 0.2))
		_host._make_loose_role("fence", pos + Vector3(offset * 0.82, 0, 0.65), Vector3(0.92, 0.92, 0.92), 90.0)
	for offset in [Vector3(-4.2, 0, 1.4), Vector3(4.0, 0, 1.2), Vector3(-4.0, 0, -1.1), Vector3(3.9, 0, -1.0)]:
		_host._make_rubble(pos + offset)
	_host._make_fog_sheet(pos + Vector3(0, 0.75, -0.4), Vector3(6.2, 0.9, 1.9), Color(0.20, 0.24, 0.22, 0.16))
func _make_route_markers() -> void:
	for pos in [Vector3(-0.9, 0, -4.5), Vector3(0.95, 0, -8.2), Vector3(-0.7, 0, -11.4)]:
		_host._make_prop_box("RoadCandle", pos + Vector3(0, 0.18, 0), Vector3(0.14, 0.36, 0.14), Color(0.20, 0.11, 0.05))
		var flame = MeshInstance3D.new()
		var flame_mesh: Variant = SphereMesh.new()
		flame_mesh.radial_segments = 5
		flame_mesh.rings = 3
		flame.mesh = flame_mesh
		flame.scale = Vector3(0.12, 0.18, 0.12)
		flame.position = pos + Vector3(0, 0.48, 0)
		flame.material_override = _host._emissive_mat(Color(1.0, 0.48, 0.16), 1.1)
		_host.write_construction_tag(flame, "world_prop_kind", "candle")
		_host.write_construction_tag(flame, "world_prop_id", "road_candle")
		_scope.zone_root.add_child(flame)
		_host._make_light("RoadCandleGlow", pos + Vector3(0, 0.72, 0), Color(1.0, 0.45, 0.16), 0.8)
func _make_greyfen_road_of_crows_story_beats() -> void:
	var marker = Node3D.new()
	marker.name = "RoadOfCrowsGreyfenStoryBeats"
	_scope.zone_root.add_child(marker)
	_host._make_black_feather_scatter("RoadCrowsNoticeBlackFeathers", Vector3(-2.8, 0.09, 9.0), 4, 0.75)
	_host._make_broken_charm("RoadCrowsNoticePrayerCharm", Vector3(-1.35, 0.10, 8.95), 0.0)
	_host._make_black_feather_scatter("RoadCrowsShrineBlackFeathers", Vector3(5.25, 0.10, -6.25), 5, 0.65)
	_host._make_broken_charm("RoadCrowsShrineSnappedToken", Vector3(5.65, 0.12, -6.75), -22.0)
	_host._append_prepared_detail("RoadCrowsExtinguishedCandle_17d04e45b8")
	_host.CemeteryEvidencePresentation.add_disturbed_soil(_scope.zone_root, Vector3(13.65, 0.057, 9.45), _host.world_materials.get_material("wet_mud", str(_host.settings.settings.get("quality_preset", "balanced")), Color(0.43, 0.38, 0.31), 0.0, false))
	_host._make_broken_charm("RoadCrowsGraveyardHalfBuriedCharm", Vector3(13.18, 0.13, 9.15), 14.0)
	_host._make_black_feather_scatter("RoadCrowsGateThresholdFeathers", Vector3(-1.25, 0.10, -13.65), 5, 0.9)
	_host._make_dark_track("RoadCrowsGateMudTrail", Vector3(0.0, 0.071, -13.15), Vector3(0.42, 0.022, 2.15), Color(0.040, 0.027, 0.020))
	_host._append_prepared_detail("RoadCrowsGateBrokenSign_70d5d38f95")
	_host._make_claw_marks("RoadCrowsGateClawedPost", Vector3(2.35, 0.95, -13.85), true)
func _make_wychwood_route_dressing() -> void:
	for item in [
		["forest_rock", Vector3(-4.6, 0, 9.0), 0.46, 8.0],
		["forest_rock", Vector3(4.7, 0, 7.8), 0.40, -16.0],
		["forest_rock", Vector3(-4.8, 0, 1.6), 0.52, 22.0],
		["forest_rock", Vector3(4.9, 0, -1.7), 0.44, 0.0],
		["barrel", Vector3(-5.2, 0, 8.2), 0.48, 0.0],
		["crate", Vector3(-5.8, 0, 7.6), 0.56, 11.0]
	]:
		_host._make_loose_role(str(item[0]), item[1], Vector3.ONE * float(item[2]), float(item[3]))
	for pos in [Vector3(-7.0, 0, 11.5), Vector3(7.1, 0, 3.0), Vector3(-7.0, 0, -2.0), Vector3(7.1, 0, -4.8)]:
		_host._make_deadfall(pos)
	for pos in [Vector3(-8.4, 0, 12.5), Vector3(8.3, 0, 11.8), Vector3(-8.6, 0, 4.8), Vector3(8.5, 0, 1.2), Vector3(-8.8, 0, -5.4), Vector3(8.7, 0, -7.2)]:
		_host._make_tree(pos)
func _make_wychwood_corridor() -> void:
	var marker = Node3D.new()
	marker.name = "WychwoodCorridorComposition"
	marker.position = Vector3(0, 0, 4)
	_scope.zone_root.add_child(marker)
	for z in [11.0, 7.5, 4.0, 0.5, -3.0]:
		_host._make_tree(Vector3(-9.2 + _host._scene_randf_range(-0.25, 0.25), 0, z))
		_host._make_tree(Vector3(9.2 + _host._scene_randf_range(-0.25, 0.25), 0, z + _host._scene_randf_range(-0.25, 0.25)))
		_host._make_fog_sheet(Vector3(0, 0.75, z - 0.8), Vector3(7.5, 0.72, 1.5), Color(0.12, 0.18, 0.16, 0.11))
func _make_wychwood_road_of_crows_story_beats() -> void:
	var marker = Node3D.new()
	marker.name = "RoadOfCrowsWychwoodStoryBeats"
	_scope.zone_root.add_child(marker)
	_host._make_cart(Vector3(-5.35, 0, 6.6))
	_host._append_prepared_detail("RoadCrowsBrokenCartSupplySack_978fae0e15")
	_host._make_dark_track("RoadCrowsDraggedTrackA", Vector3(-1.05, 0.073, 6.4), Vector3(0.32, 0.018, 2.6), Color(0.050, 0.027, 0.020))
	_host._make_dark_track("RoadCrowsDraggedTrackB", Vector3(0.75, 0.074, 5.1), Vector3(0.26, 0.018, 2.0), Color(0.055, 0.030, 0.022))
	_host._make_claw_marks("RoadCrowsCartClawMarks", Vector3(2.7, 0.22, 4.65), false)
	_host._append_prepared_detail("RoadCrowsTornRedCloth_696592259f")
	_host._make_broken_charm("RoadCrowsBrokenPrayerToken", Vector3(-3.18, 0.13, 2.25), -12.0)
	_host._make_black_feather_scatter("RoadCrowsOldRoadBlackFeathers", Vector3(-3.95, 0.10, 1.75), 6, 0.75)
	_host._make_dark_track("RoadCrowsClearingDraggedMarks", Vector3(0.0, 0.074, -5.65), Vector3(0.46, 0.020, 3.1), Color(0.060, 0.022, 0.016))
	_host._append_prepared_detail("RoadCrowsClearingOldBloodMud_3184405d5b")
	_host._make_broken_charm("RoadCrowsClearingSnappedCharm", Vector3(1.35, 0.13, -6.9), 24.0)
	_host._make_black_feather_scatter("RoadCrowsClearingFeathers", Vector3(1.55, 0.10, -7.25), 5, 0.72)
func _make_quality_wychwood_overhaul() -> void:
	if str(_host.settings.settings.get("quality_preset", "balanced")) != "quality":
		return
	var marker = Node3D.new()
	marker.name = "QualityWychwoodVisualOverhaul"
	_scope.zone_root.add_child(marker)
	for z in [12.0, 9.5, 7.0, 4.5, 2.0, -0.5, -3.0, -5.5, -8.0]:
		_host._make_visual_box("QualityWychwoodWetMud", Vector3(_host._scene_randf_range(-0.55, 0.55), 0.060, z), Vector3(_host._scene_randf_range(0.70, 1.55), 0.012, _host._scene_randf_range(0.42, 1.05)), Color(0.018, 0.027, 0.024))
		_host._make_visual_box("QualityWychwoodRootCrossing", Vector3(_host._scene_randf_range(-2.3, 2.3), 0.145, z + _host._scene_randf_range(-0.6, 0.6)), Vector3(_host._scene_randf_range(0.95, 1.8), 0.11, 0.13), Color(0.070, 0.038, 0.022))
	for z in [10.5, 7.5, 4.5, 1.5, -1.5, -4.5, -7.5]:
		_host._make_deadfall(Vector3(-5.8 + _host._scene_randf_range(-0.4, 0.2), 0, z))
		_host._make_deadfall(Vector3(5.8 + _host._scene_randf_range(-0.2, 0.4), 0, z + _host._scene_randf_range(-0.3, 0.3)))
		_host._make_tree(Vector3(-10.4, 0, z + _host._scene_randf_range(-0.5, 0.5)))
		_host._make_tree(Vector3(10.4, 0, z + _host._scene_randf_range(-0.5, 0.5)))
	for pos in [Vector3(-2.2,0,6.7), Vector3(2.6,0,4.6), Vector3(-2.8,0,1.2), Vector3(2.9,0,-1.8)]:
		_host._make_visual_box("QualityClueGroundDarkening", pos + Vector3(0, 0.065, 0), Vector3(1.15, 0.014, 0.56), Color(0.027, 0.022, 0.018))
	for pos in [Vector3(-4.8,0,-5.8), Vector3(4.6,0,-6.4), Vector3(-2.6,0,-8.8), Vector3(2.8,0,-8.3), Vector3(0.0,0,-6.2)]:
		_host._make_visual_box("QualityClearingBloodMud", pos + Vector3(0, 0.070, 0), Vector3(1.15, 0.014, 0.46), Color(0.070, 0.018, 0.012))
	for pos in [Vector3(-7.0,0,-10.4), Vector3(7.2,0,-10.0), Vector3(-6.8,0,-4.8), Vector3(6.7,0,-4.2)]:
		_host._make_fog_sheet(pos + Vector3(0, 0.85, 0), Vector3(4.4, 0.72, 1.45), Color(0.10, 0.18, 0.16, 0.18))
	for pos in [Vector3(-8.2,0,13.0), Vector3(8.0,0,12.8), Vector3(-6.5,0,8.8)]:
		_host._make_visual_box("QualityBrokenForestSign", pos + Vector3(0, 0.85, 0), Vector3(0.95, 0.12, 0.40), Color(0.11, 0.065, 0.034))
	_host._make_light("QualityForestBlueRim", Vector3(0, 3.6, -6.5), Color(0.22, 0.42, 0.58), 1.4)
	_host._make_light("QualityGateLastWarmth", Vector3(0, 2.6, 11.6), Color(1.0, 0.42, 0.14), 1.0)
func _make_gravestone(pos: Vector3) -> void:
	_host._make_prop_box("Gravestone", pos + Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.18), Color(0.31, 0.31, 0.30))
	_host._make_prop_box("GraveBase", pos + Vector3(0, 0.09, 0.34), Vector3(0.75, 0.16, 1.0), Color(0.11, 0.10, 0.09))
	_host._make_prop_box("GraveMoss", pos + Vector3(0.08, 0.72, -0.095), Vector3(0.18, 0.20, 0.025), Color(0.09, 0.18, 0.08))
func _add_visual_100_layer(zone_id: String) -> void:
	var quality: Variant = str(_host.settings.settings.get("quality_preset", "balanced")) if _host.settings != null else "balanced"
	var visual_root: Variant = Node3D.new()
	visual_root.name = "AuthoredVisualLayer_%s" % zone_id.capitalize()
	_host.write_construction_tag(visual_root, "synthetic_visual_100_removed", true)
	_scope.zone_root.add_child(visual_root)
	var motion = _host.WorldMotionController.new()
	motion.name = "WorldMotionController"
	_scope.zone_root.add_child(motion)
	motion.configure(_scope.zone_root, quality, _host.player)
	var surface = _host.SurfaceFeedbackManager.new()
	surface.name = "SurfaceFeedbackManager"
	_scope.zone_root.add_child(surface)
	surface.configure(_host.player, quality)
	_scope.world_vfx = _host.WorldVFXController.new()
	_scope.world_vfx.name = "WorldVFXController"
	_scope.zone_root.add_child(_scope.world_vfx)
	_scope.world_vfx.configure(zone_id, quality)
func _install_world_prop_controller(zone_id: String) -> void:
	_host.StoryWorldDirector.decorate(_host, _scope.zone_root, zone_id)
	if not _host.neighbor_building: _host.CovenantResolution.restore(_host)
	if _scope.zone_root == null or not is_instance_valid(_scope.zone_root):
		_scope.world_props = null
		return
	var existing: Variant = _scope.zone_root.find_child("WorldPropController", true, false) as WorldPropController
	if existing != null:
		_scope.world_props = existing
		return
	_scope.world_props = _host.WorldPropController.new()
	_scope.world_props.name = "WorldPropController"
	_scope.zone_root.add_child(_scope.world_props)
	_scope.world_props.configure(_scope.zone_root, zone_id, str(_host.settings.settings.get("quality_preset", "balanced")), _host.story_state, _host.audio)
func _apply_first_route_materials(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		_host._apply_first_route_materials(child)
	if root is MeshInstance3D:
		var mesh_instance = root as MeshInstance3D
		var palette_key = _host._first_route_palette_key(mesh_instance)
		if palette_key == "":
			return
		if _host._mesh_needs_visible_fallback(mesh_instance):
			mesh_instance.material_override = _host._first_route_material(palette_key)
func _make_lantern_rhythm() -> void:
	var points = [
		[Vector3(-2.85, 0, 6.4), true],
		[Vector3(2.95, 0, 2.2), false],
		[Vector3(-2.75, 0, -2.5), false],
		[Vector3(2.85, 0, -6.8), false],
		[Vector3(-2.55, 0, -10.8), false]
	]
	for item in points:
		_host._make_lantern_post(item[0], false, bool(item[1]))
		_host._make_fake_light_pool("RoadLanternPool", item[0] + Vector3(0, 0.035, 0.25), Vector3(1.55, 0.022, 1.05), Color(0.32, 0.135, 0.045))
func _make_shrine_approach() -> void:
	_host._append_prepared_detail("ShrinePathWarmEdge_30f036e1cc")
	_host._append_prepared_detail("ShrinePathWarmEdge_fb53d619f3")
	_host._make_lantern_post(Vector3(3.4, 0, -4.25), true, true)
	_host._make_lantern_post(Vector3(7.65, 0, -6.1), true, false)
	for offset in [Vector3(-1.25, 0, 0.75), Vector3(1.18, 0, 0.82), Vector3(-1.55, 0, -0.25), Vector3(1.5, 0, -0.3)]:
		_host._make_shrine_candle(Vector3(6.0, 0, -7.0) + offset)
	_host._make_hanging_cloth(Vector3(4.85, 1.25, -7.95), Vector3(0.55, 0.72, 0.035), Color(0.34, 0.035, 0.030))
	_host._make_hanging_cloth(Vector3(7.05, 1.20, -7.92), Vector3(0.48, 0.62, 0.035), Color(0.12, 0.16, 0.13))
func _make_village_story_clusters() -> void:
	_host._make_firewood_stack(Vector3(-6.8, 0, -0.8), -12.0)
	_host._make_firewood_stack(Vector3(8.2, 0, -1.2), 24.0)
	_host._make_broken_fence_run(Vector3(-4.8, 0, -7.0), true)
	_host._make_broken_fence_run(Vector3(4.9, 0, -10.4), true)
	_host._make_wheelbarrow(Vector3(-7.9, 0, 6.6), -22.0)
	_host._make_wheelbarrow(Vector3(11.7, 0, -10.2), 35.0)
	for pos in [Vector3(-10.7, 0, 10.5), Vector3(12.4, 0, 6.3), Vector3(15.6, 0, 7.7)]:
		_host._make_mourning_marker(pos)
	for pos in [Vector3(-12.7, 0, -5.8), Vector3(-11.8, 0, -4.3), Vector3(13.2, 0, -5.4), Vector3(14.2, 0, -4.0)]:
		_host._make_fake_fog_bank(pos)
func _make_quality_survival_cluster(pos: Vector3) -> void:
	_host._make_visual_box("QualityMudSack", pos + Vector3(0.0, 0.16, 0.0), Vector3(0.58, 0.32, 0.36), Color(0.17, 0.115, 0.065))
	_host._make_visual_box("QualityBrokenBoard", pos + Vector3(0.62, 0.13, -0.14), Vector3(0.88, 0.08, 0.18), Color(0.13, 0.075, 0.038))
	_host._make_visual_box("QualityBucket", pos + Vector3(-0.52, 0.24, 0.18), Vector3(0.32, 0.48, 0.32), Color(0.10, 0.085, 0.065))
	_host._make_visual_box("QualityClothScrap", pos + Vector3(0.1, 0.045, 0.5), Vector3(0.82, 0.018, 0.32), Color(0.23, 0.055, 0.044))
func _make_lantern_post(pos: Vector3, shrine_style: bool, casts_light: bool) -> void:
	_host._make_prop_box("LanternPost", pos + Vector3(0, 0.75, 0), Vector3(0.12, 1.5, 0.12), Color(0.12, 0.070, 0.038))
	_host._make_visual_box("LanternArm", pos + Vector3(0.28, 1.38, 0), Vector3(0.56, 0.08, 0.08), Color(0.12, 0.070, 0.038))
	_host._make_visual_box("LanternCage", pos + Vector3(0.56, 1.18, 0), Vector3(0.22, 0.34, 0.22), Color(0.055, 0.040, 0.030))
	var glow_color = Color(1.0, 0.50, 0.16) if not shrine_style else Color(0.74, 0.88, 0.58)
	var glow = MeshInstance3D.new()
	glow.name = "LanternGlow"
	_host.write_construction_tag(glow, "visual_name", "LanternGlow")
	var glow_mesh: Variant = SphereMesh.new()
	glow_mesh.radial_segments = 5
	glow_mesh.rings = 3
	glow.mesh = glow_mesh
	glow.scale = Vector3(0.16, 0.22, 0.16)
	glow.position = pos + Vector3(0.56, 1.17, 0)
	glow.material_override = _host._emissive_mat(glow_color, 1.25)
	_host.write_construction_tag(glow, "world_prop_kind", "lantern")
	_host.write_construction_tag(glow, "world_prop_moving_part", true)
	_host.write_construction_tag(glow, "world_prop_id", "lantern_glow")
	_scope.zone_root.add_child(glow)
	if casts_light:
		_host._make_light("SpawnWarmRead" if not shrine_style else "Shrine Beacon", pos + Vector3(0.45, 1.45, 0), glow_color, 0.9)
func _make_firewood_stack(pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = "FirewoodStack"
	root.position = pos
	root.rotation_degrees.y = yaw
	_scope.zone_root.add_child(root)
	for i in range(5):
		var log_mesh = MeshInstance3D.new()
		log_mesh.name = "StackedLog"
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.075
		mesh.bottom_radius = 0.085
		mesh.height = 1.05
		mesh.radial_segments = 6
		log_mesh.mesh = mesh
		log_mesh.position = Vector3(-0.34 + float(i) * 0.17, 0.18 + float(i % 2) * 0.13, 0)
		log_mesh.rotation_degrees = Vector3(90, 0, 90)
		log_mesh.material_override = _host._mat(Color(0.135, 0.078, 0.044))
		root.add_child(log_mesh)
func _make_broken_fence_run(pos: Vector3, vertical: bool) -> void:
	for i in range(3):
		var offset = Vector3(0, 0, float(i) * 0.85) if vertical else Vector3(float(i) * 0.85, 0, 0)
		_host._make_visual_box("BrokenFencePost", pos + offset + Vector3(0, 0.42 + 0.06 * float(i % 2), 0), Vector3(0.12, 0.84, 0.12), Color(0.13, 0.075, 0.040))
	var rail_size = Vector3(0.10, 0.10, 2.35) if vertical else Vector3(2.35, 0.10, 0.10)
	_host._make_visual_box("BrokenFenceRail", pos + Vector3(0.42 if not vertical else 0, 0.72, 0.42 if vertical else 0), rail_size, Color(0.16, 0.095, 0.050))
func _make_world_prop_anchor(id: String, kind: String, pos: Vector3, state_key: String = "") -> Node3D:
	var anchor: Variant = Node3D.new()
	anchor.name = "WorldPropAnchor_%s" % id.capitalize()
	anchor.position = _host.river_safe_position(pos, 0.42)
	_host.write_construction_tag(anchor, "world_prop_id", id)
	_host.write_construction_tag(anchor, "world_prop_kind", kind)
	_host.write_construction_tag(anchor, "world_prop_state_key", state_key)
	_scope.zone_root.add_child(anchor)
	return anchor
func _make_broken_charm(name: String, pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees.y = yaw
	_scope.zone_root.add_child(root)
	_host._add_visual_box_child(root, "%sBoneHalfA" % name, Vector3(-0.08, 0.0, 0.0), Vector3(0.17, 0.035, 0.24), Color(0.54, 0.50, 0.42))
	_host._add_visual_box_child(root, "%sBoneHalfB" % name, Vector3(0.11, 0.0, 0.04), Vector3(0.15, 0.035, 0.20), Color(0.48, 0.45, 0.38))
	_host._add_visual_box_child(root, "%sRedThread" % name, Vector3(0.0, 0.024, -0.12), Vector3(0.38, 0.020, 0.045), Color(0.30, 0.035, 0.028))
func _mesh_needs_visible_fallback(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh == null:
		return true
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material: Variant = mesh_instance.get_active_material(surface_index)
		if material == null:
			return true
		if _host._is_bad_white_material(material) and not _host._surface_has_authored_colors(mesh_instance.mesh, surface_index, material):
			return true
	return mesh_instance.mesh.get_surface_count() == 0
func _valid_material_or_fallback(material: Material) -> Material:
	if material != null:
		return material
	if _host.world_materials != null and (_host.world_materials != null):
		return _host.world_materials.get_fallback_material()
	return _host._first_route_material("ground")
func _make_shrine_candle(pos: Vector3) -> void:
	_host._make_visual_box("ShrineCandle", pos + Vector3(0, 0.17, 0), Vector3(0.10, 0.34, 0.10), Color(0.72, 0.62, 0.44))
	var flame = MeshInstance3D.new()
	flame.name = "ShrineCandleFlame"
	var flame_mesh: Variant = SphereMesh.new()
	flame_mesh.radial_segments = 5
	flame_mesh.rings = 3
	flame.mesh = flame_mesh
	flame.scale = Vector3(0.07, 0.11, 0.07)
	flame.position = pos + Vector3(0, 0.39, 0)
	flame.material_override = _host._emissive_mat(Color(1.0, 0.48, 0.14), 1.1)
	_scope.zone_root.add_child(flame)
func _make_mourning_marker(pos: Vector3) -> void:
	_host._make_visual_box("MourningMarkerPost", pos + Vector3(0, 0.38, 0), Vector3(0.09, 0.76, 0.09), Color(0.11, 0.075, 0.050))
	_host._make_visual_box("MourningMarkerCross", pos + Vector3(0, 0.62, 0), Vector3(0.54, 0.07, 0.07), Color(0.11, 0.075, 0.050))
	_host._make_hanging_cloth(pos + Vector3(0.25, 0.45, 0.01), Vector3(0.18, 0.28, 0.025), Color(0.30, 0.030, 0.025))
func _is_bad_white_material(material: Material) -> bool:
	if material == null:
		return true
	if material is StandardMaterial3D:
		var standard = material as StandardMaterial3D
		var has_texture = standard.albedo_texture != null
		var color = standard.albedo_color
		return not has_texture and color.r > 0.85 and color.g > 0.85 and color.b > 0.85
	return false
func _surface_has_authored_colors(mesh: Mesh, surface_index: int, material: Material) -> bool:
	if not material is StandardMaterial3D or not (material as StandardMaterial3D).vertex_color_use_as_albedo:
		return false
	var arrays: Variant = mesh.surface_get_arrays(surface_index)
	if not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		return false
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if colors.size() != (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		return false
	for color in colors:
		if color.r <= 0.85 or color.g <= 0.85 or color.b <= 0.85:
			return true
	return false
