extends Node
class_name StoryEncounterDirector

## Small, evidence-earned opportunities. No health, damage or reward changes.
## The enemy remains authoritative for collision, animation and attack timing.
var host
var actor
var reading_phases: Dictionary = {}
var recovery_phases: Dictionary = {}
var current_preparation: Dictionary = {}

static func apply(game, enemy) -> void:
	if game == null or enemy == null or enemy.get_node_or_null("StoryEncounterPreparation") != null:
		return
	if str(enemy.enemy_id) not in ["bell_eater", "bog_wretch", "ashwing", "halvern_boss", "white_hart_avatar"]:
		return
	var director = load("res://scripts/story_encounter_director.gd").new()
	director.name = "StoryEncounterPreparation"
	director.host = game
	director.actor = enemy
	enemy.add_child(director)
	director.configure()

func configure() -> void:
	actor.windup_started.connect(_on_windup)
	actor.special_attack_resolved.connect(_on_special_resolved)
	actor.parry_window_opened.connect(_on_parry_window)
	_refresh_preparation()

func _refresh_preparation() -> void:
	current_preparation = {}
	if host == null or actor == null:
		return
	match str(actor.enemy_id):
		"bell_eater":
			var graves := 0
			for id in ["grave_harl", "grave_child", "grave_soldier"]:
				if _known(id, "main_bell_beneath_greyfen", id):
					graves += 1
			if graves >= 2:
				current_preparation = {"reading":0.16, "recovery":0.65, "tell":"The cut ropes join beneath the graves. Watch the clapper lift, then step clear of its ring.", "opening":"The bell's swing is spent. The graves showed where its pull would end.", "moves":["bell_shockwave", "grave_slam", "ghoulkin_call"]}
		"bog_wretch":
			if _known("chapel_names", "main_teeth_in_rain", "read_chapel_names") and _known("ritual_stones", "main_teeth_in_rain", "name_the_dead"):
				current_preparation = {"reading":0.12, "tell":"Oren's name makes the Wretch hesitate before its first approach. Moon Oil and a clean interruption can expose the memory it carries.", "moves":[]}
		"ashwing":
			if _known("mill_accounts", "main_ash_at_the_mill", "inspect_millstones") or _known("mill_ventilation", "", "") or bool(host.story_state.get_flag("mill_ventilation_open", false)):
				current_preparation = {"reading":0.14, "recovery":0.60, "tell":"The mill dust follows its breath. Read the shoulder turn and move across the plume, not back along it.", "opening":"The breath passed clear. Ashwing must gather itself before turning again.", "moves":["ash_breath", "wing_blast", "swoop"]}
		"halvern_boss":
			if bool(host.story_state.get_flag("command_proof_recovered", false)) or _known("command_proof", "main_blood_under_stone", "recover_ledger"):
				current_preparation = {"reading":0.12, "parry":0.30, "tell":"The command record names Halvern's refusal. Read his raised guard; a clean parry opens time to hear him, not only to strike.", "opening":"His guard is open. The recovered order gives Kael a question the knight can answer.", "moves":["parry_test", "counter_lunge"]}
		"white_hart_avatar":
			if bool(host.story_state.get_flag("command_proof_recovered", false)) and bool(host.story_state.get_flag("crisis_cause_known", false)):
				current_preparation = {"reading":0.12, "tell":"The human record gives the memory an order: gate, road, then soldiers. Watch where the echo finishes before the antlers follow.", "moves":[]}
	if not current_preparation.is_empty():
		actor.set_meta("story_preparation", str(current_preparation.get("tell", "")))

func _known(id: String, quest_id: String, objective_id: String) -> bool:
	if host.story_state.has_evidence(id):
		return true
	if quest_id != "" and objective_id != "":
		var key := "%s:%s" % [quest_id, objective_id]
		if bool(host.quests.evidence_history.get(key, false)):
			return true
		# Active objective arrays still describe actual inspection. A completed
		# quest alone cannot prove that an optional clue was ever discovered.
		if host.quests.is_active(quest_id) and host.quests.is_objective_done(quest_id, objective_id):
			return true
	return false

func preparation_windup_bonus() -> float:
	_refresh_preparation()
	if current_preparation.is_empty():
		return 0.0
	var phase := str(actor.boss_phase)
	if bool(reading_phases.get(phase, false)):
		return 0.0
	reading_phases[phase] = true
	actor.set_meta("story_prepared_reading_pending", true)
	return float(current_preparation.get("reading", 0.0))

func _on_windup(_enemy) -> void:
	if bool(actor.get_meta("story_prepared_reading_pending", false)):
		actor.set_meta("story_prepared_reading_pending", false)
		_cue(str(current_preparation.get("tell", "")))

func _on_special_resolved(_enemy, move: String, _position: Vector3, _radius: float, dealt: float, parried: bool) -> void:
	if current_preparation.is_empty() or parried or dealt > 0.0 or move not in current_preparation.get("moves", []):
		return
	var phase := str(actor.boss_phase)
	if bool(recovery_phases.get(phase, false)) or not current_preparation.has("recovery"):
		return
	recovery_phases[phase] = true
	# Only a successfully avoided prepared action creates the opening.
	actor.attack_recovery_time = maxf(float(actor.attack_recovery_time), float(current_preparation.recovery))
	_cue(str(current_preparation.get("opening", "An opening follows the avoided attack.")))

func _on_parry_window(_enemy, duration: float) -> void:
	if not current_preparation.has("parry"):
		return
	var phase := str(actor.boss_phase)
	if bool(recovery_phases.get(phase, false)):
		return
	recovery_phases[phase] = true
	var opening := duration + float(current_preparation.parry)
	actor.parry_exposed_time = maxf(float(actor.parry_exposed_time), opening)
	actor.stagger(opening)
	_cue(str(current_preparation.get("opening", "The recovered account gives this opening a purpose.")))

func _cue(text: String) -> void:
	if text == "" or host.hud == null:
		return
	host.hud.set_guidance_hint(text, 5.0)
	host.hud.show_status_cue("Preparation remembered", "item")
