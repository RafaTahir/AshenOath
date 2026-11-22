extends SceneTree
const Residency=preload("res://scripts/zone_residency_service.gd")
const Spatial=preload("res://scripts/zone_spatial_service.gd")
const Surface=preload("res://scripts/spatial_surface_contract.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var host:=Node3D.new()
 root.add_child(host)
 var cache:=Residency.new()
 host.add_child(cache)
 var view:=SubViewport.new()
 view.size=Vector2i(2,2)
 view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 host.add_child(view)
 var zone:=Node3D.new()
 zone.process_mode=Node.PROCESS_MODE_DISABLED
 view.add_child(zone)
 var spatial:=Spatial.new()
 zone.add_child(spatial)
 spatial.configure("wychwood",0,Vector2(22,17))
 var body:=StaticBody3D.new()
 var shape:=CollisionShape3D.new()
 var box:=BoxShape3D.new()
 box.size=Vector3(44,.2,34)
 shape.shape=box
 body.add_child(shape)
 zone.add_child(body)
 body.position.y=-.1
 var sourceworld:=host.get_world_3d()
 var isolatedworld:=view.find_world_3d()
 for i in range(3): await physics_frame
 print("BEFORE worldmain=",sourceworld.space," view=",view.find_world_3d().space," body=",body.get_world_3d().space," disabled=",body.can_process())
 cache.suspend_runtime(zone)
 cache._cache_route_zone("wychwood",zone,[],123)
 var retiring_world:=view.find_world_3d()
 view.own_world_3d=false
 retiring_world=null
 for i in range(3): await physics_frame
 print("CACHED worldmain=",sourceworld.space," view=",view.find_world_3d().space," body=",body.get_world_3d().space)
 cache._activate_cached_zone("wychwood")
 var candidate:=Vector3(-5.874103,0,26.068644)
 var recovery:=spatial.nearest_safe(candidate,spatial.bank_for(candidate))
 for i in range(10):
  await physics_frame
  var hit:=Surface.support_hit(sourceworld.direct_space_state,candidate+Vector3.UP*6,candidate-Vector3.UP*12,[],zone)
  var safe:=Surface.support_hit(sourceworld.direct_space_state,recovery+Vector3.UP*6,recovery-Vector3.UP*12,[],zone)
  print("ACTIVE i=",i," view=",view.find_world_3d().space," body=",body.get_world_3d().space," layer=",body.collision_layer," enabled=",body.can_process()," candidate=",candidate," hit=",not hit.is_empty()," recovery=",recovery," safe=",not safe.is_empty())
 host.free()
 isolatedworld=null
 await process_frame
 quit()
