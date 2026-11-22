extends Node3D

const Interactable = preload("res://scripts/interactable.gd")
const OWNER := "BrackenFieldTrial"
const START := Vector3(-4.0, 0.0, 10.5)
const LANDMARKS := [
	{"name":"The worn wheel mark", "point":Vector3(-6.0, 0.0, 9.0)},
	{"name":"The linen knot", "point":Vector3(-2.0, 0.0, 9.0)},
	{"name":"The last cedar scrap", "point":Vector3(1.0, 0.0, 11.0)}
]
var game
var running := false
var scored := false
var elapsed := 0.0
var next_mark := 0
var markers: Array[Area3D] = []
var companion: WeakRef

static func install(host) -> void:
	if host.zone_root.get_node_or_null(OWNER) != null:
		return
	var trial = load("res://scripts/bracken_field_trial.gd").new()
	trial.name = OWNER
	trial.game = host
	host.zone_root.add_child(trial)
	trial._build()

static func stop_activity(host) -> void:
	if is_instance_valid(host.zone_root):
		var trial: Node = host.zone_root.get_node_or_null(OWNER)
		if trial != null:
			trial.cancel()

static func choose(host, action: Dictionary) -> void:
	host._resume_game()
	if not is_instance_valid(host.zone_root):
		return
	var trial: Node = host.zone_root.get_node_or_null(OWNER)
	if trial != null:
		trial.start(str(action.get("trial_mode", "")))

func _build() -> void:
	var invitation = Interactable.new()
	invitation.setup("lr_trial", "story_activity", "Bracken's field trial")
	invitation.position = START
	invitation.build_collision(0.8)
	add_child(invitation)
	invitation.add_to_group("story_activity")
	game._connect_interactable(invitation)

func activate(id: String) -> void:
	if id == "lr_trial":
		cancel()
		var dog: Node3D = game.zone_root.get_node_or_null("Bracken")
		if dog == null or not dog.adopted or dog.placement_pending or dog.global_position.distance_to(game.player.global_position) > 6.0:
			game.hud.toast("A game for you and Bracken. Bring him here when he is ready; the road needs no companion to explore.")
			return
		var best := float(game.story_state.get_flag("lr_trial_best_seconds", 0.0))
		game.get_tree().paused = true
		game.audio.set_game_paused(true)
		game.hud.show_dialogue({"name":"Bracken's field trial", "pages":[{"speaker":"The trail", "speaker_id":"narrator", "text":"Three cedar-scented marks along the southern road. Follow Bracken's nose, then inspect each mark yourself. No stakes, no missing person. Just a game." + (" Best time: %.1fs." % best if best > 0.0 else "")}], "actions":[{"type":"field_trial", "trial_mode":"practice", "label":"Practice together"}, {"type":"field_trial", "trial_mode":"scored", "label":"Ninety-second trial"}, {"type":"field_trial", "trial_mode":"decline", "label":"Leave the trail for now"}]})
	elif running and id.begins_with("lr_trial_mark_"):
		var index := int(id.trim_prefix("lr_trial_mark_"))
		if index != next_mark:
			game.hud.toast("This scent belongs later in the trail. Bracken turns back toward the earlier mark.")
		elif index < markers.size() and game.player.global_position.distance_to(markers[index].global_position) <= 2.5:
			next_mark += 1
			if next_mark == LANDMARKS.size():
				_finish()
			else:
				_indicate()

func start(mode: String) -> void:
	if mode not in ["practice", "scored"]:
		return
	var dog: Node3D = game.zone_root.get_node_or_null("Bracken")
	if not _available() or dog == null or not dog.adopted or dog.placement_pending or dog.global_position.distance_to(game.player.global_position) > 6.0 or game.player.global_position.distance_to(START) > 3.0:
		game.hud.toast("Start beside the southern trail marker with Bracken, out of danger.")
		return
	preload("res://scripts/greyfen_archery_range.gd").stop_activity(game)
	cancel()
	companion = weakref(dog)
	dog.cancel_care()
	running = true
	scored = mode == "scored"
	elapsed = 0.0
	next_mark = 0
	for index in LANDMARKS.size():
		var area = Interactable.new()
		area.setup("lr_trial_mark_" + str(index), "story_activity", str(LANDMARKS[index].name))
		area.position = LANDMARKS[index].point
		area.build_collision(0.65)
		add_child(area)
		area.add_to_group("story_activity")
		var post := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.035
		cylinder.bottom_radius = 0.05
		cylinder.height = 0.65
		cylinder.radial_segments = 6
		post.mesh = cylinder
		post.position.y = 0.325
		area.add_child(post)
		var knot := MeshInstance3D.new()
		var cloth := BoxMesh.new()
		cloth.size = Vector3(0.22, 0.12, 0.035)
		knot.mesh = cloth
		knot.position.y = 0.58
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.72, 0.75, 0.59)
		knot.material_override = material
		area.add_child(knot)
		game._connect_interactable(area)
		markers.append(area)
	_indicate()

func _available() -> bool:
	return is_instance_valid(game.player) and get_parent() == game.zone_root and game.current_zone_id == "greyfen" and not game.zone_transition_pending and not game._journey_load_pending() and not game.story_action_in_progress and game.pending_ending == "" and not game._story_has_active_combat() and game.player.health_component.health > 0.0

func _indicate() -> void:
	var dog = companion.get_ref() if companion != null else null
	if dog != null:
		dog.set_trial_direction(markers[next_mark].global_position)
	game.hud.toast("Trail %d/3: %s.%s" % [next_mark + 1, LANDMARKS[next_mark].name, " %.0fs remaining." % maxf(0.0, 90.0 - elapsed) if scored else " Take your time."], 4.0)

func _physics_process(delta: float) -> void:
	if not running:
		return
	var dog = companion.get_ref() if companion != null else null
	if not _available() or not game.input_router.is_gameplay_context() or dog == null or not dog.adopted or dog.sheltering or game.player.global_position.z < 7.3 or game.player.global_position.distance_to(START) > 17.0:
		cancel()
		return
	elapsed += delta
	if scored and elapsed >= 90.0:
		cancel()
		game.hud.toast("Time. Bracken found the best part already: going with you. Retry at the trail marker.", 5.0)

func _finish() -> void:
	var result := elapsed
	var timed := scored
	game.story_state.begin_change()
	if timed:
		var best := float(game.story_state.get_flag("lr_trial_best_seconds", 0.0))
		if best <= 0.0 or result < best:
			game.story_state.set_flag("lr_trial_best_seconds", result)
	var first := not bool(game.story_state.get_flag("lr_trial_acknowledged", false))
	game.story_state.set_flag("lr_trial_acknowledged", true)
	game.story_state.end_change()
	cancel()
	game.hud.toast(("Bracken brings his nose to your hand. Nothing needed rescuing this time. " if first else "Three marks, all found together. ") + ("%.1fs. " % result if timed else "") + "Return to the marker for another go.", 6.0)
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")

func cancel() -> void:
	var dog = companion.get_ref() if companion != null else null
	if is_instance_valid(dog):
		dog.clear_trial_direction()
	companion = null
	running = false
	for area in markers:
		if is_instance_valid(area):
			remove_child(area)
			area.queue_free()
	markers.clear()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		cancel()
