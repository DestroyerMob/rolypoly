shader_type sky;

uniform vec3 zenith : source_color = vec3(0.08, 0.27, 0.50);
uniform vec3 horizon : source_color = vec3(0.75, 0.71, 0.52);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.96, 0.85);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = direction.y;
	vec3 color = mix(horizon, zenith, pow(clamp(elevation, 0.0, 1.0), 0.35));
	vec2 cloud_uv = direction.xz / max(elevation + 0.35, 0.12) * 2.0;
	float cloud = noise(cloud_uv) * 0.6 + noise(cloud_uv * 2.1) * 0.28 + noise(cloud_uv * 4.3) * 0.12;
	float cloud_mask = smoothstep(0.52, 0.78, cloud) * smoothstep(0.01, 0.18, elevation);
	color = mix(color, cloud_color, cloud_mask * 0.65);
	float azimuth = atan(direction.z, direction.x);
	float far_hill = -0.025 + sin(azimuth * 5.0) * 0.018 + sin(azimuth * 11.0) * 0.009;
	float near_hill = -0.10 + sin(azimuth * 7.0 + 0.7) * 0.025;
	color = mix(vec3(0.36, 0.49, 0.38), color, smoothstep(far_hill - 0.018, far_hill + 0.018, elevation));
	color = mix(vec3(0.20, 0.34, 0.22), color, smoothstep(near_hill - 0.015, near_hill + 0.015, elevation));
	vec3 sun_direction = normalize(vec3(-0.84, 0.48, 0.20));
	float sun = max(dot(direction, sun_direction), 0.0);
	color += vec3(1.0, 0.72, 0.36) * pow(sun, 32.0) * 0.22;
	COLOR = color;
}
