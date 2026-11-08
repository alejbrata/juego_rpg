extends "res://scenes/battle.gd"

signal updated
signal battle_reset
signal return_to_zone_requested
signal target_preview(target_id: int)
signal camera_toggled(enabled: bool)
signal skip_toggled(enabled: bool)

var presentation_busy: bool = false
var presentation_actor: String = ""
var presentation_actor_id: int = -1
var encounter_mode: bool = false
var _return_button: Button
var party_cards: Array[PanelContainer] = []
var log_panel: PanelContainer
var camera_option: CheckButton
var skip_option: CheckButton
var _cards: HBoxContainer
var _cancel: Button
var _menu_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := _panel(self)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 12
	header.offset_right = -12
	header.offset_top = 10
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	header.add_child(top)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 18)
	titles.add_child(status)
	guardian_info = Label.new()
	guardian_info.add_theme_font_size_override("font_size", 13)
	guardian_info.add_theme_color_override("font_color", Color("c9bd9b"))
	titles.add_child(guardian_info)
	var resonance := VBoxContainer.new()
	resonance.custom_minimum_size.x = 230
	top.add_child(resonance)
	var re_label := Label.new()
	re_label.text = "RESONANCIA"
	re_label.add_theme_font_size_override("font_size", 12)
	resonance.add_child(re_label)
	resonance_bar = ProgressBar.new()
	resonance_bar.max_value = 100
	resonance_bar.custom_minimum_size.y = 16
	resonance_bar.add_theme_stylebox_override("fill", _style(Color("bd9654")))
	resonance.add_child(resonance_bar)
	var footer := _panel(self)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 12
	footer.offset_right = -12
	footer.offset_top = -202
	footer.offset_bottom = -10
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	footer.add_child(column)
	_cards = HBoxContainer.new()
	column.add_child(_cards)
	var command_row := HBoxContainer.new()
	column.add_child(command_row)
	actions = HFlowContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_row.add_child(actions)
	targets = HFlowContainer.new()
	targets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets.visible = false
	command_row.add_child(targets)
	_cancel = _add_button(command_row, "Atrás", _cancel_selection)
	_cancel.custom_minimum_size.x = 90
	_cancel.visible = false
	message = Label.new()
	message.add_theme_font_size_override("font_size", 13)
	message.add_theme_color_override("font_color", Color("c8d2ce"))
	column.add_child(message)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	column.add_child(tools)
	_add_button(tools, "Reintentar" if encounter_mode else "Reiniciar", _restart)
	_return_button = _add_button(tools, "Volver al claro" if encounter_mode else "Nueva partida", func() -> void:
		if encounter_mode:
			return_to_zone_requested.emit()
		else:
			_new_party())
	_add_button(tools, "Registro", toggle_log)
	camera_option = CheckButton.new()
	camera_option.text = "Cámara suave"
	camera_option.button_pressed = true
	camera_option.custom_minimum_size.y = 48
	camera_option.add_theme_font_size_override("font_size", 14)
	camera_option.toggled.connect(func(value: bool) -> void: camera_toggled.emit(value))
	tools.add_child(camera_option)
	skip_option = CheckButton.new()
	skip_option.text = "Omitir animación"
	skip_option.custom_minimum_size.y = 48
	skip_option.add_theme_font_size_override("font_size", 14)
	skip_option.toggled.connect(func(value: bool) -> void: skip_toggled.emit(value))
	tools.add_child(skip_option)
	_build_log()
	roster = Label.new()
	roster.visible = false
	add_child(roster)
	_restart()

func _build_log() -> void:
	log_panel = _panel(self)
	log_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_panel.offset_left = 40
	log_panel.offset_right = -40
	log_panel.offset_top = 80
	log_panel.offset_bottom = -40
	log_panel.visible = false
	var column := VBoxContainer.new()
	log_panel.add_child(column)
	var heading := Label.new()
	heading.text = "REGISTRO COMPLETO DEL COMBATE"
	heading.add_theme_color_override("font_color", Color("d3ba82"))
	column.add_child(heading)
	log_view = RichTextLabel.new()
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.scroll_following = true
	log_view.add_theme_font_size_override("normal_font_size", 15)
	column.add_child(log_view)
	_add_button(column, "Cerrar registro", toggle_log)

func toggle_log() -> void:
	log_panel.visible = not log_panel.visible
	if log_panel.visible:
		log_panel.get_child(0).get_child(2).grab_focus()

