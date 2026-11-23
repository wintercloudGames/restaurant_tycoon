class_name Plate
extends Area3D
## A finished dish waiting on the order-up table. Take it yourself or let a waiter deliver it.

var order: Order
var pass_table: PassTable
var slot: int = 0

@onready var food: ModelSlot = $Food
@onready var label: Label3D = $Label


func _ready() -> void:
	food.model_path = Food.model_path_for(order.dish_id)
	add_child(Food.make_plate()) # finished food sits on a plate
	food.position.y += 0.025
	label.text = order.where()
	if order.quality >= 0.85:
		label.modulate = Color(1.0, 0.85, 0.2) # perfect
	elif order.quality < 0.55:
		label.modulate = Color(0.8, 0.5, 0.3) # burnt


func get_prompt(player: Player) -> String:
	if order.claimed:
		return "A waiter is getting this"
	if not player.can_carry_more():
		return "Your hands are full" if player.carry_capacity() == 1 else "Your tray is full (%d plates)" % player.carry_capacity()
	return "[E] Take %s (%s, %s)" % [
		order.dish_name(), order.where(), CookMinigame.quality_name(order.quality)]


func interact(player: Player) -> void:
	if order.claimed or not player.can_carry_more():
		return
	pass_table.remove_plate(self)
	player.add_held(order)
