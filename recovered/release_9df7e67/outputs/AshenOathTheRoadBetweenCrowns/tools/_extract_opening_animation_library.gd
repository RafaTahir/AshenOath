extends SceneTree

const SOURCE_PATH := "res://assets_external/animations/AnimationLibrary_Godot_Standard.glb"
const OUTPUT_PATH := "res://assets_external/animations/AnimationLibrary_Godot_Opening.tres"

# These are the clips referenced by the shipped player, NPC, dialogue, bow,
# and equipment contracts. The source library remains the authoring reference;
# the saved resource removes its unused mannequin scene and specialist clips.
const REQUIRED_CLIPS := [
	"Idle", "Idle_Talking", "Idle_Torch", "Interact", "Sitting_Idle", "Sitting_Talking",
	"Walk", "Sprint", "Jump_Start", "Roll", "Sword_Idle", "Sword_Attack", "Sword_Attack_RM",
	"Spell_Simple_Idle", "Hit_Chest", "Hit_Head", "Death01"
]

func _initialize() -> void:
	var source_scene := ResourceLoader.load(SOURCE_PATH) as PackedScene
	if source_scene == null:
		push_error("Opening animation extraction could not load source scene")
		quit(1)
		return
	var instance := source_scene.instantiate()
	if instance == null:
		push_error("Opening animation extraction could not instantiate source scene")
		quit(1)
		return
	root.add_child(instance)
	await process_frame
	var source_player := _find_animation_player(instance)
	if source_player == null:
		push_error("Opening animation extraction found no AnimationPlayer")
		quit(1)
		return
	var output := AnimationLibrary.new()
	var missing: Array[String] = []
	for clip_name in REQUIRED_CLIPS:
		var clip := source_player.get_animation(clip_name)
		if clip == null:
			missing.append(clip_name)
			continue
		output.add_animation(clip_name, clip.duplicate(true))
	if not missing.is_empty():
		push_error("Opening animation extraction missing clips: %s" % ", ".join(missing))
		instance.free()
		quit(1)
		return
	var error := ResourceSaver.save(output, OUTPUT_PATH)
	instance.free()
	if error != OK:
		push_error("Opening animation extraction failed to save: %s" % error_string(error))
		quit(1)
		return
	print("OPENING_ANIMATION_LIBRARY: PASS clips=%d path=%s" % [output.get_animation_list().size(), OUTPUT_PATH])
	quit()

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
