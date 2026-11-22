class_name AssetLoader
## Loads a model and auto-scales it to fit a target size, so it doesn't matter how big
## or small the original Kenney model is.
##
## `size` is the box the model is scaled (uniformly) to fit inside. The result is
## centered on x/z and sits on y = 0. If there is no model, a colored box of that size
## is returned instead so the game still runs.


static func load_scene(path: String) -> PackedScene:
	if path != "" and ResourceLoader.exists(path):
		var res = load(path)
		if res is PackedScene:
			return res
	return null


static func from_scene(scene: PackedScene, size: Vector3, color: Color, fit: bool = true, height_only: bool = false) -> Node3D:
	if scene != null:
		var inst := scene.instantiate() as Node3D
		if inst != null:
			if fit:
				return _fit(inst, size, height_only)
			return inst
	return fallback_box(size, color)


static func model(path: String, size: Vector3, color: Color) -> Node3D:
	return from_scene(load_scene(path), size, color)


static func fallback_box(size: Vector3, color: Color, cylinder: bool = false) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var mi := MeshInstance3D.new()
	if cylinder:
		var cyl := CylinderMesh.new()
		cyl.top_radius = minf(size.x, size.z) / 2.0
		cyl.bottom_radius = cyl.top_radius
		cyl.height = size.y
		cyl.material = mat
		mi.mesh = cyl
	else:
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = mat
		mi.mesh = mesh
	mi.position.y = size.y / 2.0

	var root := Node3D.new()
	root.add_child(mi)
	return root


static func _fit(inst: Node3D, size: Vector3, height_only: bool = false) -> Node3D:
	var bounds := _combined_aabb(inst)
	var root := Node3D.new()
	root.add_child(inst)
	if bounds.size.x <= 0.0001 or bounds.size.y <= 0.0001 or bounds.size.z <= 0.0001:
		return root # no usable mesh bounds, leave at native size

	var s := size.y / bounds.size.y # height only: stretched-out arms don't shrink the character
	if not height_only:
		s = minf(size.x / bounds.size.x, minf(s, size.z / bounds.size.z))
	var center := bounds.position + bounds.size / 2.0
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(-center.x * s, -bounds.position.y * s, -center.z * s)
	return root


## Bounding box of every MeshInstance3D under `root`, in root's local space.
static func _combined_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var box := xf * mi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result
