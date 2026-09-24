shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;

uniform sampler2D ice_color : source_color;
uniform sampler2D ice_opacity;
uniform sampler2D ice_normal : hint_normal;

void fragment() {
	ALBEDO = texture(ice_color, UV).rgb;
	ALPHA = mix(0.18, 0.55, texture(ice_opacity, UV).r);
	NORMAL_MAP = texture(ice_normal, UV).rgb;
	ROUGHNESS = 0.15;
	SPECULAR = 0.7;
}
