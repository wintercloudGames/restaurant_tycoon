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
var held_order: Order = null
var held_visual: Node3D = null
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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if not build_mode:
			_interact()


func _physics_process(delta: float) -> void:
	if enabled:
		var input := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if not build_mode:
			var turn := float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
			var tilt := float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))
			rotate_y(-turn * key_turn_speed * delta)
			pitch = clampf(pitch + tilt * key_turn_speed * 0.6 * delta, -1.4, 1.4)
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

func set_held(order: Order) -> void:
	clear_held()
	Sfx.play(&"PickUp")
	held_order = order
	held_visual = Food.spawn(order.dish_id)
	held_point.add_child(held_visual)


func clear_held() -> void:
	held_order = null
	if held_visual and is_instance_valid(held_visual):
		held_visual.queue_free()
	held_visual = null


func _check_held() -> void:
	if held_order and not held_order.is_active():
		notice.emit("That customer left! The plate was thrown out.")
		clear_held()
