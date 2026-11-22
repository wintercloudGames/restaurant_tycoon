class_name TimingGame
extends CookMinigame
## Grill minigame (cook_minigame.tscn): stop the moving marker inside the green zone,
## once per round. Space, E or Left Click stops the marker.

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
	_start_round()


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
	_stage_label.text = "%s  (%d/%d)" % [_stage_name(_round), _round + 1, _rounds]
	_feedback_label.text = ""


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


func _game_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = event.keycode == KEY_SPACE or event.keycode == KEY_E
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if pressed:
		get_viewport().set_input_as_handled()
		_press()


func _press() -> void:
	if _phase != 0:
		return
	var dist := absf(_marker - _zone_c)
	var score := 0.2
	var text := "Miss!"
	var color := Color(1.0, 0.4, 0.4)
	Sfx.play(&"MinigamePress")
	if dist <= _zone_w * 0.15:
		score = 1.0
		text = "Perfect!"
		color = Color(1.0, 0.85, 0.2)
		Sfx.play(&"MinigamePerfect")
	elif dist <= _zone_w * 0.5:
		score = 0.7
		text = "Good!"
		color = Color(0.4, 1.0, 0.5)
		Sfx.play(&"MinigameGood")
	else:
		Sfx.play(&"MinigameMiss")
	_scores.append(score)
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)
	_phase = 1
	_timer = 0.6
