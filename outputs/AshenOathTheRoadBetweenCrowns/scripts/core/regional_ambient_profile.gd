extends RefCounted

static func for_zone(zone_id: String) -> Array:
	match zone_id:
		"greyfen":
			return [
				{"event":"village_life", "source":"village", "range":16.0, "cooldown":7.0, "pitch":0.05},
				{"event":"village_crow", "source":"village", "range":18.0, "cooldown":9.0, "pitch":0.08},
				{"event":"shrine_candle", "source":"shrine", "range":9.0, "cooldown":6.0, "pitch":0.04},
				{"event":"river_current", "source":"river", "range":18.0, "cooldown":6.0, "pitch":0.04},
				{"event":"cloth_wind", "source":"listener", "range":12.0, "cooldown":8.0, "pitch":0.04}
			]
		"wychwood":
			return [
				{"event":"forest_breath", "source":"forest", "range":16.0, "cooldown":6.5, "pitch":0.045},
				{"event":"wychwood_tension", "source":"forest", "range":14.0, "cooldown":8.0, "pitch":0.025},
				{"event":"river_current", "source":"river", "range":16.0, "cooldown":7.0, "pitch":0.04},
				{"event":"cloth_wind", "source":"listener", "range":12.0, "cooldown":9.0, "pitch":0.035}
			]
		"cemetery", "chapel":
			return [
				{"event":"shrine_hum", "source":"shrine", "range":13.0, "cooldown":7.0, "pitch":0.025},
				{"event":"shrine_bell", "source":"bell", "range":18.0, "cooldown":13.0, "pitch":0.035},
				{"event":"forest_breath", "source":"listener", "range":11.0, "cooldown":9.0, "pitch":0.04}
			]
		"vargan_approach", "vargan_court", "assembly":
			return [
				{"event":"stone_room", "source":"listener", "range":12.0, "cooldown":8.0, "pitch":0.03},
				{"event":"cloth_wind", "source":"listener", "range":12.0, "cooldown":10.0, "pitch":0.03}
			]
		"record_hall", "undercroft":
			return [
				{"event":"stone_room", "source":"listener", "range":12.0, "cooldown":9.0, "pitch":0.025},
				{"event":"forest_breath", "source":"listener", "range":10.0, "cooldown":11.0, "pitch":0.025}
			]
		"deep_wood", "burned_farmstead":
			return [
				{"event":"forest_breath", "source":"forest", "range":16.0, "cooldown":9.0, "pitch":0.035},
				{"event":"cloth_wind", "source":"listener", "range":10.0, "cooldown":12.0, "pitch":0.025}
			]
		"old_mill":
			return [
				{"event":"river_current", "source":"river", "range":15.0, "cooldown":8.0, "pitch":0.025},
				{"event":"cloth_wind", "source":"listener", "range":10.0, "cooldown":11.0, "pitch":0.025}
			]
		"marsh_crossing":
			return [
				{"event":"river_current", "source":"river", "range":15.0, "cooldown":9.0, "pitch":0.035},
				{"event":"wychwood_drop", "source":"forest", "range":12.0, "cooldown":13.0, "pitch":0.03}
			]
		"bandit_road":
			return [
				{"event":"cloth_wind", "source":"listener", "range":12.0, "cooldown":10.0, "pitch":0.035},
				{"event":"forest_breath", "source":"forest", "range":14.0, "cooldown":13.0, "pitch":0.025}
			]
		"ruins":
			return [
				{"event":"forest_breath", "source":"forest", "range":15.0, "cooldown":10.0, "pitch":0.025},
				{"event":"cloth_wind", "source":"listener", "range":10.0, "cooldown":14.0, "pitch":0.02}
			]
		"hart_glade":
			return [
				{"event":"shrine_hum", "source":"shrine", "range":16.0, "cooldown":8.0, "pitch":0.02},
				{"event":"forest_breath", "source":"forest", "range":16.0, "cooldown":9.0, "pitch":0.03}
			]
	return []
