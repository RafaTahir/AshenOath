extends SceneTree

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
	main.queue_free()
	await process_frame
	if failures == 0:
		print("FACE-RIVER-SUN-001 VERIFIER: PASS")
		quit(0)
	else:
		push_error("FACE-RIVER-SUN-001 VERIFIER: %d failure(s)" % failures)
		quit(1)

func _verify_character(node: Node, label: String) -> void:
	check(node != null, "%s is missing" % label)
	if node == null: return
	var attachment = node.find_child("FacialIdentity",true,false)
	check(attachment is BoneAttachment3D, "%s face is not bone-bound" % label)
	if attachment is BoneAttachment3D:
		check(str(attachment.bone_name).to_lower().contains("head"), "%s face is not attached to Head" % label)
		var sprite = attachment.find_child("BoneBoundFaceTexture",true,false)
		check(sprite is Sprite3D and sprite.texture != null, "%s facial texture is missing" % label)

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
	director.call("_update_sky_cycle",1.0,0.0,0.0,720.0)
	check(director.sun_disc.visible and not director.moon_disc.visible, "Noon sun/moon visibility is invalid")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame
