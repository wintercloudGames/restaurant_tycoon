extends Node
## Every input action in the game, for keyboard + mouse AND controllers, plus which one the
## player used last (so on-screen prompts can show the right button icons).
##
## The actions are registered in code (below) so they are all in one place. To change a
## binding, edit BINDINGS. Mouse buttons for clicking/placing are still read directly where they
## are used (player.gd, build_mode.gd), because they depend on the mouse being locked.
##
## Controller layout (Xbox names; PlayStation: A=Cross, B=Circle, X=Square, Y=Triangle):
##   Left stick  move              Right stick  look
##   A           interact / cook   B            cancel / back
##   Y           shop              View/Back    build mode
##   Menu/Start  pause             D-pad        assemble arrows, chop left/right
##   Build mode: A place / pick up, X sell / cancel, Y rotate, LB / RB previous / next item, B leave
##   Shop: LB / RB switch tabs, B close

signal device_changed(using_controller: bool)

const ICON_ROOT := "res://assets/input/"

# action: [deadzone, keys..., joypad buttons (JOY_BUTTON_*) as "b<n>", joypad axes as "a<axis>:<sign>", mouse as "m<n>"]
const BINDINGS := {
	"move_forward": [0.2, KEY_W, "a1:-1"],
	"move_back": [0.2, KEY_S, "a1:1"],
	"move_left": [0.2, KEY_A, "a0:-1"],
	"move_right": [0.2, KEY_D, "a0:1"],
	"look_left": [0.15, KEY_LEFT, "a2:-1"],
	"look_right": [0.15, KEY_RIGHT, "a2:1"],
	"look_up": [0.15, KEY_UP, "a3:-1"],
	"look_down": [0.15, KEY_DOWN, "a3:1"],
	"interact": [0.5, KEY_E, "b0"],
	"shop": [0.5, KEY_B, "b3"],
	"build": [0.5, KEY_V, "b4"],
	"pause": [0.5, KEY_P, "b6"],
	"cancel": [0.5, KEY_ESCAPE, "b1"],
	# Minigames
	"cook_press": [0.5, KEY_SPACE, KEY_E, "m1", "b0", "a5:1"],
	"dir_up": [0.6, KEY_UP, KEY_W, "b11", "a1:-1"],
	"dir_down": [0.6, KEY_DOWN, KEY_S, "b12", "a1:1"],
	"dir_left": [0.6, KEY_LEFT, KEY_A, "b13", "a0:-1"],
	"dir_right": [0.6, KEY_RIGHT, KEY_D, "b14", "a0:1"],
	# Build mode (controller; the mouse buttons and wheel are read in build_mode.gd)
	"build_place": [0.5, "b0"],
	"build_sell": [0.5, "b2"],
	"build_rotate": [0.5, KEY_R, "b3"],
	"build_prev": [0.5, "b9"],
	"build_next": [0.5, "b10"],
	# Shop tabs
	"tab_prev": [0.5, KEY_Q, "b9"],
	"tab_next": [0.5, KEY_TAB, "b10"],
}

# action -> [keyboard icon, Xbox icon, PlayStation icon] (file names inside assets/input)
const ICONS := {
	"interact": ["Keyboard & Mouse/Default/keyboard_e.png", "Xbox Series/Default/xbox_button_color_a.png", "PlayStation Series/Default/playstation_button_color_cross.png"],
	"cook_press": ["Keyboard & Mouse/Default/keyboard_space.png", "Xbox Series/Default/xbox_button_color_a.png", "PlayStation Series/Default/playstation_button_color_cross.png"],
	"cancel": ["Keyboard & Mouse/Default/keyboard_escape.png", "Xbox Series/Default/xbox_button_color_b.png", "PlayStation Series/Default/playstation_button_color_circle.png"],
	"shop": ["Keyboard & Mouse/Default/keyboard_b.png", "Xbox Series/Default/xbox_button_color_y.png", "PlayStation Series/Default/playstation_button_color_triangle.png"],
	"build": ["Keyboard & Mouse/Default/keyboard_v.png", "Xbox Series/Default/xbox_button_view.png", "PlayStation Series/Default/playstation5_button_create.png"],
	"pause": ["Keyboard & Mouse/Default/keyboard_p.png", "Xbox Series/Default/xbox_button_menu.png", "PlayStation Series/Default/playstation5_button_options.png"],
	"move": ["Keyboard & Mouse/Default/keyboard_w.png", "Xbox Series/Default/xbox_stick_l.png", "PlayStation Series/Default/playstation_stick_l.png"],
	"look": ["Keyboard & Mouse/Default/mouse_move.png", "Xbox Series/Default/xbox_stick_r.png", "PlayStation Series/Default/playstation_stick_r.png"],
	"dir_up": ["Keyboard & Mouse/Default/keyboard_arrow_up.png", "Xbox Series/Default/xbox_dpad_up.png", "PlayStation Series/Default/playstation_dpad_up.png"],
	"dir_down": ["Keyboard & Mouse/Default/keyboard_arrow_down.png", "Xbox Series/Default/xbox_dpad_down.png", "PlayStation Series/Default/playstation_dpad_down.png"],
	"dir_left": ["Keyboard & Mouse/Default/keyboard_arrow_left.png", "Xbox Series/Default/xbox_dpad_left.png", "PlayStation Series/Default/playstation_dpad_left.png"],
	"dir_right": ["Keyboard & Mouse/Default/keyboard_arrow_right.png", "Xbox Series/Default/xbox_dpad_right.png", "PlayStation Series/Default/playstation_dpad_right.png"],
	"build_place": ["Keyboard & Mouse/Default/mouse_left.png", "Xbox Series/Default/xbox_button_color_a.png", "PlayStation Series/Default/playstation_button_color_cross.png"],
	"build_sell": ["Keyboard & Mouse/Default/mouse_right.png", "Xbox Series/Default/xbox_button_color_x.png", "PlayStation Series/Default/playstation_button_color_square.png"],
	"build_rotate": ["Keyboard & Mouse/Default/keyboard_r.png", "Xbox Series/Default/xbox_button_color_y.png", "PlayStation Series/Default/playstation_button_color_triangle.png"],
	"build_prev": ["Keyboard & Mouse/Default/mouse_scroll_up.png", "Xbox Series/Default/xbox_lb.png", "PlayStation Series/Default/playstation_trigger_l1.png"],
	"build_next": ["Keyboard & Mouse/Default/mouse_scroll_down.png", "Xbox Series/Default/xbox_rb.png", "PlayStation Series/Default/playstation_trigger_r1.png"],
}

