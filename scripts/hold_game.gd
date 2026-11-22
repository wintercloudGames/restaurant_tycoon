class_name HoldGame
extends CookMinigame
## Frying minigame (minigame_hold.tscn): hold Space / E / Left Click to heat the oil, release
## to let it cool. Keep the marker inside the green zone (which drifts) until time runs out.

@export var duration: float = 7.0

var _heat: float = 0.15
var _holding: bool = false
var _elapsed: float = 0.0
var _in_zone: float = 0.0
var _zone_w: float = 0.25
var _zone_c: float = 0.5
var _drift_phase: float = 0.0
var _rise: float = 0.9
var _fall: float = 0.6
var _bar_w: float = 560.0
var _bar_h: float = 36.0

@onready var _bar: Control = %Bar
@onready var _zone_rect: ColorRect = %Zone
@onready var _marker_rect: ColorRect = %Marker
@onready var _time_bar: ProgressBar = %TimeBar


func _setup() -> void:
	var d := difficulty()
	_zone_w = clampf((0.28 - 0.12 * d) * (1.0 + 0.05 * GameState.cook_level), 0.12, 0.4)
	_rise = 0.9 + 0.3 * d
	_fall = 0.6 + 0.3 * d
	_drift_phase = randf() * TAU
	_bar_w = _bar.custom_minimum_size.x
	_bar_h = _zone_rect.size.y if _zone_rect.size.y > 0.0 else 36.0
	_stage_label.text = "Hold to heat, release to cool - stay in the green!"
	_update_visuals()


func _tick(delta: float) -> void:
	_elapsed += delta
	if _holding:
		_heat += _rise * delta
	else:
		_heat -= _fall * delta
	_heat = clampf(_heat, 0.0, 1.0)
	# The target slowly drifts, more for harder dishes.
	var drift := 0.12 + 0.12 * difficulty()
	_zone_c = clampf(0.5 + drift * sin(_elapsed * 1.1 + _drift_phase), _zone_w / 2.0, 1.0 - _zone_w / 2.0)
	var inside := absf(_heat - _zone_c) <= _zone_w / 2.0
	if inside:
		_in_zone += delta
	_marker_rect.color = Color(0.4, 1.0, 0.5) if inside else Color.WHITE
	_update_visuals()
	if _elapsed >= duration:
		# 80% of the time in the zone counts as a perfect dish.
		_finish(clampf((_in_zone / duration) / 0.8, 0.1, 1.0))


func _update_visuals() -> void:
	_zone_rect.position.x = (_zone_c - _zone_w / 2.0) * _bar_w
	_zone_rect.size = Vector2(_zone_w * _bar_w, _bar_h)
	_marker_rect.position.x = _heat * _bar_w - _marker_rect.size.x / 2.0
	_time_bar.value = (1.0 - _elapsed / duration) * 100.0


func _game_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_E):
		if event.pressed and not _holding:
			Sfx.play(&"MinigamePress")
		_holding = event.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _holding:
			Sfx.play(&"MinigamePress")
		_holding = event.pressed
		get_viewport().set_input_as_handled()
