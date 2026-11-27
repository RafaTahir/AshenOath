extends "res://scripts/views/novel/field_stage.gd"

## The chair has the same dimensions as the finished one at the freight door.
## Its front joint rests in Tor's hands. Only Toma wields the mallet.
const ActorMark = preload("res://scripts/views/novel/field_actor_mark.gd")
const Artist = preload("res://scripts/views/novel/field_cast.gd")
const Places = preload("res://scripts/builders/novel/working_places.gd")
const Woodwork = preload("res://scripts/builders/novel/tabletop.gd")
const CHAIR_AT := Vector3(0, 0, -1.70)
const JOINT := CHAIR_AT + Vector3(0.222, 0.525, -0.21)
const PEG_LENGTH := 0.115
const END_GRAIN := Color("#aa8054")
const MALLET_WOOD := Color("#80573a")

var setup := Node3D.new()
var actors := Node3D.new()
var peg: MeshInstance3D
var mallet := Node3D.new()
var grip: Marker3D
var worker_present := false
var progress := 0.0

func _ready() -> void:
	# The open side faces the station approach, so the backrest leaves the hands visible.
	var angle := Basis(Vector3.UP, deg_to_rad(78.0))
	setup.name = "Woodwork"
	setup.transform = Transform3D(angle, CHAIR_AT - angle * CHAIR_AT)
	add_child(setup)
	actors.transform = setup.transform
	actors.name = "Actors"
	add_child(actors)
	var chair := Node3D.new()
	chair.name = "Chair"
	chair.position = CHAIR_AT
	setup.add_child(chair)
	Places._build(chair, "rest_chair", "")
	# Front apron joins the two legs just beneath the seat.
	Woodwork.box(chair, Vector3(0, 0.405, -0.21), Vector3(0.46, 0.07, 0.054), Woodwork.WOOD)
	var dowel := CylinderMesh.new()
	dowel.top_radius = 0.016
	dowel.bottom_radius = 0.014
	dowel.height = PEG_LENGTH
	dowel.radial_segments = 10
	dowel.rings = 0
	peg = Woodwork.part(setup, dowel, JOINT, END_GRAIN)
	peg.name = "Peg"
	mallet.name = "Mallet"
	setup.add_child(mallet)
	Woodwork.box(mallet, Vector3(0, 0.055, 0), Vector3(0.096, 0.11, 0.125), MALLET_WOOD)
	Woodwork.box(mallet, Vector3(0, 0.103, 0), Vector3(0.098, 0.016, 0.127), END_GRAIN)
	Woodwork.box(mallet, Vector3(0.145, 0.056, 0), Vector3(0.29, 0.034, 0.039), Woodwork.WOOD)
	var tor := _kneel("blacksmith_tor", Vector3(-0.038, 0, -2.26), Vector3(0.20, 0, -1.82))
	_hand(tor, "LeftHand", JOINT + Vector3(-0.012, -0.105, -0.057))
	_hand(tor, "RightHand", JOINT + Vector3(-0.24, -0.031, -0.069))
	var toma := _kneel("farmer_toma", Vector3(0.69, 0, -1.91), Vector3(0.23, 0, -1.78))
	_hand(toma, "LeftHand", CHAIR_AT + Vector3(0.28, 0.51, 0.084))
	grip = _hand(toma, "RightHand", JOINT)
	mallet.hide()
	_position_tools(0)

func _kneel(id: String, at: Vector3, facing: Vector3) -> ActorMark:
	var mark := ActorMark.new()
	mark.name = id
	mark.identity = id
	mark.role = id
	mark.pose = "kneel"
	mark.kneel_height = 0.40
	mark.lean_degrees = 24.0 if id == "blacksmith_tor" else 13.0
	actors.add_child(mark)
	mark.position = at
	mark.rotation.y = atan2(at.x - facing.x, at.z - facing.z)
	return mark

func _hand(mark: ActorMark, label: String, at: Vector3) -> Marker3D:
	var hand := Marker3D.new()
	hand.name = label
	mark.add_child(hand)
	hand.position = mark.transform.affine_inverse() * at
	return hand

func set_beat(index: int) -> void:
	visible = index == 2
	set_work(0.0)

func has_worker(lease: Artist) -> bool:
	return lease != null and is_instance_valid(lease.actor) and lease.actor.is_visible_in_tree() and is_instance_valid(lease.mark) and is_ancestor_of(lease.mark) and not lease.interrupted and is_instance_valid(lease.driver) and not lease.driver.dead and not lease.driver.story_dialogue_active and not lease.driver.distance_suspended and not lease.driver.has_active_action()

func set_worker_present(present: bool) -> void:
	if worker_present == present: return
	worker_present = present
	mallet.visible = present
	if present: _position_tools(progress)

func set_work(fraction: float) -> void:
	progress = clampf(fraction, 0.0, 1.0)
	if peg != null and (worker_present or progress == 0.0):
		_position_tools(progress)

func _position_tools(t: float) -> void:
	# Each swing seats the peg only as the face of the mallet bears on it.
	var first := smoothstep(0.35, 0.41, t)
	var second := smoothstep(0.69, 0.75, t)
	var depth := 0.039 * first + 0.04 * second
	peg.position = JOINT + Vector3.UP * (0.028 - depth)
	var lift := 0.036 * (1.0 - smoothstep(0.27, 0.35, t))
	lift += 0.21 * smoothstep(0.03, 0.24, t) * (1.0 - smoothstep(0.24, 0.35, t))
	lift += 0.24 * smoothstep(0.41, 0.58, t) * (1.0 - smoothstep(0.58, 0.69, t))
	lift += 0.075 * smoothstep(0.75, 0.92, t)
	mallet.position = peg.position + Vector3.UP * (PEG_LENGTH * 0.5 + lift)
	mallet.rotation.z = -0.90 * lift
	grip.global_position = mallet.to_global(Vector3(0.215, 0.056, 0))
