class_name RestaurantPlots
extends Node3D
## The restaurant's floor space. You start with one plot (the room in main.tscn). Every
## expansion bolts another plot of the SAME size onto the existing space, in this order:
##   east, west, south, south-east, south-west, ... (never north: that's the kitchen wall).
## New plots get floor and walls on their outer edges; the walls where two plots meet are
## removed so the rooms join into one big space.
## Outer walls on the east, west and south have windows (glass you can see the street through),
## and the south wall of the front-most middle plot has the front door (see door_cell()).

const PLOT_SIZE := Vector2(16.0, 20.0) # x, z of one plot (the starting room)
const PLOT_CENTER := Vector2(0.0, 2.0) # where the starting plot is (x, z)
const WALL_HEIGHT := 4.0
const WALL_THICKNESS := 0.5
const BUILD_MARGIN := 0.4 # keep decor this far from an outside wall
const DOOR_WIDTH := 2.2
const DOOR_HEIGHT := 2.9
const WINDOW_WIDTH := 2.6
const WINDOW_BOTTOM := 1.0
const WINDOW_TOP := 2.8

## Which plot comes next, as grid steps from the starting plot (1, 0) = one plot east.
const ORDER: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(-1, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(-1, 2),
]
const SIDES := {
	"east": Vector2i(1, 0), "west": Vector2i(-1, 0),
	"south": Vector2i(0, 1), "north": Vector2i(0, -1),
}
const OPPOSITE := {"east": "west", "west": "east", "south": "north", "north": "south"}

@export var floor_color: Color = Color(0.85, 0.8, 0.7)
@export var wall_color: Color = Color(0.95, 0.92, 0.85)
@export var frame_color: Color = Color(0.42, 0.28, 0.18)
@export var glass_color: Color = Color(0.7, 0.85, 0.95, 0.25)

var cells: Array[Vector2i] = [Vector2i(0, 0)]

var _scene_walls: Dictionary = {} # side -> wall node of the starting plot (from main.tscn)
var _walls: Dictionary = {} # "gx,gz,side" -> wall node we built
var _nodes: Array[Node] = [] # everything we added (floors, walls)


## Tell the plots about the walls that are already in main.tscn, e.g.
## {"east": WallRight, "west": WallLeft, "south": WallFront, "north": WallBack}.
func adopt_scene_walls(walls: Dictionary) -> void:
	_scene_walls = walls
	# The starting room's east, west and south walls are rebuilt here so they get windows and
	# the front door; the north (kitchen) wall stays as it is in main.tscn.
	for side in ["east", "west", "south"]:
		var wall: Node = _scene_walls.get(side)
		if wall != null and is_instance_valid(wall):
			_scene_walls.erase(side)
			wall.get_parent().remove_child(wall)
			wall.queue_free()
			_build_wall(Vector2i(0, 0), side)


## Makes sure exactly `count` expansions exist (adds the missing ones).
func set_expansions(count: int) -> void:
	count = clampi(count, 0, ORDER.size())
	while cells.size() - 1 < count:
		_add_cell(ORDER[cells.size() - 1])


func expansion_count() -> int:
	return cells.size() - 1


# ---- Geometry ------------------------------------------------------------

## The floor of plot `cell`, in world x / z.
func floor_rect(cell: Vector2i) -> Rect2:
	var center := PLOT_CENTER + Vector2(cell.x * PLOT_SIZE.x, cell.y * PLOT_SIZE.y)
	return Rect2(center - PLOT_SIZE / 2.0, PLOT_SIZE)


## Where you may build in plot `cell`: its floor, pulled in from outside walls only.
func inner_rect(cell: Vector2i) -> Rect2:
	var r := floor_rect(cell)
	var lo := r.position
	var hi := r.end
	if not cells.has(cell + SIDES["west"]):
		lo.x += BUILD_MARGIN
	if not cells.has(cell + SIDES["east"]):
		hi.x -= BUILD_MARGIN
	if not cells.has(cell + SIDES["north"]):
		lo.y += BUILD_MARGIN
	if not cells.has(cell + SIDES["south"]):
		hi.y -= BUILD_MARGIN
	return Rect2(lo, hi - lo)


func _inside(p: Vector2) -> bool:
	for c in cells:
		if inner_rect(c).grow(0.001).has_point(p):
			return true
	return false


