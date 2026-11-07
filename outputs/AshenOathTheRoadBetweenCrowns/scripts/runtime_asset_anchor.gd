extends Node

## Runtime asset anchor retained for scene compatibility. Character bodies
## are owned by the opening/prepared-actor dependency records, not menu preloads.

# The Universal bodies share this neutral, non-root-motion library. It is
# opening-critical because the first visible Kael/Anwen spawn must be fully
# animated without waiting for the optional character-variant download.
const OPENING_ANIMATION_LIBRARY = preload("res://assets_external/animations/AnimationLibrary_Godot_Opening.tres")
