class_name FoodIcons
extends RefCounted
## A small picture of each dish (the 3D model rendered once into a texture), used in the
## customers' speech bubbles. Each dish is rendered the first time it's needed and then reused.

const SIZE := Vector2i(128, 128)

static var _icons: Dictionary = {} # dish id -> SubViewport (its texture is the picture)
static var _holder: Node


static func texture_for(dish_id: String) -> Texture2D:
	if _icons.has(dish_id) and is_instance_valid(_icons[dish_id]):
		return (_icons[dish_id] as SubViewport).get_texture()
	var viewport := _make_viewport(dish_id)
	_icons[dish_id] = viewport
	_get_holder().add_child(viewport)
	return viewport.get_texture()


## The viewports need to live somewhere in the scene tree to render; one holder under the
## root does for all of them (and survives scene changes).
static func _get_holder() -> Node:
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node.new()
		_holder.name = "FoodIconHolder"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_holder)
	return _holder


static func _make_viewport(dish_id: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.85
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	viewport.add_child(light)

	var model := AssetLoader.model(Food.model_path_for(dish_id), Vector3.ONE, Color(1.0, 0.7, 0.2))
	model.rotation.y = 0.55
	viewport.add_child(model)

	var camera := Camera3D.new()
	camera.fov = 30.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(1.25, 1.0, 1.5), Vector3(0, 0.36, 0)) # close, so the food fills the picture
	camera.current = true
	return viewport
