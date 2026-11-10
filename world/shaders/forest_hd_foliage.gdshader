shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// HD foliage for the CC0 scanned plants: PBR maps from the imported material,
// alpha scissor, gentle wind, back-lit translucency, per-instance hue jitter and
// the dithered see-through used by hero crowns between camera and player.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = true;
uniform bool has_orm = true;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_cut = 0.45;
uniform float wind_strength = 0.05;
uniform float wind_height = 6.0;
uniform float flutter = 0.12;
uniform float variation = 0.1;
uniform float translucency = 0.45;
uniform float reveal_radius = 0.0;
uniform vec3 reveal_camera = vec3(0.0, 18.5, 14.5);
uniform vec3 reveal_target = vec3(0.0, -100.0, 0.0);

varying float v_hash;
varying vec3 world_pos;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_hash = fract(sin(dot(origin.xz, vec2(39.3468, 11.135))) * 24634.6345);
	float h = clamp(VERTEX.y / wind_height, 0.0, 1.0);
	float t = TIME * 1.3 + origin.x * 0.21 + origin.z * 0.17;
	vec3 sway = vec3(sin(t), 0.0, cos(t * 0.83)) * wind_strength * h * h;
	sway += vec3(sin(TIME * 4.7 + VERTEX.x * 3.1 + VERTEX.z * 2.3), 0.0, cos(TIME * 4.1 + VERTEX.y * 2.7)) * flutter * wind_strength * h;
	VERTEX += sway;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 base = texture(albedo_tex, UV) * albedo_color;
	if (base.a < alpha_cut) {
		discard;
	}
	if (reveal_radius > 0.0) {
		vec3 seg = reveal_target - reveal_camera;
		float t = clamp(dot(world_pos - reveal_camera, seg) / dot(seg, seg), 0.0, 1.0);
		float d = length(world_pos - (reveal_camera + seg * t));
		float fade = 1.0 - smoothstep(reveal_radius * 0.55, reveal_radius, d);
		ivec2 px = ivec2(FRAGCOORD.xy) % 4;
		const float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if (t > 0.05 && t < 0.97 && fade * 0.82 > (bayer[px.y * 4 + px.x] + 0.5) / 16.0) {
			discard;
		}
	}
	vec3 albedo = base.rgb * (1.0 - variation + 2.0 * variation * v_hash);
	albedo.r *= 1.0 + (v_hash - 0.5) * variation;
	ALBEDO = albedo;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	if (has_orm) {
		vec3 orm = texture(orm_tex, UV).rgb;
		AO = orm.r;
		ROUGHNESS = clamp(orm.g, 0.45, 1.0);
	} else {
		ROUGHNESS = 0.8;
	}
	SPECULAR = 0.3;
	BACKLIGHT = albedo * translucency;
}
