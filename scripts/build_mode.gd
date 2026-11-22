class_name BuildMode
extends Node
## Build mode (press V). Look at the floor and a ghost of the selected item follows the
## crosshair, snapped to a grid. Green = you can place it, red = you can't.
##   1-9 / mouse wheel   choose an item (tables come WITHOUT chairs; chairs are placed separately)
##   Left click          place the item (or, with empty hands, pick something up to move it)
##   R                   rotate 90 degrees
##   Right click         cancel what you're holding (or, with empty hands, sell the thing you point
##                       at for half its price: decor, a chair, or a table together with its chairs)
##   Chairs snap to the free chair spots around a table; a table never takes more chairs than it seats.
##   V or Esc            leave build mode
## You can still walk around with WASD while building. Edit the catalog in build_catalog.gd.

const GRID := 0.5

## The part of the floor you may build on (x, z): the whole restaurant. The ticket board,
## order-up table, starter stove / counter and the staff's spots are protected by the kitchen.
@export var build_min: Vector2 = Vector2(-7.6, -7.4)
@export var build_max: Vector2 = Vector2(7.6, 11.6)
## Keep this far from the door, where customers walk in.
@export var door_clear_radius: float = 1.6
@export var sell_refund: float = 0.5
@export var reach: float = 9.0

var active: bool = false
var selected: int = -1
var held: Node3D
var held_def: Dictionary = {}
var held_new: bool = false
var held_kind: String = "" # "table", "chair" or "decor"
var held_origin: Transform3D = Transform3D.IDENTITY

var player: Player
var tables: Array[Table] = []
var door: Marker3D
var kitchen: Kitchen
var plots: RestaurantPlots # the floor you may build on (grows with expansions)
var items_parent: Node3D
var ui: BuildUi
var grid: BuildGrid

var _placed_scene: PackedScene
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var _rot: float = 0.0
var _origin_table: Table # where a chair you picked up came from (it goes back there if you cancel)
var _origin_slot: int = -1
var _slot_markers: Array[MeshInstance3D] = []
var _marker_mat: StandardMaterial3D


func setup(p_player: Player, p_tables: Array[Table], p_door: Marker3D, p_kitchen: Kitchen, p_plots: RestaurantPlots = null) -> void:
	plots = p_plots
	player = p_player
	tables = p_tables
	door = p_door
	kitchen = p_kitchen
	_placed_scene = load("res://scenes/placed_item.tscn") as PackedScene

	items_parent = Node3D.new()
	items_parent.name = "PlacedItems"
	add_child(items_parent)

	ui = (load("res://scenes/build_ui.tscn") as PackedScene).instantiate() as BuildUi
	add_child(ui)
	ui.visible = false

	var sounds := (load("res://scenes/build_sounds.tscn") as PackedScene).instantiate()
	add_child(sounds)
	Sfx.add_root(sounds)

	grid = BuildGrid.new()
	grid.name = "Grid"
	add_child(grid)
	grid.visible = false

	_ok_mat = _ghost_material(Color(0.3, 1.0, 0.4, 0.55))
	_bad_mat = _ghost_material(Color(1.0, 0.3, 0.3, 0.55))
	_marker_mat = _ghost_material(Color(1.0, 0.9, 0.2, 0.6))


func _ghost_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# ---- Turning build mode on / off -----------------------------------------

func toggle() -> void:
	if active:
		deactivate()
	else:
		activate()


func activate() -> void:
	var main := get_parent()
	if active or player.busy or not player.enabled or bool(main.get("shop_open")):
		return
	active = true
	player.build_mode = true
	ui.visible = true
	grid.fit(plots.bounds() if plots != null else Rect2(-8, -8, 16, 20))
	grid.visible = true
	selected = -1
	_refresh_ui()
	ui.set_status("Pick an item: 1-9 or mouse wheel.  Click something to move it, right-click to sell.")
	Sfx.play(&"BuildToggle")


func deactivate() -> void:
	if not active:
		return
	_cancel_hold()
	active = false
	player.build_mode = false
	ui.visible = false
	grid.visible = false
	_hide_slot_markers()
	GameState.save_game()
	Sfx.play(&"BuildToggle")


