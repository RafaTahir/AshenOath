extends SceneTree

const Interactable = preload("res://scripts/interactable.gd")

func _initialize() -> void:
	var item := Interactable.new()
	item.setup("notice_board", "dialogue", "Read notice board")
	var passed := item.get_context_prompt().begins_with("Read")
	passed = passed and item.interaction_type == "dialogue" and item.dialogue_id == "notice_board"
	item.setup("anwen", "dialogue", "Talk to Sister Anwen")
	passed = passed and item.get_context_prompt().begins_with("Speak")
	item.state_label = "Completed"
	passed = passed and item.get_context_prompt().begins_with("Completed")
	item.free()
	print("WRITTEN INTERACTION PROMPT: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
