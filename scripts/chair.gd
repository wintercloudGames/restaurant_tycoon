class_name Chair
extends Node3D
## One chair, sitting in a chair spot (slot) of a Table, or a see-through ghost while you place
## one in build mode. Tables get their chairs one at a time in build mode, up to as many as the
## table seats. The chair model is the ChairModel slot in table.tscn.

var table: Table
var slot: int = -1 # which chair spot of the table this is
var model: ModelSlot
var _pick_body: StaticBody3D


func setup(path: String, scene: PackedScene, fit: Vector3, color: Color) -> void:
	model = ModelSlot.new()
	model.model_path = path
	model.model_scene = scene
	model.fit_size = fit
	model.fallback_color = color
	add_child(model)

	# A shape on layer 2 only: build mode can point at the chair, but nobody bumps into it.
	_pick_body = StaticBody3D.new()
	_pick_body.collision_layer = 2
	_pick_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = fit
	shape.shape = box
	shape.position = Vector3(0, fit.y / 2.0, 0)
	_pick_body.add_child(shape)
	add_child(_pick_body)


func set_pickable(on: bool) -> void:
	_pick_body.collision_layer = 2 if on else 0
