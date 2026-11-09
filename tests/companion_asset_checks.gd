extends RefCounted

const KAEL_HASH := "6ab01c49f53adfc028525238511be74673d1bfdc42deca73dfae15032227f93f"
const HEROES := ["lyra", "nira"]

func run(tree: SceneTree, check: Callable) -> void:
	check.call(FileAccess.get_sha256("res://assets/characters/kael/retro/kael.glb") == KAEL_HASH, "Compañeras: Kael retro permanece intacto")
	var previous: Array = []
	for hero: String in HEROES:
		previous.append(ProjectSettings.get_setting("visuals/%s/use_imported" % hero, false))
		ProjectSettings.set_setting("visuals/%s/use_imported" % hero, true)
		check_asset(tree, check, hero)
	await check_battle(tree, check)
	for i in range(HEROES.size()):
		ProjectSettings.set_setting("visuals/%s/use_imported" % HEROES[i], previous[i])

func check_asset(tree: SceneTree, check: Callable, hero: String) -> void:
	var base := "res://assets/characters/%s/%s" % [hero, hero]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "_manifest.json"))
	check.call(FileAccess.get_sha256(base + ".glb") == manifest.glb_sha256 and FileAccess.get_sha256(base + ".blend") == manifest.blend_sha256, hero + ": fuente y GLB trazables")
	check.call(FileAccess.get_sha256(base + "_atlas.png") == manifest.atlas_sha256 and FileAccess.get_sha256("res://tools/blender/build_companions.py") == manifest.build_script_sha256 and FileAccess.get_sha256("res://tools/blender/kael_reference_mesh.py") == manifest.surface_helper_sha256, hero + ": atlas, construcción y helper trazables")
	check.call(manifest.kael_reference_glb_sha256 == KAEL_HASH and not manifest.mobile_tested, hero + ": referencia conservada y móvil pendiente explícito")
	var file := FileAccess.open(base + ".glb", FileAccess.READ)
	file.seek(12)
	var length := file.get_32()
	file.get_32()
	var gltf: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	var view: Dictionary = gltf.bufferViews[gltf.images[0].bufferView]
	file.seek(28 + length + int(view.get("byteOffset", 0)))
	check.call(gltf.images.size() == 1 and file.get_buffer(view.byteLength) == FileAccess.get_file_as_bytes(base + "_atlas.png"), hero + ": GLB incrusta exactamente su atlas revisado")
	var model := CompanionModel.new()
	model.hero_id = hero
	tree.root.add_child(model)
	var loaded := model.load_asset()
	check.call(loaded and model.asset.scene_file_path == base + ".glb" and model.load_error.is_empty(), hero + ": importación real sin fallback")
	if not loaded:
		model.free()
		return
	check.call(model.skeleton.get_bone_count() == 17 and model.scale == Vector3.ONE, hero + ": esqueleto y escala unitaria")
	var focus := model.weapon as MeshInstance3D
	check.call(focus != null and focus.skin != null and focus.get_node(focus.skeleton) == model.skeleton, hero + ": foco cosmético unido al mismo esqueleto")
	var triangles := 0
	var vertices := 0
	var surfaces := 0
	var materials: Array[Material] = []
	var skin_valid := true
	for mesh: MeshInstance3D in model.asset.find_children("*", "MeshInstance3D", true, false):
		skin_valid = skin_valid and mesh.skin != null and mesh.get_node(mesh.skeleton) == model.skeleton
		for surface in range(mesh.mesh.get_surface_count()):
			surfaces += 1
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			vertices += points.size()
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			skin_valid = skin_valid and weights.size() == points.size() * 4 and bones.size() == weights.size()
			for vertex in range(points.size()):
				var sum := 0.0
				for bind in range(4):
					var index := vertex * 4 + bind
					sum += weights[index]
					skin_valid = skin_valid and is_finite(weights[index]) and weights[index] >= 0 and bones[index] >= 0 and bones[index] < mesh.skin.get_bind_count()
				skin_valid = skin_valid and absf(sum - 1.0) < .001 and points[vertex].is_finite()
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if not materials.has(material):
				materials.append(material)
	check.call(skin_valid, hero + ": skin finito, normalizado y vinculado al rig")
	check.call(triangles == manifest.triangles and vertices == manifest.exported_vertices and surfaces == manifest.surfaces and materials.size() == manifest.materials, hero + ": métricas medidas de la malla importada coinciden con manifiesto")
	check.call(triangles >= 8000 and triangles <= 15000 and surfaces <= 6 and materials.size() <= 3, hero + ": presupuesto de geometría y superficies")
	var compatible := true
	for material: StandardMaterial3D in materials:
		compatible = compatible and material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and material.albedo_texture.get_width() == 1024 and material.albedo_texture.get_height() == 1024
	check.call(compatible, hero + ": materiales opacos iluminados y atlas 1024")
	var other := CompanionModel.new()
	other.hero_id = hero
	tree.root.add_child(other)
	check.call(other.load_asset(), hero + ": segunda instancia real")
	var special := "Cast" if hero == "lyra" else "Support"
	var required := KaelModel.REQUIRED.duplicate()
	required.append(special)
	var ap := model.animation_player
	for clip: String in required:
		var animation := ap.get_animation(clip)
		check.call(animation != null and animation.length > 0 and not is_same(animation, other.animation_player.get_animation(clip)) and animation.loop_mode == (Animation.LOOP_LINEAR if clip in ["Idle", "Walk"] else Animation.LOOP_NONE), hero + ": clip independiente y bucle correcto " + clip)
		if clip not in ["Idle", "Walk"]:
			check.call(is_equal_approx(model.presentation_duration(clip), animation.length), hero + ": presentación respeta duración completa " + clip)
		model.reset_pose()
		ap.play(clip, 0)
		ap.advance(0)
		ap.seek(0, true)
		var first_pose: Array[Transform3D] = []
		for bone in range(model.skeleton.get_bone_count()):
			first_pose.append(model.skeleton.get_bone_pose(bone))
		ap.seek(animation.length * .4, true)
		var moves := false
		for bone in range(model.skeleton.get_bone_count()):
			moves = moves or not first_pose[bone].is_equal_approx(model.skeleton.get_bone_pose(bone))
		check.call(moves, hero + ": clip deforma realmente el esqueleto " + clip)
		if clip in ["Idle", "Walk"]:
			ap.seek(animation.length - .00001, true)
			var continuous := true
			for bone in range(model.skeleton.get_bone_count()):
				var final_pose := model.skeleton.get_bone_pose(bone)
				continuous = continuous and first_pose[bone].origin.distance_to(final_pose.origin) < .001 and first_pose[bone].basis.get_rotation_quaternion().angle_to(final_pose.basis.get_rotation_quaternion()) < .005
			check.call(continuous, hero + ": bucle sin salto " + clip)
	model.reset_pose()
	model.play_action(special, model.presentation_duration(special))
	ap.advance(model.presentation_duration(special) + .1)
	check.call(model.current_clip == "Idle" and other.current_clip == "Idle", hero + ": acción especial termina en Idle sin cambiar otra instancia")
	model.set_walking(true)
	check.call(model.current_clip == "Walk" and is_equal_approx(ap.speed_scale, 2.0) and other.current_clip == "Idle", hero + ": Walk independiente adapta velocidad de referencia")
	model.set_walking(false)
	check.call(model.current_clip == "Idle" and is_equal_approx(ap.speed_scale, 1.0), hero + ": detener Walk restaura Idle")
	for clip in ["Walk", "KO"]:
		model.reset_pose()
		ap.play(clip, 0)
		ap.advance(0)
		var minimum := INF
		var duration := ap.get_animation(clip).length
		var helper := preload("res://tests/kael_polish_checks.gd").new()
		for sample in range(int(duration * 120) + 1):
			ap.seek(minf(sample / 120.0, duration), true)
			minimum = minf(minimum, helper.skin_min_y(model))
		print("COMPANION_SKIN_MIN_Y ", hero, " ", clip, " ", minimum)
		check.call(minimum >= -.0001 and minimum < .02, hero + ": skin " + clip + " sobre suelo también entre claves")
	for clip in ["KO", "Defend"]:
		model.reset_pose(clip)
		check.call(model.current_clip == clip and not ap.is_playing() and is_equal_approx(ap.current_animation_position, ap.get_animation(clip).length), hero + ": estado mantiene pose final " + clip)
	model.flash(Color.RED, .5)
	var isolated := true
	for mesh: MeshInstance3D in other.asset.find_children("*", "MeshInstance3D", true, false):
		isolated = isolated and mesh.material_overlay == null
	model.reset_pose()
	for mesh: MeshInstance3D in model.asset.find_children("*", "MeshInstance3D", true, false):
		isolated = isolated and mesh.material_overlay == null
	check.call(isolated and model.current_clip == "Idle", hero + ": destello por instancia y reset limpio")
	model.free()
	other.free()

