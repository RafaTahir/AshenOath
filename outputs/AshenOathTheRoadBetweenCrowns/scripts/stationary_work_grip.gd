extends RefCounted

## Authored rigid attachments for stationary work. The life modifier owns
## the gesture and updates these sockets after solving the existing arms.
const SOCKET_META := &"authored_stationary_work_grip"
const RIGHT_PALMS := {
	# Retained P01 bind vertex 1298; C03 and C04 use their existing palm references.
	"kael": Vector3(0.0167170368, 0.0398732841, -0.0207214954),
	"mira": Vector3(-0.0112019479, 0.0423625708, -0.0141906738),
	"tor": Vector3(0.01958974, 0.03913165, -0.00620272),
}
const PROP_CONTACTS := {
	"cloth": Vector3(0.0, 0.115, 0.0015), # Top hem of the folded linen.
	"rope": Vector3(0.1045, 0.0, 0.0), # Outer point of the first strand.
	"bowl": Vector3(0.0964, 0.05, 0.0), # Outer lip of the tending bowl.
}


static func bind(actor: Node3D, tool: Node3D, style: String) -> void:
	if not PROP_CONTACTS.has(style):
		return
	var socket := tool as BoneAttachment3D
	if socket == null or socket.bone_name != &"hand_r" or not socket.has_meta("life_generated_activity_tool") or socket.has_meta("measured_grip"):
		return
	var node: Node = socket.get_parent()
	var identity := ""
	while node != null:
		identity = str(node.get_meta("story_cast_identity", ""))
		if identity != "" or node == actor:
			break
		node = node.get_parent()
	if style == "bowl":
		if identity != "mira" and identity != "tor":
			return
	elif identity != "kael":
		return
	if socket.get_child_count() != 1:
		return
	var grip := socket.get_child(0) as Node3D
	if grip == null or grip.get_child_count() != 1:
		return
	var mesh := grip.get_child(0) as MeshInstance3D
	if mesh == null:
		return
	socket.set_meta(SOCKET_META, {
		"style": style, "palm": RIGHT_PALMS[identity], "contact": PROP_CONTACTS[style],
		"mesh": weakref(mesh),
	})


static func update(actor: Node3D, tool: Node3D, skeleton: Skeleton3D) -> void:
	if not is_instance_valid(tool) or not tool.visible or not tool.has_meta(SOCKET_META):
		return
	var socket := tool as BoneAttachment3D
	var record: Dictionary = tool.get_meta(SOCKET_META)
	var mesh := record.mesh.get_ref() as MeshInstance3D
	if not is_instance_valid(mesh) or socket.bone_idx < 0:
		return
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(socket.bone_idx)
	var scale := hand.basis.get_scale().abs()
	if scale.x <= 0.001 or not is_equal_approx(scale.x, scale.y) or not is_equal_approx(scale.x, scale.z):
		return
	var forward := -actor.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var presentation := Basis(right, Vector3.UP, -forward)
	match str(record.style):
		"bowl":
			# Hold the near lip and keep the opening upward.
			presentation = Basis(-forward, Vector3.UP, -right)
		"rope":
			# Put the anchored rim at the top and let the coil hang below.
			presentation = Basis(Vector3.UP, -forward, right)
	var local_basis := hand.basis.orthonormalized().inverse() * presentation
	var grip := mesh.get_parent() as Node3D
	grip.scale = Vector3.ONE / scale.x
	mesh.basis = local_basis
	mesh.position = (record.palm as Vector3) * scale.x - local_basis * (record.contact as Vector3)
