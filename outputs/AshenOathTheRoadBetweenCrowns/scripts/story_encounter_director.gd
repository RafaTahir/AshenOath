extends Node
class_name StoryEncounterDirector

## Evidence and small environmental actions alter a named encounter. EnemyAI
## remains authoritative for damage, collision and the actual telegraph clock.
var host
var actor
var reading_phases: Dictionary = {}
var recovery_phases: Dictionary = {}
var current_preparation: Dictionary = {}
var arena: Node3D
var rhythm_label: Label3D
var shelter_positions: Array[Vector3] = []
var root_positions: Array[Vector3] = []
var windup_length := 1.0
var cue_tick := 0.0
var last_beat := -1
var blocked_this_attack := false

static func apply(game, enemy) -> void:
	if game == null or enemy == null or enemy.get_node_or_null("StoryEncounterPreparation") != null:
		return
	if str(enemy.enemy_id) not in ["bell_eater", "rootbound_colossus", "bog_wretch", "ashwing", "halvern_boss", "white_hart_avatar"]:
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
	actor.died.connect(_on_death)
	_refresh_preparation()
	call_deferred("_build_arena")
	if actor.enemy_id == "halvern_boss" and bool(host.story_state.get_flag("halvern_surrender_protected", false)):
		_protect_surrender()

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
		"rootbound_colossus":
			current_preparation = {"reading":0.30, "recovery":0.9, "tell":"The roots feed the armored heart. Redirect two marked root channels; protect the name-board before it is swallowed.", "opening":"The broken root lane gives the heart time to open.", "moves":["root_lanes", "ground_rupture", "heart_stagger"]}
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
	var rope_bonus := 0.25 if actor.enemy_id == "bell_eater" and bool(host.story_state.get_flag("bell_rope_released", false)) else 0.0
	if current_preparation.is_empty():
		return rope_bonus
	var phase := str(actor.boss_phase)
	if bool(reading_phases.get(phase, false)):
		return rope_bonus
	reading_phases[phase] = true
	actor.set_meta("story_prepared_reading_pending", true)
	return float(current_preparation.get("reading", 0.0)) + rope_bonus

func _on_windup(_enemy) -> void:
	windup_length = maxf(float(actor.pending_attack_time), 0.01)
	last_beat = -1
	blocked_this_attack = false
	if bool(actor.get_meta("story_prepared_reading_pending", false)):
		actor.set_meta("story_prepared_reading_pending", false)
		_cue(str(current_preparation.get("tell", "")))

func _on_special_resolved(_enemy, move: String, _position: Vector3, _radius: float, dealt: float, parried: bool) -> void:
	if actor.enemy_id == "bell_eater" and bool(host.story_state.get_flag("bell_rope_released", false)):
		actor.attack_recovery_time = maxf(actor.attack_recovery_time, 1.6)
	if actor.enemy_id == "ashwing" and move in ["ash_breath", "swoop", "wing_blast"] and not bool(host.story_state.get_flag("mill_workers_rescued", false)):
		var smoke := int(host.story_state.get_flag("mill_smoke_exposure", 0))
		if not bool(host.story_state.get_flag("mill_ventilation_open", false)):
			host.story_state.set_flag("mill_smoke_exposure", mini(smoke + 1, 6))
			if smoke == 1:
				_cue("Smoke is reaching the workers. Open the sluice at the mill's south wall, then lead them to clean air.")
			_save()
	if actor.enemy_id == "ashwing" and bool(host.story_state.get_flag("ashwing_perch_grounded", false)):
		actor.attack_recovery_time = maxf(actor.attack_recovery_time, 1.3)
	if actor.enemy_id == "bell_eater" and blocked_this_attack:
		actor.attack_recovery_time = maxf(actor.attack_recovery_time, 1.25)
		_cue("The wave breaks against the mourning stone. The bell's return swing is your opening.")
	if actor.enemy_id == "rootbound_colossus" and _root_count() >= 2:
		actor.attack_recovery_time = maxf(actor.attack_recovery_time, 1.20)
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
	if actor.enemy_id == "halvern_boss":
		host.story_state.set_flag("halvern_guard_broken", true)
		host.story_state.set_flag("halvern_surrender_protected", true)
		_protect_surrender()
		_cue("Halvern lowers his blade. He will not strike or take damage while yielding. Speak to the memory behind him.")
		_save()
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

