extends RefCounted

const PERFORMANCE_PATH := "res://data/regional_performances.json"
static var _performances: Dictionary = {}

static func performance(id: String) -> Dictionary:
	if _performances.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PERFORMANCE_PATH))
		if data is Dictionary and int(data.get("version", 0)) == 1:
			_performances = data.get("quests", {})
	return _performances.get(id, {})

static func opening(id: String) -> String:
	return str(performance(id).get("opening", QUESTS.get(id, {}).get("hook", "")))

static func account(id: String, step: Array) -> String:
	return str(performance(id).get("beats", {}).get(str(step[0]), step[5]))

static func observation(id: String, step: Array, index: int) -> String:
	var clues: Array = performance(id).get("clues", QUESTS.get(id, {}).get("observations", {})).get(str(step[0]), [])
	if index >= 0 and index < clues.size():
		return str(clues[index])
	return str(step[4][index]) + ". Compare this with the other marked evidence before drawing a conclusion."

static func aftermath(id: String, outcome: String) -> String:
	if id == "saga_wyc_q05" and outcome not in ["side_channel", "natural_run"]:
		return "The work is recorded as complete, but this saved account does not identify the chosen watercourse. No branch has been inferred."
	return str(performance(id).get("outcomes", QUESTS[id].get("outcomes", {})).get(outcome, QUESTS[id].steps.back()[5]))

## Existing objective/part IDs survive; only their authored physical stations move.
const PART_SITES := {
	"side_escort_01:steady_arrival":["escort_care", "escort_forge", "arrivals"],
	"side_escort_02:read_two_roads":["deadfall", "boundary", "blind"],
	"side_escort_05:compare_accounts":["archive", "copies"],
	"saga_wyc_q01:compare_stumps":["grove", "grove", "boundary"],
	"saga_wyc_q01:return_tag":["grove", "boundary", "grove", "workers"],
	"saga_wyc_q04:follow_three_marks":["deadfall", "boundary", "blind"],
	"saga_wyc_q05:survey_watercourse":["water", "water", "pots"],
	"saga_dep_q02:survey_plot":["garden", "runoff"],
	"saga_dep_q03:inspect_air":["flue", "cellar", "flue"],
	"saga_dep_q04:inspect_stock":["graft", "orchard", "fallen"],
	"saga_roa_q01:compare_terms":["rates", "command"],
	"saga_roa_q04:survey_line":["posts", "line", "causeway"],
	"saga_roa_q04:set_markers":["posts", "line", "causeway"],
	"saga_var_q04:trace_authority":["intake", "store"],
	"saga_var_q02:deliver_copy":["intake", "service"],
	"saga_har_q03:read_tracks":["tracks", "edge", "cord"],
	"saga_har_q03:mark_quiet_edge":["edge", "tracks"]
}

const PRESENTATION_SITES := {"saga_wyc_q04":"blind", "saga_dep_q03":"cellar", "saga_dep_q04":"graft", "saga_gre_q04":"kitchen", "side_escort_02":"blind", "side_escort_04":"causeway"}

const BUNDLED_CARRIES := {
	"saga_dep_q02:prepare_bed":"supplied clean fill",
	"saga_dep_q05:fit_cover":"remaining roof-cover pieces",
	"saga_roa_q01:return_claimed_goods":"remaining claimants' bundles",
	"saga_har_q05:prepare_plot":"supplied plot pieces"
}

const GREETINGS := {
	"saga_maren":"You can sit here. It is a seat, Kael. We needn't decide anything larger over supper.",
	"saga_nessa":"There you are. Sit down a moment; I can talk without stopping the bread.",
	"saga_jory":"I checked the rope again. Couldn't help myself. How was the road?",
	"saga_iven":"Back along the same path? Good. Tell me if the markers need seeing to.",
	"saga_edda":"You can put that pack down. I am not going to put you straight back to work.",
	"saga_dain":"Mind your boot by the bench. I keep saying I will sort that pile. You have seen how well saying it works.",
	"saga_ressa":"Have a look, if you like. Things take their time here.",
	"saga_nera":"Firm ground this side. Catch your breath before you tell me what happened.",
	"saga_tavin":"I know that step now. I was getting tired of wondering who was coming up the road.",
	"saga_lysa":"I kept the source references where you can find them. There is room at the end of the table.",
	"saga_odran":"The plants have managed without your supervision, hunter. I expect we will too.",
	"saga_maelin":"Still enough light to look at the beds. No need to decide anything tonight.",
	"saga_oris":"I put the chisel down for a little while. A surprisingly difficult piece of work."
}

static func part_site(id: String, step: Array, part: int, state = null) -> String:
	var site := str(step[2])
	if id == "saga_wyc_q05" and str(step[0]) == "place_clean_pots" and state != null and str(state.get_flag(id + "_outcome", "")) == "natural_run":
		return "pots_natural"
	var stations: Array = PART_SITES.get(id + ":" + str(step[0]), [])
	if id == "side_escort_01" and state != null and str(state.get_flag(id + "_outcome", "")) == "wheel":
		stations = ["escort_forge", "escort_care", "arrivals"]
	if part >= 0 and part < stations.size():
		return str(stations[part])
	if str(step[3]) == "carry" and part % 2 == 1 and part < step[4].size():
		site = str(step[4][part])
	if id == "saga_har_q04" and str(step[0]) == "set_trial" and part == 3 and state != null \
		and str(state.get_flag(id + "_outcome", "")) == "split_trial":
		site = "seeds"
	return site

## Authored optional content; QuestManager and StoryState own all progress.
## Steps: objective ID, instruction, site, verb, work parts/choices, account.
const WORLDS := {
	"gre":{"name":"Greyfen", "region":"greyfen", "home":"greyfen", "reward":"saga_bellkeeper_clasp"},
	"wyc":{"name":"Wychwood", "region":"wychwood", "home":"wychwood", "reward":"saga_wayfarer_grip"},
	"dep":{"name":"Deep Woods", "region":"deep_wood", "home":"old_mill", "reward":"saga_ash_tempered_fitting"},
	"roa":{"name":"The Long Road", "region":"long_road", "home":"bandit_road", "reward":"saga_roadwarden_baldric"},
	"var":{"name":"Castle Vargan", "region":"vargan", "home":"record_hall", "reward":"saga_witnessguard_pommel"},
	"har":{"name":"The Hartlands", "region":"hartlands", "home":"hart_glade", "reward":"saga_oathbearer_inlay"}
}
const REWARDS := {
	"saga_bellkeeper_clasp":{"name":"Bellkeeper's Clasp", "description":"A repaired warning bell, not another binding. Guarded hits cost 10% less stamina; parries are unchanged.", "effects":{"saga_guard_multiplier":0.90}},
	"saga_wayfarer_grip":{"name":"Wayfarer's Bow Grip", "description":"A forester's steady fitting. Full bow draw takes 10% less time.", "effects":{"saga_draw_multiplier":0.90}},
	"saga_ash_tempered_fitting":{"name":"Ash-Tempered Blade Fitting", "description":"Earned at the mill. Applied blade oils last 20% longer: six minutes of active play instead of five. Reapplication refreshes the duration; it does not stack.", "effects":{"saga_oil_duration_multiplier":1.20}},
	"saga_roadwarden_baldric":{"name":"Roadwarden's Baldric", "description":"Passage without a pledge. Sprint stamina expenditure is reduced by 10%.", "effects":{"saga_sprint_multiplier":0.90}},
	"saga_witnessguard_pommel":{"name":"Witnessguard Pommel", "description":"A successful parry restores 5 additional stamina, including with Measured Riposte.", "effects":{"saga_parry_restore":5.0}},
	"saga_oathbearer_inlay":{"name":"Oathbearer's Inlay", "description":"An earned fitting, not authority over another person. Oathfire cooldown is reduced by half a second, to its existing minimum.", "effects":{"saga_cooldown_reduction":0.5}}
}
const PEOPLE := {
	"saga_maren":{"name":"Nera", "zone":"greyfen", "site":"arrivals", "role":"villager_female_human", "line":"Hold that wheel, would you? The patient has had enough surprises for one journey.", "return":"We got the load through. I am going with the next one because I choose to, not because the road has finished with us."},
	"saga_dain":{"name":"Tor", "zone":"old_mill", "site":"dispatch", "alias":true, "line":"I can mend a wheel. I cannot make an honest weight out of a secret fee.", "return":"The cover is dry. There is work under it that we chose for ourselves."},
	"saga_nessa":{"name":"Nessa", "zone":"greyfen", "site":"kitchen", "role":"villager_female_human", "line":"I can bake less. I cannot tell a child a smaller loaf is the same size.", "return":"There is bread on the shelf. Take a seat before you ask what needs doing."},
	"saga_jory":{"name":"Tor", "zone":"greyfen", "site":"bell", "role":"villager_worker_human", "line":"A bell is a promise that somebody is listening. The pin is only iron.", "return":"I checked the rope this morning. You needn't keep listening for it."},
	"saga_iven":{"name":"Toma", "zone":"wychwood", "site":"workers", "role":"villager_worker_human", "line":"The wood isn't wicked. A rotten branch doesn't need an oath to fall.", "return":"The work line is marked. What grows beyond it is not ours to spend."},
	"saga_edda":{"name":"Mira", "zone":"wychwood", "site":"shelter", "role":"villager_female_human", "line":"Charcoal buys winter food. That doesn't make every way of earning it right.", "return":"There's room on the seat. The tune hasn't grown any grander."},
	"saga_ressa":{"name":"Elna", "zone":"burned_farmstead", "site":"garden", "role":"villager_female_human", "line":"I want a place to plant. Not a promise that the old place didn't burn.", "return":"Nothing has ripened overnight. Still, there is something here to tend."},
	"saga_nera":{"name":"Nera", "zone":"marsh_crossing", "site":"keeper", "role":"villager_female_human", "line":"I closed the crossing. I can tell you why. I cannot tell you they all got home.", "return":"The warning is there in daylight too. Nobody should have to guess."},
	"saga_tavin":{"name":"Rook", "zone":"bandit_road", "site":"supply", "role":"villager_worker_human", "line":"The coat wasn't mine. For a while I hoped its name would fit better than my own.", "return":"A road needs repairs. It doesn't need to belong to the man holding the tools."},
	"saga_lysa":{"name":"Vale", "zone":"record_hall", "site":"archive", "role":"villager_female_human", "line":"A clean copy can hide a dirty order. Compare the hands, not just the words.", "return":"The comparison stays with its sources. No page gets to speak for everyone."},
	"saga_odran":{"name":"Toma", "zone":"vargan_court", "site":"garden", "role":"villager_worker_human", "line":"I like the plants. That is not the same as choosing the walls.", "return":"These plants are here by my leave. My work is not a sentence."},
	"saga_maelin":{"name":"Mira", "zone":"ruins", "site":"seeds", "role":"villager_female_human", "line":"Seeds are not a promise of spring. Keeping some back is how we try again.", "return":"Leave the larger trees. A small bed is enough work for two hands."},
	"saga_oris":{"name":"Tor", "zone":"ruins", "site":"workbench", "role":"villager_worker_human", "line":"I promised a stone for everyone. I did not know how many people everyone was.", "return":"The rack has an end. I can put down my tools when I reach it."}
}

