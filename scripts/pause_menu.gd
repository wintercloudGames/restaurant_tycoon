class_name PauseMenu
extends CanvasLayer
## Start screen + pause menu, built in code (main.gd adds it).
##
## - Shown when the game starts ("Play"), when you press P, when the window / browser tab loses
##   focus, and whenever the mouse gets released unexpectedly (on the web, Esc always releases
##   the mouse, and browsers need a click before they let a game lock the mouse).
## - While it is open the game is paused and CrazyGames is told gameplay stopped.
## - Holds the settings (volume, music, mouse sensitivity; saved to user://settings.cfg) and the
##   rewarded-ad buttons (2x cash for 3 minutes, double your welcome-back money).

const SETTINGS_PATH := "user://settings.cfg"
const THEME_PATH := "res://assets/restraunt_theme.tres"
const MUSIC_BASE_DB := -10.0 # the Music slider at full = this loud

var main: Node
var player: Player
var is_open: bool = false
var _start_screen: bool = false # the first screen of the session (PLAY plays the start chime)

var _dim: ColorRect
var _title: Label
var _info: Label
var _play_button: Button
var _boost_button: Button
var _offline_button: Button
var _boost_badge: Label
var _volume: HSlider
var _music: HSlider
var _sensitivity: HSlider
var _offline_claimable: int = 0
var _base_sensitivity: float = 0.0025
## Seconds to wait after RESUME for the browser to lock the mouse before pausing again.
var _grace: float = 0.0
var _since_resume: float = 999.0
## Web test mode (open the page with ?test): the game doesn't pause when the mouse isn't locked,
## so it can be played with the keyboard only (arrow keys turn) or by automated testing.
var _test_mode: bool = false


func setup(main_node: Node, player_node: Player) -> void:
	main = main_node
	player = player_node
	_base_sensitivity = player.sensitivity


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_test_mode = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('test')", true))
	_build()
	_load_settings()
	CrazyGames.ad_finished.connect(_on_ad_finished)
	Controls.device_changed.connect(func(_c: bool) -> void:
		if is_open and get_viewport().gui_get_focus_owner() == null:
			_play_button.grab_focus())
	GameState.changed.connect(_refresh_buttons)


# ---- Open / close --------------------------------------------------------

## Shows the menu. `start` = the first screen of the session (welcome text + "Play").
func open(start: bool = false) -> void:
	if not start and not is_open:
		Sfx.play(&"ShopOpen")
	_start_screen = start
	is_open = true
	_dim.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	CrazyGames.set_gameplay(false)
	_title.text = "Restaurant Tycoon" if start else "Paused"
	_play_button.text = "PLAY" if start else "RESUME"
	if start:
		_offline_claimable = GameState.last_offline_earned
		if _offline_claimable > 0:
			_info.text = "Welcome back! Your restaurant earned $%d while you were away." % _offline_claimable
		else:
			_info.text = "Take orders, cook dishes and serve customers to grow your restaurant!"
	else:
		_offline_claimable = 0
		_info.text = "Game paused. Click RESUME (or press P) to keep playing."
	_refresh_buttons()
	_play_button.grab_focus.call_deferred()


func resume() -> void:
	if not is_open:
		return
	is_open = false
	_dim.visible = false
	_offline_claimable = 0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_grace = 1.0
	_since_resume = 0.0
	CrazyGames.set_gameplay(true)
	_save_settings()
	Sfx.play(&"GameStart" if _start_screen else &"ShopClose")
	_start_screen = false


