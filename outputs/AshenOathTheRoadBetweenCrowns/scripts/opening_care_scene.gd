extends Node3D

## An optional human moment. StoryState owns progress; these objects only
## present it, including after a cached Greyfen tree is reactivated.
const Interactable = preload("res://scripts/interactable.gd")
const LAYER := "OpeningCareScene"
const TIMBER := Color(0.26, 0.18, 0.12)
const CLOTH := Color(0.37, 0.31, 0.27)
const LINEN := Color(0.67, 0.62, 0.48)
var host
var cup_area
var tray_area
var coat_area
var waiting_cup: Node3D
var delivered_cup: Node3D
var coat: Node3D
var carried_cup: Node3D
var carrier: Node3D
var hand_skeleton: Skeleton3D
var hand_bone := -1
var hinted := false

static func install(game, root: Node3D) -> void:
	var scene: Node = root.get_node_or_null(LAYER)
	if not bool(game.story_state.get_flag("opening_care_enabled", false)):
		if scene != null:
			root.remove_child(scene)
			scene.queue_free()
		return
	if scene == null:
		scene = load("res://scripts/opening_care_scene.gd").new()
		scene.name = LAYER
		scene.host = game
		root.add_child(scene)
		scene.build()
	scene.refresh()

static func introduce(game, actor: Node3D) -> bool:
	if not bool(game.story_state.get_flag("opening_care_enabled", false)) or bool(game.story_state.get_flag("opening_care_introduced", false)):
		return false
	if game.quests.is_objective_done("main_road_of_crows", "speak_anwen"):
		return false
	var scene: Node = game.zone_root.get_node_or_null(LAYER)
	if scene == null:
		return false
	scene.commit({"opening_care_introduced": true})
	if bool(game.story_state.get_flag("opening_cup_delivered", false)) and bool(game.story_state.get_flag("opening_coat_sheltered", false)):
		return false
	scene.show_scene("opening_care_invitation", actor)
	return true

func build() -> void:
	var anchor: Node3D = host.zone_root.find_child("AnwenAnchor", true, false) as Node3D
	position = host.zone_root.to_local(anchor.global_position) if anchor != null else Vector3(2, 0, -5)
	# Everything is resident procedural dressing: no new download before control.
	cup_area = point("opening_cup_pickup", "Take the waiting cup", Vector3(-0.85, 0, 1.4))
	box(cup_area, "StoneStep", Vector3(0, 0.10, 0), Vector3(0.60, 0.20, 0.48), Color(0.40, 0.39, 0.34))
	waiting_cup = make_cup(cup_area, Vector3(0, 0.205, 0))
	tray_area = point("opening_cup_deliver", "Set the water within reach", Vector3(-0.85, 0, -1.1))
	box(tray_area, "BedsideShelf", Vector3(0, 0.67, 0), Vector3(0.72, 0.065, 0.40), TIMBER)
	for x: float in [-0.27, 0.27]:
		box(tray_area, "ShelfLeg", Vector3(x, 0.33, 0), Vector3(0.065, 0.66, 0.065), TIMBER)
	box(tray_area, "CleanLinen", Vector3(0, 0.711, 0), Vector3(0.58, 0.015, 0.30), LINEN)
	delivered_cup = make_cup(tray_area, Vector3(-0.12, 0.72, 0))
	# A privacy screen locates the injured traveler without loading another rig.
	for x: float in [-0.60, 0.60]:
		box(tray_area, "ScreenPost", Vector3(x, 0.91, -0.54), Vector3(0.055, 1.82, 0.055), TIMBER)
	box(tray_area, "ScreenCrossbar", Vector3(0, 1.79, -0.54), Vector3(1.28, 0.055, 0.055), TIMBER)
	box(tray_area, "PrivacyLinen", Vector3(0, 1.02, -0.54), Vector3(1.17, 1.42, 0.018), LINEN)
	coat_area = point("opening_coat_shelter", "Fold Oren's coat out of the weather", Vector3(1.3, 0, 0.6))
	box(coat_area, "CoatBench", Vector3(0, 0.54, 0), Vector3(1.26, 0.08, 0.55), TIMBER)
	for x: float in [-0.49, 0.49]:
		box(coat_area, "BenchLeg", Vector3(x, 0.26, 0), Vector3(0.085, 0.52, 0.37), TIMBER)
	box(coat_area, "ShelteredShelf", Vector3(0.34, 0.92, -0.18), Vector3(0.62, 0.055, 0.38), TIMBER)
	box(coat_area, "ShelfBack", Vector3(0.34, 0.74, -0.34), Vector3(0.62, 0.38, 0.045), TIMBER)
	coat = Node3D.new()
	coat.name = "OrensMendedCoat"
	coat_area.add_child(coat)
	box(coat, "Body", Vector3.ZERO, Vector3(0.36, 0.035, 0.47), CLOTH)
	var left := box(coat, "LeftSleeve", Vector3(-0.21, 0, -0.09), Vector3(0.13, 0.03, 0.30), CLOTH)
	left.rotation.y = -0.45
	var right := box(coat, "RightSleeve", Vector3(0.21, 0, -0.09), Vector3(0.13, 0.03, 0.30), CLOTH)
	right.rotation.y = 0.45
	box(coat, "TurnedCollar", Vector3(0, 0.025, -0.205), Vector3(0.14, 0.025, 0.075), LINEN)
	for z: float in [-0.12, -0.03, 0.06]:
		box(coat, "HornButton", Vector3(0, 0.025, z), Vector3(0.024, 0.012, 0.024), Color(0.60, 0.49, 0.29))
	for z: float in [-0.10, -0.075, -0.05]:
		box(coat, "RedMending", Vector3(-0.23, 0.023, z), Vector3(0.085, 0.008, 0.008), Color(0.53, 0.20, 0.14))

