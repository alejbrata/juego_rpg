extends RefCounted

var _verify: Callable

func check(condition: bool, description: String) -> void:
	_verify.call(condition, description)

func encounter(run: PartyState = null, enemy_count: int = 1) -> BattleEngine:
	var e := BattleEngine.new()
	var heroes: Array[CombatantData] = []
	for name in ["kael", "lyra", "nira"]:
		heroes.append(load("res://data/%s.tres" % name).duplicate(true) as CombatantData)
	var enemies: Array[CombatantData] = []
	for i in range(enemy_count):
		enemies.append(load("res://data/sentinel.tres").duplicate(true) as CombatantData)
	check(e.start(heroes, enemies, run).is_empty(), "Encuentro de prueba válido")
	return e

func snapshot(e: BattleEngine) -> Dictionary:
	var states: Array = []
	for f in e.fighters:
		states.append([f.hp, f.mp, f.guarding, f.haste_rounds, f.protection_target, f.defense_down_rounds, f.defense_down_amount])
	return {"re": e.party_state.resonance, "phase": e.phase, "round": e.round_number, "cursor": e.cursor, "order": e.order.duplicate(), "fighters": states, "history": e.history.duplicate(), "events": e.events.duplicate(true), "pa": e.party_state.progress("ignar").affinity if e.party_state.progress("ignar") != null else 0}

func advance_to_round(e: BattleEngine, number: int) -> void:
	var count := 0
	while e.round_number < number and e.phase in [BattleEngine.Phase.WAITING_PLAYER, BattleEngine.Phase.ENEMY_TURN] and count < 100:
		count += 1
		if e.phase == BattleEngine.Phase.ENEMY_TURN:
			e.step_enemy()
		else:
			e.act(e.defend_action(), e.current_id())
	check(e.round_number == number, "Se alcanza la ronda solicitada sin bloquearse")

func run(verify: Callable) -> void:
	_verify = verify
	test_resonance()
	test_summon()
	test_progress_and_binding()
	test_passives()

func test_resonance() -> void:
	var e := encounter()
	check(e.party_state.resonance == 0, "RE inicial cero")
	e.act(e.basic_attack(), 3)
	check(e.party_state.resonance == 10, "Ataque básico genera 10 RE")
	e.act(e.defend_action(), 0)
	check(e.party_state.resonance == 25, "Defender genera 15 RE")
	e.step_enemy()
	check(e.party_state.resonance == 30, "Ataque enemigo solo genera 5 RE por daño recibido")
	e.act(e.fighters[2].data.abilities[0], 0)
	check(e.party_state.resonance == 40, "Cura válida genera 10 RE")
	var before := snapshot(e)
	e.act(e.fighters[1].data.abilities[0], 0)
	check(snapshot(e) == before, "Acción inválida no altera RE ni ningún estado")
	e = encounter()
	e.act(e.fighters[1].data.abilities[1], 3)
	check(e.party_state.resonance == 20, "Debilidad de hielo genera 10 RE adicionales")
	e = encounter(null, 2)
	var area := e.fighters[1].data.abilities[1].duplicate(true) as BattleAbility
	area.is_area = true
	e.fighters[1].data.abilities.append(area)
	e.act(area, 3)
	check(e.party_state.resonance == 20, "Dos debilidades en área solo bonifican una vez por acción")
	e = encounter(null, 2)
	e.act(e.basic_attack(), 3)
	e.act(e.defend_action(), 0)
	var enemy_area := e.basic_attack()
	enemy_area.is_area = true
	enemy_area.label = "Área enemiga"
	e.fighters[3].data.abilities.append(enemy_area)
	e.act(enemy_area, 0)
	check(e.party_state.resonance == 40, "Área enemiga da 5 RE por cada uno de tres impactos recibidos")
	e = encounter()
	e.act(e.basic_attack(), 3)
	e.act(e.fighters[0].data.abilities[1], 1)
	check(e.party_state.resonance == 20, "Protección es especial: genera 10 RE")
	e.act(e.basic_attack(), 1)
	check(e.party_state.resonance == 25 and e.fighters[1].hp == 75, "Interceptación genera solo 5 RE para el impacto a Kael")
	e.party_state.resonance = 999
	check(e.party_state.resonance == 100, "RE se limita a 100")
	e.party_state.resonance = -10
	check(e.party_state.resonance == 0, "RE no baja de cero")
	var state := PartyState.test_party()
	state.resonance = 95
	e = encounter(state)
	e.fighters[3].hp = 1
	e.act(e.basic_attack(), 3)
	check(e.phase == BattleEngine.Phase.VICTORY and state.resonance == 100, "Generación saturada y victoria")
	var next := encounter(state)
	check(next.party_state == state and state.resonance == 100, "Misma partida traslada RE explícitamente a otro motor")
	check(next.fighters[3].hp == 280 and next.history.is_empty(), "Nuevo combate no hereda PV ni registro temporales")
	next.abort()
	check(state.resonance == 100 and not state.in_battle(), "Abandonar conserva RE y libera vínculo")
	check(PartyState.test_party().resonance == 0, "Nueva partida expresa reinicia RE")

