extends RefCounted

static func resolve(ending: String, state) -> Array[String]:
	var cards: Array[String] = [_covenant_card(ending), _greyfen_card(state), _anwen_card(state), _vargan_card(state)]
	for actor in ["elna", "tor", "mira", "rook", "toma", "senn", "memorials", "mill"]:
		var card := _person_card(actor, state)
		if card != "":
			cards.append(card)
	return cards

static func _flag(state, key: String, fallback: String = "") -> String:
	return str(state.get_flag(key, fallback))

static func _covenant_card(ending: String) -> String:
	match ending:
		"kill":
			return "ASH\nThe Hart dies. The pressure beneath the road ends, and Greyfen sleeps without waiting for another summons. The complete memory dies with its witness; the human records Kael recovered remain. In the wood, pale shoots fail to return. The living must decide what repair means without the dead to answer them."
		"free":
			return "MERCY\nKael dismantles the binding and releases the Hart. The recovered record survives, but intimate memories and vulnerable families are not offered for public display. Proven wrongdoing stays on the record. Keeping it safe becomes human work: visits, copies, and a promise to ask before speaking for another person."
		"bind":
			return "DUTY\nKael takes stewardship of the binding upon himself. Greyfen has time to mend its roofs and feed its children. The obligation follows him beyond the glade; no villager inherits it merely by living there. He has contained the danger, not settled the debt. Each season brings another reason to return."
		_:
			return "WITNESS\nThe public record can no longer be buried. Names replace the village's comfortable account of its founding. Restitution costs iron, food, labor, and the authority of people who once decided what could be known. Kael keeps the account alive; willing witnesses may share that work, but no refusal is turned into agreement."

static func _greyfen_card(state) -> String:
	var public_names := _flag(state, "names_policy") == "published"
	var method := _flag(state, "confession_method")
	var account := "The recovered names are kept in a protected record. Families decide which private details may be shared."
	if public_names:
		account = "The refugee names enter the village record. A public name does not make every family memory public property."
	if method == "edric":
		account += " Edric's compelled confession is entered as a compelled account; the ledger must still bear its own weight."
	elif method == "witnesses":
		account += " Those who freely chose to speak are named as witnesses. The others are allowed to remain silent."
	else:
		account += " Kael answers for the account he presents, without claiming to speak for everyone."
	return "GREYFEN\n" + account

static func _anwen_card(state) -> String:
	var shrine := _flag(state, "crow_shrine_state")
	var remedy: String = {"cleansed":"She tends the unbound shrine without asking it to hide the road again.", "disturbed":"She works among the disturbed stones, separating what can be repaired from what must remain visible.", "bound":"She marks the limits of the surviving rite and refuses to treat it as absolution."}.get(shrine, "She keeps the shrine record open; what was never decided is left unresolved.")
	return "SISTER ANWEN\nAnwen's care does not undo her concealment. " + remedy + " " + _participation(state, "anwen")

static func _vargan_card(state) -> String:
	var stance := _flag(state, "edric_stance")
	var edric: String = {"cooperate":"Edric surrenders the command record to guarded custody. Cooperation buys him no ownership over a family's silence.", "exposed":"Edric's title no longer shelters the proven orders. He must answer for them before people he once excluded.", "compelled":"Edric speaks under compulsion. His words cannot replace corroboration or become a willing pledge."}.get(stance, "The recovered orders remain evidence even where Edric's own account is absent.")
	var halvern := _flag(state, "halvern_fate")
	var knight: String = {"witness":"Halvern's bounded memory of refusal is preserved beside the orders it contradicts.", "released":"Halvern is released from his repetition; the account recovered before his departure remains.", "release":"Halvern is released from his repetition; the recovered account remains.", "destroyed":"Halvern's remaining memory is lost. No later account can pretend that he agreed to its use.", "defeated":"The knight's guard was broken. Without a recorded final decision, his release or consent is not assumed."}.get(halvern, "Halvern's fate remains unrecorded; the gaps in his account are not filled with certainty.")
	return "HOUSE VARGAN\n" + edric + " " + knight

static func _participation(state, actor: String) -> String:
	match _flag(state, "witness_consent_" + actor):
		"voluntary": return "The account is shared by choice."
		"protected": return "The account is shared under agreed protection; identifying details remain guarded."
		"compelled": return "The account was compelled and is not treated as consent."
		"refused": return "Public participation was declined. The refusal is respected."
		"unavailable": return "Surviving records establish facts without inventing the absent person's consent."
		_: return "No voluntary public pledge is recorded."