# ---- Input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			toggle()
			get_viewport().set_input_as_handled()
			return
		if not active:
			return
		if event.keycode == KEY_ESCAPE:
			deactivate()
		elif event.keycode == KEY_R:
			_rotate()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index: int = event.keycode - KEY_1
			if index < BuildCatalog.ITEMS.size():
				_select(index)
		else:
			return
		get_viewport().set_input_as_handled()
	elif active and event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_select(selected - 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_select(selected + 1)
			MOUSE_BUTTON_LEFT:
				_left_click()
			MOUSE_BUTTON_RIGHT:
				_right_click()


func _left_click() -> void:
	if held != null:
		_try_place()
		return
	var node := _pick()
	if node != null:
		_pick_up(node)


func _right_click() -> void:
	if held != null:
		_cancel_hold()
		ui.set_status("Cancelled.")
		return
	var node := _pick()
	if node is PlacedItem:
		_sell(node as PlacedItem)
	elif node is Chair:
		_sell_chair(node as Chair)
	elif node is Table:
		_sell_table(node as Table)


func _rotate() -> void:
	_rot = wrapf(_rot + PI / 2.0, 0.0, TAU)
	if held != null:
		held.rotation.y = _rot
	Sfx.play(&"BuildRotate")


# ---- Choosing and holding items ------------------------------------------

## Starts holding catalog item `index` (used by the shop's Build tab).
func select_index(index: int) -> void:
	_select(index)


func _select(index: int) -> void:
	_cancel_hold()
	selected = posmod(index, BuildCatalog.ITEMS.size())
	ui.set_selected(selected)
	var def := BuildCatalog.ITEMS[selected]
	_rot = 0.0
	if GameState.rank() < BuildCatalog.rank_of(def):
		ui.set_status("%s needs restaurant rank %d (you are rank %d)." % [def["name"], BuildCatalog.rank_of(def), GameState.rank()], false)
		Sfx.play(&"BuildError")
		return
	if def["kind"] == "table":
		if GameState.table_count >= GameState.max_tables():
			ui.set_status("Table limit reached (%d). Expand your restaurant to allow more tables." % GameState.max_tables(), false)
			Sfx.play(&"BuildError")
			return
		var table := _next_free_table()
		if table == null:
			ui.set_status("No free table spot left.", false)
			Sfx.play(&"BuildError")
			return
		table.configure(int(def["seats"])) # a table for 2, 4 or 6 (it holds that many chairs)
		held = table
		held_kind = "table"
		held_origin = table.global_transform
		table.build_holding = true
		table.set_active(true)
	elif def["kind"] == "chair":
		held = _new_ghost_chair()
		held_kind = "chair"
		held_origin = held.global_transform
	else:
		var item := _new_item(def)
		held = item
		held_kind = "decor"
		held_origin = item.global_transform
	held_def = def
	held_new = true
	_set_ghost(held, true)
	Sfx.play(&"BuildSelect")


func _pick_up(node: Node3D) -> void:
	if node is Chair:
		var chair := node as Chair
		var chair_table := chair.table
		if chair_table == null or chair_table.occupied:
			ui.set_status("Customers are sitting at that table.", false)
			Sfx.play(&"BuildError")
			return
		_origin_table = chair_table
		_origin_slot = chair.slot
		chair_table.remove_chair(chair.slot) # you carry it; cancel puts it back
		held = _new_ghost_chair()
		held_kind = "chair"
		held_def = BuildCatalog.find("chair")
		held_new = false
		_set_ghost(held, true)
		Sfx.play(&"BuildSelect")
		return
	if node is Table:
		var table := node as Table
		if table.occupied:
			ui.set_status("A customer is using that table.", false)
			Sfx.play(&"BuildError")
			return
		table.occupied = true # reserved so no customer walks to it while you carry it
		held_kind = "table"
		held_def = BuildCatalog.table_def(table.seats)
	else:
		var placed := node as PlacedItem
		if placed.is_busy():
			ui.set_status("Finish the food on it first.", false)
			Sfx.play(&"BuildError")
			return
		held_kind = "decor"
		held_def = placed.def
	held = node
	held_new = false
	held_origin = node.global_transform
	_rot = node.rotation.y
	_set_ghost(held, true)
	Sfx.play(&"BuildSelect")


func _cancel_hold() -> void:
	if held == null:
		return
	_tint(held, null)
	if held_kind == "chair":
		held.get_parent().remove_child(held)
		held.queue_free()
		if not held_new and _origin_table != null and is_instance_valid(_origin_table):
			_origin_table.add_chair(_origin_slot) # back where it came from
		held = null
		_hide_slot_markers()
		return
	if held_new:
		if held_kind == "table":
			var table := held as Table
			table.global_transform = held_origin
			table.build_holding = false
			table.set_active(false)
		else:
			held.get_parent().remove_child(held)
			held.queue_free()
	else:
		held.global_transform = held_origin
		_set_ghost(held, false)
		if held is Table:
			(held as Table).occupied = false
	held = null


func _set_ghost(node: Node3D, on: bool) -> void:
	if node is PlacedItem:
		(node as PlacedItem).set_ghost(on)
	elif node is Chair:
		(node as Chair).set_pickable(not on)
	elif node is Table:
		var table := node as Table
		table.build_holding = on
		table.body.collision_layer = 0 if on else 1
		table.set_chairs_pickable(not on)


func _new_item(def: Dictionary) -> PlacedItem:
	var item := _placed_scene.instantiate() as PlacedItem
	item.setup(def)
	items_parent.add_child(item)
	return item


# ---- Placing, selling ----------------------------------------------------

func _try_place() -> void:
	if held_kind == "chair":
		_place_chair()
		return
	var reason := _check(held)
	if reason != "":
		ui.set_status(reason, false)
		Sfx.play(&"BuildError")
		return
	if held_new:
		if held_kind == "table":
			if not GameState.buy_table(int(held_def["seats"]), (held as Table).number):
				ui.set_status("Not enough money.", false)
				Sfx.play(&"BuildError")
				return
		else:
			if not GameState.spend(BuildCatalog.cost_of(held_def)):
				ui.set_status("Not enough money.", false)
				Sfx.play(&"BuildError")
				return
			GameState.purchased.emit()

	_tint(held, null)
	_set_ghost(held, false)
	if held is Table:
		var table := held as Table
		table.occupied = false
		table.set_active(true)
	held = null
	Sfx.play(&"BuildPlace")
	_sync_state()
	if held_new:
		_select(selected) # keep placing more of the same
	else:
		ui.set_status("Placed.")


func _sell(item: PlacedItem) -> void:
	if item.is_busy():
		ui.set_status("Finish the food on it first.", false)
		Sfx.play(&"BuildError")
		return
	var value := int(int(item.def["cost"]) * sell_refund)
	GameState.add_money(value)
	item.get_parent().remove_child(item)
	item.queue_free()
	ui.set_status("Sold for $%d." % value)
	Sfx.play(&"BuildSell")
	_sync_state()


## Writes the current layout into GameState (so it is saved) and refreshes the UI.
func _sync_state() -> void:
	var list: Array = []
	for child in items_parent.get_children():
		var item := child as PlacedItem
		if item != null and not item.ghost:
			list.append({"id": item.item_id, "x": item.position.x, "z": item.position.z, "rot": item.rotation.y})
	GameState.placed = list
	var layout := {}
	for t in tables:
		layout[str(t.number)] = {"x": t.position.x, "z": t.position.z, "rot": t.rotation.y, "seats": t.seats, "chairs": t.filled_slots()}
	GameState.table_layout = layout
	GameState.changed.emit()
	_refresh_ui()


## Applies the saved layout (called once after the save is loaded).
func restore_layout() -> void:
	for t in tables:
		var d = GameState.table_layout.get(str(t.number))
		if d is Dictionary:
			t.configure(int(d.get("seats", 2)))
			t.position = Vector3(float(d["x"]), t.position.y, float(d["z"]))
			t.rotation.y = float(d["rot"])
			if d.has("chairs"):
				t.set_chairs(d["chairs"])
				continue
		# Starter tables and tables from older saves come with all their chairs.
		if GameState.is_table_owned(t.number):
			t.fill_chairs()
		else:
			t.clear_chairs()
	for child in items_parent.get_children():
		items_parent.remove_child(child)
		child.queue_free()
	for d in GameState.placed:
		var def := BuildCatalog.find(str(d["id"]))
		if def.is_empty():
			continue
		var item := _new_item(def)
		item.position = Vector3(float(d["x"]), 0.0, float(d["z"]))
		item.rotation.y = float(d["rot"])
	_refresh_ui()


func _refresh_ui() -> void:
	var names: Array[String] = []
	var locked: Array[bool] = []
	for i in BuildCatalog.ITEMS.size():
		var d := BuildCatalog.ITEMS[i]
		var cost_text := "$%d" % BuildCatalog.cost_of(d)
		if d["kind"] == "table" and GameState.table_count >= GameState.max_tables():
			cost_text = "limit %d" % GameState.max_tables()
		var is_locked := GameState.rank() < BuildCatalog.rank_of(d)
		if is_locked:
			cost_text = "Rank %d" % BuildCatalog.rank_of(d)
		names.append("%d  %s   %s" % [i + 1, d["name"], cost_text])
		locked.append(is_locked)
	ui.set_items(names)
	ui.set_locked(locked)
	ui.set_selected(selected)
	ui.set_appeal(GameState.decor_appeal(), GameState.tip_multiplier())


# ---- Every frame ---------------------------------------------------------

func _process(_delta: float) -> void:
	if not active:
		return
	if held != null:
		_update_held()
		grid.set_focus(held.global_position)
	else:
		_update_hover()
		grid.set_focus(_ground_point())


func _update_held() -> void:
	if held_kind == "chair":
		_update_held_chair()
		return
	_hide_slot_markers()
	var p := _ground_point()
	held.global_position = Vector3(snappedf(p.x, GRID), 0.0, snappedf(p.z, GRID))
	held.rotation.y = _rot
	var reason := _check(held)
	_tint(held, _ok_mat if reason == "" else _bad_mat)
	if reason == "":
		var verb := "Place" if held_new else "Put down"
		var price := ("  ($%d)" % BuildCatalog.cost_of(held_def)) if held_new else ""
		ui.set_status("%s %s%s   |   R rotate   |   Right-click cancel" % [verb, held_def["name"], price])
	else:
		ui.set_status(reason, false)


func _update_hover() -> void:
	_hide_slot_markers()
	var node := _pick()
	if node is PlacedItem:
		ui.set_status("%s  -  click: move   |   right-click: sell for $%d" % [
			(node as PlacedItem).def["name"], int(int((node as PlacedItem).def["cost"]) * sell_refund)])
	elif node is Chair:
		ui.set_status("Chair  -  click: move   |   right-click: sell for $%d" % int(GameState.CHAIR_COST * sell_refund))
	elif node is Table:
		var table := node as Table
		var value := int(GameState.table_base_price(table.seats) * sell_refund)
		var chair_value := table.chair_count() * int(GameState.CHAIR_COST * sell_refund)
		ui.set_status("Table for %d (%d/%d chairs)  -  click: move   |   right-click: sell for $%d%s" % [
			table.seats, table.chair_count(), table.seats, value,
			(" + $%d for its chairs" % chair_value) if chair_value > 0 else ""])


## Where the crosshair points on the floor.
func _ground_point() -> Vector3:
	var cam := player.camera
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	if dir.y < -0.02:
		var t := minf(-origin.y / dir.y, reach)
		var p := origin + dir * t
		p.y = 0.0
		return p
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	return Vector3(origin.x, 0.0, origin.z) + flat * reach


## The placed item or table under the crosshair, if any.
func _pick() -> Node3D:
	var from := player.camera.global_position
	var to := from - player.camera.global_transform.basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(from, to, 3)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var node: Node = hit["collider"]
	while node != null and not (node is PlacedItem or node is Table or node is Chair):
		node = node.get_parent()
	return node as Node3D


# ---- Is this spot OK? ----------------------------------------------------

## Returns "" if `node` can stay where it is, otherwise the reason it can't.
func _check(node: Node3D) -> String:
	var rect := _rect_of(node)
	if plots != null:
		if not plots.contains_rect(rect):
			return "Outside the build area"
	elif rect.position.x < build_min.x or rect.position.y < build_min.y \
			or rect.end.x > build_max.x or rect.end.y > build_max.y:
		return "Outside the build area"

	var door_pos := Vector2(door.global_position.x, door.global_position.z)
	var nearest := Vector2(clampf(door_pos.x, rect.position.x, rect.end.x), clampf(door_pos.y, rect.position.y, rect.end.y))
	if nearest.distance_to(door_pos) < door_clear_radius:
		return "Keep the entrance clear"

	var padded := rect.grow(-0.02) # a hair smaller, so things can sit exactly flush against each other
	if kitchen != null:
		for reserved in kitchen.reserved_rects():
			if padded.intersects(reserved):
				return "That's in the way of the kitchen"
	for other in _obstacles():
		if other != node and padded.intersects(_rect_of(other)):
			return "Something is in the way"

	var player_pos := Vector2(player.global_position.x, player.global_position.z)
	if rect.grow(0.45).has_point(player_pos):
		return "You're standing there"

	if held_new and node == held and GameState.money < BuildCatalog.cost_of(held_def):
		return "Not enough money ($%d)" % BuildCatalog.cost_of(held_def)
	return ""


func _obstacles() -> Array[Node3D]:
	var list: Array[Node3D] = []
	for t in tables:
		if t.visible:
			list.append(t)
	for child in items_parent.get_children():
		if child is PlacedItem:
			list.append(child)
	return list


## The area an item covers on the floor (axis-aligned, so rotations are handled).
func _rect_of(node: Node3D) -> Rect2:
	var local: Rect2 = (node as Table).footprint_local() if node is Table else (node as PlacedItem).footprint_local()
	var xf := node.global_transform
	var corners: Array[Vector3] = [
		Vector3(local.position.x, 0, local.position.y), Vector3(local.end.x, 0, local.position.y),
		Vector3(local.position.x, 0, local.end.y), Vector3(local.end.x, 0, local.end.y)]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in corners:
		var w := xf * c
		lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.z))
		hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.z))
	return Rect2(lo, hi - lo)


