class_name TimingGame
extends CookMinigame
## Grill minigame (cook_minigame.tscn): stop the moving marker inside the green zone, once per
## round. Space / E / click / controller A stops the marker. The bright middle of the zone is a
## Perfect; the dots under the bar show how each round went.

@export var middle_stages: Array[String] = ["Sear it!", "Flip it!", "Season it!"]
@export var final_stage: String = "Plate it!"

var _marker: float = 0.0
var _dir: float = 1.0
var _speed: float = 1.0
var _zone_w: float = 0.25
var _zone_c: float = 0.5
var _round: int = 0
var _rounds: int = 3
var _scores: Array[float] = []
var _phase: int = 0 # 0 playing, 1 showing the round result
var _timer: float = 0.0
var _bar_w: float = 560.0
var _bar_h: float = 36.0
var _sweet: ColorRect # the Perfect part in the middle of the zone
var _dots: Array[Panel] = []

@onready var _bar: Control = %Bar
@onready var _zone_rect: ColorRect = %Zone
@onready var _marker_rect: ColorRect = %Marker


func _setup() -> void:
	var d := difficulty()
	_rounds = order.step_rounds()
	# Harder dishes move faster with a smaller zone; "Easier cooking" slows and widens.
	_speed = (0.8 + 0.6 * d) * pow(0.92, GameState.cook_level)
	_zone_w = clampf((0.30 - 0.14 * d) * (1.0 + 0.05 * GameState.cook_level), 0.12, 0.4)
	_bar_w = _bar.custom_minimum_size.x
	_bar_h = _zone_rect.size.y if _zone_rect.size.y > 0.0 else 36.0
	_zone_rect.color = Color(0.25, 0.7, 0.35)
	_sweet = ColorRect.new()
	_sweet.color = Color(0.55, 1.0, 0.6)
	_sweet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_rect.add_child(_sweet)
	_marker_rect.move_to_front()
	_build_dots()
	set_prompt(["cook_press"], "Stop the marker in the green - the bright middle is Perfect")
	_start_round()


## One dot per round under the bar; it turns gold / green / red with that round's result.
func _build_dots() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var box := _bar.get_parent()
	box.add_child(row)
	box.move_child(row, _bar.get_index() + 1)
	for i in _rounds:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		row.add_child(dot)
		_dots.append(dot)
	_paint_dots()


func _paint_dots() -> void:
	for i in _dots.size():
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(9)
		if i < _scores.size():
			style.bg_color = PERFECT_COLOR if _scores[i] >= 1.0 else (GOOD_COLOR if _scores[i] >= 0.7 else MISS_COLOR)
		elif i == _round:
			style.bg_color = Color(1, 1, 1, 0.9)
		else:
			style.bg_color = Color(1, 1, 1, 0.2)
		_dots[i].add_theme_stylebox_override("panel", style)


func _stage_name(i: int) -> String:
	if i >= _rounds - 1:
		return final_stage
	return middle_stages[i % middle_stages.size()]


func _start_round() -> void:
	_phase = 0
	_marker = 0.0
	_dir = 1.0
	_zone_c = randf_range(_zone_w / 2.0 + 0.05, 1.0 - _zone_w / 2.0 - 0.05)
	_zone_rect.position.x = (_zone_c - _zone_w / 2.0) * _bar_w
	_zone_rect.size = Vector2(_zone_w * _bar_w, _bar_h)
	_sweet.size = Vector2(_zone_w * 0.3 * _bar_w, _bar_h)
	_sweet.position = Vector2((_zone_w * _bar_w - _sweet.size.x) / 2.0, 0)
	_marker_rect.color = Color.WHITE
	_stage_label.text = "%s  (round %d of %d)" % [_stage_name(_round), _round + 1, _rounds]
	_feedback_label.text = ""
	_paint_dots()


func _poll() -> void:
	if Input.is_action_just_pressed("cook_press"):
		_press()


func _tick(delta: float) -> void:
	match _phase:
		0:
			_marker += _dir * _speed * delta
			if _marker >= 1.0:
				_marker = 1.0
				_dir = -1.0
			elif _marker <= 0.0:
				_marker = 0.0
				_dir = 1.0
			_marker_rect.position.x = _marker * _bar_w - _marker_rect.size.x / 2.0
		1:
			_timer -= delta
			if _timer <= 0.0:
				_round += 1
				if _round >= _rounds:
					var total := 0.0
					for s in _scores:
						total += s
					_finish(total / float(_scores.size()))
				else:
					_start_round()


func _press() -> void:
	if _phase != 0:
		return
	var dist := absf(_marker - _zone_c)
	var score := 0.2
	var text := "Miss!"
	var color := MISS_COLOR
	Sfx.play(&"MinigamePress")
	if dist <= _zone_w * 0.15:
		score = 1.0
		text = "Perfect!"
		color = PERFECT_COLOR
		Sfx.play(&"MinigamePerfect")
	elif dist <= _zone_w * 0.5:
		score = 0.7
		text = "Good!"
		color = GOOD_COLOR
		Sfx.play(&"MinigameGood")
	else:
		Sfx.play(&"MinigameMiss")
	_scores.append(score)
	show_feedback(text, color)
	_marker_rect.color = color # the marker freezes in the result's color
	pulse(_marker_rect, 1.4)
	_paint_dots()
	_phase = 1
	_timer = 0.7
