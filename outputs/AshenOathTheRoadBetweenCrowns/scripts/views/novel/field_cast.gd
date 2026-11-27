extends RefCounted
## A short-lived visual lease. Existing people keep their interaction and registry.
const Cast = preload("res://scripts/story_cast_profile.gd")
const Presence = preload("res://scripts/character_presence.gd")
const Area = preload("res://scripts/interactable.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
const ActorMark = preload("res://scripts/views/novel/field_actor_mark.gd")
const AnimationDriver = preload("res://scripts/character_animation_driver.gd")
const Pose = preload("res://scripts/views/novel/field_body_pose.gd")

var actor: Node3D
var driver: AnimationDriver
var mark: ActorMark
var relay: RemoteTransform3D
var pose: Pose
var temporary := false
var prior_transform := Transform3D.IDENTITY
var prior_clock := {}
var hidden: Array[Node3D] = []
var interrupted := false
var id := ""
var last_foot := Vector3.INF
var bearer_yaw_offset := 0.0

static func resident(zone: Node3D, identity: String) -> Node3D:
	var person := Cast.registered_actor(zone, identity)
	if person == null:
		person = zone.get_node_or_null(NodePath(identity)) as Area
	return person

## Promote the source pack once, including an in-flight cache-only preload.
## The shared pack manager owns mounting, retries and other consumers.
static func request_missing_actor(game: Node, role: String, path: String, requested: Dictionary) -> void:
	var packs = game.get("runtime_packs")
	if packs == null or path.is_empty(): return
	var pack_id: String = packs.actor_pack(role)
	if requested.has(pack_id) or not path in packs.get_pack(pack_id).get("contents", []): return
	requested[pack_id] = true
	packs.request_pack(pack_id, 20)

func take(game: Node, parent: Node3D, point: ActorMark, identity: String, role: String, requested: Dictionary = {}) -> bool:
	id = identity
	mark = point
	actor = resident(game.zone_root, id)
	if actor != null:
		if not actor.is_visible_in_tree() or Presence.has_protected_owner(actor) or actor.is_queued_for_deletion():
			return false
		driver = actor.find_child("CharacterAnimationDriver", true, false) as AnimationDriver
	else:
		# Prepared native packs may mount after the beat is reconstructed.
		var path: String = game.asset_helper.role_resource_path(role, true)
		if path.is_empty() or not ResourceLoader.exists(path):
			request_missing_actor(game, role, path, requested)
			return false
		var visual: Node3D = game.asset_helper.spawn_visual_role(role, "characters")
		if visual == null: return false
		temporary = true
		var body := Area.new()
		body.setup(id, "presentation", "")
		body.name = "FieldActor_" + id
		body.collision_layer = 0
		body.collision_mask = 0
		body.input_ray_pickable = false
		body.set_interaction_enabled(false)
		body.visible = false
		parent.add_child(body)
		body.global_position = point.global_position
		body.add_child(visual)
		actor = body
		Presentation.apply_npc(body, id if Cast.canonical_identity(id) != "" else role, false)
		if game._configure_npc_animation(visual, id):
			driver = visual.get_node_or_null("CharacterAnimationDriver") as AnimationDriver
	if not is_instance_valid(driver) or not driver.is_valid() or driver.dead or driver.story_dialogue_active or driver.has_active_action():
		_discard_temporary()
		return false
	if not Presence.claim(actor, "work", get_instance_id()):
		_discard_temporary()
		return false
	game.player.write_presentation_tag(actor, &"cast_work_cancel", _yield_to_dialogue)
	prior_transform = actor.transform
	prior_clock = driver.capture_clock()
	driver.set_distance_suspended(false)
	driver.set_external_tick(false)
	if temporary: actor.show()
	# Transform the actor only while this marker owns it. Its original parent,
	# interaction registration and capsule remain in place throughout.
	var facing: Vector3 = driver.get_visible_forward()
	var wanted := -point.global_basis.z.slide(Vector3.UP).normalized()
	var yaw := facing.signed_angle_to(wanted, Vector3.UP) if not facing.is_zero_approx() else 0.0
	var basis := Basis(Vector3.UP, yaw) * actor.global_basis.orthonormalized()
	bearer_yaw_offset = wanted.signed_angle_to(-basis.z.slide(Vector3.UP).normalized(), Vector3.UP)
	relay = RemoteTransform3D.new()
	point.add_child(relay)
	relay.global_basis = basis
	relay.update_scale = false
	relay.remote_path = relay.get_path_to(actor)
	actor.global_transform = Transform3D(basis.scaled_local(actor.global_basis.get_scale()), point.global_position)
	pose = Pose.new()
	pose.name = "FieldContactPose"
	driver.skeleton.add_child(pose)
	pose.bind(point, driver)
	for label in ["OccupationEquipment", "SupportedStaffEquipment", "InteractionWorldLabel"]:
		var item := actor.find_child(label, true, false) as Node3D
		if item != null and item.visible:
			hidden.append(item)
			item.hide()
	return true

func _yield_to_dialogue() -> void:
	# A higher-priority owner can use this person at the spot where Kael spoke.
	interrupted = true
	detach()

func follow_bearer(floor_y: float, delta: float) -> void:
	if not is_instance_valid(relay) or not is_instance_valid(actor) or delta <= 0.0: return
	var floor_point := mark.global_position
	floor_point.y = floor_y
	var forward := -mark.global_basis.z.slide(Vector3.UP).normalized()
	if not forward.is_zero_approx():
		relay.global_basis = Basis(Vector3.UP, bearer_yaw_offset) * Basis.looking_at(forward, Vector3.UP)
	relay.global_position = floor_point
	var velocity := (floor_point - last_foot) / delta if last_foot.is_finite() else Vector3.ZERO
	velocity.y = 0.0
	driver.set_locomotion_motion(velocity.limit_length(4.0), true)
	last_foot = floor_point

func detach() -> void:
	if is_instance_valid(relay):
		relay.remote_path = NodePath()
		relay.free()
	if is_instance_valid(pose):
		pose.active = false
		pose.free()
	if not is_instance_valid(actor): return
	Presence.release(actor, "work", get_instance_id())
	for item in hidden:
		if is_instance_valid(item): item.show()
	hidden.clear()
	if is_instance_valid(driver) and not prior_clock.is_empty():
		driver.restore_clock(prior_clock)
		prior_clock.clear()

func release() -> void:
	detach()
	if is_instance_valid(actor):
		if temporary:
			_discard_temporary()
		elif not actor.is_queued_for_deletion() and not Presence.has_protected_owner(actor) and (not is_instance_valid(driver) or not driver.dead):
			actor.transform = prior_transform
	actor = null

func _discard_temporary() -> void:
	if temporary and is_instance_valid(actor):
		actor.hide()
		actor.queue_free()
	actor = null
