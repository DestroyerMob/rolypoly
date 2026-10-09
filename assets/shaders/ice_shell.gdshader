shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 ice_color : source_color = vec4(0.12, 0.48, 0.69, 1.0);
void fragment() {
    float veins = pow(abs(sin(UV.x * 47.0 + sin(UV.y * 24.0) * 3.0)), 28.0);
    float frost = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.4);
    ALBEDO = mix(ice_color.rgb, vec3(0.60, 0.86, 0.95), frost * 0.35 + veins * 0.18);
    ROUGHNESS = 0.17 + veins * 0.2;
    METALLIC = 0.18;
    SPECULAR = 0.45;
    EMISSION = ice_color.rgb * 0.04;
}
