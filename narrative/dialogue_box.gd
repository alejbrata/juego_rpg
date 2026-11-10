class_name DialogueBox
extends Control

signal conversation_closed(id: String)

var active: bool = false
var conversation_id: String = ""
var index: int = 0
var title_label: Label
var speaker_label: Label
var text_label: Label
var count_label: Label
var advance_button: Button
var skip_button: Button
var panel: PanelContainer
var _lines: Array[Dictionary] = []
var _can_skip: bool = false
var _plate: PanelContainer
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = EclipseUI.theme()
	# 1.5: soft bottom shade only, so the scene stays readable behind the text.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.04, 0.06, 0.0))
	gradient.set_color(1, Color(0.02, 0.04, 0.06, 0.55))
	var ramp := GradientTexture2D.new()
	ramp.gradient = gradient
	ramp.fill_from = Vector2(0, 0)
	ramp.fill_to = Vector2(0, 1)
	shade.texture = ramp
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	panel = EclipseUI.panel(self, 0.94)
	var box := EclipseUI.panel_box(0.94, Color(EclipseUI.GOLD, 0.7), 14)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 22
	box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	text_label = EclipseUI.label(column, "", 21, EclipseUI.IVORY, "text")
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_constant_override("line_spacing", 4)
	text_label.custom_minimum_size.y = 84
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	column.add_child(controls)
	count_label = EclipseUI.label(controls, "", 13, EclipseUI.MUTED, "medium")
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip_button = Button.new()
	skip_button.text = "Omitir introducción"
	skip_button.flat = true
	skip_button.custom_minimum_size = Vector2(190, 48)
	skip_button.add_theme_color_override("font_color", EclipseUI.IVORY_DIM)
	skip_button.pressed.connect(skip)
	controls.add_child(skip_button)
	advance_button = Button.new()
	advance_button.custom_minimum_size = Vector2(170, 48)
	advance_button.add_theme_stylebox_override("normal", EclipseUI.button_box(Color(EclipseUI.GOLD, 0.2), EclipseUI.GOLD))
	advance_button.add_theme_stylebox_override("hover", EclipseUI.button_box(Color(EclipseUI.GOLD, 0.32), EclipseUI.GOLD_BRIGHT))
	advance_button.add_theme_font_size_override("font_size", 18)
	advance_button.pressed.connect(advance)
	controls.add_child(advance_button)
	# Speaker plate overlapping the window edge; the conversation title is context.
	_plate = PanelContainer.new()
	var plate_box := EclipseUI.panel_box(0.98, EclipseUI.GOLD, 10)
	plate_box.content_margin_left = 16
	plate_box.content_margin_right = 16
	plate_box.content_margin_top = 4
	plate_box.content_margin_bottom = 4
	_plate.add_theme_stylebox_override("panel", plate_box)
	add_child(_plate)
	speaker_label = EclipseUI.label(_plate, "", 19, EclipseUI.IVORY, "title")
	title_label = EclipseUI.label(self, "", 13, EclipseUI.GOLD, "title")
	title_label.uppercase = true
	resized.connect(_layout)
	# Tapping the text window advances too (buttons keep their own action).
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			advance()
			panel.accept_event())
	visible = false

func _layout() -> void:
	var m := EclipseUI.safe_margins(get_viewport()) if is_inside_tree() else {"left": 16.0, "right": 16.0, "bottom": 16.0}
	var width := minf(900.0, size.x - m.left - m.right)
	panel.reset_size()
	var height := maxf(170.0, panel.get_combined_minimum_size().y)
	panel.size = Vector2(width, height)
	panel.position = Vector2((size.x - width) * 0.5, size.y - m.bottom - height)
	_plate.reset_size()
	_plate.position = panel.position + Vector2(20, -_plate.get_combined_minimum_size().y * 0.55)
	title_label.reset_size()
	title_label.position = panel.position + Vector2(width - title_label.get_combined_minimum_size().x - 24, 8)

func open(id: String, title: String, lines: Array[Dictionary], can_skip: bool = false) -> bool:
	if active or lines.is_empty() or id.is_empty():
		return false
	for line in lines:
		if not line.has("speaker") or not line.has("text"):
			return false
	conversation_id = id
	_lines = lines.duplicate(true)
	index = 0
	_can_skip = can_skip
	active = true
	visible = true
	title_label.text = title
	skip_button.visible = can_skip
	_show_line()
	advance_button.grab_focus()
	_layout()
	# Short entrance; input is accepted immediately.
	if _tween != null:
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	return true

func _show_line() -> void:
	var line: Dictionary = _lines[index]
	speaker_label.text = line.speaker
	speaker_label.add_theme_color_override("font_color", {"Kael": Color("a9c3e1"), "Lyra": Color("c6b6e7"), "Nira": Color("afd2b2")}.get(line.speaker, Color.WHITE))
	text_label.text = line.text
	count_label.text = "%d / %d   ·   %s" % [index + 1, _lines.size(), "Toca para continuar" if TouchControls.enabled() else "Espacio o Enter"]
	advance_button.text = "Cerrar" if index == _lines.size() - 1 else "Continuar  ›"
	_plate.visible = not String(line.speaker).is_empty()
	if is_inside_tree():
		_layout.call_deferred()

func advance() -> void:
	if not active:
		return
	index += 1
	if index >= _lines.size():
		_close()
	else:
		_show_line()

func skip() -> void:
	if active and _can_skip:
		_close()

func _close() -> void:
	var id := conversation_id
	active = false
	visible = false
	_lines.clear()
	conversation_closed.emit(id)

func _input(event: InputEvent) -> void:
	# Consume both key edges before GUI handling: otherwise a focused Button can
	# also advance on release after the dialogue advanced on the press.
	if active and event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if event.pressed and not event.echo:
			if skip_button.visible and get_viewport().gui_get_focus_owner() == skip_button:
				skip()
			else:
				advance()
		get_viewport().set_input_as_handled()
