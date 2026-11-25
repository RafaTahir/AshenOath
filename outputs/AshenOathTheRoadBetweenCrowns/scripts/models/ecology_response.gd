extends RefCounted

## One habitat's visual response. EverydayLife owns its clock and the interaction
## Area3D stays on its authored ground marker throughout the movement.
enum State { FIRST_ACTIVITY, SECOND_ACTIVITY, ALERT, RETURN }

var state := State.FIRST_ACTIVITY
var elapsed := 0.0
var armed := true
var side := 1.0
var profile: Dictionary
var clips: Array
var pose: Transform3D
var home: Transform3D

func _init(sighting: Dictionary, home_transform: Transform3D) -> void:
	profile = sighting.response
	clips = sighting.ambient_clips
	home = home_transform
	pose = home

func reset() -> void:
	state = State.FIRST_ACTIVITY
	elapsed = 0.0
	armed = true
	pose = home

func update(delta: float, observer_local: Vector3, ground_speed: float) -> void:
	var distance := Vector2(observer_local.x - home.origin.x, observer_local.z - home.origin.z).length()
	var hears_steps := float(profile.get("step_speed", 0.0))
	var radius := float(profile.radius)
	var detects := distance <= radius and ground_speed >= hears_steps
	if distance > radius + 0.65 or (hears_steps > 0.0 and ground_speed < hears_steps * 0.4):
		armed = true
	if detects and armed and state in [State.FIRST_ACTIVITY, State.SECOND_ACTIVITY]:
		armed = false
		side = -1.0 if observer_local.x >= home.origin.x else 1.0
		state = State.ALERT
		elapsed = 0.0
	elapsed += delta
	var duration := _duration()
	if elapsed >= duration:
		# A single decision may consume a fraction of the next phase.
		elapsed = fmod(elapsed, duration)
		match state:
			State.FIRST_ACTIVITY: state = State.SECOND_ACTIVITY
			State.SECOND_ACTIVITY, State.RETURN: state = State.FIRST_ACTIVITY
			State.ALERT: state = State.RETURN
	_apply_pose()

func selected_clip() -> String:
	if state == State.ALERT: return str(profile.alert_clip)
	if state == State.RETURN: return str(profile.return_clip)
	return str(clips[int(state)])

func _duration() -> float:
	if state == State.ALERT: return float(profile.alert)
	if state == State.RETURN: return float(profile.settle)
	return float(profile.calm[int(state)])

func _apply_pose() -> void:
	if state in [State.FIRST_ACTIVITY, State.SECOND_ACTIVITY]:
		pose = home
		return
	var outward := state == State.ALERT
	var t := clampf(elapsed / (float(profile.commit) if outward else float(profile.settle)), 0.0, 1.0)
	var travel := smoothstep(0.0, 1.0, t)
	var weight := travel if outward else 1.0 - travel
	var arc := sin(PI * travel)
	var movement: Array = profile.offset
	var offset := Vector3(float(movement[0]) * side, float(movement[1]), float(movement[2])) * weight
	offset.y += float(profile.get("arc", 0.0)) * arc
	var yaw := deg_to_rad(float(profile.yaw)) * side * weight
	var bank := deg_to_rad(float(profile.get("bank", 0.0))) * side * arc
	pose = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, bank) * home.basis, home.origin + offset)
