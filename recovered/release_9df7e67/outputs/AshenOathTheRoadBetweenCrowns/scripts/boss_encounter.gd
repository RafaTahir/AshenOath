extends Node
class_name BossEncounter

## Data-driven boss coordinator. EnemyAI remains authoritative for movement,
## collision, health, and damage; this node owns phase checkpoints and
## peaceful-resolution metadata.

signal phase_changed(boss_id: String, phase: int)
signal checkpoint_saved(boss_id: String, phase: int)
signal resolved(boss_id: String, outcome: String)

var boss_id := ""
var definition: Dictionary = {}
var enemy: Node
var host: Node
var phase := 1
var outcome := ""
var checkpoint := 1
var checkpoint_health_ratio := 1.0
var resolution_emitted := false

func configure(id: String, boss_definition: Dictionary, boss_actor: Node, owner: Node) -> void:
	boss_id = id
	definition = boss_definition.duplicate(true)
	enemy = boss_actor
	host = owner
	phase = int(definition.get("starting_phase", 1))
	checkpoint = phase
	checkpoint_health_ratio = 1.0
	outcome = ""
	resolution_emitted = false
	if enemy != null:
		enemy.set_meta("boss_id", boss_id)
		enemy.set_meta("boss_phase", phase)
		if enemy.has_signal("boss_phase_changed") and not enemy.boss_phase_changed.is_connected(_on_enemy_phase_changed):
			enemy.boss_phase_changed.connect(_on_enemy_phase_changed)
		if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)

func _on_enemy_phase_changed(_actor: Node, next_phase: int) -> void:
	if outcome != "":
		return
	phase = next_phase
	checkpoint = phase
	checkpoint_health_ratio = _current_health_ratio()
	if enemy != null:
		enemy.set_meta("boss_phase", phase)
		if enemy.has_method("apply_boss_phase_visual"):
			enemy.apply_boss_phase_visual(phase)
	phase_changed.emit(boss_id, phase)
	checkpoint_saved.emit(boss_id, phase)
	if host != null and host.has_method("_on_boss_checkpoint"):
		host._on_boss_checkpoint(self)

func _on_enemy_died(_actor: Node) -> void:
	if outcome != "":
		return
	outcome = "defeated"
	checkpoint = phase
	checkpoint_health_ratio = 0.0
	_emit_resolved()

func can_peaceful_resolve() -> bool:
	if outcome != "" or not bool(definition.get("peaceful_resolution", false)):
		return false
	if boss_id == "halvern_boss" and host != null:
		return bool(host.story_state.get_flag("halvern_guard_broken", false)) or bool(host.story_state.get_flag("command_proof_recovered", false)) or bool(host.story_state.get_flag("halvern_surrender_protected", false))
	return true

func resolve_peaceful(next_outcome: String) -> bool:
	if not can_peaceful_resolve() or enemy == null or bool(enemy.get("dead")):
		return false
	outcome = next_outcome.strip_edges().to_lower()
	if outcome == "":
		outcome = ""
		return false
	if outcome in ["defeated", "", "pending"]:
		outcome = ""
		return false
	enemy.set_meta("peaceful_resolution", outcome)
	enemy.set_meta("boss_resolved", true)
	if enemy.has_method("set_encounter_active"):
		enemy.set_encounter_active(false)
	resolution_emitted = false
	if host != null and host.has_method("_on_boss_peaceful_resolution"):
		host._on_boss_peaceful_resolution(boss_id, outcome, enemy)
	_emit_resolved()
	return true

func is_resolved() -> bool:
	return outcome != ""

func get_encounter_state() -> Dictionary:
	return {
		"boss_id": boss_id,
		"phase": phase,
		"checkpoint": checkpoint,
		"outcome": outcome,
		"checkpoint_health_ratio": checkpoint_health_ratio,
		"telegraph": current_telegraph(),
		"peaceful_available": can_peaceful_resolve(),
		"resolved": is_resolved(),
	}

func _emit_resolved() -> void:
	if resolution_emitted:
		return
	resolution_emitted = true
	resolved.emit(boss_id, outcome)
	if is_instance_valid(enemy):
		var presentation := enemy.get_node_or_null("StoryEncounterPreparation")
		if presentation != null and presentation.has_method("acknowledge_resolution"):
			presentation.acknowledge_resolution(outcome)

