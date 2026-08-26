extends SceneTree

const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")

var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene is unavailable")
	if packed == null:
		_finish()
		return
	game = packed.instantiate()
	root.add_child(game)
	await _frames(2)
	game.call("_new_game")
	await _frames(14)
	var player: Node = game.get("player")
	_check(player != null, "Kael was not created by New Game")
	if player != null:
		await _verify_player(player)
	await _verify_greyfen_characters()
	await _verify_vendors()
	print("CHAR-GAMEPLAY-QA-001 controllers detected: %d" % Input.get_connected_joypads().size())
	_finish()

func _verify_player(player: Node) -> void:
	var visual_root: Node3D = player.get("visual_root")
	_check(visual_root != null, "Kael has no visual root")
	if visual_root == null:
		return
	var body_root := _find_consolidated_body(visual_root)
	_check(body_root != null, "Kael has no consolidated imported body")
	if body_root == null:
		return
	_check(str(body_root.get_meta("character_asset_family", "")) == "quaternius_animated_humanoid", "Kael is outside the selected animated family")
	_check(bool(body_root.get_meta("character_composite", false)), "Kael body is not marked as one authored layer")
	_check(int(body_root.get_meta("character_rig_layer_count", 0)) == 1, "Kael body has multiple visual rig layers")
	_check(_count_type(body_root, "Skeleton3D") == 1, "Kael must expose one Skeleton3D")
	_check(_count_type(body_root, "AnimationPlayer") == 1, "Kael must expose one AnimationPlayer")
	var role_report: Dictionary = body_root.get_meta("character_role_contract", {})
	_check(bool(role_report.get("valid", false)), "Kael failed the normalized role contract: %s" % role_report)
	var skeleton := _find_skeleton(body_root)
	_check(skeleton != null, "Kael body has no skeleton instance")
	if skeleton == null:
		return
	var weapon_aliases: Array = CharacterRoleSpec.equipment_sockets("player_human").get("weapon", [])
	var hand_index := _find_bone(skeleton, weapon_aliases)
	_check(hand_index >= 0, "Kael has no right-hand weapon bone")
	var head_aliases: Array = CharacterRoleSpec.equipment_sockets("player_human").get("head", [])
	_check(_find_bone(skeleton, head_aliases) >= 0, "Kael has no native head bone")

	var loadout: Node = player.get("equipment_loadout")
	_check(loadout != null, "Kael has no EquipmentLoadout state owner")
	_check(player.has_method("save_equipment_state") and player.has_method("load_equipment_state"), "Kael equipment save API is missing")
	var sword_socket: Node = visual_root.find_child("KaelSwordSocket", true, false)
	_check(sword_socket != null, "Kael sword socket is missing")
	_check(sword_socket != null and _matches_bone(str(sword_socket.get("bone_name")), weapon_aliases), "Kael sword is not attached to the weapon hand bone")
	_check(visual_root.find_child("KaelBackSwordSocket", true, false) != null, "Kael has no back-sword socket")
	_check(visual_root.find_child("KaelBackScabbard", true, false) != null, "Kael has no back scabbard")
	_check(visual_root.find_child("KaelBowHandSocket", true, false) != null, "Kael has no bow hand socket")
	_check(visual_root.find_child("KaelQuiverBackSocket", true, false) != null, "Kael has no quiver back socket")
	_check(not _has_proxy_anatomy(visual_root), "Kael has proxy or detached anatomy")

	var driver: Node = player.get("animation_driver")
	_check(driver != null and driver.has_method("is_valid") and driver.is_valid(), "Kael animation driver is invalid")
	if driver != null and driver.has_method("trigger_action") and hand_index >= 0:
		var before := skeleton.get_bone_pose(hand_index)
		driver.trigger_action("attack_light")
		await _frames(8)
		var after := skeleton.get_bone_pose(hand_index)
		_check(before != after, "Kael light attack does not move the actual weapon hand")

	var saved: Dictionary = player.call("save_equipment_state")
	_check(saved.has("active_weapon") and saved.has("selected_arrow_id"), "equipment save payload is incomplete")
	player.call("load_equipment_state", {"active_weapon":"bow", "sword_drawn":false, "selected_arrow_id":"bodkin_arrow"})
	await _frames(2)
	_check(str(player.call("get_weapon_mode")) == "bow", "bow equipment state did not restore")
	_check(str(player.call("get_selected_arrow_id")) == "bodkin_arrow", "selected arrow state did not restore")
	var bow: Node = player.get("bow_visual")
	var quiver: Node = player.get("bow_quiver_visual")
	var back_scabbard: Node = player.get("sheathed_sword_visual")
	_check(bow != null and bow.visible, "bow is not visible in bow mode")
	_check(quiver != null and quiver.visible, "quiver is not visible in bow mode")
	_check(back_scabbard != null and back_scabbard.visible, "sheathed sword is not visible in bow mode")
	player.call("load_equipment_state", saved)
	await _frames(2)
	_check(str(player.call("get_weapon_mode")) == str(saved.get("active_weapon", "sword")), "equipment state did not round-trip back to its original mode")