## True if a floor area (x / z) is entirely on the restaurant floor (crossing from one plot
## into the next is fine).
func contains_rect(r: Rect2) -> bool:
	var mid := r.get_center()
	var points: Array[Vector2] = [
		r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end,
		Vector2(mid.x, r.position.y), Vector2(mid.x, r.end.y),
		Vector2(r.position.x, mid.y), Vector2(r.end.x, mid.y), mid]
	for p in points:
		if not _inside(p):
			return false
	return true


## The overall floor area (x / z) of the whole restaurant.
func bounds() -> Rect2:
	var r := floor_rect(cells[0])
	for c in cells:
		r = r.merge(floor_rect(c))
	return r


## The plot whose south wall has the front door: the front-most plot in the middle column.
func door_cell() -> Vector2i:
	var best := Vector2i(0, 0)
	for c in cells:
		if c.x == 0 and c.y > best.y:
			best = c
	return best


## The middle of the front doorway, on the floor (world x / z of the wall's middle).
func door_position() -> Vector3:
	var r := floor_rect(door_cell())
	return Vector3(r.get_center().x, 0.0, r.end.y + WALL_THICKNESS / 2.0)


# ---- Building a plot -----------------------------------------------------

func _add_cell(cell: Vector2i) -> void:
	cells.append(cell)
	var rect := floor_rect(cell)

	var body := StaticBody3D.new()
	body.name = "Floor_%d_%d" % [cell.x, cell.y]
	add_child(body)
	body.global_position = Vector3(rect.get_center().x, -0.1, rect.get_center().y)
	_add_box(body, Vector3(PLOT_SIZE.x, 0.2, PLOT_SIZE.y), floor_color)
	_nodes.append(body)

	for side in SIDES:
		var neighbor: Vector2i = cell + SIDES[side]
		if cells.has(neighbor):
			_remove_wall(neighbor, OPPOSITE[side]) # the rooms join: open the shared wall
		else:
			_build_wall(cell, side)


func _build_wall(cell: Vector2i, side: String) -> void:
	var rect := floor_rect(cell)
	var c := rect.get_center()
	var half := WALL_THICKNESS / 2.0
	var size := Vector3.ZERO
	var pos := Vector3.ZERO
	match side:
		"east":
			size = Vector3(WALL_THICKNESS, WALL_HEIGHT, PLOT_SIZE.y)
			pos = Vector3(rect.end.x + half, WALL_HEIGHT / 2.0, c.y)
		"west":
			size = Vector3(WALL_THICKNESS, WALL_HEIGHT, PLOT_SIZE.y)
			pos = Vector3(rect.position.x - half, WALL_HEIGHT / 2.0, c.y)
		"south":
			size = Vector3(PLOT_SIZE.x + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS)
			pos = Vector3(c.x, WALL_HEIGHT / 2.0, rect.end.y + half)
		"north":
			size = Vector3(PLOT_SIZE.x + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS)
			pos = Vector3(c.x, WALL_HEIGHT / 2.0, rect.position.y - half)
	var body := StaticBody3D.new()
	body.name = "Wall_%d_%d_%s" % [cell.x, cell.y, side]
	add_child(body)
	body.global_position = pos
	if side == "north":
		_add_box(body, size, wall_color) # the kitchen side: a plain wall
	else:
		_add_wall_with_openings(body, size, side, side == "south" and cell.x == 0)
	_walls["%d,%d,%s" % [cell.x, cell.y, side]] = body
	_nodes.append(body)


## Takes away the wall on `side` of `cell` (one we built, or the starting room's own wall).
func _remove_wall(cell: Vector2i, side: String) -> void:
	var key := "%d,%d,%s" % [cell.x, cell.y, side]
	var wall: Node = _walls.get(key)
	if wall == null and cell == Vector2i(0, 0):
		wall = _scene_walls.get(side)
		_scene_walls.erase(side)
	_walls.erase(key)
	if wall != null and is_instance_valid(wall):
		wall.get_parent().remove_child(wall)
		wall.queue_free()


func _add_box(body: StaticBody3D, size: Vector3, color: Color, offset: Vector3 = Vector3.ZERO, transparent: bool = false) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	body.add_child(shape)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.1
		mat.metallic_specular = 0.9
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	body.add_child(mi)


