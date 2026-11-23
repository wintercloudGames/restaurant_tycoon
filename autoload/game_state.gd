extends Node
## Global game state: money, upgrades, staff, saving and offline earnings.

signal changed
signal purchased # emitted after any successful purchase (used for the Buy sound)
signal rank_up(new_rank: int) # the restaurant reached a new rank
signal expanded(count: int) # a new floor was added to the restaurant

const SAVE_PATH := "user://save.json"
const MAX_OFFLINE_SECONDS := 8 * 3600
## A small restaurant only has room for a few tables; every expansion raises the limit (see max_tables).
const BASE_TABLES := 4
const TABLES_PER_EXPANSION := 3
const CHAIR_COST := 25
## Customers on a comfy (red) chair wait this many times longer before leaving.
const COMFY_CHAIR_PATIENCE := 1.5
const MAX_RANK := 20
const MAX_EXPANSIONS := 8
## What each expansion costs, the rank it needs, and what the new floor is called.
const EXPANSION_COSTS: Array[int] = [500, 1200, 2500, 4500, 7500, 12000, 18000, 26000]
const EXPANSION_RANKS: Array[int] = [2, 4, 6, 8, 10, 12, 14, 16]
const EXPANSION_NAMES: Array[String] = ["East wing", "West wing", "South hall", "South-east hall", "South-west hall", "Far south hall", "Far south-east hall", "Far south-west hall"]
const RANK_TITLES: Array[String] = ["Street Stall", "Street Stall", "Snack Bar", "Snack Bar", "Cafe", "Cafe", "Diner", "Diner", "Bistro", "Bistro", "Restaurant", "Restaurant", "Brasserie", "Brasserie", "Fine Dining", "Fine Dining", "Gourmet", "Gourmet", "Five Star", "Five Star"]
const MAX_COOKS := 4
const MAX_WAITERS := 3
const MAX_COOK_LEVEL := 10
const MAX_MARKETING := 5
const MAX_COMFORT := 5
## Serving Tray upgrade: each level lets you carry one more plate (1 plate without it).
const MAX_TRAY := 3
const TRAY_COSTS: Array[int] = [250, 700, 1500]
const TRAY_RANKS: Array[int] = [2, 5, 8]

