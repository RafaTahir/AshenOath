extends Resource

const PATH := "res://data/prepared_greyfen_social_collision.res"

@export var shapes: Dictionary[String, ConcavePolygonShape3D] = {}
@export var source_mesh_sha256: Dictionary[String, String] = {}

static func fitted(id: String, mesh: Mesh) -> ConcavePolygonShape3D:
	if ResourceLoader.exists(PATH):
		var catalog := load(PATH)
		var stored: Variant = catalog.get("shapes") if catalog != null else null
		if stored is Dictionary:
			var shape := stored.get(id) as ConcavePolygonShape3D
			if shape != null:
				return shape
	return preload("res://scripts/immutable_collision_shapes.gd").camera_mesh(mesh)
