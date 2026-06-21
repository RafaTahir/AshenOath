extends Area3D

var prompt = "Interact"
var interaction_id = ""
var interaction_type = "dialogue"
var quest_id = ""
var objective_id = ""
var zone_target = ""
var ingredients = {}
var dialogue_id = ""

func setup(id: String, type: String, prompt_text: String) -> void:
	name = id
	interaction_id = id
	interaction_type = type
	prompt = prompt_text
	if dialogue_id == "":
		dialogue_id = id

func build_collision(radius: float = 1.4) -> void:
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)
