extends Node3D

const OWNER := "GreyfenGathering"
const VOICES := {"rook":"Rook", "blacksmith_tor":"Tor", "sister_anwen":"Anwen", "mira":"Mira", "bracken":"Bracken"}
var game
var decorations: Node3D
var refresh_clock := 0.0

static func install(host) -> void:
	if host.zone_root.get_node_or_null(OWNER) != null:
		return
	var gathering = load("res://scripts/greyfen_gathering.gd").new()
	gathering.name = OWNER
	gathering.game = host
	host.zone_root.add_child(gathering)

static func eligible(host) -> bool:
	return host.current_zone_id == "greyfen" and str(host.story_state.get_flag("evidence_report", "")) != "" and host.pending_ending == "" and not host._story_has_active_combat() and not host.zone_transition_pending

static func active(host) -> bool:
	if not eligible(host):
		return false
	var raw: Variant = host.story_state.get_flag("lr_gathering_window", {})
	if not raw is Dictionary or raw.is_empty():
		return false
	var now: float = int(host.day_night.day_count) * 1440.0 + host.day_night.get_time()
	return now >= float(raw.get("start", -1)) and now < float(raw.get("end", -1)) and str(raw.get("names", "")) == str(host.story_state.get_flag("names_policy", "")) and bool(raw.get("final", false)) == bool(host.story_state.get_flag("final_choice_completed", false))

static func choose(host, action: Dictionary) -> void:
	host._resume_game()
	if not eligible(host) or host.player.global_position.distance_to(Vector3(-5.4, 0, 10.5)) > 3.0:
		return
	var choice := str(action.get("gathering_choice", ""))
	host.story_state.begin_change()
	if choice == "attend":
		var now: float = int(host.day_night.day_count) * 1440.0 + host.day_night.get_time()
		host.story_state.set_flag("lr_gathering_invitation", "attended")
		host.story_state.set_flag("lr_gathering_window", {"start":now, "end":now + 120.0, "names":host.story_state.get_flag("names_policy", ""), "final":host.story_state.get_flag("final_choice_completed", false)})
		host.hud.toast("The common table is laid. Rook has Three Marks; Tor has Greyfen Draughts. The southern range is open. There is no obligation to stay.", 7.0)
	elif choice in ["decline", "leave"]:
		if active(host):
			host.story_state.set_flag("lr_gathering_completed", true)
		if choice == "decline" and host.story_state.get_flag("lr_gathering_invitation", null) == null:
			host.story_state.set_flag("lr_gathering_invitation", "declined")
		host.story_state.set_flag("lr_gathering_window", {})
		host.hud.toast("No one stops you. A place at the table is an offer, not another debt.")
	host.story_state.end_change()
	host.story_save_pending = true
	host.call_deferred("_persist_story_action")

static func open_invitation(host) -> void:
	if not eligible(host):
		host.hud.toast("The common table will welcome company after the first road report, when Greyfen is safe.")
		return
	var actions: Array = [{"type":"gathering_choice", "gathering_choice":"attend", "label":"Join the table"}, {"type":"gathering_choice", "gathering_choice":"decline", "label":"Another time"}]
	if active(host):
		actions = [{"type":"gathering_choice", "gathering_choice":"leave", "label":"Say goodnight"}, {"type":"close", "label":"Stay a while"}]
	host.get_tree().paused = true
	host.audio.set_game_paused(true)
	host.hud.show_dialogue({"name":"Room at the common table", "pages":[{"speaker":"Greyfen", "speaker_id":"narrator", "text":"The boards have been wiped and the last cups set out. Nothing is settled by an evening together. That is not a reason to refuse one. Three Marks, Greyfen Draughts and the archery range are open as usual; work and the road can still call you away."}], "actions":actions})

static func conversation(host, actor_id: String) -> Dictionary:
	var words := ""
	match actor_id:
		"rook": words = "Three marks. Not three promises. I thought we could both do with knowing the rules before we started."
		"blacksmith_tor": words = "I closed the forge for a cup, not the shop. If you need arrows, say so. If you want to lose a board game, sit down."
		"sister_anwen": words = "Someone laughed just now. I had forgotten how far the sound travels when no one is afraid of it."
		"mira": words = "There are still people waiting for medicine. I can give you a little time, though. A little is not nothing."
		"bracken": words = "Bracken noses beneath the table, finds no emergency, and settles where he can see you."
	if actor_id == "sister_anwen":
		words += " " + ("The names were spoken aloud. Tonight we can speak of the people, too." if str(host.story_state.get_flag("evidence_report", "")) == "public" else "What you brought me stays where you chose to put it. No one owes this table a confession.")
	if actor_id == "mira" and host.story_state.commitment_partner() == "mira":
		words += " Save the place beside you. I will come back when I can."
	if actor_id == "rook" and str(host.story_state.get_flag("lr_friend_rook_stool", "")) == "completed":
		words += " Your stool is still level. My excuses are suffering."
	return {"name":str(VOICES.get(actor_id, "Greyfen")), "pages":[{"speaker":str(VOICES.get(actor_id, "Greyfen")), "speaker_id":"narrator" if actor_id == "bracken" else actor_id, "text":words}], "actions":[{"type":"close", "label":"Share the moment"}]}

func _process(delta: float) -> void:
	refresh_clock -= delta
	if refresh_clock > 0.0 or not is_instance_valid(game.zone_root) or get_parent() != game.zone_root:
		return
	refresh_clock = 1.0
	var present := active(game)
	if present and not is_instance_valid(decorations):
		var table := game.zone_root.find_child("common_table", true, false) as Node3D
		var board := table.get_node_or_null("common_table_CarvedBoard") as MeshInstance3D if table != null else null
		if board != null and board.mesh is BoxMesh:
			decorations = Node3D.new()
			decorations.name = "GatheringLinen"
			table.add_child(decorations)
			var runner := MeshInstance3D.new()
			var cloth := BoxMesh.new()
			cloth.size = Vector3((board.mesh as BoxMesh).size.x + 0.2, 0.008, 0.17)
			runner.mesh = cloth
			runner.position = board.position + Vector3(0, -0.04, (board.mesh as BoxMesh).size.z * 0.5 + 0.09)
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.59, 0.65, 0.61)
			runner.material_override = material
			decorations.add_child(runner)
	if is_instance_valid(decorations):
		decorations.visible = present
	var window: Variant = game.story_state.get_flag("lr_gathering_window", {})
	if not present and window is Dictionary and not window.is_empty():
		game.story_state.begin_change()
		game.story_state.set_flag("lr_gathering_window", {})
		game.story_state.set_flag("lr_gathering_completed", true)
		game.story_state.end_change()
		game.story_save_pending = true
		game.call_deferred("_persist_story_action")

func _exit_tree() -> void:
	if is_instance_valid(decorations):
		decorations.queue_free()
