@tool
class_name ModelSlot
extends Node3D
## A spot where a 3D model appears. Select this node in the editor and, in the Inspector:
##  - drag a .glb file into "Model Path" (or a scene into "Model Scene") to swap the model
##  - change "Fit Size" to make the model bigger or smaller (it is auto-scaled to fit)
##  - "Random Paths" (optional): at runtime one of these is picked at random
## If no model is found, a colored box is shown instead (size = "Fallback Size", or "Fit Size" if that is zero).

@export_file("*.glb", "*.gltf", "*.tscn", "*.scn") var model_path: String = "":
	set(value):
		model_path = value
		_rebuild()
@export var model_scene: PackedScene:
	set(value):
		model_scene = value
		_rebuild()
@export_file("*.glb", "*.gltf", "*.tscn", "*.scn") var random_paths: Array[String] = []
@export var fit_size: Vector3 = Vector3(1, 1, 1):
	set(value):
		fit_size = value
		_rebuild()
@export var fallback_size: Vector3 = Vector3.ZERO:
	set(value):
		fallback_size = value
		_rebuild()
## Scale by height only (good for characters, whose arms can make them look wider than tall).
@export var fit_height_only: bool = false:
	set(value):
		fit_height_only = value
		_rebuild()
@export var auto_fit: bool = true:
	set(value):
		auto_fit = value
		_rebuild()
@export var fallback_color: Color = Color(0.7, 0.7, 0.7):
	set(value):
		fallback_color = value
		_rebuild()
@export var random_fallback_color: bool = false
@export var fallback_cylinder: bool = false # placeholder is a cylinder (pots, pans) instead of a box

var instance: Node3D
var _ready_done: bool = false


func _ready() -> void:
	_ready_done = true
	_rebuild()


func _rebuild() -> void:
	if not _ready_done:
		return
	if instance != null and is_instance_valid(instance):
		remove_child(instance)
		instance.queue_free()
	instance = null

	var color := fallback_color
	if random_fallback_color and not Engine.is_editor_hint():
		color = Color.from_hsv(randf(), 0.5, 0.9)

	var scene := model_scene
	if scene == null:
		var path := model_path
		if not Engine.is_editor_hint() and not random_paths.is_empty():
			path = random_paths.pick_random()
		scene = AssetLoader.load_scene(path)

	if scene != null:
		# Slots with Random Paths are characters, which are always scaled by height.
		var height_only := fit_height_only or not random_paths.is_empty()
		instance = AssetLoader.from_scene(scene, fit_size, color, auto_fit, height_only)
	else:
		instance = AssetLoader.fallback_box(fit_size if fallback_size == Vector3.ZERO else fallback_size, color, fallback_cylinder)
	add_child(instance)
