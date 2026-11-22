extends Node3D

var player: Node3D
var last_track_position := Vector3(9999, 9999, 9999)
var tracks: Array[MeshInstance3D] = []
var enabled := true

func configure(target: Node3D, quality: String) -> void:
	player = target
	enabled = quality != "potato"

func _process(_delta: float) -> void:
	if not enabled or player == null or not is_instance_valid(player) or not player.is_inside_tree() or not is_inside_tree():
		return
	var flat := Vector2(player.global_position.x, player.global_position.z)
	var previous := Vector2(last_track_position.x, last_track_position.z)
	if flat.distance_to(previous) < 0.78:
		return
	last_track_position = player.global_position
	var track := MeshInstance3D.new()
	track.name = "PlayerFootprint"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.012, 0.34)
	track.mesh = mesh
	add_child(track)
	track.global_position = player.global_position + Vector3(0.12 if tracks.size() % 2 == 0 else -0.12, 0.025, 0.10)
	track.global_rotation = Vector3(0, player.global_rotation.y, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.025, 0.020, 0.016, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	track.material_override = material
	tracks.append(track)
	if tracks.size() > 20:
		var old: MeshInstance3D = tracks.pop_front()
		old.queue_free()