static func _person_card(actor: String, state) -> String:
	match actor:
		"elna":
			var outcome := _flag(state, "widow_truth")
			if outcome == "": return ""
			var body: String = {"told":"Elna learns what Harl did at the gate. She keeps a memory of the man she loved beside the account of the harm he helped cause.", "comforted":"Elna receives the gentler account Kael chose. Its silence remains his responsibility; grief does not turn an omission into truth.", "private":"Elna hears the recovered memory in private. The proof of the gate stays on record; her grief is not offered as a public performance.", "token":"Elna hears the recovered memory without Kael arranging its answer. She decides what to carry home."}.get(outcome, "Elna keeps the bell and decides how its story belongs in her own life.")
			return "ELNA\n" + body + " " + _participation(state, "elna")
		"tor":
			var outcome := _flag(state, "iron_fate")
			if outcome == "": return ""
			return "TOR\n" + str({"memorial":"Tor begins replacement work and stamps recovered names into the old iron. Useful tools are replaced before their material is taken away.", "tools":"Tor keeps the tools in use and names their origin. Repairing a hinge is now part of restitution, not an excuse to forget.", "surrendered":"Tor relinquishes control of the inherited stock. Village hands share the work; a reserve of ordinary arrows remains available.", "weapon":"The old iron becomes a weapon. Tor cannot claim that an edge settles what was taken from its first owners."}.get(outcome, "Tor's chosen use of the iron remains on record.")) + " " + _participation(state, "tor")
		"mira":
			var outcome := _flag(state, "mira_truth")
			if outcome == "": return ""
			return "MIRA\n" + str({"kept":"Mira continues the private treatment. Patients recover, but Kael has left them without the knowledge needed to consent.", "confessed":"Mira labels the treatment's origin and asks patients before using it. A refusal sends her to the slower replacement remedy; care continues.", "destroyed":"The ash-fed bed is destroyed. Mira turns to replacement medicine and borrowed supplies. Treatment takes more work, and the patients are not abandoned."}.get(outcome, "Mira keeps the treatment decision on record and continues caring for the sick.")) + " " + _participation(state, "mira")
		"rook":
			var outcome := _flag(state, "rook_disclosure", _flag(state, "rook_map_fate"))
			if outcome == "": return ""
			return "ROOK\n" + str({"protected":"Rook's corrected road survives with identifying details guarded. His family's story is useful without becoming everybody's possession.", "public":"The corrected road is copied into the public record. Rook's separately recorded agreement determines whether his family is named.", "preserved":"Rook keeps the older road beside the false marker. The map proves where people were sent without settling who may name his family.", "destroyed":"The map is destroyed. Rook remembers the route alone, and Kael cannot promise that the lost copy will protect everyone.", "erased":"The copy is destroyed to protect its holders. The route becomes harder to prove; Rook's memory is not a replacement archive."}.get(outcome, "Rook retains a say in how the surviving road is told.")) + " " + _participation(state, "rook")
		"toma":
			var outcome := _flag(state, "guardian_plan", _flag(state, "black_dog_fate"))
			if outcome == "": return ""
			return "TOMA\n" + str({"spared":"The guardian remains under Toma's care. The family it protected is safe for now; watching the fold becomes a duty shared with their neighbors.", "supervised":"Toma keeps the guardian under a shared watch. His neighbors know the risk and help keep the fold separate from its patrol.", "hidden":"Toma keeps the guardian in secret. The easier story calms Greyfen, but leaves him answering alone if the arrangement fails.", "relocated":"Toma helps move the guardian away from the fold. He loses its protection and knows where his children may safely walk.", "killed":"The creature will never threaten the fold again. Toma also loses the guide that brought his daughter home."}.get(outcome, "Toma lives with the remedy chosen for the fold."))
		"senn":
			var outcome := _flag(state, "senn_fate")
			if outcome == "": return ""
			var deserters := _flag(state, "bannerless_fate")
			var coda := str({"testimony":" The deserters' signed refusal remains beside his account; signing does not erase either man's responsibility.", "assembly":" The deserters' refusal enters the assembly record even if Senn is absent.", "shielded":" The signed refusal is preserved with homes and identifying details protected.", "protected":" The deserters' families remain protected while their refusal is preserved."}.get(deserters, ""))
			return "SENN\n" + str({"testimony":"Senn signs the account of the order he obeyed. The signature establishes responsibility; it does not pardon the men who suffered under him.", "exile":"Senn leaves his banner and goes. Exile ends his command here, while the recovered refusal of his soldiers remains evidence.", "punished":"Senn pays the punishment Kael chose. The road still needs protection, and his followers still need to answer for their own acts."}.get(outcome, "Senn's fate is recorded without making his account the whole truth.")) + " " + _participation(state, "senn") + coda
		"memorials":
			var body := ""
			if bool(state.get_flag("oren_charm_returned", false)):
				body += "Oren's thread rests at a named grave. Someone can now come there to remember a child, rather than an absence. "
			if bool(state.get_flag("three_candles_lit", false)):
				body += "Bram, Sella, and Oren have three lights along the cemetery road. Keeping them lit is a small task the living can continue."
			var returned := _flag(state, "returned_soldier_fate")
			if returned == "named":
				body += " The returned soldier receives a name and a place to rest. His memory is kept without turning his family into an exhibit."
			elif returned == "anonymous":
				body += " The returned soldier rests without a public name. Kael records the omission rather than pretending the grave has answered."
			return "THE SMALL MEMORIALS\n" + body if body != "" else ""
		"mill":
			var operation := _flag(state, "mill_operation")
			if operation == "": return ""
			return "THE MILL\n" + str({"closed":"The harmful mill stops. Food arrives through a slower relief route; nobody calls the extra labor a cure for the ash already spread.", "supervised":"The mill works under named oversight. Supplies continue, and the recovered measure stays available to the people whose fields were harmed.", "restitution":"The mill's labor and stock help repair the harm. A ledger records who receives aid and what remains owed."}.get(operation, "The village keeps its food decision on record without destroying the evidence."))
	return ""
