extends SceneTree

## Actual AnimationTree morph blending on a disposable triangle and skeleton.
## The protected clips intentionally contain no blend-shape tracks.
const Driver = preload("res://scripts/character_animation_driver.gd")
const Residency = preload("res://scripts/zone_residency_service.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor := Node3D.new()
	var skeleton := Skeleton3D.new()
	skeleton.name="Skeleton3D"
	skeleton.add_bone("pelvis")
	actor.add_child(skeleton)
	var mesh := MeshInstance3D.new()
	mesh.name="AmbientMesh"
	var resource := ArrayMesh.new()
	resource.add_blend_shape("Pulse")
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	var shape: Array=[]
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(0,0,0.1),Vector3(1,0,0.1),Vector3(0,1,0.1)])
	resource.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[shape])
	mesh.mesh=resource
	actor.add_child(mesh)
	mesh.set_blend_shape_value(0,0.17)
	actor.set_meta("authored_creature_ambient",true)
	var ownership := [{"node_path":"AmbientMesh","shape_name":"Pulse","neutral_weight":0.17}]
	actor.set_meta("authored_creature_ambient_morphs",ownership)
	var player := AnimationPlayer.new()
	player.name="AnimationPlayer"
	actor.add_child(player)
	var library := AnimationLibrary.new()
	library.add_animation("Idle",_clip(false))
	library.add_animation("Ambient",_clip(true))
	player.add_animation_library("",library)
	root.add_child(actor)
	var driver := Driver.new()
	actor.add_child(driver)
	_check(driver.configure(actor,{"idle":"Idle","walk":"Idle","hit":"Idle","death":"Idle"}),"real graph resolves the declared native morph")
	if not driver.is_valid():
		_finish(actor)
		return
	driver.set_external_tick(true)
	_check(driver.ambient_morph_bindings.size()==1,"the actual mesh/index binding is cached once")
	_start_ambient(driver,mesh)
	driver.set_locomotion_motion(Vector3.RIGHT,true)
	_neutral(mesh,"movement immediately releases ambient deformation")
	driver.advance_external(0.05)
	_neutral(mesh,"outgoing ambient crossfade cannot reapply movement's stale weights")
	_start_ambient(driver,mesh)
	_check(driver.trigger_action("hit",1.0,0.14,true,0.4),"protected action has its original native clock")
	_neutral(mesh,"protected action immediately clears an unrelated ambient shape")
	driver.advance_external(0.05)
	_neutral(mesh,"protected clip without morph tracks stays neutral after graph evaluation")
	_check(is_equal_approx(driver.action_duration,0.4),"morph cleanup never changes the action duration")
	_start_ambient(driver,mesh)
	driver.set_dialogue_pose(true)
	driver.advance_external(0.05)
	_neutral(mesh,"dialogue owns a neutral ambient shape through the crossfade")
	_start_ambient(driver,mesh)
	driver.clear_observation_clip()
	driver.sample_pose()
	_neutral(mesh,"explicit cancellation and direct pose sampling both restore authored neutral")
	_start_ambient(driver,mesh)
	driver.set_distance_suspended(true)
	_neutral(mesh,"distance suspension neutralizes the visible shape without another tick")
	driver.advance_external(0.5)
	_neutral(mesh,"suspended clocks cannot reapply an ambient deformation")
	driver.set_distance_suspended(false)
	_start_ambient(driver,mesh)
	driver.set_dead()
	driver.advance_external(0.05)
	_neutral(mesh,"terminal pose cannot retain inflated sacs or moving antennae")
	driver.reset_for_journey_restore()
	_neutral(mesh,"journey restoration starts from the authored neutral")
	driver.free()
	var invalid := Driver.new()
	actor.add_child(invalid)
	actor.set_meta("authored_creature_ambient_morphs",[{"node_path":"missing","shape_name":"Pulse","neutral_weight":0.17}])
	_check(not invalid.configure(actor,{"idle":"Idle"}),"an unresolved morph binding fails the animation contract")
	actor.set_meta("authored_creature_ambient_morphs",[{"node_path":"AmbientMesh","shape_name":"Pulse","neutral_weight":NAN}])
	_check(not invalid.configure(actor,{"idle":"Idle"}),"a nonfinite authored neutral fails the animation contract")
	actor.set_meta("authored_creature_ambient_morphs",ownership+ownership)
	_check(not invalid.configure(actor,{"idle":"Idle"}),"duplicate ownership of a native morph is rejected")
	invalid.free()
	actor.set_meta("authored_creature_ambient_morphs",ownership)
	var retiring := Driver.new()
	actor.add_child(retiring)
	_check(retiring.configure(actor,{"idle":"Idle","walk":"Idle"}),"retiring branch starts with a valid playback owner")
	if retiring.is_valid():
		retiring.set_external_tick(true)
		_start_ambient(retiring,mesh)
	var residency := Residency.new()
	residency._release_zone_render_resources(actor)
	_check(mesh.mesh==null,"retirement detaches mesh resources")
	_check(not retiring.is_valid() and retiring.ambient_morph_bindings.is_empty() and not skeleton.has_meta("character_motion_owner"),"retirement clears playback bindings before final deletion")
	residency.free()
	_finish(actor)

func _clip(morph: bool) -> Animation:
	var clip := Animation.new()
	clip.length=2.0
	clip.loop_mode=Animation.LOOP_LINEAR
	var bone := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(bone,NodePath("Skeleton3D:pelvis"))
	clip.position_track_insert_key(bone,0.0,Vector3.ZERO)
	clip.position_track_insert_key(bone,2.0,Vector3.ZERO)
	if morph:
		var track := clip.add_track(Animation.TYPE_BLEND_SHAPE)
		clip.track_set_path(track,NodePath("AmbientMesh:Pulse"))
		clip.blend_shape_track_insert_key(track,0.0,0.7)
		clip.blend_shape_track_insert_key(track,1.0,0.9)
		clip.blend_shape_track_insert_key(track,2.0,0.7)
	return clip

func _start_ambient(driver: Node, mesh: MeshInstance3D) -> void:
	driver.stop_story_gesture()
	driver.stop_action()
	driver.set_locomotion_motion(Vector3.ZERO,true)
	_check(driver.set_observation_clip("Ambient"),"ambient owner acquires its native clip")
	for tick in 10: driver.advance_external(0.05)
	_check(mesh.get_blend_shape_value(0)>0.4,"real native ambient playback visibly owns its morph")

func _neutral(mesh: MeshInstance3D, message: String) -> void:
	_check(is_equal_approx(mesh.get_blend_shape_value(0),0.17),message)

func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

func _finish(actor: Node3D) -> void:
	actor.free()
	for failure: String in failures: printerr("AMBIENT MORPH OWNERSHIP: "+failure)
	print("AMBIENT MORPH OWNERSHIP: %s checks=%d" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
