class_name MashGame
extends CookMinigame
## Stirring minigame (minigame_mash.tscn): mash Space / E / Left Click to fill the meter
## before time runs out. The meter drains while you're not stirring. Finish sooner = better.

@export var time_limit: float = 8.0

var _meter: float = 0.0
var _gain: float = 0.08
var _decay: float = 0.2
var _elapsed: float = 0.0

@onready var _meter_bar: ProgressBar = %Meter
@onready var _time_bar: ProgressBar = %TimeBar


func _setup() -> void:
	var d := difficulty()
	_gain = 0.085 - 0.03 * d
	_decay = 0.18 + 0.12 * d
	_stage_label.text = "Stir! Mash Space / E / Click!"
	_update_bars()


func _tick(delta: float) -> void:
	_elapsed += delta
	_meter = maxf(0.0, _meter - _decay * delta)
	_update_bars()
	if _elapsed >= time_limit:
		# Ran out of time: burnt, a bit better the closer you got.
		_finish(clampf(_meter * 0.5, 0.1, 0.5))


func _update_bars() -> void:
	_meter_bar.value = _meter * 100.0
	_time_bar.value = (1.0 - _elapsed / time_limit) * 100.0


func _game_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = event.keycode == KEY_SPACE or event.keycode == KEY_E
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if pressed:
		get_viewport().set_input_as_handled()
		_stir()


func _stir() -> void:
	if _result_timer >= 0.0:
		return
	_meter += _gain
	Sfx.play(&"MinigamePress")
	if _meter >= 1.0:
		_meter = 1.0
		_update_bars()
		# Finishing with at least half the time left is a perfect dish.
		var time_left := 1.0 - _elapsed / time_limit
		_finish(clampf(0.55 + 0.45 * (time_left / 0.5), 0.55, 1.0))
