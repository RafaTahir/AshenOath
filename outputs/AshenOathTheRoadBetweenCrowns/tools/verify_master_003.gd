extends SceneTree

const CharacterVisualContract = preload("res://scripts/character_visual_contract.gd")
var failures := 0

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null,"Main scene is missing")
	if packed == null: quit(1); return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(4)
	_verify_sky(game)
	_verify_characters(game)
	_verify_dialogue(game)
	_verify_interactions(game)
	_verify_oathfire(game)
	game.call("_load_zone","wychwood",Vector3(0,1,8))
	await _frames(4)
	_verify_enemies(game)
	print("MASTER-003 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_sky(game) -> void:
	var sky = game.visual_director
	sky.set_time(720.0,"day",0)
	check(sky.sun_disc.visible and not sky.moon_disc.visible,"Midday sun/moon visibility overlaps")
	sky.set_time(0.0,"night",0)
	check(sky.moon_disc.visible and not sky.sun_disc.visible,"Midnight sun/moon visibility overlaps")
	var cards := 0
	var spheres := 0
	for node in _walk(sky.cloud_layer):
		if node is MeshInstance3D:
			if (node as MeshInstance3D).mesh is QuadMesh: cards += 1
			if (node as MeshInstance3D).mesh is SphereMesh: spheres += 1
	check(cards >= 3 and spheres == 0,"Balanced clouds are not a soft three-lobe card formation")

func _verify_characters(game) -> void:
	var player_visual = game.player.find_child("player_kael_visual",true,false)
	check(player_visual != null,"Kael full-body visual is missing")
	if player_visual != null:
		var report := CharacterVisualContract.validate(player_visual,true)
		check(bool(report.valid),"Kael fails the full-body skeletal contract: %s" % str(report))
	var anwen = game.zone_root.find_child("sister_anwen",true,false)
	check(anwen != null,"Sister Anwen is missing")
	if anwen != null:
		var report := CharacterVisualContract.validate(anwen,true)
		check(bool(report.valid),"Sister Anwen fails the full-body skeletal contract: %s" % str(report))
		check(not _has_name_fragment(anwen,"FacePlane"),"Sister Anwen still uses a detached face plane")

func _verify_dialogue(game) -> void:
	var data: Dictionary = game.dialogue.get_dialogue("sister_anwen")
	game.hud.show_dialogue(data)
	check(game.hud.dialogue_pages.size() >= 2,"Dialogue is not paginated line by line")
	check(game.hud.dialogue_actions.get_child_count() == 1,"Dialogue page has unstable controls")
	game.hud.dialogue_page_index = game.hud.dialogue_pages.size()-1
	game.hud.call("_render_dialogue_page")
	check(game.hud.dialogue_actions.get_child_count() >= 1,"Dialogue choices are missing at conversation end")
	game.hud.dialogue_layer.visible = false

func _verify_interactions(game) -> void:
	check(game.has_method("_update_interaction_focus"),"Central interaction focus resolver is missing")
	var anwen = game.zone_root.find_child("sister_anwen",true,false)
	game.call("_stage_dialogue_moment",anwen)
	if anwen != null:
		var to_player: Vector3 = game.player.global_position-anwen.global_position
		to_player.y = 0.0
		# The imported cleric source is calibrated +Z -> the gameplay-facing -Z
		# contract at the actor root. Test the visible forward, not the raw source
		# basis, so dialogue acceptance matches the runtime role calibration.
		var npc_forward: Vector3 = -anwen.global_basis.z
		npc_forward.y = 0.0
		check(npc_forward.normalized().dot(to_player.normalized()) > 0.65,"Sister Anwen turns away during dialogue")

func _verify_oathfire(game) -> void:
	check(game.player.has_signal("beam_phase_changed"),"Oathfire phase signal is missing")
	var direction: Vector3 = game.player.call("_lock_beam_direction") as Vector3
	game.player.rotation.y += 1.0
	check(direction.dot(game.player.get_beam_locked_direction()) > 0.999,"Oathfire direction changes after lock")
	game.call("_make_oathfire_beam",Vector3(0,1,0),Vector3(0,1,-6),0.7,true)
	var effect = game.zone_root.find_child("OathfireBeamEffect",true,false)
	check(effect != null and _contains_mesh_type(effect,"CylinderMesh"),"Oathfire beam is not tapered cylindrical geometry")

func _verify_enemies(game) -> void:
	check(game.active_enemies.size() == 5,"Wychwood pack is incomplete")
	var profiles: Dictionary = {}
	for enemy in game.active_enemies:
		profiles[enemy.get_behavior_state().profile] = true
		var visual = enemy.find_child("*_visual",true,false)
		check(visual != null,"Enemy full-body visual is missing")
	check(profiles.size() >= 4,"Monster approach profiles are not varied")

func _contains_mesh_type(root_node: Node, type_name: String) -> bool:
	for node in _walk(root_node):
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as MeshInstance3D).mesh.get_class() == type_name:
			return true
	return false

func _has_name_fragment(root_node: Node, fragment: String) -> bool:
	for node in _walk(root_node):
		if str(node.name).contains(fragment): return true
	return false

func _walk(parent: Node) -> Array:
	var nodes: Array = [parent]
	for child in parent.get_children(): nodes.append_array(_walk(child))
	return nodes

func _frames(count: int) -> void:
	for _i in range(count): await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