## These shoulders are outside the existing main route and combat lanes.
## The activity owner fits them to the shared spatial occupancy contract.
const SITES := {
	"greyfen":{"kitchen":Vector3(-3.7,0,7.4), "cart":Vector3(-5.6,0,10.3), "store":Vector3(-9.0,0,10.3), "bell":Vector3(-11,0,-7), "basket":Vector3(-9,0,-6), "door":Vector3(9,0,8.8), "timber":Vector3(6.2,0,12.5), "table":Vector3(-7,0,12.1), "arrivals":Vector3(-2.8,0,13.5), "courtyard":Vector3(4,0,10), "well":Vector3(-2.8,0,1.4), "letter":Vector3(8,0,10.4)},
	"wychwood":{"workers":Vector3(-5.8,0,10.2), "grove":Vector3(-8.2,0,8), "boundary":Vector3(-10,0,6.7), "shelter":Vector3(6,0,10), "snares":Vector3(8,0,7.8), "deadfall":Vector3(-5,0,12), "blind":Vector3(-10,0,10.8), "water":Vector3(7.7,0,-5.8), "pots":Vector3(10,0,-6), "pots_natural":Vector3(10,0,-4.3), "bog":Vector3(3.6,0,-7.0)},
	"old_mill":{"dispatch":Vector3(-3.6,0,7.5), "sacks":Vector3(-6,0,8.3), "slip":Vector3(-8,0,7), "shelter":Vector3(-4.5,0,11), "timber":Vector3(-7.3,0,10), "records":Vector3(-2.4,0,9.5), "hatch":Vector3(-7.8,0,1.1)},
	"burned_farmstead":{"garden":Vector3(3.5,0,8), "runoff":Vector3(5.5,0,9), "fill":Vector3(1.7,0,10.5), "cellar":Vector3(-4,0,-6), "flue":Vector3(-3.7,0,-3.6), "crock":Vector3(-3,0,-5.1), "orchard":Vector3(-5,0,7.8), "graft":Vector3(-7.2,0,7.8), "fallen":Vector3(-8.5,0,5.7)},
	"marsh_crossing":{"keeper":Vector3(-4.4,0,9), "mooring":Vector3(-5,0,6), "box":Vector3(-6.8,0,7.7), "posts":Vector3(4.5,0,9), "line":Vector3(4.5,0,3.2), "causeway":Vector3(6.5,0,9.7)},
	"bandit_road":{"supply":Vector3(-5,0,6.6), "rates":Vector3(-3,0,3.2), "bundles":Vector3(-6.3,0,4.1), "collection":Vector3(-3.6,0,9.4), "command":Vector3(6.7,0,2.8), "lane":Vector3(2.8,0,5.7), "cache":Vector3(-7.5,0,7.5)},
	"record_hall":{"archive":Vector3(-5,0,7.8), "copies":Vector3(-7.2,0,7.6), "dispatch":Vector3(5,0,7.5), "memorial":Vector3(7.4,0,4.8), "backing":Vector3(-8.2,0,8.4)},
	"vargan_court":{"garden":Vector3(-6.3,0,7.3), "locker":Vector3(-4.6,0,5.4), "service":Vector3(5.8,0,8), "intake":Vector3(3.5,0,9.5), "store":Vector3(7.6,0,5.8)},
	"vargan_approach":{"passage":Vector3(-4,0,7.3)},
	"undercroft":{"memorial":Vector3(-6,0,9)},
	"ruins":{"workbench":Vector3(-5,0,4.8), "sources":Vector3(-8,0,3), "memorial":Vector3(-5,0,1.5), "rack":Vector3(-2.6,0,4.4), "seeds":Vector3(5,0,5.3), "alcove":Vector3(7.4,0,4.8), "sanctuary":Vector3(6,0,-5.5)},
	"hart_glade":{"tracks":Vector3(-7,0,8), "cord":Vector3(-8.5,0,5.5), "edge":Vector3(-5,0,10), "plot":Vector3(5.4,0,9), "record":Vector3(7.5,0,9.8), "grove":Vector3(8.2,0,6)}
}

