class_name Waiter
extends Node3D
## A hired waiter. Takes orders from seated customers and carries finished plates
## from the order-up table to the right customer. Edit waiter.tscn to change the look.

enum S { IDLE, TO_CUSTOMER_ORDER, TO_PASS, TO_CUSTOMER_FOOD, RETURN }

const IDLE_NAMES: Array[String] = ["idle"]
const WALK_NAMES: Array[String] = ["walk"]

@export var speed: float = 4.0
@export var work_time: float = 0.8

var kitchen: Kitchen
var home: Vector3

var _state: S = S.IDLE
var _customer: Customer
var _plate: Plate
var _order: Order
var _held: Node3D
var _work_timer: float = -1.0
var _anim: CharAnim

@onready var model: Node3D = $Model
@onready var held_point: Marker3D = $HeldPoint


func _ready() -> void:
	_anim = CharAnim.new(model)
	_anim.play(IDLE_NAMES)


func _process(delta: float) -> void:
	match _state:
		S.IDLE:
			_find_job()
		S.TO_CUSTOMER_ORDER:
			if not is_instance_valid(_customer) or _customer.state != Customer.State.WAIT_ORDER:
				_go_home()
			elif _walk(_customer.get_waiter_spot(), delta):
				if _work_done(delta):
					_customer.take_order()
					_go_home()
		S.TO_PASS:
			if not is_instance_valid(_plate) or not _order.is_active():
				_drop_order()
			elif _walk(kitchen.pass_table.pickup_point(), delta):
				kitchen.pass_table.remove_plate(_plate)
				_plate = null
				_hold(_order)
				_work_timer = -1.0
				_state = S.TO_CUSTOMER_FOOD
		S.TO_CUSTOMER_FOOD:
			if not _order.is_active():
				_drop_order()
			elif _walk(_order.customer.get_waiter_spot(), delta):
				if _work_done(delta):
					_order.customer.serve(_order)
					_drop_order()
		S.RETURN:
			if _walk(home, delta):
				_state = S.IDLE


func _find_job() -> void:
	# Food first, then taking orders.
	var plate := kitchen.pass_table.claim_plate()
	if plate != null:
		_plate = plate
		_order = plate.order
		_order.claimed = true
		_work_timer = -1.0
		_state = S.TO_PASS
		return
	for node in get_tree().get_nodes_in_group("customers"):
		var customer := node as Customer
		if customer.state == Customer.State.WAIT_ORDER and not customer.claimed:
			_customer = customer
			customer.claimed = true
			_work_timer = -1.0
			_state = S.TO_CUSTOMER_ORDER
			return


## Counts down the short "working" pause once the waiter has arrived.
func _work_done(delta: float) -> bool:
	if _work_timer < 0.0:
		_work_timer = work_time
	_work_timer -= delta
	return _work_timer <= 0.0


func _go_home() -> void:
	if is_instance_valid(_customer):
		_customer.claimed = false
	_customer = null
	_work_timer = -1.0
	_state = S.RETURN


## Give up on (or finish) the current order and head back.
func _drop_order() -> void:
	if _order != null:
		_order.claimed = false
	_order = null
	_plate = null
	if _held and is_instance_valid(_held):
		_held.queue_free()
	_held = null
	_go_home()


func _hold(order: Order) -> void:
	_held = Food.spawn_served(order.dish_id)
	held_point.add_child(_held)


## Walks toward `target`. Returns true once there.
func _walk(target: Vector3, delta: float) -> bool:
	var flat := Vector3(target.x, position.y, target.z)
	var d := flat - position
	if d.length() < 0.05:
		_anim.play(IDLE_NAMES)
		return true
	rotation.y = atan2(d.x, d.z) # models face +Z
	position = position.move_toward(flat, speed * delta)
	_anim.play(WALK_NAMES)
	return false
