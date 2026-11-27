extends Node3D
## Visual projection only. The active station and the route still belong to the novel director.
## The origin stays clear for Use. Actors/-Z points headward on beds and faces the work otherwise.
var _beat := -1
const CART_AT := Vector3(-0.76, 0.33, -1.69)
const LEVER_AT := Vector3(-0.76, 0.82, -1.61)
const LITTER_AT := Vector3(-0.87, 0.14, -2.14)
const WARD_AT := Vector3(-0.06, 0, -1.55)

func set_beat(index: int) -> void:
	if index == _beat: return
	_beat = index
	for marker in $Actors.get_children():
		$Actors.remove_child(marker)
		marker.queue_free()
	for part: Node3D in [$Cart,$Bank,$Litter,$Ward,$Wreck,$Lever]:
		part.hide()
	match index:
		0:
			$Cart.transform = Transform3D(Basis.IDENTITY,Vector3(0.66,0,-1.93))
			$Cart.show()
			_person("saga_nera","saga_nera","watch",Vector3(-0.42,0,-1.21),Vector3(-1.45,0,-1.45))
			_person("patrolman","castle_guard_human","guard",Vector3(-1.48,0,-1.44),Vector3(-0.42,0,-1.21))
		1:
			$Bank.position = Vector3(-0.71,0,-1.52)
			$Bank.show()
			$Cart.show()
			$Lever.show()
			set_work(0)
			var trapped := _person("patrolman","castle_guard_human","kneel",Vector3(-1.79,0,-0.93), Vector3(-1.66,0,-1.64))
			trapped.set_meta("lean_degrees",21.0)
			_hand(trapped,"LeftHand",Vector3(-1.55,0.56,-1.50))
			_hand(trapped,"RightHand",Vector3(-1.74,0.58,-1.50))
			var nera := _person("saga_nera","saga_nera","brace",Vector3(0.57,0,-1.19),Vector3(-0.52,0,-1.55))
			_hand(nera,"LeftHand",LEVER_AT+Vector3(1.33,0.26,0.31))
			_hand(nera,"RightHand",LEVER_AT+Vector3(1.03,0.22,0.26))
			# The low stone at the foot of the milestone supports Rook after the shaft catches him.
			var seated := _person("rook","rook_human","seated",Vector3(1.49,0.35,-2.14),Vector3(-1.43,0,-1.32))
			seated.set_meta("support","milestone")
		2:
			$Litter.transform = Transform3D(Basis.IDENTITY,LITTER_AT)
			$Litter.show()
			$Wreck.position = Vector3(1.0,0,-2.35)
			$Wreck.show()
			# The torn sleeve is on the broken axle now, and the patrolman is clear of the water.
			_person("patrolman","castle_guard_human","rest",Vector3(1.44,0,-1.53),Vector3(-0.83,0,-1.48))
			var patient := _person("rook","rook_human","supported",LITTER_AT+Vector3(0,-0.079,1.27),LITTER_AT+Vector3(0,0,0.27))
			patient.set_meta("support","ground_litter")
			_person("mira","mira_human","kneel",LITTER_AT+Vector3(-0.70,-0.14,0.74),LITTER_AT+Vector3(0,0,0.74))
		3,4:
			$Ward.position = WARD_AT
			$Ward.show()
			_person("saga_nera","saga_nera","guard",WARD_AT+Vector3(1.01,0,1.20),Vector3(1.74,0,1.15))
			if index == 4:
				var patient := _person("rook","rook_human","supported",WARD_AT+Vector3(-0.66,0.522,-0.44),WARD_AT+Vector3(-0.66,0,-1.44))
				patient.set_meta("support","washroom_bed")
				# Kael and Elna have set the empty carrier against the outside of the linen screen.
				$Litter.transform = Transform3D(Basis(Vector3.RIGHT,-1.16), WARD_AT+Vector3(1.58,0.035,-1.45))
				$Litter.show()
			_person("mira","mira_human","watch" if index == 3 else "kneel",WARD_AT+Vector3(-1.27,0,0.29),WARD_AT+Vector3(-0.66,0,-0.44))

func set_work(progress: float) -> void:
	if _beat != 1: return
	var lift := smoothstep(0.12,0.86,clampf(progress,0,1))
	# Nera bears on the outside of the lever while Kael frees the sleeve at the axle.
	$Cart.position = CART_AT + Vector3.UP * 0.037 * lift
	$Cart.rotation = Vector3(-0.08,0.06,0.32-0.078*lift)
	$Lever.position = LEVER_AT
	$Lever.rotation.z = -0.095 * lift
	var nera: Node3D = $Actors.get_node_or_null("saga_nera")
	if nera != null:
		for spec: Array in [["LeftHand", Vector3(1.33,0.26,0.31)],["RightHand", Vector3(1.03,0.22,0.26)]]:
			var target: Node3D = nera.get_node_or_null(str(spec[0]))
			if target != null:
				target.position = nera.transform.affine_inverse() * ($Lever.transform * Vector3(spec[1]))

func _person(id: String, role: String, pose: String, position_at: Vector3, facing: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = id
	marker.position = position_at
	var direction := facing-position_at
	marker.rotation.y = atan2(-direction.x,-direction.z)
	marker.set_meta("identity",id)
	marker.set_meta("role",role)
	marker.set_meta("pose",pose)
	$Actors.add_child(marker)
	return marker

func _hand(marker: Marker3D, side: String, spot: Vector3) -> void:
	var target := Marker3D.new()
	target.name = side
	target.position = marker.transform.affine_inverse() * spot
	marker.add_child(target)
