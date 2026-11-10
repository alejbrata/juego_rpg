extends "res://scenes/battle.gd"
## 1.5 battle interface. Reads the resolved BattleEngine/PartyState and only decides
## presentation: which commands exist, their costs, targets and the invocation are
## still decided once in battle.gd and validated by the engine.
##
## Layout (anchored, safe-area aware): turn banner top-left, Resonance + options
## top-right, command window bottom-left, party cards bottom-right.

signal updated
signal battle_reset
signal return_to_zone_requested
signal target_preview(target_id: int)
signal targets_offered(target_ids: Array[int])
signal camera_toggled(enabled: bool)
signal skip_toggled(enabled: bool)

const COMMAND_WIDTH := 172.0
const PANEL_GAP := 10.0

var presentation_busy: bool = false
var presentation_actor: String = ""
var presentation_actor_id: int = -1
var encounter_mode: bool = false
var _return_button: Button
var party_cards: Array[PanelContainer] = []
var log_panel: PanelContainer
var options_panel: PanelContainer
var camera_option: CheckButton
var skip_option: CheckButton
var resonance_value: Label
var command_panel: PanelContainer
var command_title: Label
var result_row: HBoxContainer
var turn_panel: PanelContainer
var round_label: Label
var order_row: HBoxContainer
var menu_button: Button
var _resonance_panel: PanelContainer
var _resonance_glow: Tween
var _turn_emblem: PanelContainer
var _cards: VBoxContainer
var _card_parts: Array[Dictionary] = []
var _cancel: Button
var _menu_tween: Tween
var _last_actor := -2
var _margins := {}
var _log_empty: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = EclipseUI.theme()
	_build_turn_banner()
	_build_resonance()
	_build_commands()
	_build_party()
	_build_options()
	_build_log()
	roster = Label.new()
	roster.visible = false
	add_child(roster)
	_layout()
	resized.connect(_layout)
	_restart()

# --- construction ---------------------------------------------------------

func _build_turn_banner() -> void:
	turn_panel = EclipseUI.panel(self, 0.88)
	turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	turn_panel.add_child(row)
	_turn_emblem = EclipseUI.emblem(row, "", "?", 40)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	round_label = EclipseUI.caption(column, "Ronda 1")
	status = EclipseUI.label(column, "", 22, EclipseUI.IVORY, "title")
	order_row = HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 4)
	column.add_child(order_row)

func _build_resonance() -> void:
	var top := HBoxContainer.new()
	top.name = "TopRight"
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_resonance_panel = EclipseUI.panel(top, 0.88)
	_resonance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resonance_panel.custom_minimum_size.x = 250
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_resonance_panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	UIIcon.make(heading, "guardian", EclipseUI.RESONANCE, 16)
	var title := EclipseUI.caption(heading, "Resonancia")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resonance_value = EclipseUI.label(heading, "0", 18, EclipseUI.GOLD_BRIGHT, "bold")
	resonance_bar = EclipseUI.bar(column, EclipseUI.RESONANCE, 10)
	resonance_bar.max_value = 100
	guardian_info = EclipseUI.label(column, "", 14, EclipseUI.IVORY_DIM)
	menu_button = Button.new()
	menu_button.custom_minimum_size = Vector2(EclipseUI.TOUCH, EclipseUI.TOUCH)
	menu_button.tooltip_text = "Opciones y registro"
	menu_button.add_theme_stylebox_override("normal", EclipseUI.panel_box(0.88, Color(EclipseUI.GOLD, 0.55), 24))
	menu_button.add_theme_stylebox_override("hover", EclipseUI.panel_box(0.95, EclipseUI.GOLD, 24))
	menu_button.add_theme_stylebox_override("pressed", EclipseUI.panel_box(0.95, EclipseUI.GOLD_BRIGHT, 24))
	menu_button.pressed.connect(toggle_options)
	top.add_child(menu_button)
	var icon := UIIcon.make(menu_button, "menu", EclipseUI.IVORY, 22)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _build_commands() -> void:
	command_panel = EclipseUI.panel(self)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	command_panel.add_child(column)
	command_title = EclipseUI.label(column, "", 19, EclipseUI.GOLD_BRIGHT, "title")
	message = EclipseUI.label(column, "", 14, EclipseUI.IVORY_DIM)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x = COMMAND_WIDTH * 2 + 8
	actions = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	actions.custom_minimum_size.x = COMMAND_WIDTH * 2 + 8
	column.add_child(actions)
	targets = HFlowContainer.new()
	targets.add_theme_constant_override("h_separation", 8)
	targets.add_theme_constant_override("v_separation", 8)
	targets.custom_minimum_size.x = COMMAND_WIDTH * 2 + 8
	targets.visible = false
	column.add_child(targets)
	_cancel = _plain_button(column, "Atrás", _cancel_selection, "back")
	_cancel.custom_minimum_size.x = COMMAND_WIDTH * 2 + 8
	_cancel.tooltip_text = "Cancelar sin gastar el turno (Esc)"
	_cancel.visible = false
	result_row = HBoxContainer.new()
	result_row.add_theme_constant_override("separation", 8)
	result_row.visible = false
	column.add_child(result_row)

