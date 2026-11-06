extends SceneTree

const Direction = preload("res://scripts/story_scene_direction.gd")
const WorldScenes = preload("res://scripts/story_world_scenes.gd")
const Dialogue = preload("res://scripts/dialogue_manager.gd")
const Audio = preload("res://scripts/audio_manager.gd")
var checks := 0
var failures: Array[String] = []

class MemoryState extends RefCounted:
	var flags: Dictionary = {}
	func get_flag(key: String, fallback: Variant = null) -> Variant: return flags.get(key, fallback)

class FixtureHost extends RefCounted:
	var current_zone_id := "record_hall"
	var story_state := MemoryState.new()
	var quests = null

class FixtureActor extends Node3D:
	var interaction_id := "vargan_steward"

class FixtureDriver extends Node:
	var prop_ready := false
	func supports_story_prop(kind: String) -> bool: return prop_ready and kind == "cup"

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _run() -> void:
	var topics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/conversation_topics.json"))
	var scenes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/everyday_scenes.json"))
	for topic: Dictionary in topics.topics:
		if not str(topic.id).begins_with("life2_"): continue
		for index: int in topic.lines.size():
			var line: Dictionary = topic.lines[index]
			var source := "conversation_topic:%s:line:%d" % [topic.id, index]
			check(not Direction.authored(source, line.speaker_id, line.text).is_empty(), source)
			check(Direction.authored(source, "white_hart", line.text).is_empty(), source + " wrong speaker")
			check(Direction.authored(source, line.speaker_id, line.text + " changed").is_empty(), source + " stale text")
	var merrow: Dictionary = {}
	for scene: Dictionary in scenes.scenes:
		if not str(scene.id).begins_with("life2_"): continue
		if str(scene.id) == "life2_merrow_no_form": merrow = scene
		for index: int in scene.turns.size():
			var turn: Array = scene.turns[index]
			check(not Direction.authored("world_scene:%s:turn:%d" % [scene.id, index], turn[0], turn[2]).is_empty(), str(scene.id))
	check(Direction.checked_performance({"gesture":"invented"}).is_empty(), "unknown gesture fails")
	check(Direction.checked_performance({"emotion":"warm"}).get("emotion") == "warmth", "warm alias")
	check(Direction.checked_performance({"attention":{"mode":"point", "offset":[0, NAN, 0]}}).is_empty(), "nonfinite gaze fails")
	check(Direction.checked_performance({"body_gesture":"attack"}).is_empty(), "ambient performance cannot inject combat")
	var performance = preload("res://scripts/story_performance.gd")
	check(performance.speaker_matches("vale", "vargan_record_keeper"), "Vale speaks with canonical recording identity")
	check(performance.speaker_matches("merrow", "vargan_steward"), "Merrow speaks with canonical recording identity")
	check(performance.speaker_matches("nera", "saga_maren"), "Nera regional speaker alias")
	check(not performance.speaker_matches("anwen", "not_anwen"), "substring is not a speaker identity")
	check(not performance.speaker_matches("merrow", "narrator"), "narrator cannot animate a named speaker")
	var dialogue := Dialogue.new()
	var pages: Array = dialogue._build_pages({"name":"Merrow", "lines":[{"text":"A moment.", "performance":{"emotion":"warmth", "gesture":"reassure"}}]})
	check(pages.size() == 1 and pages[0].get("performance", {}).get("gesture") == "reassure", "authored page direction preserved")
	check(Direction.for_page("unknown", pages[0], 0).get("emotion") == "warmth", "page direction reaches playback")
	var host := FixtureHost.new()
	host.current_zone_id = str(merrow.zone)
	host.story_state.flags["castle_discovered"] = true
	var actor := FixtureActor.new()
	var driver := FixtureDriver.new()
	driver.name = "CharacterAnimationDriver"
	actor.add_child(driver)
	check(not WorldScenes.requestable_for(merrow, host, actor), "cup scene unavailable before actual prop/clip readiness")
	driver.prop_ready = true
	check(WorldScenes.requestable_for(merrow, host, actor), "cup scene offered when ready")
	actor.interaction_id = "vargan_record_keeper"
	check(not WorldScenes.requestable_for(merrow, host, actor), "stale actor cannot request another person's scene")
	actor.interaction_id = "vargan_steward"
	host.story_state.flags["world_scenes_heard"] = {str(merrow.id):true}
	check(not WorldScenes.requestable_for(merrow, host, actor), "completed personal scene stays completed")
	actor.free()
	var audio := Audio.new()
	audio.generated_current_recordings_allowed = true
	var entry := {"narrative_revision":"road-renewal-1", "production_mode":"generated", "review_status":"pending_listening_review", "status":"generated_current", "speaker_id":"nessa", "text":"A warm loaf.", "text_sha256":"A warm loaf.".sha256_text(), "path":"res://assets_external/audio/voices/living_cast/fixture.ogg"}
	audio._register_revised_voice_entry("nessa_fixture", entry)
	check(audio.dialogue_voice_keys.get(audio._exact_voice_key("saga_nessa", "A warm loaf.")) == "nessa_fixture", "canonical speaker aliases use exact recording")
	check(not audio.dialogue_voice_keys.has(audio._exact_voice_key("nera", "A warm loaf.")), "different person cannot use recording")
	check(not audio.dialogue_voice_keys.has(audio._exact_voice_key("nessa", "A cold loaf.")), "edited subtitle has no recording")
	var stale := entry.duplicate(true)
	stale.text = "Changed after production."
	audio._register_revised_voice_entry("stale_fixture", stale)
	check(not audio.revised_voice_entries.has("stale_fixture"), "stale recording text hash rejected")
	check(audio._same_voice_speaker("saga_maren", "nera"), "Nera retained regional alias")
	check(not audio._same_voice_speaker("", ""), "empty identity rejected")
	audio.free()
	dialogue.free()
	for failure: String in failures: push_error(failure)
	print("PERSONAL CAST RUNTIME %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
