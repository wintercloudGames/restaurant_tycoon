class_name ShopUi
extends CanvasLayer
## The shop window (see shop_ui.tscn): a scrolling grid of cards, each with a 3D preview,
## a short description, and a buy button. Tabs: Dishes, Upgrades, Staff, Build, Restaurant.
## Anything that needs a higher restaurant rank than you have is greyed out and says so.
## The cards are made from the lists below - add a dish in autoload/game_state.gd or an item
## in scripts/build_catalog.gd and it shows up here automatically.

signal build_requested(index: int) # the player pressed a Build card
signal close_requested

const TABS: Array[String] = ["Dishes", "Upgrades", "Staff", "Build", "Restaurant"]
const CARD_SIZE := Vector2(200, 255)
const PREVIEW_SIZE := Vector2i(180, 130)
const GAME_NAMES := {"timing": "Grill", "hold": "Fry / pour", "mash": "Stir / mix", "chop": "Chop", "sequence": "Assemble"}

var _tab: int = 0
var _cards: Dictionary = {} # tab index -> Array[PanelContainer]

@onready var _tabs: TabBar = %Tabs
@onready var _scroll: ScrollContainer = %Scroll
@onready var _grid: GridContainer = %Grid
@onready var _money_label: Label = %MoneyLabel
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_style_panel()
	for t in TABS:
		_tabs.add_tab(t)
	_tabs.tab_changed.connect(_show_tab)
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	_scroll.resized.connect(_update_columns)
	_scroll.follow_focus = true # the list scrolls to the card a controller selects
	Controls.device_changed.connect(func(_c: bool) -> void:
		if visible:
			_focus_first_card())


## A solid dark window so the 3D scene and HUD don't show through.
func _style_panel() -> void:
	var panel := get_node_or_null("Root/Panel") as PanelContainer
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.11, 0.13, 0.98)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)


## Shows the shop (call after making it visible).
func open() -> void:
	_show_tab(_tab)


# ---- What is for sale ----------------------------------------------------

func _entries(tab: int) -> Array[Dictionary]:
	match tab:
		0:
			return _dish_entries()
		1:
			return _upgrade_entries()
		2:
			return _staff_entries()
		3:
			return _build_entries()
		4:
			return _restaurant_entries()
	return []


func _dish_entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for id in GameState.DISHES:
		var d: Dictionary = GameState.DISHES[id]
		var owned: bool = id in GameState.unlocked_dishes
		var cost := int(d["unlock"])
		var req := GameState.dish_rank(id)
		list.append({
			"name": d["name"],
			"info": _dish_info(id),
			"model": Food.model_path_for(id),
			"button": "Owned" if owned else "Unlock  $%d" % cost,
			"enabled": not owned and GameState.rank() >= req and GameState.money >= cost,
			"owned": owned,
			"rank_req": 0 if owned else req,
			"action": GameState.unlock_dish.bind(id),
		})
	return list


## "$14 each, 2 steps" and the stations the steps use, e.g. "Counter > Stove > Counter".
func _dish_info(id: String) -> String:
	var steps := GameState.dish_steps(id)
	if steps.size() == 1:
		return "$%d each\n%s  -  %s" % [GameState.dish_price(id),
			"Stove" if GameState.dish_station(id) == "stove" else "Counter", GAME_NAMES.get(GameState.dish_game(id), "")]
	var stations: Array[String] = []
	for step in steps:
		stations.append("Stove" if step["station"] == "stove" else "Counter")
	return "$%d each - %d steps\n%s" % [GameState.dish_price(id), steps.size(), " > ".join(stations)]


func _upgrade_entries() -> Array[Dictionary]:
	return [
		_level_entry("Easier cooking", "Slower marker, wider zones, faster chefs.",
			"res://assets/food-kit/frying-pan.glb", GameState.cook_level, GameState.MAX_COOK_LEVEL,
			GameState.cook_cost(), GameState.cook_upgrade_rank(), GameState.buy_cook_upgrade),
		_level_entry("Marketing", "Customers arrive 10% faster.",
			"res://assets/furniture-kit/televisionModern.glb", GameState.marketing_level, GameState.MAX_MARKETING,
			GameState.marketing_cost(), GameState.marketing_rank(), GameState.buy_marketing),
		_level_entry("Serving Tray", "Carry one more plate at a time (now %d)." % GameState.carry_capacity(),
			"res://assets/food-kit/plate-rectangle.glb", GameState.tray_level, GameState.MAX_TRAY,
			GameState.tray_cost(), GameState.tray_rank(), GameState.buy_tray),
		_level_entry("Comfy seating", "Customers wait 15% longer.",
			"res://assets/furniture-kit/loungeChair.glb", GameState.comfort_level, GameState.MAX_COMFORT,
			GameState.comfort_cost(), GameState.comfort_rank(), GameState.buy_comfort),
	]


