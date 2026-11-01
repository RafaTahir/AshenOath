extends SceneTree
## Production damage and blade resolver, with no imported models or save data.

const Enemy = preload("res://scripts/enemy_ai.gd")
const Health = preload("res://scripts/health_component.gd")
const Combat = preload("res://scripts/combat_manager.gd")
const Inventory = preload("res://scripts/inventory_manager.gd")

class BladePlayer extends CharacterBody3D:
	func is_blade_ready() -> bool: return true
	func get_selected_blade_id() -> String: return "steel"

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var stage := Node3D.new()
	root.add_child(stage)
	var increases: Array[String] = []
	for id: String in definitions:
		var definition: Dictionary = definitions[id]
		var enemy := _enemy(stage, id, definition)
		for source_tag: String in ["", "spirit", "undead", "moon_oil", "rot_oil", "ash_bomb", "iron_trap", "oathfire", "unrelated"]:
			for parry: bool in [false, true]:
				enemy.health_component.configure(10000.0)
				enemy.parry_exposed_time = 1.0 if parry else 0.0
				var literal: bool = source_tag == str(definition.weakness) or source_tag == str(definition.tag)
				var oil: bool = (source_tag == "spirit" and str(definition.weakness) == "moon_oil") or (source_tag == "undead" and str(definition.weakness) == "rot_oil")
				var expected := 20.0 + (15.0 if literal or oil else 0.0) + (8.0 if parry else 0.0)
				enemy.apply_damage(20.0, source_tag)
				_check(is_equal_approx(10000.0 - enemy.health_component.health, expected), "%s / %s / parry=%s damage must be %.2f" % [id, source_tag, parry, expected])
				if oil and not literal and not parry:
					increases.append(id + ":" + source_tag)
				if parry:
					_check(is_zero_approx(enemy.parry_exposed_time), "Parry exposure must still be consumed once")
		enemy.free()
	_check(increases == ["bell_eater:spirit"], "Only Bell-Eater's missing Moon Oil match may increase from the previous damage policy")
	var inventory := Inventory.new()
	stage.add_child(inventory)
	inventory.load_items("res://data/items.json")
	inventory.items["moon_oil"] = 1
	_check(inventory.apply_oil("moon_oil"), "Real inventory must apply a Moon Oil bottle")
	_check(inventory.items.moon_oil == 0 and inventory.active_oil == "moon_oil", "Applying oil must consume exactly one bottle")
	var target := _enemy(stage, "bell_eater", definitions.bell_eater)
	target.position = Vector3(0, 0, -1)
	var player := BladePlayer.new()
	stage.add_child(player)
	var combat := Combat.new()
	stage.add_child(combat)
	await physics_frame
	var contact := {"attack_id": 1, "base": Vector3(0, 0.72, -0.5), "tip": Vector3(0, 0.72, -1.5), "damage": 20.0, "reach": 2.0, "heavy": false}
	var result: Dictionary = combat.resolve_player_blade_contact(player, [target], contact, inventory.active_oil)
	_check(bool(result.get("hit", false)), "The production blade resolver must hit the fixture")
	_check(is_equal_approx(10000.0 - target.health_component.health, 35.0), "A real Moon Oil blade contact must award Bell-Eater one +15 bonus")
	combat.resolve_player_blade_contact(player, [target], contact, inventory.active_oil)
	_check(is_equal_approx(10000.0 - target.health_component.health, 35.0), "Repeated samples of one blade attack must not damage twice")
	stage.free()
	print("OIL WEAKNESS DAMAGE: %s checks=%d definitions=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, definitions.size()])
	quit(0 if failures.is_empty() else 1)

func _enemy(parent: Node3D, id: String, definition: Dictionary) -> Enemy:
	var enemy := Enemy.new()
	enemy.set_physics_process(false)
	enemy.enemy_id = id
	enemy.tag = str(definition.tag)
	enemy.weakness = str(definition.weakness)
	enemy.health_component = Health.new()
	enemy.add_child(enemy.health_component)
	enemy.health_component.configure(10000.0)
	parent.add_child(enemy)
	return enemy

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
