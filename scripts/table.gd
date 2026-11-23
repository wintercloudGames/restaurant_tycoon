class_name Table
extends Node3D
## A table. Tables are placed WITHOUT chairs (Table for 2 / 4 / 6); you then place chairs
## one at a time in build mode, and they snap to the chair spots around the table. A table
## holds at most as many chairs as it seats. Change the models in table.tscn (TableModel /
## ChairModel: the chair model you set there is used for every chair). Set "Number" on each
## table in the main scene; "Seats" is the size (set when you buy the table).
##
## A party of 1 up to as many people as there are CHAIRS sits at a table at a time, so a table
## for 4 with 3 chairs hosts 1 to 3 people. The table counts as in use until the whole party
## has left, and a table with no chairs can't seat anyone.

@export var number: int = 0
@export_range(1, 8) var seats: int = 2:
	set(value):
		seats = clampi(value, 1, 8)
		if _ready_done:
			_build()
## Default chair seat height (used when the SeatPoint marker sits on the floor).
@export var seat_height: float = 0.45

## How likely each party size is, per number of chairs (index 0 = a party of 1).
const PARTY_WEIGHTS := {
	1: [1.0],
	2: [0.55, 0.45],
	3: [0.30, 0.40, 0.30],
	4: [0.25, 0.35, 0.25, 0.15],
	5: [0.15, 0.30, 0.25, 0.20, 0.10],
	6: [0.10, 0.25, 0.20, 0.20, 0.15, 0.10],
	7: [0.10, 0.20, 0.20, 0.20, 0.15, 0.10, 0.05],
	8: [0.08, 0.17, 0.18, 0.18, 0.15, 0.12, 0.07, 0.05],
}

var occupied: bool = false
var build_holding: bool = false # true while being moved/placed in build mode
var party_left: int = 0 # people from the current party still at / heading to the table

var _ready_done: bool = false
var _chairs: Array[Chair] = [] # one entry per chair spot; null = no chair there yet
var _chair_path: String = ""
var _chair_scene: PackedScene
var _chair_fit: Vector3 = Vector3(0.6, 1.0, 0.6)
var _chair_color: Color = Color(0.7, 0.5, 0.3)

@onready var body: StaticBody3D = $Body
@onready var number_label: Label3D = $NumberLabel
@onready var seat_point: Marker3D = $SeatPoint
@onready var waiter_point: Marker3D = $WaiterPoint
@onready var food_point: Marker3D = $FoodPoint
@onready var table_model: ModelSlot = $TableModel
@onready var chair_model: ModelSlot = $ChairModel


func _ready() -> void:
	number_label.text = str(number)
	# The ChairModel slot in the scene is the template for every chair.
	_chair_path = chair_model.model_path
	_chair_scene = chair_model.model_scene
	_chair_fit = chair_model.fit_size
	_chair_color = chair_model.fallback_color
	chair_model.visible = false
	_ready_done = true
	_build()


## Changes the table's size (2, 4 or 6 chairs' worth). Any chairs are removed.
func configure(new_seats: int) -> void:
	if new_seats == seats and _ready_done:
		_build()
	else:
		seats = new_seats


# ---- Size and chair spots --------------------------------------------------

func table_diameter() -> float:
	return 1.0 + 0.17 * seats


func chair_radius() -> float:
	return table_diameter() / 2.0 + 0.55


## Angle of chair spot `i` around the table. Spot 0 is on the +Z side.
func _angle(i: int) -> float:
	return TAU * float(i) / float(seats)


## Direction from the table's middle out towards chair spot `i`, in the table's own space.
func _outward(i: int) -> Vector3:
	return Vector3(sin(_angle(i)), 0.0, cos(_angle(i)))


func _build() -> void:
	clear_chairs()
	var d := table_diameter()
	table_model.fit_size = Vector3(d, table_model.fit_size.y, d)

	var shape := body.get_node("CollisionShape3D") as CollisionShape3D
	var box := BoxShape3D.new() # a fresh shape so other tables are not resized too
	box.size = Vector3(d, 0.8, d)
	shape.shape = box
	shape.position = Vector3(0, 0.4, 0)
	_chairs.clear()
	_chairs.resize(seats)


## The floor area the table and ALL of its chair spots cover (in the table's own space), for
## build mode. It keeps the spots clear so you can always add the chairs you've paid for.
func footprint_local() -> Rect2:
	var half_table := table_diameter() / 2.0
	var lo := Vector2(-half_table, -half_table)
	var hi := Vector2(half_table, half_table)
	for i in seats:
		var p := _outward(i) * chair_radius()
		lo = Vector2(minf(lo.x, p.x - 0.4), minf(lo.y, p.z - 0.4))
		hi = Vector2(maxf(hi.x, p.x + 0.4), maxf(hi.y, p.z + 0.4))
	return Rect2(lo, hi - lo)


## Tables you haven't bought yet are hidden and don't block you.
func set_active(active: bool) -> void:
	visible = active
	body.collision_layer = 1 if active else 0


# ---- Chairs ----------------------------------------------------------------

