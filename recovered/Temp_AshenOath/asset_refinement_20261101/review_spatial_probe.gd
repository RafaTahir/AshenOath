extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var service = load("res://scripts/zone_spatial_service.gd").new()
    world.add_child(service)
    service.configure("review_fixture",999.0,Vector2(10,10))
    var floor_body := StaticBody3D.new()
    world.add_child(floor_body)
    var floor_shape := CollisionShape3D.new()
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(20,0.2,20)
    floor_shape.shape = floor_box
    floor_shape.position.y = -0.1
    floor_body.add_child(floor_shape)
    var blocker := StaticBody3D.new()
    world.add_child(blocker)
    var shape_node := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(1,0.25,1)
    shape_node.shape = box
    shape_node.position.y = 0.125
    blocker.add_child(shape_node)
    await physics_frame
    await process_frame
    await physics_frame
    print("LOW_BLOCKER occupied=",service.is_position_occupied(Vector3.ZERO,0.3016,1.65)," segment_allowed=",service.validate_runtime_segment(Vector3(-2,0,0),Vector3(2,0,0),0.58))
    box.size = Vector3(1,1.2,1)
    shape_node.position.y = 0.6
    await physics_frame
    await process_frame
    await physics_frame
    print("HIGH_BLOCKER occupied=",service.is_position_occupied(Vector3.ZERO,0.3016,1.65)," segment_allowed=",service.validate_runtime_segment(Vector3(-2,0,0),Vector3(2,0,0),0.58))
    var capsule: CapsuleShape3D = service._get_probe_shape(0.3016,1.65)
    print("CAPSULE actual_size=",capsule.get_debug_mesh().get_aabb().size," bottom_of_runtime_probe=",0.14+capsule.height*0.5+0.3016-capsule.get_debug_mesh().get_aabb().size.y*0.5)
    world.free()
    quit()
