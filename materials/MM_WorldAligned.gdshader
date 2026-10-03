// MM_WorldAligned.gdshader
// Master material. World-aligned triplanar. One shader, many MI_ instances.
// Every map is optional, so an instance pays only for what it switches on.

shader_type spatial; // Declare what rendering pipeline this shader goes into
// Five types
// 1. Spatial 3D  2. Canvas_item 2D/UI  3. Particles  4. Sky  5. Fog
// The type decides which built-ins exist. ALBEDO only exists in spatial.

render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx; //specular_schlick_ggx;
// Sets flags on the pipeline surrounding the shader
// Blend_mix   - solid surfaces replace what is behind them
// Blend_add   - colours sum, for fire and glows
// Cull_back   - throws away triangles facing away from camera. Halves the work
//               on a closed box. Use cull_disabled for single-sided planes.
// Diffuse_burley  - realistic, darkens at grazing angles
// Diffuse_lambert - cheaper, ignores that
// Diffuse_toon    - cel banding. CHOSEN, matches the Goose Game direction
// Specular_schlick_ggx - the highlight formula. specular_toon to match the above
// Specular_toon - the highlight becomes a hard-edged blob instead of a smooth

/*
Uniform: a value from outside the shader, identical for every pixel in the draw.
This is what lets one shader serve many materials. The GPU runs the same code for
the marble and the veneer, only the uniform values differ.

Sampler2D: a handle the GPU uses to look up pixels in a texture. You never get
the pixels as data, you only ask "what colour is at this coordinate".

Hints after the colon are promises made at declaration time, because the sampler
hardware must be configured before any code runs:
  source_color       - file is sRGB, decode to linear. COLOUR ONLY.
                       Never on roughness/metallic/AO, they are data and it
                       corrupts the numbers.
  hint_normal        - tells Godot this is a normal map, not a colour
  hint_default_white - unassigned slot samples pure white, which is the neutral
                       value for a multiply. This is what makes every map optional.
  filter_linear_mipmap - smooth up close, pre-built smaller copies at distance.
                       Without mipmaps a surface shimmers as the camera moves.
  repeat_enable      - coordinates past 1.0 wrap and tile. NOT OPTIONAL here,
                       because world_pos / world_scale produces values like 12.7.

Bool toggles: branching on a uniform is coherent. Every pixel in the draw takes
the same path, so the GPU does not split into divergent lanes. All maps off is
3 texture reads. All on is 15. This is Godot's nearest thing to an Unreal
static switch.
*/

///// GROUP ALBEDO /////
group_uniforms Albedo;
uniform sampler2D albedo_texture : source_color, hint_default_white,
                                   filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// vec4 = R,G,B,Alpha. source_color on a vec4 makes the Inspector draw a colour
// picker and converts the pick to linear. Default white because white x tint
// = tint, so a new instance shows the texture untouched.
// The cheapest art-direction knob you will ever build: one texture plus three
// tints gives oak, walnut and painted timber at zero extra memory.

uniform float albedo_brightness : hint_range(0.0, 2.0) = 1.0;
// Multiplies the sampled colour. 1.0 is the texture untouched.
// Tint can only ever REMOVE colour, because white x anything = that thing and
// every channel of a tint is at most 1.0. This is the knob that adds.
// Range capped at 2.0 deliberately. ALBEDO is reflectance, not light output,
// so real surfaces live under 0.9. Past about 1.3 you are lying to the
// renderer and global illumination will bounce the lie around the room.
// If you need more than that, the room is underlit, not the timber.

///// GROUP ROUGHNESS /////
group_uniforms Roughness;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.5;
// hint_range makes it a slider with hard stops. Values outside 0..1 are
// meaningless to the lighting maths and fail silently, so make them unreachable.
// 0.15 polished stone | 0.3 gloss paint | 0.6 timber | 1.0 chalk
uniform bool use_roughness_map = false;
uniform sampler2D roughness_map : hint_default_white,
                                  filter_linear_mipmap, repeat_enable;
								
// Greyscale. MULTIPLIES roughness_value, so the slider stays a master gain and
// white leaves it untouched. Only worth it when roughness varies across the
// surface: worn floorboards, a wet bench, a scorched pot.

