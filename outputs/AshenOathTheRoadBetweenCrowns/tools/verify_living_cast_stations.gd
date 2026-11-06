extends SceneTree

const Stations = preload("res://scripts/living_cast_stations.gd")
const Social = preload("res://scripts/greyfen_social_presentation.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var care := Stations.add_care_table(world)
	_check(care != null, "care table exists")
	if care != null:
		_check(Stations.add_care_table(world) == care, "care table creation idempotent")
		_check_work(care.get_node("LifeWork_anwen"), care.get_node("RetainedTimberTable"), "anwen")
		var shape: BoxShape3D = care.get_node("TableSolid/TableCollision").shape
		_check(shape.size.is_equal_approx(Vector3(1.21,1.015,0.825)), "care collision fitted furniture dimensions")
	for id: String in ["mira_apothecary", "common_table"]:
		var area := Node3D.new()
		area.name = id
		world.add_child(area)
		Social.apply(area, id)
		Stations.decorate_place(area, id)
		var identity := "mira" if id == "mira_apothecary" else "rook"
		var station := area.get_node("LifeWork_" + identity)
		var furniture := area.get_node("GreyfenSocialFurniture") as MeshInstance3D
		var contact_surface := area.get_node("MiraRaisedDryingRack") as MeshInstance3D if identity == "mira" else furniture
		if identity == "rook":
			var satchel := area.get_node("RookStationSatchel") as Node3D
			var strap := satchel.get_node("SatchelStrap") as MeshInstance3D
			_check_work(station, strap, identity)
			_check(satchel.position.is_equal_approx(Vector3(-1.22,0.93,0)), "Rook satchel rests on the retained table")
			_check(satchel.get_node_or_null("SatchelKnot") is Node3D, "Rook satchel has a separate contact-driven knot")
			for side: String in ["WorkLeft", "WorkRight"]:
				var grip := satchel.to_local((station.get_node(side) as Node3D).global_position)
				_check(is_equal_approx(grip.x,-0.08) and is_equal_approx(grip.y,0.18) and is_equal_approx(absf(grip.z),0.10), "Rook " + side + " aligns with the authored strap grip")
		else:
			_check_work(station, contact_surface, identity)
		if identity == "mira":
			_check(is_equal_approx(contact_surface.position.y,float(furniture.mesh.get_meta("counter_height"))), "Mira rack feet rest on the authored counter")
			_check(is_equal_approx(contact_surface.scale.y*0.93,0.15), "Mira rack raises visible work plane by fifteen centimetres")
			_check(contact_surface.process_mode == Node.PROCESS_MODE_INHERIT and not contact_surface.is_processing(), "Mira rack has no animation loop")
		Stations.decorate_place(area, id)
		_check(area.get_node("LifeWork_" + identity) == station, identity + " markers idempotent")
		if identity == "mira":
			_check(area.get_node("MiraRaisedDryingRack") == contact_surface, "Mira rack idempotent")
		else:
			_check(area.find_children("RookStationSatchel", "Node3D", false, false).size() == 1, "Rook satchel idempotent")
	var bench := Node3D.new()
	world.add_child(bench)
	Stations.decorate_place(bench, "shrine_prayer")
	var rest: Marker3D = bench.get_node("LifeRest_anwen")
	_check(bool(rest.get_meta("rest_supported", false)), "rest explicitly supported")
	_check(str(rest.get_meta("rest_kind", "")) == "seated", "rest is seated")
	_check(is_equal_approx(rest.position.y,0.48+0.12/2.0), "rest matches real shrine bench top")
	var stand: Vector3 = rest.position + rest.get_meta("stand_offset")
	_check(is_zero_approx(stand.y), "rest stand remains on ground")
	_check(stand.z > 0.35+0.25, "rest stand clears shrine bench")
	_check(str(rest.get_meta("interaction_owner", "")) == "shrine_prayer", "rest identifies shared player interaction")
	world.free()
	for failure in failures: printerr(failure)
	print("LIVING CAST STATIONS: %s checks=%d" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _check_work(station: Node3D, visual: MeshInstance3D, identity: String) -> void:
	for marker: String in ["WorkContact", "WorkLeft", "WorkRight", "WorkStand"]:
		_check(station.get_node_or_null(marker) is Marker3D, identity + " has " + marker)
	var contact: Vector3 = station.get_node("WorkContact").global_position
	var local := visual.to_local(contact)
	var faces := visual.mesh.get_faces()
	var nearest := INF
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(local.x,10,local.z),Vector3.DOWN,faces[index],faces[index+1],faces[index+2])
		if hit is Vector3:
			nearest = minf(nearest, absf((hit as Vector3).y-local.y))
	_check(nearest <= 0.035, identity + " contact lies on actual furniture (error=" + str(nearest) + ")")
	var stand: Vector3 = station.get_node("WorkStand").global_position
	_check(is_zero_approx(stand.y), identity + " stand stays grounded")
	var horizontal := Vector2(contact.x-stand.x,contact.z-stand.z).length()
	_check(horizontal >= 0.30 and horizontal <= 0.50, identity + " contact fits retained short-arm rig reach")
	_check(not visual.mesh.get_aabb().has_point(visual.to_local(stand+Vector3.UP*0.4)), identity + " stand outside furniture bounds")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