## Colors a whole model (green/red ghost), or restores it when `mat` is null.
func _tint(node: Node, mat: Material) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat


# ---- Chairs ----------------------------------------------------------------

## The next table you haven't bought yet (tables are bought in number order, and a sold
## table's number is free again).
func _next_free_table() -> Table:
	for t in tables:
		if not GameState.is_table_owned(t.number) and not t.build_holding:
			return t
	return null


func _new_ghost_chair() -> Chair:
	var chair := tables[0].make_chair()
	items_parent.add_child(chair)
	chair.set_pickable(false)
	return chair


## Which free chair spot a point on the floor snaps to: {table, slot, reason}. `table` is null
## (with a `reason`) if there isn't one: no table nearby, or the table already has all its chairs.
func _chair_snap(point: Vector3) -> Dictionary:
	var best_table: Table = null
	var best_slot := -1
	var best_dist := 1.5 # chairs snap to a spot up to this far away
	var full_table: Table = null
	for t in tables:
		if not t.visible or t.build_holding:
			continue
		var free := t.free_slots()
		if free.is_empty():
			var to_table := Vector2(point.x - t.global_position.x, point.z - t.global_position.z).length()
			if to_table < t.chair_radius() + 1.5:
				full_table = t
			continue
		for slot in free:
			var p := t.slot_position(slot)
			var d := Vector2(p.x - point.x, p.z - point.z).length()
			if d < best_dist:
				best_dist = d
				best_table = t
				best_slot = slot
	if best_table != null:
		return {"table": best_table, "slot": best_slot, "reason": ""}
	if full_table != null:
		return {"table": null, "slot": -1, "reason": "That table for %d already has all %d chairs" % [full_table.seats, full_table.seats]}
	return {"table": null, "slot": -1, "reason": "Chairs go next to a table"}


