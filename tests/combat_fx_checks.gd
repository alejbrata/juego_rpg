extends RefCounted
## Iteration 1.7: combat presentation (effects, sounds, floating numbers, camera).
## Presentation only: every check also verifies that the engine state matches a
## run with the presentation skipped, so no rule depends on the new layer.

var _tree: SceneTree
var _verify: Callable

func check(condition: bool, description: String) -> void:
	_verify.call(condition, "Presentación de combate: " + description)

func snapshot(engine: BattleEngine) -> Dictionary:
	return preload("res://tests/guardian_checks.gd").new().snapshot(engine)

func make_stage(time_scale: float = 0.05) -> Node3D:
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	stage.animation_time_scale = time_scale
	_tree.root.add_child(stage)
	await _tree.process_frame
	return stage

func settle(stage: Node3D) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while (stage.playing or not stage.event_queue.is_empty()) and Time.get_ticks_msec() < deadline:
		await _tree.process_frame

func find_action(ui, title: String) -> Button:
	for button in ui.actions.get_children():
		if String(button.get_meta("title", button.text)).begins_with(title):
			return button
	return null

## Uses `title` on `target` through the HUD; returns the events it produced.
func use(stage: Node3D, title: String, target: String) -> Array:
	var ui = stage.hud
	var before: int = ui.engine.events.size()
	var button := find_action(ui, title)
	if button == null:
		return []
	button.pressed.emit()
	if ui.targets.visible:
		for option in ui.targets.get_children():
			if String(option.get_meta("title", option.text)) == target:
				option.pressed.emit()
	return ui.engine.events.slice(before)

func advance_to(stage: Node3D, actor_id: int) -> void:
	var ui = stage.hud
	for i in 12:
		if ui.engine.current_id() == actor_id:
			return
		ui.actions.get_child(0 if ui.engine.phase == BattleEngine.Phase.ENEMY_TURN else 1).pressed.emit()
		if ui.targets.visible:
			ui.targets.get_child(0).pressed.emit()
		stage.skip_presentation()

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_verify = verify
	await resources()
	await abilities()
	await invariance()
	await camera_and_skip()
	await numbers_layout()
	await summon()

func resources() -> void:
	var missing: Array[String] = []
	for sound: String in CombatAudio.MIX:
		if CombatAudio.stream(sound) == null:
			missing.append(sound)
	check(missing.is_empty() and CombatAudio.MIX.size() == 19, "los 19 sonidos originales se importan (%s)" % ", ".join(missing))
	var textures: Array[String] = []
	for name in ["soft_dot", "spark_star", "slash", "ring", "ring_thin", "flame", "chevron", "column", "lava_cracks", "frost", "rune_circle"]:
		if CombatVFX.texture(name) == null:
			textures.append(name)
	check(textures.is_empty(), "las texturas de efectos existen (%s)" % ", ".join(textures))
	# Every existing action has a cue whose sounds exist; nothing falls back silently.
	var labels: Array[String] = ["Ataque", "Defender"]
	for path in ["res://data/kael.tres", "res://data/lyra.tres", "res://data/nira.tres"]:
		for ability: BattleAbility in (load(path) as CombatantData).abilities:
			labels.append(ability.label)
	var uncovered: Array[String] = []
	for label in labels:
		var cue: Dictionary = CombatCues.ACTIONS.get(label, {})
		if cue.is_empty() or (not String(cue.cast).is_empty() and CombatAudio.stream(cue.cast) == null) or CombatAudio.stream(cue.impact) == null:
			uncovered.append(label)
	check(uncovered.is_empty() and labels.size() == 8, "cada acción existente tiene efecto y sonidos propios (%s)" % ", ".join(uncovered))
	var vfx_ids := {}
	for label in labels:
		vfx_ids[CombatCues.ACTIONS[label].vfx] = true
	check(vfx_ids.size() == labels.size() and CombatCues.ENEMY_PHYSICAL.impact == "hit_hero", "efectos distintos por habilidad y golpe enemigo con sonido de daño recibido")
	# Audio pool: bounded voices, a missing sound never errors.
	var audio := CombatAudio.new()
	_tree.root.add_child(audio)
	for i in 12:
		audio.play("hit")
	check(audio.active_voices() <= CombatAudio.VOICES and not audio.play("no_existe") and audio.played.size() == 12, "el audio limita voces simultáneas e ignora sonidos inexistentes")
	audio.stop_all()
	audio.free()
	# Phones get fewer particles, same recipe.
	var layer := Node3D.new()
	_tree.root.add_child(layer)
	var full := CombatVFX.new(layer, null)
	full.quality = 1.0
	var reduced := CombatVFX.new(layer, null)
	reduced.quality = 0.6
	var a := full.particles(Vector3.ZERO, {"amount": 20})
	var b := reduced.particles(Vector3.ZERO, {"amount": 20})
	var previous: Variant = ProjectSettings.get_setting("visuals/combat_fx/quality", "auto")
	ProjectSettings.set_setting("visuals/combat_fx/quality", "low")
	var low := CombatVFX.default_quality()
	ProjectSettings.set_setting("visuals/combat_fx/quality", previous)
	check(a.amount == 20 and b.amount == 12 and low == 0.6 and CombatVFX.default_quality() == (0.6 if OS.has_feature("mobile") else 1.0), "calidad móvil reduce partículas (20 → 12) sin cambiar el efecto")
	layer.free()

