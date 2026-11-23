class_name Outside
extends Node3D
## Everything outside the restaurant, built in code from the Kenney city / nature / car kits:
## grass all around, a sidewalk and a two-lane street along the front (south) side with a
## crosswalk at the door, shops across the street (with trees, parked cars and gardens between
## them) and a few houses further back, street
## lamps and trees, planters and a bench by the door, a sign and awning over the door, cars
## driving by, and trees / bushes / flowers on the other three sides.
##
## main.gd calls rebuild() at the start and after every expansion, so the street always runs
## along the current front of the restaurant. Invisible walls keep you on your side of the street.
## Model paths and sizes are the constants below; swap a file name to change a piece.

const ROADS := "res://assets/city-kit-roads/"
const SHOPS := "res://assets/city-kit-commercial/"
const TOWN := "res://assets/city-kit-suburban/"
const CARS := "res://assets/car-kit/"
const NATURE := "res://assets/nature-kit/"
const FURNITURE := "res://assets/furniture-kit/"

const SIDEWALK_DEPTH := 5.0
const ROAD_WIDTH := 9.0 # one road tile, scaled to this size, has both lanes
const FAR_SIDEWALK := 4.0
const STREET_REACH := 45.0 # how far the street runs past the restaurant on each side
const NATURE_REACH := 26.0 # how far the trees go out on the other sides
const CAR_SPEED := 9.0

const SHOP_MODELS: Array[String] = ["building-a", "building-b", "building-c", "building-d", "building-e",
	"building-f", "building-g", "building-h", "building-i", "building-j", "building-k", "building-l", "building-m", "building-n"]
const CAR_MODELS: Array[String] = ["sedan", "taxi", "van", "suv", "hatchback-sports", "sedan-sports", "delivery", "police", "truck"]
# Full paths: green trees from the town kit, autumn trees from the nature kit.
const TREE_MODELS: Array[String] = [TOWN + "tree-large.obj", TOWN + "tree-small.obj", TOWN + "tree-large.obj",
	NATURE + "tree_default_fall.obj", NATURE + "tree_oak_fall.obj", NATURE + "tree_detailed_fall.obj"]
const BUSH_MODELS: Array[String] = ["plant_bushLarge", "plant_bush", "plant_bushDetailed", "plant_bushSmall"]
const FLOWER_MODELS: Array[String] = ["flower_redA", "flower_yellowA", "flower_purpleA", "flower_redB", "flower_yellowB"]

var _built: Node3D # everything from the last rebuild (cleared on the next one)
var _cars: Array[Dictionary] = [] # {node, dir}
var _car_timer: float = 1.0
var _lanes: Array[float] = [] # z of the two driving lanes
var _street_x: Vector2 = Vector2(-60, 60) # where cars appear / disappear
var _mesh_cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()


## Builds (or rebuilds) the outside around the restaurant floor `bounds` (x / z), with the
## front door's middle at `door` (on the outer face of the front wall).
func rebuild(bounds: Rect2, door: Vector3) -> void:
	if _built != null:
		_built.queue_free()
	for car in _cars:
		(car["node"] as Node3D).queue_free()
	_cars.clear()
	_built = Node3D.new()
	_built.name = "Built"
	add_child(_built)
	_rng.seed = 12345 # the same layout every time

	var front := bounds.end.y + 0.5 # outer face of the front wall
	var curb := front + SIDEWALK_DEPTH
	var road_mid := curb + ROAD_WIDTH / 2.0
	var far_curb := curb + ROAD_WIDTH
	var x0 := bounds.position.x - STREET_REACH
	var x1 := bounds.end.x + STREET_REACH
	_street_x = Vector2(x0, x1)
	_lanes = [road_mid - ROAD_WIDTH * 0.22, road_mid + ROAD_WIDTH * 0.22]

	_ground(bounds, front)
	_sidewalk(x0, x1, front, curb)
	_sidewalk(x0, x1, far_curb, far_curb + FAR_SIDEWALK)
	_road(x0, x1, road_mid, door.x)
	_street_props(x0, x1, front, curb, far_curb, door.x)
	_shops(x0, x1, far_curb + FAR_SIDEWALK)
	_door_dressing(door, front)
	_nature(bounds, front)
	_boundary(bounds, curb)


# ---- Pieces --------------------------------------------------------------

func _mesh(path: String) -> Mesh:
	if not _mesh_cache.has(path):
		var res = load(path) if ResourceLoader.exists(path) else null
		_mesh_cache[path] = res if res is Mesh else null
	return _mesh_cache[path]