const QUESTS := {
	"side_escort_01":{"title":"The One Who Returned", "zone":"greyfen", "region":"greyfen", "actor":"saga_maren", "site":"arrivals", "activity":"care", "hook":"Nera's relief cart has arrived with a loose wheel and an exhausted traveler. Anwen has the patient; Tor needs someone to brace the axle. Neither job can wait for a biography.", "outcomes":{"care":"Anwen settled the traveler first; Tor's axle was braced afterward. Nera recognized Kael from the escort he abandoned. She survived without his return, and has offered no forgiveness.", "wheel":"Tor's axle was secured first while Anwen stayed with the traveler. Nera recognized Kael from the escort he abandoned. Her present relief work is her own."}, "steps":[
		["choose_priority","Ask where your hands are needed first","arrivals","choice",{"care":"Help Anwen settle the traveler, then brace Tor's axle","wheel":"Brace Tor's axle while Anwen stays with the traveler"},"Both tasks will be finished. Choosing their order does not heal Kael, consume a patient's supplies or decide anyone's survival."],
		["steady_arrival","Settle the relief arrival with Anwen and Tor","arrivals","work",["Hold the clean linen within Anwen's reach","Seat Tor's axle brace","Check the secured wheel and leave the traveler space"],"The wheel holds and the traveler can rest. Nera stacks the remaining supplies herself. Nobody waited here for a hunter to do all the work."],
		["hear_recognition","Hear what Nera recognizes","arrivals","talk",[],"Nera: 'I know you. Not from this village. You were on our escort. You left at the bend.' Kael: 'I did.' Nera: 'I learned to set a wheel after that. We still needed to get somewhere. If you want to follow the work line, Toma can show you where it crosses the old road. Do not tell me what I must want from you.'"]]},
	"side_escort_02":{"title":"No Footsteps Back", "zone":"wychwood", "region":"wychwood", "actor":"saga_maren", "site":"workers", "previous":"side_escort_01", "early_clues":true, "hook":"Toma's present work line crosses the road Nera remembers. Follow what can still be observed; old damage cannot tell Kael everything that happened after he left.", "outcomes":{"dry_shoulder":"Kael checked the dry shoulder on foot. Fresh work tracks are distinct from the older broken route; the clearing's creatures do not explain away his retreat.", "work_line":"Kael checked Toma's marked work line on foot. The maintained marks describe present passage, not a complete reconstruction of the abandoned escort."}, "steps":[
		["read_two_roads","Compare old damage with the current work trail","deadfall","inspect",["Old escort wheel scrape","Fresh work-line notch","Current lookout tracks"],"The marks have different ages. Kael recognizes where he turned away, but cannot see the lives that continued beyond him."],
		["choose_approach","Choose a maintained approach through Wychwood","workers","choice",{"dry_shoulder":"Take the dry shoulder to the old lookout","work_line":"Follow the maintained work line past the boundary"},"Both approaches use existing firm ground. Look at the clearing from the shoulder before entering; there is no new river crossing or replacement encounter."],
		["walk_approach","Walk and check the chosen approach","deadfall","walk",["deadfall","boundary","blind"],"The fresh tracks continue past the old damage. Existing creatures and cleared encounters retain their actual state; none are summoned to reenact Kael's past."],
		["mark_passage","Turn the existing route marker toward the checked passage","blind","work",["Turn the loose marker toward firm ground","Check the work-line notch against the route just walked"],"A useful marker faces the checked path. Nera's crew can read it without knowing Kael's story."]]},
	"side_escort_03":{"title":"What We Carried", "zone":"old_mill", "region":"deep_wood", "actor":"saga_maren", "site":"shelter", "previous":"side_escort_02", "activity":"repair", "hook":"Nera has brought the relief load to the mill yard. A damaged lifting frame puts the usable supplies at risk. Tor knows the frame; Nera knows which loads can be moved safely.", "outcomes":{"medicine":"The supported lift recovered the sealed medicine load; damaged repair stock remains marked aside. Nera's crew made the decision with Kael, not for his absolution.", "tools":"The supported lift recovered the usable tools; the unstable medicine crate remains isolated for the crew's later work. No inventory supplies or campaign rescues were erased."}, "steps":[
		["hear_lift_plan","Hear Nera's loading plan","shelter","talk",[],"Nera: 'Light crate to the left. Heavy one stays low. Tor says the frame will hold if someone seats that brace.' Kael: 'You have done this before.' Nera: 'There was no one left to do it for us. Mind your fingers.'"],
		["brace_lift","Brace and test the relief lifting frame","shelter","work",["Seat the foot brace","Take the slack out of the lift rope","Test the supported crossbeam"],"The frame takes the strain. Nobody enters the old mill or changes the recorded workers' escape."],
		["choose_load","Agree which supported load to recover now","shelter","choice",{"medicine":"Recover the light sealed medicine load","tools":"Recover the usable repair tools"},"The crew isolates the unsafe stock. A practical limit is not a claim that every loss can be undone."],
		["lower_load","Lower the chosen load onto the supported tray","shelter","work",["Hold the brake while Nera guides the load","Lower the cradle onto its supports","Release the slack rope"],"Nera checks the load herself. 'That much we can use. Leave the rest marked. We are not putting a person under it.'"]]},
	"side_escort_04":{"title":"Hold the Rear", "zone":"marsh_crossing", "region":"long_road", "actor":"saga_maren", "site":"keeper", "previous":"side_escort_03", "hook":"Nera and the relief travelers are ready for Nera's crossing. She will lead the group. Kael can clear the approach or protect the rear, and stay until the last traveler reaches firm ground.", "outcomes":{"approach":"Kael checked the approach while Nera led the travelers through Nera's existing safe route. The group waited at safe anchors when separated or threatened.", "rear":"Kael stayed behind the last traveler while Nera led the crossing. It was present work, not a replacement version of his retreat."}, "steps":[
		["choose_position","Agree your place in the crossing","keeper","choice",{"approach":"Clear the approach; let Nera lead the travelers","rear":"Protect the rear; stay behind the last traveler"},"Nera: 'I give the travelers their pace. If you need us to stop, we stop. No one gets dragged along to finish your promise.'"],
		["cross_with_crew","Accompany every traveler to the far safe shoulder","keeper","escort",["keeper","line","causeway"],"The last traveler reaches firm ground. The group kept its own pace; no unseen casualty clock decided the crossing."],
		["check_last_load","Check the last load with Nera","causeway","talk",[],"Nera counts the people before the crates. 'All here. That is what I asked. It does not change the other road.' Kael: 'No.' Nera: 'Good. Help me get the rope dry.'"],
		["coil_return_rope","Coil the emergency rope clear of the passage","causeway","work",["Dry the used length on the existing post","Coil it where the next traveler can reach it"],"Nera's emergency rope is ready for the next crossing. Nobody has inherited Senn's authority over the road."]]},
	"side_escort_05":{"title":"The Word Retreat", "zone":"record_hall", "region":"vargan", "actor":"saga_maren", "site":"archive", "previous":"side_escort_04", "early_clues":true, "activity":"read", "hook":"Vale can retain a correction to Kael's own report. Nera has offered a limited written account of her escort, not testimony about Vargan's massacre. Her name is not the price of correcting his.", "outcomes":{"public":"Kael publicly corrected his own retreat report. Nera's separately offered account remains limited to what she experienced; her participation was not purchased.", "protected":"Kael retained a protected correction with a challengeable source reference. Nera's name and account were not made public. The original command proof is unchanged."}, "steps":[
		["compare_accounts","Compare Kael's report with Nera's offered account","archive","inspect",["Kael's report of retreat","Nera's limited escort account"],"Kael called his departure a retreat and omitted the civilians he had promised to escort. Nera records only her own experience afterward. Neither page proves Vargan's massacre."],
		["hear_boundary","Ask what Nera permits you to retain","archive","talk",[],"Nera: 'Keep what I gave you. Not a list of everyone who was there. Some of them do not want you finding them.' Vale: 'The correction concerns your report, Kael. Start with your own name.'"],
		["choose_correction","Choose custody of your own correction","archive","choice",{"public":"Correct your own report in the public register","protected":"Retain a protected correction with a source reference"},"Kael: 'I left civilians after promising escort. I wrote retreat because it sounded like something done to me.' The correction does not ask anyone else for forgiveness."],
		["place_correction","Place and reference the correction without altering old proof","copies","work",["Place Kael's signed correction","Keep Nera's offered account in its agreed custody","Cross-reference rather than overwrite the original"],"Vale leaves the original legible beside its correction. The command ledger and Halvern's bounded account retain their own authority."]]},
	"side_escort_06":{"title":"A Road Kept Open", "zone":"hart_glade", "completed_zone":"greyfen", "region":"hartlands", "actor":"saga_maren", "site":"plot", "previous":"side_escort_05", "requires":"hart", "activity":"sort_supplies", "lore":"Nera's relief cord: a journal keepsake of a completed handover, not another oath or equipment bonus. The people from the abandoned escort retain lives Kael does not know.", "outcomes":{"company":"Nera accepted company for the handover and kept her own plans. Kael completed the existing journey home; the next road is an offer, not proof of forgiveness.", "distance":"Nera kept a little distance while the relief work was handed over. Kael respected it and completed the existing homecoming. Cooperation did not erase the abandoned escort."}, "steps":[
		["handover_relief","Complete the relief handover beside the changed grove","plot","work",["Place the recovered load on the receiving tray","Leave the route markers with the willing receivers"],"The handover takes place after the recorded covenant. No Hart is restored after Ash, no binding is invented after Mercy, and no one is pledged to carry this work forever."],
		["choose_company","Offer company without demanding reconciliation","plot","choice",{"company":"Share a quiet meal before the next journey","distance":"Keep a little distance and finish the handover"},"Nera: 'I can work beside you. Some days I may not want to. Let that be an answer too.' Kael agrees. The next journey remains hers to choose."],
		["return_home","Finish the existing Greyfen homecoming, then meet Nera at arrivals","arrivals","homecoming",[],"Nera has collected her next route. 'Nessa packed too much bread. She says that is a problem for my judgment, not her baking.' The cord stays in Kael's journal. A place at supper is offered without another oath.",{"zone":"greyfen"}]]},
	"saga_gre_q01":{"title":"The Baker's Last Sack", "zone":"greyfen", "actor":"saga_nessa", "site":"kitchen", "hook":"The marked sack and the delivery scale disagree. Help Nessa find what changed without accusing a hungry household.", "items":{"travel_bread":2}, "steps":[
		["hear_shortfall","Ask Nessa about the short delivery","kitchen","talk",[],"Nessa: 'A smaller loaf is not the same size. Let's find the measure before we find someone to blame.'"],
		["compare_measures","Compare the sack seam and delivery scale","cart","inspect",["Marked sack seam","Replaced scale pin"],"The sack's old seam agrees with Tor's weight. A smaller pin changed the delivery measure."],
		["trace_diversion","Follow spilled grain and read the current ration slip","store","inspect",["Spilled grain","Dry store ration slip"],"An intermediary took a fee. One household then kept an extra share. Neither fact proves who ordered the massacre."],
		["settle_supply","Agree how the measure will be corrected","kitchen","choice",{"public":"Post a correction without household addresses","private":"Keep protected copies and witness repayment","coerced":"Threaten to publish the household's address unless they repay"},"Nessa keeps the household out of the accusation. The next delivery can be challenged."],
		["weigh_next_batch","Set the corrected weight and mark the next receipt","kitchen","work",["Seat corrected weight","Mark the new receipt"],"Nessa: 'You left us enough truth to change the measure. That will do for today.'"]]},
	"saga_gre_q02":{"title":"The Apprentice's Bell", "zone":"greyfen", "actor":"saga_jory", "site":"bell", "hook":"Tor's warning bell is unreliable. Repair its ordinary mechanism without disturbing the cemetery guardian.", "lore":"Tor's maintenance sketch: brake, pin, release; the warning belongs to the watch.", "steps":[
		["inspect_mechanism","Inspect rope wear and the three notches","bell","inspect",["Frayed rope","Counterweight notches"],"The middle notch is worn bright. Tor's pin fell into the dry runoff basket."],
		["recover_pin","Collect Tor's dropped pin","basket","work",["Collect matching pin"],"A small iron pin. Nothing cursed; nothing safe to leave loose."],
		["seat_counterweight","Brake the weight, fit the pin, release the brake","bell","work",["Apply brake","Fit pin","Release brake"],"The weight now seats squarely. The watch can use its warning without entering the chapel."],
		["agree_warning","Agree a warning everyone can recognize","bell","choice",{"posted":"Post Tor's written rhythm guide","demonstrated":"Ask the watch to demonstrate and repeat it"},"Tor records the rhythm in words as well as beats. Nobody must hear perfectly to understand it."],
		["sound_trial","Ring the repaired warning and receive the watch's acknowledgement","bell","bell",["Pull trial rope","Watch acknowledges"],"Tor lifts a hand. The watch answers. This warning does not summon or dismiss the Bell-Eater."]]},
	"saga_gre_q03":{"title":"A Door Before Winter", "zone":"greyfen", "actor":"saga_nessa", "site":"door", "hook":"Elna has permitted a repair to her wet, sticking doorway. Keep her carved strip and her say in the work.", "items":{"bitterleaf_tonic":1}, "steps":[
		["survey_frame","Inspect Elna's wet sill and misaligned frame","door","inspect",["Wet sill","Carved frame"],"Elna's note gives permission to repair the entrance, not to decide her testimony."],
		["choose_repair","Choose a practical repair that preserves the carving","door","choice",{"renewed":"Replace the sill; retain the carved strip","braced":"Brace and drain the retained sill"},"Elna approves the proposed support. The public storm pile supplies the piece."],
		["fit_support","Carry the supplied support and seat it at the door","timber","carry",["Support from the storm pile","door"],"The new support is seated clear of the entrance. The old carving remains."],
		["check_clearance","Operate the repaired door and ask Elna to check the latch","door","door",["Open door","Close door","Elna checks the latch"],"Elna: 'It shuts without lifting it. That is a winter's worth of kindness.'"]]},
	"saga_gre_q04":{"title":"A Small Dishonesty", "zone":"greyfen", "actor":"saga_nessa", "site":"table", "hook":"Nessa and Rook disagree about a borrowed kettle and a wager. You need not win a game to put it right.", "items":{"travel_bread":1}, "steps":[
		["hear_accounts","Hear both accounts of the kitchen wager","table","inspect",["Nessa's account","Rook's account"],"Nessa offered a kettle for the evening. Rook remembers the word 'win' more clearly than the word 'borrow'."],
		["inspect_tally","Compare the score slip and chalked terms","table","inspect",["Scratched score slip","Chalked terms"],"A smudged tally cannot decide ownership. Both agree the kettle belongs in the kitchen."],
		["offer_settlement","Agree a replay or void the disputed advantage","table","choice",{"replayed":"Replay one ordinary Three Marks round; any result counts","voided":"Void the wager and return the kettle"},"Rook: 'Written terms. My oldest enemy.' Nessa laughs despite herself."],
		["return_kettle","Return the kettle to Nessa's shelf","table","carry",["Kitchen kettle","kitchen"],"Nessa puts the kettle on. Rook loses neither his friendship nor his place at the table."]]},
	"saga_gre_q05":{"title":"A Gate Left Open", "zone":"greyfen", "actor":"saga_nessa", "site":"arrivals", "requires":"bell", "hook":"The bell is quiet. New travelers still need somewhere to sleep without signing away their choices.", "steps":[
		["meet_arrivals","Greet the waiting travelers at the safe verge","arrivals","talk",[],"A traveler: 'We heard the bell stopped. We didn't know if that meant the road was welcome.'"],
		["prepare_shelter","Inspect and choose a usable shelter","courtyard","choice",{"store":"Open Nessa's dry store with a privacy screen","courtyard":"Prepare the quiet covered courtyard"},"Both spaces offer shelter without a pledge. The travelers agree to walk with you."],
		["escort_to_shelter","Stay with the travelers on the short village walk","arrivals","escort",["kitchen","courtyard"],"The travelers reach the prepared space on foot. They can rest without promising anything."],
		["post_terms","Post admission and maintenance terms; hand over the supplies","courtyard","work",["Post unconditional admission","Set the work and supply tray"],"Shelter without signature. Nessa leaves a dry place for tomorrow's arrivals."]]},
	"saga_wyc_q01":{"title":"The Woodcutter's Silence", "zone":"wychwood", "actor":"saga_iven", "site":"workers", "hook":"Toma stopped work after unfamiliar disturbances. Distinguish damaged timber, human marks and a living forest.", "items":{"iron_trap":1}, "steps":[
		["hear_stoppage","Hear Toma at the working layby","workers","talk",[],"Toma: 'We need wood. That doesn't make every standing tree ours.'"],
		["compare_stumps","Inspect the rotten, cut and living boundary stumps","grove","inspect",["Rotten stump","Fresh cut","Living boundary growth"],"Rot and a saw explain two marks. The third grew around an old boundary tag, not a new curse."],
		["find_old_boundary","Compare the displaced stake and stone boundary","boundary","inspect",["Displaced stake","Old stone boundary"],"The work line moved. The forest did not agree to it."],
		["mark_working_line","Choose and mark the agreed work line","grove","choice",{"fallen":"Use sound fallen timber only","limited":"Mark a limited live stand with agreed checks"},"Toma accepts a line that can be checked, rather than a promise of endless timber."],
		["return_tag","Set three line marks and return the boundary tag","workers","work",["Place first line mark","Place second line mark","Place third line mark","Return the tagged copy"],"Toma keeps the tag with the work book. The marked wood is a livelihood, not an enemy."]]},
	"saga_wyc_q02":{"title":"What the Traps Took", "zone":"wychwood", "actor":"saga_edda", "site":"snares", "hook":"An abandoned snare line hurts animals long after its owner leaves. Find who will answer for it.", "items":{"redroot_potion":1}, "steps":[
		["read_snare","Inspect the mechanism and fresh track","snares","inspect",["Snare mechanism","Fresh animal track"],"The cord has been left under tension. One anchor still moves."],
		["release_line","Open all three marked snares","snares","work",["Release empty snare","Ease injured animal's loop","Release the last snare"],"The caught animal slips into cover. The other loops hang slack."],
		["trace_owner","Compare the cord with Mira's tool roll","shelter","talk",[],"Mira: 'Mine. I left them when the road closed. Hunger explains it. It doesn't check the line for me.'"],
		["settle_hunting","Agree responsibility for the old line","shelter","choice",{"regulated":"Mark seasonal limits and a named check rota","retired":"Retire this line; establish an exchange basket"},"Mira chooses work she can account for. Neither answer makes the forest evil."],
		["clear_remaining","Collect loose wire and check the quiet release place","snares","work",["Collect loose wire","Secure the wire bin","Inspect the released line"],"No loop is left waiting. The work remains Mira's to maintain."]]},
	"saga_wyc_q03":{"title":"A Song for No One", "zone":"wychwood", "actor":"saga_edda", "site":"shelter", "hook":"Mira remembers a charcoal work-song, and a seat that needs mending. A quiet hour can matter without changing the world.", "lore":"Mira's work-song: a private call and reply, kept in words rather than an unapproved voice recording.", "steps":[
		["hear_invitation","Ask Mira about the tune","shelter","talk",[],"Mira: 'It isn't for calling spirits. It is for knowing somebody is still working beside you.'"],
		["find_seat_parts","Collect the fallen plank and peg","deadfall","work",["Collect sound plank","Collect matching peg"],"Both pieces are from the public fallen pile. No living branch is taken."],
		["restore_seat","Fit the plank and peg in the rest alcove","shelter","work",["Fit seat plank","Seat the peg"],"The seat is steady. Mira sets down her work."],
		["share_call","Share the private song","shelter","choice",{"listened":"Listen: 'Let the last coal rest.'","joined":"Answer: 'There is a hand beside your own.'"},"Mira: 'That is all of it. Some things don't need a crowd.'"]]},
	"saga_wyc_q04":{"title":"The Hunter's Blind", "zone":"wychwood", "actor":"saga_iven", "site":"deadfall", "hook":"A split-feather carving points toward an old lookout. Follow practical marks instead of chasing an invisible beacon.", "items":{"iron_trap":1}, "steps":[
		["read_first_mark","Read the split-feather sign by the deadfall","deadfall","inspect",["Split-feather sign"],"A cut below the feather points along the dry shoulder."],
		["follow_three_marks","Follow three branch scars on dry ground","blind","inspect",["Low branch scar","Forked branch scar","Lookout approach scar"],"The marks lead to a ground-level blind. No crossing through the river is needed."],
		["open_blind","Move the loose screen and read the keeper's diary","blind","work",["Move loose screen","Read maintenance diary"],"The owner left tools for maintained work, not a trophy for finding the place."],
		["deliver_deposit","Choose custody for the labeled tools","workers","choice",{"returned":"Return the deposit to Toma's maintained tool table","preserved":"Keep the tools in the blind with a recorded custodian"},"The deposit's location and owner remain recorded. Nobody's equipment becomes a repeatable cache."]]},
	"saga_wyc_q05":{"title":"Where the Water Runs", "zone":"wychwood", "actor":"saga_iven", "site":"water", "requires":"bog", "hook":"The Bog Wretch is resolved. The watercourse still needs hands, a screen and a place to collect clean water.", "steps":[
		["survey_watercourse","Inspect the inlet, blocked screen and downstream pots","water","inspect",["Upstream inlet","Blocked screen","Downstream collection"],"The guardian's fall did not remove the silt. Both possible channels can keep water clear."],
		["choose_flow","Agree how work and water will share this bank","water","choice",{"side_channel":"Fit a contained side channel for workers","natural_run":"Restore the natural run and move the collection stand"},"Toma marks the agreed line. Neither plan narrows the bridge or opens a river shortcut."],
		["clear_and_set","Clear debris, fit the screen and seat its gate","water","work",["Lift debris into basket","Fit reused screen","Seat the gate"],"The screen holds without damming the river."],
		["place_clean_pots","Carry both pots and compare the clearer flow","pots","work",["Place first collection pot","Place second collection pot","Compare the clear outflow"],"Clean water reaches the pots. The repaired place remains visible on return."]]},
	"saga_dep_q01":{"title":"The Second Ledger", "zone":"old_mill", "actor":"saga_dain", "site":"dispatch", "hook":"Today's freight is short. Tor wants the present fee accounted for, separately from the old wage chest.", "items":{"travel_bread":1}, "steps":[
		["read_dispatch","Read the current exterior dispatch page","dispatch","inspect",["Today's dispatch"],"Tor's present loads do not match the levy. This is not the atrocity's wage record."],
		["compare_sack_marks","Compare three current sack seals","sacks","inspect",["First sack seal","Second sack seal","Third sack seal"],"The seals match the scrape to the rejected-load bay."],
		["trace_fee","Follow the yard marks to the rejected-load slip","slip","inspect",["Wheel scrape","Rejected-load slip"],"An intermediary charged twice for a single rejected load. The signature proves that fee, not every old crime."],
		["settle_account","Choose custody of the freight comparison","dispatch","choice",{"public":"Post redacted current figures","witnessed":"Keep duplicate witnessed worker copies","falsified":"Knowingly mark the current dispatch paid; conceal the double fee"},"The comparison keeps names of hungry households out of the dispute."],
		["mark_next_load","Re-tag the next load and place its copy","sacks","work",["Re-tag the next load","Place the chosen dispatch copy"],"Tor: 'Now the next worker has something to check. More useful than telling us all to trust you.'"]]},
	"saga_dep_q02":{"title":"A Field Without Ash", "zone":"burned_farmstead", "actor":"saga_ressa", "site":"garden", "hook":"Elna needs a clean trial bed, not a miracle harvest on poisoned ground.", "ingredients":{"redroot":2}, "steps":[
		["survey_plot","Inspect the cleared bed and old runoff edge","garden","inspect",["Cleared bed","Old runoff"],"The runoff carries ash. A contained bed or screened terrace can keep the trial separate."],
		["source_clean_fill","Compare clean compost and contaminated ash","fill","inspect",["Public clean compost","Contaminated ash sample"],"Elna supplies the fill. Neither ordinary supplies nor anyone's food is consumed."],
		["choose_layout","Choose a clean growing trial","garden","choice",{"raised":"Build a contained raised bed","terrace":"Screen and drain a small terrace"},"Elna marks the trial. There is no promise that a new crop appears tonight."],
		["prepare_bed","Bring the supplied fill together and fit its edging","fill","carry",["Clean fill load one","garden","Clean fill load two","garden"],"The agreed bed is filled and raked, separate from the old ash."],
		["plant_trial","Set the supplied seed tray and origin label","garden","work",["Set Elna's seed tray","Label the seed origin"],"Elna: 'Not a field yet. A place where we can find out.'"]]},
	"saga_dep_q03":{"title":"The House That Kept Its Heat", "zone":"burned_farmstead", "actor":"saga_ressa", "site":"cellar", "hook":"Dry shelves survived beneath a sun-facing flue. Find the ordinary reason, and leave the store usable.", "lore":"The surviving cellar: sun-warmed brick, air through a dry flue, and Elna's marked bread crock.", "steps":[
		["inspect_air","Compare the flue, tracks and cellar grate","flue","inspect",["Sun-facing flue","Clean animal tracks","Cellar grate"],"Warm brick and moving air explain the dry space. No hidden fire spirit is needed."],
		["clear_entry","Lift two loose boards from the low entry","cellar","work",["Lift first loose board","Lift second loose board"],"The shelving can be reached from the safe apron without another interior or a crawl trap."],
		["identify_store","Read the shelf marks and bread crock","crock","inspect",["Dry shelf marks","Elna's crock mark"],"The crock is Elna's. Surviving storage is useful without pretending the house survived."],
		["choose_crock","Agree where the crock belongs","crock","choice",{"returned":"Return it to Elna's new work table","stored":"Keep it on the dry shelf with permission"},"Elna: 'Keep it useful. I don't need it kept as a wound.'"],
		["secure_air","Open the safe vent and fasten the grate","cellar","work",["Open safe vent","Fasten loose grate"],"The dry store is secured. Its contents and custody remain recorded."]]},
	"saga_dep_q04":{"title":"The Orchard's Debt", "zone":"burned_farmstead", "actor":"saga_ressa", "site":"orchard", "hook":"Living stock and repair timber are both needed. Keep their costs distinct from Rootbound's binding.", "items":{"iron_trap":1}, "steps":[
		["inspect_stock","Inspect the healthy graft, hollow trunk and fallen timber","orchard","inspect",["Healthy graft","Hollow trunk","Public fallen timber"],"There is still living growth. There is also sound wood already on the ground."],
		["hear_uses","Compare Elna's planting plan and Tor's repair note","graft","inspect",["Elna's planting plan","Tor's signed repair need"],"Neither plan cures the old roots. These are present workers' needs."],
		["choose_orchard","Agree which living growth to protect","orchard","choice",{"standing":"Keep the living stock; repair with fallen salvage","nursery":"Use sound salvage and protect a new nursery graft"},"Elna records what remains alive and what workers may take."],
		["protect_graft","Carry the frame, fit its stakes and wrap the graft","fallen","carry",["Supplied graft frame","graft"],"The frame holds without harming the graft or altering Rootbound's counterplay."],
		["record_material","Label the timber and the protected nursery","graft","work",["Label repair timber","Label protected graft"],"The next worker need not guess what this little place is for."]]},
	"saga_dep_q05":{"title":"A Roof Before Rain", "zone":"old_mill", "actor":"saga_dain", "site":"shelter", "requires":"mill", "hook":"Ashwing is gone and the mill's operation is settled. Give the workers a dry place for tomorrow's work.", "steps":[
		["survey_shelter","Inspect the yard cover and both supports","shelter","inspect",["Storm-damaged cover","West support","East support"],"The separate yard frame can be repaired whether the mill is closed or working."],
		["choose_station","Agree the new station's use","shelter","choice",{"relief_store":"Use a relief store for the closed mill","checking_station":"Use a checking station for working loads","workshop":"Use an independent workers' workshop"},"The chosen use respects the recorded mill operation; no old fate is rewritten."],
		["fit_cover","Carry three sound cover pieces to the frame","timber","carry",["First cover piece","shelter","Second cover piece","shelter","Third cover piece","shelter"],"The fitted cover is pegged, then checked from below."],
		["move_current_records","Move the new rota and dispatch copies under cover","records","carry",["Current work copies","shelter"],"Only current copies move. The old wage evidence remains available."],
		["open_workplace","Open the finished station with the workers' handover","shelter","work",["Inspect dry cover","Place the workers' handover"],"Tor's handover: 'A roof is useful because someone can work beneath it. Come back and see what we make of it.'"]]},
	"saga_roa_q01":{"title":"Toll for the Living", "zone":"bandit_road", "actor":"saga_tavin", "site":"collection", "hook":"Two receipts charge for one crossing. Recover the held goods through the camp account, not a fresh attack.", "items":{"travel_bread":2}, "steps":[
		["hear_double_toll","Compare the traveler's two receipts","collection","inspect",["Crossing receipt","Checkpoint receipt"],"The same journey was charged twice. The bundles have named claimants."],
		["compare_terms","Read the crossing rate and checkpoint stamp","rates","inspect",["Crossing rate","Checkpoint stamp"],"Neither rate authorizes the second charge."],
		["locate_held_goods","Identify both held bundles in the camp bay","bundles","inspect",["First claimant's bundle","Second claimant's bundle"],"Both bundles can be released against their receipts. Nobody needs to win another fight."],
		["secure_release","Agree a challengeable release record","supply","choice",{"public":"Expose the doubled rate without household addresses","recorded":"Keep protected copies and both claimants' receipts"},"The camp account yields the goods. The record does not become a pledge."],
		["return_claimed_goods","Carry both bundles to their collection stand","bundles","carry",["First held bundle","collection","Second held bundle","collection"],"Both claimants collect their own goods. The doubled charge is struck out."]]},
	"saga_roa_q02":{"title":"The Crossing Keeper's Oath", "zone":"marsh_crossing", "actor":"saga_nera", "site":"keeper", "hook":"Nera can account for a closed crossing without pretending she knows every traveler's fate.", "items":{"redroot_potion":1}, "steps":[
		["hear_closure","Hear Nera's account of the closure","keeper","talk",[],"Nera: 'I cut the rope. I could not hold it. I left that out when I wrote the log.'"],
		["inspect_last_marks","Inspect the mooring, cut cord and dated mark","mooring","inspect",["Old mooring post","Cut rescue cord","Dated closure mark"],"The marks support her account of the closure, not a count of the dead."],
		["recover_work_record","Read the later rescue in the keeper's box","box","inspect",["Keeper's later work record"],"Some people were rescued later. No record identifies everybody who was turned away."],
		["choose_account","Agree how Nera's admission will be kept","keeper","choice",{"open_log":"Place the factual admission in the open log","protected":"Keep protected duplicates without household names"},"Nera gives her own account. Kael does not promise forgiveness on another person's behalf."],
		["set_rescue_terms","Fit a warning board and emergency rope","mooring","work",["Fit daylight warning","Place emergency rope"],"The new warning is readable by shape and words. The rope is ready for a rescue, not another oath."]]},
	"saga_roa_q03":{"title":"Boots That Do Not Fit", "zone":"bandit_road", "actor":"saga_tavin", "site":"supply", "hook":"Rook borrowed a coat and a name. Return the effects without opening another person's letter.", "items":{"bitterleaf_tonic":1}, "steps":[
		["hear_borrowed_name","Hear Rook's admission","supply","talk",[],"Rook: 'I wore his coat. I let them call me by his name. The letter stayed sealed.'"],
		["verify_property","Compare the repair mark and address label","supply","inspect",["Coat's repair mark","Unopened household label"],"The effects can be returned without publishing the household's address."],
		["choose_delivery","Agree a private or signed return","supply","choice",{"private":"Use a neutral collection receipt","signed":"Rook signs his own account, without another pledge"},"Rook chooses how to own the act. The original letter remains closed."],
		["prepare_parcel","Fold the coat and seal its return parcel","supply","work",["Fold the borrowed coat","Seal the unopened letter","Mark ownership returned"],"The old identity is not destroyed. It is returned."],
		["confirm_receipt","Deliver the parcel and read its acknowledgement","collection","work",["Leave the sealed parcel","Read the collection acknowledgement"],"A dated receipt confirms collection. No off-map household is invented as a live speaker."]]},
	"saga_roa_q04":{"title":"Lights Across the Marsh", "zone":"marsh_crossing", "actor":"saga_nera", "site":"posts", "hook":"Restore a short signaling line that can be understood in sunlight as well as darkness.", "items":{"standard_arrow":6}, "steps":[
		["read_post","Read the fallen post's shape code","posts","inspect",["Shape code and maintenance mark"],"A notch faces safe ground. Light helps, but the daytime shape carries the same warning."],
		["survey_line","Inspect all three bases from dry ground","line","inspect",["South marker base","Middle marker base","North marker base"],"The marked route stays on existing firm ground. There is no new wading crossing."],
		["set_markers","Set and hood the three route markers","line","work",["Set south marker","Set middle marker","Set north marker"],"Each hood faces the next post. Words and notches remain legible without a lamp."],
		["walk_check","Choose the signal mode and walk both ends","posts","signal",{"fixed_posts":"Use fixed notched daylight posts","hooded_lamps":"Use hooded lamps with the same daylight notches"},"Nera: 'Now someone arriving late has more than our luck to guide them.'"]]},
	"saga_roa_q05":{"title":"The Road Belongs to No One", "zone":"bandit_road", "actor":"saga_tavin", "site":"command", "requires":"senn", "hook":"Senn's fate is settled. Decide who repairs the road without inheriting his ownership of it.", "steps":[
		["inspect_vacated_control","Inspect the retired command table and toll record","command","inspect",["Retired command terms","Old passage demand"],"The captain's fate is recorded. Nobody inherits the right to demand another person's oath."],
		["hear_maintenance","Compare Nera's rota and Rook's supply plan","supply","inspect",["Nera's voluntary rota","Rook's supply plan"],"Both plans keep repair duties challengeable and aid unconditional."],
		["choose_passage","Agree who keeps the road usable","command","choice",{"shared_rota":"Use voluntary rotating repair shifts","open_keeper":"Appoint an accountable keeper with open records"},"The work has owners. The road does not."],
		["open_lane","Retire the obsolete toll beam and install the new board","lane","work",["Carry aside the loose toll beam","Fit the open-passage board"],"The existing safe lane remains unobstructed. The old demand is not repeated."],
		["make_handover","Set the supply tray and accompany the first traveler","collection","escort",["supply","lane"],"A traveler walks through without signing. The new maintenance record stays at the supply tray."]]},
	"saga_var_q01":{"title":"The Orders Between Lines", "zone":"record_hall", "actor":"saga_lysa", "site":"archive", "hook":"Vale needs an attributed comparison, not a substitute for the command proof you already recovered.", "lore":"Vale's comparison separates the working author, copier and approving countersign; it is not the sole command proof.", "steps":[
		["hear_alteration","Hear Vale's comparison request","archive","talk",[],"Vale: 'An altered order is still a decision by somebody. Compare the hands.'"],
		["compare_copies","Compare the margin, working sheet and outgoing copy","copies","inspect",["Original margin","Revised working sheet","Outgoing copy"],"The dated sheets show a changed ration condition. The guaranteed command proof remains separate."],
		["attribute_hands","Compare the dated countersigns","archive","inspect",["Author's date","Copier's mark","Approver's countersign"],"Copying and approving are different acts. The comparison names each supported role."],
		["choose_custody","Agree custody for the comparison","archive","choice",{"archive":"File redacted copies in Vale's archive","protected":"Keep protected duplicates with named custodians"},"No household's intimate account is made public by default."],
		["file_comparison","Arrange and file the comparison with its sources","copies","work",["Arrange dated copies","File the attributed comparison"],"Vale leaves the source references visible. A document proves acts; it cannot consent for a person."]]},
	"saga_var_q02":{"title":"A Servant's Price", "zone":"vargan_court", "actor":"", "site":"service", "hook":"A servant's offered note records a family pass tied to silence. Protect departure without trading testimony for safety.", "items":{"travel_bread":2}, "steps":[
		["hear_offer","Read the servant's offered private note","service","inspect",["Signed offered account"],"Servant's note: 'They will let my family out if I say I saw nothing. I did not ask you to say it for me.'"],
		["verify_pass","Compare the family pass and complaint receipt","service","inspect",["Pass terms","Dated complaint receipt"],"The complaint predates the proposed silence. It can be recorded without naming the household publicly."],
		["choose_protection","Decide the terms of the household's departure","service","choice",{"unconditional_pass":"Require an unconditional pass on record","documented_passage":"Arrange neutral documented passage and protect the complaint","conditional_pass":"Accept Merrow's pass; withhold the household's optional complaint"},"The offered account remains the servant's. Departure does not depend on testimony."],
		["deliver_copy","Place complaint and pass copies at their separate destinations","intake","work",["File the complaint at intake","Place the household's pass copy"],"Both documents reach the agreed trays. Neither overwrites command evidence."],
		["confirm_departure","Read the dated departure acknowledgement","service","inspect",["Departure acknowledgement"],"The household passed through. The acknowledgement records a journey, not a new oath."]]},
	"saga_var_q03":{"title":"The Prisoner's Garden", "zone":"vargan_court", "actor":"saga_odran", "site":"garden", "hook":"Toma's release left his tools impounded. Let him choose whether gardening here is work he wants.", "ingredients":{"redroot":2}, "steps":[
		["read_release","Compare Toma's release order and tool tag","garden","inspect",["Dated release order","Impounded-tool tag"],"Release is already owed. A new labor pledge is not a price for his own tools."],
		["recover_tools","Claim the marked tools against the order","locker","work",["Present dated order","Collect the released tools"],"The service locker gives up the tools without theft or a new fight."],
		["choose_garden","Hear and record Toma's own choice","garden","choice",{"departed":"Help pack his traveling garden; he chooses to leave","voluntary_work":"Record voluntary paid work with the right to leave"},"Toma: 'The plants can stay if I do. That decision is mine.'"],
		["settle_bed","Move the tray and tools; place a water pot","locker","carry",["Released garden tray and tools","garden"],"The alcove is left clear for Toma's chosen use."],
		["acknowledge_choice","Receive Toma's own acknowledgement","garden","talk",[],"Toma confirms the recorded choice. The work is not a continuation of his confinement."]]},
	"saga_var_q04":{"title":"A Seal Without a Crown", "zone":"vargan_court", "actor":"", "site":"store", "requires":"ledger", "hook":"A supply office can feed people without inheriting Edric's authority over their promises.", "lore":"The trial distribution record removes assent as a condition of food; the Greyfen Assembly still requires its own work.", "steps":[
		["compare_warrants","Compare blank warrant, ration condition and actual authority","store","inspect",["Blank supply warrant","Current ration condition","Recorded distribution authority"],"The ration clause demands assent where an ordinary receipt would suffice."],
		["trace_authority","Follow the matching dockets to the dispatch tray","intake","inspect",["Courtyard docket","Dispatch counterfoil"],"The named officers can answer for supplies without claiming a crown."],
		["choose_register","Agree a challengeable supply record","store","choice",{"public_totals":"Publish aggregate allocations and voluntary officers","private_receipts":"Give households copies and preserve challengeable totals"},"Every household can challenge an allocation. No intimate account is a ration condition."],
		["prepare_clean_forms","Strike the coercive clause and duplicate the clean form","store","work",["Strike the assent clause","Make the clean duplicate"],"The new form asks what was delivered, not who consented to be ruled."],
		["issue_trial","Issue one supply parcel and its matching receipt","intake","work",["Set the trial parcel","Place the matching receipt"],"One ordinary delivery is recorded. This does not complete the separate Assembly relief sequence."]]},
	"saga_var_q05":{"title":"Those Who Had No Graves", "zone":"record_hall", "actor":"saga_lysa", "site":"memorial", "requires":"halvern", "hook":"Halvern's disposition is recorded. Give supported names a place while leaving unknown people honestly unknown.", "steps":[
		["compare_named_records","Compare supported proof and memorial entries","archive","inspect",["Guaranteed copied proof","Existing memorial entries"],"Only supported names are copied. Gaps remain gaps; Halvern's bounded memory is attributed."],
		["choose_memorial","Agree a public panel or a quiet repository","memorial","choice",{"public_panel":"Use attributed names on a redacted public panel","quiet_repository":"Keep protected copies in a quiet accessible repository"},"Neither route speaks publicly for a person who did not give consent."],
		["prepare_place","Clear the alcove and fit the supplied supports","memorial","work",["Clear loose work debris","Fit first support","Fit second support"],"The side alcove remains outside the arrival and return route."],
		["place_accounts","Place the attributed copies by hand","copies","carry",["Attributed memorial copies","memorial"],"The headings distinguish an account from a living speaker."],
		["leave_response_space","Set an empty reply tray and read its invitation","memorial","work",["Set empty reply tray","Place the invitation to correct the record"],"There is room for a living person's answer. No unrecorded victim is assigned a convenient name."]]},
	"saga_har_q01":{"title":"The Names Without Stones", "zone":"ruins", "actor":"saga_oris", "site":"workbench", "hook":"Tor has known names and too much unfinished stone. Leave room for what the living do not know.", "lore":"The optional Ruins memorial preserves attributed names and an explicitly unnamed place; it does not replace the complete Hart testimony.", "steps":[
		["read_request","Read Tor's invitation and known-name list","workbench","talk",[],"Tor: 'I can cut a name I know. I cannot make a person out of an empty line.'"],
		["compare_sources","Compare the offered copy and two memorial sources","sources","inspect",["Offered copied account","First memorial source","Second memorial source"],"The copied names have sources. The unfilled line stays unfilled."],
		["choose_place","Choose a supported memorial form","memorial","choice",{"named_walk":"Make a small attributed public walk","quiet_place":"Make a modest quiet repository with private copies"},"The marker states where each known name came from. Unknown is not erased."],
		["set_stones","Carry three supplied work stones to the prepared places","workbench","carry",["First light work stone","memorial","Second light work stone","memorial","Third light work stone","memorial"],"The stones stand clear of the path. The work was carried, not conjured by the final choice."],
		["leave_space","Place a blank marker for future information","memorial","work",["Set explicitly unnamed marker"],"Tor leaves the last line blank, on purpose."]]},
	"saga_har_q02":{"title":"A Promise Made in Fear", "zone":"ruins", "actor":"saga_oris", "site":"workbench", "hook":"Tor promised a memorial for everyone. Help him distinguish a finite task from a life he never freely offered.", "items":{"redroot_potion":1}, "steps":[
		["hear_promise","Let Tor describe the promise in his own words","workbench","talk",[],"Tor: 'If I stop, I thought it meant I had stopped caring. I am tired of caring like this.'"],
		["separate_obligations","Compare the commission, terms and unfinished work","rack","inspect",["Unfinished commission","Voluntary terms","Already-cut plaques"],"There is enough cut stone for a finite rack. The impossible promise adds no more names."],
		["offer_terms","Offer release or a bounded commission; hear his answer","workbench","choice",{"released":"Tor chooses release without a replacement vow","bounded":"Tor chooses a named finite task and stopping point"},"Tor answers for himself. Neither answer is Kael binding another person."],
		["finish_finite_work","Stack the already-cut plaques in the dry rack","rack","work",["Stack first finished plaque","Stack second finished plaque","Secure dry rack"],"The agreed finite work has an end."],
		["record_his_answer","Receive Tor's signed answer","workbench","talk",[],"Tor: 'Put that down as my answer. Not as something the stones made me say.'"]]},
	"saga_har_q03":{"title":"Where the Deer Return", "zone":"hart_glade", "actor":"", "site":"tracks", "hook":"Ordinary animals need a quiet passage. Remove abandoned work hazards without summoning another Hart.", "lore":"Fresh ordinary hoofprints returned through a cleared corridor. No new complete supernatural witness appeared.", "steps":[
		["read_tracks","Compare hoofprints, rubbed bark and abandoned cord","tracks","inspect",["Hoofprints","Rubbed trunk","Abandoned cord"],"The marks belong to ordinary wildlife. The hanging cord is the human problem."],
		["choose_corridor","Choose a quiet corridor outside the main route","edge","choice",{"outer":"Use the quiet outer shoulder","inner":"Use the sheltered inner shoulder"},"Both routes leave room for the living without changing the Hart's arena."],
		["clear_hazards","Unwind three cord points and brace the fallen screen","cord","work",["Unwind first cord","Unwind second cord","Unwind third cord","Brace fallen screen"],"No live tree is cut down. The dangerous loops are gone."],
		["mark_quiet_edge","Place two discreet human-work markers","edge","work",["Set first quiet-edge marker","Set second quiet-edge marker"],"The marks ask workers to keep clear. They are not giant signs hung over the forest."],
		["confirm_signs","Leave the immediate work area, return and inspect fresh tracks","tracks","return",[],"Fresh hoofprints pass through. Something living used the quiet you left."]]},
	"saga_har_q04":{"title":"The Keeper's Last Seed", "zone":"ruins", "actor":"saga_maelin", "site":"seeds", "hook":"Mira offers a limited reserve for a real trial, not permission to spend every seed on a promise.", "ingredients":{"grave_moss":2}, "steps":[
		["inspect_reserve","Examine Mira's offered envelope and notes","seeds","talk",[],"Mira: 'Some to try. Some to keep. If the first bed fails, we should still have a choice.'"],
		["survey_sites","Compare the drained alcove and sheltered bed","alcove","inspect",["Drained alcove","Sheltered woodland bed"],"Both sites are plausible. A trial must still leave a reserve."],
		["choose_plan","Agree a bounded seed trial","seeds","choice",{"split_trial":"Split a trial between both sites","reserve_first":"Use the better site and keep a larger reserve"},"Mira offers only the agreed portion. No outcome consumes her entire inheritance."],
		["set_trial","Carry the supplied soil cups and label the trial","seeds","carry",["Supplied trial cup one","alcove","Supplied trial cup two","alcove"],"The cups are labeled with their origin and the actual chosen trial."],
		["store_reserve","Put the remaining reserve and record in the dry box","seeds","work",["Store the untouched reserve","Place growing notes"],"Mira closes the box herself. There is something left to try next year."]]},
	"saga_har_q05":{"title":"What We Leave Growing", "zone":"hart_glade", "actor":"", "site":"plot", "requires":"hart", "hook":"The covenant is settled. Do a little work beside its changed garden, then leave responsibility with willing hands.", "steps":[
		["survey_aftermath","Inspect the actual covenant garden and adjacent plot","plot","inspect",["Recorded covenant aftermath","Adjacent practical work plot"],"The garden reflects the actual ending, including Ash. A practical place can remain after every resolution."],
		["choose_tending","Agree a nursery or a small resting shelter","plot","choice",{"nursery":"Establish a shared nursery with voluntary custodians","resting_shelter":"Establish a modest maintained resting shelter"},"Nobody is pledged to tend it forever. The work has names and a stopping point."],
		["prepare_plot","Carry two supplied pieces to the new plot","record","carry",["First supplied work piece","plot","Second supplied work piece","plot"],"The loose hazards are cleared. The new work sits beside, not over, the covenant garden."],
		["place_record","Place the actual outcome's attributed record","record","work",["Copy the recorded covenant","Attribute its known consequences"],"The record does not invent consent, resurrection or a better hidden ending."],
		["make_handover","Leave tools and instructions for the next willing hands","plot","work",["Leave the maintenance tools","Place the voluntary handover"],"The ordinary road remains open. Anwen, the workbench and the existing road-home reflection still await their own visits."]]}
}

