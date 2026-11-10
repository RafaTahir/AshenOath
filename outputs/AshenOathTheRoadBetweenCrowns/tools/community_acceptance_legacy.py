"""Build a test-only adapter from the maintained real-input route helpers.

No game script is rewritten. The exact source and derived adapter are hashed by
the runner. Select a transitive helper closure instead of maintaining a second
copy of combat input logic. Current save labels, chapter insertions and rituals
are explicit overrides; none completes an objective or writes gameplay flags.
"""
import re

ROOTS = [
    "_run_opening", "_continue_teeth_in_rain", "_continue_names_they_burned",
    "_return_register_to_deep_wood", "_fight_rootbound_real_input", "_return_from_rootbound",
    "_prepare_for_ash_mill", "_travel_to_ash_mill", "_inspect_ash_millstones", "_fight_ashwing_real_input",
    "_travel_to_bandit_road", "_fight_senn_guard", "_travel_to_castle_approach", "_collect_castle_evidence",
    "_enter_record_hall", "_resolve_record_ledger", "_fight_record_haunting", "_confront_edric",
    "_enter_undercroft", "_break_halvern_guard", "_resolve_halvern_witness", "_travel_to_assembly",
    "_hear_assembly_witnesses", "_choose_assembly_testimony", "_travel_to_hart_glade", "_fight_hart_ending",
]

HEADER = '''extends RefCounted
const CemeterySection = preload("res://scripts/zones/cemetery_section.gd")
const DEADLINE_MS := 120000
var owner: SceneTree
var stabilize_route_bearing := true
var route_camera_yaw := 0.0
var expected_ash_supply_arrows := 20
var failures: Array[String]:
\tget: return owner.failures
var root: Window:
\tget: return owner.root
var process_frame: Signal:
\tget: return owner.process_frame
var physics_frame: Signal:
\tget: return owner.physics_frame
var paused: bool:
\tget: return owner.paused
func create_timer(seconds: float): return owner.create_timer(seconds)
'''

