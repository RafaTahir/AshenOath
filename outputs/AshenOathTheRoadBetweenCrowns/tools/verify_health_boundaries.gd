extends SceneTree

var failures := 0
var deaths := 0

func _initialize() -> void:
	var health := preload("res://scripts/health_component.gd").new()
	root.add_child(health)
	health.died.connect(func(): deaths += 1)
	health.configure(100.0)
	for value in [-20.0, NAN, INF]:
		health.damage(value)
		check(health.health == 100.0, "Invalid damage must not change health")
	health.damage(30.0)
	for value in [-20.0, NAN, INF]:
		health.heal(value)
		check(health.health == 70.0, "Invalid healing must not change health")
	health.heal(200.0)
	check(health.health == 100.0, "Healing must cap at maximum")
	health.damage(200.0)
	health.damage(1.0)
	health.heal(100.0)
	check(health.dead and health.health == 0.0 and deaths == 1, "Death must emit once and prevent healing")
	for value in [null, "invalid", {}, true, NAN, INF, -1.0]:
		health.load_state({"max_health":value, "health":value, "dead":false})
		check(health.max_health > 0 and is_finite(health.health) and health.health >= 0 and health.health <= health.max_health, "Malformed save must preserve bounded health")
	health.load_state({"max_health":120.0, "health":200.0, "dead":false})
	check(health.health == 120.0, "Saved health must cap at maximum")
	health.load_state({"max_health":120.0, "health":0.0, "dead":false})
	check(health.dead, "Zero saved health must not restore a living actor")
	health.load_state({"max_health":120.0, "health":50.0, "dead":true})
	check(health.dead and health.health == 0.0, "Dead saved actor must have zero health")
	check(deaths == 1, "Restoring saves must not replay death events")
	health.free()
	var stamina := preload("res://scripts/stamina_component.gd").new()
	root.add_child(stamina)
	for amount in [-1.0, NAN, INF]:
		check(not stamina.spend(amount), "Invalid stamina cost must be rejected")
		stamina.restore(amount)
		check(stamina.stamina == 100.0, "Invalid stamina input must not change balance")
	check(stamina.spend(0.0) and stamina.cooldown == 0.0, "Free action must not delay regeneration")
	check(stamina.spend(30.0) and stamina.stamina == 70.0, "Valid stamina cost must be preserved")
	check(not stamina.spend(80.0) and stamina.stamina == 70.0, "Insufficient stamina must not mutate balance")
	for value in [null, "invalid", {}, true, NAN, INF, -1.0]:
		stamina.load_state({"max_stamina": value, "stamina": value})
		check(stamina.max_stamina > 0 and is_finite(stamina.stamina) and stamina.stamina >= 0 and stamina.stamina <= stamina.max_stamina, "Malformed stamina save must remain bounded")
	stamina.load_state({"max_stamina":120.0, "stamina":200.0})
	check(stamina.stamina == 120.0 and stamina.cooldown == 0.0, "Restore must clamp stamina and clear prior-session cooldown")
	stamina.free()
	print("HEALTH BOUNDARIES: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
