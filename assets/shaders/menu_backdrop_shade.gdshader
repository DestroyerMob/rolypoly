shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float left_shade = (1.0 - smoothstep(0.12, 0.53, UV.x)) * 0.36;
	float edge_shade = smoothstep(0.35, 0.72, length((UV - vec2(0.5)) * vec2(0.9, 1.0))) * 0.18;
	COLOR = vec4(0.045, 0.032, 0.02, max(left_shade, edge_shade));
}