OVERRIDES = {
    "_fail": '''func _fail(message: String) -> void: owner._fail(message)\n''',
    "_key": '''func _key(key: Key, pressed: bool) -> void: owner._key(key,pressed)\n''',
    "_mouse_button": '''func _mouse_button(button: MouseButton, pressed: bool) -> void: owner._mouse_button(button,pressed)\n''',
    "_frames": '''func _frames(count: int) -> void: await owner._frames(count)\n''',
    "_finish": '''func _finish() -> void: owner._fail("Legacy helper requested early fixture completion")\n''',
    "_shutdown_game": '''func _shutdown_game(_game: Node) -> void: owner._fail("Legacy helper requested early world teardown")\n''',
    "_save_campaign_checkpoint": '''func _save_campaign_checkpoint(game: Node) -> Dictionary:
\towner.region=str(game.current_zone_id)
\tawait owner._release()
\tawait owner._tap(KEY_ESCAPE)
\tawait owner._button("Quick Save")
\tawait owner._frames(12)
\treturn game.save_manager._read_slot(game.save_manager.SAVE_PATH)
''',
    "_open_crow_chapel": '''func _open_crow_chapel(game: Node) -> void:
\towner.region=str(game.current_zone_id)
\tif not game.quests.is_objective_done("main_bell_beneath_greyfen","open_chapel"):
\t\tawait owner._interact("chapel_door")
\t\tawait owner._close_dialogue()
\tif not bool(game.story_state.get_flag("bell_eater_defeated",false)):
\t\tawait _fight_bell_eater_real_input(game)
\tawait owner._choose_outcome("crow_shrine_choice","crow_shrine_state","cleansed")
\towner._check(game.quests.is_completed("main_bell_beneath_greyfen"),"Bell chapter earned after its actual encounter")
''',
    "_choose_mill_record": '''func _choose_mill_record(game: Node) -> void:
\tawait owner._choose_outcome("miller_record","mill_operation","closed")
\tvar next := "main_empty_tables" if owner.expanded else "main_soldier_without_banner"
\towner._check(game.quests.is_completed("main_ash_at_the_mill") and game.quests.is_active(next),"Ash unlocks the correct revision's next chapter")
\tawait _save_campaign_checkpoint(game)
''',
    "_resolve_halvern_witness": '''func _resolve_halvern_witness(game: Node) -> void:
\tawait owner._choose_outcome("halvern","halvern_fate","witness")
\tvar next := "main_house_many_names" if owner.expanded else "main_crowns_without_mercy"
\towner._check(game.quests.is_completed("main_last_witness") and game.quests.is_active(next),"Last Witness unlocks the correct revision's next chapter")
\towner._check(str(game.story_state.get_flag("halvern_fate",""))=="witness","Halvern retains his authored voluntary outcome")
\tawait _save_campaign_checkpoint(game)
''',
    "_choose_focused_dialogue_action": '''func _choose_focused_dialogue_action(_game: Node, interaction_id: String, _action_prefix: String, _label: String) -> void:
\tif interaction_id=="edric_campaign":
\t\tvar outcome := "exposed" if OS.get_cmdline_user_args().has("--edric-exposed") else "compelled" if OS.get_cmdline_user_args().has("--edric-compelled") else "cooperate"
\t\tawait owner._choose_outcome(interaction_id,"edric_stance",outcome)
\telif interaction_id=="vargan_ledger_choice":
\t\tvar flag := "vargan_ledger_hidden" if OS.get_cmdline_user_args().has("--ledger-hidden") else "vargan_ledger_left_copied" if OS.get_cmdline_user_args().has("--ledger-copied") else "vargan_ledger_taken_openly"
\t\tawait owner._choose_outcome(interaction_id,flag,true)
\telse: _fail("Unreviewed authored action selector: "+interaction_id)
''',
    "_continue_wychwood_teeth": '''func _continue_wychwood_teeth(game: Node) -> void:
\tawait owner._interact("ritual_stones")
\tawait owner._close_dialogue()
\towner._check(game.quests.is_objective_done("main_teeth_in_rain","name_the_dead"),"Oren's name is spoken through the actual ritual stones")
\tawait owner._interact("saga_bog_challenge")
\tvar bog: Node3D
\tfor enemy in game.active_enemies:
\t\tif is_instance_valid(enemy) and str(enemy.enemy_id)=="bog_wretch" and not enemy.dead: bog=enemy; break
\tif bog==null:
\t\t_fail("Actual northern Wychwood invitation did not stage the Bog Wretch")
\t\treturn
\tawait _fight_bog_wretch(game,bog)
\tawait owner._choose_outcome("bog_core_choice","bog_core_fate","returned")
\towner._check(game.quests.is_completed("main_teeth_in_rain"),"The current Wychwood encounter and actual memory choice complete Teeth")
''',
    "_continue_names_they_burned": '''func _continue_names_they_burned(game: Node) -> void:
\tawait owner._travel("greyfen")
\tfor id in ["register_anwen","register_tor"]:
\t\tawait owner._interact(id)
\t\tawait owner._close_dialogue()
\tawait owner._travel("burned_farmstead")
\tawait owner._interact("register_rook")
\tawait owner._close_dialogue()
\towner._check(game.quests.is_objective_done("main_names_they_burned","reconstruct_register"),"Three actual register fragments reconstruct the account")
\tawait owner._travel("old_mill")
\tawait _save_campaign_checkpoint(game)
''',
    "_verify_rootbound_reload": '''func _verify_rootbound_reload(game: Node) -> void:
\towner._check(game.quests.is_objective_done("main_names_they_burned","reconstruct_register"),"Rootbound requires the actually reconstructed register")
\tif not bool(game.story_state.get_flag("rootbound_arena_entered",false)):
\t\tawait owner._interact("rootbound_challenge")
\towner._check(bool(game.story_state.get_flag("rootbound_arena_entered",false)),"Actual invitation opens the guardian's memory clearing")
''',
    "_choose_assembly_testimony": '''func _choose_assembly_testimony(game: Node) -> void:
\tawait owner._interact("witnesses_ready")
\tawait owner._close_dialogue()
\towner._check(game.quests.is_objective_done("main_crowns_without_mercy","gather_witnesses"),"Actual witness records complete the assembly preparation")
\tawait owner._choose_outcome("assembly_choice","confession_method","witnesses")
\towner._check(game.quests.is_completed("main_crowns_without_mercy") and game.quests.is_active("main_hart_remembers"),"Actual public testimony starts the finale")
\towner._check(str(game.story_state.get_flag("confession_method",""))=="witnesses","The assembly retains the chosen public account")
\tawait _save_campaign_checkpoint(game)
''',
    "_fight_senn_guard": '''func _fight_senn_guard(game: Node) -> void:
\towner._check(game.quests.is_active("main_soldier_without_banner"),"Senn confrontation belongs to the active Soldier chapter")
\tawait owner._interact("saga_senn_challenge")
\tvar enemy: Node3D
\tfor candidate in game.active_enemies:
\t\tif is_instance_valid(candidate) and str(candidate.enemy_id)=="captain_senn" and not candidate.dead: enemy=candidate; break
\tif enemy==null:
\t\t_fail("Actual Senn challenge did not stage the living captain")
\t\treturn
\tawait owner._tap(KEY_1)
\tvar deadline := Time.get_ticks_msec()+90000
\tvar last_attack := 0
\tvar last_potion := 0
\twhile Time.get_ticks_msec()<deadline and failures.is_empty():
\t\tif game.quests.is_objective_done("main_soldier_without_banner","senn_confrontation"):
\t\t\tawait owner._release()
\t\t\tawait owner._choose_outcome("captain_senn","senn_fate","testimony")
\t\t\towner._check(game.quests.is_completed("main_soldier_without_banner") and str(game.story_state.get_flag("senn_fate",""))=="testimony","Senn yields alive and receives his actual recorded outcome")
\t\t\tawait _save_campaign_checkpoint(game)
\t\t\treturn
\t\tif game.player.health_component.health<=0 or not is_instance_valid(enemy) or enemy.dead:
\t\t\t_fail("Senn encounter ended before the captain yielded alive")
\t\t\treturn
\t\tif game.camera_rig.get_locked_combat_target()!=enemy:
\t\t\tif game.camera_rig.get_locked_combat_target()!=null: await owner._tap(KEY_T)
\t\t\tawait owner._tap(KEY_T)
\t\t\tawait owner._frames(6)
\t\tvar now := Time.get_ticks_msec()
\t\tif game.player.health_component.health<65 and int(game.inventory.items.get("redroot_potion",0))>0 and now-last_potion>6000:
\t\t\tawait owner._tap(KEY_R); last_potion=now
\t\telif float(enemy.pending_attack_time)>0 and float(enemy.pending_attack_time)<game.player.get_parry_window_duration()*0.75:
\t\t\tawait owner._release()
\t\t\tawait owner._tap(KEY_Q)
\t\telse: last_attack=await _drive_contact_strike(game,enemy,last_attack,430)
\t\tawait owner._frames(3)
\t_fail("Actual Senn challenge exceeded its ninety-second deadline")
''',
}

