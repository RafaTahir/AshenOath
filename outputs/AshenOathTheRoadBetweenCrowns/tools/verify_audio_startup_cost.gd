extends SceneTree

const Audio = preload("res://scripts/audio_manager.gd")

func _initialize() -> void:
	var audio := Audio.new()
	var started := Time.get_ticks_usec()
	audio._build_menu_library()
	var menu := Time.get_ticks_usec()
	audio._build_library()
	var generated := Time.get_ticks_usec()
	audio._build_recorded_library()
	var recorded := Time.get_ticks_usec()
	audio._build_voice_library()
	var voice := Time.get_ticks_usec()
	audio.prewarm_opening_audio()
	var opening := Time.get_ticks_usec()
	print("AUDIO STARTUP COST " + JSON.stringify({"menu_ms": (menu-started)/1000.0, "generated_ms": (generated-menu)/1000.0, "recorded_ms": (recorded-generated)/1000.0, "voice_ms": (voice-recorded)/1000.0, "opening_ms": (opening-voice)/1000.0, "sounds": audio.sounds.size(), "voices": audio.voices.size()}))
	audio.free()
	quit()
