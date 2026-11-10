shader_type spatial;
// HD Eclipse Forest ground: four CC0 PBR layers (Poly Haven) blended by a
// world-space mask (R trail, G meadow, B plaza) with height-aware transitions.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec4 mask_rect = vec4(-32.0, -34.0, 64.0, 55.0); // x, z, width, depth

uniform sampler2D floor_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trail_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaza_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaza_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaza_orm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform float floor_scale = 0.33;
uniform float meadow_scale = 0.4;
uniform float trail_scale = 0.38;
uniform float plaza_scale = 0.3;
uniform vec3 floor_tint : source_color = vec3(0.86, 0.9, 0.8);
uniform vec3 meadow_tint : source_color = vec3(0.9, 1.0, 0.82);
uniform float blend_sharpness = 6.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float height_blend(float base, float layer_height, float weight) {
	return clamp((weight - (1.0 - layer_height) * 0.55) * blend_sharpness + weight * 0.5, 0.0, 1.0);
}

void fragment() {
	vec2 xz = world_pos.xz;
	vec3 m = texture(mask, (xz - mask_rect.xy) / mask_rect.zw).rgb;
	vec2 uf = xz * floor_scale;
	vec2 um = xz * meadow_scale + vec2(0.37, 0.11);
	vec2 ut = xz * trail_scale;
	vec2 up = xz * plaza_scale;

	vec3 a = texture(floor_albedo, uf).rgb * floor_tint;
	vec3 n = texture(floor_normal, uf).rgb;
	vec3 o = texture(floor_orm, uf).rgb;

	vec3 ma = texture(meadow_albedo, um).rgb * meadow_tint;
	float wm = height_blend(0.0, dot(ma, vec3(0.33)) * 1.6, m.g);
	a = mix(a, ma, wm);
	n = mix(n, texture(meadow_normal, um).rgb, wm);
	o = mix(o, texture(meadow_orm, um).rgb, wm);

	vec3 ta = texture(trail_albedo, ut).rgb;
	float wt = height_blend(0.0, dot(ta, vec3(0.33)) * 1.8, m.r);
	a = mix(a, ta, wt);
	n = mix(n, texture(trail_normal, ut).rgb, wt);
	o = mix(o, texture(trail_orm, ut).rgb, wt);

	vec3 pa = texture(plaza_albedo, up).rgb;
	float wp = height_blend(0.0, dot(pa, vec3(0.33)) * 1.8, m.b);
	a = mix(a, pa, wp);
	n = mix(n, texture(plaza_normal, up).rgb, wp);
	o = mix(o, texture(plaza_orm, up).rgb, wp);

	ALBEDO = a;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.2;
	AO = o.r;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = clamp(o.g, 0.55, 1.0);
	METALLIC = 0.0;
}
