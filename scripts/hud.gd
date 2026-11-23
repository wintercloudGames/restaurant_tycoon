class_name Hud
extends CanvasLayer
## On-screen text and the shop panel (see hud.tscn).

@onready var money_label: Label = %MoneyLabel
@onready var toast_label: Label = %ToastLabel
@onready var prompt_label: Label = %PromptLabel
@onready var held_label: Label = %HeldLabel
@onready var shop_panel: PanelContainer = %ShopPanel
@onready var shop_box: VBoxContainer = %ShopBox

var _toast_id: int = 0
var _prompt_rich: RichTextLabel # shows the prompt with the button icon instead of "[E]"
var _prompt_text: String = ""

const KEYBOARD_HINT := "WASD move  |  Mouse / arrows look  |  E or Click interact  |  B shop  |  V build  |  P pause"
const CONTROLLER_HINT := "Left stick move  |  Right stick look  |  A interact  |  Y shop  |  View build  |  Menu pause"


func _ready() -> void:
	_prompt_rich = RichTextLabel.new()
	_prompt_rich.bbcode_enabled = true
	_prompt_rich.fit_content = true
	_prompt_rich.scroll_active = false
	_prompt_rich.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_rich.anchor_top = prompt_label.anchor_top
	_prompt_rich.anchor_bottom = prompt_label.anchor_bottom
	_prompt_rich.anchor_right = 1.0
	_prompt_rich.offset_bottom = 48
	_prompt_rich.add_theme_font_size_override("normal_font_size", 26)
	_prompt_rich.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt_rich.add_theme_constant_override("outline_size", 8)
	prompt_label.get_parent().add_child(_prompt_rich)
	prompt_label.visible = false
	Controls.device_changed.connect(func(_c: bool) -> void:
		_update_hint()
		_render_prompt())
	_update_hint.call_deferred()


## The look-at prompt ("[E] Take order"): "[E]" becomes the E key or the controller's A button.
func set_prompt(text: String) -> void:
	if text == _prompt_text:
		return
	_prompt_text = text
	_render_prompt()


func _render_prompt() -> void:
	var text := _prompt_text.replace("[", "[lb]") # keep other brackets as plain text
	text = text.replace("[lb]E] ", Controls.bb("interact", 36) + " ")
	_prompt_rich.text = "" if _prompt_text == "" else "[center]%s[/center]" % text


## The controls line at the top changes when you switch between keyboard and controller.
func _update_hint() -> void:
	var hint := get_node_or_null("Root/HintLabel") as Label
	if hint != null:
		hint.text = CONTROLLER_HINT if Controls.using_controller else KEYBOARD_HINT


func show_toast(text: String) -> void:
	toast_label.text = text
	_toast_id += 1
	var id := _toast_id
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if id == _toast_id:
			toast_label.text = "")


func clear_shop() -> void:
	for child in shop_box.get_children():
		child.queue_free()


func add_shop_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	shop_box.add_child(label)


func add_shop_button(text: String, enabled: bool, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(action)
	shop_box.add_child(b)