## Secret: zone, site, clue, unlock action, contents/account, items, prerequisite.
const SECRETS := {
	"GRE-S01":["greyfen","bell","A maker's notch is repeated beneath the bell brake.","Release the maker's concealed catch","The founder's maintenance sketch is ordinary craft, not the guardian's binding.",{"iron_trap":1},""],
	"GRE-S02":["greyfen","well","Three short tally cuts point beneath the well-side ledge.","Lift the loose well-side cover","A current mutual-aid cache: the withdrawal is recorded, not anonymous theft.",{"travel_bread":2},""],
	"GRE-S03":["greyfen","letter","An offered envelope says: 'Ask before opening.'","Accept the household's invitation","The unfinished letter may remain sealed. Acknowledging it is enough; privacy is not a lesser discovery.",{},"consent"],
	"WYC-S01":["wychwood","blind","A small heel print ends beside a split-feather cut.","Follow the track and open the dry cache","A hunter's labeled current reserve, not the blind's separately held tool deposit.",{"standard_arrow":6},""],
	"WYC-S02":["wychwood","shelter","A charcoal tally follows the sheltered side of the bank.","Lift the old shelter's loose screen","A burner's weather note and one supplied tonic survive behind the screen.",{"bitterleaf_tonic":1},""],
	"WYC-S03":["wychwood","water","The clearer side water reveals a boundary cut from dry ground.","Read the exposed boundary inscription","The older boundary marks use of this bank, not the forest's moral guilt.",{},"water"],
	"DEP-S01":["burned_farmstead","cellar","A cupboard hinge has fresh work dust beside older scorch marks.","Open the accessible false cupboard","Elna's permitted current relief jar contains bread; the old keepsakes stay intact.",{"travel_bread":1},""],
	"DEP-S02":["old_mill","hatch","A millwright's scratched square marks a ground-level maintenance hatch.","Lift the released maintenance cover","A maintenance diagram and a tool from the shared repair supply.",{"iron_trap":1},""],
	"DEP-S03":["burned_farmstead","graft","The dry seed-store notch faces away from the ash runoff.","Open the orchard's marked seed store","A modest seed store, distinct from the new graft trial.",{},""],
	"ROA-S01":["marsh_crossing","causeway","Paired notch shapes line a dry shoulder; their shadows are not required.","Follow the dry causeway marks","A keeper's shelter niche holds one bread ration. The marks do not open a wading shortcut.",{"travel_bread":1},""],
	"ROA-S02":["bandit_road","cache","An old quartermaster's count ends beneath a loose supply stone.","Lift the supply stone","Three bodkin arrows were recorded as reserve, not another missing household's property.",{"bodkin_arrow":3},""],
	"ROA-S03":["bandit_road","command","A dispatch fold carries no outgoing seal.","Read the unsent military dispatch","An abandoned request for supplies; it excuses neither the raids nor the doubled toll.",{},""],
	"VAR-S01":["vargan_approach","passage","A service tally matches the existing record keeper's passage seal.","Inspect the documented service passage","The passage has its existing lock and destination. This discovery does not replace guaranteed command proof.",{"redroot_potion":1},"passage"],
	"VAR-S02":["record_hall","backing","A shelf backing has an ordinary repair tab.","Unfasten the false backing","A clerk's private copy survives; it is not the sole essential evidence. Six reserve arrows lie in the work roll.",{"standard_arrow":6},""],
	"VAR-S03":["vargan_court","garden","Toma's standing invitation permits inspection, not taking his whole collection.","Inspect the offered seed collection","Toma's labels preserve a living history. The seeds remain his in departure and voluntary-work outcomes.",{},""],
	"HAR-S01":["ruins","sanctuary","Weathered leaves on a low lintel point toward a sheltered recess.","Clear the loose leaves and read the limited record","An earlier visitor's account names its own limits. Only the Hart has complete testimony.",{},""],
	"HAR-S02":["ruins","rack","A chisel-maker's mark repeats on a discarded practice tile.","Open the shallow stoneworker's niche","An unfinished maker's dedication and one tool from a current work crate.",{"iron_trap":1},""],
	"HAR-S03":["hart_glade","grove","The changed covenant exposes the same shallow old root passage.","Read the newly accessible seasonal record","Witness opens canopy; Mercy releases ribbons; Duty leaves a steward mark; Ash burns a screen. The record survives all four.",{},"hart"]
}

