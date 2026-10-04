extends Node

const CastProfile = preload("res://scripts/story_cast_profile.gd")
var actor: Node3D
var listener: Node3D
var driver: Node
var face: Node
var saved_modes: Dictionary = {}
var profile: Dictionary = {}
var elapsed := 0.0
var next_beat := 2.8
var active := false
var previous_external_tick := false
var previous_update_interval := 0.0
var speaking := true
var pending_gesture := ""
var audio_source: Node
var delivery_active := false
var page_speaker := ""
var previous_face_focus: Node3D
var previous_expression := "neutral"
var previous_face_suspended := false

static func begin(target: Node3D, player: Node3D, _dialogue: Dictionary = {}, state = null) -> void:
	if target == null or not is_instance_valid(target):
		return
	var performance := target.get_node_or_null("StoryPerformance")
	if performance == null:
		performance = load("res://scripts/story_performance.gd").new()
		performance.name = "StoryPerformance"
		target.add_child(performance)
	performance.start(target, player, state)
	if player != null and is_instance_valid(player) and player != target:
		var player_performance := player.get_node_or_null("StoryPerformance")
		if player_performance == null:
			player_performance = load("res://scripts/story_performance.gd").new()
			player_performance.name = "StoryPerformance"
			player.add_child(player_performance)
		player_performance.start(player, target, state)

static func finish(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var performance := target.get_node_or_null("StoryPerformance")
	if performance != null:
		var partner: Node3D = performance.listener
		if is_instance_valid(partner):
			var partner_performance := partner.get_node_or_null("StoryPerformance")
			if partner_performance != null and partner_performance.listener == target:
				partner_performance.stop()
		performance.stop()

static func page(target: Node3D, entry: Dictionary, audio: Node = null) -> void:
	if target == null or not is_instance_valid(target):
		return
	var performance := target.get_node_or_null("StoryPerformance")
	if performance != null:
		performance.audio_source = audio
		performance.present_page(entry)
		var partner: Node3D = performance.listener
		if is_instance_valid(partner):
			var partner_performance := partner.get_node_or_null("StoryPerformance")
			if partner_performance != null and partner_performance.listener == target:
				partner_performance.audio_source = audio
				partner_performance.present_page(entry)

func present_page(entry: Dictionary) -> void:
	var speaker := str(entry.get("speaker_id", "")).to_lower()
	page_speaker = speaker
	delivery_active = false
	var id := str(profile.get("id", ""))
	speaking = speaker != "narrator" and (speaker == "player" if id == "kael" else (id != "" and speaker.contains(id)))
	var direction: Dictionary = entry.get("performance", {})
	if driver != null:
		driver.set_story_listening(true)
	if face != null:
		var emotion := str(direction.get("emotion" if speaking else "listener_emotion", entry.get("emotion", profile.get("expression", "neutral"))))
		if emotion != "":
			face.set_expression(emotion)
	pending_gesture = str(direction.get("gesture", "")) if speaking else str(direction.get("listener_gesture", "remember" if str(direction.get("emotion", "")) == "grieving" else ""))
	next_beat = elapsed + float(direction.get("reaction_delay", 0.18))

func start(target: Node3D, player: Node3D, state) -> void:
	if active:
		stop()
	actor = target
	listener = player
	profile = CastProfile.get_profile(str(actor.get_meta("character_identity_profile", "")), str(actor.name))
	if actor.has_method("face_target"):
		profile = CastProfile.get_profile("player")
	driver = actor.find_child("CharacterAnimationDriver", true, false)
	face = actor.find_child("CharacterFaceDriver", true, false)
	if driver == null and face == null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = true
	speaking = true
	elapsed = 0.0
	next_beat = 2.8
	# Only the speaking actor's presentation continues through dialogue pause.
	# Physics, NPC schedules, combat and all surrounding actors remain paused.
	for node in actor.find_children("*", "", true, false):
		if node is AnimationPlayer or node is Skeleton3D or node is SkeletonModifier3D or node == driver or node == face or node is Timer and node.get_parent() in [driver, face]:
			saved_modes[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_ALWAYS
	if driver != null:
		previous_external_tick = bool(driver.get("externally_ticked"))
		previous_update_interval = float(driver.get("manual_update_interval"))
		driver.set_external_tick(false)
		driver.set_distance_suspended(false)
		driver.set_update_rate_hz(30.0)
		driver.set_dialogue_pose(true)
	if face != null:
		previous_face_focus = face.focus_target
		previous_expression = str(face.expression)
		previous_face_suspended = bool(face.distance_suspended)
		face.set_conversation_active(true)
		face.set_distance_suspended(false)
		face.set_focus_target(listener)
		face.set_expression(CastProfile.expression_for(profile, state))
	set_process(true)

func _process(delta: float) -> void:
	if not active or not is_instance_valid(actor):
		set_process(false)
		return
	var delivery: Dictionary = audio_source.get_dialogue_delivery() if is_instance_valid(audio_source) else {}
	var delivering: bool = speaking and bool(delivery.get("playing", false)) and str(delivery.get("speaker_id", "")).to_lower() == page_speaker
	if delivering != delivery_active:
		delivery_active = delivering
		if is_instance_valid(driver): driver.set_story_listening(not delivering)
	if is_instance_valid(face):
		face.set_speech_amount(float(delivery.get("amplitude", 0.0)) if delivering else 0.0)
	if bool(delivery.get("paused", false)): return
	elapsed += delta
	if pending_gesture != "" and elapsed >= next_beat:
		var gesture := pending_gesture
		pending_gesture = ""
		if face != null:
			face.play_story_gesture(gesture)
		if delivery_active and driver != null and gesture in ["offer", "explain"]:
			driver.play_story_gesture(gesture, float(profile.get("pace", 0.9)))

func stop() -> void:
	active = false
	pending_gesture = ""
	set_process(false)
	if is_instance_valid(driver):
		driver.stop_story_gesture()
		driver.set_update_rate_hz(1.0 / previous_update_interval if previous_update_interval > 0.0 else 0.0)
		driver.set_external_tick(previous_external_tick)
	if is_instance_valid(face):
		face.set_speech_amount(0.0)
		face.set_conversation_active(false)
		face.set_focus_target(previous_face_focus if is_instance_valid(previous_face_focus) else null)
		face.set_expression(previous_expression)
		face.set_distance_suspended(previous_face_suspended)
	audio_source = null
	for node in saved_modes:
		if is_instance_valid(node):
			node.process_mode = saved_modes[node]
	saved_modes.clear()
