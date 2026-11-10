extends SceneTree

## Candidate-only retained GLTF proof. No production import/cache replacement,
## world construction, save changes, attack recalibration or visual acceptance.
const Driver = preload("res://scripts/character_animation_driver.gd")
const Contract = preload("res://tools/creature_ambient_source_contract.gd")
const NativeEquivalence = preload("res://tools/creature_candidate_native_contract.gd")
const CANDIDATES := {
	"M15": {
		"source": "art_source/art_recovery_v2/models/living_assets_stage3_20261107/creatures/M15/M15_living_candidate.glb",
		"shapes": ["Sac0_Inflate", "Sac1_Inflate", "Sac2_Inflate"],
	},
	"M16": {
		"source": "art_source/art_recovery_v2/models/living_assets_stage3_20261107/creatures/M16/M16_living_candidate.glb",
		"shapes": ["AntennaProbe_L", "AntennaProbe_R", "BrushFeed_L", "BrushFeed_R"],
	},
}
const INTERRUPTIONS := ["movement", "attack", "hit", "dialogue", "cancel", "distance", "death", "restore"]
var checks := 0
var failures: Array[String] = []
var bindings: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var interruption_samples: Array[Dictionary] = []
var options: Dictionary = {}
var proof: Dictionary = {}
var native_equivalence: Dictionary = {}
var source_path := ""
var asset := ""
var expected_shapes: Array[String] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair := argument.substr(2).split("=",true,1)
			options[pair[0]]=pair[1]
	call_deferred("_run")

func _run() -> void:
	asset=str(options.get("asset",""))
	if not CANDIDATES.has(asset):
		_check(false,"Explicit --asset=M15 or --asset=M16 is required for this scoped actual-morph fixture")
		_finish(null)
		return
	var candidate: Dictionary=CANDIDATES[asset]
	expected_shapes.assign(candidate.shapes)
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	source_path=repository.path_join(str(candidate.source))
	if not FileAccess.file_exists(source_path):
		_check(false,"The immutable source-reviewed "+asset+" candidate exists")
		_finish(null)
		return
	var source_sha := FileAccess.get_sha256(source_path)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(source_path,state)
	_check(error==OK,"Actual candidate GLTF imports without production cache replacement")
	if error!=OK:
		_finish(null)
		return
	var visual := document.generate_scene(state) as Node3D
	_check(visual!=null,"Actual candidate produces its retained scene")
	if visual==null:
		_finish(null)
		return
	root.add_child(visual)
	var root_transform := visual.transform
	native_equivalence=NativeEquivalence.compare(visual,source_path.get_base_dir().path_join(asset+"_retained_input.glb"))
	_check(bool(native_equivalence.get("verified",false)),"Retained raw native frames/rests/actual bounds match: "+str(native_equivalence.get("errors",[])))
	if not bool(native_equivalence.get("verified",false)):
		_finish(visual)
		return
	proof=Contract.apply_candidate(visual,asset)
	_check(bool(proof.get("verified",false)) and bool(proof.get("candidate_only",false)) and not proof.has("error"),"Actual native candidate passes exact source/clip/morph bindings: "+str(proof.get("error","")))
	if not bool(proof.get("verified",false)) or proof.has("error"):
		_finish(visual)
		return
	_check(str(proof.get("source_sha256",""))==source_sha,"Candidate proof binds the exact imported bytes")
	for raw: Dictionary in proof.get("morph_bindings",[]):
		var mesh := visual.get_node_or_null(str(raw.node_path)) as MeshInstance3D
		var index := mesh.find_blend_shape_by_name(str(raw.shape_name)) if mesh!=null else -1
		_check(mesh!=null and mesh.mesh!=null and index>=0,"Authored morph resolves to actual candidate geometry: "+str(raw.shape_name))
		if mesh!=null and index>=0:
			bindings.append({"mesh":mesh,"index":index,"shape":str(raw.shape_name),"neutral":float(raw.neutral_weight)})
	var names: Array[String]=[]
	for binding: Dictionary in bindings:names.append(str(binding.shape))
	names.sort()
	_check(names==expected_shapes,"All "+str(expected_shapes.size())+" explicit "+asset+" shapes have independent native morph ownership")
	var original_clips := _clip_fingerprints(Contract._player(visual))
	var driver := Driver.new()
	visual.add_child(driver)
	_check(driver.configure(visual,{"idle":"Idle","walk":"Walking","run":"Running","attack":"Attack","hit":"HitReact","dialogue":"Interact","death":"Death"}),"Actual retained driver binds candidate rig: "+str(driver.contract_errors))
	if not driver.is_valid():
		_finish(visual)
		return
	driver.set_external_tick(true)
	_check(driver.ambient_morph_bindings.size()==expected_shapes.size(),"Driver caches every expected real mesh/index/neutral binding")
	var rest: Array[Transform3D]=[]
	for bone in driver.skeleton.get_bone_count():rest.append(driver.skeleton.get_bone_rest(bone))
	for clip: String in Contract.CLIPS:
		_measure_clip(driver,clip)
	for interruption: String in INTERRUPTIONS:
		# Authored pulses may be staggered; simultaneous activation is not required.
		# Exercise every cached shape at its own real nonneutral native phase.
		for binding: Dictionary in bindings:
			_exercise_interruption(driver,interruption,binding)
	_check(interruption_samples.size()==INTERRUPTIONS.size()*expected_shapes.size(),"All eight interruptions exercise each expected actual nonneutral shape")
	_check(visual.transform.is_equal_approx(root_transform),"Candidate lifecycle never moves the retained visual root")
	for bone in rest.size():
		_check(driver.skeleton.get_bone_rest(bone).is_equal_approx(rest[bone]),"Retained bone rest remains unchanged: "+str(bone))
	_check(_clip_fingerprints(driver.animation_player)==original_clips,"Driver preserves every imported ambient and protected animation curve")
	_check(FileAccess.get_sha256(source_path)==source_sha,"Candidate source bytes remain unchanged after runtime proof")
	_check(not bindings.is_empty() and _activate_shape(driver,bindings[0]),"Native ambient reacquires after all interruptions")
	driver.free()
	_neutral("Final driver teardown clears actual morph ownership")
	_finish(visual)

