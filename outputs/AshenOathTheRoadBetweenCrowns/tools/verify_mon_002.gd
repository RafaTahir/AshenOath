extends SceneTree

const EnemyAI = preload("res://scripts/enemy_ai.gd")

var required := ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bog_wretch", "gravebound_knight", "bell_eater", "rootbound_colossus", "ashwing", "halvern_boss", "white_hart_avatar"]
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures += 1
		push_error("enemies.json is not a dictionary")
	else:
		for role in required:
			if not parsed.has(role):
				failures += 1
				push_error("missing enemy role %s" % role)
		for boss_id in ["bell_eater", "rootbound_colossus", "ashwing", "halvern_boss", "white_hart_avatar"]:
			if parsed.has(boss_id) and not bool(parsed[boss_id].get("boss", false)):
				failures += 1
				push_error("%s is not marked as a boss" % boss_id)
	var enemy_ai := FileAccess.get_file_as_string("res://scripts/enemy_ai.gd")
	for needle in ["bell_eater", "rootbound_colossus", "ashwing", "halvern_boss", "_add_boss_silhouette"]:
		if not enemy_ai.contains(needle):
			failures += 1
			push_error("enemy presentation missing %s" % needle)
	await _verify_white_hart_runtime(parsed if typeof(parsed) == TYPE_DICTIONARY else {})
	if failures == 0:
		print("PASS MON-002: released monster and boss roles have data and presentation mappings")
		quit(0)
	else:
		push_error("MON-002: %d failure(s)" % failures)
		quit(1)

func _verify_white_hart_runtime(enemy_definitions: Dictionary) -> void:
	var definition: Dictionary = enemy_definitions.get("white_hart_avatar", {})
	if definition.is_empty():
		return
	var target := Node3D.new()
	target.name = "WhiteHartVerifierTarget"
	root.add_child(target)
	var hart := EnemyAI.new()
	hart.name = "WhiteHartVerifierActor"
	root.add_child(hart)
	hart.setup("white_hart_avatar", definition, target)
	await process_frame
	var skeleton := _find_type(hart, "Skeleton3D")
	var animation_player := _find_type(hart, "AnimationPlayer")
	check(skeleton != null, "White Hart runtime has no Skeleton3D")
	check(animation_player != null, "White Hart runtime has no AnimationPlayer")
	check(hart.get_node_or_null("visual_root") != null, "White Hart runtime has no visual root")
	var antler_attachment := _find_named(hart, "WhiteHartAntlerHeadAttachment")
	check(antler_attachment != null, "White Hart antlers are not attached to the head")
	if antler_attachment != null:
		check(str(antler_attachment.bone_name) == "Bone.003", "White Hart antlers use the wrong head bone")
	check(_find_named(hart, "SpectralAntlerMain") != null, "White Hart crown has no antler geometry")
	check(_find_named(hart, "HartBody") == null, "White Hart still uses segmented primitive fallback")
	hart.queue_free()
	target.queue_free()

func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null

func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("MON-002: %s" % message)
