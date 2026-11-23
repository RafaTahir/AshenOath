extends RefCounted

static func offset(kind: String, progress: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	var envelope := pow(sin(t * PI), 2.0)
	match kind:
		"acknowledge", "nod": return Vector3(0.07 * envelope, 0, 0)
		"disagree": return Vector3(0, sin(t * TAU * 1.5) * 0.085 * envelope, 0)
		"remember", "recall": return Vector3(0.09 * envelope, -0.035 * envelope, -0.025 * envelope)
		"reassure": return Vector3(0.035 * envelope, 0, 0.04 * envelope)
		"guarded_listening": return Vector3(-0.025 * envelope, 0.035 * envelope, -0.018 * envelope)
		"offer": return Vector3(0.045 * envelope, 0, -0.018 * envelope)
		"explain": return Vector3(sin(t * TAU) * 0.035 * envelope, 0.045 * envelope, 0.015 * envelope)
		"hesitate": return Vector3(0.045 * envelope, -0.065 * envelope, -0.018 * envelope)
		"relief": return Vector3(0.06 * sin(t * TAU) * envelope, 0.0, 0.018 * envelope)
	return Vector3.ZERO