func test_summon() -> void:
	var state := PartyState.test_party()
	var e := encounter(state)
	state.resonance = 99
	var before := snapshot(e)
	check(not e.summon().is_empty() and snapshot(e) == before, "Invocar con 99 RE se rechaza sin efectos secundarios")
	state.resonance = 100
	e.fighters[1].hp = 0
	before = snapshot(e)
	check(not e.summon().is_empty() and snapshot(e) == before, "Portador inconsciente no invoca")
	e.fighters[1].hp = 75
	e.act(e.defend_action(), 1)
	before = snapshot(e)
	check(not e.summon().is_empty() and snapshot(e) == before, "Kael sin vínculo no puede invocar")
	e.act(e.defend_action(), 0)
	before = snapshot(e)
	check(not e.summon().is_empty() and snapshot(e) == before, "Enemigo no puede invocar usando RE del grupo")
	e.abort()
	e = encounter(state, 3)
	e.fighters[4].data.resistances.clear()
	e.fighters[4].data.weaknesses = ["fire"]
	e.fighters[5].hp = 0
	for f in e.fighters:
		if f.enemy:
			f.data.strength = 0
	var received_events: Array[Dictionary] = []
	e.battle_event.connect(func(event: Dictionary) -> void: received_events.append(event))
	check(e.summon().is_empty(), "Invocación válida con 100 RE")
	check(state.resonance == 0 and e.current_id() == 0 and e.fighters[1].mp == 35, "Invocar consume 100 RE y turno sin PM ni regeneración por debilidad")
	check(e.fighters[3].hp == 260 and e.fighters[4].hp == 220 and e.fighters[5].hp == 0, "Ignar causa 20 contra resistencia y 60 contra debilidad, omite caídos")
	check(e.fighters[0].hp == 120 and e.fighters[1].hp == 75 and e.fighters[2].hp == 90, "Ignar no daña aliados")
	check(e.fighters[0].defense_down_rounds == 0 and e.fighters[1].defense_down_rounds == 0 and e.fighters[2].defense_down_rounds == 0, "Ignar tampoco reduce Defensa de aliados")
	check(e.fighters.size() == 6, "Guardián no se incorpora como combatiente")
	check(e.events.size() == 4 and e.events[0].type == "summon_appear" and e.events[1].type == "summon_effect" and e.events[3].type == "summon_disappear", "Eventos ordenados de aparición, dos efectos y retirada")
	check(received_events == e.events and e.events[1].hp_lost == 20 and e.events[2].hp_lost == 60, "Señal entrega eventos con objetivos y pérdida real de PV")
	check(e.fighters[3].physical_defense() == 9 and e.fighters[4].physical_defense() == 9, "DEF -25 % se aplica incluso al resistente al fuego")
	check(e.fighters[3].data.defense == 12 and e.fighters[3].defense_down_rounds == 3, "Debuff temporal no muta Resource ni comienza vencido")
	e.act(e.basic_attack(), 3)
	check(e.fighters[3].hp == 245, "Ataque físico usa DEF efectiva reducida: 24 menos 9")
	advance_to_round(e, 2)
	check(e.fighters[3].physical_defense() == 9, "Debuff activo primera ronda completa")
	advance_to_round(e, 3)
	check(e.fighters[3].physical_defense() == 9, "Debuff activo segunda ronda completa")
	advance_to_round(e, 4)
	check(e.fighters[3].physical_defense() == 12 and e.fighters[3].defense_down_amount == 0.0, "Debuff expira después de dos rondas completas")
	state.resonance = 100
	e.summon()
	advance_to_round(e, 5)
	state.resonance = 100
	e.summon()
	check(e.fighters[3].physical_defense() == 9 and e.fighters[3].defense_down_rounds == 3, "Reaplicar renueva duración sin acumular reducción")
	advance_to_round(e, 7)
	check(e.fighters[3].physical_defense() == 9, "Renovación dura dos rondas posteriores")
	advance_to_round(e, 8)
	check(e.fighters[3].physical_defense() == 12, "Renovación también expira")
	e.abort()
	e = encounter(state)
	state.resonance = 100
	e.fighters[3].data.resistances.clear()
	e.fighters[3].data.resistance = 999
	e.fighters[1].data.magic = 999
	e.fighters[3].data.defense = 11
	e.summon()
	check(e.fighters[3].hp == 240, "Base fija 40 de Ignar no depende de MAG/RES")
	check(e.fighters[3].physical_defense() == 8, "DEF reducida redondea hacia abajo: 11 por 0,75 = 8")
	e.abort()
	e = encounter(state)
	state.resonance = 100
	e.fighters[3].data.weaknesses.append("fire")
	before = snapshot(e)
	check(not e.summon().is_empty() and snapshot(e) == before, "Invocación con datos contradictorios no consume nada ni emite eventos")
	e.abort()
	e = encounter(state)
	e.fighters[3].hp = 1
	e.summon()
	check(e.phase == BattleEngine.Phase.VICTORY and state.progress("ignar").affinity == 50, "Invocación puede ganar y concede PA una vez")
	before = snapshot(e)
	check(not e.summon().is_empty() and snapshot(e) == before, "Invocar tras victoria no altera estado ni duplica premio")
	e = encounter(state)
	state.resonance = 100
	e.fighters[1].mp = 0
	check(e.summon().is_empty() and e.fighters[1].mp == 0, "Invocar funciona incluso con cero PM")
	e.abort()

