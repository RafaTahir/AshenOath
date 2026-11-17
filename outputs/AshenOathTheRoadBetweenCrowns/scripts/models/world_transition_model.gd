class_name WorldTransitionModel
extends RefCounted
## One publication authority; background readiness cannot activate a journey.
enum State { BOOT, MENU, PREPARING_OPENING, ACTIVE_ZONE, PRELOADING_ADJACENT, COMMITTING_TRAVEL, TEARING_DOWN }
var state: State = State.BOOT
var transition_epoch: int = 0
var active_zone_id: String = ""
var target_zone_id: String = ""
var mounted_packs: Dictionary = {}
var cancelling: bool = false
var failure: String = ""
var _requested: bool = false
var _prepared_zones: Dictionary = {}

func enter_menu() -> bool:
	if state not in [State.BOOT, State.MENU, State.PREPARING_OPENING]:
		return false
	if state == State.PREPARING_OPENING: cancel(transition_epoch)
	state = State.MENU
	target_zone_id = ""
	_requested = false
	return true

func prepare_opening(zone_id: String = "greyfen") -> int:
	if state == State.BOOT: enter_menu()
	if state not in [State.BOOT, State.MENU, State.PREPARING_OPENING]:
		return -1
	transition_epoch += 1
	target_zone_id = zone_id
	state = State.PREPARING_OPENING
	cancelling = false
	failure = ""
	return transition_epoch

func prepare_adjacent(zone_id: String) -> int:
	if state not in [State.ACTIVE_ZONE, State.PRELOADING_ADJACENT] or zone_id.is_empty():
		return -1
	if state == State.PRELOADING_ADJACENT and target_zone_id == zone_id:
		return transition_epoch
	transition_epoch += 1
	target_zone_id = zone_id
	state = State.PRELOADING_ADJACENT
	cancelling = false
	failure = ""
	return transition_epoch

func request_travel(zone_id: String, interrupt: bool = false) -> int:
	if zone_id.is_empty() or state == State.TEARING_DOWN:
		return -1
	if state == State.COMMITTING_TRAVEL and not interrupt:
		return transition_epoch if target_zone_id == zone_id else -1
	transition_epoch += 1
	target_zone_id = zone_id
	state = State.COMMITTING_TRAVEL
	_requested = true
	cancelling = false
	failure = ""
	return transition_epoch

func accepts(epoch: int, zone_id: String = "") -> bool:
	return not cancelling and state != State.TEARING_DOWN and epoch == transition_epoch and (zone_id.is_empty() or target_zone_id == zone_id)

func pack_mounted(pack_id: String, epoch: int) -> bool:
	if not accepts(epoch) or pack_id.is_empty():
		return false
	mounted_packs[pack_id] = true
	return true

func mark_prepared(zone_id: String, epoch: int) -> bool:
	if not accepts(epoch, zone_id):
		return false
	_prepared_zones[zone_id] = epoch
	if state == State.PRELOADING_ADJACENT:
		state = State.ACTIVE_ZONE
		target_zone_id = ""
	return true

func commit(zone_id: String, epoch: int, supported: bool, ready: bool) -> bool:
	if not accepts(epoch, zone_id) or not _requested or state != State.COMMITTING_TRAVEL or not supported or not ready:
		return false
	active_zone_id = zone_id
	target_zone_id = ""
	state = State.ACTIVE_ZONE
	_requested = false
	return true

func fail(epoch: int, reason: String) -> bool:
	if epoch != transition_epoch or state == State.TEARING_DOWN:
		return false
	failure = reason
	return cancel(epoch)

func cancel(epoch: int) -> bool:
	if epoch != transition_epoch or state == State.TEARING_DOWN:
		return false
	cancelling = true
	transition_epoch += 1
	target_zone_id = ""
	_requested = false
	state = State.ACTIVE_ZONE if not active_zone_id.is_empty() else State.MENU
	cancelling = false
	return true

func teardown() -> int:
	transition_epoch += 1
	state = State.TEARING_DOWN
	target_zone_id = ""
	_requested = false
	cancelling = true
	return transition_epoch

func autosave_allowed() -> bool:
	return state == State.ACTIVE_ZONE and not cancelling and not _requested

func manual_save_allowed() -> bool:
	return state in [State.ACTIVE_ZONE, State.PRELOADING_ADJACENT] and not active_zone_id.is_empty() and not cancelling and not _requested

func can_request_travel() -> bool:
	return state in [State.MENU, State.PREPARING_OPENING, State.ACTIVE_ZONE, State.PRELOADING_ADJACENT]

func snapshot() -> Dictionary:
	return {"state": State.keys()[state], "epoch": transition_epoch, "active_zone_id": active_zone_id,
		"target_zone_id": target_zone_id, "mounted_packs": mounted_packs.duplicate(),
		"autosave_allowed": autosave_allowed(), "failure": failure}
