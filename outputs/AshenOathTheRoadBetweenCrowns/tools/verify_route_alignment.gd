extends "res://tools/verify_opening_real_input_native.gd"

func _initialize() -> void:
	var cases := 0
	for start in [7.44414, 8.9, 10.3, 13.3, 15.7]:
		for initial_velocity in [-3.4, 0.0, 3.4]:
			var position: float = start
			var velocity: float = initial_velocity
			var previous_drive := 0
			var settled := 0
			for tick in range(120):
				var drive := _alignment_drive(13.2 - position, velocity, 21.0, 1.0 / 30.0)
				# Model physical acceleration plus one input-boundary delay.
				velocity = move_toward(velocity, previous_drive * 3.4, (21.0 if previous_drive == 0 else 17.0) / 30.0)
				position += velocity / 30.0
				previous_drive = drive
				settled = settled + 1 if absf(position - 13.2) <= 0.08 and absf(velocity) < 0.2 else 0
				if settled >= 3:
					break
			if settled < 3:
				_fail("Alignment did not settle under unchanged4s bounds: start=%.5f speed=%.1f final=%.5f" % [start, initial_velocity, position])
			cases += 1
	print("ROUTE ALIGNMENT: cases=%d tolerance=0.08 stopped_ticks=3 deadline_seconds=4 logic_only=true" % cases)
	quit(0 if failures.is_empty() else 1)
