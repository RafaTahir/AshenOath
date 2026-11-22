extends RefCounted

static var white_texture: ImageTexture

static func normalize(material: Material) -> Material:
	if not material is StandardMaterial3D:
		return material
	var standard := material as StandardMaterial3D
	if standard.albedo_texture == null:
		if white_texture == null:
			var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			image.fill(Color.WHITE)
			white_texture = ImageTexture.create_from_image(image)
		standard.albedo_texture = white_texture
	if not standard.emission_enabled and standard.emission_texture == null \
			and standard.emission.r == 0.0 and standard.emission.g == 0.0 and standard.emission.b == 0.0:
		standard.emission_enabled = true
	return material
