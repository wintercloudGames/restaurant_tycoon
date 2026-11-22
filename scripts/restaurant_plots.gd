class_name RestaurantPlots
extends Node3D
## The restaurant's floor space. You start with one plot (the room in main.tscn). Every
## expansion bolts another plot of the SAME size onto the existing space, in this order:
##   east, west, south, south-east, south-west, ... (never north: that's the kitchen wall).
## New plots get floor and walls on their outer edges; the walls where two plots meet are
## removed so the rooms join into one big space.

const PLOT_SIZE := Vector2(16.0, 20.0) # x, z of one plot (the starting room)
const PLOT_CENTER := Vector2(0.0, 2.0) # where the starting plot is (x, z)
const WALL_HEIGHT := 4.0
const WALL_THICKNESS := 0.5
const BUILD_MARGIN := 0.4 # keep decor this far from an outside wall

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

var cells: Array[Vector2i] = [Vector2i(0, 0)]

var _scene_walls: Dictionary = {} # side -> wall node of the starting plot (from main.tscn)
var _walls: Dictionary = {} # "gx,gz,side" -> wall node we built
var _nodes: Array[Node] = [] # everything we added (floors, walls)


## Tell the plots about the walls that are already in main.tscn, e.g.
## {"east": WallRight, "west": WallLeft, "south": WallFront, "north": WallBack}.
func adopt_scene_walls(walls: Dictionary) -> void:
	_scene_walls = walls


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
	_add_box(body, size, wall_color)
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


func _add_box(body: StaticBody3D, size: Vector3, color: Color) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)


## True if there is a wall on this side of the starting plot (used by tests).
func has_scene_wall(side: String) -> bool:
	var wall: Node = _scene_walls.get(side)
	return wall != null and is_instance_valid(wall) and wall.is_inside_tree()
