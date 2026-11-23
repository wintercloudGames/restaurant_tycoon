class_name CookMinigame
extends CanvasLayer
## Base class for the cooking minigames. Each recipe step picks one (see "game" in
## autoload/game_state.gd):
##   TimingGame   (cook_minigame.tscn)     grill: stop the marker in the green zone
##   HoldGame     (minigame_hold.tscn)     fry / pour: hold to heat, release to cool, stay in the zone
##   MashGame     (minigame_mash.tscn)     stir / mix: mash the button to fill the meter in time
##   ChopGame     (minigame_chop.tscn)     chop / slice: tap left and right in turn
##   SequenceGame (minigame_sequence.tscn) assemble: press the shown arrows in order
##
## Input goes through the actions in autoload/controls.gd, so keyboard, mouse and controllers all
## work: "cook_press" (Space / E / click / A), "dir_*" (arrows / WASD / D-pad / stick) and
## "cancel" (Esc / B; the dish stays on the stove).
##
## Every game shows the same frame: the recipe's steps along the top (done / now / next), a
## prompt row with the button icons for the device you're using, a pop-up for each hit
## (Perfect / Good / Miss) and a big result at the end. Subclasses override _setup, _tick and _poll.

signal finished(quality: float)
signal cancelled

const PERFECT_COLOR := Color(1.0, 0.85, 0.2)
const GOOD_COLOR := Color(0.4, 1.0, 0.5)
const MISS_COLOR := Color(1.0, 0.4, 0.4)
const DIM_COLOR := Color(1, 1, 1, 0.35)
## Ignore buttons for a moment after opening, so the press that started the game doesn't count.
const INPUT_DELAY := 0.2

var order: Order

var _closed: bool = false
var _result_timer: float = -1.0 # >= 0 while the final result is showing
var _age: float = 0.0
var _prompt_actions: Array[String] = []
var _prompt_icons: HBoxContainer
var _prompt_text: Label
var _cancel_icon: TextureRect
var _feedback_tween: Tween

@onready var _title: Label = %Title
@onready var _stage_label: Label = %StageLabel
@onready var _feedback_label: Label = %FeedbackLabel


static func quality_name(q: float) -> String:
	if q >= 0.85:
		return "Perfect"
	if q >= 0.55:
		return "Good"
	return "Burnt"


static func quality_color(q: float) -> Color:
	if q >= 0.85:
		return PERFECT_COLOR
	if q >= 0.55:
		return GOOD_COLOR
	return MISS_COLOR


## 0 (easy) .. 1 (hard), from the dish.
func difficulty() -> float:
	return GameState.dish_difficulty(order.dish_id)


func _ready() -> void:
	_style_panel()
	_title.text = "%s for %s" % [order.dish_name(), order.where()]
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_feedback_label.add_theme_constant_override("outline_size", 6)
	_build_steps_row()
	_build_prompt_row()
	Controls.device_changed.connect(_on_device_changed)
	_setup()


