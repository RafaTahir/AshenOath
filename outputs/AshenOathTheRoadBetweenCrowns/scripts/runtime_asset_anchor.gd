extends Node

## Explicit export dependency for the neutral humanoid animation library. The
## runtime also loads it through the fusion service, but dynamic role manifests
## are not sufficient for Godot's Web resource scanner.
const NEUTRAL_HUMANOID_ANIMATION_LIBRARY: PackedScene = preload("res://assets_external/animations/AnimationLibrary_Godot_Standard.glb")