func abilities() -> void:
	var stage := await make_stage()
	var ui = stage.hud
	# action title, actor id, target label, expected number text source, sounds
	var cases := [
		["Llama", 1, "Centinela de piedra", ["fire_cast", "fire_impact"], "damage_fire"],
		["Escarcha", 1, "Centinela de piedra", ["ice_cast", "ice_impact"], "damage_ice"],
		["Ataque", 0, "Centinela de piedra", ["swing", "hit"], "damage"],
		["Golpe potente", 0, "Centinela de piedra", ["swing", "hit_heavy"], "damage_heavy"],
		["Protección", 0, "Lyra", ["protect"], "status"],
		["Cura", 2, "Kael", ["heal"], "heal"],
		["Impulso", 2, "Kael", ["haste"], "status"],
	]
	for case: Array in cases:
		ui.run.resonance = 0
		ui._restart()
		advance_to(stage, case[1])
		if case[0] == "Cura":
			ui.engine.fighters[0].hp = 40
		stage.sfx.played.clear()
		# Count every effect node created (at test speed some live < 1 frame).
		var created := [0]
		var counter := func(_node: Node) -> void: created[0] += 1
		stage._effects.child_entered_tree.connect(counter)
		var events := use(stage, case[0], case[2])
		var number_texts: Array[String] = []
		for i in 6:
			await _tree.process_frame
			for label: Label in stage.numbers.get_children():
				if not number_texts.has(label.text):
					number_texts.append(label.text)
		await settle(stage)
		for i in 3:
			await _tree.process_frame
			for label: Label in stage.numbers.get_children():
				if not number_texts.has(label.text):
					number_texts.append(label.text)
		stage._effects.child_entered_tree.disconnect(counter)
		var spawned: int = created[0]
		var expected := ""
		for event: Dictionary in events:
			if event.type == "damage":
				expected = str(event.amount)
			elif event.type == "heal":
				expected = "+%d" % event.amount
		if expected.is_empty():
			expected = String(CombatCues.STATUS_TEXT.get(events[0].effect, "")) if not events.is_empty() else "?"
		var sounds_ok := true
		for sound: String in case[3]:
			sounds_ok = sounds_ok and stage.sfx.played.has(sound)
		check(not events.is_empty() and spawned > 0 and sounds_ok and number_texts.has(expected), "%s: efecto, sonidos %s y número «%s»" % [case[0], case[3], expected])
		check(not stage.playing and not ui.presentation_busy and stage.event_queue.is_empty(), "%s: la presentación termina y devuelve el control" % case[0])
	# Enemy turn on a hero and a hero K.O.
	ui._restart()
	advance_to(stage, 3)
	for f in ui.engine.fighters:
		if not f.enemy:
			f.hp = 1
	stage.sfx.played.clear()
	var before: int = ui.engine.events.size()
	ui.actions.get_child(0).pressed.emit()
	var texts: Array[String] = []
	var deadline := Time.get_ticks_msec() + 4000
	while (stage.playing or not stage.event_queue.is_empty() or texts.size() < 2) and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
		for label: Label in stage.numbers.get_children():
			if not texts.has(label.text):
				texts.append(label.text)
	var knocked := false
	for event: Dictionary in ui.engine.events.slice(before):
		knocked = knocked or (event.type == "damage" and event.hp_after == 0)
	check(knocked and texts.has("1") and texts.has("K.O.") and stage.sfx.played.has("enemy_swing") and stage.sfx.played.has("hit_hero"), "golpe enemigo: daño recibido en rojo, K.O. visible y sonidos propios")
	await _tree.create_timer(0.3).timeout
	check(stage.sfx.played.has("knockout"), "K.O. con sonido de caída")
	# Physical blows land before the attacker returns; spells after the full cast.
	ui._restart()
	advance_to(stage, 0)
	var attack := {"type": "action", "actor_id": 0, "target_id": 3, "effect": "physical", "element": "physical", "label": "Ataque"}
	var contact: float = stage._play_event(attack)
	var clip: float = stage.visuals[0].presentation_duration("physical")
	check(contact < clip and contact > clip * 0.3 and stage._settle_until > Time.get_ticks_msec(), "el golpe impacta a mitad del ataque y se espera el regreso del atacante")
	stage.skip_presentation()
	stage.free()

