shader_type spatial;

uniform vec3 light_wood : source_color = vec3(0.72, 0.46, 0.23);
uniform vec3 dark_wood : source_color = vec3(0.38, 0.20, 0.08);

void fragment() {
	vec2 p = UV;
	float warp = sin(p.x * 11.0) * 0.4 + sin(p.x * 29.0 + p.y * 3.0) * 0.12;
	float grain = sin(p.y * 190.0 + warp * 4.0) * 0.5 + 0.5;
	float fine_grain = sin(p.y * 530.0 + warp * 7.0) * 0.5 + 0.5;
	ALBEDO = mix(light_wood, dark_wood, grain * 0.22 + fine_grain * 0.08);
	ROUGHNESS = 0.46 + grain * 0.1;
	SPECULAR = 0.3;
}