///// GROUP METALLIC /////
group_uniforms Metallic;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
// Not a spectrum, a switch. 0.0 = albedo is the surface colour.
// 1.0 = albedo becomes the REFLECTION TINT and there is no diffuse colour at all.
// Values between are physically meaningless except as a blend across a mask.
// Metal with nothing to reflect renders black. Your WorldEnvironment feeds it.
uniform bool use_metallic_map = false;
uniform sampler2D metallic_map : hint_default_white,
                                 filter_linear_mipmap, repeat_enable;

///// GROUP SPECULAR /////
group_uniforms Specular;
uniform float specular_value : hint_range(0.0, 1.0) = 0.5;
// How much light the surface bounces straight back WITHOUT entering it.
// 0.5 is the physical default and means 4 percent reflectance, which is what
// almost every non-metal actually does. The slider runs 0 to 8 percent.
//
// This is the SIZE of the highlight's energy. roughness_value is its SPREAD.
// Two different questions:
//   specular = "is there a highlight at all"
//   roughness = "is it a dot or a wash"
// Set this to 0.0 and roughness becomes a no-op on a non-metal, because there
// is nothing left to spread.
//
// Deliberately NOT a metallic substitute. At metallic 1.0 the renderer ignores
// this entirely and uses ALBEDO as the reflection tint instead.
//
// 0.2 plaster and raw terracotta | 0.5 timber | 0.8 glazed tile and marble
///// VERTEX: runs per corner. Model space to world space. /////
///// GROUP OCCLUSION /////
group_uniforms Occlusion;
uniform bool use_ao_map = false;
uniform sampler2D ao_map : hint_default_white,
                           filter_linear_mipmap, repeat_enable;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
// AO darkens creases that the lighting cannot work out on its own.
// Pointless on a flat slab, useful on tile grout and carved timber.

///// GROUP NORMAL /////
group_uniforms Normal;
uniform bool use_normal_map = false;
uniform sampler2D normal_map : hint_normal,
                               filter_linear_mipmap, repeat_enable;
// OpenGL convention only. Poly Haven's _nor_gl, NEVER _nor_dx.
// DirectX flips the green channel, so bumps render as dents.
uniform float normal_strength : hint_range(-10.0, 10.0) = 1.0;
// Negative inverts. That is the one-field fix if the detail reads inside out.
// Avoid normal maps on play surfaces: fake shading competes with the player
// reading where the real edges are.

uniform bool normal_reconstruct_z = true;
// Godot's VRAM Compressed import for normal maps is RGTC, which stores RED and
// GREEN only and throws BLUE away. StandardMaterial3D rebuilds it internally.
// A custom shader must do it itself or every normal comes out pointing sideways.
// Check the texture preview: "RGTC RedGreen8" means leave this ON.
// Safe to leave ON for uncompressed RGB maps as well, since the rebuilt Z is
// mathematically the same value the file was storing anyway.
// Turn it OFF only if you are deliberately authoring a non-unit normal map.

uniform bool normal_flip_green = false;
// The OTHER convention problem, and a separate one. OpenGL and DirectX disagree
// on which way green points, so a _nor_dx file renders bumps as dents.
// The right fix is to source the _nor_gl file. This is the fix when you cannot.

///// GROUP PROJECTION /////
group_uniforms Projection;
uniform float world_scale = 100.0;
// World units covered by one tile. Our world is 100 units per fictional metre,
// so 100 tiles once per metre.
// It is a DIVIDE, not a multiply. Bigger number = bigger tile = less repetition.
// You are scaling the coordinate space the texture is read from, and that is
// the inverse of scaling the texture.
// No hint_range because there is no natural maximum. Do not invent one.
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;
// Only affects the band at corners where two planes both have a claim.
// 1.0 wide mushy blend | 4.0 tight, invisible | 16.0 almost a hard seam
// Past 16 the pow() loses precision and flickers at grazing angles.
uniform vec3 world_offset = vec3(0.0);
// The texture is nailed to the world, so where a tile boundary lands is decided
// by the object's position, which is an accident. This shifts the pattern
// without moving the geometry.
// Applied in vertex() BEFORE the divide, so the number means world units. Move
// it after and it would mean tiles, which is a worse number to hand a designer.

uniform float uv_rotation_degrees : hint_range(-360.0, 360.0) = 0.0;
// Rotates the texture within each plane. 90 turns horizontal grain vertical.

uniform vec2 uv_tiling = vec2(1.0, 1.0);
// Stretches the lookup per axis AFTER world_scale has done the uniform part.
// world_scale answers "how big is one tile". This answers "what shape is it".
// A border strip texture is wide and short, so forcing it into the square that
// world_scale alone produces squashes it. Set y to 2 and the pattern is half
// as tall in world units, which un-squashes a 2:1 strip.
// (1, 1) is the neutral value, so every existing material is untouched.