## A solid dark panel so the 3D scene doesn't show through.
func _style_panel() -> void:
	var panel := get_node_or_null("Panel") as PanelContainer
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.96)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	var box := get_node_or_null("Panel/Box") as VBoxContainer
	if box != null:
		box.add_theme_constant_override("separation", 12)
		# Bars and meters keep their width and sit in the middle of the (wider) panel.
		for child in box.get_children():
			if child is Control and (child as Control).custom_minimum_size.x > 0.0:
				(child as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER


# ---- The shared frame ----------------------------------------------------

## The recipe along the top: "1 Grill patty  >  2 Build burger", the current step highlighted.
func _build_steps_row() -> void:
	var row := HBoxContainer.new()
	row.name = "Steps"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var box := _title.get_parent()
	box.add_child(row)
	box.move_child(row, _title.get_index() + 1)
	var steps := order.steps()
	for i in steps.size():
		if i > 0:
			var arrow := Label.new()
			arrow.text = ">"
			arrow.modulate = DIM_COLOR
			row.add_child(arrow)
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_content_margin_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		var label := Label.new()
		var step_name := str(steps[i].get("label", order.dish_name())) if steps.size() > 1 else order.step_label()
		label.add_theme_font_size_override("font_size", 16)
		if i < order.step_index:
			style.bg_color = Color(0.2, 0.45, 0.25)
			label.text = "%s  done" % step_name
		elif i == order.step_index:
			style.bg_color = Color(0.85, 0.6, 0.1)
			style.border_color = Color(1, 0.9, 0.5)
			style.set_border_width_all(2)
			label.text = step_name if steps.size() == 1 else "Step %d: %s" % [i + 1, step_name]
			label.add_theme_color_override("font_color", Color(0.1, 0.07, 0.02))
		else:
			style.bg_color = Color(1, 1, 1, 0.08)
			label.text = step_name
			label.modulate = Color(1, 1, 1, 0.6)
		chip.add_theme_stylebox_override("panel", style)
		chip.add_child(label)
		row.add_child(chip)


## The bottom row: the button(s) to press and what they do, then how to cancel. It replaces the
## scene's old text-only Hint label.
func _build_prompt_row() -> void:
	var hint := get_node_or_null("Panel/Box/Hint") as Label
	var box := _title.get_parent()
	var row := HBoxContainer.new()
	row.name = "Prompt"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	if hint != null:
		hint.visible = false
		box.add_child(row)
		box.move_child(row, hint.get_index())
	else:
		box.add_child(row)
	_prompt_icons = HBoxContainer.new()
	_prompt_icons.add_theme_constant_override("separation", 4)
	row.add_child(_prompt_icons)
	_prompt_text = Label.new()
	_prompt_text.add_theme_font_size_override("font_size", 18)
	row.add_child(_prompt_text)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 28
	row.add_child(spacer)
	_cancel_icon = _icon_rect(Controls.icon("cancel"), 28)
	row.add_child(_cancel_icon)
	var cancel_text := Label.new()
	cancel_text.text = "Cancel"
	cancel_text.add_theme_font_size_override("font_size", 16)
	cancel_text.modulate = Color(1, 1, 1, 0.6)
	row.add_child(cancel_text)


## Sets the prompt: the icons of `actions` (for keyboard or controller) and a short text.
func set_prompt(actions: Array[String], text: String) -> void:
	_prompt_actions = actions
	_prompt_text.text = text
	_refresh_prompt_icons()


func _refresh_prompt_icons() -> void:
	for child in _prompt_icons.get_children():
		child.queue_free()
	for action in _prompt_actions:
		_prompt_icons.add_child(_icon_rect(Controls.icon(action), 36))
	if _cancel_icon != null:
		_cancel_icon.texture = Controls.icon("cancel")


func _on_device_changed(_controller: bool) -> void:
	_refresh_prompt_icons()
	_device_changed()


static func _icon_rect(tex: Texture2D, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


## Shows a short word (Perfect! / Good! / Miss!) that pops in and settles.
func show_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)
	_feedback_label.pivot_offset = _feedback_label.size / 2.0
	if _feedback_tween != null:
		_feedback_tween.kill()
	_feedback_label.scale = Vector2.ONE * 1.5
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_feedback_label, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A quick pulse on any control (e.g. the button icon when you press it).
func pulse(node: Control, amount: float = 1.2) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2.ONE * amount
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.15)


# ---- Loop ----------------------------------------------------------------

func _process(delta: float) -> void:
	if _closed:
		return
	if not order.is_active():
		_close(false)
		return
	_age += delta
	if _result_timer >= 0.0:
		_result_timer -= delta
		if _result_timer <= 0.0:
			_close(true)
		return
	if _age >= INPUT_DELAY:
		if Input.is_action_just_pressed("cancel"):
			_close(false)
			return
		_poll()
	_tick(delta)


# ---- For subclasses ------------------------------------------------------

func _setup() -> void:
	pass


## Read the buttons (Input.is_action_just_pressed / is_action_pressed) once per frame.
func _poll() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


## The player switched between keyboard and controller (update any extra icons).
func _device_changed() -> void:
	pass


## Ends the game with a result (0..1). The result shows for a moment, then it closes.
func _finish(quality: float) -> void:
	order.quality = quality
	_stage_label.text = "Step done!" if order.has_more_steps() else "Dish done!"
	show_feedback("%s!" % quality_name(quality).to_upper(), quality_color(quality))
	_feedback_label.add_theme_font_size_override("font_size", 40)
	_result_timer = 1.2
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
