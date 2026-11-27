extends Node3D

const Workpiece = preload("res://scripts/novel/tabletop.gd")
## Physical results of completed work remain after the corresponding Use target
## retires. Each arrangement is created once per resident sector.
const PLACES := {
	"greyfen":[["novel_bell_custody","returned","bell_home",[-4.6,7.5],"elna_bell","returned"]],
	"cemetery":[["novel_oren_buried",true,"family_graves",[-2.2,7.4],"grave_flowers",""]],
	"old_mill":[["novel_tor_braced",true,"measuring_bench",[-2.4,8.6],"work_bench",""]],
	"lantern_reach":[["novel_done_hearth_cover",true,"relief_place",[-4.0,5.1],"rest_chair",""],["novel_load_limits_known",true,"load_board",[2.3,1.8],"load_board",""]],
	"hearthward":[["novel_first_beds",true,"guest_bed",[-5.5,4.2],"guest_bed",""],["novel_alarm_heard",true,"wall_pan",[2.7,5.7],"wall_pan",""],["novel_season","spring","spring_chair",[2.8,6.8],"rest_chair",""]],
	"hart_glade":[["final_covenant","ash","burnt_bed",[-3.0,6.3],"burnt_bed",""]]
}

static func project(owner: Node, zone: String, state) -> void:
	if not PLACES.has(zone): return
	var layer: Node3D = owner.get_node_or_null("WorkAftermath")
	for row: Array in PLACES[zone]:
		var present: bool = state.get_flag(row[0],null) == row[1]
		if row[2]=="burnt_bed": present = present and bool(state.get_flag("final_choice_completed",false))
		if layer == null:
			if not present: continue
			layer = Node3D.new()
			layer.name = "WorkAftermath"
			owner.add_child(layer)
		var object := layer.get_node_or_null(str(row[2])) as Node3D
		if object == null and present:
			object = Node3D.new()
			object.name = str(row[2])
			layer.add_child(object)
			object.position = Vector3(row[3][0],0,row[3][1])
			_build(object,str(row[4]),str(row[5]))
		if object != null: object.visible = present

static func _build(root: Node3D, kind: String, variant: String) -> void:
	match kind:
		"elna_bell","oren_crow":
			var prop := Workpiece.keepsake(kind,variant)
			if prop != null:
				var instance := prop.instantiate() as Node3D
				var hook := Workpiece.box(root,Vector3(0,0.35,0),Vector3(0.12,0.70,0.11),Workpiece.WOOD)
				hook.rotation.z = -0.015
				instance.position = Vector3(0,0.68,0)
				root.add_child(instance)
		"grave_flowers":
			for i in 3:
				var stem := Workpiece.box(root,Vector3(i*0.39,0.12,0.04*(i%2)),Vector3(0.012,0.23,0.012),Color("#586141"))
				stem.rotation.z = 0.2*i
				Workpiece.box(stem,Vector3(0,0.12,0),Vector3(0.051,0.034,0.044),Color("#dcce9e"))
		"guest_bed":
			Workpiece.dress(root,"frame",0.12)
			Workpiece.box(root,Vector3(0,0.36,0),Vector3(0.64,0.16,1.25),Workpiece.LINEN)
			Workpiece.box(root,Vector3(0,0.47,-0.42),Vector3(0.46,0.11,0.30),Workpiece.PAPER)
		"rest_chair","work_bench":
			var width := 0.55 if kind=="rest_chair" else 1.00
			for x in [-1,1]:
				for z in [-1,1]: Workpiece.box(root,Vector3(x*width*0.42,0.24,z*0.21),Vector3(0.07,0.48,0.07),Workpiece.WOOD)
			Workpiece.box(root,Vector3(0,0.48,0),Vector3(width,0.09,0.54),Workpiece.WOOD)
			if kind=="rest_chair":
				Workpiece.box(root,Vector3(0,0.69,0.22),Vector3(width,0.40,0.07),Workpiece.WOOD)
			else: Workpiece.dress(root,"order",0.52)
		"wall_pan","load_board":
			Workpiece.dress(root,"post")
			if kind=="wall_pan":
				var pan := CylinderMesh.new()
				pan.height = 0.045
				pan.top_radius = 0.16
				pan.bottom_radius = 0.13
				Workpiece.part(root,pan,Vector3(0,0.53,0.11),Workpiece.IRON).rotation.x = PI/2
			else:
				Workpiece.box(root,Vector3(0,0.60,0.04),Vector3(0.54,0.30,0.06),Workpiece.WOOD)
				for i in 6:
					Workpiece.box(root,Vector3(-0.20+0.08*i,0.62,0.086),Vector3(0.023,0.12 if i<4 else 0.065,0.008),Workpiece.PAPER)
		"burnt_bed":
			Workpiece.box(root,Vector3(0,0.015,0),Vector3(1.6,0.03,0.85),Color("#39342e"))
			for i in 3:
				Workpiece.box(root,Vector3(-0.4+i*0.4,0.12,0.18*(i%2)),Vector3(0.033,0.23,0.033),Workpiece.PAINT).rotation.z = 0.13*i
