extends SceneTree

const Geometry = preload("res://tools/living_cast_capture_geometry.gd")
var failures: Array[String] = []
var checks := 0
var skipped: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var capture: Script = load("res://tools/capture_living_cast.gd")
	_check(capture != null and capture.can_instantiate(), "capture script compiles without launching a world")
	var scene := Node3D.new()
	root.add_child(scene)
	var actor := Node3D.new()
	actor.name = "Actor"
	scene.add_child(actor)
	var player := Node3D.new()
	player.name = "Player"
	scene.add_child(player)
	var wall := _box(scene,"Facade",Vector3(0,1,1.4),Vector3(2,2,0.1))
	var body := _box(actor,"Body",Vector3(0,1,0),Vector3(0.5,1.6,0.5))
	_box(player,"PlayerBody",Vector3(0,1,2),Vector3(0.5,1.6,0.5))
	var multi := MultiMeshInstance3D.new()
	multi.name = "VisualOnlyFence"
	multi.multimesh = MultiMesh.new()
	multi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multi.multimesh.mesh = wall.mesh
	multi.multimesh.instance_count = 1
	multi.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(4,1,1)))
	scene.add_child(multi)
	await process_frame
	var geometry := Geometry.new()
	var receipt := geometry.build(scene,player)
	var multimesh_transform_available := multi.multimesh.get_instance_transform(0).origin.is_equal_approx(Vector3(4,1,1))
	# The headless dummy renderer discards MultiMesh buffers. Keep that limitation
	# explicit; the same fixture exercises them when run with a graphical driver.
	if not multimesh_transform_available:
		skipped.append("MultiMesh instance transform/visibility (dummy renderer discards buffers)")
		multi.multimesh.visible_instance_count = 0
	_check(int(receipt.instances) == 3,"player excluded, actor/wall/multimesh indexed")
	_check(int(receipt.unique_meshes) == 2,"shared mesh BVH cached once")
	_check(not geometry.obstruction(Vector3(0,1,3),Vector3(0,1,0),actor,1).is_empty(),"visual facade blocks without a physics body")
	wall.visible = false
	_check(geometry.obstruction(Vector3(0,1,3),Vector3(0,1,0),actor,1).is_empty(),"hidden mesh and actor/player are excluded")
	wall.visible = true
	wall.layers = 2
	_check(geometry.obstruction(Vector3(0,1,3),Vector3(0,1,0),actor,1).is_empty(),"camera layer mask applied")
	_check(not geometry.obstruction(Vector3(0,1,3),Vector3(0,1,0),actor,2).is_empty(),"matching camera layer blocks")
	wall.layers = 1
	wall.position.x = 8
	_check(geometry.obstruction(Vector3(0,1,3),Vector3(0,1,0),actor,1).is_empty(),"live mesh transform updates without rebuilding")
	if multimesh_transform_available:
		_check(not geometry.obstruction(Vector3(4,1,3),Vector3(4,1,0),actor,1).is_empty(),"MultiMesh instance transform blocks")
		multi.multimesh.visible_instance_count = 0
		_check(geometry.obstruction(Vector3(4,1,3),Vector3(4,1,0),actor,1).is_empty(),"MultiMesh visibility updates")
	wall.position = Vector3(0,1,1)
	wall.rotation.y = 0.7
	wall.scale = Vector3(1.5,0.5,2)
	_check(not geometry.obstruction(Vector3(0,1,3),Vector3(0,1,0),actor,1).is_empty(),"rotated scaled geometry intersection")
	wall.visible = false
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0,1.5,3)
	camera.look_at(Vector3(0,1,0))
	camera.make_current()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = size
		await process_frame
		_check(geometry.validate_actor(camera,actor,size,Vector3.FORWARD).is_empty(),"clear projected actor at " + str(size))
		wall.visible = true
		_check(not geometry.validate_actor(camera,actor,size,Vector3.FORWARD).is_empty(),"occluded actor rejected at " + str(size))
		wall.visible = false
		camera.look_at(Vector3(0,1,8))
		_check(not geometry.validate_actor(camera,actor,size,Vector3.FORWARD).is_empty(),"behind-camera actor rejected")
		camera.look_at(Vector3(0,1,0))
		actor.position.x = 12
		_check(not geometry.validate_actor(camera,actor,size,Vector3.FORWARD).is_empty(),"off-frame actor rejected")
		actor.position.x = 0
	var other := Camera3D.new()
	root.add_child(other)
	other.make_current()
	_check(not geometry.validate_actor(camera,actor,root.size,Vector3.FORWARD).is_empty(),"camera ownership change rejected")
	_check(body.is_visible_in_tree(),"actor was not hidden to make validation pass")
	other.free()
	camera.free()
	scene.free()
	for failure: String in failures: printerr("CAPTURE FIXTURE: " + failure)
	for limitation: String in skipped: print("CAPTURE FIXTURE SKIP: " + limitation)
	print("CAPTURE FIXTURE: %s checks=%d (synthetic geometry, camera projection, script compile; no world/gameplay)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _box(parent: Node3D, label: String, position: Vector3, size: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	parent.add_child(node)
	node.position = position
	return node

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
