extends RefCounted
var _life: Node
func _init(life: Node) -> void:
	_life = life
func _on_activity_contact(event: String, point: Vector3, source: WeakRef) -> void:
	var actor: Variant = source.get_ref() as Node3D
	if not is_instance_valid(_life.host) or not is_instance_valid(actor) or not bool(_life.host.game_started) or _life.get_tree().paused or _life.Presence.protected(actor):
		return
	if event == "satchel_cinch":
		if not _life._begin_satchel_cinch(actor):
			return
		event = "cloth_wind"
	elif event.begins_with("life_work:"):
		var identity: Variant = event.trim_prefix("life_work:")
		if not _life._begin_station_contact(actor, identity): return
		event = "record_page" if identity in ["vale", "merrow", "edric"] else "cloth_wind"
	if event=="forge_hammer" and is_instance_valid(_life.player) and actor.global_position.distance_squared_to(_life.player.global_position)<=121.0:
		for entry: Dictionary in _life.actors:
			if entry.node!=actor or not bool(entry.get("activity_active",false)) or str(entry.profile.get("activity",""))!="forge": continue
			var driver: Node = entry.get("driver")
			if not is_instance_valid(driver) or not is_instance_valid(driver.life_modifier): continue
			if str(driver.life_modifier.activity)!="forge": continue
			var contact: Dictionary = driver.life_modifier.last_contact_samples.get("right",{})
			var contact_error: Variant = float(contact.get("error",INF))
			if str(contact.get("kind",""))!="hammer" or not is_finite(contact_error) or contact_error>0.06 or not point.is_finite(): continue
			var effects: Node = _life.host.get("world_vfx")
			if is_instance_valid(effects) and _life.supports(effects, "emit_work_contact"):
				effects.emit_work_contact(point,_life.player.global_position,"forge")
			break
	if is_instance_valid(_life.host.audio) and is_instance_valid(_life.player):
		_life.host.audio.play_spatial_event(event, point, _life.player.global_position, 11.0, 0.25, 0.025)

func _begin_satchel_cinch(actor: Node3D) -> bool:
	for entry: Dictionary in _life.actors:
		if entry.node != actor or not bool(entry.get("activity_active", false)) or not is_instance_valid(entry.driver): continue
		var station: Dictionary = entry.profile.get("workstation", {})
		var reference: WeakRef = station.get("node_ref")
		var station_node: Variant = reference.get_ref() as Node3D if reference != null else null
		if station_node == null or str(_life.read_tag(station_node, "work_identity", "")) != "rook": return false
		var prop_ref: WeakRef = _life.read_tag(station_node, "task_prop") if station_node.has_meta("task_prop") else null
		var bag: Variant = prop_ref.get_ref() as Node3D if prop_ref != null else null
		var knot: Variant = bag.find_child("SatchelKnot", true, false) as Node3D if bag != null else null
		if knot == null: return false
		_life._clear_work_contact_effects(actor)
		_life.work_contact_effects.append({"actor":weakref(actor), "driver":weakref(entry.driver), "node":weakref(knot), "scale":knot.scale, "remaining":0.35})
		knot.scale *= Vector3(0.92, 1.0, 0.92)
		return true
	return false

func _begin_station_contact(actor: Node3D, identity: String) -> bool:
	for entry: Dictionary in _life.actors:
		if entry.node != actor or not bool(entry.get("activity_active", false)): continue
		var station: Dictionary = entry.profile.get("workstation", {})
		var reference: WeakRef = station.get("node_ref")
		var station_node: Variant = reference.get_ref() as Node3D if reference != null else null
		if station_node == null or str(_life.read_tag(station_node, "work_identity", "")) != identity: return false
		var prop_ref: WeakRef = _life.read_tag(station_node, "task_prop") if station_node.has_meta("task_prop") else null
		var prop: Variant = prop_ref.get_ref() as Node3D if prop_ref != null else null
		var part: Variant = prop.find_child("WorkContactPart", true, false) as Node3D if prop != null else null
		if part == null: return false
		_life._clear_work_contact_effects(actor)
		var effect: Variant = {"actor":weakref(actor),"driver":weakref(entry.driver),"node":weakref(part),"scale":part.scale,"transform":part.transform,"remaining":0.35,"response":str(_life.read_tag(part, "contact_response", "compress")),"amount":clampf(float(_life.read_tag(part, "contact_amount", 0.04)),0.0,0.08)}
		if str(effect.response) == "morph":
			var binding: Variant = _life._station_contact_morph(part)
			if binding.is_empty(): return false
			effect["morph"] = binding
			(part as MeshInstance3D).set_blend_shape_value(int(binding.index),float(binding.target))
		_life.work_contact_effects.append(effect)
		return true
	return false