func refresh() -> void:
	var early: bool = not host.quests.is_completed("main_road_of_crows")
	var carrying: bool = flag("opening_cup_carried") and not flag("opening_cup_delivered")
	set_available(cup_area, early and not carrying and not flag("opening_cup_delivered"))
	set_available(tray_area, carrying)
	set_available(coat_area, early and not flag("opening_coat_sheltered"))
	waiting_cup.visible = not carrying and not flag("opening_cup_delivered")
	delivered_cup.visible = flag("opening_cup_delivered")
	if not carrying:
		clear_carried_cup()
	coat.position = Vector3(0.28, 0.59, -0.04) if flag("opening_coat_sheltered") else Vector3(-0.24, 0.59, 0.12)
	coat.rotation.y = 0.0 if flag("opening_coat_sheltered") else -0.22
	coat.scale = Vector3(0.72, 1.7, 0.65) if flag("opening_coat_sheltered") else Vector3.ONE
	host.interaction_focus_dirty = true

func activate(id: String) -> void:
	match id:
		"opening_cup_pickup":
			if not cup_area.is_interaction_enabled(): return
			commit({"opening_cup_carried": true})
			host.hud.set_guidance_hint("Leave the water on the linen-covered tray beside the privacy screen.", 9.0)
		"opening_cup_deliver":
			if not tray_area.is_interaction_enabled(): return
			commit({"opening_cup_carried": false, "opening_cup_delivered": true})
			show_scene("opening_care_water")
		"opening_coat_shelter":
			if not coat_area.is_interaction_enabled(): return
			commit({"opening_coat_sheltered": true})
			show_scene("opening_care_coat")

func commit(flags: Dictionary) -> void:
	host.story_state.begin_change()
	for key: String in flags:
		host.story_state.set_flag(key, flags[key])
	host.story_state.end_change()
	refresh()
	host.story_save_pending = true
	host.call_deferred("_persist_story_action")

