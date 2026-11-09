extends SceneTree

var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FALLO: " + description)

func battle() -> BattleEngine:
	var engine := BattleEngine.new()
	var heroes: Array[CombatantData] = []
	for name in ["kael", "lyra", "nira"]:
		heroes.append(load("res://data/%s.tres" % name).duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CombatantData)
	var enemies: Array[CombatantData] = [load("res://data/sentinel.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CombatantData]
	engine.start(heroes, enemies)
	return engine

func defend_until_round(engine: BattleEngine, target_round: int) -> void:
	var limit := 100
	while engine.round_number < target_round and limit > 0:
		limit -= 1
		if engine.phase == BattleEngine.Phase.ENEMY_TURN:
			engine.step_enemy()
		elif engine.phase == BattleEngine.Phase.WAITING_PLAYER:
			engine.act(engine.defend_action(), engine.current_id())
		else:
			break
	check(limit > 0, "Avance acotado de rondas")

func protection_battle(target_id: int = 1) -> BattleEngine:
	var e := BattleEngine.new()
	var heroes: Array[CombatantData] = [load("res://data/kael.tres"), load("res://data/lyra.tres"), load("res://data/nira.tres")]
	var enemy := (load("res://data/sentinel.tres") as CombatantData).duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CombatantData
	var enemies: Array[CombatantData] = [enemy, enemy]
	e.start(heroes, enemies)
	e.act(e.basic_attack(), 3)
	check(e.act(e.fighters[0].data.abilities[1], target_id).is_empty(), "Kael puede proteger a un aliado vivo")
	return e

func test_protection() -> void:
	var e := protection_battle()
	check(e.current_id() == 3 and e.fighters[0].mp == 7, "Protección consume 5 PM y el turno de Kael")
	check(not e.fighters[1].guarding, "Protección no aplica Defender al aliado")
	e.act(e.basic_attack(), 1)
	check(e.fighters[0].hp == 113 and e.fighters[1].hp == 75, "Intercepta con DEF de Kael y reduce 50 %")
	check(e.fighters[0].protection_target == -1, "Interceptar consume Protección")
	check("\n".join(e.history).contains("Kael intercepta el ataque contra Lyra"), "Registro identifica interceptor y objetivo")
	e.act(e.basic_attack(), 1)
	check(e.fighters[1].hp == 52 and e.fighters[0].hp == 113, "El segundo ataque alcanza al aliado")
	e = protection_battle()
	var magic := BattleAbility.new()
	magic.label = "Magia de prueba"
	magic.effect = "magic"
	magic.power = 10
	e.fighters[3].data.magic = 30
	e.fighters[3].data.abilities.append(magic)
	e.act(magic, 1)
	check(e.fighters[0].hp == 104 and e.fighters[1].hp == 75, "Interceptación mágica usa RES de Kael")
	e = protection_battle(0)
	e.fighters[0].guarding = true # Assert non-stacking even if both statuses coexist.
	e.act(e.basic_attack(), 0)
	check(e.fighters[0].hp == 113, "Autoprotección y Defender aplican una sola reducción")
	e = protection_battle()
	e.fighters[0].hp = 0
	e.act(e.basic_attack(), 1)
	check(e.fighters[1].hp == 52, "Kael inconsciente no intercepta")
	e = protection_battle()
	e.fighters[0].hp = 3
	e.act(e.basic_attack(), 1)
	check(e.fighters[0].hp == 0 and e.fighters[1].hp == 75, "Golpe letal al interceptor no transfiere daño sobrante")
	e = protection_battle(2)
	e.act(e.basic_attack(), 0)
	e.act(e.basic_attack(), 0)
	check(e.current_id() == 2 and e.fighters[0].protection_target == 2, "Protección no expira al comenzar turno del receptor")
	e.act(e.defend_action(), 2)
	check(e.fighters[0].protection_target == 2, "Protección persiste entre rondas antes de actuar Kael")
	e.act(e.basic_attack(), 3)
	check(e.current_id() == 0 and e.fighters[0].protection_target == -1, "Expira al comenzar siguiente turno de Kael")
	e = protection_battle()
	var area := e.basic_attack()
	area.label = "Área de prueba"
	area.is_area = true
	e.fighters[3].data.abilities.append(area)
	e.act(area, 1)
	check(e.fighters[0].hp == 106 and e.fighters[1].hp == 52 and e.fighters[2].hp == 70, "Área daña a todos sin interceptación")
	check(e.fighters[0].protection_target == 1, "Área no consume Protección")
	e.act(e.basic_attack(), 1)
	check(e.fighters[0].hp == 99 and e.fighters[1].hp == 52, "Ataque individual posterior al área sí se intercepta")
	e = battle()
	e.act(e.basic_attack(), 3)
	var protection := e.fighters[0].data.abilities[1]
	check(e.valid_targets(protection) == [0, 1, 2], "Protección admite todos los aliados vivos incluido Kael")
	check(not e.act(protection, 3).is_empty(), "Protección rechaza enemigo")
	e.fighters[1].hp = 0
	check(not e.act(protection, 1).is_empty(), "Protección rechaza aliado caído")
	e.fighters[0].mp = 4
	check(not e.act(protection, 0).is_empty(), "Protección requiere 5 PM")
	check(e.current_id() == 0 and e.fighters[0].mp == 4 and e.fighters[0].protection_target == -1 and e.history.size() == 2, "Protección inválida conserva recursos, turno, estado y registro")

func test_elements() -> void:
	var e := battle()
	e.act(e.fighters[1].data.abilities[1], 3)
	check(e.fighters[3].hp == 244 and e.fighters[1].mp == 28, "Escarcha: base 24 por debilidad 1,5 = 36")
	e = battle()
	var enemy := e.fighters[3].data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CombatantData
	e.fighters[3].data = enemy
	var spell := e.fighters[1].data.abilities[0].duplicate(true) as BattleAbility
	var mage := e.fighters[1].data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CombatantData
	e.fighters[1].data = mage
	mage.abilities.append(spell)
	spell.element = "neutral"
	enemy.weaknesses.append("neutral")
	e.act(spell, 3)
	check(e.fighters[3].hp == 252, "Neutral siempre multiplica por uno incluso en afinidades")
	e = battle()
	mage = e.fighters[1].data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CombatantData
	e.fighters[1].data = mage
	spell = mage.abilities[1]
	spell.power = 7
	e.act(spell, 3)
	check(e.fighters[3].hp == 243, "Debilidad: base 25 por 1,5 redondea abajo a 37")
	e = battle()
	mage = e.fighters[1].data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CombatantData
	e.fighters[1].data = mage
	spell = mage.abilities[0]
	spell.power = 11
	e.act(spell, 3)
	check(e.fighters[3].hp == 266, "Resistencia: base 29 por 0,5 redondea abajo a 14")
	e = battle()
	e.fighters[3].guarding = true
	e.act(e.fighters[1].data.abilities[0], 3)
	check(e.fighters[3].hp == 273, "Elemento antes de Defender: base 28, resistencia 14, defensa 7")
	e = battle()
	mage = e.fighters[1].data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CombatantData
	e.fighters[1].data = mage
	mage.magic = 0
	e.act(mage.abilities[0], 3)
	check(e.fighters[3].hp == 279, "Daño mínimo uno tras resistencia y redondeo")
	e = battle()
	enemy = e.fighters[3].data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CombatantData
	enemy.weaknesses.append("fire")
	var heroes: Array[CombatantData] = [e.fighters[0].data]
	var enemies: Array[CombatantData] = [enemy]
	check(not e.start(heroes, enemies).is_empty(), "Se rechaza enemigo débil y resistente al mismo elemento")
	check(e.fighters.size() == 4 and e.current_id() == 1 and e.history.is_empty(), "Inicio con datos inválidos no altera combate anterior")
	e.fighters[3].data = enemy
	check(not e.act(e.fighters[1].data.abilities[0], 3).is_empty(), "Afinidades contradictorias también bloquean acciones")
	check(e.fighters[1].mp == 35 and e.current_id() == 1 and e.fighters[3].hp == 280, "Datos inválidos no consumen recursos ni turno")
	enemy.weaknesses.erase("fire")
	enemy.resistances.append("unknown")
	check(not enemy.validation_error().is_empty(), "Elemento desconocido en afinidades se rechaza")
	e = battle()
	mage = e.fighters[1].data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CombatantData
	e.fighters[1].data = mage
	mage.abilities[0].element = "unknown"
	check(not e.act(mage.abilities[0], 3).is_empty() and e.fighters[1].mp == 35 and e.current_id() == 1, "Habilidad con elemento inválido no consume PM ni turno")
	check((load("res://data/sentinel.tres") as CombatantData).validation_error().is_empty(), "Centinela original permanece válido y sin mutar")

func _initialize() -> void:
	preload("res://tests/guardian_checks.gd").new().run(check)
	test_protection()
	test_elements()
	var e := battle()
	check(e.order == [1, 0, 3, 2], "Orden por velocidad")
	check(e.round_number == 1 and e.phase == BattleEngine.Phase.WAITING_PLAYER, "Inicio espera al jugador")
	var flame := e.fighters[1].data.abilities[0]
	check(e.act(flame, 0) != "", "Rechaza magia contra aliado")
	check(e.act(flame, -1) != "" and e.act(flame, 99) != "", "Rechaza índices inválidos")
	check(e.act(null, 3) != "", "Rechaza acción nula")
	check(e.act(e.fighters[0].data.abilities[0], 3) != "", "Rechaza habilidad ajena")
	check(e.current_id() == 1 and e.fighters[1].mp == 35 and e.history.is_empty(), "Intentos inválidos conservan turno y recursos")
	e.fighters[1].mp = 0
	check(e.act(flame, 3) != "" and e.current_id() == 1, "Valida PM antes de actuar")
	e.fighters[1].mp = 35
	check(e.act(flame, 3).is_empty(), "Llama válida")
	check(e.fighters[3].hp == 266 and e.fighters[1].mp == 27, "Fórmula mágica, resistencia al fuego y coste")
	check(e.act(e.fighters[0].data.abilities[0], 3).is_empty(), "Golpe potente válido")
	check(e.fighters[3].hp == 239 and e.fighters[0].mp == 8, "Fórmula física y coste")
	e.step_enemy()
	check(e.fighters[0].hp == 106 and e.current_id() == 2, "IA ataca y pasa turno")
	e.fighters[0].hp = 110
	e.act(e.fighters[2].data.abilities[0], 0)
	check(e.fighters[0].hp == 120 and e.fighters[2].mp == 23, "Cura limitada al máximo")
	check(e.round_number == 2, "Nueva ronda tras todas las actuaciones")
	e = battle()
	e.act(e.defend_action(), 1)
	e.act(e.defend_action(), 0)
	e.step_enemy()
	e.fighters[0].hp = 50
	e.act(e.fighters[2].data.abilities[0], 0)
	check(e.fighters[0].hp == 90, "Cura recupera MAG más 20")
	e = battle()
	e.act(e.defend_action(), 1)
	e.act(e.fighters[0].data.abilities[1], 0)
	e.step_enemy()
	check(e.fighters[0].hp == 113 and not e.fighters[0].guarding and e.fighters[0].protection_target == -1, "Autoprotección intercepta una vez sin activar Defender")
	e.act(e.defend_action(), 2)
	check(not e.fighters[1].guarding, "Defensa expira al comenzar el turno propio")
	e.act(e.defend_action(), 1)
	check(not e.fighters[0].guarding, "Protección no se confunde con Defender")
	e = battle()
	e.act(e.basic_attack(), 3)
	e.act(e.basic_attack(), 3)
	e.step_enemy()
	e.act(e.fighters[2].data.abilities[1], 2)
	check(e.round_number == 2 and e.order == [1, 2, 0, 3], "Impulso cambia orden de la próxima ronda")
	defend_until_round(e, 3)
	check(e.fighters[2].speed() == 15, "Impulso activo segunda ronda completa")
	defend_until_round(e, 4)
	check(e.fighters[2].speed() == 10 and e.order == [1, 0, 3, 2], "Impulso expira después de dos rondas completas")
	# Reapplying haste refreshes it without stacking speed.
	e.act(e.defend_action(), 1)
	e.act(e.defend_action(), 0)
	e.step_enemy()
	e.act(e.fighters[2].data.abilities[1], 2)
	e.act(e.defend_action(), 1)
	e.act(e.fighters[2].data.abilities[1], 2)
	check(e.fighters[2].speed() == 15 and e.fighters[2].haste_rounds == 3, "Impulso renueva sin acumular velocidad")
	e = battle()
	e.fighters[0].hp = 0
	e.fighters[3].hp = 1
	check(not e.valid_targets(e.fighters[2].data.abilities[0]).has(0), "No se puede curar inconscientes")
	e.act(e.basic_attack(), 3)
	check(e.phase == BattleEngine.Phase.VICTORY, "Victoria inmediata al caer enemigo")
	check(e.act(e.basic_attack(), 3) != "", "No hay acciones tras final")
	e = battle()
	e.fighters[0].hp = 0
	e.fighters[2].hp = 0
	e.fighters[1].hp = 1
	e.act(e.basic_attack(), 3)
	check(e.phase == BattleEngine.Phase.ENEMY_TURN and e.current_id() == 3, "Se omiten turnos de caídos")
	e.step_enemy()
	check(e.phase == BattleEngine.Phase.DEFEAT, "Derrota al caer último héroe")
	var a := CombatantData.new()
	a.label = "A"
	a.max_hp = 20
	a.speed = 10
	var b := CombatantData.new()
	b.label = "B"
	b.max_hp = 20
	b.speed = 10
	var heroes: Array[CombatantData] = [a]
	var enemies: Array[CombatantData] = [b]
	e = BattleEngine.new()
	e.start(heroes, enemies)
	check(e.order == [0, 1], "Empate estable por índice inicial")
	e.act(e.basic_attack(), 1)
	check(e.fighters[1].hp == 19, "Daño mínimo uno")
	e.start(heroes, enemies)
	e.act(e.defend_action(), 0)
	e.step_enemy()
	check(e.fighters[0].hp == 19, "Defensa conserva mínimo uno")
	b.strength = 3
	e.start(heroes, enemies)
	e.act(e.defend_action(), 0)
	e.step_enemy()
	check(e.fighters[0].hp == 18, "Defensa redondea daño impar hacia arriba")
	check(a.max_hp == 20 and b.max_hp == 20, "Recursos no mutados")
	# Regression: complete battle with only basic attacks, no scene/rendering.
	e = battle()
	var turns := 0
	while e.phase in [BattleEngine.Phase.WAITING_PLAYER, BattleEngine.Phase.ENEMY_TURN] and turns < 200:
		turns += 1
		if e.phase == BattleEngine.Phase.ENEMY_TURN:
			e.step_enemy()
		else:
			e.act(e.basic_attack(), 3)
	check(turns < 200 and e.phase == BattleEngine.Phase.DEFEAT, "Combate completo con ataques termina en derrota")
	e = battle()
	turns = 0
	while e.phase in [BattleEngine.Phase.WAITING_PLAYER, BattleEngine.Phase.ENEMY_TURN] and turns < 200:
		turns += 1
		if e.phase == BattleEngine.Phase.ENEMY_TURN:
			e.step_enemy()
		else:
			var actor := e.fighters[e.current_id()]
			var action := e.basic_attack()
			var target := 3
			if e.current_id() == 2 and e.fighters[0].hp > 0 and e.fighters[0].hp <= 80 and actor.mp >= 7:
				action = actor.data.abilities[0]
				target = 0
			elif e.current_id() != 2:
				for ability in actor.data.abilities:
					if ability.target_kind == "enemy" and actor.mp >= ability.cost:
						action = ability
						break
			e.act(action, target)
	check(turns < 200 and e.phase == BattleEngine.Phase.VICTORY, "Combate completo ganable usando habilidades y cura")
	e.start(heroes, enemies)
	check(e.history.is_empty() and e.round_number == 1 and e.fighters[0].hp == 20, "Reinicio limpio")
	# Instantiate the actual UI and exercise action/target callbacks headlessly.
	var scene := load("res://scenes/battle.tscn") as PackedScene
	var ui := scene.instantiate()
	root.add_child(ui)
	# SceneTree initialization defers ready until the first frame.
	await process_frame
	check(ui.actions.get_child_count() == 4, "Interfaz carga las cuatro acciones de Lyra")
	ui.actions.get_child(0).pressed.emit()
	check(ui.targets.get_child_count() == 1, "Interfaz muestra objetivo enemigo")
	ui.targets.get_child(0).pressed.emit()
	check(ui.engine.current_id() == 0, "Botón de objetivo ejecuta acción y refresca turno")
	ui.actions.get_child(1).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	check(ui.engine.phase == BattleEngine.Phase.ENEMY_TURN and ui.actions.get_child_count() == 1, "Interfaz ofrece resolver enemigo")
	ui.actions.get_child(0).pressed.emit()
	check(ui.engine.current_id() == 2, "Botón enemigo ejecuta IA y avanza a Nira")
	ui._restart()
	check(ui.engine.current_id() == 1 and ui.engine.history.is_empty(), "Reinicio de interfaz")
	check(ui.status.text.contains("Lyra") and ui.roster.text.contains("TURNO ACTIVO: Lyra"), "Interfaz identifica personaje activo")
	check(ui.actions.get_child(2).text.contains("[fire]") and ui.actions.get_child(3).text.contains("[ice]"), "Botones muestran elementos de habilidades")
	ui.actions.get_child(2).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	check(ui.log_view.text.contains("PV 280 → 266 (-14)") and ui.log_view.text.contains("PM 35 → 27 (-8)"), "Registro visual incluye cambios reales de PV y PM")
	ui.actions.get_child(3).pressed.emit()
	check(ui.targets.get_child_count() == 3, "Interfaz permite elegir aliado para Protección")
	ui.engine.fighters[0].mp = 0
	ui.targets.get_child(0).pressed.emit()
	check(ui.engine.current_id() == 0 and ui.engine.fighters[0].mp == 0 and ui.message.text == "PM insuficientes.", "Callback inválido muestra error sin gastar turno ni PM")
	ui.engine.fighters[0].mp = 12
	ui.targets.get_child(0).pressed.emit()
	ui.actions.get_child(0).pressed.emit()
	check(ui.engine.fighters[0].hp == 113 and ui.log_view.text.contains("Kael intercepta"), "Interfaz ejecuta y muestra autoprotección")
	ui._restart()
	check(ui.engine.fighters[0].protection_target == -1 and ui.engine.fighters[0].mp == 12 and ui.log_view.text.is_empty(), "Reiniciar limpia Protección, PM y registro")
	# Additional UI flow; all 92 checks from iteration 0.2 remain above.
	ui._new_party()
	check(ui.run.resonance == 0 and ui.resonance_bar.value == 0 and ui.actions.get_child_count() == 4, "Nueva partida muestra RE cero y no ofrece Invocar")
	check(ui.guardian_info.text.contains("Lyra: Ignar") and ui.guardian_info.text.contains("nivel 1") and ui.guardian_info.text.contains("0 PA"), "Interfaz muestra portador, nivel y PA iniciales")
	ui.run.resonance = 100
	ui._refresh()
	check(ui.resonance_bar.value == 100 and ui.actions.get_child_count() == 5 and ui.actions.get_child(4).text.contains("Invocar"), "Interfaz ofrece Invocar a Lyra con barra llena")
	ui.actions.get_child(4).pressed.emit()
	check(ui.run.resonance == 0 and ui.resonance_bar.value == 0 and ui.engine.current_id() == 0, "Botón Invocar consume RE y actualiza turno")
	check(ui.message.text.contains("Juicio de Ceniza") and ui.log_view.text.contains("20 de daño") and ui.log_view.text.contains("Defensa física -25%"), "Interfaz muestra mensaje, daño y reducción de Defensa")
	check(ui.engine.fighters[1].mp == 35 and ui.engine.events.size() == 3, "Flujo de interfaz invoca sin gastar PM y registra tres eventos")
	ui.run.resonance = 100
	ui._refresh()
	check(ui.actions.get_child_count() == 4, "Kael sin vínculo no recibe botón Invocar aunque haya 100 RE")
	ui._restart()
	check(ui.run.resonance == 100 and ui.actions.get_child_count() == 5 and ui.engine.fighters[3].defense_down_rounds == 0, "Reiniciar combate conserva RE y limpia debuff temporal")
	ui.engine.fighters[3].hp = 1
	ui.actions.get_child(0).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	check(ui.engine.phase == BattleEngine.Phase.VICTORY and ui.guardian_info.text.contains("50 PA"), "Victoria actualiza PA mostrados")
	ui._restart()
	ui.engine.fighters[3].hp = 1
	ui.actions.get_child(0).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	check(ui.guardian_info.text.contains("nivel 2") and ui.guardian_info.text.contains("100 PA"), "Segunda victoria muestra nuevo nivel de Ignar")
	ui._new_party()
	check(ui.run.resonance == 0 and ui.run.progress("ignar").affinity == 0 and ui.engine.fighters[3].hp == 280, "Nueva partida reinicia RE, PA y combate")
	ui.free()
	await preload("res://tests/presentation_checks.gd").new().run(self, check)
	await preload("res://tests/exploration_checks.gd").new().run(self, check)
	await historical_companion_fixture(preload("res://tests/visual_refresh_checks.gd").new())
	await preload("res://tests/narrative_checks.gd").new().run(self, check)
	await historical_companion_fixture(preload("res://tests/kael_asset_checks.gd").new())
	await preload("res://tests/kael_art_checks.gd").new().run(self, check)
	await preload("res://tests/kael_reference_checks.gd").new().run(self, check)
	await preload("res://tests/kael_polish_checks.gd").new().run(self, check)
	await preload("res://tests/kael_retro_checks.gd").new().run(self, check)
	await preload("res://tests/companion_asset_checks.gd").new().run(self, check)
	print("%d comprobaciones; %d fallos" % [checks, failures])
	quit(0 if failures == 0 else 1)

func historical_companion_fixture(suite: RefCounted) -> void:
	# 0.6 explicitly checks separate procedural capes; 0.8 checks that only Kael
	# is imported. Keep every original assertion under its original fixture.
	# companion_asset_checks covers the current imported party separately.
	var previous: Array = []
	for hero in ["lyra", "nira"]:
		previous.append(ProjectSettings.get_setting("visuals/%s/use_imported" % hero, false))
		ProjectSettings.set_setting("visuals/%s/use_imported" % hero, false)
	await suite.run(self, check)
	for i in range(2):
		ProjectSettings.set_setting("visuals/%s/use_imported" % ["lyra", "nira"][i], previous[i])
