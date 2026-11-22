extends SceneTree

class GeometryOnlyEnemy extends "res://scripts/enemy_ai.gd":
	var received := 0.0
	func _try_build_mapped_body() -> bool:
		return true
	func apply_damage(amount: float, _source_tag: String = "") -> void:
		received += amount

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var combat := preload("res://scripts/combat_manager.gd").new()
	root.add_child(combat)
	var records := []
	for role: String in ["silt_maw", "millback", "glassmoth", "knell_leech", "hearthscale", "gallows_weaver", "reed_choir", "inkblind", "cairn_mother", "shroud_swimmer"]:
		var actor := GeometryOnlyEnemy.new()
		actor.enemy_id = role
		actor.set_physics_process(false)
		root.add_child(actor)
		# Invoke the production collision builder; the override skips only asset loading.
		actor._build_body(Color.WHITE)
		var collision := actor.get_child(0) as CollisionShape3D
		var spec := preload("res://scripts/character_role_spec.gd").for_role(role)
		var body: Dictionary = combat._body_segment(actor)
		var record := {"role":role,"intended_height":spec.collision_height,"intended_radius":spec.collision_radius,"actual_height":collision.shape.height,"actual_radius":collision.shape.radius,"center_y":collision.position.y,"top_y":collision.position.y+collision.shape.height*.5,"combat_start":str(body.start),"combat_end":str(body.end)}
		if role == "shroud_swimmer":
			var result: Dictionary = combat.resolve_arrow_shot([actor],{"origin":Vector3(0,.9,-2),"endpoint":Vector3(0,.9,2),"direction":Vector3.BACK,"width":0.001,"damage":1.0,"report_miss":false})
			record["arrow_at_local_y_0_9_hit"] = result.hit
			record["damage_received"] = actor.received
		records.append(record)
		actor.free()
	print("WILDLIFE CAPSULE REVIEW ", JSON.stringify(records))
	combat.free()
	quit()