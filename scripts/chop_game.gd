class_name ChopGame
extends CookMinigame
## Chop / slice minigame (minigame_chop.tscn): tap LEFT and RIGHT in turn (arrow keys, A / D,
## the D-pad or the left stick) - every switch is one cut. Pressing the same side twice slips
## and doesn't cut. Make all the cuts before time runs out; finishing with half the time left
## is a Perfect (the gold line on the time bar).

@export var time_limit: float = 8.0

var _cuts_needed: int = 12
var _cuts: int = 0
var _last_side: String = ""
var _elapsed: float = 0.0
var _slips: int = 0
var _side_icons: Dictionary = {} # "left" / "right" -> TextureRect

@onready var _meter_bar: ProgressBar = %Meter
@onready var _time_bar: ProgressBar = %TimeBar


func _setup() -> void:
	_cuts_needed = 10 + int(round(8.0 * difficulty()))
	_meter_bar.show_percentage = false
	_build_sides()
	_add_perfect_line()
	set_prompt(["dir_left", "dir_right"], "Tap left and right in turn to chop")
	_update()


## Two big buttons under the title: the one to press next lights up.
func _build_sides() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	var box := _meter_bar.get_parent()
	box.add_child(row)
	box.move_child(row, _meter_bar.get_index())
	for side in ["left", "right"]:
		var rect := _icon_rect(Controls.icon("dir_" + side), 72)
		row.add_child(rect)
		_side_icons[side] = rect


func _device_changed() -> void:
	for side in _side_icons:
		(_side_icons[side] as TextureRect).texture = Controls.icon("dir_" + side)


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
	if Input.is_action_just_pressed("dir_left"):
		_chop("left")
	elif Input.is_action_just_pressed("dir_right"):
		_chop("right")


func _chop(side: String) -> void:
	if _result_timer >= 0.0:
		return
	pulse(_side_icons[side], 1.25)
	if side == _last_side:
		_slips += 1
		show_feedback("Switch sides!", MISS_COLOR)
		Sfx.play(&"MinigameMiss")
		return
	_last_side = side
	_cuts += 1
	_feedback_label.text = ""
	Sfx.play(&"Chop")
	_update()
	if _cuts >= _cuts_needed:
		var time_left := 1.0 - _elapsed / time_limit
		_finish(clampf(0.55 + 0.45 * (time_left / 0.5), 0.55, 1.0))


func _tick(delta: float) -> void:
	_elapsed += delta
	_update()
	if _elapsed >= time_limit:
		# Out of time: burnt, a bit better the further you got.
		_finish(clampf(float(_cuts) / float(_cuts_needed) * 0.5, 0.1, 0.5))


func _update() -> void:
	_meter_bar.value = float(_cuts) / float(_cuts_needed) * 100.0
	_time_bar.value = (1.0 - _elapsed / time_limit) * 100.0
	_stage_label.text = "Cuts: %d of %d" % [_cuts, _cuts_needed]
	var next := "right" if _last_side == "left" else "left"
	for side in _side_icons:
		var rect := _side_icons[side] as TextureRect
		rect.modulate = Color.WHITE if (side == next or _last_side == "") else Color(1, 1, 1, 0.3)