func save_state() -> Dictionary:
	var health_state: Dictionary = {}
	if enemy != null and is_instance_valid(enemy):
		var health = enemy.get("health_component")
		if health != null and is_instance_valid(health) and health.has_method("save_state"):
			health_state = health.save_state()
	return {
		"boss_id": boss_id,
		"phase": phase,
		"checkpoint": checkpoint,
		"outcome": outcome,
		"checkpoint_health_ratio": checkpoint_health_ratio,
		"health": health_state,
		"called_ghoulkin": bool(enemy.get_meta("called_ghoulkin", false)) if enemy != null else false,
		"resolved": is_resolved(),
	}

func load_state(data: Dictionary) -> void:
	phase = _saved_phase(data.get("phase", phase), phase)
	checkpoint = maxi(phase, _saved_phase(data.get("checkpoint", phase), phase))
	outcome = str(data.get("outcome", outcome))
	resolution_emitted = false
	var ratio: Variant = data.get("checkpoint_health_ratio", _phase_health_ratio(phase))
	checkpoint_health_ratio = _phase_health_ratio(phase)
	if typeof(ratio) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(ratio)):
		checkpoint_health_ratio = clampf(float(ratio), 0.0, 1.0)
	if enemy != null:
		enemy.set_meta("boss_phase", phase)
		enemy.set_meta("called_ghoulkin", bool(data.get("called_ghoulkin", enemy.get_meta("called_ghoulkin", false))))
		if enemy.has_method("set") and enemy.get("base_move_speed") != null and enemy.get("base_damage") != null:
			var phase_index := clampi(phase - 1, 0, 2)
			enemy.set("boss_phase", phase)
			enemy.set("move_speed", float(enemy.get("base_move_speed")) * [1.0, 1.10, 1.18][phase_index])
			enemy.set("damage", float(enemy.get("base_damage")) * [1.0, 1.08, 1.15][phase_index])
		if enemy.has_method("apply_boss_phase_visual"):
			enemy.apply_boss_phase_visual(phase)
		if outcome != "":
			enemy.set_meta("boss_resolved", true)
			if enemy.has_method("set_encounter_active"):
				enemy.set_encounter_active(false)
		var health = enemy.get("health_component")
		var saved_health = data.get("health", {})
		if health != null and is_instance_valid(health) and health.has_method("load_state") and typeof(saved_health) == TYPE_DICTIONARY and not saved_health.is_empty():
			health.load_state(saved_health)
		elif health != null and is_instance_valid(health) and health.has_method("load_state") and outcome == "":
			var restored_ratio := checkpoint_health_ratio
			health.load_state({"health": health.max_health * restored_ratio, "max_health": health.max_health, "dead": false})

func current_telegraph() -> String:
	var phase_data := phase_definition()
	return str(phase_data.get("telegraph", ""))

func _saved_phase(value: Variant, fallback: int) -> int:
	var count := maxi(1, (definition.get("phases", []) as Array).size())
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return clampi(fallback, 1, count)
	var number := float(value)
	if not is_finite(number) or number != floorf(number):
		return clampi(fallback, 1, count)
	return int(clampf(number, 1.0, float(count)))

func phase_definition() -> Dictionary:
	var phases: Array = definition.get("phases", [])
	if phases.is_empty():
		return {}
	return phases[clampi(phase - 1, 0, phases.size() - 1)]

func _current_health_ratio() -> float:
	if enemy == null or not is_instance_valid(enemy):
		return checkpoint_health_ratio
	var health = enemy.get("health_component")
	if health == null or not is_instance_valid(health) or float(health.max_health) <= 0.0:
		return checkpoint_health_ratio
	return clampf(float(health.health) / float(health.max_health), 0.0, 1.0)

func _phase_health_ratio(value: int) -> float:
	var phases: Array = definition.get("phases", [])
	if phases.is_empty():
		return 1.0
	var data: Dictionary = phases[clampi(value - 1, 0, phases.size() - 1)]
	return clampf(float(data.get("health_ratio", 1.0)), 0.0, 1.0)