OVERRIDES["_hear_assembly_witnesses"] = '''func _hear_assembly_witnesses(game: Node) -> void:
\tfor row: Array in [["witness_3","anwen"],["witness_-3","rook"],["witness_-7","mira"]]:
\t\tvar actor := game.zone_root.find_child(str(row[0]),true,false) as Node3D
\t\tvar willing := str(game.story_state.get_flag("witness_consent_"+str(row[1]),""))=="voluntary"
\t\tif not willing:
\t\t\towner._check(actor==null or not actor.is_visible_in_tree(),"Absent or refusing witness is never staged as willing: "+str(row[1]))
\t\t\tcontinue
\t\towner._check(actor!=null and actor.is_visible_in_tree() and not actor.find_children("*","Skeleton3D",true,false).is_empty(),"Willing assembly witness retains native body: "+str(row[1]))
\t\tawait owner._interact(str(row[0]))
\t\tawait owner._close_dialogue()
\tawait owner._interact("witness_7")
\tawait owner._close_dialogue()
'''

# The maintained topology no longer has a direct Undercroft/Assembly door.
# All travel overrides use the game's current allowed graph and actual walking
# or E on the actual door; they never request a zone through a private method.
for _method, _destination in {
    "_return_register_from_farmstead": "old_mill", "_return_register_to_deep_wood": "deep_wood",
    "_travel_to_ash_mill": "old_mill", "_travel_to_bandit_road": "bandit_road",
    "_travel_to_castle_approach": "vargan_approach", "_enter_record_hall": "record_hall",
    "_enter_undercroft": "undercroft", "_travel_to_assembly": "assembly", "_travel_to_hart_glade": "hart_glade",
}.items():
    OVERRIDES[_method] = f'''func {_method}(game: Node) -> void:
\tawait owner._travel("{_destination}")
\tawait _save_campaign_checkpoint(game)
'''

OVERRIDES["_return_from_rootbound"] = '''func _return_from_rootbound(game: Node) -> void:
\tawait owner._travel("greyfen")
\tawait owner._choose_outcome("names_decision","names_policy","published")
\towner._check(game.quests.is_completed("main_names_they_burned"),"All recovered register evidence leads to the actual Names choice")
'''


