extends SceneTree

const Enemy = preload("res://scripts/enemy_ai.gd")
class Driver extends "res://scripts/character_animation_driver.gd":
	func is_valid() -> bool:
		return skeleton != null

func _initialize() -> void:
	var enemy := Enemy.new()
	root.add_child(enemy)
	enemy.set_physics_process(false)
	var driver := Driver.new()
	var skeleton := Skeleton3D.new()
	enemy.add_child(driver)
	enemy.add_child(skeleton)
	driver.skeleton = skeleton
	enemy.animation_driver = driver
	# Imported index order must not override the authored right-hand preference.
	skeleton.add_bone("hand_l")
	skeleton.add_bone("hand_r")
	enemy._configure_attack_contact_bone()
	var passed := enemy.attack_contact_bone == 1
	skeleton.clear_bones()
	skeleton.add_bone("LeftHand")
	skeleton.add_bone("RightHand")
	enemy._configure_attack_contact_bone()
	passed = passed and enemy.attack_contact_bone == 1
	skeleton.clear_bones()
	skeleton.add_bone("hand_l")
	enemy._configure_attack_contact_bone()
	passed = passed and enemy.attack_contact_bone == 0
	skeleton.clear_bones()
	skeleton.add_bone("Head")
	enemy._configure_attack_contact_bone()
	passed = passed and enemy.attack_contact_bone == 0 and enemy.attack_contact_local_offset == Vector3(0, 0, -0.58)
	skeleton.basis = Basis.from_euler(Vector3(0.6, 1.2, 0.4)).scaled(Vector3(26, 32, 27))
	skeleton.set_bone_rest(0, Transform3D(Basis.from_euler(Vector3(0.2, -0.9, 0.7)), Vector3.ZERO))
	enemy._configure_attack_contact_bone()
	var world_probe := skeleton.basis * skeleton.get_bone_global_rest(0).basis * enemy.attack_contact_local_offset
	passed = passed and world_probe.distance_to(Vector3(0, 0, -0.58)) < 0.0001
	enemy.free()
	print("ENEMY CONTACT BONE: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
