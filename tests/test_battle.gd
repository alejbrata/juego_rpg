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
	var heroes: Array[CombatantData] = [load("res://data/kael.tres"), load("res://data/lyra.tres"), load("res://data/nira.tres")]
	var enemies: Array[CombatantData] = [load("res://data/sentinel.tres")]
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

func _initialize() -> void:
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
	check(e.fighters[3].hp == 252 and e.fighters[1].mp == 27, "Fórmula mágica y coste")
	check(e.act(e.fighters[0].data.abilities[0], 3).is_empty(), "Golpe potente válido")
	check(e.fighters[3].hp == 225 and e.fighters[0].mp == 8, "Fórmula física y coste")
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
	check(e.fighters[0].hp == 113 and e.fighters[0].guarding, "Protección reduce daño a la mitad")
	e.act(e.defend_action(), 2)
	check(not e.fighters[1].guarding and e.fighters[0].guarding, "Defensa expira solo al comenzar el turno propio")
	e.act(e.defend_action(), 1)
	check(not e.fighters[0].guarding, "Protección expira al turno del receptor")
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
	ui.free()
	print("%d comprobaciones; %d fallos" % [checks, failures])
	quit(0 if failures == 0 else 1)
