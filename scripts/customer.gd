class_name Customer
extends Area3D
## Walks in, sits, asks for food in a chat bubble, waits for the order to be taken and
## the food to arrive, eats, pays and leaves. Edit customer.tscn to change the look.

signal order_taken(customer: Customer)

enum State { WALK_TO_TABLE, WAIT_ORDER, WAIT_FOOD, EATING, LEAVING }

# Animation names are matched loosely (case-insensitive, first hit wins).
# The full list found in your model is printed to the Output panel on the first customer.
const WALK_NAMES: Array[String] = ["walk"]
## How big the speech bubbles are (1.0 = the full-size picture).
const BUBBLE_SCALE := 0.8
const SIT_NAMES: Array[String] = ["sit", "idle"]

@export var speed: float = 3.0
@export var patience_seconds: float = 100.0
@export var eat_seconds: float = 3.0
## How far above the chair seat the hip joint sits when seated.
@export var hip_above_seat: float = 0.06
## Extra manual lift (+) or drop (-) while seated, if the sitting still looks off.
@export var sit_offset_extra: float = 0.0

var state: State = State.WALK_TO_TABLE
var table: Table
var exit_pos: Vector3
var dish_id: String = ""
var patience: float = 1.0
var timer: float = 0.0
var seat_index: int = 0 # which chair at the table
var start_delay: float = 0.0
var claimed: bool = false # a waiter is on the way to take this customer's order
var quality: float = 0.75 # quality of the food they were served
var food: Node3D

@onready var model: Node3D = $Model
@onready var bubble: MeshInstance3D = $Bubble
@onready var bubble_label: Label3D = $BubbleLabel

var mood_root: Node3D # the speech bubble: food picture, mood face, patience bar
var _bg: Sprite3D
var _tail: Sprite3D
var _food_sprite: Sprite3D
var _mood_face: Sprite3D
var _bar_back: Sprite3D
var _bar_fill: Sprite3D
var _badge: Sprite3D
var _mood: String = ""
var _bubble_shown: bool = false
var _bubble_scale: float = 0.0
var _bubble_time: float = 0.0
var _anim: CharAnim
var _last_text: String = ""
var _bob_time: float = 0.0
var _sit_offset: float = 0.0
static var _logged_sit: bool = false
static var _logged_sit_result: bool = false
static var _logged_anims: bool = false


## `p_seat` is the chair number at the table; `delay` staggers the people of a party so they
## don't all appear on top of each other at the door.
func setup(p_table: Table, p_seat: int, start: Vector3, p_exit: Vector3, delay: float = 0.0) -> void:
	table = p_table
	seat_index = p_seat
	position = start
	exit_pos = p_exit
	start_delay = delay
	visible = delay <= 0.0


func _ready() -> void:
	add_to_group("customers")
	Sfx.play(&"CustomerArrive")
	_build_bubble()
	_anim = CharAnim.new(model)
	_anim.play(WALK_NAMES)
	if _anim.player != null and not Customer._logged_anims:
		Customer._logged_anims = true
		print("Customer animations available: ", _anim.player.get_animation_list())


## The speech bubble is a small group of pictures that always faces the camera:
## a bubble (tinted by mood), a picture of the food they want, a mood face, a patience bar,
## a "!" badge while they wait to order, and a short caption.
func _build_bubble() -> void:
	# Stagger the bubbles of a party so neighbours don't cover each other.
	var lift := 0.32 * float(seat_index % 3)
	mood_root = Node3D.new()
	mood_root.name = "MoodBubble"
	mood_root.position = Vector3(0, 2.35 + lift, 0)
	mood_root.visible = false
	add_child(mood_root)
	bubble.mesh = null # the old plain white box isn't used any more
	bubble.visible = false

	_bg = _sprite(MoodIcons.bubble(), 0.0046, Vector3(0, 0, 0), 0)
	_tail = _sprite(MoodIcons.tail(), 0.0046, Vector3(0, -0.47, 0), 0)
	_food_sprite = _sprite(null, 0.0038, Vector3(-0.30, 0.10, 0.01), 1)
	_mood_face = _sprite(MoodIcons.face("happy"), 0.0072, Vector3(0.33, 0.14, 0.01), 1)
	_bar_back = _sprite(MoodIcons.white(), 0.01, Vector3(0, -0.33, 0.01), 1)
	_bar_back.modulate = Color(0.15, 0.15, 0.2, 0.9)
	_bar_back.scale = Vector3(25.0, 1.25, 1.0) # 1.0 wide, 0.05 tall
	_bar_fill = _sprite(MoodIcons.white(), 0.01, Vector3(0, -0.33, 0.02), 2)
	_badge = _sprite(MoodIcons.badge(), 0.0045, Vector3(0.56, 0.37, 0.03), 3)

	bubble_label.reparent(mood_root, false)
	bubble_label.position = Vector3(0, -0.2, 0.02)
	bubble_label.font_size = 30
	bubble_label.pixel_size = 0.0042
	bubble_label.render_priority = 3


