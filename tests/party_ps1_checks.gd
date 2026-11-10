extends RefCounted
## Experimental PS1-battle-model party (iteration 1.2). The variant is opt-in:
## "current" must stay the default and every existing asset untouched.

const HEROES := ["kael", "lyra", "nira"]
const CURRENT := {
	"kael": "res://assets/characters/kael/retro/kael.glb",
	"lyra": "res://assets/characters/lyra/lyra.glb",
	"nira": "res://assets/characters/nira/nira.glb",
}
var _check: Callable
var _tree: SceneTree

func check(condition: bool, description: String) -> void:
	_check.call(condition, "PS1: " + description)

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_check = verify
	var previous: Variant = ProjectSettings.get_setting("visuals/party/style", "current")
	var imported := []
	for hero in ["lyra", "nira"]:
		imported.append(ProjectSettings.get_setting("visuals/%s/use_imported" % hero, false))
		ProjectSettings.set_setting("visuals/%s/use_imported" % hero, true)
	check(String(previous) == "current", "estilo actual sigue siendo el predeterminado")
	ProjectSettings.set_setting("visuals/party/style", "ps1")
	for hero: String in HEROES:
		check_asset(hero)
	await check_battle()
	await check_exploration()
	ProjectSettings.set_setting("visuals/party/style", "current")
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	tree.root.add_child(stage)
	await tree.process_frame
	var restored := true
	for i in 3:
		restored = restored and stage.visuals[i].imported_model != null and stage.visuals[i].imported_model.asset.scene_file_path == CURRENT[HEROES[i]]
	check(restored, "volver a 'current' recupera los tres modelos anteriores")
	stage.free()
	ProjectSettings.set_setting("visuals/party/style", previous)
	for i in 2:
		ProjectSettings.set_setting("visuals/%s/use_imported" % ["lyra", "nira"][i], imported[i])

func load_model(hero: String) -> KaelModel:
	var model: KaelModel
	if hero == "kael":
		model = KaelModel.new()
		_tree.root.add_child(model)
		model.load_asset(KaelModel.PS1_PATHS.kael)
	else:
		model = CompanionModel.new()
		model.hero_id = hero
		_tree.root.add_child(model)
		model.load_asset()
	return model

