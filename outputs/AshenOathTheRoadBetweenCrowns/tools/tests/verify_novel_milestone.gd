extends "res://tools/verify_community_world_input.gd"

## Read-only observations after continuing an explicitly labelled boundary journey.
## Story progression is earned through physical movement, normal Use and dialogue.
func _ready(expected: String) -> void:
	if not failures.is_empty(): return
	var deadline := Time.get_ticks_msec()+240000
	var sample := 0
	while Time.get_ticks_msec()<deadline:
		if game.game_started and str(game.current_zone_id)==expected and not game.zone_transition_pending and not game.zone_load_request_pending and not game._journey_load_pending() and game.pending_player_restore.is_empty() and is_instance_valid(game.player) and game.player.can_control and not paused:
			await _frames(8)
			return
		if Time.get_ticks_msec()>=sample:
			sample=Time.get_ticks_msec()+20000
			print("NOVEL ARRIVAL ",expected," ",game.world_transition.snapshot()," game_started=",game.game_started," paused=",paused," menu=",game.hud.active_menu," frames=",game.zone_transition_frames," transition=",game.zone_transition_pending," restore=",game.journey_continuity.restore_request().get("phase","")," control=",game.player.can_control if is_instance_valid(game.player) else false)
		await process_frame
	_fail("No playable arrival at "+expected)

func _interact(id: String) -> void:
	# A player can turn and Use from the aisle without circling a reading desk.
	var target := game.zone_root.find_child(id,true,false) as Node3D
	if target != null and target.is_visible_in_tree() and game.player.global_position.distance_to(target.global_position)<3.0:
		await _face(target.global_position)
		await _frames(6)
		if game.active_interactable==target:
			await _tap(KEY_E)
			await _frames(6)
			return
	await super._interact(id)

func _walk_direct(target: Vector3, stop_zone: String="") -> void:
	if not failures.is_empty(): return
	var deadline := Time.get_ticks_msec()+150000
	var distance := INF
	var stagnant_ticks := 0
	while Time.get_ticks_msec()<deadline:
		if stop_zone!="" and (game.current_zone_id!=stop_zone or game.zone_transition_pending): break
		var offset: Vector3 = target-game.player.global_position
		offset.y = 0
		if offset.length() < 0.36: break
		if paused or not game.player.can_control:
			_fail("Walking lost input ownership in "+str(game.hud.active_menu))
			break
		if offset.length()+0.035 < distance:
			distance = offset.length()
			stagnant_ticks = 0
		else: stagnant_ticks += 2
		if stagnant_ticks > 240: break
		var direction := offset.normalized()
		var forward: float = direction.dot(game.camera_rig.get_flat_forward())
		var right: float = direction.dot(game.camera_rig.get_flat_right())
		_key(KEY_W, forward>0.38)
		_key(KEY_S, forward< -0.38)
		_key(KEY_D, right>0.38)
		_key(KEY_A, right< -0.38)
		await physics_frame
		await physics_frame
	if Time.get_ticks_msec()>=deadline or stagnant_ticks>240:
		var blockers: Array[String]=[]
		for index in game.player.get_slide_collision_count():
			var collision: KinematicCollision3D = game.player.get_slide_collision(index)
			if collision.get_collider() is Node3D: blockers.append("%s at %s normal %s"%[collision.get_collider().get_path(),collision.get_collider().global_position,collision.get_normal()])
		_fail("Walk to %s stopped at %s; velocity %s; colliders %s; menu %s"%[target,game.player.global_position,game.player.velocity,blockers,game.hud.active_menu])
	await _release()

func _initialize() -> void:
	output = OS.get_environment("ASHEN_NOVEL_EVIDENCE")
	case_id = output.get_file()
	var scene_key := str(FileAccess.get_file_as_string(output.path_join("scene.txt"))).strip_edges()
	if output.is_empty() or scene_key not in ["tor_wrist","seals","dry_floor","spring_open_road"] or DisplayServer.get_name().to_lower()=="headless":
		quit(2)
		return
	start_ms = Time.get_ticks_msec()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	topology = load("res://scripts/world_sector_manifest.gd")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(game)
	await _frames(8)
	var deadline := Time.get_ticks_msec()+420000
	while Time.get_ticks_msec()<deadline:
		var available := false
		for control: Button in root.find_children("*","Button",true,false):
			if control.is_visible_in_tree() and not control.disabled and control.text.begins_with("Continue"):
				available=true
				break
		if available or game.startup_prepare_failed: break
		await process_frame
	await _button("Continue")
	region = {"tor_wrist":"old_mill","seals":"record_hall","dry_floor":"hearthward","spring_open_road":"hearthward"}[scene_key]
	await _ready(region)
	report_extra={"seed":"synthetic_boundary","scene":scene_key,"full_campaign_proof":false}
	if not failures.is_empty():
		await _finish()
		return
	var story=game.story_state
	_check(story.get_flag("novel_edition",0)==1,"New literary edition loaded")
	var layer: Node = game.zone_root.get_node_or_null("StoryActivities/NovelScenes")
	if layer==null or not layer.turns.has(scene_key):
		_fail("Required scene absent on actual restored sector: "+scene_key)
		await _finish()
		return
	var sequence: Array=layer.turns[scene_key].scene.beats
	var original_day := int(game.day_night.day_count)
	for index in range(int(story.get_flag("novel_step_"+scene_key,0)),sequence.size()):
		if not failures.is_empty(): break
		await _interact("novel_%s_%d"%[scene_key,index])
		if sequence[index].has("choices"): await _dialogue_button(sequence[index].choices[0].label)
		var limit := Time.get_ticks_msec()+18000
		while failures.is_empty() and int(story.get_flag("novel_step_"+scene_key,0))==index and Time.get_ticks_msec()<limit: await process_frame
		_check(int(story.get_flag("novel_step_"+scene_key,0))==index+1,"Earned "+str(sequence[index].prompt))
		if index==0 and failures.is_empty():
			await _save_reload(scene_key+"_in_progress")
			story=game.story_state
			_check(int(story.get_flag("novel_step_"+scene_key,0))==1,"Continue restored the next physical step")
	if failures.is_empty():
		_check(bool(story.get_flag("novel_done_"+scene_key,false)),"Reached the scene consequence")
		if scene_key=="spring_open_road": _check(int(game.day_night.day_count)==original_day+180,"Explicit spring visit advanced 180 days once")
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(output.path_join(scene_key+".png"))==OK,"Recorded the playable scene")
	await _finish()
