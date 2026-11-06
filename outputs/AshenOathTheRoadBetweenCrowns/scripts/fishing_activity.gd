extends Node3D

## A stationary leisure action, owned and interrupted by StoryActivities.
const Presence = preload("res://scripts/character_presence.gd")
var host
var owner_service
var station: Node3D
var rig: Node3D
var rod: Node3D
var line: MeshInstance3D
var bobber: MeshInstance3D
var overlay: CanvasLayer
var status: Label
var action: Button
var meter: ProgressBar
var stage := "ready"
var elapsed := 0.0
var tension := 0.0
var landed := 0.0
var reeling := false
var start_position := Vector3.ZERO
var water := Vector3.ZERO
var catch_id := "river_dace"
var closed := false
var line_mesh := ImmediateMesh.new()

func begin(service, area: Node3D, endpoint: Vector3) -> bool:
	host = service.host
	owner_service = service
	station = area
	if not service.safe_station(area) or host.inventory.owned_count("river_dace")+host.inventory.owned_count("copper_perch") >= 6: return false
	if not Presence.claim(host.player,"work",get_instance_id()): return false
	host.player.set_meta("cast_work_cancel",finish)
	start_position = host.player.global_position
	water = endpoint
	host.player._request_equipment(host.player.weapon_mode,host.player.get_selected_blade_id(),false)
	host.input_router.set_ui_context("minigame")
	rig = Node3D.new()
	add_child(rig)
	rod = (load("res://assets/everyday/fishing_rod.glb") as PackedScene).instantiate()
	rig.add_child(rod)
	line = MeshInstance3D.new()
	line.mesh = line_mesh
	line.material_override = host._mat(Color(0.57,0.5,0.33))
	rig.add_child(line)
	bobber = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	bobber.mesh = sphere
	bobber.material_override = host._mat(Color(0.88,0.65,0.28))
	rig.add_child(bobber)
	bobber.global_position = water
	_ui()
	return true

func _ui() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 65
	add_child(overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -155
	margin.offset_left = 18
	margin.offset_right = -18
	overlay.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "A borrowed rod. Six fresh fish fit in your pack."
	column.add_child(status)
	meter = ProgressBar.new()
	meter.show_percentage = false
	meter.custom_minimum_size.y = 12
	column.add_child(meter)
	var row := HBoxContainer.new()
	column.add_child(row)
	action = Button.new()
	action.text = "Cast"
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var metrics: Dictionary = host.hud.get("_display_metrics")
	var layout := preload("res://scripts/hud_layout_policy.gd").resolve(get_viewport().get_visible_rect().size,metrics,1.0,"touch")
	action.custom_minimum_size.y = maxf(48.0,float(layout.button_min_height))
	row.add_child(action)
	action.button_down.connect(_press)
	action.button_up.connect(func(): reeling=false)
	var leave := Button.new()
	leave.text = "Return the rod"
	leave.custom_minimum_size.y = action.custom_minimum_size.y
	row.add_child(leave)
	leave.pressed.connect(finish)
	action.grab_focus()

func _press() -> void:
	if stage == "ready":
		stage = "waiting"
		elapsed = 0.0
		var catches := int(host.story_state.get_flag("everyday_fish_catches",0))
		catch_id = "copper_perch" if catches % 4 == 3 else "river_dace"
		action.text = "Wait for the dip"
	elif stage == "bite":
		stage = "reeling"
		tension = 0.35
		landed = 0.0
		elapsed = 0.0
		action.text = "Hold to reel; release to ease"
		reeling = true
	elif stage == "reeling": reeling = true
	elif stage == "waiting":
		stage = "ready"
		action.text = "Cast again"
		status.text = "Too early. The fish keeps its distance."

func _physics_process(delta: float) -> void:
	if closed or not is_instance_valid(host) or not is_instance_valid(station): return
	if not owner_service.safe_station(station) or host.player.global_position.distance_to(start_position)>0.4 or host.player.hurt_react_time>0.0 or str(host.input_router.input_context) != "minigame":
		finish()
		return
	if host.player.equipment_loadout.is_transitioning(): return
	host.player.animation_driver.set_life_activity("fishing")
	var direction: Vector3 = (water-host.player.global_position).normalized()
	var hand: Vector3 = host.player.global_position+Vector3.UP*1.05+direction*0.35
	host.player.face_target(water)
	var skeleton: Skeleton3D = host.player.animation_driver.skeleton
	if is_instance_valid(skeleton):
		for alias: String in ["hand_r","Hand_R","RightHand"]:
			var bone := skeleton.find_bone(alias)
			if bone >= 0:
				hand = skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
				break
	rod.global_position = hand
	rod.look_at(hand+direction+Vector3.UP*0.25)
	rod.rotate_object_local(Vector3.RIGHT,-PI*0.5)
	elapsed += delta
	if stage == "waiting":
		status.text = "Watch the float."
		if elapsed >= 3.0+float(int(host.story_state.get_flag("everyday_fish_catches",0))%3):
			stage = "bite"
			elapsed = 0.0
			action.text = "Strike"
			status.text = "The float dips."
			host.audio.play_event("foliage_contact")
	elif stage == "bite" and elapsed > 1.6:
		stage = "ready"
		action.text = "Cast again"
		status.text = "The bite has passed."
	elif stage == "reeling":
		tension = clampf(tension+delta*((0.22 if catch_id=="copper_perch" else 0.17) if reeling else -0.3),0.0,1.0)
		landed += delta*(0.2 if reeling else -0.035)
		meter.value = tension*100.0
		status.text = "Line tension: %d%% | fish brought in: %d%%" % [int(tension*100),clampi(int(landed*100),0,100)]
		if tension>=1.0:
			stage="ready"
			reeling=false
			action.text="Cast again"
			status.text="The fish slips the hook. Ease the pull next time."
		elif landed>=1.0: _land()
	elif stage == "caught" and elapsed >= 2.0:
		finish()
		return
	bobber.global_position = water+Vector3.UP*(sin(elapsed*3.0)*0.025-(0.14 if stage=="bite" else 0.0))
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	line_mesh.surface_add_vertex(to_local(rod.to_global(Vector3(0,1.8,0))))
	line_mesh.surface_add_vertex(to_local(bobber.global_position))
	line_mesh.surface_end()

func _land() -> void:
	if host.inventory.owned_count("river_dace")+host.inventory.owned_count("copper_perch") < 6:
		host.story_state.set_flag("everyday_fish_catches",int(host.story_state.get_flag("everyday_fish_catches",0))+1)
		host.inventory.add_item(catch_id,1)
		owner_service.persist()
		var fish := (load("res://assets/everyday/"+catch_id+".glb") as PackedScene).instantiate()
		rig.add_child(fish)
		fish.global_position=host.player.global_position+Vector3.UP*1.1
		host.hud.toast("Caught "+host.inventory.get_item_name(catch_id)+". Keep it for a meal or Nessa's limited kitchen orders.")
	stage = "caught"
	elapsed = 0.0
	action.disabled = true

func finish() -> void:
	if closed:return
	closed=true
	if is_instance_valid(host) and is_instance_valid(host.player):
		if host.player.get_meta("cast_work_owner",0)==get_instance_id():
			host.player.animation_driver.clear_life_activity()
		Presence.release(host.player,"work",get_instance_id())
		if not get_tree().paused and str(host.input_router.input_context)=="minigame":
			host.input_router.set_gameplay_context()
	queue_free()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT] and is_instance_valid(host):
		finish()

func _exit_tree() -> void:
	if not closed: finish()
