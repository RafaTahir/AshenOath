extends SceneTree

const Director = preload("res://scripts/story_activity_director.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var scenes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interaction_scenes.json"))
	for id: String in scenes:
		if not id.begins_with("aftermath_") or not id.ends_with("_concord") and not id.ends_with("_open_road"): continue
		var scene: Dictionary = scenes[id].duplicate(true)
		scene["pages"] = scene.lines.duplicate(true)
		var required: Array = scene.required_actors
		var snapshot := JSON.stringify(scene)
		var absent := Director.community_aftermath_projection(scene,[])
		_check(absent.pages==scene.unattended_pages,"absent participant uses authored public captions: "+id)
		_check(str(absent.primary_actor)=="","absent participant cannot focus a different actor")
		for page: Dictionary in absent.pages:
			_check(str(page.speaker_id)=="narrator" and not str(page.text).is_empty(),"fallback has exact caption text, no invented recording")
		var complete := Director.community_aftermath_projection(scene,required)
		_check(complete.pages==scene.pages,"present participants retain the authored spoken scene")
		_check(JSON.stringify(scene)==snapshot,"projection does not mutate the shared dialogue catalog")
		if required.size()>1:
			var partial := Director.community_aftermath_projection(scene,[required[0]])
			_check(partial.pages==scene.unattended_pages,"one participant cannot supply another participant's speech")
	var legacy := {"pages":[{"speaker_id":"rook","text":"Existing scene"}]}
	_check(Director.community_aftermath_projection(legacy,[])==legacy,"original ending scenes remain unchanged")
	for failure: String in failures: printerr("COMMUNITY AFTERMATH: "+failure)
	print("COMMUNITY AFTERMATH: %s checks=%d (pure projection, no world/input claim)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label)
