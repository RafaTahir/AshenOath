@abstract
extends Node3D
## The station supplies the beat and its normalized work progress. Each ground
## scene implements both so cancelling work can restore the authored start pose.
@abstract func set_beat(index: int) -> void
@abstract func set_work(progress: float) -> void
