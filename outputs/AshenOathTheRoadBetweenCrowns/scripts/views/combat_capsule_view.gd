extends RefCounted
## Collision belongs to the scene even when a dedicated server omits rendering.
const Roles = preload("res://scripts/character_role_spec.gd")

static func install_player(actor: CharacterBody3D) -> void:
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.height = Roles.collision_height("player_human", 1.65)
	shape.radius = Roles.collision_radius("player_human", 0.32)
	_attach(actor, shape, shape.height * 0.5)

static func install_enemy(actor: CharacterBody3D, identity: String, boss: bool) -> void:
	var spec: Dictionary = Roles.for_role(identity)
	var height: float = 3.30 if identity == "white_hart_avatar" else float(spec.get("collision_height", 1.15))
	var radius: float = 0.78 if identity == "white_hart_avatar" else float(spec.get("collision_radius", 0.35))
	if boss:
		height = float({"bell_eater": 3.60, "rootbound_colossus": 4.10, "ashwing": 2.45, "halvern_boss": 2.20}.get(identity, height))
		radius = float({"bell_eater": 0.82, "rootbound_colossus": 1.05, "ashwing": 0.66, "halvern_boss": 0.50}.get(identity, radius))
	var shape: Shape3D
	if height < radius * 2.0:
		var cylinder: CylinderShape3D = CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = height
		shape = cylinder
	else:
		var capsule: CapsuleShape3D = CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = height
		shape = capsule
	_attach(actor, shape, height * 0.5 + radius * 0.18)

static func _attach(actor: CharacterBody3D, shape: Shape3D, center_y: float) -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = center_y
	actor.add_child(collision)