func _begin(driver: Node, clip: String) -> bool:
	driver.set_distance_suspended(false)
	driver.reset_for_journey_restore()
	driver.set_locomotion_motion(Vector3.ZERO,true)
	if not driver.set_observation_clip(clip):return false
	for tick in 120:
		driver.advance_external(1.0/60.0)
		var sample: Dictionary=driver.observation_motion_sample()
		if not sample.is_empty() and float(sample.time)>0.10:return true
	return false

func _measure_clip(driver: Node, clip: String) -> void:
	_check(_begin(driver,clip),"Actual candidate starts native "+clip)
	var sample: Dictionary=driver.observation_motion_sample()
	if sample.is_empty():return
	var ranges: Dictionary={}
	for binding: Dictionary in bindings:ranges[binding.shape]=Vector2(INF,-INF)
	for tick in ceili(float(sample.duration)*120.0):
		driver.advance_external(1.0/60.0)
		for binding: Dictionary in bindings:
			var weight: float=binding.mesh.get_blend_shape_value(int(binding.index))
			_check(is_finite(weight),clip+" has finite actual "+str(binding.shape)+" deformation")
			var extent: Vector2=ranges[binding.shape]
			ranges[binding.shape]=Vector2(minf(extent.x,weight),maxf(extent.y,weight))
	var result := {"clip":clip,"duration":sample.duration,"actual_mesh_ranges":{}}
	for shape: String in ranges:
		var extent: Vector2=ranges[shape]
		_check(extent.y-extent.x>0.0001,clip+" visibly changes the real "+shape+" weight")
		result.actual_mesh_ranges[shape]=[extent.x,extent.y]
	samples.append(result)

