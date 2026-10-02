shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;

uniform sampler2D ice_color : source_color;
uniform sampler2D ice_opacity;
uniform sampler2D ice_normal : hint_normal;
uniform float melt_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = texture(ice_color, UV).rgb;
	ALPHA = mix(0.18, 0.55, texture(ice_opacity, UV).r) * (1.0 - smoothstep(0.85, 1.0, melt_progress));
	NORMAL_MAP = texture(ice_normal, UV).rgb;
	ROUGHNESS = 0.15;
	SPECULAR = 0.7;
}