func _update_held_chair() -> void:
	var p := _ground_point()
	var snap := _chair_snap(p)
	var reason := str(snap["reason"])
	var chair := held as Chair
	if snap["table"] != null:
		var table: Table = snap["table"]
		chair.global_transform = table.slot_global_transform(int(snap["slot"]))
	else:
		chair.global_position = Vector3(p.x, 0.0, p.z)
		chair.rotation.y = _rot
	_show_slot_markers()
	if reason == "" and held_new and GameState.money < BuildCatalog.cost_of(held_def):
		reason = "Not enough money ($%d)" % BuildCatalog.cost_of(held_def)
	_tint(held, _ok_mat if reason == "" else _bad_mat)
	if reason == "":
		var table: Table = snap["table"]
		var verb := "Place" if held_new else "Put down"
		var price := ("  ($%d)" % BuildCatalog.cost_of(held_def)) if held_new else ""
		ui.set_status("%s chair%s  -  table for %d: %d/%d chairs   |   Right-click cancel" % [
			verb, price, table.seats, table.chair_count() + 1, table.seats])
	else:
		ui.set_status(reason, false)


func _place_chair() -> void:
	var snap := _chair_snap(held.global_position)
	if snap["table"] == null:
		ui.set_status(str(snap["reason"]), false)
		Sfx.play(&"BuildError")
		return
	if held_new:
		if not GameState.spend(BuildCatalog.cost_of(held_def)):
			ui.set_status("Not enough money.", false)
			Sfx.play(&"BuildError")
			return
		GameState.purchased.emit()
	var table: Table = snap["table"]
	var ghost := held
	held = null
	ghost.get_parent().remove_child(ghost)
	ghost.queue_free()
	table.add_chair(int(snap["slot"]))
	_origin_table = null
	_hide_slot_markers()
	Sfx.play(&"BuildPlace")
	_sync_state()
	if held_new:
		_select(selected) # keep placing more chairs
	else:
		ui.set_status("Moved the chair.")


