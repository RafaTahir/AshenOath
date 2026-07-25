extends SceneTree

const AudioManager = preload("res://scripts/audio_manager.gd")
const MANIFEST_PATH := "res://voice_production_manifest.json"

var failures := 0

func _initialize() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	check(typeof(manifest) == TYPE_DICTIONARY, "Voice production manifest is invalid")
	if typeof(manifest) != TYPE_DICTIONARY:
		_finish()
		return
	check(str(manifest.get("status", "")) == "scratch", "Synthetic voice must be identified as scratch delivery")
	check(str(manifest.get("authoritative_delivery", "")) == "subtitles", "Subtitles are not authoritative")
	var audio := AudioManager.new()
	root.add_child(audio)
	await process_frame
	var payload := 0
	for voice_id in manifest.get("required_lines", []):
		var id := str(voice_id)
		var path := "res://assets_external/audio/voices/scratch/%s.wav" % id
		check(FileAccess.file_exists(path), "Scratch voice file is missing: %s" % id)
		check(audio.has_voice(id), "AudioManager did not register voice: %s" % id)
		var stream = audio.voices.get(id)
		check(stream != null and str(stream.get_meta("scratch_voice_path", "")).contains("/voices/scratch/"), "Voice did not prefer recorded scratch audio: %s" % id)
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			payload += file.get_length()
	check(payload <= int(manifest.get("maximum_payload_bytes", 0)), "Scratch voice payload exceeds its 15 MB budget")
	print("VOICE-001 payload_bytes=%d" % payload)
	_finish()

func _finish() -> void:
	print("VOICE-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
