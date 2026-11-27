extends SceneTree
## Run headless with --path pointing to the Godot project after importing the GLBs.

const CATALOG := "res://assets/narrative_props/library.json"
var failures: Array[String] = []
var counts := {}


func _initialize() -> void:
	call_deferred("_verify")


func require(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _verify() -> void:
	var library: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not library is Dictionary:
		push_error("Cannot read the narrative prop library")
		quit(1)
		return
	for id: String in ["oren_crow", "elna_bell", "tor_brace", "merrow_strongbox"]:
		require(library.has(id), "Missing library entry: " + id)
		if not library.has(id): continue
		var entry: Dictionary = library[id]
		var forms: Dictionary = entry.get("variants", {}).duplicate()
		forms["default"] = entry["default"]
		for form: String in forms:
			var scene := load(forms[form]) as PackedScene
			require(scene != null, "Cannot load " + str(forms[form]))
			if scene == null: continue
			var prop := scene.instantiate() as Node3D
			require(prop != null, "Prop scene root must be Node3D")
			if prop == null: continue
			root.add_child(prop)
			var meshes := prop.find_children("*", "MeshInstance3D", true, false)
			var surfaces := 0
			var all_bounds := AABB()
			for instance: MeshInstance3D in meshes:
				require(instance.mesh != null, id + " missing mesh on " + str(instance.name))
				if instance.mesh == null: continue
				var bounds := instance.global_transform * instance.get_aabb()
				all_bounds = bounds if surfaces == 0 else all_bounds.merge(bounds)
				for surface in instance.mesh.get_surface_count():
					surfaces += 1
					require(instance.get_active_material(surface) != null, id + " missing surface material")
			require(surfaces > 0 and all_bounds.is_finite() and all_bounds.size.length() > 0.02,
					"No finite physical geometry on " + str(forms[form]))
			require(all_bounds.size.length() < 1.3, "Check metre units on " + str(forms[form]))
			counts[id + "/" + form] = {"surfaces":surfaces, "extent_m":str(all_bounds.size)}
			_check_form(id, form, prop)
			prop.free()
	print("NARRATIVE PROPS: ", JSON.stringify({"forms":counts, "failures":failures}))
	quit(1 if not failures.is_empty() else 0)


func _check_form(id: String, form: String, prop: Node3D) -> void:
	match id:
		"elna_bell":
			for marker in ["Grip", "FiledMarks", "StrikerEye"]:
				require(prop.get_node_or_null(marker) is Marker3D, "Bell missing " + marker)
			require(prop.has_node("StrikerPivot/TemporaryStriker") == (form == "cemetery"), "Incorrect striker configuration")
			require(prop.has_node("WaxedWool") == (form == "cemetery"), "Incorrect grip wrapping")
			require(prop.has_node("WaxAtHandle") == (form == "returned"), "Incorrect return state")
			if form == "cemetery":
				var pivot: Node3D = prop.get_node("StrikerPivot")
				require(pivot.position.distance_to(prop.get_node("StrikerEye").position) < 0.0001, "Striker hinge is off its eye")
		"oren_crow":
			for marker in ["Grip", "InspectFocus"]:
				require(prop.get_node_or_null(marker) is Marker3D, "Crow missing " + marker)
			if form != "wrapped":
				require(prop.get_node_or_null("CordAnchor") is Marker3D, "Exposed crow has no cord attachment")
		"tor_brace":
			require(prop.get_node_or_null("WristCrease") is Marker3D, "Brace is missing its fitting reference")
			require(prop.get_node_or_null("SplintsAndLinen") is MeshInstance3D, "Brace is missing the left wrist splints")
		"merrow_strongbox":
			for marker in ["ClerkLock/KeySocket","HouseholdLock/KeySocket","FloorFixingLeft","FloorFixingRight","LidHinge/PryCorner","WrappedVolume/Grip"]:
				require(prop.get_node_or_null(marker) is Marker3D, "Strongbox missing " + marker)
			var hinge := prop.get_node_or_null("LidHinge") as Node3D
			if hinge != null and prop.has_node("ClerkLock/KeySocket") and prop.has_node("LidHinge/PryCorner"):
				var lock: Node3D = prop.get_node("ClerkLock/KeySocket")
				var original_lock := lock.global_transform
				var front_rim := Vector3(0, 0, -0.30)
				var closed_rim := hinge.to_global(front_rim)
				hinge.rotate_x(0.75)
				require(hinge.to_global(front_rim).y > closed_rim.y + 0.15, "Front rim does not rise around its hinge")
				require(lock.global_transform.is_equal_approx(original_lock), "Opening the lid displaced a front lock")
