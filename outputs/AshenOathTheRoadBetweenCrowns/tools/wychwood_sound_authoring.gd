extends RefCounted
## Offline score for the hollow axle, the far-bank reply, and the three forest
## windups. Exported WAV resources play through the ordinary spatial SFX pool.

const RATE := 22050
const CUES := {
	"wychwood_road_call": 1.48, "wychwood_road_answer": 1.64,
	"wychwood_road_grant": 0.52, "wychwood_road_ack": 1.13,
	"stalker_husk_rasp": 0.50, "raider_cord_cinch": 0.43, "brute_heel_set": 0.62
}

static func compile(folder: String, catalog: Dictionary) -> Error:
	var status := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if status != OK: return status
	for cue: String in CUES:
		var wav := render(cue)
		var path := folder.path_join("cues_" + cue + ".res")
		status = ResourceSaver.save(wav, path, ResourceSaver.FLAG_COMPRESS)
		if status != OK: return status
		catalog[cue] = path
	return OK

static func knock(t: float, pitch: float, grit: float, ring: float) -> float:
	if t < 0.0: return 0.0
	var onset := 1.0 - exp(-t * 2800.0)
	var wood := sin(TAU*pitch*t) * exp(-t*29.0)
	wood += 0.40 * sin(TAU*pitch*2.71*t) * exp(-t*46.0)
	wood += 0.17 * sin(TAU*pitch*4.38*t) * exp(-t*61.0)
	var iron := sin(TAU*1358.0*t) + 0.39*sin(TAU*2011.0*t)
	return onset * (wood*0.52 + ring*iron*exp(-t*13.0) + 0.23*grit*exp(-t*175.0))

static func rub(t: float, span: float) -> float:
	if t <= 0.0 or t >= span: return 0.0
	return pow(sin(PI*t/span), 1.3)

static func throat_click(t: float, pitch: float, rasp: float) -> float:
	if t < 0.0: return 0.0
	var pulse := (1.0-exp(-t*1850.0))*exp(-t*37.0)
	var throat := sin(TAU*pitch*t + 0.9*sin(TAU*pitch*0.48*t))
	var tongue := sin(TAU*738.0*t)*exp(-t*84.0)
	return pulse*(0.76*throat + 1.05*rasp) + 0.24*tongue

static func render(cue: String) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = 678213 + CUES.keys().find(cue)
	var count := roundi(float(CUES[cue]) * RATE)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var low := 0.0
	var middle := 0.0
	for i in count:
		var t := float(i)/RATE
		var noise := random.randf_range(-1.0, 1.0)
		low += (noise-low)*0.055
		middle += (noise-middle)*0.37
		var grit := middle-low
		var sample_value := 0.0
		match cue:
			"wychwood_road_call":
				sample_value = knock(t-0.018, 261.0, grit, 0.056)
				sample_value += 0.80*knock(t-0.223, 277.0, grit, 0.031)
				sample_value += 0.96*knock(t-0.772, 252.0, grit, 0.11)
			"wychwood_road_answer":
				# The creature can reproduce a carter's rhythm with its throat.
				sample_value = throat_click(t-0.055, 182.0, grit)
				sample_value += 0.83*throat_click(t-0.312, 196.0, grit)
				sample_value += throat_click(t-0.955, 173.0, grit)
				sample_value += 0.31*low*rub(t-0.47, 0.36)
			"wychwood_road_grant":
				sample_value = knock(t-0.018, 243.0, grit, 0.13)
			"wychwood_road_ack":
				sample_value = 0.23*low*rub(t-0.05, 0.27) + throat_click(t-0.46, 165.0, grit)
			"stalker_husk_rasp":
				var breath := rub(t-0.018, 0.36)
				var husks := rub(t-0.045, 0.10) + 0.69*rub(t-0.181, 0.15)
				sample_value = breath*low*1.55 + husks*grit*(0.83+0.26*sin(t*287.0))
			"raider_cord_cinch":
				var catch := rub(t-0.015, 0.19) + 0.38*rub(t-0.242, 0.09)
				sample_value = catch*grit*(1.0+0.46*sin(t*272.0))
				sample_value += 0.50*knock(t-0.192, 536.0, grit, 0.06)
			"brute_heel_set":
				var heel := maxf(0.0, t-0.017)
				sample_value = 0.79*(1.0-exp(-heel*620.0))*exp(-heel*18.0)*sin(TAU*(77.0*heel+0.33*(1.0-exp(-heel*50.0))))
				sample_value += 0.65*knock(t-0.020, 126.0, grit, 0.008)
				sample_value += low*1.7*rub(t-0.061, 0.43)
		# Short release eliminates any end discontinuity in bass and breath.
		var end_fade := clampf(float(count-1-i)/(RATE*0.015), 0.0, 1.0)
		samples.encode_s16(i*2, roundi(clampf(sample_value*end_fade, -0.97, 0.97)*32767.0))
	var wav := AudioStreamWAV.new()
	wav.resource_name = cue
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = samples
	return wav
