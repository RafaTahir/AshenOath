extends SceneTree

const GreyfenSection = preload("res://scripts/zones/greyfen_section.gd")
const Frontier = preload("res://scripts/greyfen_frontier.gd")
var failures: Array[String] = []
const Roads = preload("res://scripts/connected_route_geometry.gd")

class HostFixture extends Node:
	var zone_root := Node3D.new()
	var scene_rng := RandomNumberGenerator.new()

func _initialize() -> void:
	if "--connector-profile-only" in OS.get_cmdline_user_args():
		call_deferred("_connector_profiles")
		return
	var host := HostFixture.new()
	root.add_child(host)
	host.add_child(host.zone_root)
	var section := GreyfenSection.new()
	section._build_horizon_ridges(ZoneBuildContext.new(host, "greyfen"))
	_check(host.zone_root.find_child("GreyfenHorizonRidges", true, false) == null, "Obsolete perimeter wall ownership remains")
	var frontier := host.zone_root.find_child("GreyfenAuthoredFrontier", true, false)
	_check(frontier != null, "Authored adjoining landscape is missing")
	if frontier != null:
		_check(frontier.find_children("*", "CollisionObject3D", true, false).is_empty(), "Adjoining art changes physical traversal")
		var ground := frontier.find_child("VillageAdjoiningLandscape", true, false) as MeshInstance3D
		_check(ground != null and ground.mesh != null and ground.mesh.get_surface_count() == 2, "Adjoining landscape requires both ground and track")
		if ground != null and ground.mesh != null:
			for surface in ground.mesh.get_surface_count():
				var material := ground.get_active_material(surface) as StandardMaterial3D
				_check(material != null and material.albedo_texture != null, "Adjoining landscape has no authored surface texture")
				var arrays := ground.mesh.surface_get_arrays(surface)
				for normal in arrays[Mesh.ARRAY_NORMAL]:
					_check(normal.y > 0.5, "Adjoining ground has a downward or wall-facing normal")
			for point in ground.mesh.get_faces():
				_check(point.is_finite() and (absf(point.z) >= 16.99 or absf(point.x) >= 20.99), "Adjoining landscape enters the physical village core")
			_check(ground.mesh.get_aabb().size.z > 130.0, "Adjoining ground does not close distant depth")
			_check(ground.mesh.get_faces().size() / 3 <= 3500, "Complete adjoining landscape exceeds its geometry budget")
			for x in [-21.0, -12.0, -5.0, 0.0, 5.0, 12.0, 21.0]:
				for z in [-17.0, 17.0]:
					_check(absf(Frontier.height_at(x, z)) < 0.001, "Adjoining surface does not meet the physical village floor")
			for z in [-17.0, -10.0, 0.0, 10.0, 17.0]:
				for x in [-21.0, 21.0]:
					_check(absf(Frontier.height_at(x, z)) < 0.001, "Village side surface leaves an exposed boundary gap")
	for count in [24, 40]:
		var positions := Frontier.tree_positions(count)
		_check(positions.size() == count, "Quality tier loses its forest population")
		for position in positions:
			_check(position.is_finite() and absf(position.y - Frontier.height_at(position.x, position.z)) < 0.001, "Adjoining tree is not grounded on its owner")
			_check(absf(position.z) > 18.7 or absf(position.x) > 21.4, "Adjoining tree obstructs a playable route")
	host.free()
	print("GREYFEN HORIZON GEOMETRY: %s (not visual acceptance)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _connector_profiles() -> void:
	# Direct geometry/physics on every affected shared consumer, not a campaign.
	var count := 0
	var segments := 0
	for zone: String in WorldSectorManifest.all_ids():
		if zone in ["vargan_approach","vargan_court","record_hall","undercroft"]: continue
		for edge: Dictionary in WorldSectorManifest.connections(zone):
			var points := WorldSectorManifest.connector_points(edge)
			var polygon := WorldSectorManifest.connector_polygon(edge)
			var left := PackedVector3Array()
			var right := PackedVector3Array()
			for index in points.size():
				left.append(Vector3(polygon[index].x,0,polygon[index].y))
				var reverse := polygon[polygon.size()-1-index]
				right.append(Vector3(reverse.x,0,reverse.y))
			var fixture := Node3D.new()
			root.add_child(fixture)
			var material := StandardMaterial3D.new()
			Roads._strip(fixture,"Ground",left,right,material,true)
			for side: PackedVector3Array in [left,right]:
				var crest := PackedVector3Array()
				var outer := PackedVector3Array()
				for index in side.size():
					var outward := (side[index]-points[index]).normalized()
					crest.append(side[index]+outward*2.2+Vector3.UP*Roads.soil_crest_height(index))
					outer.append(side[index]+outward*5.5)
				var bank := Roads._build_contoured_strip(side,crest,"bank")
				var back := Roads._build_contoured_strip(crest,outer,"backslope")
				var faces := bank.get_faces()
				var back_faces := back.get_faces()
				_check(faces.size()/3 <= 256 and back_faces.size()/3 <= 256,"Soil geometry exceeds bounded budget: "+zone)
				for mesh: ArrayMesh in [bank,back]:
					for point: Vector3 in mesh.get_faces():
						_check(point.is_finite() and point.y >= -0.001,"Invalid soil vertex: "+zone)
						_check(point.y < 2.7,"Soil shoulder still forms an oversized wall: "+zone)
					var vertices := mesh.get_faces()
					for across in Roads.SOIL_CROSS_SECTIONS:
						var start: int = across*6
						var end: int = ((points.size()-1)*Roads.SOIL_SECTIONS-1)*Roads.SOIL_CROSS_SECTIONS*6+across*6
						_check(absf(vertices[start].y)<0.001 and absf(vertices[start+2].y)<0.001,"Exposed entry soil cut: "+zone)
						_check(absf(vertices[end+1].y)<0.001 and absf(vertices[end+4].y)<0.001,"Exposed return soil cut: "+zone)
				for segment in range(points.size()-1):
					for station in Roads.SOIL_SECTIONS:
						var base: int = (segment*Roads.SOIL_SECTIONS+station)*Roads.SOIL_CROSS_SECTIONS*6
						var top: int = base+(Roads.SOIL_CROSS_SECTIONS-1)*6
						_check(faces[top+2].is_equal_approx(back_faces[base]) and faces[top+1].is_equal_approx(back_faces[base+4]),"Split soil crest: "+zone+"/"+str(edge.target))
				Roads._strip(fixture,"Bank",side,crest,material,true,"bank")
				Roads._strip(fixture,"BackSlope",crest,outer,material,false,"backslope")
			for visual: MeshInstance3D in fixture.find_children("*","MeshInstance3D",true,false):
				var body := visual.get_child(0) as StaticBody3D if visual.get_child_count()>0 else null
				_check(body != null,"Required connector collision missing: "+zone)
				if body == null: continue
				if str(visual.get_meta("connector_surface","")) == "BackSlope":
					_check(body.collision_layer == 64 and body.collision_mask == 0 and not bool(body.get_meta("walkable_support",true)),"Outer scenery changes player support: "+zone)
				var collision := body.get_child(0) as CollisionShape3D
				_check(collision.shape.get_faces() == visual.mesh.get_faces(),"Invisible/mismatched connector collider: "+zone)
			await physics_frame
			await physics_frame
			await process_frame
			var space := fixture.get_world_3d().direct_space_state
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.32
			capsule.height = 1.65
			for index in range(points.size()-1):
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.collision_mask = 1
				query.transform.origin = points[index]+Vector3.UP*0.905
				query.motion = points[index+1]-points[index]
				var fractions := space.cast_motion(query)
				_check(fractions.size()==2 and fractions[0] >= 0.999,"Soil obstructs unchanged road: "+zone+"/"+str(edge.target)+"/"+str(index))
				var midpoint := points[index].lerp(points[index+1],0.5)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(midpoint+Vector3.UP*0.4,midpoint-Vector3.UP*0.4,1))
				_check(not hit.is_empty() and absf((hit.position as Vector3).y) < 0.001 and bool(hit.collider.get_meta("walkable_support",false)),"Lost connector ground: "+zone)
				segments += 1
			fixture.free()
			count += 1
	print("CONNECTOR PROFILE: %s; directional_consumers=%d capsule_segments=%d; geometry/physics only, not route/performance acceptance" % ["PASS" if failures.is_empty() else "FAIL",count,segments])
	quit(0 if failures.is_empty() else 1)