def functions(source: str) -> dict[str, str]:
    result = {}
    for block in re.split(r"(?m)(?=^func )", source):
        if block.startswith("func "):
            name = re.match(r"func (\w+)\(", block).group(1)
            if name in result:
                raise ValueError(f"duplicate input helper: {name}")
            result[name] = block
    return result


TOUCH_KEYS = {"KEY_W", "KEY_A", "KEY_S", "KEY_D", "KEY_SHIFT", "KEY_Q", "KEY_C", "KEY_E",
              "KEY_ENTER", "KEY_ESCAPE", "KEY_1", "KEY_2", "KEY_R", "KEY_F", "KEY_T"}


def validate_touch_adapter(adapter: str) -> None:
    """Fail closed on direct injection or any key without a reviewed screen path."""
    if "const ACCEPTANCE_INPUT_MODE := \"touch\"" not in adapter:
        raise ValueError("generated touch adapter lacks its explicit input contract")
    for pattern in [r"\bInput(?:Event\w*|\.)", r"\bowner\._(?:key|mouse_button)\(",
                    r"\.call\(\s*[\"'](?:_input|_unhandled_input)[\"']",
                    r"\.(?:_input|_unhandled_input|grab_focus|set_virtual_axes|request_virtual_action|add_touch_look_delta)\(",
                    r"\.(?:pressed|button_down|button_up)\.emit\(", r"\.(?:scroll_vertical|scroll_horizontal)\s*="]:
        if re.search(pattern, adapter, re.MULTILINE):
            raise ValueError(f"touch helper bypasses its screen-only owner: {pattern}")
    for line in adapter.splitlines():
        if not line.startswith("func ") and re.search(r"(?<![\w.])(?<!await )_(?:key|mouse_button)\(", line):
            raise ValueError("touch helper did not await a screen action")
    unknown = set(re.findall(r"\bKEY_[A-Z0-9_]+\b", adapter)) - TOUCH_KEYS
    if unknown:
        raise ValueError(f"touch helper has unmapped keys: {sorted(unknown)}")


def touch_blocks(blocks: dict[str, str]) -> None:
    previously_async = {name for name, block in blocks.items() if re.search(r"\bawait\b", block)}
    blocks["_key"] = 'func _key(key: Key, pressed: bool) -> void: await owner._touch_key(key,pressed)\n'
    blocks["_mouse_button"] = 'func _mouse_button(button: MouseButton, pressed: bool) -> void: await owner._touch_mouse(button,pressed)\n'
    blocks["_focus_vendor_button"] = '''func _focus_vendor_button(label_prefix: String, _backwards: bool = false) -> bool:
\t# Select an actual visible row for the subsequent screen tap; never move GUI focus.
\treturn owner._touch_vendor_target(label_prefix)
'''
    for name, yaw, direction in [("_turn_camera_north", "0.0", "FORWARD"), ("_turn_camera_south", "PI", "BACK")]:
        blocks[name] = f'''func {name}(game: Node) -> void:
\troute_camera_yaw = {yaw}
\tawait owner._face(game.player.global_position+Vector3.{direction}*5.0)
\towner._check(absf(angle_difference(float(game.camera_rig.yaw),route_camera_yaw))<0.06,"Screen swipes restore the route bearing")
'''
    original = '''\t\tif stabilize_route_bearing:
\t\t\tvar bearing_error := wrapf(float(game.camera_rig.yaw) - route_camera_yaw, -PI, PI)
\t\t\t_key(KEY_RIGHT, bearing_error > 0.04)
\t\t\t_key(KEY_LEFT, bearing_error < -0.04)
\tif stabilize_route_bearing:
\t\t_key(KEY_RIGHT, false)
\t\t_key(KEY_LEFT, false)
'''
    if blocks["_move_until"].count(original) != 1:
        raise ValueError("maintained movement bearing changed; review its screen adaptation")
    blocks["_move_until"] = blocks["_move_until"].replace(original, '''\t\tif stabilize_route_bearing and absf(angle_difference(float(game.camera_rig.yaw),route_camera_yaw))>0.04:
\t\t\tvar forward := Vector3(-sin(route_camera_yaw),0,-cos(route_camera_yaw))
\t\t\tawait owner._face(game.player.global_position+forward*5.0)
''')
    # Discrete More actions must finish before the combat helper proceeds.
    # Rewrite calls only, retaining the maintained route geometry and assertions.
    for name, block in list(blocks.items()):
        blocks[name] = "\n".join(line if line.startswith("func ") else
            re.sub(r"(?<![\w.])(?<!await )(_(?:key|mouse_button)\()", r"await \1", line)
            for line in block.split("\n"))
    # Holding/releasing movement was synchronous in the keyboard route. A
    # helper which now awaits a screen action becomes a coroutine too; carry
    # that ownership through every caller, not only the direct input helpers.
    propagated = set()
    while True:
        introduced = {name for name, block in blocks.items() if re.search(r"\bawait\b", block)} - previously_async - propagated
        if not introduced:
            break
        pattern = r"(?<![\w.])(?<!await )(" + "|".join(re.escape(name) for name in sorted(introduced)) + r")\("
        for name, block in list(blocks.items()):
            blocks[name] = "\n".join(line if line.startswith("func ") else
                re.sub(pattern, r"await \1(", line) for line in block.split("\n"))
        propagated.update(introduced)


