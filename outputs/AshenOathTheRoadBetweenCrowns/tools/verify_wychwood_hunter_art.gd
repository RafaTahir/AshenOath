extends SceneTree

## Compare the actual native actor, production wardrobe and cooked animation data
## against a second untouched instance. All samples use the player's real evaluator.
const Dressing = preload("res://scripts/views/wychwood_hunter_wardrobe.gd")
const Enemy = preload("res://scripts/enemy_ai.gd")
const ASSETS := {
	"ghoulkin": ["167225684a08f30a29e2ea17", "BurialShroud", "hand_r", "M01"],
	"wychwood_stalker": ["9b917237c5f1da73cb1ee634", "SplinterMantle", "Hand.R", "M02"]
}
var failures: Array[String] = []
var measured := {}

func _initialize() -> void: run.call_deferred()

func expect(value: bool, label: String) -> void:
	if not value: failures.append(label)

func run() -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/native_attack_profiles.json")).profiles
	for identity: String in ASSETS:
		var spec: Array = ASSETS[identity]
		var scene := load("res://assets_external/characters_prepared/monsters/" + str(spec[0]) + ".scn") as PackedScene
		var actor := Enemy.new(false)
		root.add_child(actor)
		actor.set_physics_process(false)
		var placement := Node3D.new()
		actor.add_child(placement)
		var after := scene.instantiate() as Node3D
		var before := scene.instantiate() as Node3D
		placement.add_child(after)
		placement.add_child(before)
		expect(Dressing.install(after, identity), identity + " binds native appearance")
		expect(Dressing.install(after, identity), identity + " supports re-entry")
		var parts := after.find_children(spec[1], "MeshInstance3D", true, false)
		expect(parts.size() == 1, identity + " exactly one fitted layer")
		if parts.size() != 1:
			actor.free()
			continue
		var clothing: MeshInstance3D = parts[0]
		var first: MeshInstance3D = after.find_children("*","MeshInstance3D",true,false)[0]
		expect(clothing.skin == first.skin and clothing.get_node(clothing.skeleton) == first.get_node(first.skeleton), identity + " shares the actual skeleton and original skin")
		expect(clothing.mesh.get_surface_count() == 1 and (clothing.get_active_material(0) as StandardMaterial3D).vertex_color_use_as_albedo, identity + " single painted surface")
		var rig := first.get_node(first.skeleton) as Skeleton3D
		var original_rig := before.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		var original := before.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
		var cooked := after.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
		var probe := rig.find_bone(spec[2])
		var head := rig.find_bone("Head")
		var offset := Vector3.ZERO
		for entry: Dictionary in profiles.values():
			if entry.id == spec[3]: offset = Vector3(entry.probe_offset[0],entry.probe_offset[1],entry.probe_offset[2])
		var worst := 0.0
		var distances := {}
		for clip: String in ["Idle", "Walking", "Running", "Attack"]:
			var seconds := original.get_animation(clip).length
			expect(is_equal_approx(seconds, cooked.get_animation(clip).length), identity + "/" + clip + " retains original timing")
			expect(original.get_animation(clip) != cooked.get_animation(clip), identity + "/" + clip + " has independent baked animation")
			original.play(clip, 0)
			cooked.play(clip, 0)
			var change := 0.0
			var count := ceili(seconds * 120) + 1
			for k in count:
				var t := minf(seconds, k / 120.0)
				original.seek(t, true)
				cooked.seek(t, true)
				original.advance(0.0)
				cooked.advance(0.0)
				var a := original_rig.get_bone_global_pose(head).basis.get_rotation_quaternion()
				var b := rig.get_bone_global_pose(head).basis.get_rotation_quaternion()
				change = maxf(change, rad_to_deg(a.angle_to(b)))
				if clip == "Attack":
					var old := original_rig.get_bone_global_pose(probe) * offset
					var new_point := rig.get_bone_global_pose(probe) * offset
					worst = maxf(worst, new_point.distance_to(old))
			distances[clip] = snapped(change, .01)
			expect(change > 5.0, identity + "/" + clip + " has measurable new head/body articulation")
		expect(worst < 0.00001, identity + " 120Hz native contact sweep unchanged")
		expect(original.get_animation("Death") == cooked.get_animation("Death") and original.get_animation("HitReact") == cooked.get_animation("HitReact"), identity + " retains death and stagger owners")
		measured[identity] = {"head_rotation_delta_deg":distances, "max_probe_delta_m":worst, "surfaces":clothing.mesh.get_surface_count(), "weighted_vertices":clothing.mesh.surface_get_array_len(0)}
		actor.free()
	print(JSON.stringify({"hunter_rigs":measured,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
