shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.8, 0.76, 0.65, 1.0);
uniform int style = 0;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float grain = sin(world_pos.z * 16.0 + sin(world_pos.x * 0.8) * 5.0 + sin(world_pos.z * 2.0));
    float vein = pow(abs(sin(world_pos.x * 0.65 + world_pos.z * 0.21 + sin(world_pos.z * 0.45))), 30.0);
    float pattern = style == 1 ? grain * 0.045 : -vein * 0.10;
    ALBEDO = base_color.rgb * (1.0 + pattern);
    ROUGHNESS = style == 1 ? 0.48 : 0.3 + vein * 0.1;
}