func invariance() -> void:
	# Same commands with and without presentation: identical engine state.
	var results: Array[Dictionary] = []
	for skip in [false, true]:
		var stage := await make_stage(0.04)
		stage.set_skip_animations(skip)
		var ui = stage.hud
		var script := [["Llama", "Centinela de piedra"], ["Golpe potente", "Centinela de piedra"], ["", ""], ["Impulso", "Kael"], ["Escarcha", "Centinela de piedra"]]
		for step: Array in script:
			if ui.engine.phase == BattleEngine.Phase.ENEMY_TURN or step[0] == "":
				ui.actions.get_child(0).pressed.emit()
			else:
				use(stage, step[0], step[1])
			await settle(stage)
		results.append(snapshot(ui.engine))
		stage.free()
	check(results[0] == results[1], "el motor queda idéntico con presentación completa u omitida")

func camera_and_skip() -> void:
	var stage := await make_stage(1.0)
	var ui = stage.hud
	var home: Vector3 = stage.camera.position
	stage._shake(1.0)
	await _tree.process_frame
	await _tree.process_frame
	var moved: bool = not stage.camera.position.is_equal_approx(home)
	await _tree.create_timer(0.45).timeout
	await _tree.process_frame
	check(moved and stage.camera.position.is_equal_approx(home) and stage.camera.h_offset == 0.0, "la sacudida mueve la cámara y vuelve exactamente al encuadre base")
	stage.set_camera_motion_enabled(false)
	stage._shake(1.0)
	await _tree.process_frame
	await _tree.process_frame
	check(stage.camera.position.is_equal_approx(home), "sin movimiento de cámara no hay sacudidas")
	stage.set_camera_motion_enabled(true)
	# Skip in the middle of a spell: effects, numbers and sounds stop at once.
	var resolved: Dictionary
	use(stage, "Llama", "Centinela de piedra")
	resolved = snapshot(ui.engine)
	for i in 30:
		await _tree.process_frame
	var busy: bool = stage._effects.get_child_count() > 0
	stage.skip_presentation()
	await _tree.process_frame
	check(busy and stage._effects.get_child_count() == 0 and stage.numbers.active_count() == 0 and stage.sfx.active_voices() == 0 and snapshot(ui.engine) == resolved and not ui.presentation_busy, "omitir a mitad de un hechizo limpia efectos, números y sonidos sin repetir nada")
	# Delayed parts (bolt launch) never appear after the skip.
	await _tree.create_timer(0.8).timeout
	check(stage._effects.get_child_count() == 0 and stage.numbers.active_count() == 0, "ninguna parte diferida reaparece tras omitir")
	# Hit-stop always restores the animation speed.
	var visual: BattleActorVisual = stage.visuals[0]
	visual.hit_stop(0.05)
	await _tree.create_timer(0.15).timeout
	var player: AnimationPlayer = visual.imported_model.animation_player if visual.imported_model != null else null
	check(player == null or is_equal_approx(player.speed_scale, 1.0), "la congelación del impacto recupera la velocidad de animación")
	# Interface sounds: select, confirm, cancel; Resonance chime only when it fills.
	stage.sfx.played.clear()
	ui._restart()
	await _tree.process_frame
	ui._choose(ui.engine.fighters[1].data.abilities[0])
	ui._cancel_selection()
	use(stage, "Llama", "Centinela de piedra")
	check(stage.sfx.played.slice(0, 3) == ["ui_select", "ui_cancel", "ui_select"] and stage.sfx.played.has("ui_confirm"), "sonidos de selección, cancelación y confirmación")
	stage.skip_presentation()
	stage.sfx.played.clear()
	ui.run.resonance = 95
	ui._refresh()
	ui.run.resonance = 100
	ui._refresh()
	ui._refresh()
	check(stage.sfx.played.count("resonance_ready") == 1, "aviso sonoro único al llenarse la Resonancia")
	stage.free()

