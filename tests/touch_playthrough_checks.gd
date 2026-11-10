extends RefCounted
## Iteration 1.6: the provisional mission played start to end with touch input only:
## dialogue buttons tapped, the hero walked with joystick drags, clues opened with
## the Interact button, both Sentinels fought by tapping commands, targets and the
## Guardian, and the anomaly closed. Engine/mission APIs are only read, never called.
## Headless simulation of touch events: it does not replace a test on a real phone.

var _tree: SceneTree
var _verify: Callable
var game: Node
var _taps := 0

func check(condition: bool, description: String) -> void:
	_verify.call(condition, "Recorrido táctil: " + description)

func event_touch(index: int, point: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	return event

## A finger tap on a button (finger 1, routed like any secondary finger).
func tap(fingers: Node, button: Control) -> bool:
	for i in 2:
		await _tree.process_frame
	if button == null or not button.is_visible_in_tree():
		return false
	var point := button.get_global_rect().get_center()
	fingers._input(event_touch(1, point, true))
	fingers._input(event_touch(1, point, false))
	_taps += 1
	await _tree.process_frame
	return true

func zone() -> Node:
	return game.zone

func finish_dialogue() -> int:
	var count := 0
	while zone().dialogue.active and count < 30:
		var button: Button = zone().dialogue.advance_button
		await tap(zone()._fingers, button)
		count += 1
	await _tree.process_frame
	await _tree.process_frame
	return count

## Joystick drags toward a point until reached (or a battle starts).
func walk(target: Vector2) -> bool:
	var stick: TouchJoystick = zone().joystick
	await _tree.process_frame
	await _tree.process_frame
	var base := stick.get_global_rect().position + Vector2(120, stick.size.y - 120)
	stick._input(event_touch(0, base, true))
	for frame in 600:
		if game.battle != null:
			return true
		var at := Vector2(zone().player.position.x, zone().player.position.z)
		if at.distance_to(target) < 0.15:
			break
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = base + (target - at).normalized() * TouchJoystick.RADIUS
		stick._input(drag)
		await _tree.physics_frame
	if is_instance_valid(stick) and stick.is_inside_tree():
		stick._input(event_touch(0, base, false))
	await _tree.physics_frame
	return Vector2(zone().player.position.x, zone().player.position.z).distance_to(target) < 0.2

func interact() -> bool:
	await _tree.process_frame
	await _tree.process_frame
	return await tap(zone()._fingers, zone().interact_button)

func fight() -> bool:
	for i in 30:
		if game.battle != null and game.battle.is_inside_tree():
			break
		await _tree.process_frame
	var stage = game.battle
	if stage == null:
		return false
	var ui = stage.hud
	var fingers: Node = ui.get_children().filter(func(n): return n is TouchControls.SecondaryFingers)[0]
	# Animations skipped from the options menu, by touch.
	if not ui.skip_option.button_pressed:
		await tap(fingers, ui.menu_button)
		await tap(fingers, ui.skip_option)
		await tap(fingers, ui.options_panel.get_child(0).get_child(ui.options_panel.get_child(0).get_child_count() - 1))
	var engine: BattleEngine = ui.engine
	var summoned := false
	var victory := false
	var defeated_before: int = game.session.defeated_encounters.size()
	for turn in 300:
		victory = victory or engine.phase == BattleEngine.Phase.VICTORY
		if victory or engine.phase == BattleEngine.Phase.DEFEAT or not is_instance_valid(ui):
			break
		for wait in 60:
			if not is_instance_valid(ui) or not ui.presentation_busy:
				break
			await _tree.process_frame
		victory = victory or engine.phase == BattleEngine.Phase.VICTORY
		if victory or not is_instance_valid(ui):
			break
		var actions: Array = ui.actions.get_children()
		if engine.phase == BattleEngine.Phase.ENEMY_TURN:
			await tap(fingers, actions[0])
			continue
		var actor := engine.fighters[engine.current_id()]
		var choice: Button = actions[0]
		if actions.size() > 4:
			choice = actions[4]   # Invocar a Ignar
			summoned = true
		elif actor.data.id in ["kael", "lyra"] and not actions[2].disabled:
			choice = actions[2]   # Golpe potente / Llama
		elif actor.data.id == "nira" and actor.hp > 0 and _hurt_ally(engine) >= 0 and not actions[2].disabled:
			choice = actions[2]   # Cura
		await tap(fingers, choice)
		if is_instance_valid(ui) and ui.targets.visible:
			var targets: Array = ui.targets.get_children()
			var pick: Button = targets[0]
			if choice == actions[2] and actor.data.id == "nira":
				var hurt := _hurt_ally(engine)
				for button: Button in targets:
					if String(button.get_meta("title")) == engine.fighters[hurt].data.label:
						pick = button
			await tap(fingers, pick)
	for i in 20:
		await _tree.process_frame
	victory = game.session.defeated_encounters.size() > defeated_before
	print("Recorrido táctil: victoria %s, invocación %s, ronda %d, modo %d, PV héroes %s" % [victory, summoned, engine.round_number, game.session.mode, engine.fighters.map(func(f): return f.hp)])
	return victory

func _hurt_ally(engine: BattleEngine) -> int:
	for i in engine.fighters.size():
		var f := engine.fighters[i]
		if not f.enemy and f.hp > 0 and f.hp * 2 < f.data.max_hp:
			return i
	return -1

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_verify = verify
	var previous: Variant = ProjectSettings.get_setting("visuals/touch/mode", "auto")
	ProjectSettings.set_setting("visuals/touch/mode", "on")
	game = preload("res://scenes/forest_exploration.tscn").instantiate()
	_tree.root.add_child(game)
	for i in 4:
		await _tree.physics_frame
	var lines := await finish_dialogue()
	check(not zone().dialogue.active and zone().session.mission.intro_seen and lines >= 2, "introducción avanzada tocando Continuar (%d toques)" % lines)
	var mission: ExpeditionMission = game.session.mission
	var route := [
		["camp", [Vector2(-4.5, 2.9)]],
		["inscription", [Vector2(-4.3, -2.8), Vector2(-2.6, -2.7)]],
		["crystal", [Vector2(0, -2.9), Vector2(3.1, -0.5)]],
	]
	for step: Array in route:
		var reached := true
		for point: Vector2 in step[1]:
			reached = reached and await walk(point)
		var opened := await interact()
		var conversation: String = zone().dialogue.conversation_id
		await finish_dialogue()
		check(reached and opened and conversation == step[0] and mission.investigated.has(step[0]), "pista %s alcanzada con el joystick y examinada con el botón" % step[0])
	# First Sentinel (on the path back to the clearing centre).
	await walk(Vector2(0, 1))
	check(game.battle != null and game.session.mode == GameSession.Mode.BATTLE, "caminar hasta el Centinela I abre el combate")
	var won := await fight()
	for i in 20:
		await _tree.process_frame
	check(won and game.battle == null and game.session.defeated_encounters.size() == 1 and zone().joystick.visible, "Centinela I vencido por toques y regreso al claro con joystick")
	await walk(Vector2(3.1, -0.5))
	await walk(Vector2(5, -2.8))
	won = await fight()
	for i in 20:
		await _tree.process_frame
	check(won and game.session.defeated_encounters.size() == 2, "Centinela II vencido por toques")
	var back := await walk(Vector2(3.1, -0.5))
	# Back through the cleared centre (Sentinel I) and north to the ruins.
	var near := await walk(Vector2(0, 1)) and await walk(Vector2(0, -2.6))
	await _tree.process_frame
	var opened := await interact()
	await finish_dialogue()
	check(back and near and opened and mission.completed and zone().hint.text.contains("continuará"), "anomalía activada y misión completada solo con toques (%d toques)" % _taps)
	game.free()
	ProjectSettings.set_setting("visuals/touch/mode", previous)
	Input.emulate_touch_from_mouse = false
