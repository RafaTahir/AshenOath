extends RefCounted
## Godot finishes routing an emulated mouse release after the touch event.
## Rebuilding dialogue during that release detaches its active GUI target.
static func bind_pressed(button: Button, activate: Callable) -> void:
	var reference: WeakRef = weakref(button)
	button.pressed.connect(func() -> void:
		var target := reference.get_ref() as Button
		if is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree() and not target.is_queued_for_deletion() and not target.disabled:
			activate.call(), CONNECT_DEFERRED)