func numbers_layout() -> void:
	# Readable sizes at the three validated resolutions, inside the screen.
	var sizes := [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(960, 540)]
	var stage := await make_stage(1.0)
	var inside := true
	var heal_color: Color
	var damage_color: Color
	var received_color: Color
	var previous := _tree.root.size
	for size in sizes:
		_tree.root.size = size
		await _tree.process_frame
		stage.numbers.clear()
		var labels: Array[Label] = []
		for id in stage.visuals.size():
			labels.append(stage.numbers.show_text(stage._number_anchor(id), "123", "damage"))
		await _tree.process_frame
		var bounds: Rect2 = stage.numbers.get_viewport_rect()
		for label in labels:
			inside = inside and label.visible and bounds.encloses(label.get_global_rect())
	stage.numbers.clear()
	heal_color = stage.numbers.show_text(Vector3.ZERO, "+1", "heal").get_theme_color("font_color")
	damage_color = stage.numbers.show_text(Vector3.ZERO, "1", "damage").get_theme_color("font_color")
	received_color = stage.numbers.show_text(Vector3.ZERO, "1", "received").get_theme_color("font_color")
	var big: bool = CombatCues.NUMBER_STYLES.damage.size >= 40 and CombatCues.NUMBER_STYLES.heal.size >= 40
	check(inside and big, "números grandes y dentro de pantalla en 16:9, 19,5:9 y 960×540")
	check(heal_color.g > heal_color.r and damage_color != heal_color and received_color.r > received_color.g and received_color != damage_color, "daño, daño recibido y curación con colores distintos")
	await _tree.create_timer(CombatNumbers.STATUS_LIFE + 0.2).timeout
	check(stage.numbers.active_count() == 0 and stage.numbers.get_child_count() == 0, "los números desaparecen en menos de 1,2 s")
	_tree.root.size = previous
	stage.free()

## Ignar: HD model in the party's pipeline when installed, procedural golem otherwise;
## both summon the same way and leave the engine result untouched.
func summon() -> void:
	var previous: Variant = ProjectSettings.get_setting("visuals/party/style", "hd")
	var results: Array[Dictionary] = []
	for style in ["hd", "current"]:
		ProjectSettings.set_setting("visuals/party/style", style)
		var stage := await make_stage(0.2)
		var ui = stage.hud
		ui.run.resonance = 100
		ui._refresh()
		ui.actions.get_child(4).pressed.emit()
		await _tree.process_frame
		await _tree.process_frame
		var hd: bool = stage._ignar is IgnarModel
		var expected_hd: bool = style == "hd" and IgnarModel.available()
		check(is_instance_valid(stage._ignar) and hd == expected_hd and stage._ignar.get_meta("source_mesh_count", 0) >= 25,
			"Ignar %s en estilo %s" % ["HD (mismo esqueleto y animaciones que el grupo)" if expected_hd else "procedural", style])
		if hd:
			var model: IgnarModel = stage._ignar
			check(model.skeleton.get_bone_count() == 65 and model.animation_player.has_animation("Attack") and model.head_anchor != null and model.chest_anchor != null,
				"Ignar HD: 65 huesos, clips Appear/Idle/Attack y anclas de cabeza y pecho")
		var texts: Array[String] = []
		var deadline := Time.get_ticks_msec() + 6000
		while (stage.playing or not stage.event_queue.is_empty()) and Time.get_ticks_msec() < deadline:
			await _tree.process_frame
			for label: Label in stage.numbers.get_children():
				if not texts.has(label.text):
					texts.append(label.text)
		results.append(snapshot(ui.engine))
		check(texts.has("20") and texts.has("DEF ↓") and stage.sfx.played.has("summon") and stage.sfx.played.has("fire_impact"), "invocación (%s): golpe con daño, DEF ↓ y sonidos" % style)
		await _tree.create_timer(0.3).timeout
		check(not is_instance_valid(stage._ignar) and not stage.playing and not ui.presentation_busy, "invocación (%s) termina, retira a Ignar y devuelve el control" % style)
		stage.free()
	ProjectSettings.set_setting("visuals/party/style", previous)
	check(results[0] == results[1], "Ignar HD y procedural dejan idéntico el estado del combate")