func check_asset(hero: String) -> void:
	var base := "res://assets/characters/%s/ps1/%s" % [hero, hero]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "_manifest.json"))
	check(FileAccess.get_sha256(base + ".glb") == manifest.glb_sha256 and FileAccess.get_sha256(base + ".blend") == manifest.blend_sha256 and FileAccess.get_sha256(base + "_atlas.png") == manifest.atlas_sha256, hero + ": GLB, fuente y atlas trazables")
	check(FileAccess.get_sha256("res://tools/blender/build_ps1_party.py") == manifest.build_script_sha256 and not manifest.mobile_tested, hero + ": generado por el script actual; móvil pendiente explícito")
	# The importer extracted atlases before (fallback risk): it must be embedded.
	var file := FileAccess.open(base + ".glb", FileAccess.READ)
	file.seek(12)
	var length := file.get_32()
	file.get_32()
	var gltf: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	var view: Dictionary = gltf.bufferViews[gltf.images[0].bufferView]
	file.seek(28 + length + int(view.get("byteOffset", 0)))
	check(gltf.images.size() == 1 and file.get_buffer(view.byteLength) == FileAccess.get_file_as_bytes(base + "_atlas.png"), hero + ": GLB incrusta su atlas")
	check(not FileAccess.file_exists(base.get_base_dir() + "/" + hero + "_" + hero.capitalize() + "PS1Atlas.png"), hero + ": sin textura auxiliar extraída")
	var model := load_model(hero)
	check(model.asset != null and model.asset.scene_file_path == base + ".glb" and model.load_error.is_empty(), hero + ": importación real sin fallback")
	if model.asset == null:
		model.free()
		return
	# Same skeleton contract as the current models (events, poses, exploration).
	var reference := KaelModel.new() if hero == "kael" else CompanionModel.new()
	if reference is CompanionModel:
		reference.hero_id = hero
	_tree.root.add_child(reference)
	reference.load_asset(CURRENT[hero])
	var names := true
	for bone in reference.skeleton.get_bone_count():
		names = names and model.skeleton.find_bone(reference.skeleton.get_bone_name(bone)) >= 0
	check(model.skeleton.get_bone_count() == 17 and names, hero + ": mismos 17 huesos que el modelo actual")
	reference.free()
	# Rigid parts (PS1 method): one bone per vertex, so joints never stretch.
	var rigid := true
	var weapon_on_hand := true
	var triangles := 0
	var vertices := 0
	var surfaces := 0
	var materials: Array[Material] = []
	var hand := model.skeleton.find_bone("hand.R")
	for mesh: MeshInstance3D in model.asset.find_children("*", "MeshInstance3D", true, false):
		rigid = rigid and mesh.skin != null and mesh.get_node(mesh.skeleton) == model.skeleton
		for surface in mesh.mesh.get_surface_count():
			surfaces += 1
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			vertices += points.size()
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			for vertex in points.size():
				var used := 0
				for bind in 4:
					if weights[vertex * 4 + bind] > .001:
						used += 1
						var bind_id: int = bones[vertex * 4 + bind]
						var bone_index: int = mesh.skin.get_bind_bone(bind_id)
						if bone_index < 0:  # glTF skins bind by bone name
							bone_index = model.skeleton.find_bone(mesh.skin.get_bind_name(bind_id))
						if mesh == model.weapon:
							weapon_on_hand = weapon_on_hand and bone_index == hand
				rigid = rigid and used == 1 and absf(weights[vertex * 4] + weights[vertex * 4 + 1] + weights[vertex * 4 + 2] + weights[vertex * 4 + 3] - 1.0) < .001
			var material := mesh.mesh.surface_get_material(surface)
			if not materials.has(material):
				materials.append(material)
	check(rigid, hero + ": piezas rígidas, un hueso por vértice")
	check(model.weapon != null and weapon_on_hand, hero + ": arma unida solo a la mano derecha")
	check(triangles == manifest.triangles and vertices == manifest.exported_vertices and surfaces == manifest.surfaces, hero + ": métricas importadas coinciden con manifiesto")
	check(triangles >= 5000 and triangles <= 10000 and materials.size() == 1 and surfaces <= 2, hero + ": presupuesto (%d triángulos, %d materiales)" % [triangles, materials.size()])
	var material := materials[0] as StandardMaterial3D
	check(material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_texture != null and material.albedo_texture.get_width() == 512, hero + ": material opaco con atlas 512")
	# Exploration moves at 4 m/s and playback is capped at 2.5x: a shorter
	# authored stride would make the feet slide.
	check(float(manifest.walk_reference_speed) * 2.5 >= 4.0, hero + ": zancada cubre la velocidad de exploración sin resbalar (%.2f m/s)" % float(manifest.walk_reference_speed))
	var special: String = {"kael": "", "lyra": "Cast", "nira": "Support"}[hero]
	var clips: Array[String] = KaelModel.REQUIRED.duplicate()
	if not special.is_empty():
		clips.append(special)
	var ap := model.animation_player
	var helper := preload("res://tests/kael_polish_checks.gd").new()
	for clip in clips:
		var animation := ap.get_animation(clip)
		check(animation != null and animation.loop_mode == (Animation.LOOP_LINEAR if clip in ["Idle", "Walk"] else Animation.LOOP_NONE), hero + ": clip y bucle " + clip)
		if clip not in ["Idle", "Walk"]:
			check(is_equal_approx(model.presentation_duration(clip), animation.length), hero + ": duración de presentación completa " + clip)
		model.reset_pose()
		ap.play(clip, 0)
		ap.advance(0)
		ap.seek(0, true)
		var first: Array[Transform3D] = []
		for bone in model.skeleton.get_bone_count():
			first.append(model.skeleton.get_bone_pose(bone))
		var moves := false
		var minimum := INF
		for sample in int(animation.length * 30) + 1:
			ap.seek(minf(sample / 30.0, animation.length), true)
			minimum = minf(minimum, helper.skin_min_y(model))
			for bone in model.skeleton.get_bone_count():
				moves = moves or not first[bone].is_equal_approx(model.skeleton.get_bone_pose(bone))
		check(moves, hero + ": clip mueve el esqueleto " + clip)
		check(minimum >= -.005 and minimum < .06, hero + ": apoyo en el suelo entre claves " + clip + " (%.3f)" % minimum)
		if clip in ["Idle", "Walk"]:
			ap.seek(animation.length - .00001, true)
			var continuous := true
			for bone in model.skeleton.get_bone_count():
				var last := model.skeleton.get_bone_pose(bone)
				continuous = continuous and first[bone].origin.distance_to(last.origin) < .002 and first[bone].basis.get_rotation_quaternion().angle_to(last.basis.get_rotation_quaternion()) < .01
			check(continuous, hero + ": bucle sin salto " + clip)
	for clip in ["KO", "Defend"]:
		model.reset_pose(clip)
		check(model.current_clip == clip and not ap.is_playing(), hero + ": mantiene pose final " + clip)
	model.reset_pose()
	model.free()
	var broken := KaelModel.new()
	_tree.root.add_child(broken)
	check(not broken.load_asset(base.get_base_dir() + "/missing.glb", false) and broken.load_error.contains("No existe"), hero + ": ruta ausente devuelve diagnóstico para el fallback")
	broken.free()

