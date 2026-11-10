// Bark, stone and small props: vertex colour, soft wrap lighting, no textures.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

uniform float variation = 0.08;
uniform float brightness = 1.0;

varying float v_hash;

// glTF stores vertex colours in linear space, but the renderer linearizes COLOR
// as if it were sRGB. Undo that second conversion (measured: 0.2 -> 0.033).
vec3 vertex_linear(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_hash = fract(sin(dot(origin.xz, vec2(39.3468, 11.135))) * 24634.6345);
}

void fragment() {
	ALBEDO = vertex_linear(COLOR.rgb) * brightness * (1.0 - variation + 2.0 * variation * v_hash);
	ROUGHNESS = 1.0;
}
