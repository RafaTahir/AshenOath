extends RefCounted

## A campaign action is published only after its flags, rewards and objectives
## agree. Presentation and save listeners never observe half of a decision.

func begin(game) -> void:
	game.story_action_in_progress = true
	game.story_state.begin_change()
	game.quests.begin_change()

func finish(game, action: Dictionary) -> void:
	var action_type := str(action.get("type", ""))
	if action_type == "story_choice":
		var decision_id := str(action.get("choice_id", "%s:%s" % [action.get("quest", ""), action.get("objective", "")]))
		if decision_id == ":":
			var keys: Array = action.get("sets_flags", {}).keys()
			keys.sort()
			decision_id = "promise:%s" % ",".join(keys)
		game.story_state.record_decision(decision_id, action)
	elif action_type == "ending":
		game.story_state.record_decision("final_covenant", action)
	# Completion handlers grant their chapter rewards while the transaction is
	# still closed to checkpointing. Then publish the complete story snapshot.
	game.quests.end_change()
	game.story_state.end_change()
	game.story_action_in_progress = false
	game.call_deferred("_finish_story_action", action)