static func region_for_prefix(prefix: String) -> String:
	return str(WORLDS.get(prefix, {}).get("region", ""))

static func region_for_quest(id: String) -> String:
	return str(QUESTS.get(id, {}).get("region", region_for_prefix(id.get_slice("_", 1))))

static func step_zone(id: String, step: Array) -> String:
	if step.size() > 6:
		return str(step[6].get("zone", QUESTS[id].zone))
	return str(QUESTS[id].get("completed_zone", QUESTS[id].zone) if step.is_empty() else QUESTS[id].zone)

static func person_location(id: String, quests) -> Dictionary:
	var person: Dictionary = PEOPLE[id]
	if id != "saga_maren":
		return {"zone":person.zone, "site":person.site}
	for index in range(1, 7):
		var quest_id := "side_escort_%02d" % index
		if quests.is_completed(quest_id):
			continue
		var quest: Dictionary = QUESTS[quest_id]
		for step: Array in quest.steps:
			if quests.is_objective_done(quest_id, str(step[0])):
				continue
			return {"zone":step_zone(quest_id, step), "site":"causeway" if quest_id == "side_escort_04" and quests.is_objective_done(quest_id, "cross_with_crew") else str(step[2]) if index == 6 else str(quest.site)}
	return {"zone":"greyfen", "site":"arrivals"}

