extends RefCounted

const ID := "saga_var_q03"
const TITLE := "Three Marks at the Garden Gate"
const HOOK := "Toma petitions for three seasonal garden workers. Their tools and release cannot be made conditional on another season’s work."
const STEPS := [
	["read_release","Compare the three workers’ release and the tool tags","garden","inspect",["Three marks on Toma’s petition","The expired bond at the tool locker"],"Two advances were charged twice. One expired bond is still holding a tool."],
	["recover_tools","Release the marked tools to their owners","locker","work",["Present the release","Collect the three marked tools"],"The tools belong to the workers. Getting them back requires no new pledge."],
	["choose_garden","Hear what work the freed hands choose","garden","choice",{"departed":"Arrange passage for the workers who want to leave","voluntary_work":"Offer the paid cart shift with a right to leave"},"Toma checks each answer. Two want the road home. The other wants to see the wage and stopping time before deciding."],
	["settle_bed","Bring the tools and planting tray to the collection point","locker","carry",["The released tray and tools","garden"],"The property is available at the garden gate. Its owners can take it in either direction."],
	["acknowledge_choice","Receive the departing workers’ acknowledgement","garden","talk",[],"The petition carries three marks and a release. Toma keeps the receipt. Nobody has signed on for life."]
]

static func active(id: String, state: Node) -> bool:
	return id==ID and state!=null and state.get_flag("novel_edition",0)==1

static func row(original: Dictionary) -> Dictionary:
	return original.merged({"title":TITLE,"hook":HOOK,"steps":STEPS,"needs_garden_petition":true},true)

static func project(definitions: Dictionary) -> void:
	if not definitions.has(ID): return
	var def: Dictionary = definitions[ID]
	def.title=TITLE
	def.description=HOOK
	for i in mini(STEPS.size(), def.objectives.size()): def.objectives[i].text=STEPS[i][1]

static func aftermath(outcome: String) -> String:
	if outcome=="voluntary_work": return "Two seasonal hands leave with their tools. The third takes a paid cart shift and knows when it ends. Toma’s petition and the receipt stay on file."
	if outcome=="departed": return "The released tools have gone home with their owners. Toma leaves his copy of the three-mark petition at the locker and returns to Pell."
	return "The release has been filed. The surviving copy leaves the workers’ later choices open."
