extends Node
## CrazyGames SDK v3 bridge (web builds only).
##
## The SDK script itself is loaded by the web export's HTML head (see export_presets.cfg ->
## "Head Include"), which also defines a few small helpers on `window` (cgInit, cgAd, cgCall,
## cgGetItem, cgSetItem). Everywhere else (the editor, desktop builds) every call here is a
## safe no-op, so the game can call these functions without checking the platform.

signal sdk_ready
signal ad_started
signal ad_finished

## Minimum seconds between two midgame ads (CrazyGames also enforces its own limit).
const MIDGAME_COOLDOWN := 180.0
## No midgame ad in the first few minutes of a session.
const FIRST_MIDGAME_AFTER := 150.0

var is_web: bool = false
var ready_done: bool = false # init finished (successfully or not)
var available: bool = false # SDK is running (on crazygames.com or localhost)
var ad_playing: bool = false

var _window: JavaScriptObject
var _callbacks: Array = [] # JavaScriptBridge callbacks must stay referenced while JS can call them
var _session_time: float = 0.0
var _last_midgame: float = -INF
var _gameplay_on: bool = false
var _master_volume_before_ad: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_web = OS.has_feature("web")
	if not is_web:
		ready_done = true
		return
	_window = JavaScriptBridge.get_interface("window")
	if _window == null or _window.cgInit == null:
		ready_done = true # the page has no SDK glue (e.g. exported without the head include)
		return
	var on_done := JavaScriptBridge.create_callback(_on_init_done)
	_callbacks.append(on_done)
	_window.cgInit(on_done)


func _process(delta: float) -> void:
	_session_time += delta


func _on_init_done(args: Array) -> void:
	available = args.size() > 0 and bool(args[0])
	ready_done = true
	sdk_ready.emit()


## Waits until the SDK has started (or failed), at most `timeout` seconds.
func wait_ready(timeout: float = 4.0) -> void:
	var waited := 0.0
	while not ready_done and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()


# ---- Game events ---------------------------------------------------------

func loading_stop() -> void:
	_call("loadingStop")


## Tell CrazyGames the player is playing (true) or in a menu / paused (false).
func set_gameplay(on: bool) -> void:
	if on == _gameplay_on:
		return
	_gameplay_on = on
	_call("gameplayStart" if on else "gameplayStop")


## A happy moment (rank up, big purchase): CrazyGames may show a small celebration.
func happy_time() -> void:
	_call("happytime")


func _call(method: String) -> void:
	if available:
		_window.cgCall(method)


# ---- Ads -----------------------------------------------------------------

func can_show_rewarded() -> bool:
	return available and not ad_playing


## Shows a midgame ad at a natural break, if the cooldown allows it. `done` runs afterwards
## (also when no ad was shown).
func try_midgame(done: Callable = Callable()) -> void:
	if not available or ad_playing or _session_time < FIRST_MIDGAME_AFTER \
			or _session_time - _last_midgame < MIDGAME_COOLDOWN:
		if done.is_valid():
			done.call()
		return
	_last_midgame = _session_time
	_request_ad("midgame", func(_ok: bool) -> void:
		if done.is_valid():
			done.call())


## Shows a rewarded ad. `on_result` gets true if the player watched it (give the reward).
func show_rewarded(on_result: Callable) -> void:
	if not can_show_rewarded():
		on_result.call(false)
		return
	_request_ad("rewarded", on_result)


func _request_ad(kind: String, on_result: Callable) -> void:
	var start_cb := JavaScriptBridge.create_callback(func(_a: Array) -> void: _begin_ad())
	var done_cb: JavaScriptObject
	var error_cb: JavaScriptObject
	var finish := func(ok: bool) -> void:
		_end_ad()
		_callbacks.erase(start_cb)
		_callbacks.erase(done_cb)
		_callbacks.erase(error_cb)
		on_result.call(ok)
	done_cb = JavaScriptBridge.create_callback(func(_a: Array) -> void: finish.call(true))
	error_cb = JavaScriptBridge.create_callback(func(a: Array) -> void:
		push_warning("CrazyGames ad error: %s" % [a])
		finish.call(false))
	_callbacks.append_array([start_cb, done_cb, error_cb])
	_window.cgAd(kind, start_cb, done_cb, error_cb)


## While an ad plays the game is paused and muted, and gameplay is reported as stopped.
func _begin_ad() -> void:
	if ad_playing:
		return
	ad_playing = true
	_master_volume_before_ad = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_mute(0, true)
	get_tree().paused = true
	set_gameplay(false)
	ad_started.emit()


func _end_ad() -> void:
	if not ad_playing:
		return
	ad_playing = false
	AudioServer.set_bus_mute(0, false)
	ad_finished.emit() # the pause menu decides whether to unpause


# ---- Cloud saves (CrazyGames Data module) ------------------------------

## True when saves should go to CrazyGames' storage (synced to the player's account).
func has_data() -> bool:
	return available


func get_item(key: String) -> String:
	if not available:
		return ""
	var value = _window.cgGetItem(key)
	return "" if value == null else str(value)


func set_item(key: String, value: String) -> void:
	if available:
		_window.cgSetItem(key, value)