func _level_entry(title: String, text: String, model: String, level: int, max_level: int, cost: int, req: int, action: Callable) -> Dictionary:
	var maxed := level >= max_level
	return {
		"name": title,
		"info": "%s\nLevel %d / %d" % [text, level, max_level],
		"model": model,
		"button": "MAX" if maxed else "Upgrade  $%d" % cost,
		"enabled": not maxed and GameState.rank() >= req and GameState.money >= cost,
		"owned": maxed,
		"rank_req": 0 if maxed else req,
		"action": action,
	}


func _staff_entries() -> Array[Dictionary]:
	return [
		_hire_entry("Hire cook", "Cooks tickets on free stoves and counters.",
			"res://assets/mini-characters/character-worker.glb", GameState.cook_count, GameState.MAX_COOKS,
			GameState.cook_hire_cost(), GameState.cook_hire_rank(), GameState.hire_cook),
		_hire_entry("Hire waiter", "Takes orders and carries plates to tables.",
			"res://assets/mini-characters/character-male-b.glb", GameState.waiter_count, GameState.MAX_WAITERS,
			GameState.waiter_hire_cost(), GameState.waiter_hire_rank(), GameState.hire_waiter),
	]


func _hire_entry(title: String, text: String, model: String, count: int, max_count: int, cost: int, req: int, action: Callable) -> Dictionary:
	var full := count >= max_count
	return {
		"name": title,
		"info": "%s\nHired %d / %d" % [text, count, max_count],
		"model": model,
		"button": "Full" if full else "Hire  $%d" % cost,
		"enabled": not full and GameState.rank() >= req and GameState.money >= cost,
		"owned": full,
		"rank_req": 0 if full else req,
		"action": action,
		"height_only": true,
	}


func _build_entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for i in BuildCatalog.ITEMS.size():
		var d := BuildCatalog.ITEMS[i]
		var cost := BuildCatalog.cost_of(d)
		var req := BuildCatalog.rank_of(d)
		var info := ""
		var model := BuildCatalog.model_path_for(d)
		var all_placed := false
		match str(d["kind"]):
			"table":
				model = "res://assets/furniture-kit/tableRound.glb"
				all_placed = GameState.table_count >= GameState.max_tables()
				info = "Holds up to %d chairs (bought separately).\n%d of %d tables allowed" % [d["seats"], GameState.table_count, GameState.max_tables()]
			"chair":
				info = "Snaps to a free spot around a table. A table holds as many chairs as it seats."
				if d.get("comfy", false):
					info = "So comfy that customers sitting on it wait %d%% longer before leaving." % int(round((GameState.COMFY_CHAIR_PATIENCE - 1.0) * 100.0))
			"station":
				info = "A cooking station."
				if d["id"] == "stove":
					info = "4 burners for grilled, fried and stirred dishes."
				elif d["id"] == "counter":
					info = "2 prep spots for food that needs no stove."
			_:
				info = "Decor appeal +%d\n%s" % [int(d.get("appeal", 0)), "Can't walk through" if d.get("blocks", true) else "Walk over it"]
		list.append({
			"name": d["name"],
			"info": info,
			"model": model,
			"button": "All placed" if all_placed else "Build  $%d" % cost,
			"enabled": not all_placed and GameState.rank() >= req and GameState.money >= cost,
			"owned": false,
			"rank_req": req,
			"action": build_requested.emit.bind(i),
		})
	return list


## Restaurant tab: your rank, then each expansion (bought in order).
func _restaurant_entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var progress := GameState.rank_progress()
	var rank_text := "MAX RANK" if GameState.rank() >= GameState.MAX_RANK else "XP %d / %d to rank %d" % [progress.x, progress.y, GameState.rank() + 1]
	list.append({
		"name": "Rank %d: %s" % [GameState.rank(), GameState.rank_title()],
		"info": "Serve customers to earn XP.\n%s" % rank_text,
		"model": "res://assets/mini-characters/character-worker.glb",
		"button": "Total XP %d" % GameState.xp,
		"enabled": false,
		"owned": false,
		"action": Callable(),
		"height_only": true,
	})
	for i in GameState.MAX_EXPANSIONS:
		var built := i < GameState.expansions
		var is_next := i == GameState.expansions
		var cost: int = GameState.EXPANSION_COSTS[i]
		var req: int = GameState.EXPANSION_RANKS[i]
		var button := "Built"
		if not built:
			button = ("Expand  $%d" % cost) if is_next else "Build the one before"
		list.append({
			"name": GameState.EXPANSION_NAMES[i],
			"info": "Adds another floor the same size as your restaurant, and room for %d more tables." % GameState.TABLES_PER_EXPANSION,
			"model": "res://assets/furniture-kit/floorFull.glb",
			"button": button,
			"enabled": is_next and GameState.rank() >= req and GameState.money >= cost,
			"owned": built,
			"rank_req": 0 if built else req,
			"action": GameState.buy_expansion,
		})
	return list


