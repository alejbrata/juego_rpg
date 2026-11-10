extends RefCounted
## Iteration 1.5: battle and exploration interface. Presentation only: every check
## compares the interface with the state already resolved by the engine/session.

const SIZES := [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(960, 540)]
var _tree: SceneTree
var _verify: Callable

func check(condition: bool, description: String) -> void:
	_verify.call(condition, "Interfaz 1.5: " + description)

func snapshot(engine: BattleEngine) -> Dictionary:
	return preload("res://tests/guardian_checks.gd").new().snapshot(engine)

func buttons(node: Node, result: Array[BaseButton]) -> void:
	for child in node.get_children():
		if child is BaseButton and child.is_visible_in_tree():
			result.append(child)
		buttons(child, result)

func titles(container: Container) -> Array[String]:
	var result: Array[String] = []
	for button in container.get_children():
		result.append(String(button.get_meta("title", button.text)))
	return result

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_verify = verify
	await battle()
	await enemy_turn()
	await layouts()
	await exploration()

func battle() -> void:
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	_tree.root.add_child(stage)
	await _tree.process_frame
	var ui = stage.hud
	stage.set_skip_animations(true)
	var engine: BattleEngine = ui.engine
	# Commands: same actions as the engine offers, player-facing categories, costs.
	check(titles(ui.actions) == ["Ataque", "Defender", "Llama", "Escarcha"], "comandos de Lyra en el orden del motor")
	var technical := false
	var labels: Array[String] = []
	for label: Label in ui.actions.find_children("*", "Label", true, false):
		labels.append(label.text)
		technical = technical or label.text.contains("[") or label.text.contains("physical") or label.text.contains("fire")
	check(not technical and labels.has("Magia · Fuego") and labels.has("Magia · Hielo") and labels.has("8 PM") and labels.has("7 PM"), "categorías y costes legibles sin etiquetas técnicas")
	check(ui.status.text == "Turno de Lyra" and ui.round_label.text == "Ronda 1" and ui.order_row.get_child_count() >= 7, "cabecera con personaje activo, ronda y orden del turno")
	var active_card: PanelContainer = ui.party_cards[1]
	check((active_card.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left == 2 and ui._card_parts[1].marker.visible and not ui._card_parts[0].marker.visible, "tarjeta de Lyra resaltada como activa")
	# Availability follows the engine's MP rule and says why.
	engine.fighters[1].mp = 7
	ui._refresh()
	var flame: Button = ui.actions.get_child(2)
	var reason := flame.find_children("Detail", "Label", true, false)[0] as Label
	check(flame.disabled and not ui.actions.get_child(3).disabled and reason.text.contains("Faltan PM") and flame.modulate.a < 1.0, "acción sin PM deshabilitada con motivo visible")
	engine.fighters[1].mp = 35
	ui._refresh()
	# Targets: only the engine's valid targets, side marked, cancel keeps the turn.
	var before := snapshot(engine)
	ui.actions.get_child(2).pressed.emit()
	check(ui.targets.visible and not ui.actions.visible and ui._cancel.visible and titles(ui.targets) == ["Centinela de piedra"], "habilidad abre solo los objetivos válidos")
	check(stage._target_marker.visible and stage._target_hints.get_child_count() == 1 and stage._target_marker.material_override == stage._marker_materials[true], "objetivo enemigo marcado con aro discreto del bando enemigo")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	ui._unhandled_input(cancel)
	check(snapshot(engine) == before and ui.actions.visible and not ui.targets.visible and not stage._target_marker.visible and stage._target_hints.get_child_count() == 0, "Esc cancela la selección sin gastar turno, PM ni RE")
	# Turn change: Lyra attacks, Kael becomes active; HP/MP shown from the engine.
	ui.actions.get_child(2).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	stage.skip_presentation()
	check(ui.status.text == "Turno de Kael" and ui._card_parts[0].marker.visible and ui._card_parts[1].mp_value.text == "%d/35" % engine.fighters[1].mp, "cambio de turno y PM actualizados desde el motor")
	ui.actions.get_child(3).pressed.emit()
	check(titles(ui.targets) == ["Kael", "Lyra", "Nira"] and stage._target_marker.material_override == stage._marker_materials[false] and stage._target_hints.get_child_count() == 3, "Protección ofrece los tres aliados con marca aliada")
	ui._cancel_selection()
	engine.fighters[0].hp = 20
	engine.fighters[2].haste_rounds = 2
	engine.fighters[0].guarding = true
	ui._refresh()
	var kael_chips: Array[String] = []
	for label: Label in ui._card_parts[0].chips.find_children("*", "Label", true, false):
		kael_chips.append(label.text)
	var nira_chips: Array[String] = []
	for label: Label in ui._card_parts[2].chips.find_children("*", "Label", true, false):
		nira_chips.append(label.text)
	check(ui._card_parts[0].hp_value.text == "20/120" and (ui._card_parts[0].hp.get_theme_stylebox("fill") as StyleBoxFlat).bg_color == EclipseUI.HP_CRITICAL and kael_chips.has("Defensa") and nira_chips.has("Impulso"), "PV bajos en color crítico y estados existentes como fichas")
	# Resonance and the guardian.
	ui.run.resonance = 100
	ui._refresh()
	check(ui.resonance_value.text == "100" and titles(ui.actions).size() == 4, "RE llena no ofrece invocar a quien no porta a Ignar")
	ui._restart()
	ui.run.resonance = 100
	ui._refresh()
	var invoke: Button = ui.actions.get_child(4)
	check(String(invoke.get_meta("title")) == "Invocar a Ignar" and invoke.custom_minimum_size.x > ui.COMMAND_WIDTH and ui.guardian_info.text.contains("listo") and (ui._resonance_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color == EclipseUI.RESONANCE, "RE al 100 % resalta la invocación del portador")
	invoke.pressed.emit()
	stage.skip_presentation()
	check(ui.run.resonance == 0 and ui.resonance_value.text == "0" and ui._resonance_glow == null and ui.guardian_info.text.contains("vínculo con Lyra"), "invocar gasta la RE del motor y apaga el aviso")
	# Restart and result.
	ui._restart()
	check(engine.history.is_empty() and ui.status.text == "Turno de Lyra" and not ui.options_panel.visible and not ui.log_panel.visible, "reinicio limpia menús y vuelve al primer turno")
	ui.toggle_options()
	check(ui.options_panel.visible and ui.camera_option.is_visible_in_tree() and ui.skip_option.is_visible_in_tree() and ui._return_button.is_visible_in_tree(), "opciones (registro, cámara, omitir, reinicio) accesibles en el menú")
	ui.toggle_options()
	engine.fighters[3].hp = 1
	ui.actions.get_child(0).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	stage.skip_presentation()
	check(engine.phase == BattleEngine.Phase.VICTORY and ui.status.text == "¡Victoria!" and ui.result_row.visible and not ui.actions.visible, "resultado del combate con acciones de cierre")
	stage.free()

## Enemy turns resolve by themselves (no "continue" tap), paused while a menu is open.
func enemy_turn() -> void:
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	_tree.root.add_child(stage)
	await _tree.process_frame
	var ui = stage.hud
	stage.set_skip_animations(true)
	var engine: BattleEngine = ui.engine
	for turn in 6:
		if engine.phase != BattleEngine.Phase.WAITING_PLAYER:
			break
		ui.actions.get_child(1).pressed.emit()   # Defender
		if ui.targets.visible:
			ui.targets.get_child(0).pressed.emit()
		stage.skip_presentation()
	var enemy_id: int = engine.current_id()
	var reached: bool = engine.phase == BattleEngine.Phase.ENEMY_TURN and ui.actions.get_child_count() == 1
	var before: int = engine.history.size()
	ui.toggle_options()
	for i in 40:
		await _tree.physics_frame
	var paused: bool = engine.phase == BattleEngine.Phase.ENEMY_TURN and engine.current_id() == enemy_id and engine.history.size() == before
	ui.toggle_options()
	var waited := 0
	while engine.history.size() == before and waited < 300:
		await _tree.physics_frame
		waited += 1
	for i in 3:
		stage.skip_presentation()
		await _tree.process_frame
	check(reached and paused and engine.history.size() > before and (engine.phase != BattleEngine.Phase.ENEMY_TURN or engine.current_id() != enemy_id), "turno enemigo resuelto solo tras una pausa, sin pulsar nada y detenido con el menú abierto")
	stage.free()

func layouts() -> void:
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	_tree.root.add_child(stage)
	await _tree.process_frame
	var ui = stage.hud
	var original := _tree.root.size
	for size: Vector2i in SIZES:
		_tree.root.size = size
		for state in ["commands", "targets", "resonance"]:
			ui._restart()
			if state == "targets":
				ui._choose(ui.engine.fighters[1].data.abilities[0])
			elif state == "resonance":
				ui.run.resonance = 100
				ui._refresh()
			await _tree.process_frame
			await _tree.process_frame
			var area := Rect2(Vector2.ZERO, ui.size)
			var controls: Array[BaseButton] = []
			buttons(ui, controls)
			var inside := true
			var touch := true
			for button in controls:
				inside = inside and area.encloses(button.get_global_rect().grow(-0.5))
				touch = touch and button.size.y >= 47.5 and button.size.x >= 47.5
			var panels: Array[Control] = [ui.turn_panel, ui.get_node("TopRight"), ui.command_panel, ui._cards]
			var apart := true
			for a in panels.size():
				inside = inside and area.encloses(panels[a].get_global_rect().grow(-0.5))
				for b in range(a + 1, panels.size()):
					apart = apart and not panels[a].get_global_rect().grow(-1).intersects(panels[b].get_global_rect().grow(-1))
			check(inside and touch and apart, "%dx%d (%s): controles dentro, táctiles y paneles sin solaparse" % [size.x, size.y, state])
		ui.run.resonance = 0
	_tree.root.size = original
	await _tree.process_frame
	stage.free()

func exploration() -> void:
	var zone = preload("res://scenes/forest_zone.tscn").instantiate()
	_tree.root.add_child(zone)
	await _tree.process_frame
	var dialogue: DialogueBox = zone.dialogue
	check(dialogue.active and dialogue.speaker_label.text == "Kael" and dialogue._plate.visible and dialogue.title_label.uppercase and dialogue.title_label.text == "El Bosque del Eclipse", "diálogo con placa de hablante y título original")
	check(dialogue.advance_button.size.y >= 48 and dialogue.skip_button.visible and not zone._menu_button.visible, "diálogo con botones táctiles y sin menú superpuesto")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	dialogue._input(key)
	check(dialogue.index == 1, "Espacio avanza una línea")
	dialogue.skip()
	await _tree.process_frame
	check(not dialogue.active and zone._menu_button.visible and not zone._menu_panel.visible and zone._objective_box.visible and zone.objective_label.text == zone.session.mission.objective(zone.session.defeated_encounters), "exploración muestra solo lugar, objetivo y menú")
	check(not zone.info.is_visible_in_tree() and zone.info.text.contains("RE 0/100") and zone.info.text.contains("Ignar"), "datos del grupo guardados en el menú, no permanentes")
	zone.toggle_menu()
	check(zone._menu_panel.visible and zone.info.is_visible_in_tree() and zone._restart_button.is_visible_in_tree(), "menú muestra grupo, controles y Nueva partida")
	zone.toggle_menu()
	zone.player.position = zone.interests.camp.position + Vector3(0.9, 0, 0.6)
	for i in 3:
		await _tree.physics_frame
	await _tree.process_frame
	check(zone.interact_button.visible and zone.interact_button.text.begins_with("Examinar") and zone.interact_button.size.y >= 48, "aviso de interacción breve y táctil")
	zone.free()
