extends SceneTree
## Isolate the production outfit installer on the exact prepared rigs. Compare
## all sampled Attack poses to a second, untouched instance of the same body.
const Ward = preload("res://scripts/views/wychwood_burden_view.gd")

class Driver extends Node:
	var current_state := "idle"

class Bearer extends CharacterBody3D:
	var enemy_id := ""
	var dead := false
	var encounter_active := true
	var animation_driver := Driver.new()
	var raised := false

	func wood_guard_raised() -> bool:
		return raised

var failures: Array[String] = []
var checks := 0

func require(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
	for kind: String in ["wychwood_raider","wychwood_brute"]:
		var actor := Bearer.new()
		actor.enemy_id = kind
		root.add_child(actor)
		actor.add_child(actor.animation_driver)
		var scene: PackedScene
		for key: String in catalog:
			if key.begins_with(kind + "_creature|") and "_Wychwood_" in key:
				scene = load(catalog[key].path)
				break
		var reference: Node3D = scene.instantiate()
		var dressed: Node3D = scene.instantiate()
		actor.add_child(reference)
		actor.add_child(dressed)
		require(Ward.install(actor,dressed),kind + " installs")
		var body := dressed.find_child(Ward.BODIES[kind],true,false) as MeshInstance3D
		var gear := body.get_node_or_null("RoadWardrobe") as MeshInstance3D
		if gear == null:
			actor.free()
			continue
		var rig := body.get_node(body.skeleton) as Skeleton3D
		var native_rig: Skeleton3D = reference.find_children("*","Skeleton3D",true,false)[0]
		require(gear.skin == body.skin and gear.get_node(gear.skeleton) == rig,kind + " shares original bone bind table")
		require(gear.mesh.get_surface_count() == 2,kind+" two wardrobe draws")
		for i in gear.mesh.get_surface_count():
			var mat := gear.get_active_material(i) as StandardMaterial3D
			require(mat != null and mat.vertex_color_use_as_albedo and mat.albedo_texture != null,kind + " detailed pigment")
			var colors: PackedColorArray = gear.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
			var painted := false
			for pigment: Color in colors:
				if absf(pigment.r-pigment.b) > .011:
					painted = true
					break
			require(painted,kind + " exported Pigment is visible on " + mat.resource_name)
		var native: AnimationPlayer = reference.find_children("*","AnimationPlayer",true,false)[0]
		var styled: AnimationPlayer = dressed.find_children("*","AnimationPlayer",true,false)[0]
		for clip: String in ["Idle","Walking","Running","Attack"]:
			require(native.get_animation(clip) != styled.get_animation(clip),kind + " independent authored " + clip)
			require(is_equal_approx(native.get_animation(clip).length,styled.get_animation(clip).length),kind + " duration " + clip)
			native.play(clip,0)
			styled.play(clip,0)
			var max_pose_shift := 0.0
			for frame in 61:
				var time: float = native.get_animation(clip).length * frame/60.0
				native.seek(time,true)
				native.advance(0.0)
				styled.seek(time,true)
				styled.advance(0.0)
				var left := rig.find_bone("hand_l")
				var right := rig.find_bone("hand_r")
				max_pose_shift = maxf(max_pose_shift, rig.get_bone_global_pose(left).origin.distance_to(native_rig.get_bone_global_pose(left).origin))
				if clip == "Attack":
					if kind == "wychwood_brute":
						var left_foot := rig.get_bone_global_pose(rig.find_bone("foot_l")).origin
						var right_foot := rig.get_bone_global_pose(rig.find_bone("foot_r")).origin
						require(left_foot.distance_to(Vector3(.32,.08,.33)) < .018 and right_foot.distance_to(Vector3(-.29,.08,-.16)) < .018, "stationary hauling stance " + str(frame))
					require(rig.get_bone_global_pose(right).origin.distance_to(native_rig.get_bone_global_pose(right).origin)<.0001,kind+" retained contact point at "+str(frame))
			require(max_pose_shift > .055,kind + " visible independent left-hand trajectory " + clip)
		if kind == "wychwood_raider":
			var guard := rig.get_node("RoadWardGuardPose") as Ward.ShieldLift
			styled.play("Idle",0)
			styled.seek(.32,true)
			styled.advance(0)
			var before := rig.get_bone_global_pose(rig.find_bone("hand_l")).origin
			actor.raised = true
			guard._process_modification_with_delta(.2)
			var after := rig.get_bone_global_pose(rig.find_bone("hand_l")).origin
			require(after.y > before.y + .09 and guard.raised == 1.0,"alert lifts shield")
			actor.dead = true
			guard._process_modification_with_delta(.025)
			require(guard.raised == 0.0,"terminal ownership clears shield layer")
		actor.free()
	print(JSON.stringify({"checks":checks,"failures":failures,"fixture":"wychwood_burdens"}))
	quit(0 if failures.is_empty() else 1)