func _station_contact_morph(part: Node3D) -> Dictionary:
	var mesh: Variant = part as MeshInstance3D
	if mesh == null or mesh.mesh == null: return {}
	var resource_id: Variant = mesh.mesh.get_instance_id()
	var cached: Dictionary = _life.read_tag(part, "living_contact_morph",{})
	if int(cached.get("mesh_id",0)) == resource_id: return cached if bool(cached.get("valid",false)) else {}
	var shape: Variant = str(_life.read_tag(part, "contact_shape",""))
	var index: Variant = mesh.find_blend_shape_by_name(shape)
	var neutral: Variant = _life.read_tag(part, "contact_neutral_weight",0.0)
	var target: Variant = _life.read_tag(part, "contact_target_weight",1.0)
	var valid: Variant = index >= 0 and typeof(neutral) in [TYPE_FLOAT,TYPE_INT] and typeof(target) in [TYPE_FLOAT,TYPE_INT]
	valid = valid and is_finite(float(neutral)) and is_finite(float(target)) and float(neutral)>=0.0 and float(target)>float(neutral) and float(target)<=1.0
	if valid: valid = is_equal_approx(mesh.get_blend_shape_value(index),float(neutral))
	if not valid:
		_life.write_tag(part, "living_contact_morph",{"mesh_id":resource_id,"valid":false})
		push_error("Living task contact cannot bind its declared shape/neutral: " + str(part.get_path()))
		return {}
	var binding: Variant = {"mesh_id":resource_id,"valid":true,"index":index,"shape":shape,"neutral":mesh.get_blend_shape_value(index),"target":float(target)}
	_life.write_tag(part, "living_contact_morph",binding)
	return binding

func _set_work_contact_morph(node: Node3D, effect: Dictionary, tension: float) -> bool:
	var mesh: Variant = node as MeshInstance3D
	var binding: Dictionary = effect.get("morph",{})
	if mesh == null or mesh.mesh == null or int(binding.get("mesh_id",0)) != mesh.mesh.get_instance_id(): return false
	mesh.set_blend_shape_value(int(binding.index),lerpf(float(binding.neutral),float(binding.target),clampf(tension,0.0,1.0)))
	return true

func _restore_work_contact_effect(effect: Dictionary, node: Node3D) -> void:
	if effect.has("morph"): _life._set_work_contact_morph(node,effect,0.0)
	elif effect.has("transform"): node.transform = effect.transform
	else: node.scale = effect.scale

func _tick_work_contact_effects(delta: float) -> void:
	for index in range(_life.work_contact_effects.size() - 1, -1, -1):
		var effect: Dictionary = _life.work_contact_effects[index]
		var knot: Variant = effect.node.get_ref() as Node3D
		if not is_instance_valid(knot):
			_life.work_contact_effects.remove_at(index)
			continue
		var actor: Node3D = effect.actor.get_ref()
		var driver_ref: WeakRef = effect.get("driver")
		var driver: Node = driver_ref.get_ref() if driver_ref != null else null
		if not is_instance_valid(actor) or _life.Presence.protected(actor) or is_instance_valid(driver) and (bool(driver.get("dead")) or bool(driver.get("distance_suspended"))):
			_life._restore_work_contact_effect(effect,knot)
			_life.work_contact_effects.remove_at(index)
			continue
		effect.remaining = maxf(0.0, float(effect.remaining) - delta)
		var tension: Variant = float(effect.remaining) / 0.35
		if effect.has("morph"):
			if not _life._set_work_contact_morph(knot,effect,tension): effect.remaining = 0.0
		elif effect.has("transform"):
			knot.transform = effect.transform
			var amount: Variant = float(effect.amount) * tension
			if str(effect.response) == "tilt":
				knot.rotate_object_local(Vector3.RIGHT, amount)
			else:
				knot.scale = (effect.scale as Vector3) * Vector3(1.0+amount*0.5,1.0-amount,1.0+amount*0.5)
		else:
			knot.scale = (effect.scale as Vector3) * Vector3(1.0 - tension * 0.08, 1.0, 1.0 - tension * 0.08)
		if float(effect.remaining) <= 0.0:
			_life.work_contact_effects.remove_at(index)

func _clear_work_contact_effects(actor: Node3D) -> void:
	for index in range(_life.work_contact_effects.size() - 1, -1, -1):
		var effect: Dictionary = _life.work_contact_effects[index]
		if effect.actor.get_ref() != actor:
			continue
		var knot: Variant = effect.node.get_ref() as Node3D
		if is_instance_valid(knot):
			_life._restore_work_contact_effect(effect,knot)
		_life.work_contact_effects.remove_at(index)
