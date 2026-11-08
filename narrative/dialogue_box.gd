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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.25)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 18
	panel.offset_right = -18
	panel.offset_top = -240
	panel.offset_bottom = -18
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.085, 0.11, 0.98)
	style.border_color = Color("b9a87a")
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("d9c58e"))
	column.add_child(title_label)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 18)
	column.add_child(speaker_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 18)
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(text_label)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	count_label = Label.new()
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.add_theme_font_size_override("font_size", 13)
	controls.add_child(count_label)
	skip_button = Button.new()
	skip_button.text = "Omitir introducción"
	skip_button.custom_minimum_size = Vector2(190, 48)
	skip_button.pressed.connect(skip)
	controls.add_child(skip_button)
	advance_button = Button.new()
	advance_button.custom_minimum_size = Vector2(190, 48)
	advance_button.pressed.connect(advance)
	controls.add_child(advance_button)
	visible = false

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
	return true

func _show_line() -> void:
	var line: Dictionary = _lines[index]
	speaker_label.text = line.speaker
	speaker_label.add_theme_color_override("font_color", {"Kael": Color("a9c3e1"), "Lyra": Color("c6b6e7"), "Nira": Color("afd2b2")}.get(line.speaker, Color.WHITE))
	text_label.text = line.text
	count_label.text = "%d/%d · Espacio / Enter" % [index + 1, _lines.size()]
	advance_button.text = "Cerrar" if index == _lines.size() - 1 else "Continuar"

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
