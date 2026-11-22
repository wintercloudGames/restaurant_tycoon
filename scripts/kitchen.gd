class_name Kitchen
extends Node3D
## The back of the restaurant (see kitchen.tscn): ticket board, stove with 4 burners,
## the order-up table, and the hired cooks and waiters.
## Move the Slot / Spot / Home markers in the scene to change where things appear.

@export var ticket_scene: PackedScene
@export var cook_scene: PackedScene
@export var waiter_scene: PackedScene
## A starter prep counter is added here if the kitchen has no node named "Counter".
@export var counter_scene: PackedScene
@export var default_counter_position: Vector3 = Vector3(5.0, 0, -6.5)
## "timing" (grill) minigame. The other minigames are loaded from scenes/ if left empty.
@export var minigame_scene: PackedScene
@export var hold_game_scene: PackedScene
@export var mash_game_scene: PackedScene
@export var sequence_game_scene: PackedScene

var tickets: Array = []
var _slot_positions: Array[Vector3] = [] # where tickets hang (kitchen space): two rows
var _pending: Array[Order] = [] # orders waiting for a free spot on the board
var burners: Array[Burner] = []
var cooks: Array[Cook] = []
var waiters: Array[Waiter] = []

@onready var ticket_slots: Node3D = $TicketSlots
@onready var stove: Node3D = $Stove
@onready var pass_table: PassTable = $PassTable
@onready var cook_spots: Node3D = $CookSpots
@onready var waiter_homes: Node3D = $WaiterHomes


func _ready() -> void:
	add_to_group("kitchen")
	if counter_scene == null:
		counter_scene = load("res://scenes/counter.tscn")
	if not has_node("Counter") and counter_scene != null:
		var counter := counter_scene.instantiate() as Node3D
		counter.name = "Counter"
		add_child(counter)
		counter.position = default_counter_position
	_snap_appliances()
	if minigame_scene == null:
		minigame_scene = load("res://scenes/cook_minigame.tscn")
	if hold_game_scene == null:
		hold_game_scene = load("res://scenes/minigame_hold.tscn")
	if mash_game_scene == null:
		mash_game_scene = load("res://scenes/minigame_mash.tscn")
	if sequence_game_scene == null:
		sequence_game_scene = load("res://scenes/minigame_sequence.tscn")
	_build_ticket_slots()
	GameState.changed.connect(_sync_staff)
	_sync_staff()


## The board has the marker row from kitchen.tscn plus a second row below it, so a few big
## parties can order at once. Orders beyond that wait in a queue and appear as spots free up.
func _build_ticket_slots() -> void:
	_slot_positions.clear()
	var row_two: Array[Vector3] = []
	for child in ticket_slots.get_children():
		var p := to_local((child as Node3D).global_position)
		_slot_positions.append(p)
		row_two.append(p + Vector3(0, -0.75, 0))
	_slot_positions.append_array(row_two)
	tickets.clear()
	tickets.resize(_slot_positions.size())

	var board := get_node_or_null("Board") as MeshInstance3D
	if board != null and board.mesh is BoxMesh:
		var old := board.mesh as BoxMesh
		var taller := BoxMesh.new()
		taller.size = Vector3(old.size.x, old.size.y + 0.8, old.size.z)
		taller.material = old.material
		board.mesh = taller
		board.position.y -= 0.4


## Puts the starter stove, counter and order-up table on the same grid build mode uses, so the
## stoves and counters you build line up with them and can sit right up against them.
func _snap_appliances() -> void:
	stove.position = _snap(stove.position)
	pass_table.position = _snap(pass_table.position)
	var starter := get_node_or_null("Counter") as Node3D
	if starter != null:
		starter.position = _snap(starter.position)


func _snap(v: Vector3) -> Vector3:
	return Vector3(snappedf(v.x, BuildMode.GRID), v.y, snappedf(v.z, BuildMode.GRID))