var using_controller: bool = false
var _icon_cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()
	_add_ui_bindings()
	using_controller = Input.get_connected_joypads().size() > 0 and DisplayServer.get_name() != "headless" \
		and not OS.has_feature("web") # on the web a controller only counts once it is used
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _register_actions() -> void:
	for action in BINDINGS:
		var spec: Array = BINDINGS[action]
		if not InputMap.has_action(action):
			InputMap.add_action(action, float(spec[0]))
		for i in range(1, spec.size()):
			var b = spec[i]
			var ev: InputEvent
			if b is int:
				var k := InputEventKey.new()
				k.physical_keycode = b
				ev = k
			elif str(b).begins_with("b"):
				var jb := InputEventJoypadButton.new()
				jb.button_index = int(str(b).substr(1))
				ev = jb
			elif str(b).begins_with("m"):
				var mb := InputEventMouseButton.new()
				mb.button_index = int(str(b).substr(1))
				ev = mb
			else: # "a<axis>:<sign>"
				var parts := str(b).substr(1).split(":")
				var jm := InputEventJoypadMotion.new()
				jm.axis = int(parts[0])
				jm.axis_value = float(parts[1])
				ev = jm
			InputMap.action_add_event(action, ev)


## Menus: the left stick also moves between buttons (the D-pad and A / B already do by default).
func _add_ui_bindings() -> void:
	for pair in [["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0],
			["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = pair[1]
		jm.axis_value = pair[2]
		if not InputMap.action_has_event(pair[0], jm):
			InputMap.action_add_event(pair[0], jm)


func _input(event: InputEvent) -> void:
	var controller := using_controller
	if event is InputEventJoypadButton and event.pressed:
		controller = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		controller = true
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		controller = false
	elif event is InputEventMouseMotion and event.relative.length() > 4.0:
		controller = false
	if controller != using_controller:
		using_controller = controller
		device_changed.emit(using_controller)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected and Input.get_connected_joypads().is_empty() and using_controller:
		using_controller = false
		device_changed.emit(false)


## True for a PlayStation pad (its buttons are shown as Cross / Circle / Square / Triangle).
func is_playstation() -> bool:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return false
	var name := Input.get_joy_name(pads[0]).to_lower()
	return name.contains("playstation") or name.contains("dualsense") or name.contains("dualshock") \
		or name.contains("ps4") or name.contains("ps5") or name.contains("sony")


## The button icon for `action` on the device the player is using (null if there is none).
func icon(action: String) -> Texture2D:
	var files: Array = ICONS.get(action, [])
	if files.is_empty():
		return null
	var index := 0
	if using_controller:
		index = 2 if is_playstation() else 1
	var path: String = ICON_ROOT + str(files[index])
	if not ResourceLoader.exists(path) and index == 2:
		path = ICON_ROOT + str(files[1]) # no PlayStation icon: use the Xbox one
	if _icon_cache.has(path):
		return _icon_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icon_cache[path] = tex
	return tex


## A BBCode image tag for `action`, for RichTextLabels ("" if there is no icon).
func bb(action: String, size: int = 32) -> String:
	var tex := icon(action)
	return "" if tex == null else "[img=%dx%d]%s[/img]" % [size, size, tex.resource_path]
