class_name Order
extends RefCounted
## One customer's order as it moves: ticket board -> burner -> player's hands -> customer.

var customer: Customer
var dish_id: String = ""
var table_number: int = 0
var seat_letter: String = "" # which chair at the table (A, B, C ...)
var time_left: float = 0.0
var done: bool = false
var quality: float = 0.75 # 0..1 from the cooking minigame (or a cook's skill)
var claimed: bool = false # a cook (on a ticket) or waiter (on a plate) is handling it
var step_index: int = 0 # which step of the recipe is being made now
var step_scores: Array[float] = [] # quality of each finished step


func _init(p_customer: Customer, p_dish: String, p_table: int, p_seat_letter: String = "") -> void:
	customer = p_customer
	dish_id = p_dish
	table_number = p_table
	seat_letter = p_seat_letter


## An order is only worth cooking while its customer is still waiting for food.
func is_active() -> bool:
	return is_instance_valid(customer) and customer.state == Customer.State.WAIT_FOOD


## Short label for tickets, plates and prompts: "T3-B" (table 3, chair B).
func where() -> String:
	if seat_letter == "":
		return "T%d" % table_number
	return "T%d-%s" % [table_number, seat_letter]


# ---- Recipe steps -----------------------------------------------------------

func steps() -> Array:
	return GameState.dish_steps(dish_id)


func step_count() -> int:
	return steps().size()


## The step being made right now (a dictionary: label, station, game, cookware, ...).
func step() -> Dictionary:
	var list := steps()
	return list[mini(step_index, list.size() - 1)]


func has_more_steps() -> bool:
	return step_index < step_count() - 1


func step_label() -> String:
	return str(step().get("label", "Cook"))


func step_station() -> String:
	return str(step().get("station", "stove"))


func step_game() -> String:
	return str(step().get("game", "timing"))


func step_cookware() -> String:
	return str(step().get("cookware", "pan"))


## Timing-game rounds for this step. Steps of a multi-step dish are shorter by default.
func step_rounds() -> int:
	var default_rounds := GameState.dish_rounds(dish_id) if step_count() == 1 else 2
	return int(step().get("rounds", default_rounds))


## "Step 2/3" for a multi-step dish, "" for a single-step one.
func step_text() -> String:
	if step_count() <= 1:
		return ""
	return "Step %d/%d" % [step_index + 1, step_count()]


## The model shown on the stove / counter: the ingredient for this step, else the finished dish.
func step_model_path() -> String:
	var paths: Array = step().get("models", [])
	for p in paths:
		if ResourceLoader.exists(p):
			return p
	return Food.model_path_for(dish_id)


## Records how well the current step went. The order's quality is the average of all steps.
func record_step(step_quality: float) -> void:
	step_scores.append(step_quality)
	var total := 0.0
	for q in step_scores:
		total += q
	quality = total / float(step_scores.size())


func advance() -> void:
	step_index += 1


func dish_name() -> String:
	return GameState.DISHES[dish_id]["name"]
