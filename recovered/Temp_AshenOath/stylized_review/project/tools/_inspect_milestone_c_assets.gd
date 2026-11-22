extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")

const ROLES := [
	["player_human", "characters"],
	["sister_anwen_human", "characters"],
	["road_ranger_human", "characters"],
	["ghoulkin_creature", "enemies"],
	["ghoul_stalker_real", "enemies"],
	["ghoul_brute_real", "enemies"]
]

const SOURCES := [
	"res://assets_external/enemies/Skeleton.fbx",
	"res://assets_external/enemies/Bat.fbx",
	"res://assets_external/enemies/Dragon.fbx",
	"res://assets_external/enemies/Wolf.fbx",
	"res://assets_external/characters/KnightCharacter.fbx"
]

func _initialize() -> void:
	var helper := AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	for entry in ROLES:
		var role := str(entry[0])
		var category := str(entry[1])
		var visual := helper.spawn_visual_role(role, category)
		if visual == null:
			print("ROLE %s MISSING" % role)
			continue
		root.add_child(visual)
		await process_frame
		_print_role(role, visual)
		visual.free()
	for path in SOURCES:
		var resource := ResourceLoader.load(path)
		if not resource is PackedScene:
			print("SOURCE %s INVALID" % path)
			continue
		var source_node := (resource as PackedScene).instantiate()
		root.add_child(source_node)
		await process_frame
		_print_role(path.get_file(), source_node)
		source_node.free()
	quit()

func _print_role(role: String, root_node: Node) -> void:
	print("ROLE %s" % role)
	print("  children=%d root_transform=%s" % [root_node.get_child_count(), (root_node as Node3D).transform if root_node is Node3D else "n/a"])
	for skeleton in root_node.find_children("*", "Skeleton3D", true, false):
		var names: Array[String] = []
		for index in range((skeleton as Skeleton3D).get_bone_count()):
			names.append(str((skeleton as Skeleton3D).get_bone_name(index)))
		print("  SKELETON %s bones=%d" % [skeleton.name, names.size()])
		print("    %s" % ", ".join(names))
	for player in root_node.find_children("*", "AnimationPlayer", true, false):
		print("  ANIM %s: %s" % [player.name, (player as AnimationPlayer).get_animation_list()])
	for mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var material_names: Array[String] = []
		for index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.mesh.surface_get_material(index)
			material_names.append(str(material.resource_name) if material != null else "<null>")
		var world_box: AABB = mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		print("  MESH %s skinned=%s local_aabb=%s world_aabb=%s surfaces=%s" % [mesh_instance.name, mesh_instance.skin != null, mesh_instance.mesh.get_aabb(), world_box, material_names])