func _style(color: Color, border: Color = Color("4c625f")) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(4)
	return result

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _style(Color(0.055, 0.09, 0.11, 0.96), Color("8a846b"))
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _add_button(container: Container, text: String, callback: Callable) -> Button:
	var button := super._add_button(container, text, callback)
	button.custom_minimum_size = Vector2(140 if container in [actions, targets] else 110, 48)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _style(Color("253c44")))
	button.add_theme_stylebox_override("hover", _style(Color("38565e"), Color("c4b17c")))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("d9c58e")))
	button.add_theme_stylebox_override("pressed", _style(Color("47666b"), Color("d9c58e")))
	button.add_theme_stylebox_override("disabled", _style(Color("1b2b30"), Color("344649")))
	button.add_theme_color_override("font_disabled_color", Color("687878"))
	if container == actions:
		button.text = text.replace(" [", "\n[").replace("Defender (", "Defender\n(")
	return button

func _restart() -> void:
	if _menu_tween != null:
		_menu_tween.kill()
	if log_panel != null:
		log_panel.visible = false
	super._restart()
	battle_reset.emit()

func _refresh() -> void:
	super._refresh()
	_refresh_cards()
	guardian_info.text = "BOSQUE DEL ECLIPSE"
	for fighter in engine.fighters:
		if fighter.enemy:
			continue
		var guardian := run.guardian_for(fighter.data.id)
		if guardian != null:
			guardian_info.text += " · Ignar / %s · Nv %d · %d PA" % [fighter.data.label, run.guardian_level(fighter.data.id), run.progress(guardian.id).affinity]
	actions.visible = selected == null
	targets.visible = selected != null
	_cancel.visible = selected != null
	set_presentation_busy(presentation_busy)
	if encounter_mode and _return_button != null:
		_return_button.disabled = presentation_busy or engine.phase != BattleEngine.Phase.DEFEAT
	updated.emit()

func _refresh_cards() -> void:
	_clear(_cards)
	party_cards.clear()
	for i in range(engine.fighters.size()):
		var fighter := engine.fighters[i]
		if fighter.enemy:
			continue
		var active: bool = i == (presentation_actor_id if presentation_busy else engine.current_id()) and fighter.hp > 0
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color("21363e"), Color("cfb878") if active else Color("43575a")))
		_cards.add_child(card)
		party_cards.append(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 1)
		card.add_child(content)
		var title := Label.new()
		title.text = ("▶ " if active else "") + fighter.data.label
		if fighter.hp == 0:
			title.text += " · KO"
		elif fighter.guarding:
			title.text += " · Defensa"
		elif fighter.protection_target >= 0:
			title.text += " · Protege"
		if run.guardian_for(fighter.data.id) != null:
			title.text += " · Ignar"
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color("e2c98c") if active else Color("e1e6db"))
		content.add_child(title)
		var values := Label.new()
		values.text = "PV %d/%d     PM %d/%d" % [fighter.hp, fighter.data.max_hp, fighter.mp, fighter.data.max_mp]
		values.add_theme_font_size_override("font_size", 14)
		content.add_child(values)
		var bar := ProgressBar.new()
		bar.max_value = fighter.data.max_hp
		bar.value = fighter.hp
		bar.show_percentage = false
		bar.custom_minimum_size.y = 5
		bar.add_theme_stylebox_override("fill", _style(Color("83a181")))
		content.add_child(bar)

func _choose(ability: BattleAbility) -> void:
	super._choose(ability)
	actions.visible = false
	targets.visible = true
	_cancel.visible = true
	var ids := engine.valid_targets(ability)
	for i in range(ids.size()):
		var id := ids[i]
		var button := targets.get_child(i) as Button
		button.focus_entered.connect(func() -> void: target_preview.emit(id))
		button.mouse_entered.connect(func() -> void: target_preview.emit(id))
	if not ids.is_empty():
		target_preview.emit(ids[0])
		targets.get_child(0).grab_focus()
	if _menu_tween != null:
		_menu_tween.kill()
	targets.modulate.a = 0.5
	_menu_tween = create_tween()
	_menu_tween.tween_property(targets, "modulate:a", 1.0, 0.1)

func _cancel_selection() -> void:
	selected = null
	_clear(targets)
	_refresh()

func set_presentation_busy(value: bool) -> void:
	presentation_busy = value
	if value:
		status.text = "Acción de %s · resolviendo…" % presentation_actor
	for container in [actions, targets]:
		for button in container.get_children():
			if value:
				button.disabled = true
	_cancel.disabled = value

func unlock_actions() -> void:
	presentation_busy = false
	presentation_actor = ""
	presentation_actor_id = -1
	_refresh()
