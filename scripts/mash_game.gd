class_name MashGame
extends CookMinigame
## Stir / mix minigame (minigame_mash.tscn): mash Space / E / click / controller A to fill the
## meter before time runs out. The meter drains while you're not stirring. Finish with at least
## half the time left for a Perfect (the gold line on the time bar).

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
	_meter_bar.show_percentage = true
	_add_perfect_line()
	set_prompt(["cook_press"], "Mash it to fill the meter!")
	_update_bars()


## A gold line at the halfway point of the time bar: fill the meter before it for a Perfect.
func _add_perfect_line() -> void:
	var line := ColorRect.new()
	line.color = Color.WHITE # the "finish before here for a Perfect" mark
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_bar.add_child(line)
	line.anchor_left = 0.5
	line.anchor_right = 0.5
	line.anchor_bottom = 1.0
	line.offset_left = -3
	line.offset_right = 3


func _poll() -> void:
	if Input.is_action_just_pressed("cook_press"):
		_stir()


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
	var left := time_limit - _elapsed
	_stage_label.text = "Faster!  %.1fs left" % left if left < 2.5 else "Keep going!  %.1fs left" % left


func _stir() -> void:
	if _result_timer >= 0.0:
		return
	_meter += _gain
	Sfx.play(&"Stir")
	pulse(_meter_bar, 1.04)
	if _prompt_icons.get_child_count() > 0:
		pulse(_prompt_icons.get_child(0) as Control)
	if _meter >= 1.0:
		_meter = 1.0
		_update_bars()
		# Finishing with at least half the time left is a perfect dish.
		var time_left := 1.0 - _elapsed / time_limit
		_finish(clampf(0.55 + 0.45 * (time_left / 0.5), 0.55, 1.0))