## A wall made of pieces around its openings: windows spaced along it (glass, no way through)
## and, if `door`, a doorway in the middle that you and the customers can walk through.
func _add_wall_with_openings(body: StaticBody3D, size: Vector3, side: String, door: bool) -> void:
	var along_x := side == "south" or side == "north"
	var length := size.x if along_x else size.z
	var thick := size.z if along_x else size.x
	# Openings along the wall: [centre, width, bottom, top, is_door]
	var openings: Array = []
	if door:
		openings.append([0.0, DOOR_WIDTH, 0.0, DOOR_HEIGHT, true])
		for x in [-length * 0.3, length * 0.3]:
			openings.append([x, WINDOW_WIDTH, WINDOW_BOTTOM, WINDOW_TOP, false])
	else:
		for x in [-length * 0.25, length * 0.25]:
			openings.append([x, WINDOW_WIDTH, WINDOW_BOTTOM, WINDOW_TOP, false])
	openings.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var h := size.y
	var cursor := -length / 2.0
	for o in openings:
		var left: float = o[0] - o[1] / 2.0
		var right: float = o[0] + o[1] / 2.0
		_wall_piece(body, along_x, cursor, left, 0.0, h, thick) # solid wall up to the opening
		_wall_piece(body, along_x, left, right, o[3], h, thick) # above it
		if o[2] > 0.0:
			_wall_piece(body, along_x, left, right, 0.0, o[2], thick) # below a window
			_glass(body, along_x, left, right, o[2], o[3], thick)
		_frame(body, along_x, left, right, o[2], o[3], thick, bool(o[4]))
		cursor = right
	_wall_piece(body, along_x, cursor, length / 2.0, 0.0, h, thick)


## One solid box of wall from `a` to `b` along the wall, `y0`..`y1` high (body-local, centred).
func _wall_piece(body: StaticBody3D, along_x: bool, a: float, b: float, y0: float, y1: float, thick: float) -> void:
	if b - a < 0.01 or y1 - y0 < 0.01:
		return
	var mid := (a + b) / 2.0
	var size := Vector3(b - a, y1 - y0, thick) if along_x else Vector3(thick, y1 - y0, b - a)
	var offset := Vector3(mid, (y0 + y1) / 2.0 - WALL_HEIGHT / 2.0, 0) if along_x \
		else Vector3(0, (y0 + y1) / 2.0 - WALL_HEIGHT / 2.0, mid)
	_add_box(body, size, wall_color, offset)


## A see-through pane in a window (it still blocks walking).
func _glass(body: StaticBody3D, along_x: bool, a: float, b: float, y0: float, y1: float, thick: float) -> void:
	var mid := (a + b) / 2.0
	var size := Vector3(b - a, y1 - y0, 0.04) if along_x else Vector3(0.04, y1 - y0, b - a)
	var offset := Vector3(mid, (y0 + y1) / 2.0 - WALL_HEIGHT / 2.0, 0) if along_x \
		else Vector3(0, (y0 + y1) / 2.0 - WALL_HEIGHT / 2.0, mid)
	_add_box(body, Vector3(size.x, size.y, maxf(size.z, thick)) if along_x else Vector3(maxf(size.x, thick), size.y, size.z),
		glass_color, offset, true)


## A wooden frame around a window or the doorway (thin boxes, no collision).
func _frame(body: StaticBody3D, along_x: bool, a: float, b: float, y0: float, y1: float, thick: float, is_door: bool) -> void:
	var t := 0.12
	var depth := thick + 0.08
	var pieces: Array = [
		[a - t / 2.0, a + t / 2.0, y0, y1 + t], [b - t / 2.0, b + t / 2.0, y0, y1 + t], # sides
		[a - t / 2.0, b + t / 2.0, y1, y1 + t]] # top
	if not is_door:
		pieces.append([a - t / 2.0, b + t / 2.0, y0 - t, y0]) # sill
	for p in pieces:
		var mid: float = (p[0] + p[1]) / 2.0
		var w: float = p[1] - p[0]
		var hh: float = p[3] - p[2]
		var size := Vector3(w, hh, depth) if along_x else Vector3(depth, hh, w)
		var y: float = (p[2] + p[3]) / 2.0 - WALL_HEIGHT / 2.0
		var offset := Vector3(mid, y, 0) if along_x else Vector3(0, y, mid)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = frame_color
		mesh.material = mat
		mi.mesh = mesh
		mi.position = offset
		body.add_child(mi)


## True if there is a wall on this side of the starting plot (used by tests).
func has_scene_wall(side: String) -> bool:
	var wall: Node = _scene_walls.get(side)
	return wall != null and is_instance_valid(wall) and wall.is_inside_tree()
