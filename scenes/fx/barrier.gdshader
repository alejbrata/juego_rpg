// Iteration 1.7: Protection / Defender barrier. Hexagonal cells brightest at the
// silhouette (fresnel), additive and unlit; `intensity` animates appear/fade.
// Runs on Forward+, Mobile and Compatibility (no screen textures).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.45, 0.8, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float energy = 1.6;
uniform float cells = 9.0;
uniform float sweep = 0.0;   // 0..1 band of light travelling upwards while it forms

float hex_edge(vec2 p) {
	// Distance to the edge of the nearest hexagon (pointy-top grid).
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return 0.5 - max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x);
}

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	float edge = smoothstep(0.06, 0.0, hex_edge(UV * vec2(cells * 2.0, cells)));
	float band = sweep > 0.0 ? smoothstep(0.12, 0.0, abs(UV.y - (1.0 - sweep))) : 0.0;
	float glow = rim * 0.85 + edge * (0.25 + rim * 0.75) + band * 0.9 + 0.04;
	ALBEDO = color.rgb * energy;
	ALPHA = clamp(glow * intensity, 0.0, 1.0);
}
