class_name CookMinigame
extends CanvasLayer
## Base class for the cooking minigames. Each dish picks one (see "game" in
## autoload/game_state.gd):
##   TimingGame   (cook_minigame.tscn)     grill: stop the marker in the green zone
##   HoldGame     (minigame_hold.tscn)     fry: hold to heat, release to cool, stay in the zone
##   MashGame     (minigame_mash.tscn)     stir: mash the button to fill the meter in time
##   SequenceGame (minigame_sequence.tscn) assemble: press the shown keys in order
## Esc cancels (the dish stays on the stove). Subclasses override _setup, _tick and _game_input.

signal finished(quality: float)
signal cancelled

var order: Order

var _closed: bool = false
var _result_timer: float = -1.0 # >= 0 while the final result is showing

@onready var _title: Label = %Title
@onready var _stage_label: Label = %StageLabel
@onready var _feedback_label: Label = %FeedbackLabel


static func quality_name(q: float) -> String:
	if q >= 0.85:
		return "Perfect"
	if q >= 0.55:
		return "Good"
	return "Burnt"


## 0 (easy) .. 1 (hard), from the dish.
func difficulty() -> float:
	return GameState.dish_difficulty(order.dish_id)


func _ready() -> void:
	_style_panel()
	if order.step_count() > 1:
		_title.text = "%s: %s - %s (%s)" % [order.step_text(), order.step_label(), order.dish_name(), order.where()]
	else:
		var verb := "Cooking" if order.step_station() == "stove" else "Preparing"
		_title.text = "%s %s for %s" % [verb, order.dish_name(), order.where()]
	_setup()


## A solid dark panel so the 3D scene doesn't show through.
func _style_panel() -> void:
	var panel := get_node_or_null("Panel") as PanelContainer
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.96)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)


func _process(delta: float) -> void:
	if _closed:
		return
	if not order.is_active():
		_close(false)
		return
	if _result_timer >= 0.0:
		_result_timer -= delta
		if _result_timer <= 0.0:
			_close(true)
	else:
		_tick(delta)


func _input(event: InputEvent) -> void:
	if _closed:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close(false)
		return
	if _result_timer < 0.0:
		_game_input(event)


# ---- For subclasses ------------------------------------------------------

func _setup() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _game_input(_event: InputEvent) -> void:
	pass


## Ends the game with a result (0..1). The result shows for a second, then it closes.
func _finish(quality: float) -> void:
	order.quality = quality
	_stage_label.text = "Done!"
	_feedback_label.text = "%s dish!" % quality_name(quality)
	_result_timer = 1.0
	Sfx.play(&"MinigameDone")


## `success` true -> finished signal, false -> cancelled signal.
func _close(success: bool) -> void:
	if _closed:
		return
	_closed = true
	if success:
		finished.emit(order.quality)
	else:
		Sfx.play(&"MinigameCancel")
		cancelled.emit()
	queue_free()
