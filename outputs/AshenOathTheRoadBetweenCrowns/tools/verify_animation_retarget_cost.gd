extends SceneTree

const Fusion = preload("res://scripts/character_animation_fusion.gd")

func _initialize() -> void:
	var source := load(Fusion.ANIMATION_LIBRARY_PATH) as AnimationLibrary
	var rig := Node3D.new()
	var armature := Node3D.new()
	armature.name = "Armature"
	rig.add_child(armature)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	armature.add_child(skeleton)
	var signatures: Array[String] = []
	for iteration in range(3):
		var start := Time.get_ticks_usec()
		var library := source.duplicate(true) as AnimationLibrary
		var duplicate_us := Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		Fusion._retarget_library(library, rig, skeleton)
		var retarget_us := Time.get_ticks_usec() - start
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		for animation_name in library.get_animation_list():
			var animation := library.get_animation(animation_name)
			digest.update(var_to_bytes([animation_name, animation.length, animation.loop_mode]))
			for track in range(animation.get_track_count()):
				digest.update(var_to_bytes([animation.track_get_path(track), animation.track_get_type(track), animation.track_get_interpolation_type(track)]))
				for key in range(animation.track_get_key_count(track)):
					digest.update(var_to_bytes([animation.track_get_key_time(track, key), animation.track_get_key_value(track, key), animation.track_get_key_transition(track, key)]))
		var signature := digest.finish().hex_encode()
		signatures.append(signature)
		print("RETARGET COST: duplicate_us=%s retarget_us=%s signature=%s" % [duplicate_us, retarget_us, signature])
	rig.free()
	if signatures[0] != signatures[1] or signatures[0] != signatures[2]:
		push_error("Retarget output differs between independent instances")
		quit(1)
	else:
		print("RETARGET COST: PASS deterministic tracks and keys")
		quit(0)
