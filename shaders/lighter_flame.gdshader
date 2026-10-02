shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

uniform vec4 base_color : source_color = vec4(0.08, 0.25, 1.0, 1.0);
uniform vec4 middle_color : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.16, 0.015, 1.0);
uniform float flame_height = 3.0;
uniform float flame_width = 0.75;
uniform float energy = 2.0;
uniform float phase = 0.0;

varying float height;

void vertex() {
	height = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	float pulse = sin(TIME * 9.0 + phase) * 0.045 + sin(TIME * 15.3) * 0.025;
	VERTEX.xz *= flame_width * (1.15 - height * 0.8);
	VERTEX.y = height * flame_height * (1.0 + pulse);
	// The nozzle stays fixed while the upper flame bends and flickers.
	VERTEX.x += sin(TIME * 5.7 + height * 4.0 + phase) * height * height * 0.18;
	VERTEX.z += cos(TIME * 7.1 + height * 3.0 + phase) * height * height * 0.12;
}

void fragment() {
	vec3 color = mix(base_color.rgb, middle_color.rgb, smoothstep(0.05, 0.3, height));
	color = mix(color, tip_color.rgb, smoothstep(0.45, 1.0, height));
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.7);
	ALBEDO = color;
	EMISSION = color * energy;
	ALPHA = edge * smoothstep(0.0, 0.07, height) * (1.0 - smoothstep(0.75, 1.0, height)) * 0.72;
}
