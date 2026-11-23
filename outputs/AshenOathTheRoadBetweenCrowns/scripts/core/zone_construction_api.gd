class_name ZoneConstructionApi
extends "res://scripts/systems/game_bindings.gd"
## Checked construction surface; only the root-bound facade implements these hooks.
var coordinator: Node3D
var context: ZoneBuildContext
func write_construction_tag(node: Node, key: StringName, value: Variant) -> void:
	assert(false, "Construction hook requires a bound facade: write_construction_tag")
func read_construction_tag(node: Node, key: StringName, fallback: Variant = null) -> Variant:
	assert(false, "Construction hook requires a bound facade: read_construction_tag")
	return null
func flush_environment_batch_step(phase: int) -> void:
	assert(false, "Construction hook requires a bound facade: flush_environment_batch_step")
func _publish_environment_0(install_routes: bool = true) -> void:
	assert(false, "Construction hook requires a bound facade: _publish_environment_0")
func _publish_environment_1() -> void:
	assert(false, "Construction hook requires a bound facade: _publish_environment_1")
func _publish_environment_2(only_key: String = "") -> void:
	assert(false, "Construction hook requires a bound facade: _publish_environment_2")
func _publish_environment_3(only_key: String = "") -> void:
	assert(false, "Construction hook requires a bound facade: _publish_environment_3")
func _publish_environment_4(only_key: String = "") -> void:
	assert(false, "Construction hook requires a bound facade: _publish_environment_4")
func _publish_environment_5() -> void:
	assert(false, "Construction hook requires a bound facade: _publish_environment_5")
func tree_publication_units(fallback: Callable) -> Array[Callable]:
	assert(false, "Construction hook requires a bound facade: tree_publication_units")
	return []
func _publish_environment_6(include_ecology: bool = true) -> void:
	assert(false, "Construction hook requires a bound facade: _publish_environment_6")
func _publish_connected_route(index: int) -> void:
	assert(false, "Construction hook requires a bound facade: _publish_connected_route")
func _build_design_pack_ecology(only_index: int = -1) -> void:
	assert(false, "Construction hook requires a bound facade: _build_design_pack_ecology")
func _make_interaction_label(area: Node3D, text: String, pos: Vector3, font_size: int, pixel_size: float, outlined: bool) -> void:
	assert(false, "Construction hook requires a bound facade: _make_interaction_label")
func _make_board_game_solidity(area: Node3D, size: Vector3) -> bool:
	assert(false, "Construction hook requires a bound facade: _make_board_game_solidity")
	return false