def build_adapter(source: str, input_mode: str = "keyboard_mouse") -> tuple[str, list[str]]:
    if input_mode not in ("keyboard_mouse", "touch"):
        raise ValueError("unsupported legacy adapter input mode")
    # The untouched source bytes are separately frozen by the runner. Parse
    # Windows and LF checkouts identically without changing that provenance.
    source = source.replace("\r\n", "\n")
    blocks = functions(source)
    initializer = blocks.get("_initialize", "")
    marker = '\t\tprint("REAL_INPUT menu_to_greyfen=PASS'
    if initializer.count(marker) != 1:
        raise ValueError("maintained opening helper changed; review its extraction boundary")
    opening = initializer[initializer.index(marker):].split("\n\tawait _shutdown_game(game)", 1)
    if len(opening) != 2:
        raise ValueError("maintained opening helper has no unique shutdown boundary")
    body = "\n".join(line[1:] if line.startswith("\t") else line for line in opening[0].splitlines())
    blocks.update(OVERRIDES)
    blocks["_run_opening"] = "func _run_opening(game: Node) -> void:\n\tvar anwen_only := false\n\tvar wychwood_only := false\n" + body + "\n"
    if input_mode == "touch":
        touch_blocks(blocks)
    required = set()
    pending = list(ROOTS)
    while pending:
        name = pending.pop()
        if name in required:
            continue
        if name not in blocks:
            raise ValueError(f"missing maintained input helper: {name}")
        required.add(name)
        pending.extend(set(re.findall(r"(?<![\w.])(_\w+)\(", blocks[name])) - required)
    selected = "\n\n".join(blocks[name].rstrip() for name in sorted(required)) + "\n"
    header = HEADER
    if not re.search(r"\bCemeterySection\b", selected):
        header = header.replace('const CemeterySection = preload("res://scripts/zones/cemetery_section.gd")\n', '')
    adapter = header + f'const ACCEPTANCE_INPUT_MODE := "{input_mode}"\n' + selected
    # Older optional visual checks named a machine-local output. Retain their
    # image operation but keep every write under this runner's isolated user://.
    adapter = re.sub(r'save_png\("D:/Temp/AshenOath/([^/"\\]+)"', r'save_png("user://\1"', adapter)
    for forbidden in [r"\.(?:set_flag|complete_objective|complete_choice|add_item|add_reward|heal|restore|reset_for_journey_restore|set_meta|set)\(",
                      r"\.(?:global_position|position|rotation|global_rotation|transform|global_transform|yaw|pitch|health|stamina|can_control)(?:\.[xyzw])?\s*(?:[+*/-]?=)(?!=)",
                      r"\bgame\.(?:story_state|quests|inventory|progression|save_manager)(?:\.\w+|\[[^\]\n]*\])*\s*[+*/-]?=(?!=)",
                      r"\.(?:load_state|load_game|save_game|load_save_state|request_load|_write_atomic|_load_zone|_handle_interaction|_apply_mouse_motion)\(",
                      r"\b(?:DisplayServer\.(?:window_move_to_foreground|mouse_set_mode|mouse_warp)|Input\.warp_mouse)\(",
                      r"\b(?:game|player|boss|enemy)(?:\.\w+)*\.call\((?!\"_interaction_target_valid\")"]:
        if re.search(forbidden, adapter):
            raise ValueError(f"input adapter acquired a gameplay shortcut: {forbidden}")
    if re.search(r'save_png\("[A-Za-z]:', adapter):
        raise ValueError("selected input helper writes outside the disposable profile")
    if input_mode == "touch":
        validate_touch_adapter(adapter)
    return adapter, sorted(required)
