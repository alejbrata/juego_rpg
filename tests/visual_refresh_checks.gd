extends RefCounted

var _tree: SceneTree
var _verify: Callable

func check(condition: bool, description: String) -> void:
	_verify.call(condition, description)

func buttons(node: Node, result: Array[BaseButton]) -> void:
	for child in node.get_children():
		if child is BaseButton and child.is_visible_in_tree():
			result.append(child)
		buttons(child, result)

func snapshot(engine: BattleEngine) -> Dictionary:
	return preload("res://tests/guardian_checks.gd").new().snapshot(engine)

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_verify = verify
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	_tree.root.add_child(stage)
	await _tree.process_frame
	var ui = stage.hud
	check(stage.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and stage.camera.position.x > 0, "Cámara diagonal usa perspectiva")
	check(not ui.camera_option.button_pressed, "Opción de cámara respeta configuración del inspector")
	var ids: Array[String] = []
	for visual in stage.visuals:
		ids.append(visual.visual_id)
		check(visual.model_pivot.get_meta("source_mesh_count") >= 25, "Modelo completo conserva geometría de anatomía/vestimenta antes de agrupar")
		check(visual.model_pivot.get_child_count() < 16, "Geometría estática agrupada reduce nodos de dibujo por actor")
	check(ids == ["kael", "lyra", "nira", "sentinel"], "Asociación visual mantiene identificadores de combatientes existentes")
	check(stage.visuals[0].weapon != null and stage.visuals[1].weapon != null and stage.visuals[2].weapon != null, "Héroes conservan accesorios animables diferenciados")
	check(stage.visuals[1].cape != null and stage.visuals[2].cape != null, "Lyra y Nira tienen capas separadas del cuerpo")
	check(stage.visuals[0].model_pivot.global_basis.z.x > 0 and stage.visuals[3].model_pivot.global_basis.z.x < 0, "Héroes y Centinela se orientan hacia el bando opuesto")
	check(not stage.visuals[0].caption.visible and not stage.visuals[0].nameplate.text.contains("PV") and stage.visuals[3].nameplate.text.contains("PV 280/280"), "Estadísticas completas dejan de superponerse a los modelos")
	check(ui.party_cards.size() == 3 and not ui.log_panel.visible, "Tarjetas del grupo y registro opcional sustituyen panel de depuración permanente")
	var original_size := _tree.root.size
	for size in [Vector2i(960, 640), Vector2i(1280, 720), Vector2i(800, 450)]:
		_tree.root.size = size
		await _tree.process_frame
		await _tree.process_frame
		var controls: Array[BaseButton] = []
		buttons(ui, controls)
		var inside := true
		for button in controls:
			inside = inside and Rect2(Vector2.ZERO, ui.size).encloses(button.get_global_rect().grow(-0.5))
		check(inside, "Controles accesibles dentro del viewport %dx%d" % [size.x, size.y])
		check(ui.actions.get_child(0).size.y >= 48 and ui._return_button.size.y >= 48, "Altura táctil lógica de 48 se mantiene al redistribuir UI")
		ui._choose(ui.engine.fighters[1].data.abilities[1])
		check(stage._target_marker.visible and ui.targets.visible and not ui.actions.visible, "Selección muestra aro de objetivo y sustituye comandos sin crecer verticalmente")
		ui._cancel_selection()
	_tree.root.size = original_size
	await _tree.process_frame
	var before := snapshot(ui.engine)
	ui._choose(ui.engine.basic_attack())
	ui._cancel_selection()
	check(snapshot(ui.engine) == before and not stage._target_marker.visible, "Cancelar selección no consume turno, PM ni RE")
	ui.actions.get_child(0).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	var resolved := snapshot(ui.engine)
	stage.set_skip_animations(true)
	await _tree.process_frame
	check(snapshot(ui.engine) == resolved and ui.engine.fighters[3].hp == 279, "Omitir acción ya resuelta no altera su resultado")
	check(not stage.playing and stage.event_queue.is_empty() and stage._effects.get_child_count() == 0 and not ui.presentation_busy, "Omisión libera controles sin esperar temporizadores de presentación")
	check(stage.camera.fov == 42 and stage.camera.h_offset == 0, "Omitir restaura encuadre de cámara")
	ui.toggle_log()
	check(ui.log_panel.visible and ui.log_view.text == "\n".join(ui.engine.history), "Registro completo conserva todo el historial del motor")
	ui.toggle_log()
	check(not ui.log_panel.visible, "Registro se cierra y deja libre la arena")
	stage.set_camera_motion_enabled(true)
	stage._camera_impact()
	stage.set_camera_motion_enabled(false)
	await _tree.process_frame
	await _tree.process_frame
	check(stage.camera.h_offset == 0 and stage.camera.fov == 42, "Desactivar cámara cancela también un impacto ya iniciado")
	ui._new_party()
	stage.set_skip_animations(false)
	stage.set_camera_motion_enabled(true)
	ui.run.resonance = 100
	ui._refresh()
	ui.actions.get_child(4).pressed.emit()
	resolved = snapshot(ui.engine)
	await _tree.process_frame
	await _tree.process_frame
	check(is_instance_valid(stage._ignar) and stage._ignar.get_meta("source_mesh_count") >= 25, "Invocación crea titán volcánico completo con geometría agrupada")
	stage.set_skip_animations(true)
	check(snapshot(ui.engine) == resolved and ui.engine.fighters[3].hp == 260 and ui.run.resonance == 0, "Omitir Ignar conserva daño, gasto de RE y reducción de Defensa")
	check(not is_instance_valid(stage._ignar) and stage._effects.get_child_count() == 0 and stage.camera.fov == 42, "Omisión de invocación elimina manifestación y restablece cámara")
	ui._new_party()
	stage.set_skip_animations(false)
	ui.run.resonance = 100
	ui._refresh()
	ui.actions.get_child(4).pressed.emit()
	await _tree.process_frame
	await _tree.process_frame
	ui._new_party()
	check(stage._effects.get_child_count() == 0 and stage.event_queue.is_empty() and stage.camera.fov == 42 and not ui.log_panel.visible, "Reinicio durante Ignar limpia VFX, menús y movimientos de cámara")
	check(ui.engine.fighters[3].hp == 280 and ui.engine.fighters[1].mp == 35 and ui.run.resonance == 0, "Renovación visual no modifica valores iniciales de gameplay")
	# Pending async callbacks must also be invalidated when the scene is released.
	stage.free()
	await _tree.process_frame
