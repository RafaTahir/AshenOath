extends RefCounted
const DEVICE_KEYBOARD_MOUSE := "keyboard_mouse"
const DEVICE_GAMEPAD := "gamepad"
const DEVICE_TOUCH := "touch"

const CONTEXT_MENU := "menu"
const CONTEXT_GAMEPLAY := "gameplay"
const CONTEXT_PAUSE := "pause"
const CONTEXT_DIALOGUE := "dialogue"
const CONTEXT_JOURNAL := "journal"
const CONTEXT_SETTINGS := "settings"
const CONTEXT_CONTROLS := "controls"
const CONTEXT_REMAP := "remap"
const CONTEXT_MINIGAME := "minigame"
const CONTEXT_DEATH := "death"
const CONTEXT_TRANSITION := "transition"
const UI_CONTEXTS := [
	CONTEXT_MENU, CONTEXT_PAUSE, CONTEXT_DIALOGUE, CONTEXT_JOURNAL,
	CONTEXT_SETTINGS, CONTEXT_CONTROLS, CONTEXT_REMAP, CONTEXT_MINIGAME,
	CONTEXT_DEATH, CONTEXT_TRANSITION,
]

const KEYBOARD_BINDINGS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"run": KEY_SHIFT,
	"dodge": KEY_SPACE,
	"jump": KEY_X,
	"block": KEY_Q,
	"interact": KEY_E,
	"use_potion": KEY_R,
	"throw_bomb": KEY_F,
	"oathfire_beam": KEY_C,
	"open_inventory": KEY_TAB,
	"pause": KEY_ESCAPE,
	"camera_left": KEY_LEFT,
	"camera_right": KEY_RIGHT,
	"camera_up": KEY_UP,
	"camera_down": KEY_DOWN,
	"camera_zoom_in": KEY_PAGEUP,
	"camera_zoom_out": KEY_PAGEDOWN,
	"target_lock": KEY_T,
	"target_next": KEY_Y,
	"target_previous": KEY_U,
	"weapon_sword": KEY_1,
	"weapon_bow": KEY_2,
	"weapon_oathblade": KEY_3,
	"weapon_sheath": KEY_H,
	"companion_command": KEY_V,
	"cycle_arrow": KEY_Z,
}

const MOUSE_BINDINGS := {
	"light_attack": MOUSE_BUTTON_LEFT,
	"heavy_attack": MOUSE_BUTTON_RIGHT,
	"aim_bow": MOUSE_BUTTON_RIGHT,
	"fire_bow": MOUSE_BUTTON_LEFT,
}

const GAMEPAD_BUTTON_BINDINGS := {
	"interact": JOY_BUTTON_A,
	"dodge": JOY_BUTTON_B,
	"jump": JOY_BUTTON_Y,
	"run": JOY_BUTTON_LEFT_STICK,
	"block": JOY_BUTTON_LEFT_SHOULDER,
	"light_attack": JOY_BUTTON_RIGHT_SHOULDER,
	"use_potion": JOY_BUTTON_DPAD_LEFT,
	"throw_bomb": JOY_BUTTON_DPAD_RIGHT,
	"open_inventory": JOY_BUTTON_BACK,
	"pause": JOY_BUTTON_START,
	"target_lock": JOY_BUTTON_RIGHT_STICK,
	"weapon_cycle": JOY_BUTTON_X,
	"cycle_arrow": JOY_BUTTON_DPAD_UP,
	"companion_command": JOY_BUTTON_DPAD_DOWN,
}

const GAMEPAD_AXIS_BINDINGS := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"camera_left": [JOY_AXIS_RIGHT_X, -1.0],
	"camera_right": [JOY_AXIS_RIGHT_X, 1.0],
	"camera_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"camera_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"oathfire_beam": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"heavy_attack": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"aim_bow": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"fire_bow": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	# These semantic actions share the right stick with camera look. The
	# camera consumes them only while a target is locked, so free look remains
	# unchanged and target switching is still discoverable/remappable.
	"target_previous": [JOY_AXIS_RIGHT_X, -1.0],
	"target_next": [JOY_AXIS_RIGHT_X, 1.0],
}

const KEYBOARD_LABELS := {
	"interact": "E",
	"dodge": "Space",
	"jump": "X",
	"run": "Shift",
	"block": "Q",
	"light_attack": "Left Mouse",
	"heavy_attack": "Right Mouse",
	"oathfire_beam": "C",
	"use_potion": "R",
	"throw_bomb": "F",
	"open_inventory": "Tab",
	"pause": "Esc",
	"camera_zoom_in": "Page Up",
	"camera_zoom_out": "Page Down",
	"target_lock": "T",
	"target_next": "Y",
	"target_previous": "U",
	"weapon_sword": "1",
	"weapon_bow": "2",
	"weapon_oathblade": "3",
	"weapon_sheath": "H",
	"companion_command": "V",
	"cycle_arrow": "Z",
}

const GAMEPAD_LABELS := {
	"interact": "A",
	"dodge": "B",
	"jump": "Y",
	"run": "L3",
	"block": "LB",
	"light_attack": "RB",
	"heavy_attack": "RT",
	"oathfire_beam": "LT",
	"use_potion": "D-Pad Left",
	"throw_bomb": "D-Pad Right",
	"open_inventory": "View",
	"pause": "Menu",
	"camera_zoom_in": "D-Pad Up",
	"camera_zoom_out": "D-Pad Down",
	"target_lock": "R3",
	"target_next": "Right Stick Left/Right",
	"target_previous": "Right Stick Left/Right",
	"weapon_cycle": "X",
	"weapon_sword": "Unbound",
	"weapon_bow": "Unbound",
	"weapon_oathblade": "Unbound",
	"weapon_sheath": "Unbound",
	"companion_command": "D-Pad Down",
	"cycle_arrow": "D-Pad Up",
}

const TOUCH_LABELS := {
	"interact": "Use",
	"dodge": "Dodge",
	"jump": "Jump",
	"run": "Stick",
	"block": "Guard",
	"light_attack": "Strike",
	"heavy_attack": "Heavy",
	"oathfire_beam": "Oath",
	"use_potion": "Remedy",
	"throw_bomb": "Tool",
	"open_inventory": "Journal",
	"pause": "Pause",
	"camera_zoom_in": "Zoom In",
	"camera_zoom_out": "Zoom Out",
	"aim_bow": "Aim",
	"fire_bow": "Fire",
	"cycle_arrow": "Arrows",
	"target_lock": "Lock",
	"target_next": "Next Target",
	"target_previous": "Previous Target",
	"weapon_sword": "Steel",
	"weapon_oathblade": "Oathblade",
	"weapon_bow": "Bow",
	"weapon_sheath": "Draw / Sheathe",
	"companion_command": "Bracken",
}