func _process(delta: float) -> void:
	_update_badge()
	_grace = maxf(_grace - delta, 0.0)
	_since_resume += delta
	if is_open or CrazyGames.ad_playing or main == null or _grace > 0.0 or _test_mode:
		return
	# The mouse got released while we should be playing (Esc on the web, alt-tab...): pause.
	# Not when playing with a controller: it doesn't need the mouse locked.
	if not bool(main.get("shop_open")) and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and not Controls.using_controller:
		var lock_failed := _since_resume < 2.0
		open(false)
		if lock_failed:
			_info.text = "The browser didn't lock the mouse. Click RESUME again (right after Esc, browsers wait a second)."


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not is_open and main != null and not _test_mode \
			and not bool(main.get("shop_open")) and not CrazyGames.ad_playing:
		open(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo(): # P or the controller's Menu / Start
		if is_open:
			resume()
		elif main != null and not bool(main.get("shop_open")):
			open(false)
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("cancel") and not event.is_echo(): # Esc or B
		resume()
		get_viewport().set_input_as_handled()


func _on_ad_finished() -> void:
	# The browser usually releases the mouse during an ad, so ask for a click to continue.
	if not is_open:
		open(false)
		_info.text = "Thanks for watching! Click RESUME to keep playing."


# ---- Rewarded ads --------------------------------------------------------

func _on_boost_pressed() -> void:
	_boost_button.disabled = true
	CrazyGames.show_rewarded(func(ok: bool) -> void:
		if ok:
			GameState.start_boost()
			_info.text = "2x cash for the next 3 minutes!"
		else:
			_info.text = "No ad available right now. Try again later."
		_refresh_buttons())


func _on_offline_pressed() -> void:
	var amount := _offline_claimable
	_offline_button.disabled = true
	CrazyGames.show_rewarded(func(ok: bool) -> void:
		if ok and amount > 0:
			_offline_claimable = 0
			GameState.add_money(amount) # the first half was already paid on load
			GameState.save_game()
			_info.text = "Doubled! +$%d extra welcome-back cash." % amount
		elif not ok:
			_info.text = "No ad available right now. Try again later."
		_refresh_buttons())


func _refresh_buttons() -> void:
	if _boost_button == null:
		return
	var ads := CrazyGames.available
	_boost_button.visible = ads
	_boost_button.disabled = not CrazyGames.can_show_rewarded()
	_boost_button.text = "Watch ad: 2x cash for 3 min" if GameState.boost_time_left <= 0.0 \
		else "Watch ad: +3 min more 2x cash"
	_offline_button.visible = ads and _offline_claimable > 0
	_offline_button.disabled = not CrazyGames.can_show_rewarded()
	_offline_button.text = "Watch ad: double it (+$%d)" % _offline_claimable


func _update_badge() -> void:
	var left := GameState.boost_time_left
	_boost_badge.visible = left > 0.0
	if left > 0.0:
		_boost_badge.text = "2x CASH  %d:%02d" % [int(left) / 60, int(left) % 60]


# ---- Settings ------------------------------------------------------------

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume.value, 0.0001)))
	var music := _find_music()
	if music != null:
		music.volume_db = MUSIC_BASE_DB + linear_to_db(maxf(_music.value, 0.0001))
	if player != null:
		player.sensitivity = _base_sensitivity * _sensitivity.value


func _find_music() -> AudioStreamPlayer:
	if main == null:
		return null
	for child in main.get_children():
		var m := child.get_node_or_null("Music") as AudioStreamPlayer
		if m != null:
			return m
	return null


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # a missing file just leaves the defaults
	_volume.set_value_no_signal(float(cfg.get_value("audio", "volume", 0.8)))
	_music.set_value_no_signal(float(cfg.get_value("audio", "music", 0.6)))
	_sensitivity.set_value_no_signal(float(cfg.get_value("input", "sensitivity", 1.0)))
	_apply_settings()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", _volume.value)
	cfg.set_value("audio", "music", _music.value)
	cfg.set_value("input", "sensitivity", _sensitivity.value)
	cfg.save(SETTINGS_PATH)


# ---- Building the UI -----------------------------------------------------

func _build() -> void:
	var theme := load(THEME_PATH) as Theme

	_boost_badge = Label.new()
	_boost_badge.anchor_left = 1.0
	_boost_badge.anchor_right = 1.0
	_boost_badge.offset_left = -260
	_boost_badge.offset_right = -20
	_boost_badge.offset_top = 16
	_boost_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boost_badge.add_theme_font_size_override("font_size", 28)
	_boost_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_boost_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_boost_badge.add_theme_constant_override("outline_size", 8)
	_boost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_badge.visible = false
	add_child(_boost_badge)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.theme = theme
	_dim.visible = false
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	_title = _label(box, "Restaurant Tycoon", 44)
	_info = _label(box, "", 20)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_play_button = _button(box, "PLAY", 34, resume)
	_play_button.custom_minimum_size.y = 72
	_offline_button = _button(box, "", 22, _on_offline_pressed)
	_boost_button = _button(box, "", 22, _on_boost_pressed)

	box.add_child(HSeparator.new())
	_volume = _slider(box, "Volume", 0.0, 1.0, 0.05)
	_music = _slider(box, "Music", 0.0, 1.0, 0.05)
	_sensitivity = _slider(box, "Mouse sensitivity", 0.2, 3.0, 0.1)
	box.add_child(HSeparator.new())

	var controls := _label(box,
		"WASD move  ·  Mouse / arrow keys look  ·  E / Click interact\nB shop  ·  V build  ·  P pause\n"
		+ "Controller: sticks move / look  ·  A interact  ·  Y shop  ·  View build  ·  Menu pause", 16)
	controls.modulate = Color(1, 1, 1, 0.8)


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, size: int, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _slider(parent: Node, text: String, lo: float, hi: float, step: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 200
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(_v: float) -> void: _apply_settings())
	row.add_child(s)
	return s
