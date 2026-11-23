extends Node

const CastProfile = preload("res://scripts/story_cast_profile.gd")
const Presence = preload("res://scripts/character_presence.gd")
var actor: Node3D
var listener: Node3D
var driver: Node
var face: Node
var saved_modes: Dictionary = {}
var profile: Dictionary = {}
var elapsed := 0.0
var next_beat := 2.8
var active := false
var previous_clock: Dictionary = {}
var speaking := true
var pending_gesture := ""
var audio_source: Node
var delivery_active := false
var page_speaker := ""
var previous_attention: Dictionary = {}

static func begin(target: Node3D, player: Node3D, _dialogue: Dictionary = {}, state = null) -> void:
	if not is_instance_valid(target):
		return
	begin_actor(target, player, state)
	if is_instance_valid(player) and player != target:
		begin_actor(player, target, state)

static func begin_actor(target: Node3D, partner: Node3D, state: Variant = null) -> void:
	var performance := target.get_node_or_null("StoryPerformance")
	if performance != null and performance.active:
		return
	if performance == null:
		performance = load("res://scripts/story_performance.gd").new()
		performance.name = "StoryPerformance"
		target.add_child(performance)
	performance.start(target, partner, state)

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

static func finish_actor(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var performance := target.get_node_or_null("StoryPerformance")
	if performance != null:
		performance.stop()

static func speaker_matches(identity: String, speaker_id: String) -> bool:
	return preload("res://scripts/views/actor_dialogue_pose.gd").speaker_matches(identity, speaker_id)

static func page(target: Node3D, entry: Dictionary, audio: Node, speaker: Node3D, eyeline: Node3D, reacts: bool) -> void:
	var performance := target.get_node_or_null("StoryPerformance")
	if performance != null:
		performance.audio_source = audio
		performance.present_page(entry, target == speaker, eyeline, reacts)

func owns_speaker_identity(speaker: String) -> bool:
	if not active or not is_instance_valid(actor):
		return false
	var id := str(profile.get("id", ""))
	if speaker_matches(id, speaker):
		return true
	if id != "kael" and actor.has_method("is_interaction_enabled"):
		var actor_id := str(actor.get("interaction_id"))
		return preload("res://scripts/views/actor_dialogue_pose.gd").supporting_speaker(actor_id, speaker)
	return false

func present_page(entry: Dictionary, owns_voice: bool, eyeline: Node3D, reacts: bool) -> void:
	if not active or not is_instance_valid(actor):
		return
	page_speaker = str(entry.get("speaker_id", "")).to_lower()
	speaking = owns_voice
	delivery_active = false
	var direction: Dictionary = entry.get("performance", {})
	preload("res://scripts/views/actor_dialogue_pose.gd").apply_pose(driver, face, eyeline, speaking, reacts, profile, entry, direction)
	pending_gesture = ""
	if speaking:
		pending_gesture = str(direction.get("gesture", ""))
	elif reacts:
		pending_gesture = str(direction.get("listener_gesture", "remember" if str(direction.get("emotion", "")) == "grieving" else ""))
	next_beat = elapsed + float(direction.get("reaction_delay", 0.18))

func start(target: Node3D, player: Node3D, state: Variant) -> void:
	if active:
		stop()
	if not Presence.claim(target, "dialogue", get_instance_id()):
		return
	actor = target
	listener = player
	var role := str(actor.get_meta("story_actor_alias", actor.get_meta("character_identity_profile", "")))
	profile = CastProfile.get_profile(role, str(actor.name))
	if profile.is_empty():
		profile = CastProfile.presence_profile(role, str(actor.name))
	if actor.has_method("face_target"):
		profile = CastProfile.get_profile("player")
	driver = actor.find_child("CharacterAnimationDriver", true, false)
	face = actor.find_child("CharacterFaceDriver", true, false)
	if (is_instance_valid(driver) and bool(driver.dead)) or (driver == null and face == null):
		Presence.release(target, "dialogue", get_instance_id())
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = true
	speaking = true
	elapsed = 0.0
	next_beat = 2.8
	# Only staged participants' presentation continues through dialogue pause.
	# Physics, NPC schedules, combat and all surrounding actors remain paused.
	for node in actor.find_children("*", "", true, false):
		if node is AnimationPlayer or node is Skeleton3D or node is SkeletonModifier3D or node == driver or node == face or node is Timer and node.get_parent() in [driver, face]:
			saved_modes[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_ALWAYS
	if face != null:
		previous_attention = face.capture_attention()
	if driver != null:
		previous_clock = driver.capture_clock()
		driver.set_external_tick(false)
		driver.set_distance_suspended(false)
		driver.set_update_rate_hz(30.0)
		driver.set_dialogue_pose(true)
	if face != null:
		face.set_conversation_active(true)
		face.set_distance_suspended(false)
		face.set_focus_target(listener)
		face.set_expression(CastProfile.expression_for(profile, state))
	set_process(true)

func _process(delta: float) -> void:
	if not active or not is_instance_valid(actor) or is_instance_valid(driver) and bool(driver.dead):
		stop()
		return
	var delivery: Dictionary = audio_source.get_dialogue_delivery() if is_instance_valid(audio_source) else {}
	if bool(delivery.get("paused", false)):
		if is_instance_valid(face):
			face.set_speech_amount(0.0)
		return
	var delivering: bool = speaking and bool(delivery.get("playing", false)) and speaker_matches(page_speaker, str(delivery.get("speaker_id", "")))
	# A short line may end while the actor is still completing its gesture.
	var gesture_finishing := is_instance_valid(driver) and float(driver.story_gesture_remaining) > 0.0
	if delivering != delivery_active and (delivering or not gesture_finishing):
		delivery_active = delivering
		if is_instance_valid(driver): driver.set_story_listening(not delivering)
	if is_instance_valid(face):
		face.set_speech_amount(float(delivery.get("amplitude", 0.0)) if delivering else 0.0)
	elapsed += delta
	# Listeners can react during a held beat. The speaker's gesture waits for
	# the scheduled take, or uses the authored delay on a subtitle-only page.
	if pending_gesture != "" and elapsed >= next_beat and not (speaking and bool(delivery.get("pending", false))):
		var gesture := pending_gesture
		pending_gesture = ""
		if is_instance_valid(face):
			face.play_story_gesture(gesture)
		if is_instance_valid(driver) and gesture in ["offer", "explain", "acknowledge", "disagree", "recall", "remember", "reassure", "guarded_listening"]:
			driver.play_story_gesture(gesture, float(profile.get("pace", 0.9)))

func stop() -> void:
	if not active:
		return
	active = false
	if is_instance_valid(actor):
		Presence.release(actor, "dialogue", get_instance_id())
	pending_gesture = ""
	set_process(false)
	if is_instance_valid(driver):
		driver.stop_story_gesture()
		driver.restore_clock(previous_clock)
	previous_clock.clear()
	if is_instance_valid(face):
		face.set_speech_amount(0.0)
		face.restore_attention(previous_attention)
	previous_attention.clear()
	audio_source = null
	for node in saved_modes:
		if is_instance_valid(node):
			node.process_mode = saved_modes[node]
	saved_modes.clear()

func _exit_tree() -> void:
	stop()
