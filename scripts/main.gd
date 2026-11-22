extends Node3D
## The restaurant (see main.tscn). Spawns customers and runs the shop.
## Move tables, walls, lights etc. in the scene. Each Table has a "Number" in the Inspector.

@export var customer_scene: PackedScene
@export var spawn_interval: float = 9.0
## 0 = a random party size for the table; set 1+ to force how many people arrive (used by tests).
@export var party_size_override: int = 0

var tables: Array[Table] = []
var shop_open: bool = false
var spawn_timer: float = 0.0
var build_mode: BuildMode
var shop_ui: ShopUi
var plots: RestaurantPlots
var rank_label: Label
var rank_bar: ProgressBar
var rank_detail: Label
var pause_menu: PauseMenu
var _loaded: bool = false # the save is loaded (on the web we wait for the CrazyGames SDK first)

@onready var kitchen: Kitchen = $Kitchen
@onready var player: Player = $Player
@onready var hud: Hud = $HUD
@onready var door: Marker3D = $Door


func _ready() -> void:
	spawn_timer = spawn_interval - 2.0
	_setup_sounds()
	for node in $Tables.get_children():
		if node is Table:
			tables.append(node)
	tables.sort_custom(func(a: Table, b: Table) -> bool: return a.number < b.number)

	player.notice.connect(hud.show_toast)
	_setup_plots()
	_setup_build_mode()
	_setup_shop()
	_setup_rank_ui()
	GameState.changed.connect(_refresh)
	GameState.rank_up.connect(_on_rank_up)
	GameState.expanded.connect(_on_expanded)
	_setup_pause_menu()
	# On CrazyGames the save lives in their storage, which is only readable once the SDK started.
	await CrazyGames.wait_ready()
	var earned := GameState.load_game()
	plots.set_expansions(GameState.expansions)
	_sync_table_pool()
	build_mode.restore_layout()
	_refresh()
	_loaded = true
	CrazyGames.loading_stop()
	pause_menu.open(true) # start screen (also gives the browser the click it needs to lock the mouse)
	if earned > 0:
		hud.show_toast("Welcome back! You earned $%d while away." % earned)


## Start screen, pause menu (P) and settings. See pause_menu.gd.
func _setup_pause_menu() -> void:
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.setup(self, player)
	add_child(pause_menu)


## All sound effects and the music live in scenes/game_sounds.tscn.
func _setup_sounds() -> void:
	var scene := load("res://scenes/game_sounds.tscn") as PackedScene
	if scene == null:
		return
	var sounds := scene.instantiate()
	add_child(sounds)
	Sfx.setup(sounds)
	var rank_scene := load("res://scenes/rank_sounds.tscn") as PackedScene
	if rank_scene != null:
		var rank_sounds := rank_scene.instantiate()
		add_child(rank_sounds)
		Sfx.add_root(rank_sounds)
	var music := sounds.get_node_or_null("Music") as AudioStreamPlayer
	if music != null:
		music.finished.connect(music.play) # loop the music
	GameState.purchased.connect(_on_purchased)


func _on_purchased() -> void:
	Sfx.play(&"Buy")


## The restaurant floor: the starting room plus the expansions you've bought.
func _setup_plots() -> void:
	plots = RestaurantPlots.new()
	plots.name = "Plots"
	add_child(plots)
	plots.adopt_scene_walls({
		"west": get_node_or_null("WallLeft"), "east": get_node_or_null("WallRight"),
		"north": get_node_or_null("WallBack"), "south": get_node_or_null("WallFront")})


## Each expansion makes room for 2 more tables. Tables beyond the 8 in main.tscn are made here.
func _sync_table_pool() -> void:
	var holder := get_node("Tables")
	var scene := load("res://scenes/table.tscn") as PackedScene
	while tables.size() < GameState.max_tables():
		var table := scene.instantiate() as Table
		table.number = tables.size() + 1
		holder.add_child(table)
		table.set_active(false)
		tables.append(table)


func _on_expanded(count: int) -> void:
	plots.set_expansions(count)
	_sync_table_pool()
	hud.show_toast("Your restaurant grew! %s added: a whole new floor to build on." % GameState.EXPANSION_NAMES[count - 1])
	Sfx.play(&"Expand")


func _on_rank_up(new_rank: int) -> void:
	var unlocked := GameState.unlocks_at_rank(new_rank)
	var text := "RANK UP! Rank %d: %s" % [new_rank, GameState.rank_title(new_rank)]
	if not unlocked.is_empty():
		text += "  -  unlocked: " + ", ".join(unlocked)
	hud.show_toast(text)
	Sfx.play(&"RankUp")
	CrazyGames.happy_time()
	# A rank up is a natural break: CrazyGames may show a midgame ad (rate-limited).
	CrazyGames.try_midgame()


