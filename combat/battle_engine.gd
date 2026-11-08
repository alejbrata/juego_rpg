class_name BattleEngine
extends RefCounted

signal battle_event(event: Dictionary)

enum Phase { NOT_STARTED, WAITING_PLAYER, ENEMY_TURN, VICTORY, DEFEAT }

class Fighter extends RefCounted:
	var data: CombatantData
	var enemy: bool
	var hp: int
	var mp: int
	var guarding: bool = false
	var haste_rounds: int = 0
	var protection_target: int = -1
	var defense_down_rounds: int = 0
	var defense_down_amount: float = 0.0
	func _init(definition: CombatantData, is_enemy: bool) -> void:
		data = definition
		enemy = is_enemy
		hp = data.max_hp
		mp = data.max_mp

	func speed() -> int:
		return data.speed + (5 if haste_rounds > 0 else 0)

	func physical_defense() -> int:
		return floori(data.defense * (1.0 - defense_down_amount)) if defense_down_rounds > 0 else data.defense

var phase: Phase = Phase.NOT_STARTED
var fighters: Array[Fighter] = []
var order: Array[int] = []
var round_number: int = 0
var cursor: int = 0
var history: Array[String] = []
var events: Array[Dictionary] = []
var party_state := PartyState.new()
var _rewards_granted: bool = false

func start(heroes: Array[CombatantData], enemies: Array[CombatantData], run: PartyState = null) -> String:
	var next_run := run if run != null else party_state
	var hero_ids: Array[String] = []
	for data in heroes + enemies:
		if data == null:
			return "Combatiente inexistente."
		var error := data.validation_error()
		if not error.is_empty():
			return error
	for data in heroes:
		if not data.id.is_empty():
			if hero_ids.has(data.id):
				return "Identificador de héroe repetido."
			hero_ids.append(data.id)
		var guardian := next_run.guardian_for(data.id)
		if guardian != null and not guardian.validation_error().is_empty():
			return guardian.validation_error()
	var lock_error := next_run.begin_battle(self)
	if not lock_error.is_empty():
		return lock_error
	if party_state != next_run:
		party_state.end_battle(self)
	party_state = next_run
	fighters.clear()
	history.clear()
	events.clear()
	_rewards_granted = false
	order.clear()
	cursor = 0
	round_number = 0
	for data in heroes:
		fighters.append(Fighter.new(data, false))
	for data in enemies:
		fighters.append(Fighter.new(data, true))
	if not _check_end():
		_new_round()
	return ""

func abort() -> void:
	# Explicit abandonment: keep RE/PA, release equipment lock, grant no reward.
	party_state.end_battle(self)
	phase = Phase.NOT_STARTED

func current_id() -> int:
	return order[cursor] if cursor < order.size() else -1

func basic_attack() -> BattleAbility:
	var action := BattleAbility.new()
	action.label = "Ataque"
	action.element = "physical"
	return action

func defend_action() -> BattleAbility:
	var action := BattleAbility.new()
	action.label = "Defender"
	action.effect = "guard"
	action.target_kind = "self"
	return action

func valid_targets(action: BattleAbility) -> Array[int]:
	var result: Array[int] = []
	if not phase in [Phase.WAITING_PLAYER, Phase.ENEMY_TURN] or current_id() < 0 or action == null:
		return result
	var actor := fighters[current_id()]
	for i in range(fighters.size()):
		var target := fighters[i]
		if target.hp <= 0:
			continue
		if (action.target_kind == "self" and i == current_id()) or (action.target_kind == "ally" and target.enemy == actor.enemy) or (action.target_kind == "enemy" and target.enemy != actor.enemy):
			result.append(i)
	return result

