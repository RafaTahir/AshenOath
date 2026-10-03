extends RefCounted

const CAPACITY := 40
var screens: Dictionary = {}
var order: Array[String] = []

func capture(id: String, parent: String, root: Node) -> void:
	if id.is_empty() or not is_instance_valid(root):
		return
	var previous: Dictionary = screens.get(id, {})
	var state := {"parent": parent, "focus": str(previous.get("focus", "")), "index": int(previous.get("index", 0)), "scrolls": {}, "drafts": previous.get("drafts", {}).duplicate(true)}
	var controls: Array[Control] = []
	_collect(root, controls)
	var focused := root.get_viewport().gui_get_focus_owner()
	var focus_index := 0
	for index in range(controls.size()):
		var control := controls[index]
		var key := str(control.get_meta("navigation_key", ""))
		if control == focused:
			state["focus"] = key
			state["index"] = focus_index
		if key != "" and control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree() and not (control is BaseButton and control.disabled):
			focus_index += 1
		var draft := str(control.get_meta("navigation_draft", ""))
		if draft != "" and (control is LineEdit or control is TextEdit):
			state.drafts[draft] = str(control.get("text")).left(2097152)
		var scroll := str(control.get_meta("navigation_scroll", ""))
		if scroll != "":
			if control is ScrollContainer:
				state.scrolls[scroll] = control.scroll_vertical
			elif control is RichTextLabel:
				state.scrolls[scroll] = control.get_v_scroll_bar().value
	screens[id] = state
	_touch(id)

func set_parent(id: String, parent: String) -> void:
	var state: Dictionary = screens.get(id, {})
	state["parent"] = parent
	screens[id] = state
	_touch(id)

func parent_of(id: String, fallback: String = "pause") -> String:
	return str(screens.get(id, {}).get("parent", fallback))

func draft(id: String, key: String, fallback: String = "") -> String:
	return str(screens.get(id, {}).get("drafts", {}).get(key, fallback))

func clear_draft(id: String, key: String) -> void:
	if screens.has(id):
		screens[id].get("drafts", {}).erase(key)

func restore(id: String, root: Node) -> void:
	if not is_instance_valid(root):
		return
	var state: Dictionary = screens.get(id, {})
	var controls: Array[Control] = []
	_collect(root, controls)
	var candidates: Array[Control] = []
	var chosen: Control
	for control in controls:
		var scroll := str(control.get_meta("navigation_scroll", ""))
		if state.get("scrolls", {}).has(scroll):
			if control is ScrollContainer:
				control.scroll_vertical = int(state.scrolls[scroll])
			elif control is RichTextLabel:
				control.get_v_scroll_bar().value = float(state.scrolls[scroll])
		if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree() or (control is BaseButton and control.disabled):
			continue
		if str(control.get_meta("navigation_key", "")) == "":
			continue
		candidates.append(control)
		if str(control.get_meta("navigation_key", "")) == str(state.get("focus", "")):
			chosen = control
	if chosen == null and not candidates.is_empty():
		chosen = candidates[clampi(int(state.get("index", 0)), 0, candidates.size() - 1)]
	if chosen != null:
		chosen.grab_focus()

func _collect(node: Node, result: Array[Control]) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Control:
			result.append(child)
		_collect(child, result)

func _touch(id: String) -> void:
	order.erase(id)
	order.append(id)
	while order.size() > CAPACITY:
		screens.erase(order.pop_front())
