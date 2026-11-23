class_name Player
extends CharacterBody3D
## First-person controller. Look at something and press E (or click) to interact.

signal notice(text: String)

@export var speed: float = 5.0
@export var sensitivity: float = 0.0025
@export var reach: float = 3.5
@export var gravity: float = 20.0
@export var step_interval: float = 0.45 # seconds between footstep sounds
## Arrow keys turn the camera too (radians per second), for players without a mouse lock.
@export var key_turn_speed: float = 2.2

@onready var camera: Camera3D = $Camera3D
@onready var held_point: Marker3D = $Camera3D/HeldPoint

var enabled: bool = true
var pitch: float = 0.0
var prompt: String = ""
var target: Node = null
var held_orders: Array[Order] = [] # plates you're carrying (more than one with the Serving Tray upgrade)
var _held_root: Node3D # the plates (and the tray, if carrying more than one) in your hands
var busy: bool = false # true while playing the cooking minigame
var build_mode: bool = false # true while in build mode (clicks build instead of interacting)
var _step_timer: float = 0.0


func _ready() -> void:
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.4, 1.4)
		camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not build_mode:
			_interact()
	elif event.is_action_pressed("interact") and not event.is_echo():
		if not build_mode:
			_interact() # E or the controller's A button


func _physics_process(delta: float) -> void:
	if enabled:
		# WASD or the left stick (a half-pushed stick walks slower).
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var dir := transform.basis * Vector3(input.x, 0, input.y)
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		# Arrow keys or the right stick turn the camera; the mouse sensitivity setting scales it too.
		var look := Input.get_vector("look_left", "look_right", "look_down", "look_up")
		if look != Vector2.ZERO:
			var turn_speed := key_turn_speed * (sensitivity / 0.0025)
			rotate_y(-look.x * turn_speed * delta)
			pitch = clampf(pitch + look.y * turn_speed * 0.6 * delta, -1.4, 1.4)
			camera.rotation.x = pitch
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	_footsteps(delta)

	_check_held()
	_update_target()


func _update_target() -> void:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space := get_world_3d().direct_space_state

	# Look past things that have nothing to do right now (e.g. an empty front burner whose box
	# sits in front of the pan on the back burner) so they don't block what's behind them.
	target = null
	prompt = ""
	var skipped: Array[RID] = []
	for i in 4:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		if hit.collider.has_method("interact"):
			var text: String = hit.collider.get_prompt(self)
			if text != "":
				target = hit.collider
				prompt = text
				break
		skipped.append(hit.rid)
		query.exclude = skipped


func _interact() -> void:
	if target and is_instance_valid(target):
		Sfx.play(&"Interact")
		target.interact(self)


func _footsteps(delta: float) -> void:
	if enabled and is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5:
		_step_timer -= delta
		if _step_timer <= 0.0:
			Sfx.play(&"Footstep")
			_step_timer = step_interval
	else:
		_step_timer = 0.0


# ---- Carrying a plate ----------------------------------------------------

## How many plates you can carry at once (1, or more with the Serving Tray upgrade).
func carry_capacity() -> int:
	return GameState.carry_capacity()


func can_carry_more() -> bool:
	return held_orders.size() < carry_capacity()


## The plate you're carrying for `customer`, if any.
func held_for(customer: Customer) -> Order:
	for o in held_orders:
		if o.customer == customer:
			return o
	return null


func add_held(order: Order) -> void:
	if not can_carry_more():
		return
	Sfx.play(&"PickUp")
	held_orders.append(order)
	_rebuild_held()


func remove_held(order: Order) -> void:
	held_orders.erase(order)
	_rebuild_held()


func clear_held() -> void:
	held_orders.clear()
	_rebuild_held()


## One plate: held in your hand. Two or more: plates side by side on a serving tray.
func _rebuild_held() -> void:
	if _held_root != null and is_instance_valid(_held_root):
		_held_root.queue_free()
	_held_root = null
	if held_orders.is_empty():
		return
	_held_root = Node3D.new()
	held_point.add_child(_held_root)
	if carry_capacity() == 1:
		_held_root.scale = Vector3.ONE * 0.75
		_held_root.add_child(Food.spawn_served(held_orders[0].dish_id))
		return
	# A tray as wide as the plates it can hold, held a little lower and to the middle.
	var n := carry_capacity()
	var cols := 2 if n > 2 else n
	var rows := int(ceil(float(n) / float(cols)))
	var spacing := 0.46
	_held_root.position = Vector3(-0.3, -0.12, -0.05)
	_held_root.scale = Vector3.ONE * 0.5
	var tray := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(cols * spacing + 0.06, 0.025, rows * spacing + 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.36, 0.2)
	box.material = mat
	tray.mesh = box
	tray.position.y = -0.0125
	_held_root.add_child(tray)
	for i in held_orders.size():
		var served := Food.spawn_served(held_orders[i].dish_id)
		var c := i % cols
		var r := i / cols
		served.position = Vector3((c - (cols - 1) / 2.0) * spacing, 0.0, (r - (rows - 1) / 2.0) * spacing)
		_held_root.add_child(served)


func _check_held() -> void:
	var gone := held_orders.filter(func(o: Order) -> bool: return not o.is_active())
	if gone.is_empty():
		return
	for o in gone:
		held_orders.erase(o)
	notice.emit("That customer left! The plate was thrown out.")
	_rebuild_held()
