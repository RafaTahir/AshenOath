extends RefCounted

const PlayerController = preload("res://scripts/player_controller.gd")
const CameraController = preload("res://scripts/camera_controller.gd")

static func create_player_camera(owner: Node, position: Vector3, zone_id: String) -> Dictionary:
	var player = PlayerController.new()
	player.name = "Player"
	owner.add_child(player)
	player.global_position = position
	var camera = CameraController.new()
	camera.name = "PlayerCameraRig"
	owner.add_child(camera)
	camera.setup(player)
	camera.set_zone(zone_id)
	player.camera_controller = camera
	return {"player": player, "camera": camera}

static func is_valid_pair(pair: Dictionary) -> bool:
	return pair.has("player") and pair.has("camera") \
		and pair["player"] != null and pair["camera"] != null \
		and is_instance_valid(pair["player"]) and is_instance_valid(pair["camera"])
