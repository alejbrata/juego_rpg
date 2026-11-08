extends "res://scenes/battle.gd"

signal updated
signal battle_reset
signal return_to_zone_requested

var presentation_busy: bool = false
var presentation_actor: String = ""
var encounter_mode: bool = false
var _return_button: Button

func _ready() -> void:
	# Reuse the original controller; only the arrangement changes for the 3D view.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := _panel(self)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 12
	header.offset_right = -12
	header.offset_top = 10
	var top := VBoxContainer.new()
	header.add_child(top)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 22)
	top.add_child(status)
	guardian_info = Label.new()
	guardian_info.add_theme_font_size_override("font_size", 14)
	guardian_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(guardian_info)
	resonance_bar = ProgressBar.new()
	resonance_bar.max_value = 100
	resonance_bar.custom_minimum_size.y = 12
	resonance_bar.show_percentage = false
	top.add_child(resonance_bar)
	var footer := _panel(self)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 12
	footer.offset_right = -12
	footer.offset_top = -258
	footer.offset_bottom = -10
	var rows := VBoxContainer.new()
	footer.add_child(rows)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	rows.add_child(split)
	var commands := VBoxContainer.new()
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands.size_flags_stretch_ratio = 2.0
	split.add_child(commands)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 32
	message.add_theme_font_size_override("font_size", 14)
	commands.add_child(message)
	actions = HFlowContainer.new()
	commands.add_child(actions)
	targets = HFlowContainer.new()
	commands.add_child(targets)
	var log_column := VBoxContainer.new()
	log_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(log_column)
	var log_title := Label.new()
	log_title.text = "REGISTRO"
	log_title.add_theme_color_override("font_color", Color("c5ae78"))
	log_column.add_child(log_title)
	log_view = RichTextLabel.new()
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.scroll_following = true
	log_view.add_theme_font_size_override("normal_font_size", 13)
	log_column.add_child(log_view)
	var controls := HFlowContainer.new()
	rows.add_child(controls)
	_add_button(controls, "Reintentar combate" if encounter_mode else "Reiniciar combate", _restart)
	_return_button = _add_button(controls, "Volver al claro" if encounter_mode else "Nueva partida (RE/PA a cero)", func() -> void:
		if encounter_mode:
			return_to_zone_requested.emit()
		else:
			_new_party())
	# Retained for the shared controller; actor labels provide these data in 3D.
	roster = Label.new()
	roster.visible = false
	add_child(roster)
	_restart()

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.09, 0.94)
	style.border_color = Color("657483")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _add_button(container: Container, text: String, callback: Callable) -> Button:
	var button := super._add_button(container, text, callback)
	button.add_theme_font_size_override("font_size", 14)
	if container == actions:
		button.text = text.replace(" [", "\n[").replace("Defender (", "Defender\n(")
	return button

func _restart() -> void:
	super._restart()
	battle_reset.emit()

func _refresh() -> void:
	super._refresh()
	set_presentation_busy(presentation_busy)
	if encounter_mode and _return_button != null:
		_return_button.disabled = presentation_busy or engine.phase != BattleEngine.Phase.DEFEAT
	updated.emit()

func set_presentation_busy(value: bool) -> void:
	presentation_busy = value
	if value:
		status.text = "Acción de %s · resolviendo…" % presentation_actor
	for container in [actions, targets]:
		for button in container.get_children():
			if value:
				button.disabled = true
	if not value:
		# Rebuild using the original affordability checks; never blindly enable skills.
		for button in targets.get_children():
			button.disabled = false

func unlock_actions() -> void:
	presentation_busy = false
	presentation_actor = ""
	_refresh()
