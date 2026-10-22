// world_grid.gdshader
// World-aligned prototyping grid for Rolypoly.
// 1 metre major cells, optional subdivisions, triplanar so it wraps
// any geometry without UVs and never stretches with object scale.

shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms Grid;
uniform float cell_size = 100.0;            // metres per major cell
uniform float subdivisions = 5.0;        // minor lines per major cell
uniform float major_line_width = 1.0;   // metres
uniform float minor_line_width = 0.25;   // metres
uniform vec3 world_offset = vec3(0.0);    // shift the grid origin

group_uniforms Colors;
uniform vec4 checker_a : source_color = vec4(0.30, 0.31, 0.33, 1.0);
uniform vec4 checker_b : source_color = vec4(0.38, 0.39, 0.42, 1.0);
uniform vec4 major_line_color : source_color = vec4(0.88, 0.89, 0.92, 1.0);
uniform vec4 minor_line_color : source_color = vec4(0.52, 0.53, 0.56, 1.0);
uniform float checker_strength : hint_range(0.0, 1.0) = 1.0;

group_uniforms Origin_Axes;
uniform bool show_axes = true;
uniform vec4 axis_x_color : source_color = vec4(0.85, 0.25, 0.25, 1.0);
uniform vec4 axis_z_color : source_color = vec4(0.25, 0.45, 0.90, 1.0);

group_uniforms Surface;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 8.0;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + world_offset;
    world_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

// Distance in metres to the nearest line of a grid of given cell size.
vec2 dist_to_lines(vec2 p, float cell) {
    return abs(mod(p + 0.5 * cell, cell) - 0.5 * cell);
}

// Screen-space antialiased line mask. 1.0 on the line, 0.0 off it.
float line_mask(vec2 p, float cell, float width, vec2 aa) {
    vec2 d = dist_to_lines(p, cell);
    vec2 m = vec2(1.0) - smoothstep(vec2(width * 0.5) - aa, vec2(width * 0.5) + aa, d);
    return max(m.x, m.y);
}

float checker_mask(vec2 p, float cell) {
    vec2 c = floor(p / cell);
    return mod(c.x + c.y, 2.0);
}

// Fades detail out once a cell is smaller than a pixel, which kills moire.
float detail_fade(float cell, vec2 aa) {
    return clamp(1.0 - max(aa.x, aa.y) / (cell * 0.5), 0.0, 1.0);
}

vec3 grid_plane(vec2 p) {
    vec2 aa = fwidth(p);

    float minor_cell = cell_size / max(subdivisions, 1.0);

    float checker = checker_mask(p, cell_size);
    float chk_fade = detail_fade(cell_size, aa);
    vec3 base = mix(checker_a.rgb, checker_b.rgb, checker * checker_strength * chk_fade);

    float minor = line_mask(p, minor_cell, minor_line_width, aa) * detail_fade(minor_cell, aa);
    float major = line_mask(p, cell_size, major_line_width, aa) * chk_fade;

    vec3 col = mix(base, minor_line_color.rgb, minor);
    col = mix(col, major_line_color.rgb, major);

    if (show_axes) {
        float ax_u = 1.0 - smoothstep(major_line_width * 0.75 - aa.x,
                                      major_line_width * 0.75 + aa.x, abs(p.x));
        float ax_v = 1.0 - smoothstep(major_line_width * 0.75 - aa.y,
                                      major_line_width * 0.75 + aa.y, abs(p.y));
        col = mix(col, axis_z_color.rgb, ax_u * chk_fade);
        col = mix(col, axis_x_color.rgb, ax_v * chk_fade);
    }

    return col;
}

void fragment() {
    vec3 n = normalize(world_nrm);
    vec3 w = pow(abs(n), vec3(triplanar_sharpness));
    w /= max(w.x + w.y + w.z, 0.0001);

    // Each plane samples the two world axes it lies in.
    vec3 col_x = grid_plane(world_pos.zy);
    vec3 col_y = grid_plane(world_pos.xz);
    vec3 col_z = grid_plane(world_pos.xy);

    ALBEDO = col_x * w.x + col_y * w.y + col_z * w.z;
    ROUGHNESS = roughness_value;
    METALLIC = metallic_value;
}