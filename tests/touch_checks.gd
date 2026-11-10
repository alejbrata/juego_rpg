extends RefCounted
## Iteration 1.6: touch controls. Real InputEventScreenTouch/Drag events (with
## finger indices) go through the same input nodes the game uses; the hero is moved
## by the existing CharacterBody3D. This is not a substitute for a device test.

const SIZES := [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(960, 540)]
var _tree: SceneTree
var _verify: Callable

func check(condition: bool, description: String) -> void:
	_verify.call(condition, "Táctil: " + description)

func touch(target: Node, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	target._input(event)

func drag(target: Node, index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	target._input(event)

func frames(count: int) -> void:
	for i in count:
		await _tree.physics_frame

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_verify = verify
	var previous: Variant = ProjectSettings.get_setting("visuals/touch/mode", "auto")
	conversion()
	ProjectSettings.set_setting("visuals/touch/mode", "off")
	var desktop = preload("res://scenes/forest_zone.tscn").instantiate()
	desktop.session.mission.intro_seen = true
	_tree.root.add_child(desktop)
	await _tree.process_frame
	check(not TouchControls.enabled() and desktop.joystick == null and not desktop.touch_ui, "en PC sin táctil no aparece el joystick")
	desktop.free()
	ProjectSettings.set_setting("visuals/touch/mode", "on")
	await exploration()
	await layouts()
	await scene_change()
	await battle()
	ProjectSettings.set_setting("visuals/touch/mode", previous)
	Input.emulate_touch_from_mouse = false

func conversion() -> void:
	var r := TouchJoystick.RADIUS
	check(TouchJoystick.to_vector(Vector2(r * 0.1, 0)) == Vector2.ZERO and TouchJoystick.to_vector(Vector2(0, -r * TouchJoystick.DEAD_ZONE * 0.9)) == Vector2.ZERO, "zona muerta ignora desplazamientos pequeños")
	check(TouchJoystick.to_vector(Vector2(r, 0)).is_equal_approx(Vector2.RIGHT) and is_equal_approx(TouchJoystick.to_vector(Vector2(0, r * 3)).length(), 1.0), "magnitud máxima 1 también fuera del radio")
	var analog := true
	for degrees in range(0, 360, 15):
		var direction := Vector2.from_angle(deg_to_rad(degrees))
		var half := TouchJoystick.to_vector(direction * r * 0.5)
		analog = analog and half.normalized().is_equal_approx(direction) and is_equal_approx(half.length(), (0.5 - TouchJoystick.DEAD_ZONE) / (1.0 - TouchJoystick.DEAD_ZONE))
	check(analog, "movimiento analógico en 360° con fuerza proporcional tras la zona muerta")

func exploration() -> void:
	var zone = preload("res://scenes/forest_zone.tscn").instantiate()
	_tree.root.add_child(zone)
	await _tree.process_frame
	var stick: TouchJoystick = zone.joystick
	check(zone.touch_ui and stick != null and zone.dialogue.active and not stick.visible, "joystick oculto durante la introducción")
	# Advancing the dialogue by tapping the text window.
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = false
	zone.dialogue.panel.gui_input.emit(tap)
	check(zone.dialogue.index == 1, "tocar la ventana de diálogo avanza una línea")
	zone.dialogue.skip()
	await frames(2)
	await _tree.process_frame
	check(stick.visible and zone.player.movement_enabled, "joystick disponible al terminar el diálogo")
	var start: Vector3 = zone.player.position
	var base := stick.get_global_rect().position + Vector2(120, stick.size.y - 120)
	touch(stick, 0, base, true)
	drag(stick, 0, base + Vector2(TouchJoystick.RADIUS, 0))
	await frames(10)
	var moved: Vector3 = zone.player.position - start
	check(stick.finger == 0 and stick.vector.is_equal_approx(Vector2.RIGHT) and moved.x > 0.4 and absf(moved.z) < 0.05, "arrastrar a la derecha mueve a Kael con la física existente")
	check(is_equal_approx(Vector2(zone.player.velocity.x, zone.player.velocity.z).length(), zone.player.movement_speed), "velocidad máxima igual que con teclado")
	# A second finger inside the stick area does not steal it; other drags ignored.
	touch(stick, 1, base + Vector2(20, -20), true)
	drag(stick, 1, base + Vector2(-60, 0))
	check(stick.finger == 0 and stick.vector.is_equal_approx(Vector2.RIGHT), "segundo dedo no altera el joystick")
	touch(stick, 1, base, false)
	# Releasing far outside the zone stops the hero (no residual motion).
	drag(stick, 0, Vector2(900, 100))
	touch(stick, 0, Vector2(900, 100), false)
	await frames(3)
	var stopped: Vector3 = zone.player.position
	await frames(5)
	check(stick.finger == -1 and stick.vector == Vector2.ZERO and zone.player.position.distance_to(stopped) < 0.01, "soltar fuera del área detiene el movimiento")
	# Keyboard still works with the touch interface on.
	Input.action_press("ui_right")
	await frames(6)
	var keyed: Vector3 = zone.player.position
	Input.action_release("ui_right")
	await frames(2)
	check(keyed.x > stopped.x + 0.2, "teclado sigue moviendo a Kael en modo táctil")
	# Hold the stick while tapping Interact with a second finger next to a clue.
	zone.player.position = zone.interests.camp.position + Vector3(0.9, 0, 0.6)
	await frames(3)
	await _tree.process_frame
	touch(stick, 0, base, true)
	drag(stick, 0, base + Vector2(0, -TouchJoystick.RADIUS * 0.4))
	var button: Button = zone.interact_button
	var centre := button.get_global_rect().get_center()
	check(button.visible and centre.x > _tree.root.get_visible_rect().size.x * 0.5 and not stick.get_global_rect().intersects(button.get_global_rect()), "botón de interacción a la derecha, fuera del área del joystick")
	touch(zone._fingers, 1, centre, true)
	touch(zone._fingers, 1, centre, false)
	await _tree.process_frame
	await frames(2)
	check(zone.dialogue.active and zone.dialogue.conversation_id == "camp" and not stick.visible and stick.finger == -1 and zone.player.velocity.length() < 0.01, "interactuar con otro dedo abre la pista, oculta el joystick y detiene a Kael")
	drag(stick, 0, base + Vector2(TouchJoystick.RADIUS, 0))
	await frames(3)
	check(stick.finger == -1 and not zone.player._use_external_input, "arrastres durante el diálogo no mueven al personaje")
	touch(stick, 0, base, false)
	while zone.dialogue.active:
		zone.dialogue.advance()
	await _tree.process_frame
	await _tree.process_frame
	check(stick.visible and zone.session.mission.investigated.has("camp"), "al cerrar la pista vuelve el control y la misión registra la pista")
	# Opening the menu while moving stops the hero and hides the stick.
	touch(stick, 0, base, true)
	drag(stick, 0, base + Vector2(TouchJoystick.RADIUS, 0))
	zone.toggle_menu()
	await _tree.process_frame
	await frames(2)
	check(not stick.visible and stick.finger == -1 and not zone.player._use_external_input, "abrir el menú mientras se mueve libera el joystick")
	zone.toggle_menu()
	zone.free()

func layouts() -> void:
	var original := _tree.root.size
	var original_scale := _tree.root.content_scale_factor
	for factor in [1.0, 1.3]:
		_tree.root.content_scale_factor = factor
		for size: Vector2i in SIZES:
			_tree.root.size = size
			var zone = preload("res://scenes/forest_zone.tscn").instantiate()
			zone.session.mission.intro_seen = true
			_tree.root.add_child(zone)
			await _tree.process_frame
			zone.player.position = zone.interests.camp.position + Vector3(0.9, 0, 0.6)
			await frames(3)
			await _tree.process_frame
			await _tree.process_frame
			var area: Rect2 = _tree.root.get_visible_rect()
			var stick: Rect2 = zone.joystick.get_global_rect()
			var others: Array[Rect2] = [zone.interact_button.get_global_rect(), zone._menu_button.get_global_rect(), zone._location_panel.get_global_rect()]
			var clear := area.encloses(stick) and stick.get_center().x < area.size.x * 0.5
			for rect in others:
				clear = clear and area.encloses(rect) and not stick.intersects(rect)
			check(clear and zone.interact_button.size.y >= 48 and zone._menu_button.size.y >= 48, "%dx%d ×%.2f: joystick a la izquierda sin tapar botones ni paneles" % [size.x, size.y, factor])
			zone.free()
	_tree.root.size = original
	_tree.root.content_scale_factor = original_scale
	await _tree.process_frame

func scene_change() -> void:
	var game = preload("res://scenes/forest_exploration.tscn").instantiate()
	_tree.root.add_child(game)
	await frames(4)
	var zone = game.zone
	zone.dialogue.skip()
	await frames(2)
	await _tree.process_frame
	var stick: TouchJoystick = zone.joystick
	var base := stick.get_global_rect().position + Vector2(120, stick.size.y - 120)
	touch(stick, 0, base, true)
	drag(stick, 0, base + Vector2(TouchJoystick.RADIUS, 0))
	await frames(2)
	game._on_encounter_requested(zone.encounters[0])
	await _tree.process_frame
	await frames(2)
	var battle_sticks: Array[Node] = game.battle.find_children("*", "TouchJoystick", true, false) if game.battle != null else []
	check(game.battle != null and battle_sticks.is_empty() and stick.finger == -1 and not zone.player._use_external_input, "entrar en combate con el dedo en el joystick lo libera y el combate no tiene joystick")
	touch(stick, 0, base + Vector2(TouchJoystick.RADIUS, 0), false)
	game._return_to_zone(true)
	await _tree.process_frame
	await frames(3)
	var at: Vector3 = zone.player.position
	await frames(5)
	check(stick.is_inside_tree() and stick.visible and stick.finger == -1 and zone.player.position.distance_to(at) < 0.01, "al volver del combate no queda movimiento residual")
	game.free()

func battle() -> void:
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	_tree.root.add_child(stage)
	await _tree.process_frame
	await _tree.process_frame
	var ui = stage.hud
	stage.set_skip_animations(true)
	var fingers: Node = ui.find_children("*", "Node", false, false).filter(func(n): return n is TouchControls.SecondaryFingers)[0]
	var engine: BattleEngine = ui.engine
	var before: Dictionary = preload("res://tests/guardian_checks.gd").new().snapshot(engine)
	# Every step by finger taps: command, target list, cancel, then act.
	var tap := func(button: Control) -> void:
		await _tree.process_frame
		await _tree.process_frame
		var point := button.get_global_rect().get_center()
		touch(fingers, 1, point, true)
		touch(fingers, 1, point, false)
	await tap.call(ui.actions.get_child(2))
	check(ui.targets.visible and ui.targets.get_child_count() == 1, "tocar Llama muestra solo el objetivo válido")
	await tap.call(ui._cancel)
	check(ui.actions.visible and preload("res://tests/guardian_checks.gd").new().snapshot(engine) == before, "tocar Atrás cancela sin gastar turno ni recursos")
	await tap.call(ui.actions.get_child(2))
	await tap.call(ui.targets.get_child(0))
	stage.skip_presentation()
	check(engine.fighters[3].hp < 280 and engine.fighters[1].mp == 27 and engine.current_id() == 0, "tocar habilidad y objetivo ejecuta la acción del motor")
	await tap.call(ui.actions.get_child(3))
	check(ui.targets.get_child_count() == 3, "Protección por toques ofrece los tres aliados")
	await tap.call(ui.targets.get_child(1))
	stage.skip_presentation()
	check(engine.fighters[0].protection_target == 1, "tocar un aliado aplica Protección")
	var buttons: Array[BaseButton] = []
	_collect(ui, buttons)
	var small := buttons.filter(func(b: BaseButton) -> bool: return b.size.y < 47.5 or b.size.x < 47.5)
	check(small.is_empty(), "todos los botones visibles del combate son táctiles (%d)" % buttons.size())
	await tap.call(ui.menu_button)
	check(ui.options_panel.visible, "menú de opciones accesible por toque")
	await tap.call(ui._return_button)
	check(not ui.options_panel.visible and engine.history.is_empty(), "reinicio/nueva partida desde el menú por toque")
	stage.free()

func _collect(node: Node, result: Array[BaseButton]) -> void:
	for child in node.get_children():
		if child is BaseButton and child.is_visible_in_tree():
			result.append(child)
		_collect(child, result)