# Returns an error without changing any state when validation fails.
func act(action: BattleAbility, target_id: int) -> String:
	if phase != Phase.WAITING_PLAYER and phase != Phase.ENEMY_TURN:
		return "No hay un turno activo."
	var actor := fighters[current_id()]
	if actor.hp <= 0:
		return "El actor está inconsciente."
	if action == null:
		return "Acción inexistente."
	var is_basic := action.effect == "physical" and action.label == "Ataque" and action.cost == 0 and action.power == 0 and action.target_kind == "enemy" and action.element == "physical" and not action.is_area
	var is_defend := action.effect == "guard" and action.label == "Defender" and action.cost == 0 and action.target_kind == "self" and not action.is_area
	if not is_basic and not is_defend and not actor.data.abilities.has(action):
		return "Habilidad no disponible."
	if action.cost < 0 or actor.mp < action.cost:
		return "PM insuficientes."
	if not valid_targets(action).has(target_id):
		return "Objetivo inválido."
	if not action.effect in ["physical", "magic", "heal", "guard", "protect", "haste"]:
		return "Efecto desconocido."
	if not action.element in ["physical", "fire", "ice", "neutral"]:
		return "Elemento desconocido."
	if action.is_area and (not action.effect in ["physical", "magic"] or action.target_kind != "enemy"):
		return "Área solo disponible para ataques ofensivos contra enemigos."
	if action.effect == "protect" and action.target_kind != "ally":
		return "Protección requiere un aliado."
	# Validate all data before mutating resources, turn, statuses or log.
	for fighter in fighters:
		var error := fighter.data.validation_error()
		if not error.is_empty():
			return error
	var target := fighters[target_id]
	var old_mp := actor.mp
	var old_re := party_state.resonance
	actor.mp -= action.cost
	var detail := ""
	var exploited_weakness := false
	match action.effect:
		"physical", "magic":
			var recipients: Array[int] = []
			if action.is_area:
				recipients = valid_targets(action)
			else:
				recipients.append(target_id)
			for recipient_id in recipients:
				var hit_weakness := _damage(actor, action, recipient_id)
				exploited_weakness = exploited_weakness or hit_weakness
			detail = "daño registrado"
		"heal":
			var old_hp := target.hp
			var restored := mini(target.data.max_hp - target.hp, actor.data.magic + action.power)
			target.hp += restored
			detail = "%s PV %d → %d (+%d)" % [target.data.label, old_hp, target.hp, restored]
		"guard":
			target.guarding = true
			detail = "defensa activa"
		"protect":
			actor.protection_target = target_id
			detail = "Protección preparada hasta el próximo turno de %s" % actor.data.label
		"haste":
			target.haste_rounds = 3
			detail = "+5 VEL durante las próximas dos rondas"
	if not actor.enemy:
		party_state.resonance += 15 if action.effect == "guard" else 10
		if exploited_weakness:
			party_state.resonance += 10
			var guardian := _guardian(actor)
			if guardian != null and action.element == guardian.element and party_state.guardian_level(actor.data.id) >= 3:
				party_state.resonance += guardian.weakness_re_bonus
	history.append("%s → %s [%s] → %s: %s. PM %d → %d (%+d). RE %d → %d." % [actor.data.label, action.label, action.element, target.data.label, detail, old_mp, actor.mp, actor.mp - old_mp, old_re, party_state.resonance])
	_finish_turn()
	return ""

func _finish_turn() -> void:
	if not _check_end():
		cursor += 1
		_select_turn()

func _guardian(fighter: Fighter) -> GuardianData:
	return party_state.guardian_for(fighter.data.id) if not fighter.enemy else null

func _damage(actor: Fighter, action: BattleAbility, target_id: int, summon_base: int = -1) -> bool:
	var target := fighters[target_id]
	var intercepted := false
	if actor.enemy and not target.enemy and not action.is_area:
		for protector in fighters:
			if not protector.enemy and protector.hp > 0 and protector.protection_target == target_id:
				history.append("Protección: %s intercepta el ataque contra %s." % [protector.data.label, target.data.label])
				protector.protection_target = -1
				target = protector
				intercepted = true
				break
	var offense := actor.data.strength if action.effect == "physical" else actor.data.magic
	var defense := target.physical_defense() if action.effect == "physical" else target.data.resistance
	var damage := maxi(1, offense + action.power - defense) if summon_base < 0 else summon_base
	var multiplier := target.data.element_multiplier(action.element)
	var attacker_guardian := _guardian(actor)
	if summon_base < 0 and attacker_guardian != null and action.element == attacker_guardian.element and party_state.guardian_level(actor.data.id) >= 2:
		multiplier *= 1.0 + attacker_guardian.damage_bonus
	var defender_guardian := _guardian(target)
	if defender_guardian != null and action.element == defender_guardian.element:
		multiplier *= 1.0 - defender_guardian.resistance_bonus
	damage = maxi(1, floori(damage * multiplier))
	# Interception and Defender never stack; self-protection follows the same path.
	if intercepted or target.guarding:
		damage = maxi(1, ceili(damage * 0.5))
	var old_hp := target.hp
	target.hp = maxi(0, target.hp - damage)
	if not target.enemy and target.hp < old_hp:
		party_state.resonance += 5
	history.append("%s → %s [%s]: %d de daño; PV %d → %d (%+d)." % [action.label, target.data.label, action.element, damage, old_hp, target.hp, target.hp - old_hp])
	return target.hp < old_hp and target.data.element_multiplier(action.element) > 1.0

