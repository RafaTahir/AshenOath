extends RefCounted

## Keeps only live-control references and numeric reading/editing positions.
## The caller owns the deferred-layout generation guard and fallback focus.

static func capture(root: Node) -> Dictionary:
	if not is_instance_valid(root) or root.is_queued_for_deletion():
		return {}
	var snapshot: Dictionary = {
		"root": weakref(root),
		"focus": null,
		"scrolls": [],
		"line_edits": [],
		"text_edits": []
	}
	var viewport: Viewport = root.get_viewport()
	if viewport != null:
		var focused: Control = viewport.gui_get_focus_owner()
		if _belongs_to(focused, root):
			snapshot["focus"] = weakref(focused)
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		for child: Node in node.get_children():
			pending.append(child)
		if node is ScrollContainer:
			var scroll: ScrollContainer = node as ScrollContainer
			snapshot.scrolls.append({
				"owner": weakref(scroll),
				"vertical": _capture_range(scroll.get_v_scroll_bar()),
				"horizontal": _capture_range(scroll.get_h_scroll_bar())
			})
		elif node is RichTextLabel:
			var reader: RichTextLabel = node as RichTextLabel
			snapshot.scrolls.append({"owner": weakref(reader), "vertical": _capture_range(reader.get_v_scroll_bar())})
		elif node is LineEdit:
			var line: LineEdit = node as LineEdit
			var selected: bool = line.has_selection()
			snapshot.line_edits.append({
				"owner": weakref(line),
				"caret": line.caret_column,
				"selected": selected,
				"from": line.get_selection_from_column() if selected else 0,
				"to": line.get_selection_to_column() if selected else 0
			})
		elif node is TextEdit:
			var editor: TextEdit = node as TextEdit
			var selected: bool = editor.has_selection(0)
			snapshot.text_edits.append({
				"owner": weakref(editor),
				"caret_line": editor.get_caret_line(0),
				"caret_column": editor.get_caret_column(0),
				"selected": selected,
				"from_line": editor.get_selection_from_line(0) if selected else 0,
				"from_column": editor.get_selection_from_column(0) if selected else 0,
				"to_line": editor.get_selection_to_line(0) if selected else 0,
				"to_column": editor.get_selection_to_column(0) if selected else 0
			})
	return snapshot

static func restore(snapshot: Dictionary, root: Node) -> bool:
	if not is_instance_valid(root) or root.is_queued_for_deletion():
		return false
	var root_ref: Variant = snapshot.get("root", null)
	if not root_ref is WeakRef or (root_ref as WeakRef).get_ref() != root:
		return false
	var focused: Control = _live_control(snapshot.get("focus", null), root)
	var focus_restored: bool = false
	if _can_focus(focused):
		focused.grab_focus()
		focus_restored = focused.has_focus()
	for raw: Variant in snapshot.get("line_edits", []):
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw
		var line: LineEdit = _live_control(row.get("owner", null), root) as LineEdit
		if line == null:
			continue
		var length: int = line.text.length()
		line.caret_column = clampi(int(row.get("caret", 0)), 0, length)
		if bool(row.get("selected", false)):
			var from: int = clampi(int(row.get("from", 0)), 0, length)
			var to: int = clampi(int(row.get("to", 0)), 0, length)
			if from != to:
				line.select(mini(from, to), maxi(from, to))
			else:
				line.deselect()
		else:
			line.deselect()
	for raw: Variant in snapshot.get("text_edits", []):
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw
		var editor: TextEdit = _live_control(row.get("owner", null), root) as TextEdit
		if editor == null:
			continue
		var caret: Vector2i = _edit_position(editor, int(row.get("caret_line", 0)), int(row.get("caret_column", 0)))
		editor.set_caret_line(caret.x, false, true, 0, 0)
		editor.set_caret_column(caret.y, false, 0)
		if bool(row.get("selected", false)):
			var from: Vector2i = _edit_position(editor, int(row.get("from_line", 0)), int(row.get("from_column", 0)))
			var to: Vector2i = _edit_position(editor, int(row.get("to_line", 0)), int(row.get("to_column", 0)))
			if from != to:
				editor.select(from.x, from.y, to.x, to.y, 0)
			else:
				editor.deselect(0)
		else:
			editor.deselect(0)
	# Restore scroll after focus/caret placement, which can ask containers to
	# reveal their focused child. Range updates remain ordinary UI scrolling.
	for raw: Variant in snapshot.get("scrolls", []):
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw
		var control: Control = _live_control(row.get("owner", null), root)
		if control is ScrollContainer:
			var scroll: ScrollContainer = control as ScrollContainer
			scroll.scroll_vertical = roundi(_restored_value(row.get("vertical", {}), scroll.get_v_scroll_bar()))
			scroll.scroll_horizontal = roundi(_restored_value(row.get("horizontal", {}), scroll.get_h_scroll_bar()))
		elif control is RichTextLabel:
			var reader: RichTextLabel = control as RichTextLabel
			var scrollbar: VScrollBar = reader.get_v_scroll_bar()
			if is_instance_valid(scrollbar):
				scrollbar.value = _restored_value(row.get("vertical", {}), scrollbar)
	return focus_restored

static func _capture_range(scrollbar: Range) -> Dictionary:
	if not is_instance_valid(scrollbar):
		return {}
	var minimum: float = scrollbar.min_value
	var extent: float = maxf(0.0, scrollbar.max_value - scrollbar.page - minimum)
	var value: float = clampf(scrollbar.value, minimum, minimum + extent)
	return {"value": value, "extent": extent, "ratio": (value - minimum) / extent if extent > 0.0 else 0.0}

static func _restored_value(raw: Variant, scrollbar: Range) -> float:
	if not is_instance_valid(scrollbar):
		return 0.0
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		return scrollbar.value
	var saved: Dictionary = raw
	var minimum: float = scrollbar.min_value
	var extent: float = maxf(0.0, scrollbar.max_value - scrollbar.page - minimum)
	var value: float = float(saved.get("value", minimum))
	if float(saved.get("extent", 0.0)) > 0.0:
		value = minimum + clampf(float(saved.get("ratio", 0.0)), 0.0, 1.0) * extent
	return clampf(value, minimum, minimum + extent)

static func _edit_position(editor: TextEdit, line: int, column: int) -> Vector2i:
	var bounded_line: int = clampi(line, 0, maxi(0, editor.get_line_count() - 1))
	var bounded_column: int = clampi(column, 0, editor.get_line(bounded_line).length())
	return Vector2i(bounded_line, bounded_column)

static func _live_control(raw: Variant, root: Node) -> Control:
	if not raw is WeakRef:
		return null
	var control: Control = (raw as WeakRef).get_ref() as Control
	if not _belongs_to(control, root) or not control.is_inside_tree() or not control.is_visible_in_tree():
		return null
	if control is BaseButton and (control as BaseButton).disabled:
		return null
	return control

static func _belongs_to(node: Node, root: Node) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion() and (node == root or root.is_ancestor_of(node))

static func _can_focus(control: Control) -> bool:
	if not is_instance_valid(control) or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is LineEdit and not (control as LineEdit).editable:
		return false
	if control is TextEdit and not (control as TextEdit).editable:
		return false
	return true
