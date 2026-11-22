extends RefCounted

## Saved summaries use isolated value owners. Their signals have no listeners;
## they never enter the scene tree or replace the active game's state.
const QuestView = preload("res://scripts/quest_manager.gd")
const StoryView = preload("res://scripts/story_state.gd")
const Journal = preload("res://scripts/story_journal.gd")
const Routes = preload("res://scripts/story_route_catalog.gd")

static func describe(data: Dictionary, recorded: Dictionary, quest_defs: Dictionary, item_defs: Dictionary) -> Dictionary:
	var quests = QuestView.new()
	quests.quest_defs = quest_defs.duplicate(true)
	quests.load_state(data.get("quests", {}))
	var story = StoryView.new()
	story.load_state(data.get("story_state", {}))
	var zone_id: String = str(data.get("world_sector", data.get("zone", "")))
	var recap: Dictionary = Journal.recap_model(quests, story, zone_id)
	var company: String = preload("res://scripts/epilogue_resolver.gd").journey_company(story)
	quests.free()
	story.free()
	var known_story: bool = bool(recorded.get("story_known", false)) or bool(recorded.get("quests_known", false))
	var saved_at: String = str(recorded.get("saved_at_utc", ""))
	var known_time: bool = bool(recorded.get("saved_at_known", false))
	var place: String = str(Routes.zone_name(zone_id)) if bool(recorded.get("place_known", false)) else "Place not recorded"
	var resources: Array[String] = _resources(recorded, item_defs)
	if bool(recorded.get("story_known", false)):
		resources.append(company)
	return {
		"title": str(data.get("slot_name", "Saved journey")),
		"place": place,
		"chapter": str(recap.get("heading", "The road ahead")) if known_story else "Chapter not recorded",
		"promise": str(recap.get("promise", "")) if known_story else "This save did not record a current promise.",
		"last_commitment": str(recap.get("last_commitment", "")) if known_story else "The order of earlier commitments is unknown.",
		"next_action": str(recap.get("next_action", "")) if known_story else "Open On Return after loading to see the surviving account.",
		"saved_at": saved_at if known_time else "",
		"saved_at_known": known_time,
		"resource_lines": resources,
		"time_label": "Saved %s UTC" % saved_at.replace("T", " ").trim_suffix("Z") if known_time else "Save time not recorded",
		"world_clock_label": _world_clock(recorded.get("day_night", {})),
		"replay": bool(data.get("replay_session", false)),
		"journey_id": str(data.get("journey_id", ""))
	}

static func _resources(recorded: Dictionary, item_defs: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var health: Dictionary = recorded.get("player_health", {})
	var stamina: Dictionary = recorded.get("player_stamina", {})
	if _number(health.get("health")) and _number(health.get("max_health")):
		result.append("Recorded health: %d / %d" % [int(health.health), int(health.max_health)])
	else:
		result.append("Health not recorded")
	if _number(stamina.get("stamina")) and _number(stamina.get("max_stamina")):
		result.append("Recorded stamina: %d / %d" % [int(stamina.stamina), int(stamina.max_stamina)])
	var inventory: Dictionary = recorded.get("inventory", {})
	var items: Dictionary = inventory.get("items", {}) if typeof(inventory.get("items")) == TYPE_DICTIONARY else {}
	var supplies: Array[String] = []
	if _number(inventory.get("coin")):
		supplies.append("%d coin" % int(inventory.coin))
	if _number(items.get("redroot_potion")):
		supplies.append("%d Redroot Potions" % int(items.redroot_potion))
	if not supplies.is_empty():
		result.append("Supplies: " + ", ".join(supplies))
	else:
		result.append("Supplies not recorded")
	var equipment: Dictionary = recorded.get("equipment", {})
	var selected: String = str(equipment.get("selected_arrow_id", ""))
	if selected != "" and _number(items.get(selected)):
		result.append("Selected arrows: %s x%d" % [str(item_defs.get(selected, {}).get("name", selected.replace("_", " ").capitalize())), int(items[selected])])
	if inventory.has("active_oil"):
		var oil: String = str(inventory.active_oil)
		result.append("Blade coating: " + (str(item_defs.get(oil, {}).get("name", oil.replace("_", " ").capitalize())) if oil != "" else "None selected"))
	return result

static func _world_clock(raw: Variant) -> String:
	if typeof(raw) != TYPE_DICTIONARY or not _number(raw.get("world_time_minutes")):
		return "World time not recorded"
	var minutes: int = int(float(raw.world_time_minutes))
	if minutes < 0 or minutes >= 1440:
		return "World time not recorded"
	var clock_text: String = "%02d:%02d" % [minutes / 60, minutes % 60]
	if _number(raw.get("day_count")) and int(raw.day_count) >= 0:
		return "World time: day %d, %s" % [int(raw.day_count) + 1, clock_text]
	return "World time: " + clock_text

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0.0
