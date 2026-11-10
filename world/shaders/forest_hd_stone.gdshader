shader_type spatial;
// HD surfaces for the original ruins / narrative props: triplanar CC0 PBR detail
// that keeps each part's authored vertex colour as tint, plus moss on top faces.

uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scale = 0.6;
uniform float moss_amount = 0.55;
uniform float tint_strength = 0.75;
// Mean colour of the detail texture: dividing by it keeps the authored tint.
uniform vec3 detail_mean = vec3(0.45, 0.43, 0.4);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 vertex_linear(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
#else
	return c;
#endif
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy) * w.x + texture(tex, p.xz) * w.y + texture(tex, p.xy) * w.z;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = world_pos * scale;
	vec3 detail = triplanar(detail_albedo, p, w).rgb;
	vec3 tint = vertex_linear(COLOR.rgb);
	vec3 albedo = mix(detail, tint * detail / detail_mean, tint_strength);
	vec3 n = triplanar(detail_normal, p, w).rgb;
	vec3 orm = triplanar(detail_orm, p, w).rgb;
	float n1 = noise(world_pos.xz * 1.3) * 0.6 + noise(world_pos.xz * 4.1) * 0.4;
	float moss = smoothstep(0.35, 0.8, world_normal.y + (n1 - 0.5) * 0.9) * moss_amount;
	moss = max(moss, smoothstep(0.35, 0.0, world_pos.y) * moss_amount * 0.6 * n1);
	vec3 moss_col = triplanar(moss_albedo, p * 1.4, w).rgb;
	albedo = mix(albedo, moss_col, moss);
	n = mix(n, triplanar(moss_normal, p * 1.4, w).rgb, moss);
	ALBEDO = albedo;
	NORMAL_MAP = n;
	AO = orm.r;
	ROUGHNESS = clamp(mix(orm.g, 0.9, moss), 0.5, 1.0);
	METALLIC = 0.0;
}
