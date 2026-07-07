extends Node3D

const FACE_ATLAS = preload("res://assets_external/textures/faces/dark_fantasy_face_atlas_1k.png")

var face_sprite: Sprite3D
var blink_timer := 2.0
var blink_phase := 0.0

static func attach(character_root: Node, role_id: String, monster: bool = false) -> Node:
	var skeleton := _find_skeleton(character_root)
	if skeleton == null:
		return null
	var old := skeleton.find_child("FacialIdentity", true, false)
	if old != null:
		return old
	var attachment := BoneAttachment3D.new()
	attachment.name = "FacialIdentity"
	var head_index := _head_bone_index(skeleton)
	if head_index < 0:
		return null
	skeleton.add_child(attachment)
	attachment.bone_idx = head_index
	attachment.bone_name = skeleton.get_bone_name(head_index)
	var identity: Node = load("res://scripts/facial_identity.gd").new()
	identity.name = "FacialIdentityDriver"
	attachment.add_child(identity)
	identity._build(role_id, monster)
	return attachment

static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

static func _head_bone_index(skeleton: Skeleton3D) -> int:
	var exact := skeleton.find_bone("Head")
	if exact >= 0:
		return exact
	for index in range(skeleton.get_bone_count()):
		var bone_name := str(skeleton.get_bone_name(index)).to_lower()
		if bone_name.contains("head"):
			return index
	return -1

func _build(role_id: String, monster: bool) -> void:
	face_sprite = Sprite3D.new()
	face_sprite.name = "BoneBoundFaceTexture"
	face_sprite.texture = FACE_ATLAS
	face_sprite.region_enabled = true
	var tile := _profile_tile(role_id, monster)
	face_sprite.region_rect = Rect2(tile.x * 256, tile.y * 256, 256, 256)
	face_sprite.pixel_size = 0.000045 if not monster else 0.000052
	face_sprite.position = Vector3(0.0, 0.015, -0.115 if not monster else -0.13)
	face_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	face_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	face_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	add_child(face_sprite)
	blink_timer = 1.8 + float(abs(role_id.hash()) % 260) / 100.0

func _process(delta: float) -> void:
	if face_sprite == null:
		return
	blink_timer -= delta
	if blink_timer <= 0.0 and blink_phase <= 0.0:
		blink_phase = 0.11
		blink_timer = 2.4 + randf() * 2.8
	if blink_phase > 0.0:
		blink_phase -= delta
		face_sprite.scale.y = 0.12 if blink_phase > 0.045 else 1.0
	else:
		face_sprite.scale.y = 1.0

func _profile_tile(role_id: String, monster: bool) -> Vector2i:
	var id := role_id.to_lower()
	if monster:
		if id.contains("brute"): return Vector2i(0,3)
		if id.contains("grave") or id.contains("skeleton"): return Vector2i(1,3)
		if id.contains("bog"): return Vector2i(2,3)
		if id.contains("stalker"): return Vector2i(3,3)
		return Vector2i(3,2)
	if id.contains("kael") or id.contains("player"): return Vector2i(0,0)
	if id.contains("anwen"): return Vector2i(1,0)
	if id.contains("edric") or id.contains("guard"): return Vector2i(2,1)
	if id.contains("mira") or id.contains("widow"): return Vector2i(2,0)
	if id.contains("rook") or id.contains("ranger"): return Vector2i(1,2)
	var human_tiles := [Vector2i(2,0),Vector2i(3,0),Vector2i(0,1),Vector2i(1,1),Vector2i(3,1),Vector2i(0,2),Vector2i(1,2)]
	return human_tiles[abs(role_id.hash()) % human_tiles.size()]
