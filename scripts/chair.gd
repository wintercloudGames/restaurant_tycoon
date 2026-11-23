class_name Chair
extends Node3D
## One chair, sitting in a chair spot (slot) of a Table, or a see-through ghost while you place
## one in build mode. Tables get their chairs one at a time in build mode, up to as many as the
## table seats. The chair model is the ChairModel slot in table.tscn.

var table: Table
var slot: int = -1 # which chair spot of the table this is
var comfy: bool = false # the comfy red chair: customers on it wait longer
var _tint: Color = Color.WHITE
var model: ModelSlot
var _pick_body: StaticBody3D


func setup(path: String, scene: PackedScene, fit: Vector3, color: Color, tint: Color = Color.WHITE) -> void:
	_tint = tint
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


func _ready() -> void:
	if _tint != Color.WHITE and model != null and model.instance != null:
		_apply_tint(model.instance)


## Multiplies the model's colors by the tint (the red of the comfy chair).
func _apply_tint(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i) as BaseMaterial3D
			if mat != null:
				mat = mat.duplicate() as BaseMaterial3D
				mat.albedo_color *= _tint
				mi.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_tint(child)


func set_pickable(on: bool) -> void:
	_pick_body.collision_layer = 2 if on else 0
