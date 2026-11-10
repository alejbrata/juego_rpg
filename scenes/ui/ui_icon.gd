class_name UIIcon
extends Control
## Small vector glyphs drawn with primitives (no icon font, crisp at any scale).
## kind: attack, technique, magic, support, guard, guardian, menu, back, next.

var kind := "attack"
var color := EclipseUI.IVORY

static func make(parent: Node, icon_kind: String, tint: Color, side: float = 22.0) -> UIIcon:
	var icon := UIIcon.new()
	icon.kind = icon_kind
	icon.color = tint
	icon.custom_minimum_size = Vector2(side, side)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func set_look(icon_kind: String, tint: Color) -> void:
	if icon_kind != kind or tint != color:
		kind = icon_kind
		color = tint
		queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var w := maxf(1.5, s * 0.09)
	match kind:
		"attack":   # sword
			draw_line(c + Vector2(-0.32, 0.32) * s, c + Vector2(0.34, -0.34) * s, color, w * 1.2, true)
			draw_line(c + Vector2(-0.30, 0.06) * s, c + Vector2(-0.06, 0.30) * s, color, w, true)
			draw_circle(c + Vector2(-0.38, 0.38) * s, w * 0.9, color)
		"technique":   # faceted diamond
			var d := PackedVector2Array([c + Vector2(0, -0.42) * s, c + Vector2(0.32, 0) * s, c + Vector2(0, 0.42) * s, c + Vector2(-0.32, 0) * s])
			draw_colored_polygon(d, Color(color, 0.35))
			d.append(d[0])
			draw_polyline(d, color, w, true)
			draw_line(d[0], d[2], Color(color, 0.7), w * 0.6, true)
		"magic":   # four-point star
			var points := PackedVector2Array()
			for i in 8:
				var r := (0.44 if i % 2 == 0 else 0.13) * s
				points.append(c + Vector2.from_angle(i * PI / 4 - PI / 2) * r)
			draw_colored_polygon(points, color)
		"support":   # rounded cross
			draw_line(c + Vector2(0, -0.34) * s, c + Vector2(0, 0.34) * s, color, w * 2.0, true)
			draw_line(c + Vector2(-0.34, 0) * s, c + Vector2(0.34, 0) * s, color, w * 2.0, true)
		"guard":   # shield
			var shield := PackedVector2Array([c + Vector2(-0.32, -0.36) * s, c + Vector2(0.32, -0.36) * s, c + Vector2(0.30, 0.02) * s,
				c + Vector2(0, 0.40) * s, c + Vector2(-0.30, 0.02) * s])
			draw_colored_polygon(shield, Color(color, 0.3))
			shield.append(shield[0])
			draw_polyline(shield, color, w, true)
		"guardian":   # radiant sun
			draw_circle(c, 0.18 * s, color)
			for i in 8:
				var a := Vector2.from_angle(i * PI / 4)
				draw_line(c + a * 0.27 * s, c + a * 0.43 * s, color, w, true)
		"menu":
			for y in [-0.22, 0.0, 0.22]:
				draw_line(c + Vector2(-0.3, y) * s, c + Vector2(0.3, y) * s, color, w * 1.1, true)
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(0.12, -0.28) * s, c + Vector2(-0.16, 0) * s, c + Vector2(0.12, 0.28) * s]), color, w * 1.2, true)
		"next":
			draw_polyline(PackedVector2Array([c + Vector2(-0.12, -0.28) * s, c + Vector2(0.16, 0) * s, c + Vector2(-0.12, 0.28) * s]), color, w * 1.2, true)
