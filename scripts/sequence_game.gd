class_name SequenceGame
extends CookMinigame
## Assembly minigame (minigame_sequence.tscn): press the arrows shown, in order, before time runs
## out. Use the arrow keys or W A S D (up / left / down / right). Wrong directions cost quality.

const DIRECTIONS: Array[String] = ["up", "down", "left", "right"]
const ARROW_SIZE := 64

@export var time_limit: float = 9.0

var _seq: Array[String] = []
var _index: int = 0
var _mistakes: int = 0
var _elapsed: float = 0.0
var _cells: Array[TextureRect] = []

static var _arrow_cache: Dictionary = {}

@onready var _sequence_label: RichTextLabel = %Sequence # the old text row; hidden, arrows are drawn instead
@onready var _time_bar: ProgressBar = %TimeBar


func _setup() -> void:
	var length := 5 + int(round(3.0 * difficulty()))
	for i in length:
		_seq.append(DIRECTIONS.pick_random())
	_stage_label.text = "Press the arrows (or W A S D) in order!"
	var hint := get_node_or_null("Panel/Box/Hint") as Label
	if hint != null:
		hint.text = "Arrow keys or W A S D: up / left / down / right     Esc: cancel"
	_build_arrows()
	_refresh()


func _tick(delta: float) -> void:
	_elapsed += delta
	_time_bar.value = (1.0 - _elapsed / time_limit) * 100.0
	if _elapsed >= time_limit:
		# Out of time: burnt, a bit better the further you got.
		_finish(clampf(float(_index) / float(_seq.size()) * 0.5, 0.1, 0.5))


## One arrow picture per step, drawn in a row where the text used to be.
func _build_arrows() -> void:
	_sequence_label.visible = false
	var row := HBoxContainer.new()
	row.name = "Arrows"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var parent := _sequence_label.get_parent()
	parent.add_child(row)
	parent.move_child(row, _sequence_label.get_index())
	for dir in _seq:
		var cell := TextureRect.new()
		cell.texture = _arrow_texture(dir)
		cell.custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE)
		cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(cell)
		_cells.append(cell)


## Done arrows go green, the one to press now is big and yellow, the rest are white.
func _refresh() -> void:
	for i in _cells.size():
		var cell := _cells[i]
		if i < _index:
			cell.modulate = Color(0.35, 0.87, 0.4)
			cell.custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE) * 0.8
		elif i == _index:
			cell.modulate = Color(1.0, 0.85, 0.2)
			cell.custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE) * 1.15
		else:
			cell.modulate = Color(1, 1, 1, 0.85)
			cell.custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE) * 0.9


## "up", "down", "left" or "right" for an arrow key or W / S / A / D; "" for anything else.
static func direction_for_key(event: InputEventKey) -> String:
	for code in [event.keycode, event.physical_keycode]:
		match code:
			KEY_UP, KEY_W:
				return "up"
			KEY_DOWN, KEY_S:
				return "down"
			KEY_LEFT, KEY_A:
				return "left"
			KEY_RIGHT, KEY_D:
				return "right"
	return ""


func _game_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var dir := direction_for_key(event)
		if dir != "":
			get_viewport().set_input_as_handled()
			_press_key(dir)


func _press_key(dir: String) -> void:
	if _result_timer >= 0.0 or _index >= _seq.size():
		return
	if dir == _seq[_index]:
		_index += 1
		_feedback_label.text = ""
		Sfx.play(&"MinigamePress")
		_refresh()
		if _index >= _seq.size():
			# No mistakes = perfect; each mistake costs about 0.2.
			var n := float(_seq.size())
			_finish(clampf(n / (n + _mistakes * 1.5), 0.0, 1.0))
	else:
		_mistakes += 1
		_feedback_label.text = "Wrong direction!"
		_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		Sfx.play(&"MinigameMiss")


## A white arrow pointing `dir`, drawn from a few shapes (no font or image file needed).
static func _arrow_texture(dir: String) -> ImageTexture:
	if _arrow_cache.has(dir):
		return _arrow_cache[dir]
	var img := Image.create(ARROW_SIZE, ARROW_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var n := float(ARROW_SIZE)
	for y in ARROW_SIZE:
		for x in ARROW_SIZE:
			var fx := (float(x) + 0.5) / n
			var fy := (float(y) + 0.5) / n
			var inside := false
			if fy >= 0.06 and fy <= 0.52:
				inside = absf(fx - 0.5) <= (fy - 0.06) / 0.46 * 0.44 # the arrow head
			elif fy > 0.52 and fy <= 0.94:
				inside = absf(fx - 0.5) <= 0.16 # the shaft
			if inside:
				img.set_pixel(x, y, Color.WHITE)
	match dir:
		"down":
			img.rotate_180()
		"left":
			img.rotate_90(COUNTERCLOCKWISE)
		"right":
			img.rotate_90(CLOCKWISE)
	var tex := ImageTexture.create_from_image(img)
	_arrow_cache[dir] = tex
	return tex
