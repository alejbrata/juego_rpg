extends RefCounted

var _tree: SceneTree
var _verify: Callable

func check(condition: bool, description: String) -> void:
	_verify.call(condition, description)

func settle(stage: Node3D) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while (stage.playing or not stage.event_queue.is_empty()) and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	check(not stage.playing and stage.event_queue.is_empty(), "La cola visual termina sin bloquear el combate")
	await _tree.create_timer(0.04).timeout

func played(stage: Node3D, type: String, effect: String = "") -> bool:
	for event in stage.played_events:
		if event.type == type and (effect.is_empty() or event.get("effect", "") == effect):
			return true
	return false

func state(engine: BattleEngine) -> Dictionary:
	return preload("res://tests/guardian_checks.gd").new().snapshot(engine)

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_verify = verify
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	stage.animation_time_scale = 0.02
	_tree.root.add_child(stage)
	await _tree.process_frame
	var ui = stage.hud
	check(stage is Node3D and stage.get_node("BattleCamera") is Camera3D, "Escena 3D carga con cámara fija")
	check(stage.visuals.size() == 4 and stage.get_node("Overlay") is CanvasLayer, "Escena tiene cuatro actores visuales y UI superpuesta")
	check(stage.visuals[0].home.x < 0 and stage.visuals[3].home.x > 0, "Héroes y enemigo ocupan lados opuestos")
	check(stage.visuals[1].caption.text.contains("Vínculo: Ignar") and stage.visuals[1].turn_ring.visible, "Etiqueta de Lyra indica vínculo y turno activo")
	check(stage.visuals[0].caption.text.contains("PV 120/120 · PM 12/12"), "Representación muestra PV y PM del motor")
	ui.actions.get_child(0).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	var resolved := state(ui.engine)
	check(ui.engine.fighters[3].hp == 279 and ui.engine.current_id() == 0, "Acción se resuelve antes de reproducir su animación")
	check(ui.presentation_busy and ui.actions.get_child(0).disabled, "Botones de acción se desactivan durante presentación")
	check(ui.status.text.contains("Acción de Lyra"), "Cabecera identifica acción en curso durante la animación")
	await settle(stage)
	check(played(stage, "action", "physical") and played(stage, "damage"), "Ataque físico e impacto llegan a la capa visual")
	check(state(ui.engine) == resolved, "Animaciones de ataque no cambian el resultado lógico")
	check(stage.visuals[0].turn_ring.visible and not ui.actions.get_child(0).disabled, "Fin de animación señala nuevo actor y restaura controles")
	ui.actions.get_child(1).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	await settle(stage)
	check(played(stage, "action", "guard") and stage.visuals[0].shield.visible and stage.visuals[0].caption.text.contains("DEFENDIENDO"), "Defender se anima y deja indicación persistente")
	ui.actions.get_child(0).pressed.emit() # Enemy turn.
	await settle(stage)
	check(stage.visuals[0].caption.text.contains("PV 113/120"), "Impacto enemigo actualiza PV visuales desde el motor")
	ui.actions.get_child(2).pressed.emit() # Nira: heal Kael.
	ui.targets.get_child(0).pressed.emit()
	resolved = state(ui.engine)
	await settle(stage)
	check(played(stage, "action", "heal") and played(stage, "heal") and stage.visuals[0].caption.text.contains("PV 120/120"), "Curación produce evento y actualización visual diferenciados")
	check(state(ui.engine) == resolved, "Presentar curación no altera PV, PM ni RE")
	ui.actions.get_child(2).pressed.emit() # Lyra: flame.
	ui.targets.get_child(0).pressed.emit()
	await settle(stage)
	check(played(stage, "action", "magic") and ui.engine.fighters[3].hp == 265, "Magia elemental se presenta conservando daño resistente de 14")
	check(not stage.visuals[0].shield.visible, "Defensa visual expira con el estado del motor")
	ui.actions.get_child(3).pressed.emit() # Kael: protect Lyra.
	ui.targets.get_child(1).pressed.emit()
	await settle(stage)
	check(played(stage, "action", "protect") and stage.visuals[0].caption.text.contains("Protege a Lyra"), "Protección muestra al protector")
	check(stage.visuals[1].caption.text.contains("Protegido por Kael") and stage._links.get_child_count() == 1, "Aliada protegida y vínculo espacial quedan indicados")
	# The provisional AI targets Kael. Issue a valid enemy attack against Lyra
	# directly to verify interception without changing the AI's design.
	ui.engine.act(ui.engine.basic_attack(), 1)
	ui._refresh()
	resolved = state(ui.engine)
	await settle(stage)
	check(played(stage, "intercept") and ui.engine.fighters[0].hp == 113 and ui.engine.fighters[1].hp == 75, "Interceptación visual respeta el receptor real y daño resuelto")
	check(stage._links.get_child_count() == 0 and stage.visuals[0].position.is_equal_approx(stage.visuals[0].home), "Tras interceptar se limpia vínculo y se restaura posición")
	check(state(ui.engine) == resolved, "Movimiento de interceptación no altera lógica")
	ui.engine.fighters[3].hp = 1
	ui.actions.get_child(0).pressed.emit() # Nira's minimum damage wins.
	ui.targets.get_child(0).pressed.emit()
	await settle(stage)
	check(ui.engine.phase == BattleEngine.Phase.VICTORY and stage.visuals[3].caption.text.contains("INCONSCIENTE"), "Victoria e inconsciencia visibles sin cambiar condición de fin")
	check(is_equal_approx(stage.visuals[3].body.rotation.z, PI * 0.5) and not stage.visuals[3].turn_ring.visible, "Combatiente caído queda tumbado y sin indicador de turno")
	ui._new_party()
	ui.actions.get_child(2).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	await _tree.process_frame # Reset while an animation is already in flight.
	await _tree.process_frame
	check(stage.playing, "Reinicio de prueba sucede con una secuencia realmente en curso")
	ui._new_party()
	await settle(stage)
	await _tree.create_timer(0.06).timeout
	check(ui.engine.fighters[3].hp == 280 and ui.engine.current_id() == 1 and ui.engine.history.is_empty(), "Reiniciar durante animación conserva el nuevo combate limpio")
	check(stage.event_queue.is_empty() and stage.played_events.is_empty() and stage._effects.get_child_count() == 0, "Reinicio cancela eventos y efectos de la batalla anterior")
	var heroes: Array[CombatantData] = [preload("res://data/kael.tres"), preload("res://data/lyra.tres"), preload("res://data/nira.tres")]
	var enemies: Array[CombatantData] = [preload("res://data/sentinel.tres"), preload("res://data/sentinel.tres")]
	ui.engine.start(heroes, enemies, ui.run)
	ui.battle_reset.emit()
	ui.run.resonance = 100
	ui._refresh()
	check(stage.visuals.size() == 5 and stage.visuals[3].home.z != stage.visuals[4].home.z, "Formación visual admite múltiples enemigos")
	ui.actions.get_child(4).pressed.emit()
	resolved = state(ui.engine)
	await _tree.process_frame
	await _tree.process_frame
	check(is_instance_valid(stage._ignar), "Evento de aparición crea manifestación distinta de Ignar")
	await settle(stage)
	var targets: Array[int] = []
	for event in stage.played_events:
		if event.type == "summon_effect":
			targets.append(event.target_id)
	check(played(stage, "summon_appear") and played(stage, "summon_disappear") and targets == [3, 4], "Ignar se presenta, afecta visualmente a cada enemigo y se retira")
	check(stage.visuals[3].caption.text.contains("DEF reducida") and stage.visuals[4].caption.text.contains("DEF reducida"), "Ambos enemigos muestran reducción de Defensa")
	check(not is_instance_valid(stage._ignar) and stage._effects.get_child_count() == 0, "Manifestación y efectos temporales se eliminan")
	check(state(ui.engine) == resolved and ui.run.resonance == 0, "Secuencia de Ignar no vuelve a aplicar daño ni a gastar recursos")
	resolved = state(ui.engine)
	var visual_count: int = stage.played_events.size()
	check(not ui.engine.summon().is_empty(), "Invocación inválida sigue siendo rechazada")
	check(state(ui.engine) == resolved and stage.event_queue.is_empty() and stage.played_events.size() == visual_count, "Acción rechazada no dispara efectos visuales")
	ui._new_party()
	ui.engine.fighters[0].mp = 0
	ui.engine.fighters[1].mp = 0
	ui._refresh()
	check(ui.actions.get_child(2).disabled and ui.actions.get_child(3).disabled, "UI 3D respeta PM insuficientes")
	ui.actions.get_child(0).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	await settle(stage)
	check(ui.actions.get_child(2).disabled and ui.actions.get_child(3).disabled and not ui.actions.get_child(0).disabled, "Desbloquear tras animación conserva validación de PM del siguiente actor")
	check(preload("res://data/flame.tres").element == "fire" and preload("res://data/flame.tres").cost == 8, "Pruebas aisladas no contaminan las habilidades precargadas por escenas")
	stage.free()
	await _tree.process_frame
