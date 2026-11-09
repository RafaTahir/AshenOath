extends SceneTree

const Geometry = preload("res://tools/living_world_geometry_contract.gd")
const Parts = preload("res://tools/living_world_part_baker.gd")
const PART_IDS := {"checkpoint":"checkpoint_cloth", "marsh_crossing":"marsh_reeds", "hart":"hart_ferns", "mill":"ash_mill_wheel"}
const MESH_IDS := ["deep_wood","burned_farmstead","marsh_crossing","bandit_road","farmstead_west","farmstead_east","checkpoint","hart","mill"]
const PIVOTS := {
	"checkpoint": [Vector3(-3.65,2.92,-5.75), Vector3(3.65,2.92,-5.75)],
	"marsh_crossing": [Vector3(-5,0,-9),Vector3(6,0,-6),Vector3(-7,0,1),Vector3(7,0,8),Vector3(-5,0,11)],
	"hart": [Vector3(-12.8,.027,-7),Vector3(-14.6,.027,3),Vector3(-12,.027,10),Vector3(13.6,.027,-8),Vector3(14.8,.027,4),Vector3(12.5,.027,12)],
	"mill": [Vector3(-4.42,1.55,1.8)],
}
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		push_error(label)

func _run() -> void:
	if "--verify-contract" in OS.get_cmdline_user_args():
		_self_test()
		return
	var art := ProjectSettings.globalize_path("res://").path_join("../../art_source/art_recovery_v2").simplify_path()
	var folder := art.path_join("evidence/living_assets_stage3_20261107/scenery/combined_original")
	var manifest_path := folder.path_join("manifest.json")
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or manifest.get("schema_version") != 1 or manifest.get("meshes",[]).size() != 9:
		_check(false, "Missing exact nine-mesh original scenery freeze")
		quit(1)
		return
	var reports: Array[Dictionary] = []
	var seen: Dictionary = {}
	for row: Dictionary in manifest.meshes:
		var identity := str(row.id)
		if identity not in MESH_IDS or seen.has(identity):
			_check(false,"Unknown or repeated frozen mesh identity: "+identity)
			continue
		seen[identity] = true
		var frozen := folder.path_join(str(row.frozen))
		if str(row.frozen) != str(row.frozen).get_file():
			_check(false,"Frozen mesh path escapes its archive: "+identity)
			continue
		if FileAccess.get_sha256(frozen) != str(row.sha256):
			_check(false, "Frozen original changed: " + identity)
			continue
		var original := ResourceLoader.load(frozen,"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		var rebuilt := ResourceLoader.load(str(row.runtime),"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if original == null or rebuilt == null:
			_check(false, "Missing original/rebuilt scenery mesh: " + identity)
			continue
		var world := Transform3D(Basis.IDENTITY, Vector3(-5.2,0,-5.25)) if identity == "mill" else Transform3D.IDENTITY
		var old_roles := {0:"ground",1:"foliage"} if identity == "hart" else {}
		var new_roles := {0:"ground"} if identity == "hart" else {}
		var before: Dictionary = Geometry.triangles(original,world,old_roles)
		var after: Dictionary = Geometry.triangles(rebuilt,world,new_roles)
		_check(before.error.is_empty() and after.error.is_empty(), identity + ": " + str(before.error) + str(after.error))
		if not before.error.is_empty() or not after.error.is_empty(): continue
		var part_count := 0
		var part_hash := ""
		if PART_IDS.has(identity):
			var path := "res://assets_external/environment_prepared/living_world/" + str(PART_IDS[identity]) + ".scn"
			part_hash = FileAccess.get_sha256(path)
			var packed := ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			if packed == null:
				_check(false, "Missing split scenery: " + identity)
				continue
			var node := packed.instantiate() as Node3D
			_check(node != null and node.transform.is_equal_approx(Transform3D.IDENTITY), identity + " assembly root retains identity")
			if node == null: continue
			_check(node.get_child_count()==PIVOTS[identity].size(), identity + " exact supported part count")
			var remaining: Array = PIVOTS[identity].duplicate()
			for child: Node in node.get_children():
				var mesh_node := child as MeshInstance3D
				if mesh_node == null:
					_check(false, identity + " has an unexpected non-mesh part")
					continue
				_check(mesh_node.basis.is_equal_approx(Basis.IDENTITY) and bool(mesh_node.get_meta("world_prop_verified_pivot",false)), identity + " part retains verified unit frame")
				var match_index := -1
				for index: int in range(remaining.size()):
					if mesh_node.position.distance_to(remaining[index])<0.00001: match_index=index; break
				_check(match_index>=0, identity + " part retains its exact original support position")
				if match_index>=0: remaining.remove_at(match_index)
				var moving: Dictionary = Geometry.triangles(mesh_node.mesh as ArrayMesh,world*mesh_node.transform)
				_check(moving.error.is_empty(), identity + " split attributes: " + str(moving.error))
				if moving.error.is_empty(): after.rows.append_array(moving.rows)
				part_count += 1
			node.free()
		var comparison: Dictionary = Geometry.compare(before.rows,after.rows)
		_check(bool(comparison.passed), identity + " union equivalence: " + str(comparison))
		var old_bounds: AABB = Geometry.bounds(before.rows)
		var new_bounds: AABB = Geometry.bounds(after.rows)
		_check(old_bounds.position.distance_to(new_bounds.position)<=Geometry.POSITION_EPS and old_bounds.end.distance_to(new_bounds.end)<=Geometry.POSITION_EPS, identity+" union world bounds remain unchanged")
		if identity=="hart": _check(rebuilt.get_surface_count()==1 and part_count==6 and after.rows.size()<=2500,"Hart retains one static surface, six parts and its triangle budget")
		if identity=="mill": _check(rebuilt.get_surface_count()==2,"Mill retains the two surrounding semantic surfaces")
		reports.append({"id":identity,"original_sha256":row.sha256,"rebuilt_sha256":FileAccess.get_sha256(str(row.runtime)),"parts_sha256":part_hash,"parts":part_count,"world_frame":var_to_str(world),"comparison":comparison})
	var report := {"passed":failures.is_empty() and reports.size()==9,"original_manifest_sha256":FileAccess.get_sha256(manifest_path),"source_commit":manifest.source_commit,"meshes":reports,"failures":failures,"world_or_visual_acceptance":false}
	var file := FileAccess.open(folder.path_join("../split_equivalence.json").simplify_path(),FileAccess.WRITE)
	if file==null: _check(false,"Cannot write split equivalence receipt")
	else: file.store_string(JSON.stringify(report,"\t")+"\n"); file.close()
	print("SCENERY_SPLIT_EQUIVALENCE: ","PASS" if failures.is_empty() else "FAIL"," meshes=",reports.size())
	quit(0 if failures.is_empty() and reports.size()==9 else 1)

func _self_test() -> void:
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(2,3,4),Vector3(3,3,4),Vector3(2,4,4)])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(2,-3),Vector2(3,-3),Vector2(2,-4)])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_name(0,"plaster")
	var original: Array = Geometry.triangles(mesh,Transform3D.IDENTITY).rows
	_check(Geometry.compare(original,original).passed,"unchanged triangles pass")
	var rebased := Parts.rebase_mesh(mesh,Vector3(2,4,4))
	_check(Geometry.compare(original,Geometry.triangles(rebased,Transform3D(Basis.IDENTITY,Vector3(2,4,4))).rows).passed,"rebase preserves world vertices, normals, colors, UVs and roles")
	var repeated := original.duplicate(true)
	repeated.append(original[0].duplicate(true))
	_check(not Geometry.compare(original,repeated).passed,"duplicate triangles fail")
	for channel: String in ["v","n","c","u","role","winding"]:
		var changed := original.duplicate(true)
		match channel:
			"v": changed[0].v[0] += Vector3(.01,0,0)
			"n": changed[0].n[0] = Vector3.UP
			"c": changed[0].c[0] = Color.BLACK
			"u": changed[0].u[0] += Vector2(.01,0)
			"role": changed[0].role = "foliage"
			"winding":
				for key: String in ["v","n","c","u"]: changed[0][key].reverse()
		_check(not Geometry.compare(original,changed).passed,channel+" drift fails")
	var near := original.duplicate(true)
	for index: int in range(3): near[0].v[index] += Vector3(-.00001,0,0)
	_check(Geometry.compare(original,near).passed,"cell-boundary floating-point tolerance preserves valid geometry")
	print("SCENERY_SPLIT_CONTRACT: ","PASS" if failures.is_empty() else "FAIL"," checks=10 authored_assets=none")
	quit(0 if failures.is_empty() else 1)
