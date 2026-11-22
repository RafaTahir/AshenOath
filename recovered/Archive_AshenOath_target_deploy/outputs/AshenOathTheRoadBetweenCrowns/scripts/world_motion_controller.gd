extends Node

var wind_time := 0.0
var wind_strength := 1.0
var tracked: Array[Node3D] = []
var update_accumulator := 0.0
const UPDATE_INTERVAL := 1.0 / 12.0

func configure(root: Node3D, quality: String) -> void:
	tracked.clear()
	wind_strength = 0.55 if quality == "potato" else (1.25 if quality == "quality" else 0.9)
	_collect(root)

func _process(delta: float) -> void:
	update_accumulator += delta
	if update_accumulator < UPDATE_INTERVAL:
		return
	delta = update_accumulator
	update_accumulator = 0.0
	wind_time += delta
	for node in tracked:
		if not is_instance_valid(node):
			continue
		var base: Vector3 = node.get_meta("motion_base", node.rotation_degrees)
		var phase := float(node.get_meta("motion_phase", 0.0))
		var kind := str(node.get_meta("motion_type", "wind"))
		var wave := sin(wind_time * (2.2 if kind == "flame" else 0.75) + phase)
		if kind == "bird":
			node.position.y += sin(wind_time * 2.0 + phase) * 0.002
			node.rotation_degrees.z = base.z + wave * 18.0
		elif kind == "wheel":
			node.rotation_degrees.x = base.x + wind_time * 22.0
		elif kind == "flame":
			node.scale.y = 1.0 + wave * 0.12
			node.rotation_degrees.z = base.z + wave * 4.0
		else:
			node.rotation_degrees.z = base.z + wave * wind_strength * float(node.get_meta("motion_amount", 3.0))

func _collect(root: Node) -> void:
	if root is Node3D and root.has_meta("motion_type"):
		var node := root as Node3D
		node.set_meta("motion_base", node.rotation_degrees)
		tracked.append(node)
	for child in root.get_children():
		_collect(child)