func snapshot(engine: BattleEngine) -> Dictionary:
	return preload("res://tests/guardian_checks.gd").new().snapshot(engine)

func check_battle(tree: SceneTree, check: Callable) -> void:
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	tree.root.add_child(stage)
	await tree.process_frame
	stage.set_process(false) # Drain individual real events deterministically below.
	for id in [1, 2]:
		var hero: String = HEROES[id - 1]
		var visual: BattleActorVisual = stage.visuals[id]
		check.call(visual.imported_model is CompanionModel and visual.imported_model.asset.scene_file_path == CompanionModel.ASSET_PATHS[hero] and visual.companion_load_error.is_empty(), hero + ": batalla usa GLB correspondiente")
		var before := snapshot(stage.hud.engine)
		for effect: String in ["physical", "hit", "guard", "knockout"]:
			visual.animate(effect)
			check.call(visual.imported_model.current_clip == {"physical": "Attack", "hit": "Hurt", "guard": "Defend", "knockout": "KO"}[effect], hero + ": mapeo de evento " + effect)
		check.call(snapshot(stage.hud.engine) == before and visual.body.rotation.is_zero_approx() and visual.body.scale == Vector3.ONE, hero + ": presentación sin mutación ni doble transformación")
		stage.hud.engine.fighters[id].hp = 0
		stage._sync_state()
		check.call(visual.imported_model.current_clip == "KO" and not visual.turn_ring.visible and not visual.imported_model.animation_player.is_playing(), hero + ": estado inconsciente mantiene KO")
		stage.hud._restart()
		check.call(stage.visuals[id].imported_model.current_clip == "Idle" and stage.hud.engine.fighters[id].hp == stage.hud.engine.fighters[id].data.max_hp, hero + ": reinicio recupera vida y presentación")
		for ability_index in range(2):
			var engine: BattleEngine = stage.hud.engine
			while engine.current_id() != id:
				if engine.phase == BattleEngine.Phase.ENEMY_TURN:
					engine.step_enemy()
				else:
					engine.act(engine.defend_action(), engine.current_id())
			stage.skip_presentation()
			if id == 2:
				engine.fighters[0].hp = 60 # Real healing has a visible amount.
			var ability: BattleAbility = engine.fighters[id].data.abilities[ability_index]
			var offset := engine.events.size()
			check.call(engine.act(ability, 3 if id == 1 else 0).is_empty(), hero + ": motor resuelve habilidad existente " + ability.label)
			var resolved := snapshot(engine)
			var action: Dictionary = {}
			for event: Dictionary in engine.events.slice(offset):
				if event.type == "action":
					action = event
			check.call(not action.is_empty() and action.effect == ability.effect and action.element == ability.element, hero + ": evento real conserva efecto y elemento")
			var duration: float = stage._play_event(action)
			visual = stage.visuals[id]
			var expected := "Cast" if id == 1 else "Support"
			check.call(visual.imported_model.current_clip == expected and duration >= visual.imported_model.animation_player.get_animation(expected).length, hero + ": evento ejecuta clip completo " + ability.label)
			check.call(stage.hud.presentation_busy and snapshot(engine) == resolved, hero + ": selección bloqueada y motor invariante mientras anima")
			stage.skip_presentation()
			check.call(snapshot(engine) == resolved and not stage.hud.presentation_busy and stage.event_queue.is_empty() and visual.imported_model.current_clip == "Idle", hero + ": omitir acción no repite gasto ni efecto")
			visual.animate(ability.effect)
			stage.hud._restart()
			check.call(stage.visuals[id].imported_model.current_clip == "Idle" and stage._effects.get_child_count() == 0 and stage.event_queue.is_empty(), hero + ": reinicio durante habilidad limpia clips, VFX y cola")
	# One complete current-party queue at its actual asynchronous entry point.
	stage.animation_time_scale = .1
	stage.set_process(true)
	var engine: BattleEngine = stage.hud.engine
	check.call(engine.act(engine.fighters[1].data.abilities[0], 3).is_empty(), "Compañeras: acción real entra en la cola completa")
	var resolved := snapshot(engine)
	# Observe the start signal itself: two frames can outlast the accelerated
	# clip on a busy render frame, making a fixed-frame assertion race the queue.
	await stage.visuals[1].imported_model.animation_player.animation_started
	check.call(stage.playing and stage.visuals[1].imported_model.current_clip == "Cast" and stage.hud.presentation_busy, "Compañeras: cola activa reproduce Cast y bloquea controles")
	await tree.create_timer(.4).timeout
	check.call(not stage.playing and stage.event_queue.is_empty() and not stage.hud.presentation_busy and stage.visuals[1].imported_model.current_clip == "Idle" and snapshot(engine) == resolved, "Compañeras: cola completa acaba en Idle sin repetir daño ni PM")
	stage.free()
	for hero: String in HEROES:
		var fighter := BattleEngine.Fighter.new(load("res://data/%s.tres" % hero), false)
		var broken := BattleActorVisual.new()
		broken.companion_asset_path = "res://assets/characters/%s/missing.glb" % hero
		broken.report_asset_warnings = false
		tree.root.add_child(broken)
		broken.build(fighter)
		check.call(broken.imported_model == null and broken.weapon != null and broken.cape != null and broken.companion_load_error.contains("No existe"), hero + ": GLB ausente recupera fallback y diagnóstico")
		broken.free()
		ProjectSettings.set_setting("visuals/%s/use_imported" % hero, false)
		var disabled := BattleActorVisual.new()
		tree.root.add_child(disabled)
		disabled.build(fighter)
		check.call(disabled.imported_model == null and disabled.weapon != null and disabled.cape != null and disabled.companion_load_error.is_empty(), hero + ": selector conserva modelo anterior sin error")
		disabled.free()
		ProjectSettings.set_setting("visuals/%s/use_imported" % hero, true)
