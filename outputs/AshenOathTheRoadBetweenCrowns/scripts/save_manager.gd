extends Node

const SAVE_PATH = "user://ashen_oath_save.json"
const AUTOSAVE_PATH = "user://ashen_oath_autosave.json"
const CHECKPOINT_PATH = "user://ashen_oath_checkpoint.json"

signal message(text: String)

func save_game(game, path: String = SAVE_PATH, label: String = "Game saved.") -> void:
	var data = {
		"version": 2,
		"zone": game.current_zone_id,
		"player_position": [game.player.global_position.x, game.player.global_position.y, game.player.global_position.z],
		"player_health": game.player.health_component.save_state(),
		"player_stamina": game.player.stamina_component.save_state(),
		"inventory": game.inventory.save_state(),
		"quests": game.quests.save_state(),
		"world_state": game.save_world_state()
	}
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	message.emit(label)

func load_game(game, path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		message.emit("No save found.")
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		message.emit("Save file is invalid.")
		return false
	game.load_save_state(data)
	message.emit("Game loaded.")
	return true

func autosave(game) -> void:
	save_game(game, AUTOSAVE_PATH, "Autosaved.")

func checkpoint(game) -> void:
	save_game(game, CHECKPOINT_PATH, "Checkpoint reached.")

func load_checkpoint(game) -> bool:
	if FileAccess.file_exists(CHECKPOINT_PATH):
		return load_game(game, CHECKPOINT_PATH)
	if FileAccess.file_exists(AUTOSAVE_PATH):
		return load_game(game, AUTOSAVE_PATH)
	return load_game(game, SAVE_PATH)
