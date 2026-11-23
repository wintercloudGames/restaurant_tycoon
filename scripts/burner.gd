class_name Burner
extends Area3D
## One cooking spot: a burner on a stove, or a prep spot on a counter (see burner.tscn,
## stove.tscn, counter.tscn). A ticket puts the food here (in a pan / pot / board / plate);
## press E on it to play the minigame. A hired cook can also use it.
## "Station" decides which dishes use it: "stove" or "counter" (a dish's "station" in
## autoload/game_state.gd). The models under "Cookware" are named Pan, Pot, Board, Plate.

signal cook_requested(burner: Burner, player: Player)

enum State { EMPTY, WAITING, PLAYER_COOKING, CHEF_COOKING }

@export_enum("stove", "counter") var station: String = "stove"
@export var food_scale: float = 0.7
@export var idle_color: Color = Color(0.1, 0.1, 0.1)
@export var waiting_color: Color = Color(0.6, 0.45, 0.1)
@export var busy_color: Color = Color(1.0, 0.35, 0.1)

var state: State = State.EMPTY
var order: Order
var status: String = ""
var disc_mat: StandardMaterial3D
var _food: Node3D
var _kitchen: Kitchen

@onready var disc: MeshInstance3D = $Disc
@onready var label: Label3D = $Label
@onready var cookware: Node3D = $Cookware
@onready var food_point: Marker3D = $FoodPoint


func _ready() -> void:
	disc_mat = (disc.mesh as CylinderMesh).material as StandardMaterial3D
	_set_cookware("")
	add_to_group("burners")
	# Burners sit close together, so the back row's label floats higher to keep them readable.
	label.position.y = 0.45 + (0.28 if position.z < -0.1 else 0.0)
	label.font_size = 30
	label.pixel_size = 0.005
	_register.call_deferred() # the kitchen exists once the whole scene is ready


func _register() -> void:
	if not is_inside_tree():
		return # removed again before the deferred call ran
	_kitchen = get_tree().get_first_node_in_group("kitchen") as Kitchen
	if _kitchen != null:
		_kitchen.register_burner(self)


func _exit_tree() -> void:
	if _kitchen != null and is_instance_valid(_kitchen):
		_kitchen.unregister_burner(self)


## False while the station this burner is on is being placed in build mode.
func is_available() -> bool:
	var node: Node = get_parent()
	while node != null:
		if node is PlacedItem and (node as PlacedItem).ghost:
			return false
		node = node.get_parent()
	return true


func is_free() -> bool:
	return state == State.EMPTY and is_available()


func is_cooking() -> bool:
	return state == State.PLAYER_COOKING or state == State.CHEF_COOKING


func _verb() -> String:
	return "cook" if station == "stove" else "prepare"


## Puts an order's food here (in its pan/pot/board). `by_chef` = a hired cook makes it,
## otherwise it waits for the player to press E.
func place(new_order: Order, by_chef: bool) -> void:
	order = new_order
	state = State.CHEF_COOKING if by_chef else State.WAITING
	status = "Chef 0%" if by_chef else "Press E"
	_set_cookware(order.step_cookware())
	_clear_food()
	_food = Food.spawn_step(order)
	_food.scale = Vector3.ONE * food_scale
	food_point.add_child(_food)
	Sfx.play(&"PutOnStove")


func begin_manual() -> void:
	state = State.PLAYER_COOKING
	status = "You"


func return_to_waiting() -> void:
	state = State.WAITING
	status = "Press E"


func clear() -> void:
	state = State.EMPTY
	order = null
	status = ""
	_set_cookware("")
	_clear_food()


func _set_cookware(kind: String) -> void:
	for child in cookware.get_children():
		(child as Node3D).visible = kind != "" and child.name.to_lower() == kind


func _clear_food() -> void:
	if _food != null and is_instance_valid(_food):
		_food.queue_free()
	_food = null


func get_prompt(_player: Player) -> String:
	match state:
		State.WAITING:
			if order.step_count() > 1:
				return "[E] %s: %s (%s)" % [order.step_label(), order.dish_name(), order.where()]
			return "[E] %s %s (%s)" % [_verb().capitalize(), order.dish_name(), order.where()]
		State.CHEF_COOKING:
			return "A chef is working on this"
	return ""


func interact(player: Player) -> void:
	if state == State.WAITING and not player.busy and is_available():
		cook_requested.emit(self, player)


func _process(_delta: float) -> void:
	if order != null and not order.is_active():
		clear() # the customer left, so stop
	if order == null:
		label.visible = false
		disc_mat.albedo_color = idle_color
		return
	label.visible = true
	var shown := status
	if state == State.WAITING:
		shown = "Press A" if Controls.using_controller else "Press E"
	label.text = "%s\n%s" % [order.where(), shown] if order.step_count() <= 1 else "%s\n%s\n%s" % [order.where(), order.step_text(), shown]
	if state == State.WAITING:
		label.modulate = Color(0.5, 1.0, 0.6)
		disc_mat.albedo_color = waiting_color
	else:
		label.modulate = Color(1.0, 0.85, 0.3)
		disc_mat.albedo_color = busy_color
