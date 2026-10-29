extends Node

## Runtime asset anchor retained for scene compatibility. Character bodies
## are owned by the opening/prepared-actor dependency records, not menu preloads.

# These small opening facade meshes are dependencies of Greyfen's first
# frame. Keeping them anchored in the root PCK prevents a streamed-pack race
# from creating a primitive placeholder while the opening pack warms in the
# background.
const OPENING_CRITICAL_ENVIRONMENT = [
	preload("res://assets_external/environment/village/Wall_Plaster_Door_Flat.obj"),
	preload("res://assets_external/environment/village/Wall_Plaster_Window_Wide_Flat.obj"),
	preload("res://assets_external/environment/village/Wall_Plaster_Straight_Base.obj"),
	preload("res://assets_external/environment/village/Prop_Chimney.obj"),
]

# The Universal bodies share this neutral, non-root-motion library. It is
# opening-critical because the first visible Kael/Anwen spawn must be fully
# animated without waiting for the optional character-variant download.
const OPENING_ANIMATION_LIBRARY = preload("res://assets_external/animations/AnimationLibrary_Godot_Opening.tres")
