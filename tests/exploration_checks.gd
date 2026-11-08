extends RefCounted

var _tree: SceneTree
var _verify: Callable
var _last_victory_re: int = -1

func check(condition: bool, description: String) -> void:
	_verify.call(condition, description)

func physics_frames(count: int) -> void:
	for i in range(count):
		await _tree.physics_frame

func settle(stage: Node3D) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while is_instance_valid(stage) and (stage.playing or not stage.event_queue.is_empty()) and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	await _tree.process_frame

func wait_for_battle(game: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 4000
	while not is_instance_valid(game.battle) and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	return is_instance_valid(game.battle)

func wait_for_zone(game: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 4000
	while is_instance_valid(game.battle) and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	return game.session.mode == GameSession.Mode.EXPLORING and game.zone.is_inside_tree()

func win_encounter(game: Node) -> bool:
	var count := 0
	while is_instance_valid(game.battle) and count < 150:
		count += 1
		var stage = game.battle
		await settle(stage)
		if not is_instance_valid(game.battle):
			break
		var ui = stage.hud
		var engine: BattleEngine = ui.engine
		if engine.phase == BattleEngine.Phase.VICTORY:
			await _tree.process_frame
			continue
		if engine.phase == BattleEngine.Phase.DEFEAT:
			return false
		if engine.phase == BattleEngine.Phase.ENEMY_TURN:
			ui.actions.get_child(0).pressed.emit()
			continue
		var actor_id := engine.current_id()
		var actor := engine.fighters[actor_id]
		if actor_id == 1 and game.session.party.resonance == 100:
			ui.actions.get_child(ui.actions.get_child_count() - 1).pressed.emit()
			if engine.phase == BattleEngine.Phase.VICTORY:
				_last_victory_re = engine.party_state.resonance
			continue
		var action_index := 0
		var target_index := 0
		if actor_id == 0 and actor.mp >= 4:
			action_index = 2
		elif actor_id == 1 and actor.mp >= 7:
			action_index = 3 # Escarcha exploits the sentinel's weakness.
		elif actor_id == 2 and actor.mp >= 7:
			for i in range(3):
				if engine.fighters[i].hp > 0 and engine.fighters[i].hp <= engine.fighters[i].data.max_hp - 35:
					action_index = 2
					var ids := engine.valid_targets(actor.data.abilities[0])
					target_index = ids.find(i)
					break
		ui.actions.get_child(action_index).pressed.emit()
		ui.targets.get_child(target_index).pressed.emit()
		if engine.phase == BattleEngine.Phase.VICTORY:
			_last_victory_re = engine.party_state.resonance
	return count < 150 and await wait_for_zone(game)

func force_defeat(game: Node) -> void:
	var ui = game.battle.hud
	ui.engine.fighters[0].hp = 0
	ui.engine.fighters[2].hp = 0
	ui.engine.fighters[1].hp = 1
	ui._refresh()
	ui.actions.get_child(0).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	await settle(game.battle)
	ui.actions.get_child(0).pressed.emit()
	await settle(game.battle)

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_verify = verify
	var game = preload("res://scenes/forest_exploration.tscn").instantiate()
	_tree.root.add_child(game)
	game.zone.dialogue.skip() # Exercise the original exploration flow after the new intro.
	await physics_frames(6)
	check(game.session.mode == GameSession.Mode.EXPLORING and game.zone is Node3D, "Exploración carga como nueva escena principal")
	check(game.zone.player is CharacterBody3D and game.zone.get_node("ForestCamera") is Camera3D, "Líder con físicas y cámara fija existen")
	check(game.zone.markers.size() == 2 and not is_instance_valid(game.battle), "Dos enemigos visibles y ningún encuentro remoto en el inicio")
	check(game.zone.info.text.contains("Bosque del Eclipse") and game.zone.info.text.contains("RE 0/100"), "HUD indica área, grupo y Resonancia")
	check(not game.zone.request_encounter(game.zone.encounters[0]), "Encuentro solicitado desde lejos se rechaza")
	var player = game.zone.player
	var start: Vector3 = player.position
	Input.action_press("ui_right")
	await physics_frames(8)
	Input.action_release("ui_right")
	await physics_frames(2)
	check(player.position.x > start.x + 0.2, "Flechas de teclado desplazan al líder")
	check(absf(player.model.rotation.y) > 0.1, "Modelo se orienta al caminar")
	var stopped: Vector3 = player.position
	await physics_frames(4)
	check(player.position.distance_to(stopped) < 0.02, "Soltar movimiento detiene al líder")
	player.movement_speed = 30
	player.position = Vector3(-5, 0.05, 5.9)
	player.set_movement_input(Vector2.RIGHT)
	await physics_frames(35)
	player.set_movement_input(Vector2.ZERO)
	check(player.position.x > 7.5 and player.position.x < 8.3, "Colisión del límite impide salir del mapa incluso a velocidad alta")
	check(player.position.y > -0.2 and player.is_on_floor(), "Suelo mantiene al líder sin atravesar el plano")
	player.position = GameSession.SPAWN
	player.set_movement_input(Vector2(1, 1))
	await physics_frames(3)
	check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.movement_speed), "Entrada externa normaliza diagonal sin aumentar velocidad")
	player.set_movement_input(Vector2.ZERO)
	player.movement_speed = 4
	# Contact through real Area3D physics, not an artificial transition call.
	player.position = Vector3(-1.8, 0.05, 1)
	player.set_movement_input(Vector2.RIGHT)
	game.session.party.resonance = 37
	check(await wait_for_battle(game), "Contacto cercano produce transición a combate")
	if not is_instance_valid(game.battle):
		game.free()
		return
	game.battle.animation_time_scale = 0.02
	var run: PartyState = game.session.party
	var previous_zone: Node3D = game.zone
	var return_position: Vector3 = game.session.leader_position
	check(not game.zone.is_inside_tree() and not game.zone.player.movement_enabled, "Exploración sale del árbol y queda sin movimiento durante combate")
	check(game.battle.hud.run == run and run.resonance == 37, "Transición reutiliza PartyState y conserva RE sin modificarla")
	check(game.battle.hud.engine.fighters.size() == 4 and game.battle.hud.encounter_enemies == game.active_encounter.enemies, "Combate usa enemigos configurados y motor existente")
	check(game.battle.hud.engine.fighters[0].hp == 120 and game.battle.hud.engine.fighters[1].mp == 35, "Simplificación explícita: PV y PM completos al entrar")
	check(not game.zone.request_encounter(game.zone.encounters[1]), "Encuentro duplicado no inicia una segunda batalla")
	check(run.in_battle() and game.battle.hud._return_button.disabled, "Vínculo bloqueado en combate y retorno anticipado desactivado")
	check(await win_encounter(game), "Combate completo ganado con habilidades e Ignar vuelve a exploración")
	if is_instance_valid(game.battle):
		game.free()
		return
	await physics_frames(4)
	check(game.zone == previous_zone and game.zone.player.position.distance_to(return_position) < 0.15, "Retorno conserva zona y posición previa al encuentro")
	check(game.session.defeated_encounters == ["clearing_sentinel_a"] and not game.zone.markers.has("clearing_sentinel_a"), "Enemigo derrotado se registra y desaparece del mapa")
	check(game.zone.markers.size() == 1 and game.zone.player.movement_enabled, "Solo queda segundo enemigo y se recupera el control")
	check(run.progress("ignar").affinity == 50 and game.session.party == run and not run.in_battle(), "Victoria conserva grupo y concede exactamente 50 PA")
	check(run.resonance > 0 and game.zone.info.text.contains("RE %d/100" % run.resonance), "RE generada en combate se muestra al regresar")
	check(run.resonance == _last_victory_re, "El retorno conserva exactamente la RE final del combate")
	check(not game.zone.request_encounter(game.zone.encounters[0]), "Encuentro derrotado no puede reactivarse")
	var saved_re := run.resonance
	game.zone.player.position = game.zone.encounters[1].map_position + Vector3.UP * 0.05
	check(await wait_for_battle(game), "Segundo enemigo visible inicia otro encuentro")
	if not is_instance_valid(game.battle):
		game.free()
		return
	game.battle.animation_time_scale = 0.02
	check(game.battle.hud.run == run and run.resonance == saved_re and run.progress("ignar").affinity == 50, "RE y PA se mantienen al entrar en el segundo combate")
	check(game.battle.hud.engine.fighters[1].mp == 35, "Nuevo encuentro restaura PM según simplificación documentada")
	check(await win_encounter(game), "Segundo combate completo permite volver a la zona")
	if is_instance_valid(game.battle):
		game.free()
		return
	check(game.zone.markers.is_empty() and game.session.defeated_encounters.size() == 2 and game.zone.hint.text.contains("Claro despejado"), "Ambos encuentros eliminados y zona de prueba terminada")
	check(run.progress("ignar").affinity == 100 and run.guardian_level("lyra") == 2, "Dos victorias mantienen progresión y desbloquean nivel 2")
	game.new_game()
	game.zone.dialogue.skip()
	await physics_frames(4)
	check(game.zone.markers.size() == 2 and game.session.defeated_encounters.is_empty() and game.session.party.resonance == 0 and game.session.party.progress("ignar").affinity == 0, "Nueva partida reinicia mapa, RE y PA sin estado antiguo")
	game.zone.player.position = game.zone.encounters[0].map_position + Vector3.UP * 0.05
	check(await wait_for_battle(game), "Encuentro disponible después de nueva partida")
	if not is_instance_valid(game.battle):
		game.free()
		return
	game.battle.animation_time_scale = 0.02
	await force_defeat(game)
	check(game.session.mode == GameSession.Mode.DEFEAT and not game.battle.hud._return_button.disabled, "Derrota permanece en batalla y habilita volver al claro")
	check(game.session.party.progress("ignar").affinity == 0 and game.session.defeated_encounters.is_empty(), "Derrota no concede PA ni elimina encuentro")
	game.battle.hud._restart()
	check(game.session.mode == GameSession.Mode.BATTLE and game.battle.hud.engine.fighters[0].hp == 120 and game.battle.hud.engine.fighters[1].mp == 35, "Reintentar restaura PV/PM y conserva el mismo encuentro")
	await force_defeat(game)
	saved_re = game.session.party.resonance
	game.battle.hud._return_button.pressed.emit()
	check(await wait_for_zone(game), "Botón de derrota vuelve a exploración")
	await physics_frames(4)
	check(game.zone.player.position.distance_to(GameSession.SPAWN) < 0.15 and game.zone.markers.size() == 2, "Derrota devuelve al inicio y mantiene enemigo disponible")
	check(game.session.party.resonance == saved_re and game.session.party.progress("ignar").affinity == 0, "Regreso tras derrota conserva RE y no inventa premios")
	check(game.zone.encounter_armed and game.zone.player.movement_enabled and not game.session.party.in_battle(), "Retorno libera entrada, detección y bloqueo de Guardianes")
	# A queued request from a discarded session cannot open a ghost battle.
	game.zone.player.position = game.zone.encounters[0].map_position
	game.zone.request_encounter(game.zone.encounters[0])
	game.new_game()
	game.zone.dialogue.skip()
	await physics_frames(4)
	check(not is_instance_valid(game.battle) and game.session.mode == GameSession.Mode.EXPLORING, "Nueva partida invalida transiciones diferidas de la anterior")
	game.free()
	await _tree.process_frame