func test_progress_and_binding() -> void:
	var state := PartyState.test_party()
	check(state.guardian_for("lyra").id == "ignar" and state.guardian_for("kael") == null, "Ignar inicialmente vinculado solo a Lyra")
	for pair in [[0, 1], [99, 1], [100, 2], [249, 2], [250, 3], [499, 3], [500, 4], [999, 4]]:
		state.progress("ignar").affinity = pair[0]
		check(state.guardian_level("lyra") == pair[1], "Umbral de PA %d corresponde a nivel %d" % pair)
	state.progress("ignar").affinity = 0
	for victory in range(10):
		var e := encounter(state)
		e.fighters[3].hp = 1
		e.act(e.basic_attack(), 3)
		check(state.progress("ignar").affinity == (victory + 1) * 50, "Victoria %d concede exactamente 50 PA" % (victory + 1))
		e._check_end()
		check(state.progress("ignar").affinity == (victory + 1) * 50, "Reevaluar victoria no duplica PA")
	check(state.guardian_level("lyra") == 4, "Diez victorias desbloquean nivel 4")
	check(state.equip("ignar", "kael").is_empty(), "Cambio de portador fuera de combate")
	check(state.guardian_for("lyra") == null and state.guardian_for("kael").id == "ignar" and state.guardian_level("kael") == 4, "Vínculo único conserva nivel y PA al transferir")
	var other := state.definition("ignar").duplicate(true) as GuardianData
	other.id = "test_guardian"
	check(state.register_guardian(other).is_empty(), "Definición adicional registrable mediante datos")
	check(not state.equip("test_guardian", "kael").is_empty() and state.guardian_for("kael").id == "ignar", "Cada héroe equipa como máximo un Guardián")
	var e := encounter(state)
	check(not state.equip("ignar", "nira").is_empty() and not state.unequip("kael").is_empty(), "Vincular y desvincular se bloquean durante combate")
	check(not state.register_guardian(other).is_empty(), "No se añaden Guardianes durante combate")
	var second := BattleEngine.new()
	var heroes: Array[CombatantData] = [e.fighters[0].data]
	var enemies: Array[CombatantData] = [e.fighters[3].data]
	check(not second.start(heroes, enemies, state).is_empty() and second.phase == BattleEngine.Phase.NOT_STARTED, "Una partida no puede estar en dos combates simultáneos")
	state.resonance = 100
	check(not e.summon().is_empty(), "Antiguo portador no puede invocar tras el cambio")
	e.act(e.basic_attack(), 3)
	check(e.summon().is_empty() and state.resonance == 0, "Nuevo portador vivo invoca durante su turno")
	e.abort()
	check(state.unequip("kael").is_empty() and state.guardian_for("kael") == null and state.progress("ignar").affinity == 500, "Desequipar conserva progreso")
	state.equip("ignar", "lyra")
	e = encounter(state)
	e.fighters[0].hp = 0
	e.fighters[2].hp = 0
	e.fighters[1].hp = 1
	e.act(e.basic_attack(), 3)
	e.step_enemy()
	check(e.phase == BattleEngine.Phase.DEFEAT and state.progress("ignar").affinity == 500 and not state.in_battle(), "Derrota no concede PA y libera vínculo")
	var retained_re := state.resonance
	e = encounter(state)
	check(state.resonance == retained_re, "RE también persiste después de derrota")
	e.act(e.basic_attack(), 3)
	e.fighters[1].hp = 0
	e.fighters[3].hp = 1
	e.act(e.basic_attack(), 3)
	check(e.phase == BattleEngine.Phase.VICTORY and state.progress("ignar").affinity == 550, "Portador equipado caído recibe PA al ganar el grupo")
	var fresh := PartyState.test_party()
	check(fresh.progress("ignar").affinity == 0 and fresh.guardian_level("lyra") == 1, "Nueva partida reinicia PA y nivel")
	fresh.unequip("lyra")
	e = encounter(fresh)
	e.fighters[3].hp = 1
	e.act(e.basic_attack(), 3)
	check(fresh.progress("ignar").affinity == 0, "Guardián no equipado no gana PA por victoria")

