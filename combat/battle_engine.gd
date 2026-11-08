class_name BattleEngine
extends RefCounted

enum Phase { NOT_STARTED, WAITING_PLAYER, ENEMY_TURN, VICTORY, DEFEAT }

class Fighter extends RefCounted:
	var data: CombatantData
	var enemy: bool
	var hp: int
	var mp: int
	var guarding: bool = false
	var haste_rounds: int = 0
	var protection_target: int = -1
	func _init(definition: CombatantData, is_enemy: bool) -> void:
		data = definition
		enemy = is_enemy
		hp = data.max_hp
		mp = data.max_mp

	func speed() -> int:
		return data.speed + (5 if haste_rounds > 0 else 0)

var phase: Phase = Phase.NOT_STARTED
var fighters: Array[Fighter] = []
var order: Array[int] = []
var round_number: int = 0
var cursor: int = 0
var history: Array[String] = []

func start(heroes: Array[CombatantData], enemies: Array[CombatantData]) -> String:
	for data in heroes + enemies:
		if data == null:
			return "Combatiente inexistente."
		var error := data.validation_error()
		if not error.is_empty():
			return error
	fighters.clear()
	history.clear()
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
	actor.mp -= action.cost
	var detail := ""
	match action.effect:
		"physical", "magic":
			var recipients: Array[int] = []
			if action.is_area:
				recipients = valid_targets(action)
			else:
				recipients.append(target_id)
			for recipient_id in recipients:
				_damage(actor, action, recipient_id)
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
	history.append("%s → %s [%s] → %s: %s. PM %d → %d (%+d)." % [actor.data.label, action.label, action.element, target.data.label, detail, old_mp, actor.mp, actor.mp - old_mp])
	if not _check_end():
		cursor += 1
		_select_turn()
	return ""

func _damage(actor: Fighter, action: BattleAbility, target_id: int) -> void:
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
	var defense := target.data.defense if action.effect == "physical" else target.data.resistance
	var damage := maxi(1, offense + action.power - defense)
	damage = maxi(1, floori(damage * target.data.element_multiplier(action.element)))
	# Interception and Defender never stack; self-protection follows the same path.
	if intercepted or target.guarding:
		damage = maxi(1, ceili(damage * 0.5))
	var old_hp := target.hp
	target.hp = maxi(0, target.hp - damage)
	history.append("%s → %s [%s]: %d de daño; PV %d → %d (%+d)." % [action.label, target.data.label, action.element, damage, old_hp, target.hp, target.hp - old_hp])

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
		_new_round()
		return
	var actor := fighters[current_id()]
	actor.guarding = false
	actor.protection_target = -1
	phase = Phase.ENEMY_TURN if actor.enemy else Phase.WAITING_PLAYER
