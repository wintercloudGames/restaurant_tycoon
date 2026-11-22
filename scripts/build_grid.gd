class_name BuildGrid
extends MeshInstance3D
## A faint grid on the floor, drawn only in build mode, so you can see the cells that items snap to.
## Thin lines are every grid step (0.5), brighter lines every 1.0. The grid fades out away from
## the spot you're pointing at.

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float cell = 0.5;
uniform float alpha_minor = 0.22;
uniform float alpha_major = 0.45;
uniform vec3 focus = vec3(0.0);
uniform float radius = 7.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 p, float step_size) {
	vec2 q = p / step_size;
	vec2 g = abs(fract(q - 0.5) - 0.5) / max(fwidth(q), vec2(0.0001));
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	float minor = grid_line(world_pos.xz, cell);
	float major = grid_line(world_pos.xz, cell * 2.0);
	float fade = clamp(1.0 - distance(world_pos.xz, focus.xz) / radius, 0.0, 1.0);
	ALBEDO = vec3(1.0);
	ALPHA = max(minor * alpha_minor, major * alpha_major) * fade;
}
"""

var _material: ShaderMaterial


func _init() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	mesh = plane
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("cell", BuildMode.GRID)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Sizes the grid to cover an area of the floor (x / z).
func fit(area: Rect2) -> void:
	(mesh as PlaneMesh).size = area.size + Vector2(2, 2)
	position = Vector3(area.get_center().x, 0.012, area.get_center().y)


## The grid is brightest around this point.
func set_focus(point: Vector3) -> void:
	_material.set_shader_parameter("focus", point)