# Every dish: rank (the restaurant rank needed to unlock it), price, cook_time (seconds for a hired cook), unlock cost, model files (the first
# one that exists is used), the cookware it sits in ("pan", "pot", "board" or "plate"),
# difficulty (0..1), the minigame ("timing" grill, "hold" fry/pour, "mash" stir/mix, "chop" chop/slice,
# "sequence" assemble) and the station that makes it: "stove" (needs a free burner) or
# "counter" (needs a free spot on a prep counter). Optional "rounds" = timing-game rounds.
# "steps" is the list of steps to make the dish. Each step has a label, the station it needs
# ("stove" or "counter"), its minigame and cookware, and optionally "models" (what the food looks
# like at that step) and "rounds". After each step the order goes back on the ticket board for the
# next one. The dish's final quality is the average of its steps, and more steps pay more.
# To add a dish, add an entry here - it shows up in the shop automatically.
const DISHES := {
	"burger": {"rank": 1, "name": "Burger", "price": 10, "cook_time": 4.0, "unlock": 0,
		"models": ["res://assets/food-kit/burger.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.20, "station": "stove",
		"steps": [
			{"label": "Grill patty", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/meat-patty.glb"]},
			{"label": "Build burger", "station": "counter", "game": "sequence", "cookware": "board", "models": ["res://assets/food-kit/bread.glb"]},
		]},
	"egg": {"rank": 1, "name": "Fried Egg", "price": 9, "cook_time": 3.0, "unlock": 40,
		"models": ["res://assets/food-kit/egg-cooked.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.15, "station": "stove",
		"steps": [
			{"label": "Fry egg", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/egg.glb"]},
		]},
	"sandwich": {"rank": 1, "name": "Sandwich", "price": 11, "cook_time": 3.0, "unlock": 50,
		"models": ["res://assets/food-kit/sandwich.glb"],
		"game": "sequence", "cookware": "board", "difficulty": 0.15, "station": "counter",
		"steps": [
			{"label": "Slice fillings", "station": "counter", "game": "chop", "cookware": "board", "models": ["res://assets/food-kit/cheese.glb"]},
			{"label": "Assemble", "station": "counter", "game": "sequence", "cookware": "board", "models": ["res://assets/food-kit/bread.glb"]},
		]},
	"soda": {"rank": 1, "name": "Soda", "price": 6, "cook_time": 2.0, "unlock": 60,
		"models": ["res://assets/food-kit/soda.glb"],
		"game": "hold", "cookware": "plate", "difficulty": 0.15, "station": "counter",
		"steps": [
			{"label": "Pour", "station": "counter", "game": "hold", "cookware": "plate"},
		]},
	"hotdog": {"rank": 1, "name": "Hot Dog", "price": 12, "cook_time": 4.0, "unlock": 80,
		"models": ["res://assets/food-kit/hot-dog.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.25, "station": "stove",
		"steps": [
			{"label": "Grill sausage", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/meat-sausage.glb"]},
			{"label": "Dress hot dog", "station": "counter", "game": "sequence", "cookware": "board", "models": ["res://assets/food-kit/bread.glb"]},
		]},
	"salad": {"rank": 2, "name": "Salad", "price": 12, "cook_time": 3.0, "unlock": 90,
		"models": ["res://assets/food-kit/salad.glb"],
		"game": "sequence", "cookware": "board", "difficulty": 0.20, "station": "counter",
		"steps": [
			{"label": "Chop veg", "station": "counter", "game": "chop", "cookware": "board", "models": ["res://assets/food-kit/cabbage.glb"]},
			{"label": "Toss salad", "station": "counter", "game": "sequence", "cookware": "board", "models": ["res://assets/food-kit/tomato.glb"]},
		]},
	"tea": {"rank": 2, "name": "Tea", "price": 7, "cook_time": 3.0, "unlock": 110,
		"models": ["res://assets/food-kit/cup-tea.glb"],
		"game": "hold", "cookware": "plate", "difficulty": 0.20, "station": "counter",
		"steps": [
			{"label": "Brew tea", "station": "counter", "game": "hold", "cookware": "plate"},
		]},
	"cheeseburger": {"rank": 2, "name": "Cheeseburger", "price": 13, "cook_time": 4.5, "unlock": 120,
		"models": ["res://assets/food-kit/burger-cheese.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.25, "station": "stove",
		"steps": [
			{"label": "Grill patty", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/meat-patty.glb"]},
			{"label": "Build burger", "station": "counter", "game": "sequence", "cookware": "board", "models": ["res://assets/food-kit/cheese.glb"]},
		]},
	"coffee": {"rank": 2, "name": "Coffee", "price": 8, "cook_time": 3.0, "unlock": 130,
		"models": ["res://assets/food-kit/cup-coffee.glb"],
		"game": "hold", "cookware": "plate", "difficulty": 0.25, "station": "counter",
		"steps": [
			{"label": "Grind beans", "station": "counter", "game": "mash", "cookware": "plate"},
			{"label": "Pour coffee", "station": "counter", "game": "hold", "cookware": "plate"},
		]},
	"bacon": {"rank": 2, "name": "Bacon", "price": 12, "cook_time": 4.0, "unlock": 140,
		"models": ["res://assets/food-kit/bacon.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.30, "station": "stove",
		"steps": [
			{"label": "Fry bacon", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/meat-raw.glb"]},
			{"label": "Plate bacon", "station": "counter", "game": "sequence", "cookware": "plate"},
		]},
	"donut": {"rank": 2, "name": "Donut", "price": 9, "cook_time": 3.0, "unlock": 150,
		"models": ["res://assets/food-kit/donut.glb", "res://assets/food-kit/donut-sprinkles.glb"],
		"game": "hold", "cookware": "plate", "difficulty": 0.20, "station": "counter",
		"steps": [
			{"label": "Fry dough", "station": "stove", "game": "hold", "cookware": "pot", "models": ["res://assets/food-kit/bread.glb"]},
			{"label": "Glaze", "station": "counter", "game": "sequence", "cookware": "plate", "models": ["res://assets/food-kit/chocolate.glb"]},
		]},
	"corndog": {"rank": 3, "name": "Corn Dog", "price": 13, "cook_time": 4.5, "unlock": 160,
		"models": ["res://assets/food-kit/corn-dog.glb"],
		"game": "hold", "cookware": "pot", "difficulty": 0.30, "station": "stove",
		"steps": [
			{"label": "Dip sausage", "station": "counter", "game": "timing", "cookware": "board", "models": ["res://assets/food-kit/meat-sausage.glb"]},
			{"label": "Fry corn dog", "station": "stove", "game": "hold", "cookware": "pot"},
		]},
	"fries": {"rank": 3, "name": "Fries", "price": 14, "cook_time": 5.0, "unlock": 200,
		"models": ["res://assets/food-kit/fries.glb"],
		"game": "hold", "cookware": "pot", "difficulty": 0.30, "station": "stove",
		"steps": [
			{"label": "Cut potatoes", "station": "counter", "game": "chop", "cookware": "board", "models": ["res://assets/food-kit/carrot.glb"]},
			{"label": "Fry", "station": "stove", "game": "hold", "cookware": "pot"},
		]},
	"cupcake": {"rank": 3, "name": "Cupcake", "price": 10, "cook_time": 3.0, "unlock": 200,
		"models": ["res://assets/food-kit/cupcake.glb"],
		"game": "sequence", "cookware": "plate", "difficulty": 0.25, "station": "counter",
		"steps": [
			{"label": "Bake", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/bread.glb"]},
			{"label": "Decorate", "station": "counter", "game": "sequence", "cookware": "plate", "models": ["res://assets/food-kit/whipped-cream.glb"]},
		]},
	"icecream": {"rank": 3, "name": "Ice Cream", "price": 14, "cook_time": 3.0, "unlock": 220,
		"models": ["res://assets/food-kit/ice-cream.glb"],
		"game": "mash", "cookware": "plate", "difficulty": 0.25, "station": "counter",
		"steps": [
			{"label": "Scoop", "station": "counter", "game": "mash", "cookware": "plate", "models": ["res://assets/food-kit/ice-cream-scoop-chocolate.glb"]},
		]},
	"broth": {"rank": 3, "name": "Broth", "price": 16, "cook_time": 5.0, "unlock": 250,
		"models": ["res://assets/food-kit/bowl-broth.glb"],
		"game": "mash", "cookware": "pot", "difficulty": 0.30, "station": "stove",
		"steps": [
			{"label": "Chop veg", "station": "counter", "game": "chop", "cookware": "board", "models": ["res://assets/food-kit/onion.glb"]},
			{"label": "Simmer broth", "station": "stove", "game": "mash", "cookware": "pot"},
		]},
	"sub": {"rank": 3, "name": "Sub", "price": 15, "cook_time": 4.0, "unlock": 280,
		"models": ["res://assets/food-kit/sub.glb"],
		"game": "sequence", "cookware": "board", "difficulty": 0.30, "station": "counter",
		"steps": [
			{"label": "Assemble sub", "station": "counter", "game": "sequence", "cookware": "board", "models": ["res://assets/food-kit/bread.glb"]},
		]},
	"sausage": {"rank": 3, "name": "Sausage", "price": 15, "cook_time": 5.0, "unlock": 300,
		"models": ["res://assets/food-kit/sausage.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.35, "station": "stove",
		"steps": [
			{"label": "Grill sausage", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/meat-sausage.glb"]},
			{"label": "Plate sausage", "station": "counter", "game": "sequence", "cookware": "plate"},
		]},
	"pancakes": {"rank": 4, "name": "Pancakes", "price": 16, "cook_time": 5.0, "unlock": 350,
		"models": ["res://assets/food-kit/pancakes.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.35, "station": "stove",
		"steps": [
			{"label": "Mix batter", "station": "counter", "game": "mash", "cookware": "board", "models": ["res://assets/food-kit/egg.glb"]},
			{"label": "Cook pancakes", "station": "stove", "game": "timing", "cookware": "pan"},
		]},
	"taco": {"rank": 4, "name": "Taco", "price": 17, "cook_time": 4.0, "unlock": 380,
		"models": ["res://assets/food-kit/taco.glb"],
		"game": "sequence", "cookware": "board", "difficulty": 0.35, "station": "counter",
		"steps": [
			{"label": "Cook filling", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/meat-raw.glb"]},
			{"label": "Fill taco", "station": "counter", "game": "sequence", "cookware": "board", "models": ["res://assets/food-kit/tomato-slice.glb"]},
		]},
	"soup": {"rank": 4, "name": "Soup", "price": 18, "cook_time": 6.0, "unlock": 400,
		"models": ["res://assets/food-kit/bowl-soup.glb"],
		"game": "mash", "cookware": "pot", "difficulty": 0.35, "station": "stove",
		"steps": [
			{"label": "Chop veg", "station": "counter", "game": "chop", "cookware": "board", "models": ["res://assets/food-kit/carrot.glb"]},
			{"label": "Simmer soup", "station": "stove", "game": "mash", "cookware": "pot"},
		]},
	"doubleburger": {"rank": 4, "name": "Double Burger", "price": 18, "cook_time": 5.0, "unlock": 450,
		"models": ["res://assets/food-kit/burger-double.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.40, "station": "stove",
		"steps": [
			{"label": "Grill patties", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/meat-patty.glb"]},
			{"label": "Toast buns", "station": "stove", "game": "hold", "cookware": "pan", "models": ["res://assets/food-kit/bread.glb"]},
			{"label": "Stack burger", "station": "counter", "game": "sequence", "cookware": "board"},
		]},
	"waffle": {"rank": 4, "name": "Waffle", "price": 18, "cook_time": 5.0, "unlock": 450,
		"models": ["res://assets/food-kit/waffle.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.30, "station": "stove",
		"steps": [
			{"label": "Mix batter", "station": "counter", "game": "mash", "cookware": "board", "models": ["res://assets/food-kit/egg.glb"]},
			{"label": "Cook waffle", "station": "stove", "game": "timing", "cookware": "pan"},
		]},
	"pizza": {"rank": 5, "name": "Pizza", "price": 25, "cook_time": 7.0, "unlock": 700,
		"models": ["res://assets/food-kit/pizza.glb"],
		"game": "sequence", "cookware": "board", "difficulty": 0.45, "station": "counter",
		"steps": [
			{"label": "Knead dough", "station": "counter", "game": "mash", "cookware": "board", "models": ["res://assets/food-kit/bread.glb"]},
			{"label": "Add toppings", "station": "counter", "game": "sequence", "cookware": "board", "models": ["res://assets/food-kit/cheese.glb"]},
			{"label": "Bake pizza", "station": "stove", "game": "timing", "cookware": "pan"},
		]},
	"sundae": {"rank": 5, "name": "Sundae", "price": 22, "cook_time": 5.0, "unlock": 800,
		"models": ["res://assets/food-kit/sundae.glb"],
		"game": "mash", "cookware": "plate", "difficulty": 0.45, "station": "counter",
		"steps": [
			{"label": "Scoop", "station": "counter", "game": "mash", "cookware": "plate", "models": ["res://assets/food-kit/ice-cream-scoop-mint.glb"]},
			{"label": "Top sundae", "station": "counter", "game": "sequence", "cookware": "plate", "models": ["res://assets/food-kit/whipped-cream.glb"]},
		]},
	"frappe": {"rank": 6, "name": "Frappe", "price": 20, "cook_time": 4.0, "unlock": 900,
		"models": ["res://assets/food-kit/frappe.glb"],
		"game": "hold", "cookware": "plate", "difficulty": 0.45, "station": "counter",
		"steps": [
			{"label": "Blend", "station": "counter", "game": "mash", "cookware": "plate", "models": ["res://assets/food-kit/ice-cream.glb"]},
			{"label": "Top with cream", "station": "counter", "game": "sequence", "cookware": "plate", "models": ["res://assets/food-kit/whipped-cream.glb"]},
		]},
	"doublecheese": {"rank": 6, "name": "Double Cheese", "price": 24, "cook_time": 5.5, "unlock": 900,
		"models": ["res://assets/food-kit/burger-cheese-double.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.50, "station": "stove",
		"steps": [
			{"label": "Grill patties", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/meat-patty.glb"]},
			{"label": "Melt cheese", "station": "stove", "game": "hold", "cookware": "pan", "models": ["res://assets/food-kit/cheese.glb"]},
			{"label": "Stack burger", "station": "counter", "game": "sequence", "cookware": "board"},
		]},
	"dimsum": {"rank": 7, "name": "Dim Sum", "price": 26, "cook_time": 6.0, "unlock": 1000,
		"models": ["res://assets/food-kit/dim-sum.glb"],
		"game": "hold", "cookware": "pot", "difficulty": 0.50, "station": "stove",
		"steps": [
			{"label": "Fold dumplings", "station": "counter", "game": "sequence", "cookware": "board", "models": ["res://assets/food-kit/onion.glb"]},
			{"label": "Steam", "station": "stove", "game": "hold", "cookware": "pot"},
		]},
	"pasta": {"rank": 7, "name": "Pasta", "price": 28, "cook_time": 7.0, "unlock": 1100,
		"models": ["res://assets/food-kit/chinese.glb", "res://assets/food-kit/plate-deep.glb"],
		"game": "mash", "cookware": "pot", "difficulty": 0.55, "station": "stove",
		"steps": [
			{"label": "Boil pasta", "station": "stove", "game": "mash", "cookware": "pot"},
			{"label": "Sauce and plate", "station": "counter", "game": "sequence", "cookware": "plate", "models": ["res://assets/food-kit/tomato.glb"]},
		]},
	"fish": {"rank": 8, "name": "Grilled Fish", "price": 30, "cook_time": 7.0, "unlock": 1300,
		"models": ["res://assets/food-kit/fish.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.60, "station": "stove",
		"steps": [
			{"label": "Season fish", "station": "counter", "game": "mash", "cookware": "board", "models": ["res://assets/food-kit/fish.glb"]},
			{"label": "Grill fish", "station": "stove", "game": "timing", "cookware": "pan"},
			{"label": "Plate fish", "station": "counter", "game": "sequence", "cookware": "plate"},
		]},
	"eggsushi": {"rank": 9, "name": "Egg Sushi", "price": 32, "cook_time": 7.0, "unlock": 1500,
		"models": ["res://assets/food-kit/sushi-egg.glb"],
		"game": "sequence", "cookware": "board", "difficulty": 0.60, "station": "counter",
		"steps": [
			{"label": "Cook rice", "station": "stove", "game": "mash", "cookware": "pot", "models": ["res://assets/food-kit/rice-ball.glb"]},
			{"label": "Roll sushi", "station": "counter", "game": "sequence", "cookware": "board", "models": ["res://assets/food-kit/egg.glb"]},
		]},
	"cake": {"rank": 9, "name": "Cake", "price": 30, "cook_time": 8.0, "unlock": 1600,
		"models": ["res://assets/food-kit/cake.glb"],
		"game": "sequence", "cookware": "plate", "difficulty": 0.60, "station": "counter",
		"steps": [
			{"label": "Bake cake", "station": "stove", "game": "timing", "cookware": "pan", "models": ["res://assets/food-kit/bread.glb"]},
			{"label": "Decorate", "station": "counter", "game": "sequence", "cookware": "plate", "models": ["res://assets/food-kit/whipped-cream.glb"]},
		]},
	"cocktail": {"rank": 10, "name": "Cocktail", "price": 28, "cook_time": 5.0, "unlock": 1700,
		"models": ["res://assets/food-kit/cocktail.glb"],
		"game": "hold", "cookware": "plate", "difficulty": 0.60, "station": "counter",
		"steps": [
			{"label": "Mix", "station": "counter", "game": "sequence", "cookware": "plate", "models": ["res://assets/food-kit/lemon.glb"]},
			{"label": "Pour", "station": "counter", "game": "hold", "cookware": "plate"},
		]},
	"steak": {"rank": 10, "name": "Steak", "price": 38, "cook_time": 8.0, "unlock": 1800,
		"models": ["res://assets/food-kit/meat-cooked.glb", "res://assets/food-kit/meat-ribs.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.70, "station": "stove", "rounds": 4,
		"steps": [
			{"label": "Season steak", "station": "counter", "game": "mash", "cookware": "board", "models": ["res://assets/food-kit/meat-raw.glb"]},
			{"label": "Sear steak", "station": "stove", "game": "timing", "cookware": "pan", "rounds": 4},
			{"label": "Plate steak", "station": "counter", "game": "sequence", "cookware": "plate"},
		]},
	"maki": {"rank": 11, "name": "Maki Roll", "price": 36, "cook_time": 8.0, "unlock": 2000,
		"models": ["res://assets/food-kit/maki-salmon.glb"],
		"game": "sequence", "cookware": "board", "difficulty": 0.70, "station": "counter",
		"steps": [
			{"label": "Cook rice", "station": "stove", "game": "mash", "cookware": "pot", "models": ["res://assets/food-kit/rice-ball.glb"]},
			{"label": "Slice fish", "station": "counter", "game": "chop", "cookware": "board", "models": ["res://assets/food-kit/fish.glb"]},
			{"label": "Roll maki", "station": "counter", "game": "sequence", "cookware": "board"},
		]},
	"pie": {"rank": 12, "name": "Pie", "price": 34, "cook_time": 8.0, "unlock": 2200,
		"models": ["res://assets/food-kit/pie.glb"],
		"game": "hold", "cookware": "plate", "difficulty": 0.60, "station": "counter",
		"steps": [
			{"label": "Make crust", "station": "counter", "game": "mash", "cookware": "board", "models": ["res://assets/food-kit/bread.glb"]},
			{"label": "Bake pie", "station": "stove", "game": "timing", "cookware": "pan"},
		]},
	"ribs": {"rank": 12, "name": "Ribs", "price": 44, "cook_time": 9.0, "unlock": 2400,
		"models": ["res://assets/food-kit/meat-ribs.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.75, "station": "stove", "rounds": 4,
		"steps": [
			{"label": "Season ribs", "station": "counter", "game": "mash", "cookware": "board", "models": ["res://assets/food-kit/meat-raw.glb"]},
			{"label": "Slow-grill ribs", "station": "stove", "game": "timing", "cookware": "pan", "rounds": 4},
			{"label": "Plate ribs", "station": "counter", "game": "sequence", "cookware": "plate"},
		]},
	"tajine": {"rank": 13, "name": "Tajine", "price": 48, "cook_time": 9.0, "unlock": 3000,
		"models": ["res://assets/food-kit/tajine.glb"],
		"game": "mash", "cookware": "pot", "difficulty": 0.75, "station": "stove",
		"steps": [
			{"label": "Chop veg", "station": "counter", "game": "chop", "cookware": "board", "models": ["res://assets/food-kit/carrot.glb"]},
			{"label": "Slow cook", "station": "stove", "game": "mash", "cookware": "pot"},
			{"label": "Plate tajine", "station": "counter", "game": "sequence", "cookware": "plate"},
		]},
	"sushi": {"rank": 14, "name": "Sushi", "price": 50, "cook_time": 9.0, "unlock": 3000,
		"models": ["res://assets/food-kit/sushi-salmon.glb"],
		"game": "sequence", "cookware": "board", "difficulty": 0.80, "station": "counter",
		"steps": [
			{"label": "Cook rice", "station": "stove", "game": "mash", "cookware": "pot", "models": ["res://assets/food-kit/rice-ball.glb"]},
			{"label": "Slice fish", "station": "counter", "game": "chop", "cookware": "board", "models": ["res://assets/food-kit/fish.glb"]},
			{"label": "Roll sushi", "station": "counter", "game": "sequence", "cookware": "board"},
		]},
	"turkey": {"rank": 16, "name": "Roast Turkey", "price": 60, "cook_time": 11.0, "unlock": 4500,
		"models": ["res://assets/food-kit/turkey.glb"],
		"game": "timing", "cookware": "pan", "difficulty": 0.85, "station": "stove", "rounds": 5,
		"steps": [
			{"label": "Season turkey", "station": "counter", "game": "mash", "cookware": "board", "models": ["res://assets/food-kit/meat-raw.glb"]},
			{"label": "Roast turkey", "station": "stove", "game": "timing", "cookware": "pan", "rounds": 5},
			{"label": "Carve and plate", "station": "counter", "game": "sequence", "cookware": "plate"},
		]},
}

var money: int = 0
var table_count: int = 1 # a new restaurant starts with one table (with one chair)
var cook_level: int = 0
var cook_count: int = 0
var xp: int = 0 # experience; the restaurant's rank comes from it
var expansions: int = 0 # extra floors added to the restaurant
var marketing_level: int = 0 # customers arrive faster
var comfort_level: int = 0 # customers wait longer
var tray_level: int = 0 # Serving Tray upgrade: carry 1 + tray_level plates
var waiter_count: int = 0
var unlocked_dishes: Array = ["burger"]
var placed: Array = [] # decor placed in build mode: [{id, x, z, rot}]
var table_layout: Dictionary = {} # table number (as text) -> {x, z, rot, seats, chairs}
var table_owned: Dictionary = {} # table number (as text) -> true/false; empty = the first `table_count` tables
## Seconds left on the "2x cash" bonus (from a rewarded ad). Counts down only while the game runs.
var boost_time_left: float = 0.0
## True when there was no save to load: a brand-new restaurant (one table, one chair).
var is_new_game: bool = false
## Offline earnings paid on the last load (the welcome screen can double them with an ad).
var last_offline_earned: int = 0

const SAVE_KEY := "restaurant_tycoon_save"
const BOOST_SECONDS := 180.0


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 15.0
	timer.autostart = true
	timer.timeout.connect(save_game)
	add_child(timer)


func _process(delta: float) -> void:
	if boost_time_left > 0.0:
		boost_time_left = maxf(boost_time_left - delta, 0.0)
		if boost_time_left == 0.0:
			changed.emit()


func _notification(what: int) -> void:
	# On the web there is no close request: save when the tab is hidden or loses focus instead.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT 			or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


## Money earned by serving customers (the 2x boost applies to this, not to refunds).
func earn(amount: int) -> void:
	add_money(amount * (2 if boost_time_left > 0.0 else 1))


func start_boost() -> void:
	boost_time_left += BOOST_SECONDS
	changed.emit()


# ---- Economy -------------------------------------------------------------

func add_money(amount: int) -> void:
	money += amount
	changed.emit()


func spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	changed.emit()
	return true


## Time a hired cook needs for a dish. Upgrades make it shorter.
func cook_time(dish_id: String) -> float:
	return float(DISHES[dish_id]["cook_time"]) * pow(0.9, cook_level)


func random_unlocked_dish() -> String:
	return unlocked_dishes.pick_random()


# ---- Rank (level) ---------------------------------------------------------
## Serving customers earns XP. Rank unlocks dishes, build items, upgrade levels, staff and
## expansions: every one of them has a "rank" it needs.

## Total XP needed to reach rank `n` (rank 1 is free: 0, rank 2: 100, rank 3: 300, ...).
static func xp_for_rank(n: int) -> int:
	return 50 * n * (n - 1)


func rank() -> int:
	for r in range(MAX_RANK, 1, -1):
		if xp >= xp_for_rank(r):
			return r
	return 1


func rank_title(r: int = -1) -> String:
	if r < 1:
		r = rank()
	return RANK_TITLES[clampi(r, 1, MAX_RANK) - 1]


## [xp earned inside this rank, xp needed to finish this rank] for the progress bar.
func rank_progress() -> Vector2i:
	var r := rank()
	if r >= MAX_RANK:
		return Vector2i(1, 1)
	return Vector2i(xp - xp_for_rank(r), xp_for_rank(r + 1) - xp_for_rank(r))


func meets_rank(required: int) -> bool:
	return rank() >= required


func add_xp(amount: int) -> void:
	var before := rank()
	xp += amount
	changed.emit()
	var after := rank()
	if after > before:
		rank_up.emit(after)


## XP for serving one plate: more for pricier dishes and for better quality.
func xp_for_plate(price: int, quality: float) -> int:
	return int(round((6.0 + price * 0.5) * (0.6 + 0.4 * clampf(quality, 0.0, 1.0))))


## Names of everything that unlocks at exactly rank `r` (for the rank-up message).
func unlocks_at_rank(r: int) -> Array[String]:
	var list: Array[String] = []
	for id in DISHES:
		if dish_rank(id) == r:
			list.append(str(DISHES[id]["name"]))
	for d in BuildCatalog.ITEMS:
		if BuildCatalog.rank_of(d) == r:
			list.append(str(d["name"]))
	for i in TRAY_RANKS.size():
		if TRAY_RANKS[i] == r:
			list.append("Serving Tray Lv %d" % (i + 1))
	for i in EXPANSION_RANKS.size():
		if EXPANSION_RANKS[i] == r:
			list.append("Expansion: %s" % EXPANSION_NAMES[i])
	return list


func dish_rank(id: String) -> int:
	return int(DISHES[id].get("rank", 1))


## The rank needed for the NEXT level of each upgrade / hire.
func cook_upgrade_rank() -> int:
	return 1 + cook_level

func marketing_rank() -> int:
	return 2 + 2 * marketing_level

func tray_rank() -> int:
	return TRAY_RANKS[mini(tray_level, MAX_TRAY - 1)]


func tray_cost() -> int:
	return TRAY_COSTS[mini(tray_level, MAX_TRAY - 1)]


## How many plates the player can carry at once.
func carry_capacity() -> int:
	return 1 + tray_level


func buy_tray() -> bool:
	if tray_level >= MAX_TRAY or rank() < tray_rank() or not spend(tray_cost()):
		return false
	tray_level += 1
	changed.emit()
	purchased.emit()
	return true


func comfort_rank() -> int:
	return 3 + 2 * comfort_level

func cook_hire_rank() -> int:
	return [3, 6, 9, 12][mini(cook_count, 3)]

func waiter_hire_rank() -> int:
	return [2, 5, 8][mini(waiter_count, 2)]

## The rank needed for a table with this many chairs.
func table_rank(seats: int) -> int:
	return {1: 1, 2: 1, 3: 2, 4: 3, 5: 5, 6: 6, 7: 7, 8: 8}.get(seats, 1) as int


# ---- Expansions -----------------------------------------------------------

## How many tables you may own: 4 in the starting room, +3 for each expansion you buy.
func max_tables() -> int:
	return BASE_TABLES + TABLES_PER_EXPANSION * expansions

func expansion_cost() -> int:
	return EXPANSION_COSTS[mini(expansions, MAX_EXPANSIONS - 1)]

func expansion_rank() -> int:
	return EXPANSION_RANKS[mini(expansions, MAX_EXPANSIONS - 1)]


func buy_expansion() -> bool:
	if expansions >= MAX_EXPANSIONS or rank() < expansion_rank() or not spend(expansion_cost()):
		return false
	expansions += 1
	changed.emit()
	purchased.emit()
	expanded.emit(expansions)
	return true


## Total appeal of the decor you've placed. Every point adds +1% to tips (max +50%).
func decor_appeal() -> int:
	var total := 0
	for d in placed:
		total += BuildCatalog.appeal_of(str(d.get("id", "")))
	return total


func tip_multiplier() -> float:
	return 1.0 + minf(0.5, decor_appeal() * 0.01)


## The steps for a dish. Dishes without a "steps" list are one step made from their own
## station / game / cookware.
func dish_steps(id: String) -> Array:
	var d: Dictionary = DISHES[id]
	if d.has("steps"):
		return d["steps"]
	return [{"label": "Cook", "station": dish_station(id), "game": dish_game(id), "cookware": dish_cookware(id)}]


## What a plate of this dish pays: the listed price, +20% for every step after the first.
func dish_price(id: String) -> int:
	return int(round(float(DISHES[id]["price"]) * (1.0 + 0.2 * (dish_steps(id).size() - 1))))


func dish_game(id: String) -> String:
	return str(DISHES[id].get("game", "timing"))


func dish_difficulty(id: String) -> float:
	return float(DISHES[id].get("difficulty", 0.3))


func dish_station(id: String) -> String:
	return str(DISHES[id].get("station", "stove"))


func dish_cookware(id: String) -> String:
	return str(DISHES[id].get("cookware", "pan"))


func dish_rounds(id: String) -> int:
	return int(DISHES[id].get("rounds", 3))


func income_per_second() -> float:
	var total := 0.0
	for id in unlocked_dishes:
		total += float(dish_price(id))
	var avg := total / maxf(1.0, float(unlocked_dishes.size()))
	# About 60% of the chairs are in use, and a party takes ~20 seconds to be served.
	var chairs := 0
	for n in range(1, max_tables() + 10):
		if is_table_owned(n):
			chairs += table_chairs(n)
	var rate := float(chairs) * 0.6 * avg / 20.0
	# Staff keep the restaurant running while you're away.
	var staff := float(mini(cook_count, 2) + mini(waiter_count, 2)) / 4.0
	return rate * (0.25 + 0.75 * clampf(staff, 0.0, 1.0))


# ---- Upgrades ------------------------------------------------------------

## The base price of a table that seats this many (2, 4 or 6). Tables come WITHOUT chairs.
func table_base_price(seats: int) -> int:
	return {1: 60, 2: 90, 3: 120, 4: 160, 5: 200, 6: 250, 7: 300, 8: 350}.get(seats, 90 * seats / 2) as int


## Price of the next table: the base price, rising a little with each table you own.
func table_cost(seats: int = 2) -> int:
	return int(table_base_price(seats) * (1.0 + 0.2 * maxi(table_count - 2, 0)))


## Whether table number `n` is bought. Before any table is bought or sold this is just the first
## `table_count` tables; after that each table is tracked on its own, so you can sell any of them.
func is_table_owned(n: int) -> bool:
	if table_owned.is_empty():
		return n <= table_count
	return bool(table_owned.get(str(n), false))


func first_free_table_number() -> int:
	for n in range(1, 100):
		if not is_table_owned(n):
			return n
	return 100


func _ensure_owned_map() -> void:
	if table_owned.is_empty():
		for n in range(1, table_count + 1):
			table_owned[str(n)] = true


## Sells table `number` (build mode refunds its price and its chairs' price).
func sell_table(number: int) -> void:
	_ensure_owned_map()
	table_owned[str(number)] = false
	table_count = maxi(table_count - 1, 0)
	changed.emit()


## How many chairs table `number` has (saved with the build layout; starter tables are full).
func table_chairs(number: int) -> int:
	var d = table_layout.get(str(number))
	if d is Dictionary and d.has("chairs"):
		return (d["chairs"] as Array).size()
	return table_seats(number)


## How many chairs table number `number` has (saved with the build layout).
func table_seats(number: int) -> int:
	var d = table_layout.get(str(number))
	if d is Dictionary:
		return int(d.get("seats", 2))
	return 2

func cook_cost() -> int:
	return 60 * (cook_level + 1)

func marketing_cost() -> int:
	return 200 * (marketing_level + 1)

func comfort_cost() -> int:
	return 150 * (comfort_level + 1)

## Multiplier on the time between customers (smaller = more customers).
func spawn_interval_multiplier() -> float:
	return pow(0.9, marketing_level)

## Multiplier on how long customers wait before leaving.
func patience_multiplier() -> float:
	return 1.0 + 0.15 * comfort_level

func cook_hire_cost() -> int:
	return 300 * (cook_count + 1)

func waiter_hire_cost() -> int:
	return 400 * (waiter_count + 1)


func buy_table(seats: int = 2, number: int = -1) -> bool:
	if table_count >= max_tables() or rank() < table_rank(seats) or not spend(table_cost(seats)):
		return false
	_ensure_owned_map()
	if number < 0:
		number = first_free_table_number()
	table_owned[str(number)] = true
	table_count += 1
	changed.emit()
	purchased.emit()
	return true


func buy_cook_upgrade() -> bool:
	if cook_level >= MAX_COOK_LEVEL or rank() < cook_upgrade_rank() or not spend(cook_cost()):
		return false
	cook_level += 1
	changed.emit()
	purchased.emit()
	return true


func buy_marketing() -> bool:
	if marketing_level >= MAX_MARKETING or rank() < marketing_rank() or not spend(marketing_cost()):
		return false
	marketing_level += 1
	changed.emit()
	purchased.emit()
	return true


func buy_comfort() -> bool:
	if comfort_level >= MAX_COMFORT or rank() < comfort_rank() or not spend(comfort_cost()):
		return false
	comfort_level += 1
	changed.emit()
	purchased.emit()
	return true


func hire_cook() -> bool:
	if cook_count >= MAX_COOKS or rank() < cook_hire_rank() or not spend(cook_hire_cost()):
		return false
	cook_count += 1
	changed.emit()
	purchased.emit()
	return true


func hire_waiter() -> bool:
	if waiter_count >= MAX_WAITERS or rank() < waiter_hire_rank() or not spend(waiter_hire_cost()):
		return false
	waiter_count += 1
	changed.emit()
	purchased.emit()
	return true


func unlock_dish(id: String) -> bool:
	if id in unlocked_dishes or rank() < dish_rank(id) or not spend(int(DISHES[id]["unlock"])):
		return false
	unlocked_dishes.append(id)
	changed.emit()
	purchased.emit()
	return true


# ---- Save / load ---------------------------------------------------------

func save_game() -> void:
	var data := {
		"money": money,
		"table_count": table_count,
		"cook_level": cook_level,
		"cook_count": cook_count,
		"marketing_level": marketing_level,
		"comfort_level": comfort_level,
		"tray_level": tray_level,
		"waiter_count": waiter_count,
		"unlocked_dishes": unlocked_dishes,
		"xp": xp,
		"expansions": expansions,
		"placed": placed,
		"table_layout": table_layout,
		"table_owned": table_owned,
		"boost_time_left": boost_time_left,
		"last_time": Time.get_unix_time_from_system(),
	}
	var text := JSON.stringify(data)
	if CrazyGames.has_data():
		CrazyGames.set_item(SAVE_KEY, text) # synced to the player's CrazyGames account
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)


## The saved JSON text: CrazyGames' storage first (on their site), then the local file.
func _read_save_text() -> String:
	if CrazyGames.has_data():
		var cloud := CrazyGames.get_item(SAVE_KEY)
		if cloud != "":
			return cloud
	if not FileAccess.file_exists(SAVE_PATH):
		return ""
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	return f.get_as_text() if f != null else ""


## Loads the save and returns the offline earnings that were paid out.
func load_game() -> int:
	last_offline_earned = 0
	is_new_game = false
	var text := _read_save_text()
	if text == "":
		is_new_game = true
		return 0
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return 0
	money = int(data.get("money", 0))
	table_count = clampi(int(data.get("table_count", 2)), 0, 100) # tables can be sold, so there is no minimum
	cook_level = int(data.get("cook_level", 0))
	cook_count = clampi(int(data.get("cook_count", 0)), 0, MAX_COOKS)
	marketing_level = clampi(int(data.get("marketing_level", 0)), 0, MAX_MARKETING)
	comfort_level = clampi(int(data.get("comfort_level", 0)), 0, MAX_COMFORT)
	tray_level = clampi(int(data.get("tray_level", 0)), 0, MAX_TRAY)
	# Old saves had a single "auto_serve" waiter flag.
	var default_waiters := 1 if bool(data.get("auto_serve", false)) else 0
	waiter_count = clampi(int(data.get("waiter_count", default_waiters)), 0, MAX_WAITERS)
	unlocked_dishes = data.get("unlocked_dishes", ["burger"])
	xp = maxi(int(data.get("xp", 0)), 0)
	expansions = clampi(int(data.get("expansions", 0)), 0, MAX_EXPANSIONS)
	placed = data.get("placed", [])
	table_layout = data.get("table_layout", {})
	table_owned = data.get("table_owned", {})
	boost_time_left = clampf(float(data.get("boost_time_left", 0.0)), 0.0, BOOST_SECONDS * 4.0)

	var elapsed := Time.get_unix_time_from_system() - float(data.get("last_time", 0))
	elapsed = clampf(elapsed, 0.0, MAX_OFFLINE_SECONDS)
	var earned := int(income_per_second() * elapsed)
	money += earned
	last_offline_earned = earned
	changed.emit()
	return earned
