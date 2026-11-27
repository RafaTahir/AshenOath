extends Node3D

## The three station origins follow tor_wrist in act 2. Bank and load keep
## their original world position as the point of work moves into the yard.
const BANK_OFFSETS := [Vector3.ZERO, Vector3(4.6,0,-2.9), Vector3(1.5,0,-3.1)]
const HINGE := Vector3(-1.24, 1.53, -1.52)
const FALLEN_ANGLE := -17.0
const SHORED_ANGLE := -4.0
var beat := -1

func _ready() -> void:
	if beat < 0:
		set_beat(0)

func set_beat(index: int) -> void:
	if beat == index:
		return
	beat = index
	var markers := get_node("Actors")
	for node in markers.get_children():
		markers.remove_child(node)
		node.queue_free()
	visible = beat >= 0 and beat < BANK_OFFSETS.size()
	if not visible:
		return
	var art := get_node("Mill/Art")
	for piece in ["GalleryBank", "Shores", "CaughtChain", "FreedChain"]:
		art.get_node(piece).position = BANK_OFFSETS[beat]
	art.get_node("FallenLoad").position = BANK_OFFSETS[beat] + HINGE
	art.get_node("Shores").visible = beat > 0
	art.get_node("CaughtChain").visible = beat == 0
	art.get_node("FreedChain").visible = beat > 0
	art.get_node("DressingBench").visible = beat == 1
	art.get_node("MarkingHorses").visible = beat == 2
	match beat:
		0:
			_actor("wheelkeeper", "generic_villager_01", "supported", Vector3(.90,.235,-.60), Vector3(0,0,-1))
			var tor := _actor("blacksmith_tor", "blacksmith_tor", "brace_load", Vector3(-.40,0,-1.08), Vector3(.15,0,-.99))
			_hand(tor, "LeftHand", Vector3(-.38,1.13,-1.369))
			_hand(tor, "RightHand", Vector3(-.03,1.01,-1.369))
		1:
			var tor := _actor("blacksmith_tor", "blacksmith_tor", "seated", Vector3(-.05,.49,-1.21), Vector3(.12,0,.99))
			_hand(tor, "LeftHand", Vector3(.20,.89,-.98))
			_hand(tor, "RightHand", Vector3(.04,.90,-.94))
			var mira := _actor("mira", "mira", "kneel", Vector3(.63,0,-.71), Vector3(-.82,0,-.57))
			mira.set_meta("kneel_height", .50)
			_hand(mira, "LeftHand", Vector3(.27,.88,-1.03))
			_hand(mira, "RightHand", Vector3(.18,.91,-.93))
		2:
			var tor := _actor("blacksmith_tor", "blacksmith_tor", "indicate", Vector3(.94,0,-.72), Vector3(-.8,0,-.40))
			_hand(tor, "RightHand", Vector3(.67,1.15,-.90))
			var nera := _actor("saga_nera", "saga_nera", "work", Vector3(-.50,0,-.87), Vector3(.22,0,-.98))
			_hand(nera, "LeftHand", Vector3(-.40,.906,-1.08))
			_hand(nera, "RightHand", Vector3(-.28,.915,-1.00))
	set_work(0.0)

func set_work(progress: float) -> void:
	if beat < 0 or beat >= BANK_OFFSETS.size():
		return
	var lift := smoothstep(0.02, 0.92, clampf(progress,0.0,1.0)) if beat == 0 else 1.0
	var angle := lerpf(FALLEN_ANGLE, SHORED_ANGLE, lift)
	var load_mesh: Node3D = get_node("Mill/Art/FallenLoad")
	load_mesh.rotation.z = deg_to_rad(angle)
	if beat == 0:
		var tor := get_node("Actors/blacksmith_tor") as Marker3D
		for hand in ["LeftHand", "RightHand"]:
			var along := .85 if hand == "LeftHand" else 1.13
			var contact: Vector3 = HINGE + Basis(Vector3.BACK, deg_to_rad(angle)) * Vector3(along,-.144,.15)
			tor.get_node(hand).position = tor.transform.affine_inverse() * contact

func _actor(id: String, role: String, pose: String, at: Vector3, forward: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = id
	marker.position = at
	marker.rotation.y = atan2(-forward.x, -forward.z)
	marker.set_meta("identity", id)
	marker.set_meta("role", role)
	marker.set_meta("pose", pose)
	get_node("Actors").add_child(marker)
	return marker

func _hand(actor: Marker3D, label: String, contact: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = actor.transform.affine_inverse() * contact
	actor.add_child(marker)