## Little yellow discs on every free chair spot, shown while you hold a chair.
func _show_slot_markers() -> void:
	var spots: Array[Vector3] = []
	for t in tables:
		if t.visible and not t.build_holding:
			for slot in t.free_slots():
				spots.append(t.slot_position(slot))
	while _slot_markers.size() < spots.size():
		var marker := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.2
		disc.bottom_radius = 0.2
		disc.height = 0.02
		disc.material = _marker_mat
		marker.mesh = disc
		add_child(marker)
		_slot_markers.append(marker)
	for i in _slot_markers.size():
		_slot_markers[i].visible = i < spots.size()
		if i < spots.size():
			_slot_markers[i].global_position = spots[i] + Vector3(0, 0.03, 0)


func _hide_slot_markers() -> void:
	for marker in _slot_markers:
		marker.visible = false


func _sell_chair(chair: Chair) -> void:
	var owner_table := chair.table
	if owner_table == null or owner_table.occupied:
		ui.set_status("Customers are sitting at that table.", false)
		Sfx.play(&"BuildError")
		return
	var value := int(GameState.CHAIR_COST * sell_refund)
	GameState.add_money(value)
	owner_table.remove_chair(chair.slot)
	ui.set_status("Sold the chair for $%d." % value)
	Sfx.play(&"BuildSell")
	_sync_state()


## Selling a table also sells the chairs that are at it (each for its own refund).
func _sell_table(table: Table) -> void:
	if table.occupied:
		ui.set_status("Customers are at that table.", false)
		Sfx.play(&"BuildError")
		return
	var chairs := table.chair_count()
	var total := int(GameState.table_base_price(table.seats) * sell_refund) + chairs * int(GameState.CHAIR_COST * sell_refund)
	GameState.add_money(total)
	table.clear_chairs()
	GameState.sell_table(table.number)
	table.set_active(false)
	ui.set_status("Sold the table%s for $%d." % [(" and its %d chairs" % chairs) if chairs > 0 else "", total])
	Sfx.play(&"BuildSell")
	_sync_state()
