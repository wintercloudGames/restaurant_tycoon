class_name PassTable
extends Node3D
## The "order up" counter. Cooks (and you) put finished dishes here; waiters pick them up.
## Plates appear at the Slot markers under "Slots" in pass_table.tscn (two rows deep, so big
## parties fit). If the counter is completely full, extra plates wait and appear as room frees.

@export var plate_scene: PackedScene

var plates: Array = []

var _slot_positions: Array[Vector3] = []
var _overflow: Array[Order] = []

@onready var slots_root: Node3D = $Slots
@onready var pickup_marker: Marker3D = $PickupPoint


func _ready() -> void:
	var back_row: Array[Vector3] = []
	for child in slots_root.get_children():
		var p := (child as Node3D).position
		_slot_positions.append(p + Vector3(0, 0, -0.18)) # front row first
		back_row.append(p + Vector3(0, 0, 0.18))
	_slot_positions.append_array(back_row)
	plates.resize(_slot_positions.size())


func add_plate(order: Order) -> void:
	order.claimed = false
	for i in plates.size():
		if plates[i] == null:
			_put_plate(i, order)
			return
	_overflow.append(order)


func _put_plate(slot: int, order: Order) -> void:
	var plate := plate_scene.instantiate() as Plate
	plate.order = order
	plate.pass_table = self
	plate.slot = slot
	plate.position = _slot_positions[slot]
	add_child(plate)
	plates[slot] = plate
	Sfx.play(&"OrderUpBell")


## A plate whose customer is still waiting and that no waiter has claimed yet.
func claim_plate() -> Plate:
	for i in plates.size():
		var plate: Plate = plates[i]
		if plate != null and plate.order.is_active() and not plate.order.claimed:
			return plate
	return null


func remove_plate(plate: Plate) -> void:
	if plates[plate.slot] == plate:
		plates[plate.slot] = null
	plate.queue_free()


## Where a waiter stands to grab plates.
func pickup_point() -> Vector3:
	return pickup_marker.global_position


func _process(_delta: float) -> void:
	# Throw away plates whose customer already left.
	for i in plates.size():
		var plate: Plate = plates[i]
		if plate != null and not plate.order.is_active():
			remove_plate(plate)
	# Put waiting plates down as room frees up.
	_overflow = _overflow.filter(func(o: Order) -> bool: return o.is_active())
	for i in plates.size():
		if _overflow.is_empty():
			break
		if plates[i] == null:
			_put_plate(i, _overflow.pop_front())
