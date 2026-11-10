class_name CombatNumbers
extends Control
## Iteration 1.7: floating combat numbers drawn in screen space, so they stay crisp
## and readable on phones (they scale with the UI, not with the 3D distance).
## Damage, healing, support statuses and K.O. use different colours and sizes
## (CombatCues.NUMBER_STYLES). Short life (< 1 s), a small pop, a clean rise and a
## quick fade; numbers on the same target stack instead of overlapping.

const LIFE := 0.95
const STATUS_LIFE := 1.15
const RISE := 46.0

var camera: Camera3D
var time_scale: float = 1.0
var _items: Array[Dictionary] = []

func _ready() -> void:
	name = "CombatNumbers"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

## Shows `text` above `world` (a point in the arena). `delay` in seconds.
func show_text(world: Vector3, text: String, style: String, delay: float = 0.0) -> Label:
	var s: Dictionary = CombatCues.NUMBER_STYLES.get(style, CombatCues.NUMBER_STYLES["damage"])
	var size: int = s.size
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", EclipseUI.font("bold"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", s.fill)
	label.add_theme_color_override("font_outline_color", s.outline)
	label.add_theme_constant_override("outline_size", maxi(6, size / 5))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.visible = false
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	# Stack over numbers that appeared on the same spot moments ago.
	var stack := 0.0
	for item in _items:
		if item.world.distance_to(world) < 0.6 and float(item.age) < 0.35:
			stack += float(item.label.size.y) * 0.8
	var is_status := style in ["status", "ko", "summon"]
	_items.append({"label": label, "world": world, "age": -delay, "life": STATUS_LIFE if is_status else LIFE,
		"stack": stack, "pop": not is_status})
	_place(_items[-1])
	return label

func clear() -> void:
	for item in _items:
		if is_instance_valid(item.label):
			item.label.queue_free()
	_items.clear()

func active_count() -> int:
	return _items.size()

func _process(delta: float) -> void:
	if _items.is_empty():
		return
	var step := delta / maxf(time_scale, 0.001)
	for i in range(_items.size() - 1, -1, -1):
		var item: Dictionary = _items[i]
		item.age = float(item.age) + step
		if not is_instance_valid(item.label) or float(item.age) >= float(item.life):
			if is_instance_valid(item.label):
				item.label.queue_free()
			_items.remove_at(i)
			continue
		_place(item)

func _place(item: Dictionary) -> void:
	var label: Label = item.label
	var age := float(item.age)
	if age < 0.0 or camera == null or not camera.is_inside_tree() or camera.is_position_behind(item.world):
		label.visible = false
		return
	label.visible = true
	var t := age / float(item.life)
	# Pop: quick overshoot for numbers, gentle fade-in for statuses.
	var scale_value := 1.0
	if bool(item.pop):
		scale_value = lerpf(0.55, 1.18, clampf(age / 0.08, 0.0, 1.0)) if age < 0.08 else lerpf(1.18, 1.0, clampf((age - 0.08) / 0.1, 0.0, 1.0))
	label.scale = Vector2.ONE * scale_value
	var rise := RISE * (1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0))
	label.modulate.a = 1.0 if t < 0.7 else clampf(1.0 - (t - 0.7) / 0.3, 0.0, 1.0)
	if not bool(item.pop):
		label.modulate.a *= clampf(age / 0.08, 0.0, 1.0)
	var screen := camera.unproject_position(item.world)
	var at := screen - label.size * 0.5 - Vector2(0, rise + float(item.stack))
	var bounds := get_viewport_rect().size
	label.position = Vector2(clampf(at.x, 8.0, bounds.x - label.size.x - 8.0), clampf(at.y, 8.0, bounds.y - label.size.y - 8.0))
