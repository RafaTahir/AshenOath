extends RefCounted

static func resolve(ending: String, story_state) -> Array[String]:
	var cards: Array[String] = []
	cards.append(_covenant_card(ending))
	cards.append(_greyfen_card(story_state))
	cards.append(_anwen_card(story_state))
	cards.append(_vargan_card(story_state))
	var road_card := _road_card(story_state)
	if road_card != "":
		cards.append(road_card)
	var village_card := _village_card(story_state)
	if village_card != "":
		cards.append(village_card)
	return cards

static func _covenant_card(ending: String) -> String:
	match ending:
		"kill":
			return "ASH\nKael destroys the White Hart. Greyfen survives the season while the Wychwood fades into grey rot."
		"free":
			return "MERCY\nKael releases the White Hart. The binding breaks, and every hidden name returns to the road."
		"bind":
			return "DUTY\nKael binds the covenant to himself. Greyfen prospers, and his name joins the debt beneath the stones."
		_:
			return "WITNESS\nKael names the dead before Greyfen. The village keeps no peace purchased by silence."

static func _greyfen_card(story_state) -> String:
	var fear := int(story_state.values.get("greyfen_fear", 0))
	var names := str(story_state.get_flag("names_policy", "withheld"))
	if names == "published":
		return "GREYFEN\nThe names hang on every door. %s" % ("Fear drives families from the old road." if fear >= 4 else "The village remains and begins the work of confession.")
	return "GREYFEN\nThe truth travels household by household. Some call that mercy; others call it one more delay."

static func _anwen_card(story_state) -> String:
	var trust := int(story_state.values.get("anwen_trust", 0))
	var shrine := str(story_state.get_flag("crow_shrine_state", "bound"))
	if trust > 0:
		return "SISTER ANWEN\nAnwen keeps Kael's confidence and opens the shrine record. The Crow Shrine remains %s." % shrine
	return "SISTER ANWEN\nAnwen tends the shrine without asking Kael to absolve her. The Crow Shrine remains %s." % shrine

static func _vargan_card(story_state) -> String:
	var edric := str(story_state.get_flag("edric_stance", "silent"))
	var halvern := str(story_state.get_flag("halvern_fate", "unknown"))
	return "HOUSE VARGAN\nEdric leaves the record hall %s. Halvern is remembered as %s." % [
		{"cooperate":"under guarded protection", "exposed":"without the shelter of his title", "compelled":"bound to a public confession"}.get(edric, "still silent"),
		{"witness":"the officer who refused", "released":"a soldier finally released", "destroyed":"the last witness lost"}.get(halvern, "an unanswered name"),
	]

static func _road_card(story_state) -> String:
	var senn := str(story_state.get_flag("senn_fate", ""))
	var mill := str(story_state.get_flag("mill_fate", ""))
	if senn == "" and mill == "":
		return ""
	return "THE ROAD\nSenn's fate is %s. The mill ledger was %s; neither decision can make the ash ordinary again." % [
		senn if senn != "" else "unrecorded",
		mill if mill != "" else "left unread",
	]

static func _village_card(story_state) -> String:
	var outcomes: Array[String] = []
	for pair in [
		["widow_truth", "Elna's bell"],
		["iron_fate", "Tor's iron"],
		["mira_truth", "Mira's roots"],
		["black_dog_fate", "Toma's guardian"],
		["returned_soldier_fate", "the returned soldier"],
	]:
		var value := str(story_state.get_flag(pair[0], ""))
		if value != "":
			outcomes.append("%s: %s" % [pair[1], value])
	if outcomes.is_empty():
		return ""
	return "GREYFEN'S SMALLER STORIES\n" + ", ".join(outcomes) + "."