func fire_received(state: PartyState, natural_resistance: bool = false) -> int:
	var e := encounter(state)
	if natural_resistance:
		e.fighters[1].data.resistances.append("fire")
	var fire := BattleAbility.new()
	fire.label = "Fuego enemigo"
	fire.effect = "magic"
	fire.element = "fire"
	fire.power = 10
	e.fighters[3].data.magic = 30
	e.fighters[3].data.abilities.append(fire)
	e.act(e.basic_attack(), 3)
	e.act(e.basic_attack(), 3)
	e.act(fire, 1)
	var lost := 75 - e.fighters[1].hp
	e.abort()
	return lost

func test_passives() -> void:
	var state := PartyState.test_party()
	check(fire_received(state) == 22, "Nivel 1 reduce fuego recibido un 10 %: floor(25 por 0,9)")
	check(fire_received(state, true) == 11, "Resistencia pasiva multiplica afinidad natural antes de redondear")
	state.unequip("lyra")
	check(fire_received(state) == 25, "Desequipar desactiva resistencia pasiva")
	state.equip("ignar", "kael")
	check(fire_received(state) == 25, "Antiguo portador deja de recibir pasiva")
	state.equip("ignar", "lyra")
	var e := encounter(state)
	e.act(e.fighters[1].data.abilities[0], 3)
	check(e.fighters[3].hp == 266, "Nivel 1 aún no mejora daño de fuego")
	e.abort()
	state.progress("ignar").affinity = 100
	e = encounter(state)
	e.act(e.fighters[1].data.abilities[0], 3)
	check(e.fighters[3].hp == 265, "Nivel 2 aumenta fuego 10 %: floor(28 por 0,5 por 1,1) = 15")
	e.abort()
	state.unequip("lyra")
	e = encounter(state)
	e.act(e.fighters[1].data.abilities[0], 3)
	check(e.fighters[3].hp == 266, "Desequipar desactiva mejora ofensiva")
	e.abort()
	state.equip("ignar", "lyra")
	for affinity in [100, 250]:
		state.progress("ignar").affinity = affinity
		state.resonance = 0
		e = encounter(state, 2)
		for f in e.fighters:
			if f.enemy:
				f.data.resistances.clear()
				f.data.weaknesses = ["fire"]
		var area := e.fighters[1].data.abilities[0].duplicate(true) as BattleAbility
		area.is_area = true
		e.fighters[1].data.abilities.append(area)
		e.act(area, 3)
		check(state.resonance == (25 if affinity == 250 else 20), "Pasiva de nivel 3 añade 5 RE una vez por acción de debilidad al fuego")
		check(e.fighters[3].hp == 234 and e.fighters[4].hp == 234, "Mejora de fuego se aplica a todos los objetivos")
		e.abort()
	state.resonance = 0
	e = encounter(state)
	e.act(e.fighters[1].data.abilities[1], 3)
	check(state.resonance == 20, "Resonancia Ardiente no bonifica debilidades de hielo")
	e.abort()
	state.unequip("lyra")
	state.resonance = 0
	e = encounter(state)
	e.fighters[3].data.resistances.clear()
	e.fighters[3].data.weaknesses = ["fire"]
	e.act(e.fighters[1].data.abilities[0], 3)
	check(state.resonance == 20, "Desequipar desactiva Resonancia Ardiente")
	e.abort()
	state.equip("ignar", "lyra")
	state.progress("ignar").affinity = 500
	state.resonance = 100
	e = encounter(state, 2)
	e.fighters[4].data.resistances.clear()
	e.fighters[4].data.weaknesses = ["fire"]
	e.summon()
	check(e.fighters[3].hp == 256 and e.fighters[4].hp == 208, "Nivel 4: base 48 de invocación causa 24/72, sin aplicar pasiva del portador")
	check(state.resonance == 0, "Invocación de nivel 4 tampoco genera RE por debilidad ni pasiva")
	check(state.definition("ignar").base_damage == 40 and state.definition("ignar").defense_reduction == 0.25, "Invocar y progresar no muta la definición del Guardián")
	e.abort()
	# Passive resistance follows the actual interceptor, not the original target.
	state.equip("ignar", "kael")
	state.resonance = 0
	e = encounter(state)
	var fire := BattleAbility.new()
	fire.label = "Fuego enemigo"
	fire.effect = "magic"
	fire.element = "fire"
	fire.power = 10
	e.fighters[3].data.magic = 30
	e.fighters[3].data.abilities.append(fire)
	e.act(e.basic_attack(), 3)
	e.act(e.fighters[0].data.abilities[1], 1)
	e.act(fire, 1)
	check(e.fighters[0].hp == 106 and e.fighters[1].hp == 75, "Sangre de Fuego sigue al interceptor: floor(32 por 0,9), luego mitad = 14")
	check(state.resonance == 25, "Pasiva defensiva e interceptación conservan generación por un solo impacto")
	e.abort()
