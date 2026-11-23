class_name HoldGame
extends CookMinigame
## Fry / pour minigame (minigame_hold.tscn): hold Space / E / click / controller A to heat,
## release to cool. Keep the marker inside the drifting green zone until time runs out. The
## stage line shows how much of the time you've kept it in the zone so far.

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
var _was_inside: bool = false

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
	_zone_rect.color = Color(0.25, 0.7, 0.35)
	_marker_rect.move_to_front()
	set_prompt(["cook_press"], "Hold to heat, let go to cool - stay in the green")
	_update_visuals()


func _poll() -> void:
	var holding := Input.is_action_pressed("cook_press")
	if holding and not _holding:
		Sfx.play(&"MinigamePress")
		if _prompt_icons.get_child_count() > 0:
			pulse(_prompt_icons.get_child(0) as Control)
	_holding = holding


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
	if inside != _was_inside and _elapsed > 0.3:
		if inside:
			show_feedback("In the zone!", GOOD_COLOR)
		else:
			show_feedback("Too hot!" if _heat > _zone_c else "Too cold!", MISS_COLOR)
	_was_inside = inside
	_marker_rect.color = GOOD_COLOR if inside else Color.WHITE
	_update_visuals()
	if _elapsed >= duration:
		# 80% of the time in the zone counts as a perfect dish.
		_finish(clampf((_in_zone / duration) / 0.8, 0.1, 1.0))


func _update_visuals() -> void:
	_zone_rect.position.x = (_zone_c - _zone_w / 2.0) * _bar_w
	_zone_rect.size = Vector2(_zone_w * _bar_w, _bar_h)
	_marker_rect.position.x = _heat * _bar_w - _marker_rect.size.x / 2.0
	_time_bar.value = (1.0 - _elapsed / duration) * 100.0
	var share := 0.0 if _elapsed <= 0.0 else _in_zone / _elapsed
	_stage_label.text = "In the zone: %d%%   (80%% or more is Perfect)" % int(round(share * 100.0))