func _build_party() -> void:
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 6)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)

func _build_options() -> void:
	options_panel = EclipseUI.panel(self, 0.96)
	options_panel.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	options_panel.add_child(column)
	EclipseUI.caption(column, "Opciones")
	_plain_button(column, "Registro del combate", func() -> void:
		toggle_options()
		toggle_log())
	_plain_button(column, "Reintentar" if encounter_mode else "Reiniciar combate", func() -> void:
		toggle_options()
		_restart())
	_return_button = _plain_button(column, "Volver al claro" if encounter_mode else "Nueva partida", _return_or_new)
	camera_option = CheckButton.new()
	camera_option.text = "Cámara suave"
	camera_option.button_pressed = true
	camera_option.custom_minimum_size.y = EclipseUI.TOUCH
	camera_option.toggled.connect(func(value: bool) -> void: camera_toggled.emit(value))
	column.add_child(camera_option)
	skip_option = CheckButton.new()
	skip_option.text = "Omitir animaciones"
	skip_option.custom_minimum_size.y = EclipseUI.TOUCH
	skip_option.toggled.connect(func(value: bool) -> void: skip_toggled.emit(value))
	column.add_child(skip_option)
	_plain_button(column, "Cerrar", toggle_options, "back")

func _build_log() -> void:
	log_panel = EclipseUI.panel(self, 0.97)
	log_panel.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	log_panel.add_child(column)
	EclipseUI.label(column, "Registro del combate", 22, EclipseUI.GOLD_BRIGHT, "title")
	log_view = RichTextLabel.new()
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.scroll_following = true
	log_view.focus_mode = Control.FOCUS_ALL
	column.add_child(log_view)
	_log_empty = EclipseUI.label(column, "Todavía no hay acciones en este combate.", 16, EclipseUI.MUTED)
	_plain_button(column, "Cerrar registro", toggle_log, "back")

