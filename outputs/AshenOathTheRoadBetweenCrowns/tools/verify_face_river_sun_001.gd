extends SceneTree

const CharacterVisualContract = preload("res://scripts/character_visual_contract.gd")

var failures := 0

func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("_new_game")
	await _frames(5)
	_verify_character(main.player, "Kael")
	var anwen = main.zone_root.find_child("sister_anwen", true, false)
	_verify_character(anwen, "Sister Anwen")
	var life = main.zone_root.find_child("GreyfenLifeController", true, false)
	check(life != null and life.actor_count() >= 6, "Greyfen population is missing")
	if life != null:
		for entry in life.actors:
			_verify_character(entry.node, str(entry.id))
			_verify_path(entry.path, 4.5, str(entry.id))
	var sample: Array = main.river_safe_path([Vector3(-8,0,0),Vector3(8,0,9)],0.9)
	_verify_path(sample,4.5,"sample bridge path")
	_verify_sun(main.visual_director)
	main.call("_load_zone","wychwood")
	await _frames(4)
	for enemy in main.active_enemies:
		_verify_character(enemy, str(enemy.enemy_id))
	var passed := failures == 0
	if passed:
		print("FACE-RIVER-SUN-001 VERIFIER: PASS")
	else:
		push_error("FACE-RIVER-SUN-001 VERIFIER: %d failure(s)" % failures)
	main.queue_free()
	await process_frame
	quit(0 if passed else 1)

func _verify_character(node: Node, label: String) -> void:
	check(node != null, "%s is missing" % label)
	if node == null: return
	check(node.find_child("FacialIdentity",true,false) == null, "%s still uses a billboard face" % label)
	var skeleton := _find_skeleton(node)
	check(skeleton != null, "%s skeletal body is missing" % label)
	var contract := CharacterVisualContract.validate(node, true)
	check(bool(contract.get("valid", false)), "%s has no complete skinned animated body contract" % label)
	if skeleton != null:
		check(_has_bone(skeleton,"head"), "%s has no animated head bone" % label)
	var face_surface_count := int(_find_meta(node, "character_face_surfaces", 0))
	var face_features := str(_find_meta(node, "character_face_features", ""))
	var profile := str(_find_meta(node, "character_identity_profile", "")).to_lower()
	var is_single_surface_monster := profile in [
		"ghoulkin", "ghoulkin_skeleton", "wychwood_stalker", "wychwood_raider", "wychwood_brute"
	]
	# The retained Skeleton monster family carries its modeled skull and head
	# bone in one connected imported surface. Humans still require multiple
	# face-bearing surfaces; monsters require the stricter single-surface native
	# contract plus the animated head-bone check above.
	var minimum_face_surfaces := 1 if is_single_surface_monster else 2
	check(face_surface_count >= minimum_face_surfaces and face_features in ["native_mesh", "bone_attached"], "%s mesh-native face material is missing" % label)

func _has_fragment(node: Node, fragment: String) -> bool:
	if str(node.name).to_lower().contains(fragment):
		return true
	for child in node.get_children():
		if _has_fragment(child,fragment):
			return true
	return false

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null: return found
	return null

func _has_bone(skeleton: Skeleton3D, fragment: String) -> bool:
	for index in range(skeleton.get_bone_count()):
		if str(skeleton.get_bone_name(index)).to_lower().contains(fragment): return true
	return false

func _find_meta(node: Node, key: String, fallback: Variant) -> Variant:
	if node.has_meta(key):
		return node.get_meta(key)
	for child in node.get_children():
		var value: Variant = _find_meta(child, key, fallback)
		if value != fallback:
			return value
	return fallback

func _verify_path(path: Array, river_z: float, label: String) -> void:
	for i in range(1,path.size()):
		var a: Vector3 = path[i-1]
		var b: Vector3 = path[i]
		if (a.z-river_z)*(b.z-river_z) < 0.0:
			check(absf(a.x) <= 2.7 and absf(b.x) <= 2.7, "%s crosses river away from bridge" % label)

func _verify_sun(director: Node) -> void:
	check(director.sun_disc.mesh is QuadMesh, "Sun is not a camera-facing disc")
	check(director.sun_disc.scale.x <= 4.0, "Sun apparent size is still oversized")
	check(director.sun_rays.get_child_count() == 0, "Cartoon sun rays still exist")
	director.call("set_time",720.0,"day",0)
	check(director.sun_disc.visible and not director.moon_disc.visible, "Noon sun/moon visibility is invalid")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame
