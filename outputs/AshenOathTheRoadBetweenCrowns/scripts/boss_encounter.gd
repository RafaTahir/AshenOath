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

func configure(id: String, boss_definition: Dictionary, boss_actor: Node, owner: Node) -> void:
	boss_id = id
	definition = boss_definition.duplicate(true)
	enemy = boss_actor
	host = owner
	phase = int(definition.get("starting_phase", 1))
	checkpoint = phase
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
	if enemy != null:
		enemy.set_meta("boss_phase", phase)
	phase_changed.emit(boss_id, phase)
	checkpoint_saved.emit(boss_id, phase)
	if host != null and host.has_method("_on_boss_checkpoint"):
		host._on_boss_checkpoint(self)

func _on_enemy_died(_actor: Node) -> void:
	if outcome == "":
		outcome = "defeated"
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
	return {"boss_id": boss_id, "phase": phase, "checkpoint": checkpoint, "outcome": outcome}

func load_state(data: Dictionary) -> void:
	phase = maxi(1, int(data.get("phase", phase)))
	checkpoint = maxi(phase, int(data.get("checkpoint", phase)))
	outcome = str(data.get("outcome", outcome))
	if enemy != null:
		enemy.set_meta("boss_phase", phase)
		if enemy.has_method("set") and enemy.get("base_move_speed") != null and enemy.get("base_damage") != null:
			var phase_index := clampi(phase - 1, 0, 2)
			enemy.set("boss_phase", phase)
			enemy.set("move_speed", float(enemy.get("base_move_speed")) * [1.0, 1.10, 1.18][phase_index])
			enemy.set("damage", float(enemy.get("base_damage")) * [1.0, 1.08, 1.15][phase_index])

func phase_definition() -> Dictionary:
	var phases: Array = definition.get("phases", [])
	if phases.is_empty():
		return {}
	return phases[clampi(phase - 1, 0, phases.size() - 1)]
