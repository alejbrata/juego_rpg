shader_type spatial;
render_mode cull_disabled;
// Instanced grass blades for the HD forest. Colour follows a root→tip gradient
// tinted per instance; wind bends the tip; blades fade near the player.

uniform vec3 root_color : source_color = vec3(0.2, 0.25, 0.1);
uniform vec3 tip_color : source_color = vec3(0.55, 0.62, 0.27);
uniform vec3 dry_color : source_color = vec3(0.62, 0.55, 0.3);
uniform float wind_strength = 0.12;
uniform vec3 push_position = vec3(0.0, -100.0, 0.0);
uniform float push_radius = 0.7;

varying float v_tip;
varying float v_hash;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_hash = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	v_tip = clamp(VERTEX.y / 0.36, 0.0, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * 1.6 + world.x * 0.35 + world.z * 0.25) * 0.6 + sin(TIME * 3.3 + world.x * 1.7) * 0.4;
	vec3 bend = vec3(gust, 0.0, gust * 0.4) * wind_strength * v_tip * v_tip;
	vec3 away = world - push_position;
	away.y = 0.0;
	float push = (1.0 - smoothstep(0.0, push_radius, length(away))) * v_tip;
	bend += normalize(away + vec3(0.0001)) * push * 0.35 - vec3(0.0, push * 0.25, 0.0);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(bend, 0.0)).xyz;
}

void fragment() {
	vec3 tip = mix(tip_color, dry_color, smoothstep(0.7, 1.0, v_hash) * 0.7);
	vec3 c = mix(root_color, tip, v_tip) * (0.85 + 0.3 * v_hash);
	ALBEDO = c;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.5;
	AO = mix(0.6, 1.0, v_tip);
	AO_LIGHT_AFFECT = 0.5;
}
