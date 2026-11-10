// Eclipse clearing foliage: vertex-coloured, opaque (no alpha sorting), cheap
// wind sway weighted by height. Mobile-friendly: no textures, one light.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform float wind_strength = 0.05;
uniform float wind_height = 5.0;
uniform float flutter = 0.25;
uniform float variation = 0.1;
uniform float brightness = 1.0;
uniform vec3 warm_shift : source_color = vec3(1.0, 0.92, 0.62);

// Optional see-through around the player (hero trees only): when reveal_radius
// is > 0, foliage between the gameplay camera and the target is dithered out.
uniform float reveal_radius = 0.0;
uniform vec3 reveal_target = vec3(0.0);
uniform vec3 reveal_camera = vec3(0.0, 20.0, 15.0);

varying float v_hash;
varying vec3 v_world;

// glTF stores vertex colours in linear space, but the renderer linearizes COLOR
// as if it were sRGB. Undo that second conversion (measured: 0.2 -> 0.033).
vec3 vertex_linear(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_hash = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float h = clamp(VERTEX.y / wind_height, 0.0, 1.5);
	float phase = TIME * 1.3 + origin.x * 0.31 + origin.z * 0.23;
	vec3 sway = vec3(sin(phase), 0.0, cos(phase * 0.83)) * h * h;
	sway += vec3(sin(TIME * 3.4 + VERTEX.x * 2.3 + VERTEX.z * 1.9 + v_hash * 6.0)) * flutter * h;
	VERTEX += sway * wind_strength;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int index = i.x + i.y * 4;
	const float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[index] + 0.5) / 16.0;
}

void fragment() {
	if (reveal_radius > 0.0) {
		vec3 ray = reveal_target - reveal_camera;
		float t = clamp(dot(v_world - reveal_camera, ray) / dot(ray, ray), 0.0, 1.0);
		float d = distance(v_world, reveal_camera + ray * t);
		float cut = (1.0 - smoothstep(reveal_radius * 0.55, reveal_radius, d)) * step(t, 0.93);
		if (cut * 0.85 > bayer4(FRAGCOORD.xy)) {
			discard;
		}
	}
	vec3 c = vertex_linear(COLOR.rgb) * brightness;
	// Per-instance hue drift so repeated kits do not read as copies.
	c *= mix(vec3(1.0 - variation), mix(vec3(1.0), warm_shift, variation * 2.5), v_hash);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	BACKLIGHT = c * 0.35;
}
