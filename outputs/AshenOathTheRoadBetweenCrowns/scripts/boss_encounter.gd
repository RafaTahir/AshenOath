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

func configure(id: String, boss_definition: Dictionary, boss_actor: Node, owner: Node) -> void:
	boss_id = id
	definition = boss_definition.duplicate(true)
	enemy = boss_actor
	host = owner
	phase = int(definition.get("starting_phase", 1))
	checkpoint = phase
	checkpoint_health_ratio = 1.0
	if enemy != null:
		enemy.set_meta("boss_id", boss_id)
		enemy.set_meta("boss_phase", phase)
		if enemy.has_signal("boss_phase_changed") and not enemy.boss_phase_changed.is_connected(_on_enemy_phase_changed):
			enemy.boss_phase_changed.connect(_on_enemy_phase_changed)
		if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)

func _on_enemy_phase_changed(_actor: Node, next_phase: int) -> void:
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
	if outcome == "":
		outcome = "defeated"
	checkpoint = phase
	checkpoint_health_ratio = 0.0
	resolved.emit(boss_id, outcome)

func can_peaceful_resolve() -> bool:
	return bool(definition.get("peaceful_resolution", false))

func resolve_peaceful(next_outcome: String) -> bool:
	if not can_peaceful_resolve() or enemy == null or bool(enemy.get("dead")):
		return false
	outcome = next_outcome.strip_edges().to_lower()
	if outcome == "":
		return false
	enemy.set_meta("peaceful_resolution", outcome)
	enemy.set_meta("boss_resolved", true)
	if host != null and host.has_method("_on_boss_peaceful_resolution"):
		host._on_boss_peaceful_resolution(boss_id, outcome, enemy)
	resolved.emit(boss_id, outcome)
	return true

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
	}

func load_state(data: Dictionary) -> void:
	phase = maxi(1, int(data.get("phase", phase)))
	checkpoint = maxi(phase, int(data.get("checkpoint", phase)))
	outcome = str(data.get("outcome", outcome))
	checkpoint_health_ratio = clampf(float(data.get("checkpoint_health_ratio", _phase_health_ratio(phase))), 0.0, 1.0)
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
		var health = enemy.get("health_component")
		var saved_health = data.get("health", {})
		if health != null and is_instance_valid(health) and health.has_method("load_state") and typeof(saved_health) == TYPE_DICTIONARY and not saved_health.is_empty():
			health.load_state(saved_health)
		elif health != null and is_instance_valid(health) and health.has_method("load_state") and outcome == "":
			var restored_ratio := _phase_health_ratio(phase)
			health.load_state({"health": health.max_health * restored_ratio, "max_health": health.max_health, "dead": false})

func current_telegraph() -> String:
	var phase_data := phase_definition()
	return str(phase_data.get("telegraph", ""))

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