uniform bool world_space = true;
// ON  - the projection is nailed to the WORLD. Rotating or moving the node
//       slides the mesh underneath a stationary texture. Two pieces meeting at
//       a corner share one continuous grain, which is the whole point of the
//       master material. Cost: a face rotated off a world axis sits between two
//       planes, both contribute, and the grain crosses itself.
// OFF - the projection is nailed to the OBJECT. The texture rotates WITH the
//       node, so an off-axis piece is axis-aligned again as far as the maths
//       cares and the crossing disappears. Cost: that piece no longer agrees
//       with its neighbours.


///// VARYINGS /////
varying vec3 proj_pos;
varying vec3 proj_nrm;
varying mat3 proj_to_view;
// Named "proj" not "world" because world_space decides which space these hold.
// Everything downstream is space-agnostic: the blend weights and the three
// plane lookups only care that position and normal agree with each other.
/*
A varying is written by vertex() and read by fragment(), and the rasteriser
INTERPOLATES it across the triangle in hardware, for free.

vertex() runs once per corner. 8 for a box.
fragment() runs once per pixel. ~400,000 for an island filling a fifth of 1080p.

That gap is why all the matrix work happens in vertex(). Transform 8 corners,
get the correct world position for 400,000 pixels at no cost.

We carry our own instead of using the built-ins because VERTEX and NORMAL are
MODEL space (relative to the object's own origin, unchanged when it moves) and
fragment()'s NORMAL is VIEW space (rotates with the camera, so the texture would
swim as you orbit). World-aligned needs world space, so we build it ourselves.
*/

void vertex() {
    if (world_space) {
        proj_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + world_offset;
        proj_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
        proj_to_view = mat3(VIEW_MATRIX);
    } else {
        // No MODEL_MATRIX, so we never leave model space. VERTEX and NORMAL are
        // already model space, which is exactly the space that rotates with the
        // node. Doing nothing IS the fix.
        proj_pos = VERTEX + world_offset;
        proj_nrm = normalize(NORMAL);
        proj_to_view = mat3(VIEW_MATRIX) * MODEL_NORMAL_MATRIX;
    }
}