func _sprite(tex: Texture2D, pixel_size: float, pos: Vector3, priority: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = pixel_size
	s.shaded = false
	s.transparent = true
	s.no_depth_test = true
	s.render_priority = priority
	s.position = pos
	mood_root.add_child(s)
	return s


## How the customer feels right now.
func _current_mood() -> String:
	if state == State.LEAVING:
		return "angry" if _last_text == "Angry!" else "yum"
	if state == State.EATING:
		return "yum"
	if patience > 0.66:
		return "happy"
	if patience > 0.4:
		return "neutral"
	if patience > 0.15:
		return "worried"
	return "angry"


func _update_bubble(delta: float) -> void:
	if mood_root == null:
		return
	mood_root.visible = _bubble_shown
	if not _bubble_shown:
		return
	_bubble_time += delta
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		mood_root.look_at(camera.global_position, Vector3.UP, true) # +Z towards the camera

	var mood := _current_mood()
	if mood != _mood:
		_mood = mood
		_mood_face.texture = MoodIcons.face(mood)
		_bg.modulate = MoodIcons.mood_color(mood)
		_tail.modulate = _bg.modulate

	# The patience bar only matters while they are waiting.
	var waiting := state == State.WAIT_ORDER or state == State.WAIT_FOOD
	var p := clampf(patience, 0.0, 1.0)
	_bar_back.visible = waiting
	_bar_fill.visible = waiting
	_bar_fill.scale = Vector3(25.0 * maxf(p, 0.001), 1.25, 1.0)
	_bar_fill.position.x = -0.5 + 0.5 * p
	_bar_fill.modulate = MoodIcons.bar_color(p)

	# A pulsing "!" while waiting for someone to take their order.
	_badge.visible = state == State.WAIT_ORDER
	_badge.scale = Vector3.ONE * (1.0 + 0.15 * sin(_bubble_time * 6.0))

	# Nearer bubbles are drawn completely on top of farther ones (every piece of a bubble gets a
	# priority band by distance), so overlapping bubbles don't show through each other.
	if camera != null:
		var band := (30 - clampi(int(camera.global_position.distance_to(mood_root.global_position) * 2.0), 0, 30)) * 4
		_bg.render_priority = band
		_tail.render_priority = band
		_food_sprite.render_priority = band + 1
		_mood_face.render_priority = band + 1
		_bar_back.render_priority = band + 1
		_bar_fill.render_priority = band + 2
		_badge.render_priority = band + 3
		bubble_label.render_priority = band + 3

	# Pop in, then wiggle when worried or angry.
	_bubble_scale = move_toward(_bubble_scale, 1.0, delta * 5.0)
	mood_root.scale = Vector3.ONE * BUBBLE_SCALE * maxf(1.0 - pow(1.0 - _bubble_scale, 3.0), 0.05)
	var wiggle := 0.0
	if _mood == "worried":
		wiggle = sin(_bubble_time * 9.0) * 0.05
	elif _mood == "angry":
		wiggle = sin(_bubble_time * 24.0) * 0.12
	if wiggle != 0.0:
		mood_root.rotate_object_local(Vector3.BACK, wiggle)


func _hide_bubble() -> void:
	_bubble_shown = false
	if mood_root != null:
		mood_root.visible = false
	bubble_label.visible = false


func _say(text: String) -> void:
	if text == _last_text:
		return
	_last_text = text
	bubble_label.text = text
	if not _bubble_shown:
		_bubble_scale = 0.0 # pop in
	_bubble_shown = true
	bubble_label.visible = true


## Chair letter at the table: A, B, C ...
func seat_letter() -> String:
	return char(65 + seat_index)


## "T3-B": table 3, chair B.
func where() -> String:
	return "T%d-%s" % [table.number, seat_letter()]


## Where a waiter stands to serve this customer.
func get_waiter_spot() -> Vector3:
	return table.get_waiter_spot(seat_index)


func _dish_name() -> String:
	return GameState.DISHES[dish_id]["name"]


func _process(delta: float) -> void:
	_update_bob(delta)
	_update_bubble(delta)
	match state:
		State.WALK_TO_TABLE:
			if start_delay > 0.0:
				start_delay -= delta
				if start_delay <= 0.0:
					visible = true
					Sfx.play(&"CustomerArrive")
				return
			if _move_to(table.get_seat(seat_index), delta):
				_face(table.global_position)
				_anim.play(SIT_NAMES)
				# Start by lifting by the chair height (the sit pose usually sits at floor level),
				# then refine using the model's hip bone.
				_sit_offset = table.get_seat_height() + sit_offset_extra
				_calibrate_sit()
				dish_id = GameState.random_unlocked_dish()
				_food_sprite.texture = FoodIcons.texture_for(dish_id)
				state = State.WAIT_ORDER
				_say("%s, please!" % _dish_name())
		State.WAIT_ORDER:
			_lose_patience(delta)
		State.WAIT_FOOD:
			_lose_patience(delta)
		State.EATING:
			timer -= delta
			if timer <= 0.0:
				_pay_and_leave()
		State.LEAVING:
			if _move_to(exit_pos, delta):
				queue_free()


# ---- Interaction (called by the player's raycast) ------------------------

func get_prompt(player: Player) -> String:
	match state:
		State.WAIT_ORDER:
			return "[E] Take order (%s)" % where()
		State.WAIT_FOOD:
			var held := player.held_order
			if held == null:
				return "Waiting for %s" % _dish_name()
			if held.customer == self:
				return "[E] Serve %s" % _dish_name()
			return "Wrong plate - this is %s" % where()
	return ""


func interact(player: Player) -> void:
	match state:
		State.WAIT_ORDER:
			take_order()
		State.WAIT_FOOD:
			if player.held_order != null and player.held_order.customer == self:
				var plate_order := player.held_order
				player.clear_held()
				serve(plate_order)


func take_order() -> void:
	if state != State.WAIT_ORDER:
		return
	state = State.WAIT_FOOD
	Sfx.play(&"OrderTaken")
	_say("Waiting for %s..." % _dish_name())
	order_taken.emit(self)


## Called when the player or a waiter delivers the food.
func serve(order: Order) -> void:
	if state != State.WAIT_FOOD:
		return
	quality = order.quality
	Sfx.play(&"Serve")
	_start_eating()


# ---- Internals -----------------------------------------------------------

func _start_eating() -> void:
	state = State.EATING
	Sfx.play(&"Eat")
	timer = eat_seconds
	_say("Yum!")
	food = Food.spawn(dish_id)
	table.add_food(food, seat_index)


func _lose_patience(delta: float) -> void:
	# Dishes with more steps take longer, so those customers are more patient.
	var step_factor := 0.8 + 0.2 * float(GameState.dish_steps(dish_id).size())
	patience -= delta / (patience_seconds * GameState.patience_multiplier() * step_factor)
	if patience <= 0.0:
		_say("Angry!")
		Sfx.play(&"Angry")
		_leave()


func _pay_and_leave() -> void:
	var price: int = GameState.dish_price(dish_id)
	var base := int(price * lerpf(0.5, 1.0, quality)) # burnt food pays less
	var tip := int(price * 0.5 * clampf(patience, 0.0, 1.0) * quality * GameState.tip_multiplier())
	GameState.earn(base + tip)
	GameState.add_xp(GameState.xp_for_plate(price, quality))
	Sfx.play(&"Pay")
	_leave()


func _leave() -> void:
	if food and is_instance_valid(food):
		food.queue_free()
		food = null
	table.party_member_left() # the table is free once the whole party has gone
	state = State.LEAVING
	_sit_offset = 0.0
	_anim.play(WALK_NAMES)
	if _last_text != "Angry!":
		_hide_bubble()


## Keeps the model at its sit height, plus (if the model has no AnimationPlayer)
## a little hop while walking.
func _update_bob(delta: float) -> void:
	var hop := 0.0
	if _anim.player == null:
		var moving := state == State.WALK_TO_TABLE or state == State.LEAVING
		_bob_time += delta
		if moving:
			hop = absf(sin(_bob_time * 10.0)) * 0.08
	model.position.y = _sit_offset + hop


## The sit animation can leave the character at floor level (so the table hides them).
## Once the sit pose is playing, measure where the hips are and move the model so the
## hips end up just above the chair seat.
func _calibrate_sit() -> void:
	# Wait until the walk -> sit animation blend has finished, otherwise the hips are still
	# mid-transition and we would under-lift the customer (they'd sit on the floor).
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree() or state == State.LEAVING:
		return
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	var skel := found[0] as Skeleton3D
	var names: Array[String] = []
	for i in skel.get_bone_count():
		names.append(skel.get_bone_name(i))
	if not Customer._logged_sit:
		Customer._logged_sit = true
		print("Customer skeleton bones: ", names)

	var heights: Array[float] = []
	for key in ["hip", "leg", "thigh"]:
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).to_lower().contains(key):
				var p := skel.global_transform * skel.get_bone_global_pose(i).origin
				heights.append(p.y - global_position.y)
		if not heights.is_empty():
			break
	if heights.is_empty():
		return
	var hip := 0.0
	for h in heights:
		hip += h
	hip /= float(heights.size())
	hip -= model.position.y # hip height of the pose itself, without our current lift
	var seat_h := table.get_seat_height()
	_sit_offset = clampf(seat_h + hip_above_seat - hip, -0.5, 0.8) + sit_offset_extra
	if not Customer._logged_sit_result:
		Customer._logged_sit_result = true
		print("Sit calibration: hip height %.2f, seat %.2f -> moved model by %.2f" % [hip, seat_h, _sit_offset])


func _face(target: Vector3) -> void:
	var d := Vector3(target.x - position.x, 0, target.z - position.z)
	if d.length() > 0.01:
		look_at(position - d, Vector3.UP) # model faces +Z, so look away


func _move_to(target: Vector3, delta: float) -> bool:
	var flat_target := Vector3(target.x, position.y, target.z)
	_face(flat_target)
	position = position.move_toward(flat_target, speed * delta)
	return position.distance_to(flat_target) < 0.05


func _exit_tree() -> void:
	if food and is_instance_valid(food):
		food.queue_free()