func snapshot(engine: BattleEngine) -> Dictionary:
	return preload("res://tests/guardian_checks.gd").new().snapshot(engine)

func scripted_battle(style: String) -> Array:
	ProjectSettings.set_setting("visuals/party/style", style)
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	_tree.root.add_child(stage)
	await _tree.process_frame
	stage.set_process(false)
	var engine: BattleEngine = stage.hud.engine
	var paths := []
	for i in 3:
		paths.append(stage.visuals[i].imported_model.asset.scene_file_path if stage.visuals[i].imported_model != null else "")
	# Same deterministic orders in both styles: the art must not change results.
	for turn in 6:
		if engine.phase == BattleEngine.Phase.ENEMY_TURN:
			engine.step_enemy()
		elif engine.phase == BattleEngine.Phase.WAITING_PLAYER:
			var id := engine.current_id()
			var ability: BattleAbility = engine.fighters[id].data.abilities[0]
			engine.act(ability, 3 if ability.effect in ["physical", "magic"] else id)
		for event: Dictionary in engine.events:
			if event.type == "action":
				stage._play_event(event)
		stage.skip_presentation()
	var result := [paths, snapshot(engine), stage]
	return result

func check_battle() -> void:
	var current: Array = await scripted_battle("current")
	current[2].free()
	var ps1: Array = await scripted_battle("ps1")
	var stage = ps1[2]
	var expected := []
	for hero: String in HEROES:
		expected.append(KaelModel.PS1_PATHS[hero])
	check(ps1[0] == expected, "batalla carga los tres GLB experimentales")
	check(current[1] == ps1[1], "mismas órdenes producen el mismo estado de combate en ambos estilos")
	var mapping := {"physical": "Attack", "hit": "Hurt", "guard": "Defend", "knockout": "KO"}
	for i in 3:
		var visual: BattleActorVisual = stage.visuals[i]
		for effect: String in mapping:
			visual.animate(effect)
			check(visual.imported_model.current_clip == mapping[effect], HEROES[i] + ": evento %s reproduce %s" % [effect, mapping[effect]])
	check(stage.visuals[1].imported_model.clip_for_effect("magic") == "Cast" and stage.visuals[2].imported_model.clip_for_effect("heal") == "Support", "magia de Lyra y apoyo de Nira conservan su clip")
	stage.hud.engine.fighters[0].hp = 0
	stage._sync_state()
	check(stage.visuals[0].imported_model.current_clip == "KO" and not stage.visuals[0].imported_model.animation_player.is_playing(), "estado inconsciente mantiene KO")
	stage.hud._restart()
	var after_restart := true
	for i in 3:
		after_restart = after_restart and stage.visuals[i].imported_model.asset.scene_file_path == expected[i] and stage.visuals[i].imported_model.current_clip == "Idle"
	check(after_restart and stage._effects.get_child_count() == 0 and stage.event_queue.is_empty(), "reinicio conserva variante y limpia presentación")
	stage.free()

func check_exploration() -> void:
	var zone = preload("res://scenes/forest_zone.tscn").instantiate()
	zone.session.mission.intro_seen = true
	_tree.root.add_child(zone)
	await _tree.process_frame
	var model: KaelModel = zone.player.model.imported_model
	check(model != null and model.asset.scene_file_path == KaelModel.PS1_PATHS.kael, "exploración usa Kael experimental")
	zone.player.set_movement_input(Vector2.RIGHT)
	for i in 6:
		await _tree.physics_frame
	check(model.current_clip == "Walk" and zone.player.position.x > GameSession.SPAWN.x, "Kael experimental camina con la misma física")
	zone.free()
