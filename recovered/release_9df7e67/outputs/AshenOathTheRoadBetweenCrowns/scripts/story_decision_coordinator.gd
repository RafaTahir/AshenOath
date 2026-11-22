extends RefCounted

const StoryChoicePresenter = preload("res://scripts/story_choice_presenter.gd")

## A campaign action is published only after its flags, rewards and objectives
## agree. Presentation and save listeners never observe half of a decision.

func begin(game) -> void:
	game.story_action_in_progress = true
	game.story_state.begin_change()
	game.quests.begin_change()

func finish(game, action: Dictionary, applied: bool = true) -> void:
	if applied:
		game.story_state.record_relationship_choice(action)
	if applied and StoryChoicePresenter.is_commitment(action):
		game.story_state.record_decision(StoryChoicePresenter.decision_id(action), action)
	# Completion handlers grant their chapter rewards while the transaction is
	# still closed to checkpointing. Then publish the complete story snapshot.
	game.quests.end_change()
	game.story_state.end_change()
	game.story_action_in_progress = false
	if applied:
		game.call_deferred("_finish_story_action", action)
