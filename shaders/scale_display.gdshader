shader_type spatial;
render_mode unshaded;

uniform vec4 screen_color : source_color = vec4(0.68, 0.72, 0.64, 1.0);

void fragment() {
	// Match the LCD's rounded interior while retaining the textured bezel.
	vec2 panel_size = vec2(1.184, 0.474);
	float corner_radius = 0.035;
	vec2 edge = abs((UV - vec2(0.5)) * panel_size)
		- (panel_size * 0.5 - vec2(corner_radius));
	float distance_to_edge = length(max(edge, vec2(0.0)))
		+ min(max(edge.x, edge.y), 0.0) - corner_radius;
	if (distance_to_edge > 0.0) {
		discard;
	}
	ALBEDO = screen_color.rgb;
}