# ---- Cards ---------------------------------------------------------------

func _show_tab(tab: int) -> void:
	if tab != _tab and visible:
		Sfx.play(&"UIClick")
	_tab = tab
	if _tabs.current_tab != tab:
		_tabs.current_tab = tab
	for child in _grid.get_children():
		_grid.remove_child(child)
	if not _cards.has(tab):
		var list: Array[PanelContainer] = []
		var entries := _entries(tab)
		for i in entries.size():
			list.append(_make_card(tab, i, entries[i]))
		_cards[tab] = list
	for card in _cards[tab]:
		_grid.add_child(card)
		# A card that was off screen needs its preview drawn again.
		(card.get_meta("viewport") as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	_scroll.scroll_vertical = 0
	refresh()
	_update_columns()
	_focus_first_card.call_deferred()


## With a controller, put the selection on the first card so the D-pad / stick can move it.
func _focus_first_card() -> void:
	if not visible or not Controls.using_controller:
		return
	var cards: Array = _cards.get(_tab, [])
	if not cards.is_empty():
		var button := (cards[0] as Node).find_child("BuyButton", true, false) as Button
		if button != null:
			button.grab_focus()


## LB / RB (or Q / Tab) switch tabs.
func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed("tab_prev"):
		_show_tab(posmod(_tab - 1, TABS.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_next"):
		_show_tab(posmod(_tab + 1, TABS.size()))
		get_viewport().set_input_as_handled()


## Updates every card's text and button (call when money or purchases change).
func refresh() -> void:
	_money_label.text = "Money: $%d" % GameState.money
	var entries := _entries(_tab)
	var cards: Array = _cards.get(_tab, [])
	for i in mini(entries.size(), cards.size()):
		_apply(cards[i], entries[i])


func _make_card(tab: int, index: int, entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(PREVIEW_SIZE)
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = PREVIEW_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	_fill_preview(viewport, str(entry["model"]), bool(entry.get("height_only", false)))
	card.set_meta("viewport", viewport)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)

	var info_label := Label.new()
	info_label.name = "InfoLabel"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size.y = 58
	info_label.modulate = Color(1, 1, 1, 0.8)
	box.add_child(info_label)

	var button := Button.new()
	button.name = "BuyButton"
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_on_card_pressed.bind(tab, index))
	box.add_child(button)
	return card


func _apply(card: PanelContainer, entry: Dictionary) -> void:
	card.get_node("Box/NameLabel").text = str(entry["name"])
	card.get_node("Box/InfoLabel").text = str(entry["info"])
	var button := card.get_node("Box/BuyButton") as Button
	var req := int(entry.get("rank_req", 0))
	var locked := req > GameState.rank()
	if locked:
		# Not available yet: say which rank unlocks it.
		button.text = "Rank %d needed" % req
		button.disabled = true
		card.get_node("Box/InfoLabel").text = "Unlocks at restaurant rank %d" % req
		card.modulate = Color(1, 1, 1, 0.5)
	else:
		button.text = str(entry["button"])
		button.disabled = not bool(entry["enabled"])
		card.modulate = Color(1, 1, 1, 0.6) if bool(entry["owned"]) else Color.WHITE


func _on_card_pressed(tab: int, index: int) -> void:
	var entries := _entries(tab)
	if index >= entries.size():
		return
	var entry := entries[index]
	if bool(entry["enabled"]):
		(entry["action"] as Callable).call()
		refresh()


## A tiny 3D scene inside the card's viewport that shows the model.
func _fill_preview(viewport: SubViewport, model_path: String, height_only: bool) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	viewport.add_child(light)

	var fit := Vector3(0.8, 1.3, 0.8) if height_only else Vector3.ONE
	var model := AssetLoader.from_scene(AssetLoader.load_scene(model_path), fit, Color(0.7, 0.7, 0.8), true, height_only)
	model.rotation.y = 0.55
	viewport.add_child(model)

	var camera := Camera3D.new()
	camera.fov = 32.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(1.7, 1.2, 2.0), Vector3(0, fit.y * 0.45, 0))
	camera.current = true


func _update_columns() -> void:
	_grid.columns = maxi(1, int(_scroll.size.x / (CARD_SIZE.x + 12.0)))
