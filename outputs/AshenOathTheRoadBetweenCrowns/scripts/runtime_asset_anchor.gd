extends Node

## Runtime asset anchor retained for scene compatibility. The small opening
## character layers and the shared animation library are deliberately anchored
## in the root PCK so the first playable Greyfen frame cannot race a streamed
## character pack. Larger role variants remain streamed.

# These three small opening façade meshes are dependencies of Greyfen's first
# frame. Keeping them anchored in the root PCK prevents a streamed-pack race
# from creating a primitive placeholder while the opening pack warms in the
# background.
const OPENING_CRITICAL_ENVIRONMENT = [
	preload("res://assets_external/environment/village/Wall_Plaster_Door_Flat.obj"),
	preload("res://assets_external/environment/village/Wall_Plaster_Window_Wide_Flat.obj"),
	preload("res://assets_external/environment/village/Prop_Chimney.obj"),
]

# Kael, Anwen, and the first Greyfen crowd are part of the opening handoff.
# Keep their small Universal source layers in the root PCK so a cold browser
# never has to wait for a non-critical character download before it can render
# the menu or publish the first playable frame. Ranger and later variants stay
# in the streamed character pack.
const OPENING_CRITICAL_CHARACTERS = [
	preload("res://assets_external/characters_universal/Male_Peasant.gltf"),
	preload("res://assets_external/characters_universal/Female_Peasant.gltf"),
	preload("res://assets_external/characters_universal/Male_Head.gltf"),
	preload("res://assets_external/characters_universal/Female_Head.gltf"),
	preload("res://assets_external/characters_universal/Hair_Buns.gltf"),
	preload("res://assets_external/characters_universal/Hair_Buzzed.gltf"),
	preload("res://assets_external/characters_universal/Hair_SimpleParted.gltf"),
]

# The Universal bodies share this neutral, non-root-motion library. It is
# opening-critical because the first visible Kael/Anwen spawn must be fully
# animated without waiting for the optional character-variant download.
const OPENING_ANIMATION_LIBRARY = preload("res://assets_external/animations/AnimationLibrary_Godot_Opening.tres")