## A small rank bar in the bottom-left corner of the HUD.
func _setup_rank_ui() -> void:
	var root := hud.get_node_or_null("Root") as Control
	if root == null:
		return
	var panel := PanelContainer.new()
	panel.name = "RankPanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_right = 276
	panel.offset_top = -86
	panel.offset_bottom = -16
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	rank_label = Label.new()
	rank_label.add_theme_font_size_override("font_size", 20)
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rank_label)
	rank_bar = ProgressBar.new()
	rank_bar.custom_minimum_size = Vector2(240, 14)
	rank_bar.show_percentage = false
	rank_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rank_bar)
	rank_detail = Label.new()
	rank_detail.add_theme_font_size_override("font_size", 13)
	rank_detail.modulate = Color(1, 1, 1, 0.8)
	rank_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rank_detail)


func _update_rank_ui() -> void:
	if rank_label == null:
		return
	rank_label.text = "Rank %d  -  %s" % [GameState.rank(), GameState.rank_title()]
	var progress := GameState.rank_progress()
	rank_bar.max_value = progress.y
	rank_bar.value = progress.x
	rank_detail.text = "MAX RANK" if GameState.rank() >= GameState.MAX_RANK else "XP %d / %d" % [progress.x, progress.y]


## The scrolling shop window (B). It also hands off to build mode for the Build tab.
func _setup_shop() -> void:
	shop_ui = (load("res://scenes/shop_ui.tscn") as PackedScene).instantiate() as ShopUi
	add_child(shop_ui)
	shop_ui.visible = false
	shop_ui.close_requested.connect(_set_shop.bind(false))
	shop_ui.build_requested.connect(_on_build_requested)


func _on_build_requested(index: int) -> void:
	_set_shop(false)
	build_mode.activate()
	if build_mode.active:
		build_mode.select_index(index)


## Build mode (press V): buy, place, move and sell tables and decor. See build_mode.gd.
func _setup_build_mode() -> void:
	build_mode = BuildMode.new()
	build_mode.name = "BuildMode"
	add_child(build_mode)
	build_mode.setup(player, tables, door, kitchen, plots)
	# Mention the build key in the on-screen controls hint.
	var hint := hud.get_node_or_null("Root/HintLabel") as Label
	if hint != null and not hint.text.contains("V build"):
		hint.text += "  |  V build"


func _process(delta: float) -> void:
	if not _loaded:
		return
	spawn_timer += delta
	if spawn_timer >= spawn_interval * GameState.spawn_interval_multiplier():
		spawn_timer = 0.0
		_try_spawn()

	hud.prompt_label.text = "" if (build_mode.active or not player.enabled) else player.prompt
	if player.held_order:
		hud.held_label.text = "Carrying: %s for %s" % [
			player.held_order.dish_name(), player.held_order.where()]
	else:
		hud.held_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if not _loaded or player.busy or build_mode.active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B or event.keycode == KEY_ESCAPE:
			_set_shop(not shop_open)


func _set_shop(open: bool) -> void:
	shop_open = open
	Sfx.play(&"ShopOpen" if open else &"ShopClose")
	shop_ui.visible = open
	if open:
		shop_ui.open()
	player.enabled = not open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	CrazyGames.set_gameplay(not open)


## A party arrives and takes a free table: 1 up to as many people as the table has chairs,
## on random chairs (so a table for 4 might get 1, 2, 3 or 4 people).
func _try_spawn() -> void:
	var free: Array[Table] = []
	for t in tables:
		if GameState.is_table_owned(t.number) and not t.occupied and not t.build_holding and t.chair_count() > 0:
			free.append(t) # only tables that have chairs can seat anyone
	if free.is_empty():
		return
	var table: Table = free.pick_random()
	var size := table.random_party_size() if party_size_override <= 0 else mini(party_size_override, table.chair_count())
	var chairs := table.begin_party(size)
	for k in chairs.size():
		var c := customer_scene.instantiate() as Customer
		c.setup(table, chairs[k], door.position, door.position, 0.6 * k)
		c.order_taken.connect(kitchen.on_order_taken)
		add_child(c)


# ---- Shop ----------------------------------------------------------------

func _refresh() -> void:
	_update_rank_ui()
	hud.money_label.text = "$%d   (+%.1f/s idle)   Decor %d (+%d%% tips)" % [
		GameState.money, GameState.income_per_second(), GameState.decor_appeal(),
		int(round((GameState.tip_multiplier() - 1.0) * 100.0))]

	for i in tables.size():
		if not tables[i].build_holding: # a table being placed is handled by build mode
			tables[i].set_active(GameState.is_table_owned(tables[i].number))

	if shop_open:
		shop_ui.refresh()
