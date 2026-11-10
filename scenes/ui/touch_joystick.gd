class_name TouchJoystick
extends Control
## 1.6 exploration joystick: vector drawing (EclipseUI palette), analogue 360°,
## dead zone, magnitude clamped to 1, one finger tracked by its touch index.
## It only produces a Vector2; the existing CharacterBody3D moves the hero.

signal moved(vector: Vector2)
signal released

const RADIUS := 70.0          # travel of the knob (logical units)
const KNOB := 30.0
const DEAD_ZONE := 0.18       # fraction of RADIUS ignored around the centre

var finger := -1              # touch index currently driving the stick, -1 idle
var vector := Vector2.ZERO
var centre := Vector2.ZERO    # base centre in global (canvas) coordinates
var _knob := Vector2.ZERO
var _home := Vector2.ZERO
var _activity := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			release())

func _notification(what: int) -> void:
	# Scene change (battle, new game) with a finger still down: no residual motion.
	if what == NOTIFICATION_EXIT_TREE:
		release()

## Pure conversion used by the stick and the tests: offset from the base centre
## to a movement vector (dead zone, rescaled so motion starts smoothly, length <= 1).
static func to_vector(offset: Vector2, radius: float = RADIUS, dead_zone: float = DEAD_ZONE) -> Vector2:
	var length := offset.length() / radius
	if length <= dead_zone:
		return Vector2.ZERO
	var strength := clampf((length - dead_zone) / (1.0 - dead_zone), 0.0, 1.0)
	return offset.normalized() * strength

func set_home(point: Vector2) -> void:
	_home = point
	if finger < 0:
		centre = point
		_knob = point
		queue_redraw()

## Touch zone: the joystick panel area (left-bottom), never the right half.
func accepts(point: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(point)

func press(index: int, point: Vector2) -> bool:
	if finger >= 0 or not accepts(point):
		return false
	finger = index
	# The base jumps under the thumb (floating stick) but stays inside the zone.
	var area := get_global_rect().grow(-RADIUS * 0.6)
	centre = point.clamp(area.position, area.end) if area.has_area() else point
	drag(index, point)
	return true

func drag(index: int, point: Vector2) -> bool:
	if index != finger:
		return false
	var offset := (point - centre).limit_length(RADIUS)
	_knob = centre + offset
	vector = to_vector(point - centre)
	moved.emit(vector)
	queue_redraw()
	return true

## Lifting the finger anywhere (inside or outside the zone) stops the hero.
func release(index: int = -2) -> bool:
	if finger < 0 or (index != -2 and index != finger):
		return false
	finger = -1
	vector = Vector2.ZERO
	centre = _home
	_knob = _home
	released.emit()
	queue_redraw()
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if press(event.index, event.position):
				get_viewport().set_input_as_handled()
		elif release(event.index):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if drag(event.index, event.position):
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var target := 1.0 if finger >= 0 else 0.0
	if not is_equal_approx(_activity, target):
		_activity = move_toward(_activity, target, delta * 6.0)
		queue_redraw()

func _draw() -> void:
	var base := centre - global_position
	var knob := _knob - global_position
	var rim := EclipseUI.GOLD.lerp(EclipseUI.GOLD_BRIGHT, _activity)
	draw_circle(base, RADIUS + 8, Color(EclipseUI.NIGHT, 0.32 + 0.18 * _activity))
	draw_arc(base, RADIUS + 8, 0, TAU, 64, Color(rim, 0.45 + 0.4 * _activity), 2.0, true)
	draw_arc(base, RADIUS * DEAD_ZONE + KNOB * 0.2, 0, TAU, 32, Color(EclipseUI.IVORY, 0.12), 1.0, true)
	# Direction ticks (N/E/S/W) help reading the stick at a glance.
	for i in 4:
		var direction := Vector2.from_angle(i * PI / 2)
		draw_line(base + direction * (RADIUS - 6), base + direction * (RADIUS + 2), Color(EclipseUI.IVORY, 0.25), 2.0, true)
	if vector != Vector2.ZERO:
		draw_line(base, knob, Color(EclipseUI.GOLD_BRIGHT, 0.35), 4.0, true)
	draw_circle(knob, KNOB, Color(EclipseUI.PETROL_LIGHT, 0.75 + 0.2 * _activity))
	draw_arc(knob, KNOB, 0, TAU, 48, rim, 2.0, true)
	draw_circle(knob, KNOB * 0.35, Color(EclipseUI.IVORY, 0.25 + 0.35 * _activity))
