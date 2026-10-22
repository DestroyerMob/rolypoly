shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;

// Same melt parameter and maps as Ethan's shader; blue tint improves readability
// against Iroh's pale countertop without changing any ice physics or timing.
uniform sampler2D ice_color : source_color;
uniform sampler2D ice_opacity;
uniform sampler2D ice_normal : hint_normal;
uniform float melt_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = texture(ice_color, UV).rgb * vec3(0.27, 0.72, 0.89);
	ALPHA = mix(0.38, 0.72, texture(ice_opacity, UV).r) * (1.0 - smoothstep(0.97, 1.0, melt_progress));
	NORMAL_MAP = texture(ice_normal, UV).rgb;
	ROUGHNESS = 0.18;
	SPECULAR = 0.7;
}
