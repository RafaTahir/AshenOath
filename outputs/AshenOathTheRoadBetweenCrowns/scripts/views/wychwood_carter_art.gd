extends RefCounted

const ROOT := "res://assets_external/environment/forest/"

static func add_axle(area: Node3D) -> void:
	var axle := MeshInstance3D.new()
	axle.name = "CartersSoundingAxle"
	axle.mesh = load(ROOT + "Wychwood_CartersAxle.res") as ArrayMesh
	axle.rotation_degrees.y = 14.0
	area.add_child(axle)

## This is the measured bottom of the captive wrist cord in the retained
## Raider bind mesh (entirely weighted to hand_l). The inverse bind maps the
## small hanging tally and its orientation into the exact skinned hand frame.
static func attach_raider_tally(actor: Node3D) -> void:
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null: continue
		for surface in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(surface)
			if mat == null or mat.resource_name != "M19_CaughtTokenCord": continue
			var rig := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
			if rig == null or rig.has_node("CartersWristCord"): return
			var hand := rig.find_bone("hand_l")
			if hand < 0: break
			for bind in mesh.skin.get_bind_count():
				if mesh.skin.get_bind_name(bind) != &"hand_l" and mesh.skin.get_bind_bone(bind) != hand: continue
				var socket := BoneAttachment3D.new()
				socket.name = "CartersWristCord"
				rig.add_child(socket)
				socket.bone_idx = hand
				var tally := MeshInstance3D.new()
				tally.name = "NotchedRoadTally"
				tally.mesh = load(ROOT + "Wychwood_RaiderTally.res") as ArrayMesh
				tally.transform = mesh.skin.get_bind_pose(bind) * Transform3D(Basis.IDENTITY, Vector3(0.7784, 1.459215, -0.066852))
				socket.add_child(tally)
				return
	push_warning("Wychwood Raider is missing the hand-bound carter's tally attachment")
