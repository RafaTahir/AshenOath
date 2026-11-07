extends SceneTree

const Props = preload("res://scripts/world_prop_controller.gd")
const Everyday = preload("res://scripts/everyday_life.gd")
const VFX = preload("res://scripts/world_vfx_controller.gd")

class FlagState:
	extends Node
	var flags: Dictionary = {}
	func get_flag(key: String, fallback: Variant = null) -> Variant: return flags.get(key, fallback)

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var props := Props.new()
	scene.add_child(props)
	props.set_process(false)
	var wheel := Node3D.new()
	scene.add_child(wheel)
	wheel.rotation = Vector3(0.3, 0.2, PI / 2.0)
	wheel.scale = Vector3.ONE * 1.4
	var base := wheel.basis
	props._register(wheel, "mill", "mill_wheel", "")
	var entry: Dictionary = props.entries.back()
	for _step in 20: props._update_entry(entry, 0.1)
	check(is_equal_approx(float(entry.spin_angle), 0.9), "mill wheel accumulates twenty steps")
	check(wheel.basis.is_equal_approx(base * Basis(Vector3.UP, 0.9)), "wheel turns around authored local axle")
	check(wheel.basis.get_scale().is_equal_approx(base.get_scale()), "wheel retains authored scale")
	entry.state = "stopped"
	props._update_entry(entry, 1.0)
	check(is_equal_approx(float(entry.spin_angle), 0.9), "stopped wheel holds orientation")
	entry.state = "idle"
	props._update_entry(entry, -1.0)
	check(is_equal_approx(float(entry.spin_angle), 0.9), "negative elapsed time cannot reverse wheel")
	wheel.set_meta("world_prop_spin_axis", Vector3.ZERO)
	props._update_entry(entry, 1.0)
	check(wheel.basis.is_equal_approx(base * Basis(Vector3.UP, 0.9)), "invalid axle cannot corrupt transform")
	var cart := Node3D.new()
	scene.add_child(cart)
	props._register(cart, "parked_cart", "cart_wheel", "")
	var cart_entry: Dictionary = props.entries.back()
	props._update_entry(cart_entry, 10.0)
	check(cart.basis.is_equal_approx(Basis.IDENTITY) and not props._needs_motion(cart_entry), "parked cart wheel remains static outside ticker")
	var housing := Node3D.new()
	scene.add_child(housing)
	props._register(housing, "lantern", "lantern", "")
	var housing_entry: Dictionary = props.entries.back()
	housing_entry.state = "extinguished"
	props._apply_entry_state(housing_entry)
	props._update_entry(housing_entry, 10.0)
	check(housing.visible and housing.transform.is_equal_approx(Transform3D.IDENTITY), "extinguished lantern housing stays fixed and visible")
	check(not props._needs_motion(housing_entry), "housing does not consume ambient motion budget")
	var flame := Node3D.new()
	flame.set_meta("world_prop_moving_part", true)
	scene.add_child(flame)
	props._register(flame, "lantern", "lantern", "")
	var flame_entry: Dictionary = props.entries.back()
	check(flame_entry.kind == "flame", "verified lantern moving part maps to flame")
	flame_entry.state = "extinguished"
	props._apply_entry_state(flame_entry)
	check(not flame.visible, "extinguished flame is hidden")
	flame_entry.state = "lit"
	props._apply_entry_state(flame_entry)
	check(flame.visible, "relit flame returns")
	var viewer := Node3D.new()
	scene.add_child(viewer)
	props.player = viewer
	viewer.position = Vector3(1000, 0, 0)
	flame.visible = false
	props._rebuild_active_entries()
	check(props.active_entries.is_empty(), "far viewer does not reactivate a fallback set")
	viewer.position = Vector3.ZERO
	for index in 40:
		var leaf := Node3D.new()
		scene.add_child(leaf)
		props._register(leaf, "leaf_%d" % index, "foliage", "")
	props._rebuild_active_entries()
	check(props.active_entries.size() == 28, "balanced ambient cap is retained")
	check(Everyday.phase_crossed(0.49, 0.52, 0.5), "contact follows actual playback crossing")
	check(not Everyday.phase_crossed(0.52, 0.52, 0.5), "repeated frame does not repeat contact")
	check(Everyday.phase_crossed(0.98, 0.04, 0.02), "normal clip wrap emits an early contact")
	check(not Everyday.phase_crossed(-1.0, 0.52, 0.5), "first sample after suspension does not emit")
	check(not Everyday.phase_crossed(0.1, 0.8, 0.5), "large seek or hitch does not synthesize contact")
	check(not Everyday.phase_crossed(NAN, 0.8, 0.5), "nonfinite sample is rejected")
	check(not Everyday.phase_crossed(0.5, 0.6, 0.5), "contact boundary emits only on entry")
	var a := Vector3(-1, 0.036, -1)
	var b := Vector3(1, 0.036, -1)
	var c := Vector3(0, 0.036, 1)
	check(Everyday.water_contact_on_triangle(Vector3(0,0.05,0), a,b,c).is_equal_approx(Vector3(0,0.036,0)), "fin probe must meet actual water surface")
	check(not Everyday.water_contact_on_triangle(Vector3(0,0.2,0), a,b,c).is_finite(), "overhead fin does not fabricate a water contact")
	check(not Everyday.water_contact_on_triangle(Vector3(2,0.05,0), a,b,c).is_finite(), "shore-side fin does not fabricate a water contact")
	check(not Everyday.water_contact_on_triangle(Vector3.ZERO, a,a,a).is_finite(), "degenerate water triangle is ignored")
	var state := FlagState.new()
	scene.add_child(state)
	props.story_state = state
	wheel.set_meta("world_prop_flow_required", true)
	wheel.set_meta("world_prop_nominal_spin_speed", 0.45)
	props._sync_story_states()
	check(wheel.get_meta("world_prop_spin_speed") == 0.0 and entry.state == "stopped", "unresolved mill cannot run")
	state.flags = {"mill_operation":"supervised", "mill_ventilation_open":true, "ashwing_defeated":true}
	props._sync_story_states(true)
	check(wheel.get_meta("world_prop_spin_speed") == 0.45 and entry.state == "running", "restored supervised mill can run")
	state.flags.mill_operation = "closed"
	props._sync_story_states(true)
	check(wheel.get_meta("world_prop_spin_speed") == 0.0, "closed mill stops without a new story flag")
	var bell := Node3D.new()
	scene.add_child(bell)
	props._register(bell, "cemetery_bell", "clapper", "cemetery_bell_rung")
	var bell_entry: Dictionary = props.entries.back()
	state.flags.cemetery_bell_rung = true
	props._sync_story_states()
	check(bell_entry.state == "rung" and bell_entry.ring_remaining == 0.0, "loading an old ring does not replay bell motion")
	state.flags.cemetery_bell_rung = false
	props._sync_story_states(true)
	state.flags.cemetery_bell_rung = true
	props._sync_story_states(true)
	check(bell_entry.ring_remaining == 4.0, "new ring starts bounded clapper response")
	props._update_entry(bell_entry, 4.1)
	check(bell_entry.ring_remaining == 0.0 and bell.rotation.is_equal_approx(Vector3.ZERO), "clapper returns to rest")
	var effects := VFX.new()
	scene.add_child(effects)
	effects.set_physics_process(false)
	effects.emit_work_contact(Vector3.UP, Vector3.ZERO, "repair")
	check(effects.work_contacts.is_empty(), "ordinary repairs do not generate hot-metal sparks")
	for _index in 6: effects.emit_work_contact(Vector3.UP, Vector3.ZERO, "forge")
	check(effects.work_contacts.size() == 3 and effects.active_pulses == 3, "verified contact shares existing transient cap")
	effects._tick_work_contacts(0.4)
	check(effects.work_contacts.is_empty() and effects.active_pulses == 0, "contact effects release transient budget")
	effects.emit_work_contact(Vector3(30,1,0), Vector3.ZERO, "forge")
	check(effects.work_contacts.is_empty(), "distant forge contact is culled")
	scene.free()
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		quit(1)
	else:
		print("LIVING WORLD MOTION PASS: %d" % checks)
		quit(0)
