extends SceneTree

const RELEASED_BUILDERS := [
	"res://scripts/zones/campaign_section.gd",
	"res://scripts/zones/castle_vargan_section.gd",
]

var failures := 0

func _initialize() -> void:
	for path in RELEASED_BUILDERS:
		var source := FileAccess.get_file_as_string(path)
		check(source != "", "Unable to read released zone builder: %s" % path)
		check(not source.contains(".call(\"_"), "Reflective private dispatch remains in %s" % path)
	var context_script = load("res://scripts/zone_build_context.gd")
	check(context_script != null, "ZoneBuildContext does not compile")
	print("ZONE BUILDER INTEGRITY: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
