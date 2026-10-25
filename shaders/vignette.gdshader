shader_type canvas_item;

// 0 is invisible, 1 is the full vignette. The script fades this.
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.85);
// Where the darkening starts, from the centre. Lower closes it in.
uniform float radius : hint_range(0.0, 1.0) = 0.35;
// How wide the fade from clear to dark is.
uniform float softness : hint_range(0.01, 1.0) = 0.45;

void fragment() {
	float d = length(UV - vec2(0.5));
	float edge = smoothstep(radius, radius + softness, d);
	COLOR = vec4(tint.rgb, tint.a * edge * strength);
}