func _build_arena() -> void:
	if actor == null or not is_instance_valid(actor) or host.zone_root == null:
		return
	arena = Node3D.new()
	arena.name = "StoryArena_" + str(actor.enemy_id)
	actor.get_parent().add_child(arena)
	var origin: Vector3 = actor.global_position
	origin.y = 0.0
	match str(actor.enemy_id):
		"bell_eater":
			for offset in [Vector3(-3.0, 0, 1.8), Vector3(2.3, 0, 2.8)]:
				var point: Vector3 = origin + offset
				shelter_positions.append(point)
				_disc(point, 1.45, Color(0.53, 0.62, 0.58), "MOURNING STONE\nShelter inside the ring")
			_point("bell_restraint", "Loose the named bell rope during its return swing", origin + Vector3(-2.5, 0, -2.5), "THE NAMED ROPE")
			rhythm_label = _label(origin + Vector3(0, 3.5, 0), "WATCH THE CLAPPER / SHELTER ON THE THIRD BEAT")
		"rootbound_colossus":
			for index in range(3):
				var point: Vector3 = origin + [Vector3(-3.8, 0, 1.3), Vector3(3.8, 0, 1.8), Vector3(0, 0, 4.5)][index]
				root_positions.append(point)
				_disc(point, 1.30, Color(0.41, 0.53, 0.31), "ROOT CHANNEL %d" % (index + 1))
				_point("redirect_root_%d" % index, "Redirect root channel %d away from the name-board" % (index + 1), point, "TURN THE ROOT / EXPOSE THE HEART")
			rhythm_label = _label(origin + Vector3(0, 3.7, 0), "ROOT-BOUND HEART / REDIRECT TWO CHANNELS")
		"ashwing":
			rhythm_label = _label(origin + Vector3(0, 4.5, 0), "OPEN THE SLUICE / LEAD THE WORKERS OUT")
			if bool(host.story_state.get_flag("ashwing_perch_grounded", false)):
				actor.stagger(3.5)
		"halvern_boss":
			_point("halvern_present_order", "Present the copied command without raising your sword", origin + Vector3(-2.6, 0, 2.0), "THE REFUSED ORDER")
			rhythm_label = _label(origin + Vector3(0, 3.0, 0), "PARRY ONCE OR PRESENT THE COMMAND RECORD")
	if rhythm_label != null:
		rhythm_label.visibility_range_end = 22.0

func _physics_process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor) or actor.dead or not actor.encounter_active or rhythm_label == null:
		return
	cue_tick += delta
	if cue_tick < 0.1:
		return
	cue_tick = 0.0
	match str(actor.enemy_id):
		"bell_eater":
			if actor.pending_attack_time > 0.0:
				var beat := clampi(int((1.0 - float(actor.pending_attack_time) / windup_length) * 3.0), 0, 2)
				if beat != last_beat:
					last_beat = beat
					rhythm_label.text = ["I / THE CLAPPER LIFTS", "II / STEP INTO A MOURNING RING", "III / THE WAVE BREAKS"][beat]
			else:
				rhythm_label.text = "THE RETURN SWING / STRIKE OR LOOSEN THE ROPE"
		"rootbound_colossus":
			rhythm_label.text = "HEART EXPOSED / ROOT CHANNELS REDIRECTED" if _root_count() >= 2 else "ROOT-BOUND HEART / %d OF TWO CHANNELS REDIRECTED" % _root_count()
		"ashwing":
			if bool(host.story_state.get_flag("mill_workers_rescued", false)):
				rhythm_label.text = "WORKERS SAFE / READ THE SHOULDER BEFORE THE SWOOP"
			elif bool(host.story_state.get_flag("mill_escort_started", false)):
				rhythm_label.text = "KEEP NEAR THE WORKERS / SOUTH YARD IS CLEAR"
		"halvern_boss":
			if bool(actor.get_meta("story_surrender_protected", false)):
				rhythm_label.text = "THE BLADE IS LOWERED / HEAR HALVERN"

func blocks_attack(move: String) -> bool:
	if host.player == null or move == "":
		return false
	var position: Vector3 = host.player.global_position
	position.y = 0.0
	if actor.enemy_id == "bell_eater" and move in ["bell_shockwave", "grave_slam", "ghoulkin_call"]:
		for shelter in shelter_positions:
			if position.distance_to(shelter) <= 1.45:
				blocked_this_attack = true
				if not bool(host.story_state.get_flag("bell_rhythm_learned", false)):
					host.story_state.set_flag("bell_rhythm_learned", true)
					host.story_state.record_evidence("bell_shelter_rhythm", {"kind":"fact", "zone":"greyfen", "title":"The third beat breaks against a mourning stone"})
					_save()
				return true
	if actor.enemy_id == "rootbound_colossus" and move in ["root_lanes", "ground_rupture"]:
		for index in range(root_positions.size()):
			if bool(host.story_state.get_flag("root_redirected_%d" % index, false)) and position.distance_to(root_positions[index]) <= 1.3:
				return true
	return false

func incoming_damage_multiplier(source_tag: String) -> float:
	if actor.enemy_id == "rootbound_colossus" and _root_count() < 2:
		# Brute force remains possible, but the environmental interpretation is
		# visibly more effective. Oathfire interrupts the binding briefly.
		if source_tag in ["oathfire", "fire", "sign"]:
			actor.interrupt_boss_windup("oathfire_exposes_binding")
			actor.stagger(1.6)
			return 1.0
		return 0.62
	return 1.0

