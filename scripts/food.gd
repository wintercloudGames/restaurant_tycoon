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


static func spawn(dish_id: String) -> Node3D:
	var scene := load("res://scenes/food.tscn") as PackedScene
	var food := scene.instantiate() as ModelSlot
	food.model_path = model_path_for(dish_id)
	return food
