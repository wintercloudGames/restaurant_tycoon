class_name Cook
extends Node3D
## A hired cook. Takes tickets off the board, cooks on a free burner, and puts the
## finished dish on the order-up table. Edit cook.tscn to change the look.

const IDLE_NAMES: Array[String] = ["idle"]
const WORK_NAMES: Array[String] = ["interact-right", "interact"]

## Hired cooks are slower than a perfect run (1.0 = same time as the dish's cook time).
@export var time_multiplier: float = 1.3

var kitchen: Kitchen
var order: Order
var burner: Burner

var _total: float = 1.0
var _elapsed: float = 0.0
var _anim: CharAnim

@onready var model: Node3D = $Model


func _ready() -> void:
	_anim = CharAnim.new(model)
	_anim.play(IDLE_NAMES)


func _process(delta: float) -> void:
	if order == null:
		if kitchen.assign_cook_job(self):
			# A cook spreads the dish's cooking time over its steps.
			_total = GameState.cook_time(order.dish_id) / float(order.step_count()) * time_multiplier
			_elapsed = 0.0
			_anim.play(WORK_NAMES)
		return

	if not order.is_active():
		order = null # customer left; the burner clears itself
		burner = null
		_anim.play(IDLE_NAMES)
		return

	_elapsed += delta
	burner.status = "Chef %d%%" % int(clampf(_elapsed / _total, 0.0, 1.0) * 100.0)
	if _elapsed >= _total:
		var finished := order
		var step_quality := clampf(0.7 + 0.05 * GameState.cook_level, 0.0, 0.95)
		burner.clear()
		order = null
		burner = null
		_anim.play(IDLE_NAMES)
		kitchen.finish_step(finished, step_quality) # next step's ticket, or the finished plate
