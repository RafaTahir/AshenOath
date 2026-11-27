extends Node3D
## The empty return brings Kael back for Siv. The normal Stalker AI owns the
## pursuit and combat. Only this bank can give way under the pursuing creature.
const EDGE := Vector3(2.8, 0, -3.3)
const SHED := Vector3(-3.9, 0, -4.4)
const Tableau = preload("res://scripts/builders/novel/tabletop.gd")
var layer: Node
var enemy: Node3D
var retry_in := 0.0
var bank_gave_way := false

static func project(source: Node) -> void:
	if source.zone != "lantern_reach": return
	var state: Node = source.game.story_state
	var needed: bool = state.get_flag("final_covenant","") == "open_road" and state.get_flag("novel_departure_legs",0) == 2 and state.get_flag("open_road_load_carried",false) and not state.get_flag("novel_departure_second_rescue",false) and not state.get_flag("novel_bank_cleared",false)
	var encounter: Node3D = source.get_node_or_null("NovelBankEdge")
	if not needed:
		if is_instance_valid(encounter): encounter.set_physics_process(false)
		return
	if encounter == null:
		encounter = new()
		encounter.name = "NovelBankEdge"
		encounter.layer = source
		source.add_child(encounter)
		encounter.global_position = source.game.zone_root.to_global(EDGE)
		Tableau.dress(encounter,"strop")

func _current() -> bool:
	return is_instance_valid(layer) and is_instance_valid(layer.game.zone_root) and layer.game.zone_root.is_ancestor_of(self) and layer.game.current_zone_id == "lantern_reach" and not layer.game.zone_transition_pending and not layer.game._journey_load_pending()

func _physics_process(delta: float) -> void:
	if not _current(): return
	var game: Node = layer.game
	if not game.story_state.get_flag("novel_done_river_pan",false): return
	if not is_instance_valid(enemy):
		retry_in -= delta
		if retry_in > 0: return
		retry_in = 1.5
		# Reconstructed sector visuals can outlive a single StoryActivities director.
		for candidate: Node in game.active_enemies:
			if is_instance_valid(candidate) and not candidate.dead and candidate.is_in_group("novel_shed_stalker") and game.zone_root.is_ancestor_of(candidate):
				enemy = candidate
				break
		if not is_instance_valid(enemy):
			enemy = game._spawn_enemy("wychwood_stalker",game.zone_root.to_global(SHED))
			if not is_instance_valid(enemy): return
			enemy.add_to_group("novel_shed_stalker")
			game.audio.play_event("shrine_bell",0.07)
		if not enemy.died.is_connected(_cleared): enemy.died.connect(_cleared, CONNECT_ONE_SHOT)
	if enemy.dead or not is_instance_valid(game.player) or not game.player.can_control: return
	var local_enemy := to_local(enemy.global_position)
	var local_kael := to_local(game.player.global_position)
	if Vector2(local_enemy.x, local_enemy.z).length() > 1.65 or Vector2(local_kael.x, local_kael.z).length() > 1.8: return
	if absf(local_enemy.y-local_kael.y) > 1.6: return
	bank_gave_way = true
	enemy.health_component.damage(enemy.health_component.health)

func _cleared(fallen: Node) -> void:
	if fallen != enemy or not _current(): return
	var state: Node = layer.game.story_state
	if state.get_flag("novel_bank_cleared",false): return
	state.begin_change()
	state.set_flag("novel_bank_cleared",true)
	state.set_flag("novel_bank_resolution","slipped" if bank_gave_way else "fought")
	state.end_change()
	layer.owner_director.community.refresh()
	layer.game.story_save_pending = true
	layer.game.call_deferred("_persist_story_action")
	var account := "The lip gives under the Stalker. The family is clear." if bank_gave_way else "The Stalker goes down. Rook lowers his pole to Siv."
	layer.game.hud.set_guidance_hint(account+" Bring Siv’s father down to the ferry.",8)
	set_physics_process(false)
