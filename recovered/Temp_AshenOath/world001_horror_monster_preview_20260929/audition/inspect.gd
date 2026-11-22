extends SceneTree

func _initialize() -> void:
	for path in ["res://Idle.fbx", "res://Walk.fbx", "res://Poses.fbx"]:
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Missing source: " + path)
			continue
		var actor := packed.instantiate()
		var skeletons := actor.find_children("*", "Skeleton3D", true, false)
		var players := actor.find_children("*", "AnimationPlayer", true, false)
		print("SOURCE %s skeletons=%d players=%d" % [path, skeletons.size(), players.size()])
		for skeleton in skeletons:
			var node := skeleton as Skeleton3D
			print("SKELETON %s bones=%d root=%s" % [node.name, node.get_bone_count(), node.get_bone_name(0) if node.get_bone_count() > 0 else "none"])
		for player in players:
			var node := player as AnimationPlayer
			for clip in node.get_animation_list():
				var animation := node.get_animation(clip)
				print("CLIP %s %s length=%.3f tracks=%d" % [path, clip, animation.length, animation.get_track_count()])
		actor.free()
	quit(0)