func show_scene(id: String, actor: Node3D = null) -> void:
	if actor == null:
		actor = host.zone_root.find_child("sister_anwen", true, false) as Node3D
	var content: Dictionary = host.dialogue.get_dialogue(id)
	if actor != null and actor.global_position.distance_to(global_position) < 5.0:
		host._stage_dialogue_moment(actor)
		preload("res://scripts/story_performance.gd").begin(actor, host.player, content, host.story_state)
	host.audio.set_dialogue_active(true)
	host.audio.set_game_paused(true)
	host.get_tree().paused = true
	host.hud.show_dialogue(content)

func _process(_delta: float) -> void:
	if host == null or host.current_zone_id != "greyfen" or host.player == null:
		return
	if not hinted and host.player.global_position.distance_to(global_position) < 4.0 and not flag("opening_care_introduced") and not flag("opening_cup_delivered"):
		hinted = true
		host.hud.set_guidance_hint("Anwen keeps water by the step. A small coat lies on the bench beside her.", 7.0)
	var carrying: bool = flag("opening_cup_carried") and not flag("opening_cup_delivered")
	if not carrying:
		clear_carried_cup()
		return
	if not is_instance_valid(carried_cup) or carrier != host.player:
		clear_carried_cup()
		carrier = host.player
		carried_cup = make_cup(carrier, Vector3.ZERO)
		carried_cup.name = "OpeningWaterCup"
		carried_cup.top_level = true
		var driver: Node = carrier.get("animation_driver") as Node
		hand_skeleton = driver.call("get_skeleton") as Skeleton3D if driver != null else null
		hand_bone = hand_skeleton.find_bone("hand_l") if hand_skeleton != null else -1
	var hand_position: Vector3 = carrier.global_transform * Vector3(-0.28, 0.90, -0.08)
	if is_instance_valid(hand_skeleton) and hand_bone >= 0:
		hand_position = (hand_skeleton.global_transform * hand_skeleton.get_bone_global_pose(hand_bone)).origin
	carried_cup.global_transform = Transform3D(Basis(Vector3.UP, carrier.global_rotation.y), hand_position + Vector3(0, -0.025, 0))

func _exit_tree() -> void:
	clear_carried_cup()

func clear_carried_cup() -> void:
	if is_instance_valid(carried_cup):
		carried_cup.queue_free()
	carried_cup = null
	carrier = null
	hand_skeleton = null
	hand_bone = -1

func flag(id: String) -> bool:
	return bool(host.story_state.get_flag(id, false))

func point(id: String, prompt: String, pos: Vector3) -> Area3D:
	var area := Interactable.new()
	area.setup(id, "story_activity", prompt)
	area.position = pos
	area.display_name = prompt
	area.build_collision(0.80)
	add_child(area)
	host._connect_interactable(area)
	return area

func set_available(area: Area3D, enabled: bool) -> void:
	area.call("set_interaction_enabled", enabled)
	if not enabled:
		host._remove_interaction_candidate(area)

func box(parent: Node3D, id: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = host._mat(color)
	parent.add_child(mesh)
	return mesh

func make_cup(parent: Node3D, pos: Vector3) -> Node3D:
	var cup := Node3D.new()
	cup.position = pos
	parent.add_child(cup)
	var shell := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.071
	cylinder.bottom_radius = 0.052
	cylinder.height = 0.13
	cylinder.radial_segments = 16
	shell.mesh = cylinder
	shell.position.y = 0.065
	shell.material_override = host._mat(Color(0.47, 0.30, 0.19))
	cup.add_child(shell)
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.061
	disc.bottom_radius = 0.061
	disc.height = 0.002
	disc.radial_segments = 16
	water.mesh = disc
	water.position.y = 0.131
	water.material_override = host._mat(Color(0.14, 0.22, 0.23))
	cup.add_child(water)
	var handle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.025
	ring.outer_radius = 0.040
	ring.rings = 12
	ring.ring_segments = 8
	handle.mesh = ring
	handle.position = Vector3(0.073, 0.065, 0)
	handle.rotation.x = PI / 2.0
	handle.material_override = shell.material_override
	cup.add_child(handle)
	return cup