func _sync_staff() -> void:
	while cooks.size() < mini(GameState.cook_count, cook_spots.get_child_count()):
		var spot := cook_spots.get_child(cooks.size()) as Node3D
		var cook := cook_scene.instantiate() as Cook
		cook.kitchen = self
		add_child(cook)
		cook.position = to_local(spot.global_position)
		cook.rotation = spot.rotation
		cooks.append(cook)
	while waiters.size() < mini(GameState.waiter_count, waiter_homes.get_child_count()):
		var spot := waiter_homes.get_child(waiters.size()) as Node3D
		var waiter := waiter_scene.instantiate() as Waiter
		waiter.kitchen = self
		waiter.home = to_local(spot.global_position)
		add_child(waiter)
		waiter.position = waiter.home
		waiters.append(waiter)


# ---- Burners (stoves and counters register themselves) -------------------

func register_burner(burner: Burner) -> void:
	if burner in burners:
		return
	burners.append(burner)
	burner.cook_requested.connect(_on_cook_requested)


func unregister_burner(burner: Burner) -> void:
	burners.erase(burner)
	if burner.cook_requested.is_connected(_on_cook_requested):
		burner.cook_requested.disconnect(_on_cook_requested)


## Floor areas of the kitchen that build mode must keep clear (ticket board, pass, staff spots)
## or that are already taken by the fixed stove / counter / order-up table.
func reserved_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var lane := _marker_rect(ticket_slots, Vector2(0.5, 0.3))
	rects.append(Rect2(lane.position, Vector2(lane.size.x, lane.size.y + 0.9)))
	rects.append(_box_rect(stove.global_position, Vector2(1.0, 1.0))) # exactly its footprint, so a new stove can sit flush
	var counter := get_node_or_null("Counter") as Node3D
	if counter != null:
		rects.append(_box_rect(counter.global_position, Vector2(2.0, 1.0)))
	var pt := pass_table.global_position
	rects.append(Rect2(pt.x - 2.3, pt.z - 0.6, 4.6, 2.3))
	rects.append(_marker_rect(cook_spots, Vector2(0.5, 0.5)))
	rects.append(_marker_rect(waiter_homes, Vector2(0.5, 0.5)))
	return rects


func _box_rect(center: Vector3, size: Vector2) -> Rect2:
	return Rect2(center.x - size.x / 2.0, center.z - size.y / 2.0, size.x, size.y)


func _marker_rect(parent: Node3D, pad: Vector2) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for child in parent.get_children():
		var m := child as Node3D
		lo = Vector2(minf(lo.x, m.global_position.x), minf(lo.y, m.global_position.z))
		hi = Vector2(maxf(hi.x, m.global_position.x), maxf(hi.y, m.global_position.z))
	return Rect2(lo - pad, hi - lo + pad * 2.0)


# ---- Tickets -------------------------------------------------------------

## Connected to each customer's order_taken signal.
func on_order_taken(customer: Customer) -> void:
	add_order(Order.new(customer, customer.dish_id, customer.table.number, customer.seat_letter()))


func add_order(order: Order) -> void:
	for i in tickets.size():
		if tickets[i] == null:
			_hang_ticket(i, order)
			return
	_pending.append(order) # the board is full: it goes up when a spot frees


func _hang_ticket(slot: int, order: Order) -> void:
	var ticket := ticket_scene.instantiate() as Ticket
	ticket.order = order
	ticket.kitchen = self
	ticket.slot = slot
	add_child(ticket)
	ticket.position = _slot_positions[slot]
	tickets[slot] = ticket
	Sfx.play(&"NewTicket")


## A free cooking spot of the given station ("stove" or "counter"); "" = any.
func _free_burner(station: String = "") -> Burner:
	for b in burners:
		if b.is_free() and (station == "" or b.station == station):
			return b
	return null


func has_free_burner(station: String = "") -> bool:
	return _free_burner(station) != null


# ---- Player cooking (minigame) ------------------------------------------

