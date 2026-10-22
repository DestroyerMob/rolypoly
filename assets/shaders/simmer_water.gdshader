shader_type spatial;
render_mode cull_disabled;

uniform vec4 broth_color : source_color = vec4(0.86, 0.46, 0.13, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 0.86, 0.56, 1.0);
uniform float wave_height = 0.02;
uniform float wave_speed = 1.5;
uniform float bubble_density = 10.0;
uniform float bubble_speed = 0.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

float surface_height(vec2 uv, float t) {
	float h = sin(uv.x * 7.0 + t * wave_speed) * 0.5;
	h += sin(uv.y * 9.0 - t * wave_speed * 1.3) * 0.5;
	h += (value_noise(uv * 6.0 + vec2(t * 0.4, -t * 0.3)) - 0.5) * 1.5;
	return h;
}

void vertex() {
	VERTEX.y += surface_height(UV, TIME) * wave_height;
}

void fragment() {
	float dist = length(UV - vec2(0.5));
	if (dist > 0.5) {
		discard;
	}

	float e = 0.01;
	float h = surface_height(UV, TIME);
	float hx = surface_height(UV + vec2(e, 0.0), TIME);
	float hz = surface_height(UV + vec2(0.0, e), TIME);
	NORMAL_MAP = vec3(0.5 + (h - hx) / e * 0.02, 0.5 + (h - hz) / e * 0.02, 1.0);

	// Popping bubbles: one expanding ring per grid cell, each on its own timer.
	vec2 grid = UV * bubble_density;
	vec2 cell = floor(grid);
	vec2 local = fract(grid) - 0.5;
	float seed = hash(cell);
	float life = fract(TIME * bubble_speed * (0.5 + seed) + seed * 7.0);
	vec2 centre = (vec2(hash(cell + 1.7), hash(cell + 3.1)) - 0.5) * 0.4;
	float ring = smoothstep(0.04, 0.0, abs(length(local - centre) - life * 0.35)) * (1.0 - life);
	ring *= step(0.35, seed);

	float rim_foam = smoothstep(0.42, 0.5, dist) * 0.7;
	float foam = clamp(rim_foam + ring, 0.0, 1.0);

	ALBEDO = mix(broth_color.rgb, foam_color.rgb, foam);
	EMISSION = broth_color.rgb * 0.12;
	ROUGHNESS = mix(0.18, 0.6, foam);
	SPECULAR = 0.7;
}