## Places a kit model: scaled so its HEIGHT (or `fit_width` if given) matches, rotated by `rot`.
func _place(path: String, pos: Vector3, rot: float, height: float, parent: Node3D = null, fit_width: float = 0.0) -> MeshInstance3D:
	var mesh := _mesh(path)
	if mesh == null:
		return null
	var size := mesh.get_aabb().size
	var s := height / maxf(size.y, 0.001)
	if fit_width > 0.0:
		s = fit_width / maxf(size.x, 0.001)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3.ONE * s
	mi.rotation.y = rot
	mi.position = pos
	(parent if parent != null else _built).add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, color: Color, solid: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	_built.add_child(mi)
	if solid:
		_collider(size, pos)


func _collider(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	_built.add_child(body)


## Grass everywhere (with a floor you can walk on), stopping at the sidewalk.
func _ground(bounds: Rect2, front: float) -> void:
	var r := bounds.grow(NATURE_REACH + STREET_REACH)
	var size := Vector3(r.size.x, 0.2, r.size.y + 60.0)
	var pos := Vector3(r.get_center().x, -0.12, r.get_center().y + 30.0)
	_box(size, pos, Color(0.42, 0.62, 0.32), true)


func _sidewalk(x0: float, x1: float, z0: float, z1: float) -> void:
	_box(Vector3(x1 - x0, 0.1, z1 - z0), Vector3((x0 + x1) / 2.0, -0.04, (z0 + z1) / 2.0), Color(0.74, 0.73, 0.7), true)
	# A darker curb along the road side.
	_box(Vector3(x1 - x0, 0.14, 0.3), Vector3((x0 + x1) / 2.0, -0.02, z1 - 0.15), Color(0.55, 0.55, 0.55))


## Road tiles along x, lined up so one tile (the crosswalk) sits right in front of the door.
func _road(x0: float, x1: float, mid_z: float, door_x: float) -> void:
	var first := door_x - ceilf((door_x - x0) / ROAD_WIDTH) * ROAD_WIDTH
	var x := first
	while x <= x1:
		var crossing := absf(x - door_x) < 0.1
		var tile := _place(ROADS + ("road-crossing.obj" if crossing else "road-straight.obj"),
			Vector3(x, -0.07, mid_z), 0.0, 0.0, null, ROAD_WIDTH) # the tiles run along x as they are
		if tile != null:
			tile.scale = Vector3(ROAD_WIDTH, ROAD_WIDTH, ROAD_WIDTH) # flat tiles: size by width
		x += ROAD_WIDTH


## Street lamps and trees along both curbs, a street sign and a dumpster.
func _street_props(x0: float, x1: float, front: float, curb: float, far_curb: float, door_x: float) -> void:
	var x := x0 + 4.0
	var i := 0
	while x < x1 - 2.0:
		if absf(x - door_x) > 5.0:
			if i % 2 == 0:
				_place(ROADS + "light-curved.obj", Vector3(x, 0.0, curb - 0.5), PI, 4.6)
				_place(ROADS + "light-curved.obj", Vector3(x + 6.0, 0.0, far_curb + 0.5), 0.0, 4.6)
			else:
				_tree(TOWN + "tree-large.obj", Vector3(x, 0.0, curb - 1.0), 5.5)
				_tree(TOWN + "tree-large.obj", Vector3(x + 6.0, 0.0, far_curb + 1.0), 5.5)
		x += 6.0
		i += 1
	_place(ROADS + "road-sign-street.obj", Vector3(door_x + 7.0, 0.0, curb - 0.4), PI, 2.6)
	_place(ROADS + "dumpster.obj", Vector3(door_x - 13.0, 0.0, front + 1.0), PI, 1.3)


## Shops facing the street, and taller buildings further back for a skyline.
func _shops(x0: float, x1: float, z_front: float) -> void:
	# A row of shops facing the street, with room between them: trees, a parked car or a little
	# garden in each gap, so it reads as a friendly street rather than a wall of buildings.
	var x := x0 + _rng.randf_range(0.0, 4.0)
	var i := 0
	while x < x1:
		var model: String = SHOP_MODELS[_rng.randi() % SHOP_MODELS.size()]
		var mesh := _mesh(SHOPS + model + ".obj")
		if mesh == null:
			x += 8.0
			continue
		var s := 6.0 / mesh.get_aabb().size.z # every shop is 6 m deep
		var width := mesh.get_aabb().size.x * s
		# Storefronts face the restaurant (the models' fronts point along -z with no turn).
		_place(SHOPS + model + ".obj", Vector3(x + width / 2.0, 0.0, z_front + 3.4), 0.0, mesh.get_aabb().size.y * s)
		x += width
		var gap := _rng.randf_range(6.0, 10.0)
		var mid := x + gap / 2.0
		match i % 3:
			0: # a big tree with bushes
				_tree(TOWN + "tree-large.obj", Vector3(mid, 0.0, z_front + 3.0), 6.0)
				for k in 3:
					_place(NATURE + BUSH_MODELS[_rng.randi() % BUSH_MODELS.size()] + ".obj",
						Vector3(mid + _rng.randf_range(-2.0, 2.0), 0.0, z_front + _rng.randf_range(1.5, 5.0)), _rng.randf() * TAU, 0.9)
			1: # a parked car, nose to the street
				var car: String = CAR_MODELS[_rng.randi() % CAR_MODELS.size()]
				_place(CARS + car + ".obj", Vector3(mid, 0.0, z_front + 3.2), PI, 0.0, null, 1.9)
			_: # a little garden: two small trees and flowers
				_tree(TOWN + "tree-small.obj", Vector3(mid - 1.6, 0.0, z_front + 3.5), 4.0)
				_tree(TOWN + "tree-small.obj", Vector3(mid + 1.6, 0.0, z_front + 3.5), 4.0)
				for k in 5:
					_place(NATURE + FLOWER_MODELS[_rng.randi() % FLOWER_MODELS.size()] + ".obj",
						Vector3(mid + _rng.randf_range(-1.2, 1.2), 0.0, z_front + _rng.randf_range(1.0, 2.2)), _rng.randf() * TAU, 0.45)
		x += gap
		i += 1
	# Further back: a few small houses with their own trees, well spread out (no skyline).
	x = x0 + _rng.randf_range(0.0, 6.0)
	while x < x1:
		var house := "building-type-%s" % "abcdefghijklmnopqrstu"[_rng.randi() % 21]
		var z := z_front + _rng.randf_range(20.0, 26.0)
		_place(TOWN + house + ".obj", Vector3(x, 0.0, z), 0.0, _rng.randf_range(5.0, 6.5))
		_tree(TOWN + "tree-large.obj", Vector3(x + _rng.randf_range(6.0, 8.0), 0.0, z + _rng.randf_range(-2.0, 2.0)), _rng.randf_range(5.0, 7.0))
		x += _rng.randf_range(18.0, 26.0)


## A sign and an awning over the door, planters under the front windows and a bench.
func _door_dressing(door: Vector3, front: float) -> void:
	var sign := Label3D.new()
	sign.text = "RESTAURANT"
	sign.font_size = 96
	sign.pixel_size = 0.008
	sign.outline_size = 18
	sign.modulate = Color(1.0, 0.85, 0.35)
	sign.outline_modulate = Color(0.25, 0.12, 0.05)
	sign.position = Vector3(door.x, 3.55, front + 0.05)
	_built.add_child(sign)
	# A striped canopy over the door.
	for i in 6:
		var stripe := Color(0.85, 0.2, 0.2) if i % 2 == 0 else Color(0.97, 0.95, 0.9)
		var w := 3.2 / 6.0
		_box(Vector3(w, 0.08, 1.1), Vector3(door.x - 1.6 + w * (i + 0.5), 3.08, front + 0.55), stripe)
	_box(Vector3(3.3, 0.22, 0.06), Vector3(door.x, 2.98, front + 1.1), Color(0.85, 0.2, 0.2))
	for side in [-1.0, 1.0]:
		var x: float = door.x + side * 1.9
		_place(TOWN + "planter.obj", Vector3(x, 0.0, front + 0.5), 0.0, 0.0, null, 0.9)
		_place(NATURE + "plant_bushDetailed.obj", Vector3(x, 0.3, front + 0.5), 0.0, 0.0, null, 0.7)
		for k in 3:
			var wx: float = door.x + side * (4.0 + k * 1.2)
			_place(NATURE + FLOWER_MODELS[(k + int(side > 0)) % FLOWER_MODELS.size()] + ".obj",
				Vector3(wx, 0.0, front + 0.35), _rng.randf() * TAU, 0.45)
	# A bench on each side of the door, looking out at the street.
	var scene := AssetLoader.load_scene(FURNITURE + "benchCushion.glb")
	if scene != null:
		for side in [-1.0, 1.0]:
			var b := AssetLoader.from_scene(scene, Vector3(1.6, 0.8, 0.6), Color.BROWN)
			b.position = Vector3(door.x + side * 6.5, 0.0, front + 1.3)
			b.rotation.y = PI
			_built.add_child(b)


func _tree(path: String, pos: Vector3, height: float) -> void:
	if _place(path, pos, _rng.randf() * TAU, height) != null:
		_collider(Vector3(0.5, 2.0, 0.5), pos + Vector3(0, 1.0, 0))


## Trees, bushes and flowers on the restaurant's sides and back (not on the street side).
func _nature(bounds: Rect2, front: float) -> void:
	var outer := bounds.grow(NATURE_REACH)
	var keep_out := bounds.grow(2.5)
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < 70 and tries < 2000:
		tries += 1
		var p := Vector2(_rng.randf_range(outer.position.x, outer.end.x), _rng.randf_range(outer.position.y, front - 1.0))
		if keep_out.has_point(p):
			continue
		var crowded := false
		for q in placed:
			if q.distance_to(p) < 3.2:
				crowded = true
				break
		if crowded:
			continue
		placed.append(p)
		var tree: String = TREE_MODELS[_rng.randi() % TREE_MODELS.size()]
		_tree(tree, Vector3(p.x, 0.0, p.y), _rng.randf_range(4.5, 8.0))
	# Bushes and flowers close to the walls.
	var ring := bounds.grow(1.4)
	for i in 40:
		var t := _rng.randf()
		var p: Vector2
		match i % 3:
			0: p = Vector2(ring.position.x, lerpf(ring.position.y, front - 1.0, t))
			1: p = Vector2(ring.end.x, lerpf(ring.position.y, front - 1.0, t))
			_: p = Vector2(lerpf(ring.position.x, ring.end.x, t), ring.position.y)
		var pos := Vector3(p.x + _rng.randf_range(-0.6, 0.6), 0.0, p.y + _rng.randf_range(-0.6, 0.6))
		if i % 4 == 0:
			_place(NATURE + FLOWER_MODELS[_rng.randi() % FLOWER_MODELS.size()] + ".obj", pos, _rng.randf() * TAU, 0.5)
		else:
			_place(NATURE + BUSH_MODELS[_rng.randi() % BUSH_MODELS.size()] + ".obj", pos, _rng.randf() * TAU, _rng.randf_range(0.7, 1.2))


## Invisible walls: you can walk around the restaurant and along the sidewalk, but not into
## the street or off the edge of the world.
func _boundary(bounds: Rect2, curb: float) -> void:
	var r := Rect2(bounds.position - Vector2(NATURE_REACH - 2.0, NATURE_REACH - 2.0),
		Vector2(bounds.size.x + 2.0 * (NATURE_REACH - 2.0), curb - 0.4 - (bounds.position.y - NATURE_REACH + 2.0)))
	var h := 6.0
	_collider(Vector3(r.size.x, h, 0.5), Vector3(r.get_center().x, h / 2.0, r.position.y))
	_collider(Vector3(r.size.x, h, 0.5), Vector3(r.get_center().x, h / 2.0, r.end.y))
	_collider(Vector3(0.5, h, r.size.y), Vector3(r.position.x, h / 2.0, r.get_center().y))
	_collider(Vector3(0.5, h, r.size.y), Vector3(r.end.x, h / 2.0, r.get_center().y))


# ---- Traffic -------------------------------------------------------------

func _process(delta: float) -> void:
	if _lanes.is_empty():
		return
	_car_timer -= delta
	if _car_timer <= 0.0:
		_car_timer = _rng.randf_range(2.5, 7.0)
		_spawn_car()
	for i in range(_cars.size() - 1, -1, -1):
		var car: Dictionary = _cars[i]
		var node := car["node"] as Node3D
		node.position.x += float(car["dir"]) * float(car["speed"]) * delta
		if node.position.x < _street_x.x - 5.0 or node.position.x > _street_x.y + 5.0:
			node.queue_free()
			_cars.remove_at(i)


func _spawn_car() -> void:
	var lane := _rng.randi() % 2
	var dir := 1.0 if lane == 0 else -1.0
	var model: String = CAR_MODELS[_rng.randi() % CAR_MODELS.size()]
	var mesh := _mesh(CARS + model + ".obj")
	if mesh == null:
		return
	var holder := Node3D.new()
	add_child(holder)
	holder.position = Vector3(_street_x.x - 4.0 if dir > 0.0 else _street_x.y + 4.0, 0.0, _lanes[lane])
	# The car models point along +z; turn them to drive along x.
	_place(CARS + model + ".obj", Vector3.ZERO, PI / 2.0 if dir > 0.0 else -PI / 2.0, 0.0, holder, 1.9)
	_cars.append({"node": holder, "dir": dir, "speed": CAR_SPEED * _rng.randf_range(0.8, 1.2)})
