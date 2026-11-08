extends RefCounted

var _tree: SceneTree
var _verify: Callable

func check(condition: bool, description: String) -> void:
	_verify.call(condition, description)

func finish_dialogue(zone: Node3D) -> void:
	var remaining := 30
	while zone.dialogue.active and remaining > 0:
		remaining -= 1
		zone.dialogue.advance_button.pressed.emit()
	check(remaining > 0 and not zone.dialogue.active, "Conversación termina mediante su control de avance")

func examine(zone: Node3D, id: String) -> void:
	zone.player.position = zone.interests[id].position + Vector3(0, 0.05, 0.9)
	check(zone.interact(id), "Interacción cercana con %s aceptada" % id)
	finish_dialogue(zone)

func test_mission() -> void:
	for order in [["camp", "crystal", "inscription"], ["crystal", "inscription", "camp"], ["inscription", "camp", "crystal"], ["camp", "inscription", "crystal"], ["inscription", "crystal", "camp"], ["crystal", "camp", "inscription"]]:
		var mission := ExpeditionMission.new()
		mission.intro_seen = true
		check(mission.objective([]) == "Investiga el claro", "Objetivo inicial sin secuencia de pistas impuesta")
		for id in order:
			check(mission.investigate(id) and not mission.investigate(id), "Pista se registra una sola vez: %s" % id)
		check(mission.all_clues() and not mission.revelation_available([]), "Tres pistas sin victorias no bastan para revelar")
		var victories: Array[String] = ["clearing_sentinel_b", "clearing_sentinel_a"]
		check(mission.revelation_available(victories) and mission.objective(victories).contains("anomalía"), "Pistas en cualquier orden y dos victorias habilitan anomalía")
		check(mission.begin_revelation(victories) and not mission.begin_revelation(victories), "Revelación se reclama una sola vez")
		check(mission.finish_revelation() and not mission.finish_revelation(), "Completar misión es idempotente")
	var mission := ExpeditionMission.new()
	var victories: Array[String] = ExpeditionMission.SENTINELS.duplicate()
	check(not mission.finish_revelation() and not mission.investigate("unknown"), "No hay cierre prematuro ni pistas desconocidas")
	mission.intro_seen = true
	check(not mission.revelation_available(victories), "Combatir antes de investigar no salta las pistas")
	for id in ExpeditionMission.CLUES:
		mission.investigate(id)
	check(mission.revelation_available(victories), "Investigar después de combatir también permite completar")

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_verify = verify
	test_mission()
	var helper = preload("res://tests/exploration_checks.gd").new()
	helper._tree = tree
	var game = preload("res://scenes/forest_exploration.tscn").instantiate()
	_tree.root.add_child(game)
	await helper.physics_frames(6)
	var zone = game.zone
	var closed: Array[String] = []
	zone.dialogue.conversation_closed.connect(func(id: String) -> void: closed.append(id))
	check(zone.dialogue.active and zone.dialogue.title_label.text == "El Bosque del Eclipse", "Nueva partida abre título e introducción")
	check(not zone.player.movement_enabled and not zone.encounter_armed and not game.session.mission.intro_seen, "Introducción bloquea movimiento y encuentros")
	var position: Vector3 = zone.player.position
	Input.action_press("ui_right")
	await helper.physics_frames(5)
	Input.action_release("ui_right")
	check(Vector2(zone.player.position.x - position.x, zone.player.position.z - position.z).length() < 0.01, "Teclado no mueve al personaje con diálogo abierto")
	check(not zone.dialogue.open("duplicate", "Duplicado", ExpeditionStory.lines("camp")) and zone.dialogue.index == 0, "No se abren conversaciones simultáneas")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await _tree.process_frame
	key = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = false
	Input.parse_input_event(key)
	await _tree.process_frame
	check(zone.dialogue.index == 1, "Pulsación real de Espacio avanza exactamente una intervención")
	key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	key.echo = true
	zone.dialogue._input(key)
	check(zone.dialogue.index == 1, "Repetición de tecla no salta intervenciones")
	finish_dialogue(zone)
	check(game.session.mission.intro_seen and zone.player.movement_enabled and zone.encounter_armed, "Cierre de introducción restaura control")
	check(zone.objective_label.text.contains("Investiga el claro") and closed == ["intro"], "Objetivo inicial y cierre único registrados")
	zone.dialogue.advance()
	zone.dialogue.skip()
	check(closed.size() == 1, "Avanzar diálogo cerrado no duplica eventos")
	var malformed: Array[Dictionary] = [{"speaker": "Kael"}]
	check(not zone.dialogue.open("bad", "Error", malformed), "Diálogo sin texto se rechaza")
	var empty: Array[Dictionary] = []
	check(not zone.dialogue.open("empty", "Vacío", empty), "Diálogo vacío se rechaza")
	check(not zone.interact("camp") and not zone.interact("missing"), "Interacción lejana o inexistente se rechaza")
	check(not zone.interact("anomaly") and not zone.interests.anomaly.available, "Anomalía no se activa antes de cumplir requisitos")
	# UI bounds and the longest narrative line, including a small landscape view.
	var original_size := _tree.root.size
	var longest := ""
	for sequence in ExpeditionStory.CONVERSATIONS.values():
		for line in sequence:
			if line.text.length() > longest.length():
				longest = line.text
	for size in [Vector2i(960, 640), Vector2i(1280, 720), Vector2i(800, 450)]:
		_tree.root.size = size
		zone.player.position = zone.interests.crystal.position + Vector3.UP * 0.05
		check(zone.interact("crystal"), "Diálogo se abre en %dx%d" % [size.x, size.y])
		zone.dialogue.text_label.text = longest # Layout stress; no content/progress mutation.
		await _tree.process_frame
		await _tree.process_frame
		var box: DialogueBox = zone.dialogue
		check(Rect2(Vector2.ZERO, box.size).encloses(box.panel.get_global_rect().grow(-0.5)) and box.panel.get_global_rect().encloses(box.advance_button.get_global_rect()), "Ventana y botón de diálogo permanecen dentro de pantalla")
		check(box.text_label.size.y >= box.text_label.get_minimum_size().y and box.advance_button.size.y >= 48, "Texto cabe y el botón conserva altura lógica accesible")
		check(not zone.player.movement_enabled and not zone.interact("crystal"), "Diálogo no se duplica durante cambios de resolución")
		finish_dialogue(zone)
	_tree.root.size = original_size
	await _tree.process_frame
	check(game.session.mission.investigated == ["crystal"] and game.session.party.resonance == 0 and game.session.party.progress("ignar").affinity == 0, "Revisitar cristal no duplica pista ni concede RE/PA")
	zone.player.position = zone.interests.camp.position + Vector3(0, 0.05, 0.9)
	await _tree.process_frame
	check(zone.interact_button.visible and zone.interests.camp.caption.visible, "Proximidad muestra señal y botón de interacción")
	key = InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	zone._unhandled_key_input(key)
	check(zone.dialogue.active and zone.dialogue.conversation_id == "camp", "E inicia interacción cercana sin avanzar el diálogo recién abierto")
	check(not zone.request_encounter(zone.encounters[0]), "Encuentros rechazados mientras se conversa")
	finish_dialogue(zone)
	game.session.party.resonance = 19
	var mission: ExpeditionMission = game.session.mission
	zone.player.position = zone.encounters[0].map_position + Vector3.UP * 0.05
	check(await helper.wait_for_battle(game), "Misión puede entrar en combate con pistas parciales")
	if not is_instance_valid(game.battle):
		game.free()
		return
	game.battle.set_skip_animations(true)
	check(game.session.mission == mission and mission.investigated.size() == 2 and game.battle.hud.run.resonance == 19, "Transición conserva pistas y RE")
	check(await helper.win_encounter(game), "Victoria real devuelve al claro durante la misión")
	if is_instance_valid(game.battle):
		game.free()
		return
	check(game.session.mission == mission and mission.investigated.size() == 2 and not game.zone.dialogue.active, "Retorno no borra pistas ni repite introducción")
	check(game.zone.objective_label.text.contains("pistas") and game.session.party.progress("ignar").affinity == 50, "Victoria mantiene objetivo pendiente y premio original")
	examine(game.zone, "inscription")
	check(mission.all_clues() and game.zone.objective_label.text.contains("Centinelas") and not mission.revelation_started, "Todas las pistas y una victoria aún requieren al segundo Centinela")
	game.zone.player.position = game.zone.encounters[1].map_position + Vector3.UP * 0.05
	check(await helper.wait_for_battle(game), "Segundo combate se integra con misión activa")
	if not is_instance_valid(game.battle):
		game.free()
		return
	game.battle.set_skip_animations(true)
	check(await helper.win_encounter(game), "Segunda victoria completa las condiciones de combate")
	if is_instance_valid(game.battle):
		game.free()
		return
	zone = game.zone
	check(zone.interests.anomaly.available and zone.objective_label.text.contains("anomalía") and not mission.completed, "Requisitos habilitan evento cerca de ruinas sin completarlo a distancia")
	check(not zone.interact("anomaly") and not mission.revelation_started, "Revelación no puede dispararse desde lejos")
	var re: int = game.session.party.resonance
	var affinity: int = game.session.party.progress("ignar").affinity
	zone.player.position = zone.interests.anomaly.position + Vector3(0, 0.05, 0.8)
	await _tree.process_frame
	zone.interact_button.pressed.emit()
	check(mission.revelation_started and not mission.completed and zone.dialogue.conversation_id == "anomaly", "Botón cercano inicia revelación una sola vez")
	check(not zone.interact("anomaly") and not zone.player.movement_enabled, "Revelación bloquea duplicados y movimiento")
	finish_dialogue(zone)
	check(mission.completed and zone.objective_label.text.contains("Completada") and zone.hint.text.contains("continuará"), "Cierre marca misión cumplida y anuncia continuación")
	check(game.session.party.resonance == re and game.session.party.progress("ignar").affinity == affinity and affinity == 100, "Final narrativo no añade recompensas ni cambia RE/PA")
	check(zone.interact("anomaly") and zone.dialogue.conversation_id == "anomaly_repeat", "Reexaminar anomalía usa texto breve y no repite final")
	finish_dialogue(zone)
	check(closed.count("anomaly") == 1 and not mission.begin_revelation(game.session.defeated_encounters), "Evento final permanece único tras revisitas")
	for id in ExpeditionMission.CLUES:
		examine(zone, id)
	check(mission.investigated.size() == 3 and game.session.party.progress("ignar").affinity == 100, "Todas las revisitas conservan pistas y premios únicos")
	game.new_game()
	check(game.zone.dialogue.active and not game.session.mission.intro_seen and not game.session.mission.completed and game.session.mission.investigated.is_empty() and game.session.defeated_encounters.is_empty(), "Nueva partida restablece introducción, misión y encuentros")
	check(game.session.party.resonance == 0 and game.session.party.progress("ignar").affinity == 0, "Nueva partida restablece recursos persistentes originales")
	game.zone.dialogue.skip_button.pressed.emit()
	check(game.session.mission.intro_seen and game.zone.player.movement_enabled and game.session.mission.investigated.is_empty(), "Omitir introducción da control sin saltar pistas")
	examine(game.zone, "camp")
	game.zone.player.position = game.zone.encounters[0].map_position + Vector3.UP * 0.05
	check(await helper.wait_for_battle(game), "Encuentro tras pista permite probar derrota narrativa")
	if not is_instance_valid(game.battle):
		game.free()
		return
	game.battle.set_skip_animations(true)
	await helper.force_defeat(game)
	re = game.session.party.resonance
	game.battle.hud._return_button.pressed.emit()
	check(await helper.wait_for_zone(game), "Derrota puede regresar al claro sin reiniciar la misión")
	check(game.session.mission.investigated == ["camp"] and game.session.mission.intro_seen and game.zone.markers.size() == 2 and not game.zone.dialogue.active, "Derrota conserva pistas y enemigos pendientes sin repetir introducción")
	check(game.session.party.resonance == re and game.session.party.progress("ignar").affinity == 0 and not game.session.mission.completed, "Derrota no cambia reglas de recursos ni completa misión")
	game.new_game()
	game.zone.dialogue.skip_button.grab_focus()
	key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await _tree.process_frame
	key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = false
	Input.parse_input_event(key)
	await _tree.process_frame
	check(game.session.mission.intro_seen and not game.zone.dialogue.active and game.zone.player.movement_enabled, "Omitir introducción también funciona con el botón enfocado y Enter")
	game.free()
	await _tree.process_frame