func _exercise_interruption(driver: Node, interruption: String, binding: Dictionary) -> void:
	var label := interruption+" while "+str(binding.shape)+" is nonneutral"
	if not _activate_shape(driver,binding):
		_check(false,"Actual native morph becomes nonneutral before "+label)
		return
	var sample: Dictionary=driver.observation_motion_sample().duplicate(true)
	sample["interruption"]=interruption
	sample["target_shape"]=binding.shape
	sample["actual_weights"]={}
	for actual: Dictionary in bindings:
		sample.actual_weights[actual.shape]=float(actual.mesh.get_blend_shape_value(int(actual.index)))
	interruption_samples.append(sample)
	var action_length := 0.0
	match interruption:
		"movement":driver.set_locomotion_motion(Vector3.RIGHT,true)
		"attack", "hit":
			var clip: StringName=driver.get_clip_for_state(interruption)
			action_length=driver.animation_player.get_animation(clip).length
			_check(driver.trigger_action(interruption),"Protected retained "+interruption+" takes ownership")
			_check(is_equal_approx(driver.action_duration,action_length),"Morph cleanup preserves the original "+interruption+" duration")
		"dialogue":driver.set_dialogue_pose(true)
		"cancel":driver.clear_observation_clip()
		"distance":driver.set_distance_suspended(true)
		"death":driver.set_dead()
		"restore":driver.reset_for_journey_restore()
	_neutral(label+" releases all actual morphs immediately")
	for tick in 6:
		driver.advance_external(0.025)
		_neutral(label+" stays neutral through outgoing native crossfade "+str(tick))
	driver.sample_pose()
	_neutral(label+" direct pose sampling cannot revive stale weights")

func _activate_shape(driver: Node, binding: Dictionary) -> bool:
	if not _begin(driver,"Idle"):return false
	for tick in 300:
		if absf(float(binding.mesh.get_blend_shape_value(int(binding.index)))-float(binding.neutral))>0.0001:return true
		driver.advance_external(1.0/60.0)
	return false

func _neutral(label: String) -> void:
	for binding: Dictionary in bindings:
		_check(absf(float(binding.mesh.get_blend_shape_value(int(binding.index)))-float(binding.neutral))<0.000001,label+": "+str(binding.shape))

func _clip_fingerprints(player: AnimationPlayer) -> Dictionary:
	var result := {}
	for name: StringName in player.get_animation_list():
		var animation := player.get_animation(name)
		var values: Array=[animation.length,animation.loop_mode]
		for track in animation.get_track_count():
			values.append([animation.track_get_type(track),str(animation.track_get_path(track)),animation.track_is_enabled(track),animation.track_get_interpolation_type(track)])
			for key in animation.track_get_key_count(track):values.append([animation.track_get_key_time(track,key),animation.track_get_key_value(track,key)])
		result[str(name)]=var_to_str(values).sha256_text()
	return result

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _finish(visual: Node3D) -> void:
	bindings.clear()
	if is_instance_valid(visual):visual.free()
	var report := {"asset":asset,"candidate_only":true,"status":"pass" if failures.is_empty() else "fail","checks":checks,"failures":failures,"source_path":source_path,"expected_shapes":expected_shapes,"expected_binding_count":expected_shapes.size(),"expected_interruption_count":INTERRUPTIONS.size()*expected_shapes.size(),"binding_proof":proof,"native_equivalence":native_equivalence,"samples":samples,"interruption_samples":interruption_samples,"visual_accepted":false,"production_source_changed":false,"attack_profiles_recalibrated":false}
	var output := str(options.get("output",""))
	if output!="":
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file==null:
			failures.append("Cannot write requested candidate proof receipt")
		else:file.store_string(JSON.stringify(report,"\t"))
	for failure: String in failures:printerr("CREATURE CANDIDATE MORPHS: "+failure)
	print("CREATURE CANDIDATE MORPHS: %s checks=%d candidate_only=true visual_accepted=false" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