## A new chair (not attached to a spot yet): the table's chair model, or the comfy red chair
## from the build catalog.
func make_chair(comfy: bool = false) -> Chair:
	var chair := Chair.new()
	if comfy:
		var def := BuildCatalog.chair_def(true)
		chair.setup(BuildCatalog.model_path_for(def), null, def["fit"], def["color"], def.get("tint", Color.WHITE))
	else:
		chair.setup(_chair_path, _chair_scene, _chair_fit, _chair_color)
	chair.comfy = comfy
	return chair


func chair_count() -> int:
	var n := 0
	for c in _chairs:
		if c != null:
			n += 1
	return n


func is_full() -> bool:
	return chair_count() >= seats


func chair_at(slot: int) -> Chair:
	return _chairs[slot] if slot >= 0 and slot < _chairs.size() else null


func filled_slots() -> Array[int]:
	var list: Array[int] = []
	for i in _chairs.size():
		if _chairs[i] != null:
			list.append(i)
	return list


## The chair spots that have a comfy red chair.
func comfy_slots() -> Array[int]:
	var list: Array[int] = []
	for i in _chairs.size():
		if _chairs[i] != null and _chairs[i].comfy:
			list.append(i)
	return list


func is_comfy(slot: int) -> bool:
	var chair := chair_at(slot)
	return chair != null and chair.comfy


func free_slots() -> Array[int]:
	var list: Array[int] = []
	for i in _chairs.size():
		if _chairs[i] == null:
			list.append(i)
	return list


## Where (and facing which way) a chair in spot `i` sits, in the world.
func slot_global_transform(i: int) -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.UP, _angle(i) + PI), _outward(i) * chair_radius())


func slot_position(i: int) -> Vector3:
	return global_transform * (_outward(i) * chair_radius())


## Puts a chair in spot `slot`. Returns it, or null if the spot is taken or doesn't exist
## (a table can't hold more chairs than it seats).
func add_chair(slot: int, comfy: bool = false) -> Chair:
	if slot < 0 or slot >= seats or _chairs[slot] != null:
		return null
	var chair := make_chair(comfy)
	chair.table = self
	chair.slot = slot
	add_child(chair)
	chair.position = _outward(slot) * chair_radius()
	chair.rotation.y = _angle(slot) + PI # chairs face the table
	_chairs[slot] = chair
	return chair


func remove_chair(slot: int) -> void:
	var chair := chair_at(slot)
	if chair == null:
		return
	_chairs[slot] = null
	remove_child(chair)
	chair.queue_free()


func clear_chairs() -> void:
	for i in _chairs.size():
		remove_chair(i)


## Gives the table a chair in each of the listed spots (and none elsewhere); the spots in
## `comfy` get the comfy red chair.
func set_chairs(slots: Array, comfy: Array = []) -> void:
	clear_chairs()
	var comfy_ints: Array[int] = []
	for c in comfy:
		comfy_ints.append(int(c))
	for s in slots:
		add_chair(int(s), comfy_ints.has(int(s)))


func fill_chairs() -> void:
	clear_chairs()
	for i in seats:
		add_chair(i)


## Lets build mode point at the chairs (off while the whole table is being carried).
func set_chairs_pickable(on: bool) -> void:
	for c in _chairs:
		if c != null:
			c.set_pickable(on)


## The empty chair spot closest to a point on the floor, or -1 if the table is full.
func nearest_free_slot(world_pos: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in free_slots():
		var p := slot_position(i)
		var d := Vector2(p.x - world_pos.x, p.z - world_pos.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


# ---- Seating, parties ------------------------------------------------------

func get_seat(index: int = 0) -> Vector3:
	return global_transform * (_outward(index) * chair_radius())


## Height the customer's hips should be at. Move the SeatPoint up in table.tscn to raise
## it; if the SeatPoint is left on the floor, the "Seat Height" value above is used.
func get_seat_height() -> float:
	var h := seat_point.global_position.y
	return h if h > 0.05 else seat_height


## Where a waiter stands to talk to or serve the customer in chair spot `index`: behind the chair.
func get_waiter_spot(index: int = 0) -> Vector3:
	return global_transform * (_outward(index) * (chair_radius() + 0.95))


## A random party size for this table: 1 up to the number of CHAIRS (0 if it has none).
func random_party_size() -> int:
	var n := chair_count()
	if n <= 0:
		return 0
	var weights: Array = PARTY_WEIGHTS.get(n, [])
	if weights.is_empty():
		return randi_range(1, n)
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := randf() * total
	for i in weights.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return i + 1
	return weights.size()


## Starts a party of `size` people and returns the chair spots they will take (only spots
## that have a chair).
func begin_party(size: int) -> Array[int]:
	var all := filled_slots()
	size = clampi(size, 1, maxi(all.size(), 1))
	occupied = true
	party_left = size
	all.shuffle()
	return all.slice(0, size)


## A member of the party has left. The table is free once everyone has gone.
func party_member_left() -> void:
	party_left = maxi(party_left - 1, 0)
	if party_left == 0:
		occupied = false


## Puts a plate / food model on the table in front of chair spot `index`.
func add_food(food: Node3D, index: int = 0) -> void:
	add_child(food)
	var spot := _outward(index) * (table_diameter() / 2.0 - 0.4)
	food.position = Vector3(spot.x, food_point.position.y, spot.z)