## Clicking a ticket puts that dish in its pan/pot on a free burner.
func place_on_burner(ticket: Ticket, player: Player) -> void:
	var burner := _free_burner(ticket.order.step_station())
	if burner == null:
		return
	var order := ticket.order
	tickets[ticket.slot] = null
	ticket.queue_free()
	burner.place(order, false)
	player.notice.emit("On the %s! Press E there to %s it." % [("stove" if burner.station == "stove" else "counter"), order.step_label().to_lower()])


func _game_scene(game_type: String) -> PackedScene:
	match game_type:
		"hold":
			return hold_game_scene
		"mash":
			return mash_game_scene
		"sequence":
			return sequence_game_scene
	return minigame_scene


## Pressing E on a burner with a dish waiting starts that dish's minigame.
func _on_cook_requested(burner: Burner, player: Player) -> void:
	var order := burner.order
	if order == null or not order.is_active() or player.busy:
		return
	burner.begin_manual()
	player.busy = true
	player.enabled = false

	var minigame := _game_scene(order.step_game()).instantiate() as CookMinigame
	minigame.order = order
	add_child(minigame)
	minigame.finished.connect(_on_player_finished.bind(order, burner, player))
	minigame.cancelled.connect(_on_player_cancelled.bind(order, burner, player))


func _on_player_finished(quality: float, order: Order, burner: Burner, player: Player) -> void:
	burner.clear()
	player.busy = false
	player.enabled = true
	var was_last := not order.has_more_steps()
	finish_step(order, quality)
	if was_last:
		player.notice.emit("%s dish sent to the order-up table!" % CookMinigame.quality_name(order.quality))
	else:
		player.notice.emit("%s! Next: %s (back on the ticket board)." % [CookMinigame.quality_name(quality), order.step_label()])


## A step of a recipe is done (by you or a cook). More steps left: the order goes back on the
## ticket board for the next one. That was the last step: the dish goes on the order-up table.
func finish_step(order: Order, quality: float) -> void:
	order.record_step(quality)
	if order.has_more_steps():
		order.advance()
		add_order(order)
	else:
		pass_table.add_plate(order)


func _on_player_cancelled(order: Order, burner: Burner, player: Player) -> void:
	if order.is_active():
		burner.return_to_waiting() # the dish stays on the stove
	else:
		burner.clear()
		player.notice.emit("That customer left!")
	player.busy = false
	player.enabled = true


# ---- Hired cooks ---------------------------------------------------------

## Gives `cook` the next ticket that has a free stove burner / counter spot, if any.
func assign_cook_job(cook: Cook) -> bool:
	for i in tickets.size():
		var ticket: Ticket = tickets[i]
		if ticket == null or not ticket.order.is_active():
			continue
		var burner := _free_burner(ticket.order.step_station())
		if burner == null:
			continue
		var order := ticket.order
		tickets[i] = null
		ticket.queue_free()
		burner.place(order, true)
		cook.order = order
		cook.burner = burner
		return true
	return false


func _process(_delta: float) -> void:
	# Sizzle sound while anything is cooking (it re-starts itself if the clip is short).
	var cooking := false
	for b in burners:
		if b.is_cooking() and b.station == "stove":
			cooking = true
	if cooking:
		if not Sfx.is_playing(&"Sizzle"):
			Sfx.play(&"Sizzle")
	else:
		Sfx.stop(&"Sizzle")

	# Remove tickets whose customer already left.
	for i in tickets.size():
		var ticket: Ticket = tickets[i]
		if ticket != null and not ticket.order.is_active():
			ticket.queue_free()
			tickets[i] = null

	# Put waiting orders on the board as spots free up.
	_pending = _pending.filter(func(o: Order) -> bool: return o.is_active())
	for i in tickets.size():
		if _pending.is_empty():
			break
		if tickets[i] == null:
			_hang_ticket(i, _pending.pop_front())
