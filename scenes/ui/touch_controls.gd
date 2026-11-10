class_name TouchControls
extends RefCounted
## 1.6 touch support helpers: when the touch interface is used, physical size of
## the UI on phones, mouse-as-finger simulation on PC and multi-finger buttons.
##
## Mode: visuals/touch/mode = "auto" (touchscreen devices), "on" (force, also on PC:
## the mouse then acts as a finger) or "off". Command line: -- --touch / --no-touch.

const MIN_TARGET_MM := 6.0      # finger target; larger hid the battle on a real-size screen (emulator check)

static func mode() -> String:
	var args := OS.get_cmdline_user_args()
	if args.has("--touch"):
		return "on"
	if args.has("--no-touch"):
		return "off"
	return String(ProjectSettings.get_setting("visuals/touch/mode", "auto"))

static func enabled() -> bool:
	match mode():
		"on":
			return true
		"off":
			return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

## Called once by the game flow: on touch devices scales the 2D interface so a
## 48-unit button is at least ~7 mm on the real screen; on PC with forced touch,
## lets the mouse produce touch events. 3D rendering is not affected.
static func configure(tree: SceneTree) -> void:
	if not enabled():
		return
	if not DisplayServer.is_touchscreen_available():
		Input.emulate_touch_from_mouse = true
	tree.root.content_scale_factor = ui_scale(tree.root)

static func ui_scale(window: Window) -> float:
	var dpi := DisplayServer.screen_get_dpi()
	var screen := DisplayServer.screen_get_size()
	if dpi <= 0 or screen.y <= 0 or DisplayServer.get_name() == "headless":
		return 1.0
	# Logical height is 640 (canvas_items, expand): physical mm per logical unit.
	var mm_per_unit := (float(mini(screen.x, screen.y)) / dpi * 25.4) / 640.0
	return clampf(MIN_TARGET_MM / (48.0 * mm_per_unit), 1.0, 1.3)

## Godot turns only finger 0 into mouse clicks; other fingers (e.g. tapping
## Interact while the joystick is held) would be lost. This presses a visible,
## enabled button under a secondary finger on release, as a click would.
class SecondaryFingers extends Node:
	var roots: Array[Control] = []
	var _down := {}   # finger index -> button pressed under it

	func _input(event: InputEvent) -> void:
		if not event is InputEventScreenTouch or event.index == 0:
			return
		if event.pressed:
			var button := button_at(event.position)
			if button != null:
				_down[event.index] = button
				get_viewport().set_input_as_handled()
		elif _down.has(event.index):
			var button: BaseButton = _down[event.index]
			_down.erase(event.index)
			if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
				if button.toggle_mode:
					button.button_pressed = not button.button_pressed   # emits toggled, like a click
				else:
					button.pressed.emit()
			get_viewport().set_input_as_handled()

	func button_at(point: Vector2) -> BaseButton:
		for root in roots:
			if not is_instance_valid(root) or not root.is_visible_in_tree():
				continue
			var found := _search(root, point)
			if found != null:
				return found
		return null

	func _search(node: Node, point: Vector2) -> BaseButton:
		for i in range(node.get_child_count() - 1, -1, -1):
			var child := node.get_child(i)
			if child is Control and not (child as Control).is_visible_in_tree():
				continue
			var found := _search(child, point)
			if found != null:
				return found
			if child is BaseButton and not child.disabled and (child as Control).get_global_rect().has_point(point):
				return child
		return null
