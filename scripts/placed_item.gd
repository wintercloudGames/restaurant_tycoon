class_name PlacedItem
extends Node3D
## One piece of decor, or a stove / counter, placed in build mode (see placed_item.tscn).
## The model and size come from its entry in build_catalog.gd. Entries with a "scene" (stoves,
## counters) are built from that scene, burners and all.

var item_id: String = ""
var def: Dictionary = {}
var ghost: bool = false # true while being placed/moved: no collision, burners unusable

var _station: Node3D
var _station_layers: Dictionary = {} # CollisionObject3D -> its original collision_layer


func setup(item_def: Dictionary) -> void:
	def = item_def
	item_id = str(def["id"])
	var fit: Vector3 = def["fit"]

	var slot := get_node("Model") as ModelSlot
	if def.has("scene"):
		# A station: swap the plain model for the station's own scene.
		remove_child(slot)
		slot.queue_free()
		_station = (load(str(def["scene"])) as PackedScene).instantiate() as Node3D
		add_child(_station)
		for node in _station.find_children("*", "CollisionObject3D", true, false):
			_station_layers[node] = (node as CollisionObject3D).collision_layer
	else:
		slot.fit_size = fit
		slot.fallback_color = def["color"]
		slot.model_path = BuildCatalog.model_path_for(def)

	var shape := get_node("Body/CollisionShape3D") as CollisionShape3D
	var box := BoxShape3D.new()
	box.size = Vector3(fit.x, maxf(fit.y, 0.12), fit.z) # thin rugs still get a clickable shape
	shape.shape = box
	shape.position = Vector3(0, box.size.y / 2.0, 0)
	_apply_layers()


## Layer 1 blocks the player, layer 2 is only used to pick things in build mode.
func _apply_layers() -> void:
	var body := get_node("Body") as StaticBody3D
	body.collision_layer = 0 if ghost else (3 if def.get("blocks", true) else 2)
	for node in _station_layers:
		if is_instance_valid(node):
			(node as CollisionObject3D).collision_layer = 0 if ghost else int(_station_layers[node])


func set_ghost(on: bool) -> void:
	ghost = on
	_apply_layers()


func footprint_local() -> Rect2:
	var fit: Vector3 = def["fit"]
	return Rect2(-fit.x / 2.0, -fit.z / 2.0, fit.x, fit.z)


## A stove / counter with food on it can't be moved or sold.
func is_busy() -> bool:
	if _station == null:
		return false
	for node in _station.find_children("*", "", true, false):
		if node is Burner and (node as Burner).state != Burner.State.EMPTY:
			return true
	return false


func sell_value() -> int:
	return int(int(def["cost"]) * 0.5)