static func quest_xp(id: String) -> int:
	if id.begins_with("side_escort_"):
		return 300
	return [300,350,250,300,500][clampi(int(id.right(2)) - 1, 0, 4)]

static func quest_definitions() -> Dictionary:
	var result := {}
	for id: String in QUESTS:
		var quest: Dictionary = QUESTS[id]
		var objectives: Array = []
		for step: Array in quest.steps:
			objectives.append({"id":step[0], "text":step[1], "kind":"choice" if str(step[3]) == "choice" else "work"})
		result[id] = {"title":quest.title, "type":"side", "description":opening(id), "objectives":objectives, "story_depth":"personal" if id.begins_with("side_escort_") else "regional", "saga_zone":quest.zone}
	return result

static func route(quest_id: String, objective_id: String, state) -> Dictionary:
	var quest: Dictionary = QUESTS.get(quest_id, {})
	for step: Array in quest.get("steps", []):
		if str(step[0]) != objective_id:
			continue
		var part := maxi(0, int(state.get_flag(quest_id + ":" + objective_id + ":part", 0))) if state != null else 0
		var site := part_site(quest_id, step, part, state)
		var target := quest_id + ":" + objective_id
		if str(step[3]) == "walk":
			var sites: Array = step[4].duplicate()
			if quest_id == "side_escort_02" and state != null and str(state.get_flag(quest_id + "_outcome", "")) == "work_line":
				sites = ["workers", "boundary", "blind"]
			site = str(sites[mini(part, sites.size() - 1)])
			target += ":walk"
		if str(step[3]) == "signal" and state != null and bool(state.get_flag(quest_id + ":signal_mode_set", false)):
			var returning := bool(state.get_flag(quest_id + ":left_work_area", false))
			site = "posts" if returning else "line"
			target += ":near" if returning else ":far"
		var targets: Array[String] = [target]
		if str(step[3]) == "inspect" and step[4].size() > 1:
			targets.clear()
			for index in range(step[4].size()):
				if state == null or not bool(state.get_flag(target + ":seen:" + str(index), false)):
					targets.append(target + ":inspect:" + str(index))
		var zone := step_zone(quest_id, step)
		return {"destination_zone":zone, "destination_name":zone.replace("_"," ").capitalize(), "target_ids":targets, "route_hint":str(step[1]) + " - " + site.replace("_"," "), "purpose":opening(quest_id), "next_action":step[1], "pinpoint":true}
	return {}