func _verify_greyfen_characters() -> void:
	var zone_root: Node = game.get("zone_root")
	_check(zone_root != null, "Greyfen zone root is missing")
	if zone_root == null:
		return
	var anwen: Node = zone_root.find_child("sister_anwen", true, false)
	_check(anwen != null, "Sister Anwen is missing")
	if anwen != null:
		_verify_face_driver(anwen, "Sister Anwen")
	var life: Node = zone_root.find_child("GreyfenLifeController", true, false)
	_check(life != null, "Greyfen life controller is missing")
	if life == null:
		return
	var actors: Array = life.get("actors")
	_check(actors.size() >= 7, "Greyfen must contain four ambient and three named actors")
	for entry in actors:
		var actor: Node = entry.get("node")
		_verify_face_driver(actor, str(entry.get("id", "routine")))

func _verify_face_driver(actor: Node, label: String) -> void:
	_check(actor != null, "%s actor is missing" % label)
	if actor == null:
		return
	var driver: Node = actor.find_child("CharacterFaceDriver", true, false)
	_check(driver != null and driver.has_method("get_contract_report"), "%s has no native face driver" % label)
	if driver == null:
		return
	var report: Dictionary = driver.get_contract_report()
	_check(bool(report.get("valid", false)), "%s face contract is invalid: %s" % [label, report])
	_check(int(report.get("native_face_surface_count", 0)) > 0, "%s has no native face surfaces" % label)
	_check(not bool(report.get("synthetic_geometry_created", true)), "%s created synthetic face geometry" % label)

func _verify_vendors() -> void:
	var inventory: Node = game.get("inventory")
	var vendor: Node = game.get("vendor_service")
	_check(inventory != null and vendor != null, "Greyfen vendor services are missing")
	if inventory == null or vendor == null:
		return
	var tor_stock: Array = vendor.call("list_stock", "tor_forge", inventory, game.get("story_state"), game.get("quests"))
	var mira_stock: Array = vendor.call("list_stock", "mira_apothecary", inventory, game.get("story_state"), game.get("quests"))
	_check(_stock_has(tor_stock, "standard_arrow"), "Tor does not stock standard arrows")
	_check(_stock_has(tor_stock, "bodkin_arrow"), "Tor does not stock bodkin arrows")
	_check(_stock_has(mira_stock, "redroot_potion"), "Mira does not stock redroot potions")
	var original_coin := int(inventory.get("coin"))
	var inventory_items: Dictionary = inventory.get("items")
	var original_arrows := int(inventory_items.get("standard_arrow", 0))
	inventory_items["standard_arrow"] = 0
	inventory.set("coin", maxi(original_coin, 2))
	var purchase: Dictionary = vendor.call("buy", "tor_forge", "standard_arrow", 2, inventory, game.get("story_state"), game.get("quests"))
	_check(bool(purchase.get("ok", false)), "Tor arrow purchase did not complete")
	_check(int(inventory_items.get("standard_arrow", 0)) == 2, "Tor purchase did not add arrows")
	# Restore the temporary test mutation before the runtime is torn down.
	inventory_items["standard_arrow"] = original_arrows
	inventory.set("coin", original_coin)

func _stock_has(stock: Array, item_id: String) -> bool:
	for entry in stock:
		if str(entry.get("item_id", "")) == item_id:
			return true
	return false

func _find_consolidated_body(node: Node) -> Node3D:
	if bool(node.get_meta("character_composite", false)) and int(node.get_meta("character_rig_layer_count", 0)) == 1:
		return node as Node3D
	for child in node.get_children():
		if child is Node:
			var found := _find_consolidated_body(child)
			if found != null:
				return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_bone(skeleton: Skeleton3D, aliases: Array) -> int:
	for index in range(skeleton.get_bone_count()):
		if _matches_bone(str(skeleton.get_bone_name(index)), aliases):
			return index
	return -1

func _matches_bone(value: String, aliases: Array) -> bool:
	var normalized := value.to_lower().replace("_", "").replace(".", "").replace("-", "")
	for alias in aliases:
		var wanted := str(alias).to_lower().replace("_", "").replace(".", "").replace("-", "")
		if normalized == wanted or normalized.ends_with(wanted):
			return true
	return false

func _has_proxy_anatomy(node: Node) -> bool:
	for child in node.find_children("*", "", true, false):
		var lowered := str(child.name).to_lower().replace("_", "")
		for token in ["faceplane", "eyebox", "fakeneck", "proxy", "hunchedback", "motionarm", "motionleg"]:
			if lowered.contains(token):
				return true
	return false

func _count_type(node: Node, type_name: String) -> int:
	return node.find_children("*", type_name, true, false).size()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _finish() -> void:
	if is_instance_valid(game):
		if game.has_method("finalize_resource_shutdown"):
			game.finalize_resource_shutdown()
		game.queue_free()
		await _frames(12)
	if failures.is_empty():
		print("CHAR-GAMEPLAY-QA-001 VERIFIER: PASS - character, equipment, bow, vendors, and save round trips")
	else:
		print("CHAR-GAMEPLAY-QA-001 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	quit(0 if failures.is_empty() else 1)