func interact(id: String) -> void:
	if actor == null or not is_instance_valid(actor) or actor.dead:
		return
	if id == "bell_restraint":
		if bool(host.story_state.get_flag("bell_rope_released", false)):
			_cue("The named rope is free. Use the longer return swing to silence the bell.")
			return
		if not bool(host.story_state.get_flag("bell_rhythm_learned", false)) and not _known("grave_soldier", "main_bell_beneath_greyfen", "grave_soldier"):
			_cue("Watch one third beat from a mourning ring, or read the soldier's grave to identify the named rope.")
			return
		if actor.pending_attack_time > 0.0:
			_cue("Wait for the wave to pass. The rope is taut until the return swing.")
			return
		host.story_state.set_flag("bell_rope_released", true)
		actor.stagger(4.0)
		actor.attack_cooldown = maxf(actor.attack_cooldown, 4.0)
		_cue("The soldier's name leaves the harness. The bell hangs off balance; its return swing stays open longer.")
	elif id.begins_with("redirect_root_"):
		var index := int(id.trim_prefix("redirect_root_"))
		var key := "root_redirected_%d" % index
		if bool(host.story_state.get_flag(key, false)):
			_cue("This channel is clear. Its marked circle shelters you from root ruptures.")
			return
		host.story_state.set_flag(key, true)
		actor.interrupt_boss_windup("root_channel_redirected")
		actor.stagger(2.0 if _root_count() < 2 else 4.0)
		actor.attack_cooldown = maxf(actor.attack_cooldown, 3.0)
		if _root_count() >= 2:
			host.story_state.set_flag("root_heart_exposed", true)
			_cue("Two roots turn away. The heart's armor opens; the testimony no longer feeds it.")
		else:
			_cue("One root turns away from the names. Clear a second channel to expose the heart.")
	elif id == "halvern_present_order":
		if not bool(host.story_state.get_flag("command_proof_recovered", false)) and not _known("command_proof", "main_blood_under_stone", "recover_ledger"):
			_cue("Without the command record, Kael can only show restraint: meet one strike with a parry, then hear Halvern.")
			return
		host.story_state.set_flag("halvern_guard_broken", true)
		host.story_state.set_flag("halvern_surrender_protected", true)
		host.quests.complete_objective("main_last_witness", "break_halvern_guard")
		_protect_surrender()
		_cue("Kael reads the refused order aloud. Halvern lowers his blade. Speak to the memory; it no longer needs to be defeated.")
	_save()

func _protect_surrender() -> void:
	actor.set_meta("story_surrender_protected", true)
	actor.stagger(0.5)
	actor.velocity = Vector3.ZERO
	actor.pending_attack_time = 0.0
	actor.windup_time = 0.0
	actor._hide_windup_marker()
	if actor.animation_driver != null:
		actor.animation_driver.set_locomotion(0.0, Vector3.ZERO, true)

func _root_count() -> int:
	var count := 0
	for index in range(3):
		if bool(host.story_state.get_flag("root_redirected_%d" % index, false)):
			count += 1
	return count

func _on_death(_enemy) -> void:
	if rhythm_label != null:
		rhythm_label.visible = false
	if actor.enemy_id == "rootbound_colossus":
		host.story_state.set_flag("root_landscape_released", _root_count() >= 2)
		if not bool(host.story_state.get_flag("root_testimony_protected", false)):
			host.story_state.set_flag("root_testimony_damaged", true)
	if actor.enemy_id == "ashwing":
		host.story_state.set_flag("mill_damage_state", "contained" if bool(host.story_state.get_flag("mill_ventilation_open", false)) else "scorched")
		_cue("The sluice kept the workers' route clear. Lead anyone still waiting to the south yard." if bool(host.story_state.get_flag("mill_ventilation_open", false)) else "The mill is scorched. The workers can still be brought out through the sluice.")
	_save()

func _save() -> void:
	host.story_save_pending = true
	host.call_deferred("_persist_story_action")

func _point(id: String, prompt: String, position: Vector3, text: String) -> void:
	var area = preload("res://scripts/interactable.gd").new()
	area.setup(id, "story_activity", prompt)
	area.position = position
	area.build_collision(1.0)
	area.set_meta("story_encounter_owner", actor.get_instance_id())
	arena.add_child(area)
	host._connect_interactable(area)
	_label(position + Vector3(0, 1.5, 0), text)

func _disc(position: Vector3, radius: float, color: Color, text: String) -> void:
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.025
	disc.radial_segments = 24
	mesh.mesh = disc
	mesh.position = position + Vector3(0, 0.045, 0)
	mesh.material_override = host._mat(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(mesh)
	_label(position + Vector3(0, 0.85, 0), text)

func _label(position: Vector3, text: String) -> Label3D:
	var label := Label3D.new()
	label.position = position
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 27
	label.pixel_size = 0.0045
	label.modulate = Color(0.96, 0.89, 0.68)
	label.outline_size = 7
	label.visibility_range_end = 16.0
	arena.add_child(label)
	return label
