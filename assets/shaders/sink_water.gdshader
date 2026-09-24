shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 shallow_color : source_color = vec4(0.05, 0.55, 0.72, 0.68);
uniform vec4 deep_color : source_color = vec4(0.015, 0.20, 0.38, 0.82);
uniform vec4 highlight_color : source_color = vec4(0.62, 0.94, 1.0, 1.0);
uniform float wave_height : hint_range(0.0, 0.2, 0.005) = 0.045;
uniform float wave_speed : hint_range(0.0, 5.0, 0.05) = 1.15;
uniform float wave_scale : hint_range(1.0, 30.0, 0.5) = 11.0;

float water_wave(vec2 uv, float time) {
	float first = sin(uv.x * wave_scale + time * wave_speed);
	float second = sin(uv.y * wave_scale * 0.78 - time * wave_speed * 1.27);
	float cross_wave = sin((uv.x + uv.y) * wave_scale * 0.48 + time * wave_speed * 0.72);
	return (first + second + cross_wave) / 3.0;
}

void vertex() {
	VERTEX.y += water_wave(UV, TIME) * wave_height;
}

void fragment() {
	float wave = water_wave(UV, TIME);
	float edge = smoothstep(0.31, 0.50, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
	float glint = pow(max(wave * 0.5 + 0.5, 0.0), 7.0);
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, 0.62 + wave * 0.12);
	ALBEDO = mix(base, highlight_color.rgb, glint * 0.32 + edge * 0.16);
	EMISSION = highlight_color.rgb * glint * 0.10;
	ROUGHNESS = 0.12;
	METALLIC = 0.04;
	SPECULAR = 0.9;
	ALPHA = mix(shallow_color.a, deep_color.a, edge * 0.40);
}
