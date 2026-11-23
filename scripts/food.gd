class_name Food
extends RefCounted
## Makes a food model for a dish. All food uses scenes/food.tscn, so edit that scene
## (fit size, fallback color) to change how all food looks. Each dish's model files are
## set in autoload/game_state.gd (the first file in the list that exists is used).


static func model_path_for(dish_id: String) -> String:
	var paths: Array = GameState.DISHES[dish_id].get("models", [])
	for p in paths:
		if ResourceLoader.exists(p):
			return p
	return paths[0] if not paths.is_empty() else ""


## The food model for the step an order is on (an ingredient, or the finished dish).
static func spawn_step(order: Order) -> Node3D:
	var scene := load("res://scenes/food.tscn") as PackedScene
	var food := scene.instantiate() as ModelSlot
	food.model_path = order.step_model_path()
	return food


const PLATE_MODEL := "res://assets/food-kit/plate.glb"
const PLATE_SIZE := Vector3(0.42, 0.04, 0.42)


## A plate model (used under every finished dish).
static func make_plate() -> ModelSlot:
	var plate := ModelSlot.new()
	plate.name = "PlateModel"
	plate.model_path = PLATE_MODEL
	plate.fit_size = PLATE_SIZE
	plate.fallback_color = Color(0.95, 0.95, 0.95)
	plate.fallback_cylinder = true
	return plate


## A finished dish served on a plate: on the order-up table, carried, and on the customer's table.
static func spawn_served(dish_id: String) -> Node3D:
	var root := Node3D.new()
	root.add_child(make_plate())
	var food := spawn(dish_id)
	food.position.y = 0.025
	root.add_child(food)
	return root


static func spawn(dish_id: String) -> Node3D:
	var scene := load("res://scenes/food.tscn") as PackedScene
	var food := scene.instantiate() as ModelSlot
	food.model_path = model_path_for(dish_id)
	return food
