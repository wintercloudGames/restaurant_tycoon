class_name BuildCatalog
extends RefCounted
## Everything you can buy in build mode. To add an item, add an entry here:
##   id        unique text id (saved in the save file)
##   rank      the restaurant rank needed before you can build it
##   name      shown in the build menu
##   cost      price (selling gives back half)
##   appeal    decor appeal points; every point adds +1% to tips (max +50% in total)
##   blocks    true = you can't walk through it (rugs don't block)
##   models    model files to try, first one that exists is used (edit to match your
##             Kenney Furniture Kit filenames; a colored box is shown if none exist)
##   fit       size box the model is scaled to fit; also its footprint when placing
##   color     placeholder color
##   scene     (stations only) a scene to build it from, instead of a plain model
## The "table" entries are special: tables come from the pool in main.tscn WITHOUT chairs, and "seats"
## is how many chairs it can hold. The "chair" entry is placed one at a time and snaps to a free chair
## spot around a table; a table never takes more chairs than it seats (see table.gd).

const ITEMS: Array[Dictionary] = [
	{"id": "table2", "rank": 1, "name": "Table for 2", "kind": "table", "seats": 2},
	{"id": "table4", "rank": 3, "name": "Table for 4", "kind": "table", "seats": 4},
	{"id": "table6", "rank": 6, "name": "Table for 6", "kind": "table", "seats": 6},
	{"id": "chair", "rank": 1, "name": "Chair", "kind": "chair", "cost": 25,
		"models": ["res://assets/furniture-kit/chair.glb"], "fit": Vector3(0.6, 1.0, 0.6), "color": Color(0.7, 0.5, 0.3)},
	# Costs more, but customers sitting on it wait longer (GameState.COMFY_CHAIR_PATIENCE).
	{"id": "chair_comfy", "rank": 1, "name": "Comfy Red Chair", "kind": "chair", "cost": 75, "comfy": true,
		"models": ["res://assets/furniture-kit/chairCushion.glb", "res://assets/furniture-kit/chair.glb"],
		"fit": Vector3(0.6, 1.0, 0.6), "color": Color(0.85, 0.15, 0.15), "tint": Color(1.0, 0.3, 0.3)},
	{"id": "stove", "rank": 3, "name": "Stove (4 burners)", "kind": "station", "cost": 250, "appeal": 0, "blocks": true,
		"scene": "res://scenes/stove.tscn", "models": ["res://assets/furniture-kit/kitchenStove.glb"],
		"fit": Vector3(1.0, 1.0, 1.0), "color": Color(0.4, 0.4, 0.45)},
	{"id": "counter", "rank": 2, "name": "Prep Counter (2 spots)", "kind": "station", "cost": 120, "appeal": 0, "blocks": true,
		"scene": "res://scenes/counter.tscn", "models": ["res://assets/furniture-kit/kitchenCabinetDrawer.glb"],
		"fit": Vector3(2.0, 1.0, 1.0), "color": Color(0.6, 0.6, 0.65)},
	{"id": "plant_big", "rank": 2, "name": "Potted Plant", "kind": "decor", "cost": 30, "appeal": 3, "blocks": true,
		"models": ["res://assets/furniture-kit/pottedPlant.glb"], "fit": Vector3(0.6, 1.2, 0.6), "color": Color(0.3, 0.6, 0.3)},
	{"id": "plant_small", "rank": 1, "name": "Small Plant", "kind": "decor", "cost": 15, "appeal": 2, "blocks": true,
		"models": ["res://assets/furniture-kit/plantSmall1.glb"], "fit": Vector3(0.4, 0.6, 0.4), "color": Color(0.4, 0.7, 0.35)},
	{"id": "lamp", "rank": 3, "name": "Floor Lamp", "kind": "decor", "cost": 40, "appeal": 3, "blocks": true,
		"models": ["res://assets/furniture-kit/lampRoundFloor.glb", "res://assets/furniture-kit/lampSquareFloor.glb"],
		"fit": Vector3(0.5, 1.6, 0.5), "color": Color(0.95, 0.9, 0.6)},
	{"id": "rug_round", "rank": 2, "name": "Round Rug", "kind": "decor", "cost": 25, "appeal": 2, "blocks": false,
		"models": ["res://assets/furniture-kit/rugRound.glb"], "fit": Vector3(2.0, 0.03, 2.0), "color": Color(0.7, 0.3, 0.3)},
	{"id": "rug_rect", "rank": 4, "name": "Rug", "kind": "decor", "cost": 35, "appeal": 3, "blocks": false,
		"models": ["res://assets/furniture-kit/rugRectangle.glb"], "fit": Vector3(3.0, 0.03, 2.0), "color": Color(0.35, 0.4, 0.7)},
	{"id": "bookcase", "rank": 5, "name": "Bookcase", "kind": "decor", "cost": 60, "appeal": 4, "blocks": true,
		"models": ["res://assets/furniture-kit/bookcaseOpen.glb", "res://assets/furniture-kit/bookcaseClosed.glb"],
		"fit": Vector3(1.0, 1.8, 0.4), "color": Color(0.55, 0.4, 0.25)},
	{"id": "sofa", "rank": 7, "name": "Sofa", "kind": "decor", "cost": 90, "appeal": 5, "blocks": true,
		"models": ["res://assets/furniture-kit/loungeSofa.glb"], "fit": Vector3(2.0, 0.9, 0.9), "color": Color(0.5, 0.35, 0.6)},
	{"id": "armchair", "rank": 5, "name": "Armchair", "kind": "decor", "cost": 50, "appeal": 3, "blocks": true,
		"models": ["res://assets/furniture-kit/loungeChair.glb"], "fit": Vector3(0.9, 0.9, 0.9), "color": Color(0.6, 0.4, 0.4)},
	{"id": "bench", "rank": 4, "name": "Bench", "kind": "decor", "cost": 40, "appeal": 3, "blocks": true,
		"models": ["res://assets/furniture-kit/benchCushion.glb", "res://assets/furniture-kit/bench.glb"],
		"fit": Vector3(1.4, 0.6, 0.5), "color": Color(0.6, 0.45, 0.3)},
	{"id": "stool", "rank": 1, "name": "Bar Stool", "kind": "decor", "cost": 20, "appeal": 1, "blocks": true,
		"models": ["res://assets/furniture-kit/stoolBar.glb"], "fit": Vector3(0.4, 0.8, 0.4), "color": Color(0.5, 0.35, 0.25)},
	{"id": "coat_rack", "rank": 3, "name": "Coat Rack", "kind": "decor", "cost": 25, "appeal": 2, "blocks": true,
		"models": ["res://assets/furniture-kit/coatRackStanding.glb"], "fit": Vector3(0.4, 1.7, 0.4), "color": Color(0.45, 0.3, 0.2)},
	{"id": "trash", "rank": 1, "name": "Trash Can", "kind": "decor", "cost": 10, "appeal": 1, "blocks": true,
		"models": ["res://assets/furniture-kit/trashcan.glb"], "fit": Vector3(0.4, 0.5, 0.4), "color": Color(0.5, 0.55, 0.55)},
	{"id": "coffee_table", "rank": 6, "name": "Coffee Table", "kind": "decor", "cost": 35, "appeal": 3, "blocks": true,
		"models": ["res://assets/furniture-kit/tableCoffee.glb", "res://assets/furniture-kit/tableCoffeeGlass.glb"],
		"fit": Vector3(1.0, 0.4, 0.6), "color": Color(0.6, 0.45, 0.3)},
	{"id": "tv", "rank": 8, "name": "Television", "kind": "decor", "cost": 80, "appeal": 5, "blocks": true,
		"models": ["res://assets/furniture-kit/televisionModern.glb", "res://assets/furniture-kit/televisionVintage.glb"],
		"fit": Vector3(1.2, 0.9, 0.4), "color": Color(0.15, 0.15, 0.18)},
]


static func find(id: String) -> Dictionary:
	for d in ITEMS:
		if d["id"] == id:
			return d
	return {}


## The catalog entry for a table with this many chairs (falls back to the 2-seat entry).
static func table_def(seats: int) -> Dictionary:
	for d in ITEMS:
		if d.get("kind", "") == "table" and int(d["seats"]) == seats:
			return d
	return find("table2")


## The catalog entry for a chair: the comfy red one or the plain one.
static func chair_def(comfy: bool) -> Dictionary:
	return find("chair_comfy" if comfy else "chair")


static func rank_of(def: Dictionary) -> int:
	return int(def.get("rank", 1))


static func appeal_of(id: String) -> int:
	return int(find(id).get("appeal", 0))


static func cost_of(def: Dictionary) -> int:
	if def.get("kind", "decor") == "table":
		return GameState.table_cost(int(def["seats"]))
	return int(def["cost"])


static func model_path_for(def: Dictionary) -> String:
	var paths: Array = def.get("models", [])
	for p in paths:
		if ResourceLoader.exists(p):
			return p
	return paths[0] if not paths.is_empty() else ""
