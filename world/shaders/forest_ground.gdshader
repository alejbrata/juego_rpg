// Painted ground of the Eclipse clearing. Two texture reads: a 2048 painted map
// placed by world XZ, plus a small tileable stroke texture for close detail.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform vec4 paint_rect = vec4(-24.0, -28.0, 48.0, 40.0);
uniform float detail_scale = 0.42;
uniform float detail_strength = 0.32;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world.xz - paint_rect.xy) / paint_rect.zw;
	vec3 c = texture(paint, uv).rgb;
	float d = texture(detail, world.xz * detail_scale).r;
	float d2 = texture(detail, world.xz * detail_scale * 0.31 + vec2(0.37, 0.71)).r;
	c *= 1.0 + ((d * 0.6 + d2 * 0.4) - 0.5) * 2.0 * detail_strength;
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
