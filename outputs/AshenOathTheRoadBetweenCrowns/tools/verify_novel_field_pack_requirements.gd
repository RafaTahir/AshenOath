extends SceneTree

const Requirements = preload("res://scripts/novel/field_pack_requirements.gd")
const WILLOW := ["novel_field_willow"]
const GALLERY := ["novel_field_gallery"]
const CULVERT := ["novel_field_culvert"]

var failures: Array[String] = []

func _expect(zone: String, flags: Dictionary, expected: Array, completed: Dictionary = {}) -> void:
	# JSON converts integer fields to floats on Continue.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(flags))
	var found := Requirements.for_zone(zone,saved,completed)
	if found != expected:
		failures.append("%s with %s expected %s, got %s" % [zone,saved,expected,found])

func _initialize() -> void:
	_expect("greyfen",{"novel_edition":1},[])
	_expect("wychwood",{},[])
	_expect("wychwood",{"novel_edition":"1"},[])
	_expect("wychwood",{"novel_edition":1},WILLOW)
	_expect("wychwood",{"novel_edition":1,"novel_step_willow_frame":5},[])
	_expect("greyfen",{"novel_edition":1,"novel_step_willow_frame":3},WILLOW)
	_expect("ruins",{"novel_edition":1,"novel_step_willow_frame":2},WILLOW)
	_expect("cemetery",{"novel_edition":1,"novel_step_willow_frame":4},WILLOW)
	_expect("cemetery",{"novel_edition":1,"novel_step_willow_frame":5},[])
	_expect("old_mill",{"novel_edition":1},GALLERY)
	_expect("old_mill",{"novel_edition":1,"novel_step_tor_wrist":3},[])
	_expect("marsh_crossing",{"novel_edition":1},CULVERT)
	_expect("vargan_approach",{"novel_edition":1,"novel_step_culvert":3},CULVERT)
	_expect("vargan_approach",{"novel_edition":1,"novel_step_culvert":4},CULVERT)
	_expect("vargan_approach",{"novel_edition":1,"novel_step_culvert":4,"novel_done_counterpart":true},[])
	_expect("vargan_approach",{"novel_edition":1,"novel_step_culvert":4},[],{"main_blood_under_stone":true})
	for failure: String in failures: push_error(failure)
	print("NOVEL FIELD PACK REQUIREMENTS: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL",failures.size()])
	quit(0 if failures.is_empty() else 1)
