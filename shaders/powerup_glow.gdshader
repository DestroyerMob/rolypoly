shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.18, 0.9, 0.8, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.14;
varying float local_height;

void vertex() {
	local_height = VERTEX.y;
}

void fragment() {
	float height = clamp((local_height + 2.2) / 4.4, 0.0, 1.0);
	float vertical_fade = pow(1.0 - height, 2.0) * smoothstep(0.0, 0.08, height);
	// Fade the silhouette so the light reads as a haze rather than a solid tube.
	float edge_fade = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	ALBEDO = glow_color.rgb;
	EMISSION = glow_color.rgb * 1.5;
	ALPHA = strength * vertical_fade * edge_fade;
}
