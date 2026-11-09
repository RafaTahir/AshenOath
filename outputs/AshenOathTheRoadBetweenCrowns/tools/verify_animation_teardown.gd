extends SceneTree

## Minimal quit-time ownership probe. Run against either frozen project root.
## --skip-delete-hook isolates the added PREDELETE callback without editing
## runtime sources; --explicit-free contrasts normal runtime actor disposal.
var scripts_to_keep: Array[Script] = []
var actors: Array[Node3D] = []
var graph_refs: Array[WeakRef] = []
var graph_ids: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var skip_hook := "--skip-delete-hook" in OS.get_cmdline_user_args()
	var explicit_free := "--explicit-free" in OS.get_cmdline_user_args()
	var source := load("res://scripts/character_animation_driver.gd") as Script
	var driver_script: Script = source
	if skip_hook:
		var text := source.source_code
		var start := text.find("\nfunc _notification(")
		var end := text.find("\nfunc ",start+1)
		if start<0 or end<0:
			printerr("ANIMATION TEARDOWN: source lacks the callback under investigation")
			quit(1)
			return
		var probe := GDScript.new()
		probe.source_code=text.substr(0,start)+"\nfunc _notification(_what: int) -> void:\n\tpass\n"+text.substr(end)
		if probe.reload()!=OK:
			printerr("ANIMATION TEARDOWN: isolated callback variant did not compile")
			quit(1)
			return
		driver_script=probe
	scripts_to_keep.append(driver_script)
	for index in 14:
		var actor := Node3D.new()
		actor.name="TeardownActor"+str(index)
		var skeleton := Skeleton3D.new()
		skeleton.name="Skeleton3D"
		skeleton.add_bone("pelvis")
		actor.add_child(skeleton)
		var player := AnimationPlayer.new()
		player.name="AnimationPlayer"
		actor.add_child(player)
		var clip := Animation.new()
		clip.length=2.0
		clip.loop_mode=Animation.LOOP_LINEAR
		var track := clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(track,NodePath("Skeleton3D:pelvis"))
		clip.position_track_insert_key(track,0.0,Vector3.ZERO)
		clip.position_track_insert_key(track,2.0,Vector3.ZERO)
		var library := AnimationLibrary.new()
		library.add_animation("Idle",clip)
		player.add_animation_library("",library)
		root.add_child(actor)
		var driver: Node = driver_script.new()
		driver.name="CharacterAnimationDriver"
		actor.add_child(driver)
		if not driver.configure(actor,{"idle":"Idle","walk":"Idle","death":"Idle"}):
			failures.append("synthetic driver could not bind")
			actor.free()
			continue
		driver.set_external_tick(true)
		driver.advance_external(0.1)
		actors.append(actor)
		graph_ids.append(str(driver.animation_graph.get_instance_id()))
		graph_refs.append(weakref(driver.animation_graph))
	print("ANIMATION TEARDOWN GRAPHS: "+JSON.stringify({"skip_delete_hook":skip_hook,"explicit_free":explicit_free,"ids":graph_ids}))
	if "--trace-refcounted-ids" in OS.get_cmdline_user_args():
		load("res://tools/animation_teardown_id_probe.gd").emit_snapshot(root,"synthetic_before_quit")
	await process_frame
	if explicit_free:
		for actor: Node3D in actors: actor.free()
		actors.clear()
		await process_frame
		await process_frame
		for reference: WeakRef in graph_refs:
			if reference.get_ref()!=null: failures.append("graph survived explicit actor disposal")
	for failure: String in failures: printerr("ANIMATION TEARDOWN: "+failure)
	print("ANIMATION TEARDOWN: %s actors=%d quit_with_tree=%s" % ["PASS" if failures.is_empty() else "FAIL",graph_ids.size(),not explicit_free])
	quit(0 if failures.is_empty() else 1)
