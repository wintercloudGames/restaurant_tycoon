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