func summon() -> String:
	if phase != Phase.WAITING_PLAYER or current_id() < 0:
		return "No es un turno del grupo protagonista."
	var actor := fighters[current_id()]
	if actor.hp <= 0:
		return "El portador está inconsciente."
	var guardian := _guardian(actor)
	if guardian == null:
		return "El actor no tiene un Guardián equipado."
	if party_state.resonance < 100:
		return "Se necesitan 100 RE."
	var error := guardian.validation_error()
	if not error.is_empty():
		return error
	for fighter in fighters:
		error = fighter.data.validation_error()
		if not error.is_empty():
			return error
	var recipients: Array[int] = []
	for i in range(fighters.size()):
		if fighters[i].enemy and fighters[i].hp > 0:
			recipients.append(i)
	if recipients.is_empty():
		return "No hay enemigos vivos."
	party_state.resonance -= 100
	var base := guardian.base_damage
	if party_state.guardian_level(actor.data.id) >= 4:
		base = floori(base * (1.0 + guardian.summon_base_bonus))
	var action := BattleAbility.new()
	action.label = guardian.summon_label
	action.effect = "magic"
	action.element = guardian.element
	action.is_area = true
	history.append("%s invoca a %s: ¡%s! RE 100 → 0. PM %d → %d." % [actor.data.label, guardian.label, guardian.summon_label, actor.mp, actor.mp])
	_emit_event({"type": "summon_appear", "guardian_id": guardian.id, "actor_id": current_id()})
	for target_id in recipients:
		var target := fighters[target_id]
		var old_hp := target.hp
		_damage(actor, action, target_id, base)
		target.defense_down_amount = guardian.defense_reduction
		target.defense_down_rounds = guardian.debuff_rounds + 1
		history.append("%s: Defensa física -%d%% (%d → %d), próximas %d rondas completas." % [target.data.label, roundi(guardian.defense_reduction * 100), target.data.defense, target.physical_defense(), guardian.debuff_rounds])
		_emit_event({"type": "summon_effect", "guardian_id": guardian.id, "target_id": target_id, "element": action.element, "hp_lost": old_hp - target.hp, "defense_reduction": guardian.defense_reduction})
	_emit_event({"type": "summon_disappear", "guardian_id": guardian.id})
	_finish_turn()
	return ""

func _emit_event(event: Dictionary) -> void:
	events.append(event)
	battle_event.emit(event.duplicate(true))

func step_enemy() -> void:
	if phase == Phase.ENEMY_TURN:
		var action := basic_attack()
		var targets := valid_targets(action)
		if not targets.is_empty():
			act(action, targets[0])

func _check_end() -> bool:
	var heroes_alive := false
	var enemies_alive := false
	for fighter in fighters:
		if fighter.hp > 0:
			if fighter.enemy:
				enemies_alive = true
			else:
				heroes_alive = true
	if not heroes_alive:
		phase = Phase.DEFEAT
	elif not enemies_alive:
		phase = Phase.VICTORY
	else:
		return false
	if phase == Phase.VICTORY and not _rewards_granted and round_number > 0:
		_rewards_granted = true
		var character_ids: Array[String] = []
		for fighter in fighters:
			if not fighter.enemy and not fighter.data.id.is_empty():
				character_ids.append(fighter.data.id)
		party_state.reward_victory(character_ids)
		for character_id in character_ids:
			var guardian := party_state.guardian_for(character_id)
			if guardian != null:
				history.append("Victoria: %s +50 PA; total %d PA, nivel %d." % [guardian.label, party_state.progress(guardian.id).affinity, party_state.guardian_level(character_id)])
	party_state.end_battle(self)
	return true

func _new_round() -> void:
	round_number += 1
	order.clear()
	for i in range(fighters.size()):
		if fighters[i].hp > 0:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if fighters[a].speed() == fighters[b].speed():
			return a < b
		return fighters[a].speed() > fighters[b].speed())
	cursor = 0
	_select_turn()

func _select_turn() -> void:
	while cursor < order.size() and fighters[order[cursor]].hp <= 0:
		cursor += 1
	if cursor >= order.size():
		for fighter in fighters:
			fighter.haste_rounds = maxi(0, fighter.haste_rounds - 1)
			fighter.defense_down_rounds = maxi(0, fighter.defense_down_rounds - 1)
			if fighter.defense_down_rounds == 0:
				fighter.defense_down_amount = 0.0
		_new_round()
		return
	var actor := fighters[current_id()]
	actor.guarding = false
	actor.protection_target = -1
	phase = Phase.ENEMY_TURN if actor.enemy else Phase.WAITING_PLAYER