func _plain_button(container: Container, text: String, callback: Callable, icon: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(COMMAND_WIDTH, EclipseUI.TOUCH)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	if not icon.is_empty():
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(button)
	return button

func _return_or_new() -> void:
	options_panel.visible = false
	if encounter_mode:
		return_to_zone_requested.emit()
	else:
		_new_party()

# --- layout -----------------------------------------------------------------

func _layout() -> void:
	if not is_inside_tree():
		return
	_margins = EclipseUI.safe_margins(get_viewport())
	var m: Dictionary = _margins
	turn_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	turn_panel.position = Vector2(m.left, m.top)
	var top_right := get_node("TopRight") as Control
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right.reset_size()
	top_right.position = Vector2(size.x - m.right - top_right.get_combined_minimum_size().x, m.top)
	command_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	command_panel.reset_size()
	command_panel.position = Vector2(m.left, size.y - m.bottom - command_panel.get_combined_minimum_size().y)
	_cards.reset_size()
	var cards_size := _cards.get_combined_minimum_size()
	_cards.size = cards_size
	_cards.position = Vector2(size.x - m.right - cards_size.x, size.y - m.bottom - cards_size.y)
	options_panel.reset_size()
	var options_size := options_panel.get_combined_minimum_size()
	options_panel.position = Vector2(size.x - m.right - options_size.x, m.top + EclipseUI.TOUCH + PANEL_GAP)
	var log_width := minf(760.0, size.x - m.left - m.right)
	log_panel.position = Vector2((size.x - log_width) * 0.5, m.top + 8)
	log_panel.size = Vector2(log_width, size.y - m.top - m.bottom - 16)

func _relayout() -> void:
	# Containers settle their minimum size during the next frame.
	_layout.call_deferred()

# --- refresh ----------------------------------------------------------------

func toggle_log() -> void:
	log_panel.visible = not log_panel.visible
	if log_panel.visible:
		_log_empty.visible = engine.history.is_empty()
		options_panel.visible = false
		log_view.grab_focus()
	else:
		_focus_first()

func toggle_options() -> void:
	options_panel.visible = not options_panel.visible
	if options_panel.visible:
		_layout()
		options_panel.get_child(0).get_child(1).grab_focus()
	else:
		menu_button.grab_focus()

func _restart() -> void:
	if _menu_tween != null:
		_menu_tween.kill()
	if log_panel != null:
		log_panel.visible = false
	if options_panel != null:
		options_panel.visible = false
	_last_actor = -2
	super._restart()
	battle_reset.emit()

func _instant() -> bool:
	return skip_option != null and skip_option.button_pressed

func _refresh() -> void:
	super._refresh()
	var ended := engine.phase in [BattleEngine.Phase.VICTORY, BattleEngine.Phase.DEFEAT]
	var actor_id := presentation_actor_id if presentation_busy else engine.current_id()
	var actor: BattleEngine.Fighter = engine.fighters[actor_id] if actor_id >= 0 and actor_id < engine.fighters.size() else null
	# Turn banner: who acts, round and the remaining order of this round.
	round_label.text = "Ronda %d" % engine.round_number
	if ended:
		status.text = "¡Victoria!" if engine.phase == BattleEngine.Phase.VICTORY else "Derrota"
	elif actor != null:
		status.text = ("Turno de " if not actor.enemy else "Turno: ") + actor.data.label
	_refresh_order()
	if actor != null:
		_set_emblem(_turn_emblem, actor)
	# Resonance and guardian bond.
	var full := run.resonance >= 100
	resonance_value.text = str(run.resonance)
	EclipseUI.tween_to(self, resonance_bar, "value", float(run.resonance), 0.3, _instant())
	guardian_info.text = ""
	for fighter in engine.fighters:
		var guardian := run.guardian_for(fighter.data.id) if not fighter.enemy else null
		if guardian != null:
			var short_name := guardian.label.get_slice(" —", 0).get_slice(" -", 0)
			guardian_info.text = ("%s listo para %s" if full else "%s · vínculo con %s") % [short_name, fighter.data.label]
			guardian_info.text += " · Nv %d" % run.guardian_level(fighter.data.id)
			guardian_info.tooltip_text = "%s · %d PA" % [guardian.label, run.progress(guardian.id).affinity]
	guardian_info.add_theme_color_override("font_color", EclipseUI.GOLD_BRIGHT if full else EclipseUI.IVORY_DIM)
	guardian_info.mouse_filter = Control.MOUSE_FILTER_PASS
	_set_resonance_glow(full)
	_refresh_cards()
	# Command window.
	actions.visible = selected == null and not ended
	targets.visible = selected != null
	_cancel.visible = selected != null
	result_row.visible = ended
	if ended:
		_build_result()
	elif selected != null:
		command_title.text = selected.label
	elif actor != null:
		command_title.text = actor.data.label if not actor.enemy else actor.data.label
		if actor.enemy:
			message.text = "El enemigo prepara su acción."
		elif message.text == "Elige una acción y después un objetivo.":
			message.text = "Elige una acción."
	_decorate_actions(actor)
	if actor_id != _last_actor and not ended:
		_last_actor = actor_id
		_slide_in(command_panel)
	set_presentation_busy(presentation_busy)
	if encounter_mode and _return_button != null:
		_return_button.disabled = presentation_busy or engine.phase != BattleEngine.Phase.DEFEAT
	_relayout()
	if not presentation_busy and not log_panel.visible and not options_panel.visible:
		_focus_first.call_deferred()
	updated.emit()

func _refresh_order() -> void:
	for child in order_row.get_children():
		order_row.remove_child(child)
		child.queue_free()
	if engine.phase in [BattleEngine.Phase.VICTORY, BattleEngine.Phase.DEFEAT]:
		return
	var shown := 0
	for i in range(engine.cursor, engine.order.size()):
		var fighter := engine.fighters[engine.order[i]]
		if fighter.hp <= 0 or shown >= 4:
			continue
		if shown > 0:
			EclipseUI.label(order_row, "›", 14, EclipseUI.MUTED)
		var color: Color = EclipseUI.ENEMY if fighter.enemy else Color(EclipseUI.HERO_COLORS.get(fighter.data.id, EclipseUI.IVORY))
		var chip := EclipseUI.label(order_row, fighter.data.label.split(" ")[0], 14, color if shown > 0 else EclipseUI.GOLD_BRIGHT, "medium" if shown > 0 else "bold")
		chip.tooltip_text = "Orden de esta ronda"
		shown += 1

func _set_emblem(holder: PanelContainer, fighter: BattleEngine.Fighter) -> void:
	var initial := holder.get_node("Initial") as Label
	initial.text = fighter.data.label.substr(0, 1)
	var box := (holder.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	var color: Color = EclipseUI.ENEMY if fighter.enemy else Color(EclipseUI.HERO_COLORS.get(fighter.data.id, EclipseUI.GOLD))
	box.border_color = color
	box.bg_color = color.darkened(0.55)
	holder.add_theme_stylebox_override("panel", box)
	var picture := holder.get_node("Portrait") as TextureRect
	var portrait: Texture2D = null if fighter.enemy else Portraits.cached(fighter.data.id)
	picture.visible = portrait != null
	picture.texture = portrait
	initial.visible = portrait == null

func _set_resonance_glow(full: bool) -> void:
	var box := EclipseUI.panel_box(0.88, EclipseUI.RESONANCE if full else Color(EclipseUI.GOLD, 0.55))
	if full:
		box.set_border_width_all(2)
		box.shadow_color = Color(EclipseUI.RESONANCE, 0.45)
		box.shadow_size = 10
	_resonance_panel.add_theme_stylebox_override("panel", box)
	if full and _resonance_glow == null and not _instant():
		# Gentle pulse only while an invocation is available.
		_resonance_glow = create_tween().set_loops()
		_resonance_glow.tween_property(_resonance_panel, "self_modulate", Color(1.15, 1.08, 0.95), 0.7)
		_resonance_glow.tween_property(_resonance_panel, "self_modulate", Color.WHITE, 0.7)
	elif not full and _resonance_glow != null:
		_resonance_glow.kill()
		_resonance_glow = null
		_resonance_panel.self_modulate = Color.WHITE

# --- party cards --------------------------------------------------------------

func _refresh_cards() -> void:
	var heroes: Array[int] = []
	for i in engine.fighters.size():
		if not engine.fighters[i].enemy:
			heroes.append(i)
	if party_cards.size() != heroes.size():
		_build_cards(heroes)
	var active_id := presentation_actor_id if presentation_busy else engine.current_id()
	for slot in heroes.size():
		var fighter := engine.fighters[heroes[slot]]
		var parts: Dictionary = _card_parts[slot]
		var active: bool = heroes[slot] == active_id and fighter.hp > 0 and not engine.phase in [BattleEngine.Phase.VICTORY, BattleEngine.Phase.DEFEAT]
		var card := party_cards[slot]
		var box := EclipseUI.panel_box(0.9 if active else 0.82, EclipseUI.GOLD_BRIGHT if active else Color(EclipseUI.GOLD, 0.3), 10)
		box.set_content_margin_all(8)
		if active:
			box.bg_color = Color(EclipseUI.PETROL, 0.95)
			box.set_border_width_all(2)
		card.add_theme_stylebox_override("panel", box)
		card.modulate = Color(1, 1, 1, 0.6) if fighter.hp == 0 else Color.WHITE
		(parts.name as Label).text = fighter.data.label
		(parts.name as Label).add_theme_color_override("font_color", EclipseUI.GOLD_BRIGHT if active else EclipseUI.IVORY)
		(parts.marker as Control).visible = active
		var hp_bar := parts.hp as ProgressBar
		hp_bar.max_value = fighter.data.max_hp
		EclipseUI.set_bar_color(hp_bar, EclipseUI.hp_color(fighter.hp, fighter.data.max_hp))
		EclipseUI.tween_to(self, hp_bar, "value", float(fighter.hp), 0.3, _instant())
		(parts.hp_value as Label).text = "%d/%d" % [fighter.hp, fighter.data.max_hp]
		(parts.hp_value as Label).add_theme_color_override("font_color", EclipseUI.hp_color(fighter.hp, fighter.data.max_hp) if fighter.hp * 4 <= fighter.data.max_hp else EclipseUI.IVORY)
		var mp_bar := parts.mp as ProgressBar
		mp_bar.max_value = maxi(1, fighter.data.max_mp)
		EclipseUI.tween_to(self, mp_bar, "value", float(fighter.mp), 0.3, _instant())
		(parts.mp_value as Label).text = "%d/%d" % [fighter.mp, fighter.data.max_mp]
		_set_emblem(parts.emblem, fighter)
		var chips := parts.chips as HBoxContainer
		for child in chips.get_children():
			chips.remove_child(child)
			child.queue_free()
		for chip: Array in _states(fighter):
			_chip(chips, chip[0], chip[1], chip[2])

## Existing engine state shown as short chips (read only, no new statuses).
func _states(fighter: BattleEngine.Fighter) -> Array:
	var result := []
	if fighter.hp == 0:
		return [["KO", EclipseUI.HP_CRITICAL, "Inconsciente"]]
	if fighter.guarding:
		result.append(["Defensa", Color("b8c6c9"), "Recibe menos daño hasta su próximo turno"])
	if fighter.protection_target >= 0:
		result.append(["Protege", EclipseUI.ALLY, "Intercepta el próximo ataque a %s" % engine.fighters[fighter.protection_target].data.label])
	if fighter.haste_rounds > 0:
		result.append(["Impulso", Color("8fd3a0"), "+5 VEL (%d rondas)" % fighter.haste_rounds])
	if fighter.defense_down_rounds > 0:
		result.append(["DEF ↓", EclipseUI.ENEMY, "Defensa reducida (%d rondas)" % fighter.defense_down_rounds])
	if run.guardian_for(fighter.data.id) != null:
		result.append(["Ignar", EclipseUI.RESONANCE, "Guardián vinculado"])
	return result

func _chip(parent: Node, text: String, color: Color, hint: String) -> void:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color, 0.18)
	box.border_color = Color(color, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	chip.add_theme_stylebox_override("panel", box)
	chip.tooltip_text = hint
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(chip)
	EclipseUI.label(chip, text, 12, color.lightened(0.25), "bold")

func _build_cards(heroes: Array[int]) -> void:
	for card in party_cards:
		card.queue_free()
	party_cards.clear()
	_card_parts.clear()
	for id in heroes:
		var fighter := engine.fighters[id]
		var card := EclipseUI.panel(_cards, 0.82)
		card.custom_minimum_size.x = 318
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		party_cards.append(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var marker := UIIcon.make(row, "next", EclipseUI.GOLD_BRIGHT, 12)
		marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var emblem := EclipseUI.emblem(row, fighter.data.id, fighter.data.label, 46)
		emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 1)
		row.add_child(column)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		column.add_child(head)
		var name_label := EclipseUI.label(head, fighter.data.label, 17, EclipseUI.IVORY, "bold")
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 4)
		chips.alignment = BoxContainer.ALIGNMENT_END
		chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(chips)
		var hp_row := HBoxContainer.new()
		hp_row.add_theme_constant_override("separation", 6)
		column.add_child(hp_row)
		var hp_tag := EclipseUI.label(hp_row, "PV", 12, EclipseUI.MUTED, "bold")
		hp_tag.custom_minimum_size.x = 20
		var hp_bar := EclipseUI.bar(hp_row, EclipseUI.HP, 9)
		hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var hp_value := EclipseUI.label(hp_row, "", 15, EclipseUI.IVORY, "bold")
		hp_value.custom_minimum_size.x = 62
		hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var mp_row := HBoxContainer.new()
		mp_row.add_theme_constant_override("separation", 6)
		column.add_child(mp_row)
		var mp_tag := EclipseUI.label(mp_row, "PM", 12, EclipseUI.MUTED, "bold")
		mp_tag.custom_minimum_size.x = 20
		var mp_bar := EclipseUI.bar(mp_row, EclipseUI.MP, 6)
		mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var mp_value := EclipseUI.label(mp_row, "", 14, Color("b9d4ee"), "medium")
		mp_value.custom_minimum_size.x = 62
		mp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_card_parts.append({"name": name_label, "marker": marker, "emblem": emblem, "chips": chips, "hp": hp_bar, "hp_value": hp_value, "mp": mp_bar, "mp_value": mp_value})
		_load_portrait(fighter)

func _load_portrait(fighter: BattleEngine.Fighter) -> void:
	if Portraits.cached(fighter.data.id) != null:
		return
	var texture := await Portraits.request(self, fighter.data.id, fighter.data)
	if texture != null and is_inside_tree():
		_refresh_cards()
		_set_emblem(_turn_emblem, engine.fighters[maxi(0, engine.current_id())])

# --- commands -------------------------------------------------------------------

## Presentation category of an existing ability (no new mechanics).
static func category(ability: BattleAbility, basic: bool) -> String:
	if basic:
		return "attack"
	match ability.effect:
		"guard":
			return "guard"
		"magic":
			return "magic"
		"heal", "haste":
			return "support"
	return "technique"

func _command_button(container: Container, glyph: String, glyph_color: Color, title: String, detail: String, cost: String, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(COMMAND_WIDTH, 52)
	button.pressed.connect(callback)
	container.add_child(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var icon := UIIcon.make(row, glyph, glyph_color, 20)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_label := EclipseUI.label(column, title, 17, EclipseUI.IVORY, "bold")
	name_label.name = "Title"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var detail_label := EclipseUI.label(column, detail, 13, EclipseUI.IVORY_DIM)
	detail_label.name = "Detail"
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.visible = not detail.is_empty()
	if not cost.is_empty():
		var cost_label := EclipseUI.label(row, cost, 14, Color("b9d4ee"), "bold")
		cost_label.name = "Cost"
		cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.tooltip_text = title + ("" if detail.is_empty() else " · " + detail)
	# Plain text keeps accessibility/search working; the visible label draws it.
	button.set_meta("title", title)
	return button

func _add_action(ability: BattleAbility, actor: BattleEngine.Fighter, callback: Callable) -> Button:
	var kind := category(ability, ability == engine.basic_attack() or ability.label == engine.basic_attack().label)
	var info: Dictionary = EclipseUI.CATEGORY[kind]
	var detail: String = {"attack": "Golpe físico", "guard": "Menos daño recibido"}.get(kind, info.name)
	if ELEMENT_DETAIL.has(ability.element):
		detail += " · " + ELEMENT_DETAIL[ability.element]
	var button := _command_button(actions, kind, info.color, ability.label, detail, ("%d PM" % ability.cost) if ability.cost > 0 else "", callback)
	button.set_meta("cost", ability.cost)
	button.set_meta("mp", actor.mp)
	return button

const ELEMENT_DETAIL := {"fire": "Fuego", "ice": "Hielo"}

func _add_invoke(guardian: GuardianData, callback: Callable) -> Button:
	var button := _command_button(actions, "guardian", EclipseUI.RESONANCE, "Invocar a " + guardian.label.get_slice(" —", 0), guardian.summon_label, "100 RE", callback)
	var glow := EclipseUI.button_box(Color(EclipseUI.RESONANCE, 0.22), EclipseUI.RESONANCE)
	button.add_theme_stylebox_override("normal", glow)
	button.custom_minimum_size.x = COMMAND_WIDTH * 2 + 8
	return button

func _add_enemy_step(actor: BattleEngine.Fighter, callback: Callable) -> Button:
	var button := _command_button(actions, "next", EclipseUI.ENEMY, "Continuar", "Actúa " + actor.data.label, "", callback)
	button.custom_minimum_size.x = COMMAND_WIDTH * 2 + 8
	return button

func _add_target(target_id: int, callback: Callable) -> Button:
	var fighter := engine.fighters[target_id]
	var side := "Enemigo" if fighter.enemy else ("Tú" if target_id == engine.current_id() else "Aliado")
	var button := _command_button(targets, "attack" if fighter.enemy else "support", EclipseUI.ENEMY if fighter.enemy else EclipseUI.ALLY,
		fighter.data.label, "%s · PV %d/%d" % [side, fighter.hp, fighter.data.max_hp], "", callback)
	var edge := EclipseUI.button_box(Color(EclipseUI.ENEMY if fighter.enemy else EclipseUI.ALLY, 0.14), Color(EclipseUI.ENEMY if fighter.enemy else EclipseUI.ALLY, 0.6))
	button.add_theme_stylebox_override("normal", edge)
	# Long names (enemies) take the full row; short hero names keep two columns.
	if fighter.data.label.length() > 12:
		button.custom_minimum_size.x = COMMAND_WIDTH * 2 + 8
	return button

## Disabled commands say why (only the existing MP rule disables them).
func _decorate_actions(actor: BattleEngine.Fighter) -> void:
	for button: Button in actions.get_children():
		var detail := button.get_node_or_null("HBoxContainer/VBoxContainer/Detail") as Label
		if detail == null:
			for child in button.find_children("Detail", "Label", true, false):
				detail = child
		button.modulate = Color(1, 1, 1, 0.5) if button.disabled else Color.WHITE
		if button.disabled and detail != null and button.has_meta("cost") and actor != null:
			detail.text = "Faltan PM (%d/%d)" % [actor.mp, int(button.get_meta("cost"))]
			detail.add_theme_color_override("font_color", EclipseUI.HP_LOW)
			detail.visible = true
			button.tooltip_text = "%s: PM insuficientes" % button.get_meta("title")

func _build_result() -> void:
	for child in result_row.get_children():
		result_row.remove_child(child)
		child.queue_free()
	var victory := engine.phase == BattleEngine.Phase.VICTORY
	command_title.text = "¡Victoria!" if victory else "Derrota"
	if message.text.is_empty():
		message.text = "El Centinela cae. Volviendo al claro…" if victory and encounter_mode else ("El grupo ha caído." if not victory else "Combate ganado.")
	_plain_button(result_row, "Reintentar" if encounter_mode else "Reiniciar", _restart)
	if encounter_mode:
		var back := _plain_button(result_row, "Volver al claro", _return_or_new)
		back.disabled = presentation_busy or victory
	else:
		_plain_button(result_row, "Nueva partida", _new_party)

func _choose(ability: BattleAbility) -> void:
	super._choose(ability)
	actions.visible = false
	targets.visible = true
	_cancel.visible = true
	command_title.text = ability.label
	var kind_text := {"enemy": "Elige un enemigo", "ally": "Elige un aliado", "self": "Se aplica a ti"}
	message.text = String(kind_text.get(ability.target_kind, "Elige objetivo")) + " · Esc o Atrás para cancelar"
	var ids := engine.valid_targets(ability)
	for i in range(ids.size()):
		var id := ids[i]
		var button := targets.get_child(i) as Button
		button.focus_entered.connect(func() -> void: target_preview.emit(id))
		button.mouse_entered.connect(func() -> void: target_preview.emit(id))
	targets_offered.emit(ids)
	if not ids.is_empty():
		target_preview.emit(ids[0])
		targets.get_child(0).grab_focus()
	if _menu_tween != null:
		_menu_tween.kill()
	targets.modulate.a = 0.5
	_menu_tween = EclipseUI.tween_to(self, targets, "modulate:a", 1.0, 0.12, _instant())
	_relayout()

func _cancel_selection() -> void:
	selected = null
	_clear(targets)
	message.text = ""
	_refresh()

func _slide_in(node: Control) -> void:
	if _instant():
		node.modulate.a = 1.0
		return
	if _menu_tween != null:
		_menu_tween.kill()
	node.modulate.a = 0.0
	_menu_tween = create_tween()
	_menu_tween.tween_property(node, "modulate:a", 1.0, 0.14)

func _focus_first() -> void:
	if presentation_busy or log_panel.visible or options_panel.visible:
		return
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner != null and is_ancestor_of(owner) and owner.is_visible_in_tree():
		return
	for container in [targets, actions, result_row]:
		if container.is_visible_in_tree():
			for button in container.get_children():
				if button is Button and not button.disabled:
					button.grab_focus()
					return

func set_presentation_busy(value: bool) -> void:
	presentation_busy = value
	if value:
		status.text = "Acción de %s" % presentation_actor
		message.text = "…"
	for container in [actions, targets]:
		for button in container.get_children():
			if value:
				button.disabled = true
	_cancel.disabled = value
	command_panel.modulate = Color(1, 1, 1, 0.55) if value else Color.WHITE

func unlock_actions() -> void:
	presentation_busy = false
	presentation_actor = ""
	presentation_actor_id = -1
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if log_panel.visible:
			toggle_log()
		elif options_panel.visible:
			toggle_options()
		elif selected != null and not presentation_busy:
			_cancel_selection()
		else:
			return
		get_viewport().set_input_as_handled()
