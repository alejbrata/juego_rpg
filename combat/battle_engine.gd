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

func start(heroes: Array[CombatantData], enemies: Array[CombatantData]) -> void:
	fighters.clear()
	history.clear()
	round_number = 0
	for data in heroes:
		fighters.append(Fighter.new(data, false))
	for data in enemies:
		fighters.append(Fighter.new(data, true))
	if not _check_end():
		_new_round()

func current_id() -> int:
	return order[cursor] if cursor < order.size() else -1

func basic_attack() -> BattleAbility:
	var action := BattleAbility.new()
	action.label = "Ataque"
	return action

func defend_action() -> BattleAbility:
	var action := BattleAbility.new()
	action.label = "Defender"
	action.effect = "guard"
	action.target_kind = "self"
	return action

func valid_targets(action: BattleAbility) -> Array[int]:
	var result: Array[int] = []
	if current_id() < 0 or action == null:
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
	var is_basic := action.effect == "physical" and action.label == "Ataque" and action.cost == 0 and action.power == 0 and action.target_kind == "enemy"
	var is_defend := action.effect == "guard" and action.label == "Defender" and action.cost == 0 and action.target_kind == "self"
	if not is_basic and not is_defend and not actor.data.abilities.has(action):
		return "Habilidad no disponible."
	if action.cost < 0 or actor.mp < action.cost:
		return "PM insuficientes."
	if not valid_targets(action).has(target_id):
		return "Objetivo inválido."
	if not action.effect in ["physical", "magic", "heal", "guard", "haste"]:
		return "Efecto desconocido."
	var target := fighters[target_id]
	actor.mp -= action.cost
	var detail := ""
	match action.effect:
		"physical", "magic":
			var offense := actor.data.strength if action.effect == "physical" else actor.data.magic
			var defense := target.data.defense if action.effect == "physical" else target.data.resistance
			var damage: int = maxi(1, offense + action.power - defense)
			if target.guarding:
				damage = maxi(1, ceili(damage * 0.5))
			target.hp = maxi(0, target.hp - damage)
			detail = "%d de daño" % damage
		"heal":
			var restored := mini(target.data.max_hp - target.hp, actor.data.magic + action.power)
			target.hp += restored
			detail = "%d PV recuperados" % restored
		"guard":
			target.guarding = true
			detail = "defensa activa"
		"haste":
			target.haste_rounds = 3
			detail = "+5 VEL durante las próximas dos rondas"
	history.append("%s → %s → %s: %s." % [actor.data.label, action.label, target.data.label, detail])
	if not _check_end():
		cursor += 1
		_select_turn()
	return ""

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
	phase = Phase.ENEMY_TURN if actor.enemy else Phase.WAITING_PLAYER
