class_name Ticket
extends Area3D
## A paper order on the kitchen board. Click it to start cooking on a free burner.

var order: Order
var kitchen: Kitchen
var slot: int = 0

@onready var label: Label3D = $Label


func _ready() -> void:
	label.font_size = 24
	label.pixel_size = 0.0042
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = 100.0 # pixels: keeps the text inside the paper
	label.text = "%s\n%s" % [order.where(), order.dish_name()]
	if order.step_count() > 1:
		label.text += "\n%d/%d" % [order.step_index + 1, order.step_count()]


func get_prompt(_player: Player) -> String:
	var station := order.step_station()
	var where := "stove" if station == "stove" else "counter"
	if kitchen.has_free_burner(station):
		var step_info := "" if order.step_count() <= 1 else " - %s: %s" % [order.step_text().to_lower(), order.step_label()]
		return "[E] Put %s on the %s (%s)%s" % [order.dish_name(), where, order.where(), step_info]
	if station == "stove":
		return "No free burner! (build another stove?)"
	return "No free counter spot! (build another counter?)"


func interact(player: Player) -> void:
	kitchen.place_on_burner(self, player)
