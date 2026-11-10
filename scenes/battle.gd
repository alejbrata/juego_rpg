extends Control

var engine := BattleEngine.new()
var run := PartyState.test_party()
var encounter_heroes: Array[CombatantData] = [preload("res://data/kael.tres"), preload("res://data/lyra.tres"), preload("res://data/nira.tres")]
var encounter_enemies: Array[CombatantData] = [preload("res://data/sentinel.tres")]
var selected: BattleAbility
var status: Label
var roster: Label
var actions: HFlowContainer
var targets: HFlowContainer
var log_view: RichTextLabel
var message: Label
var resonance_bar: ProgressBar
var guardian_info: Label

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 24)
	column.add_child(status)
	resonance_bar = ProgressBar.new()
	resonance_bar.max_value = 100
	resonance_bar.custom_minimum_size.y = 22
	column.add_child(resonance_bar)
	guardian_info = Label.new()
	column.add_child(guardian_info)
	roster = Label.new()
	column.add_child(roster)
	actions = HFlowContainer.new()
	column.add_child(actions)
	message = Label.new()
	column.add_child(message)
	targets = HFlowContainer.new()
	column.add_child(targets)
	log_view = RichTextLabel.new()
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.scroll_following = true
	column.add_child(log_view)
	var controls := HFlowContainer.new()
	column.add_child(controls)
	var restart := Button.new()
	restart.text = "Reiniciar combate"
	restart.custom_minimum_size.y = 48
	restart.pressed.connect(_restart)
	controls.add_child(restart)
	_add_button(controls, "Nueva partida (RE/PA a cero)", _new_party)
	_restart()

func _new_party() -> void:
	engine.abort()
	run = PartyState.test_party()
	_restart()

func _restart() -> void:
	var error := engine.start(encounter_heroes, encounter_enemies, run)
	if not error.is_empty():
		status.text = "Datos inválidos: " + error
		_clear(actions)
		_clear(targets)
		return
	selected = null
	_refresh()

func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	_clear(actions)
	_clear(targets)
	resonance_bar.value = run.resonance
	guardian_info.text = "Resonancia: %d/100 RE" % run.resonance
	for fighter in engine.fighters:
		if fighter.enemy:
			continue
		var guardian := run.guardian_for(fighter.data.id)
		if guardian != null:
			guardian_info.text += " · %s: %s · nivel %d · %d PA" % [fighter.data.label, guardian.label, run.guardian_level(fighter.data.id), run.progress(guardian.id).affinity]
	roster.text = ""
	for fighter in engine.fighters:
		if engine.phase in [BattleEngine.Phase.WAITING_PLAYER, BattleEngine.Phase.ENEMY_TURN] and fighter == engine.fighters[engine.current_id()]:
			roster.text += "▶ TURNO ACTIVO: "
		roster.text += "%s%s   PV %d/%d   PM %d/%d   VEL %d%s%s\n" % ["Enemigo: " if fighter.enemy else "", fighter.data.label, fighter.hp, fighter.data.max_hp, fighter.mp, fighter.data.max_mp, fighter.speed(), "  [Defensa]" if fighter.guarding else "", "  [Inconsciente]" if fighter.hp == 0 else ""]
		if fighter.protection_target >= 0 and fighter.hp > 0:
			roster.text += "    Protección → %s\n" % engine.fighters[fighter.protection_target].data.label
		if fighter.defense_down_rounds > 0:
			roster.text += "    DEF %d → %d (reducida)\n" % [fighter.data.defense, fighter.physical_defense()]
	log_view.text = "\n".join(engine.history)
	message.text = ""
	if engine.phase == BattleEngine.Phase.VICTORY or engine.phase == BattleEngine.Phase.DEFEAT:
		status.text = "¡Victoria!" if engine.phase == BattleEngine.Phase.VICTORY else "Derrota"
		return
	var actor := engine.fighters[engine.current_id()]
	status.text = "Ronda %d · Turno de %s" % [engine.round_number, actor.data.label]
	if engine.phase == BattleEngine.Phase.ENEMY_TURN:
		_add_enemy_step(actor, func() -> void:
			engine.step_enemy()
			selected = null
			_refresh())
		return
	message.text = "Elige una acción y después un objetivo."
	var options: Array[BattleAbility] = [engine.basic_attack(), engine.defend_action()]
	options.append_array(actor.data.abilities)
	for ability in options:
		var button := _add_action(ability, actor, func() -> void: _choose(ability))
		button.disabled = actor.mp < ability.cost
	if run.resonance == 100 and run.guardian_for(actor.data.id) != null and actor.hp > 0:
		var guardian := run.guardian_for(actor.data.id)
		_add_invoke(guardian, func() -> void:
			var error := engine.summon()
			if error.is_empty():
				selected = null
				_refresh()
				message.text = "¡%s: %s! Aparece, actúa y se retira." % [guardian.label, guardian.summon_label]
			else:
				message.text = error)

# Presentation hooks: which commands exist is decided above, once, for every UI.
func _add_enemy_step(_actor: BattleEngine.Fighter, callback: Callable) -> Button:
	return _add_button(actions, "Resolver turno enemigo", callback)

func _add_action(ability: BattleAbility, _actor: BattleEngine.Fighter, callback: Callable) -> Button:
	var element_label := " [%s]" % ability.element if ability.effect in ["physical", "magic"] else ""
	return _add_button(actions, "%s%s (%d PM)" % [ability.label, element_label, ability.cost], callback)

func _add_invoke(_guardian: GuardianData, callback: Callable) -> Button:
	return _add_button(actions, "Invocar · 100 RE", callback)

func _add_target(target_id: int, callback: Callable) -> Button:
	return _add_button(targets, engine.fighters[target_id].data.label, callback)

func _add_button(container: Container, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 48)
	button.pressed.connect(callback)
	container.add_child(button)
	return button

func _choose(ability: BattleAbility) -> void:
	selected = ability
	_clear(targets)
	message.text = "%s: selecciona objetivo" % ability.label
	for target_id in engine.valid_targets(ability):
		_add_target(target_id, func() -> void:
			var error := engine.act(selected, target_id)
			if error.is_empty():
				selected = null
				_refresh()
			else:
				message.text = error)