///// FRAGMENT: runs per pixel. /////
void fragment() {
    vec3 n = normalize(proj_nrm);
    // Re-normalised because interpolating two unit vectors does not give a unit
    // vector. Halfway between (1,0,0) and (0,1,0) is (0.5,0.5,0), length 0.707.
    // The weights below would be wrong before the division.

    // --- Blend weights: the whole trick ------------------------------------
    vec3 w = pow(abs(n), vec3(triplanar_sharpness));
    w /= max(w.x + w.y + w.z, 0.0001);
    // abs() because a face pointing down still uses the Y plane.
    // pow() controls how wide the corner blend is.
    // The divide is NOT optional: without it the three samples sum to something
    // other than 1 and the surface brightens or darkens with its angle.
    // max() guards a divide by zero on a degenerate normal.

    // --- Coordinate space --------------------------------------------------
    vec3 p = proj_pos / max(world_scale, 0.0001);

    // --- The three plane lookups -------------------------------------------
    vec2 uv_x = vec2(p.z * -sign(n.x), -p.y);
    vec2 uv_y = vec2(p.x,               p.z * sign(n.y));
    vec2 uv_z = vec2(p.x *  sign(n.z), -p.y);
    // sign() flips the lookup on back faces. Without it the texture mirrors on
    // opposite sides of an object, which reads as a fold down the middle.
	
	//Job: Rotate all three plane lookups
	if (uv_rotation_degrees != 0.0) {
		float a = radians(uv_rotation_degrees);
		mat2 rot = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
		uv_x = rot * uv_x;
		uv_y = rot * uv_y;
		uv_z = rot * uv_z;
	}
	
	uv_x *= uv_tiling;
	uv_y *= uv_tiling;
	uv_z *= uv_tiling;
	// After the rotation, so the aspect correction is applied in the rotated
	// frame and a rotated strip still reads as a strip.
	
    // --- Albedo, always sampled --------------------------------------------
    vec3 col = texture(albedo_texture, uv_x).rgb * w.x
             + texture(albedo_texture, uv_y).rgb * w.y
             + texture(albedo_texture, uv_z).rgb * w.z;
   ALBEDO = col * albedo_tint.rgb * albedo_brightness;

    // --- Roughness ---------------------------------------------------------
    float rough = roughness_value;
    if (use_roughness_map) {
        float r = texture(roughness_map, uv_x).r * w.x
                + texture(roughness_map, uv_y).r * w.y
                + texture(roughness_map, uv_z).r * w.z;
        rough *= r;   // .r because the map is greyscale, all channels identical
    }
    ROUGHNESS = clamp(rough, 0.0, 1.0);
    // clamp because value x map can exceed 1.0 and out-of-range roughness
    // produces artefacts rather than an error

    // --- Metallic ----------------------------------------------------------
    float metal = metallic_value;
    if (use_metallic_map) {
        float m = texture(metallic_map, uv_x).r * w.x
                + texture(metallic_map, uv_y).r * w.y
                + texture(metallic_map, uv_z).r * w.z;
        metal *= m;
    }
    METALLIC = clamp(metal, 0.0, 1.0);
	// --- Specular ----------------------------------------------------------
    SPECULAR = specular_value;
    // No clamp needed, hint_range already bounds it at declaration.
    // --- Ambient occlusion -------------------------------------------------
    if (use_ao_map) {
        float a = texture(ao_map, uv_x).r * w.x
                + texture(ao_map, uv_y).r * w.y
                + texture(ao_map, uv_z).r * w.z;
        AO = mix(1.0, a, ao_strength);   // strength 0 = no occlusion at all
        AO_LIGHT_AFFECT = 1.0;           // apply to direct light, not just ambient
    }

    // --- Normal ------------------------------------------------------------
    if (use_normal_map) {
        vec3 tx = texture(normal_map, uv_x).xyz * 2.0 - 1.0;
        vec3 ty = texture(normal_map, uv_y).xyz * 2.0 - 1.0;
        vec3 tz = texture(normal_map, uv_z).xyz * 2.0 - 1.0;
        // Sampled as .xyz unconditionally. If the file is RGTC the blue channel
        // reads 0 and unpacks to -1, which is garbage, but the reconstruction
        // below overwrites it entirely so it never reaches the lighting.

        if (normal_flip_green) {
            tx.y = -tx.y;
            ty.y = -ty.y;
            tz.y = -tz.y;
        }
        // Before strength, so the sign is corrected on the raw data.

        tx.xy *= normal_strength;
        ty.xy *= normal_strength;
        tz.xy *= normal_strength;
        // Only x and y scale. z is the "straight out" component and scaling it
        // would change the length rather than the tilt.

        if (normal_reconstruct_z) {
            tx.z = sqrt(max(1.0 - dot(tx.xy, tx.xy), 0.0));
            ty.z = sqrt(max(1.0 - dot(ty.xy, ty.xy), 0.0));
            tz.z = sqrt(max(1.0 - dot(tz.xy, tz.xy), 0.0));
        }
        // z = sqrt(1 - x^2 - y^2), because a tangent normal is a unit vector so
        // two components force the third. Run AFTER strength so the rebuilt Z
        // matches the tilt we actually asked for rather than the one on disk.
        // max() guards strength > 1 pushing xy past unit length, where the root
        // would go imaginary and the pixel would come out NaN.

        // Undo the UV rotation on the sampled slopes too. Rotating the texture
        // alone leaves highlights and reflections pointing the wrong way.
        float a = radians(uv_rotation_degrees);
        mat2 undo_rotation = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
        tx.xy = undo_rotation * (tx.xy * sign(uv_tiling));
        ty.xy = undo_rotation * (ty.xy * sign(uv_tiling));
        tz.xy = undo_rotation * (tz.xy * sign(uv_tiling));

        // Match each projection's signed U/V axes and retain the geometric
        // normal. A flat map must leave rounded edges and bevels unchanged.
        vec3 nx = vec3(n.x * tx.z, n.y - tx.y, n.z - sign(n.x) * tx.x);
        vec3 ny = vec3(n.x + ty.x, n.y * ty.z, n.z + sign(n.y) * ty.y);
        vec3 nz = vec3(n.x + sign(n.z) * tz.x, n.y - tz.y, n.z * tz.z);
        vec3 mapped_normal = normalize(nx * w.x + ny * w.y + nz * w.z);

        // Object-aligned maps need the model normal transform as well as the
        // view transform, including inverse scale for stretched geometry.
        NORMAL = normalize(proj_to_view * mapped_normal);
    }
}
