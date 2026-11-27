extends RefCounted

## Keep first-hand marks, Tor's material identification and the later archive
## comparison separate. Stable evidence IDs remain usable in both editions.
const FIRST_READ := {
	"claw_marks":"Two flat loops of blackened binding wire. Someone bent them with a tool.",
	"black_feathers":"Red thread around the feathers. Grey burial thread crosses it. The two knots are different.",
	"oren_token":"A crow painted in cart black on brass. A bare patch makes the eye. Under the paint you can make out AVEL."
}

static func field_note(state, id: String, older: String) -> String:
	if state.get_flag("novel_edition",0) != 1: return older
	return str(FIRST_READ.get(id,older))

static func detail(state, id: String, original: Dictionary) -> Dictionary:
	if state == null or state.get_flag("novel_edition",0) != 1 or id not in ["vargan_wire","oren","sella"]: return original
	var entry := original.duplicate(true)
	var reading := ""
	match id:
		"vargan_wire":
			entry.source = "Two flat loops at the broken cart"
			reading = "The site establishes how the wrap was made. The buyer is unknown."
			if state.has_evidence("novel:two_pass"): reading = "Tor identified the two-pass fastening. He could not name its buyer."
			if state.has_evidence("novel:archive_wire"): reading = "The flattened wire matches the supply coil beside the castle warrants. This supports later intervention at the cart."
		"oren":
			entry.source = "Oren’s painted brass crow"
			reading = "An older name lies under the paint. The token alone cannot say where the child went."
			if state.get_flag("novel_oren_found",false): reading = "Oren was found beneath the willow. Kael has the matching shoes and the place where he was carried ashore."
		"sella":
			entry.source = "Two threads from the cart"
			reading = "The red and grey knots were tied at different times."
			if state.get_flag("novel_anwen_admitted",false): reading = "Anwen acknowledged wrapping the grey thread over Sella’s red cord."
	entry.sections = [{"id":"record","kind":"observation","title":"At the cart","body":FIRST_READ[{"vargan_wire":"claw_marks","oren":"oren_token","sella":"black_feathers"}[id]]},{"id":"reading","kind":"interpretation","title":"What the evidence supports","body":reading}]
	return entry
