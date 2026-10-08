extends CharacterBody3D

const ID := "bracken"
const QUEST := "side_bracken_rescue"
const RESCUE_POSITION := Vector3(-3.3, 0.02, -12.1)
const BODY := preload("res://assets/companions/bracken.scn")
const Interactable = preload("res://scripts/interactable.gd")

var game: Node
var interaction: Area3D
var visual: Node3D
var animation_player: AnimationPlayer
var clips: Dictionary = {}
var tether: MeshInstance3D

static func install(host: Node, zone_root: Node3D, zone_id: String) -> void:
	if zone_id != "greyfen":
		return
	var companion := zone_root.get_node_or_null("Bracken")
	if companion == null:
		companion = load("res://scripts/companion_controller.gd").new()
		companion.name = "Bracken"
		companion.game = host
		companion.position = RESCUE_POSITION
		zone_root.add_child(companion)
	companion.refresh_presence()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 0.7
	shape.shape = capsule
	shape.position.y = 0.35
	add_child(shape)
	visual = BODY.instantiate()
	visual.name = "Visual"
	visual.rotation.y = PI
	add_child(visual)
	clips = visual.get_meta("animation_clips", {})
	animation_player = visual.find_child("AnimationPlayer", true, false)
	animation_player.play(str(clips.idle))
	interaction = Interactable.new()
	interaction.setup(ID, "dialogue", "Approach Bracken")
	interaction.display_name = "Bracken"
	interaction.dialogue_id = "bracken_rescue"
	interaction.set_meta("dialogue_focus_height", 0.55)
	interaction.build_collision(1.15)
	add_child(interaction)
	game._connect_interactable(interaction)
	_build_discarded_harness()
	refresh_presence()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func refresh_presence() -> void:
	if interaction == null or game == null:
		return
	var rescued: bool = bool(game.story_state.get_flag("bracken_rescued", false))
	var adopted: bool = str(game.story_state.get_flag("bracken_home", "")) == "adopted"
	interaction.state_label = "A familiar hound" if adopted else ("Safe beside the north road" if rescued else "Caught by a travelling strap")
	if tether != null:
		tether.visible = not rescued
	game.interaction_focus_dirty = true

static func choice_available(host: Node, action: Dictionary) -> bool:
	# Dialogue closes and releases proximity focus before dispatching its action.
	# Bind the actual staged actor, then recheck it against the live zone.
	var actor_id: int = int(action.get("companion_actor_instance", 0))
	var actor: Node = instance_from_id(actor_id) if actor_id > 0 else null
	if str(host.current_zone_id) != "greyfen" or not is_instance_valid(actor) or not actor is Area3D:
		return false
	if actor.is_queued_for_deletion() or not actor.is_visible_in_tree() or not is_instance_valid(host.zone_root) or not host.zone_root.is_ancestor_of(actor) or str(actor.get("interaction_id")) != ID:
		return false
	if not is_instance_valid(host.player) or host.player.global_position.distance_to(actor.global_position) > 3.6:
		return false
	if host._story_has_active_combat():
		return false
	var state = host.story_state
	match str(action.get("companion_action", "")):
		"calm": return not bool(state.get_flag("bracken_calmed", false))
		"release": return bool(state.get_flag("bracken_calmed", false)) and not bool(state.get_flag("bracken_rescued", false))
		"adopt": return bool(state.get_flag("bracken_rescued", false)) and str(state.get_flag("bracken_home", "")) != "adopted"
		"leave": return bool(state.get_flag("bracken_rescued", false)) and str(state.get_flag("bracken_home", "")) == ""
	return false

static func apply_choice(host: Node, action: Dictionary) -> bool:
	if not choice_available(host, action):
		return false
	var state = host.story_state
	var step: String = str(action.get("companion_action", ""))
	state.set_flag("bracken_companion_id", ID)
	if step == "calm":
		if not host.quests.is_active(QUEST) and not host.quests.is_completed(QUEST):
			host.quests.start_quest(QUEST)
		state.set_flag("bracken_calmed", true)
		host.quests.complete_objective(QUEST, "calm_hound")
		host.hud.toast("He stops pulling. The old strap is caught, not his leg.")
	elif step == "release":
		state.set_flag("bracken_rescued", true)
		host.quests.complete_objective(QUEST, "release_strap")
		host.hud.toast("The strap falls away. The hound steps clear and waits.")
	else:
		state.set_flag("bracken_home", "adopted" if step == "adopt" else "safe")
		state.set_flag("bracken_home_zone", "greyfen")
		host.quests.complete_choice(QUEST, "companion_choice")
		host.hud.toast("Bracken accepts your hand. He can rest safely at Greyfen." if step == "adopt" else "Bracken stays safe by Greyfen. You can return to him later.")
	return true

func _build_discarded_harness() -> void:
	# A ground prop, not anatomy attached to an unvalidated bone. The loose
	# strap disappears on release; the discarded loops remain by the road.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.16, 0.10)
	material.roughness = 0.95
	var vertices := PackedVector3Array()
	for center: Vector3 in [Vector3(-0.57, 0.035, 0.1), Vector3(-0.65, 0.045, 0.4)]:
		for i in range(18):
			var angle: float = TAU * float(i) / 18.0
			var next: float = TAU * float(i + 1) / 18.0
			var a := center + Vector3(cos(angle) * 0.31, 0, sin(angle) * 0.22)
			var b := center + Vector3(cos(next) * 0.31, 0, sin(next) * 0.22)
			var inner_a := center + (a - center) * 0.77
			var inner_b := center + (b - center) * 0.77
			vertices.append_array(PackedVector3Array([a, inner_a, b, b, inner_a, inner_b]))
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var harness := MeshInstance3D.new()
	harness.name = "DiscardedTravellingHarness"
	harness.mesh = mesh
	harness.material_override = material
	add_child(harness)
	tether = MeshInstance3D.new()
	tether.name = "CaughtStrap"
	var strap := BoxMesh.new()
	strap.size = Vector3(0.035, 0.025, 0.50)
	tether.mesh = strap
	tether.material_override = material
	tether.position = Vector3(-0.23, 0.12, 0.38)
	tether.rotation_degrees = Vector3(-24, -50, 0)
	add_child(tether)
