extends RefCounted

func run(tree: SceneTree, check: Callable) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/kael/kael_manifest.json"))
	check.call(FileAccess.file_exists("res://assets/characters/kael/kael.blend"), "Fuente Blender conservada")
	check.call(FileAccess.get_sha256(KaelModel.ASSET_PATH) == manifest.glb_sha256, "GLB coincide con manifiesto de exportación")
	check.call(FileAccess.get_sha256("res://assets/characters/kael/kael.blend") == manifest.blend_sha256, "Fuente coincide con manifiesto")
	check.call(FileAccess.get_sha256("res://tools/blender/build_kael.py") == manifest.script_sha256, "Generador coincide con manifiesto")
	check.call(manifest.triangles <= 7000, "Kael respeta presupuesto de 7000 triángulos")
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	tree.root.add_child(stage)
	await tree.process_frame
	var visual: BattleActorVisual = stage.visuals[0]
	var model: KaelModel = visual.imported_model
	check.call(model != null and model.load_error.is_empty(), "Batalla carga GLB real sin fallback ni error")
	if model == null:
		stage.free()
		return
	check.call(stage.visuals[1].imported_model == null and stage.visuals[2].imported_model == null and stage.visuals[3].imported_model == null, "Solo Kael cambia de modelo")
	check.call(model.skeleton.get_bone_count() == 17, "Esqueleto importado conserva 17 huesos")
	for bone in manifest.bones:
		check.call(model.skeleton.find_bone(bone) >= 0, "Hueso importado: " + bone)
	for clip in KaelModel.REQUIRED:
		check.call(model.animation_player.has_animation(clip) and model.animation_player.get_animation(clip).length > 0, "Clip importado: " + clip)
	var sword := model.weapon as MeshInstance3D
	check.call(sword != null and sword.skin != null and sword.get_node(sword.skeleton) == model.skeleton, "Espada utiliza skin y esqueleto del cuerpo")
	var before: Dictionary = preload("res://tests/guardian_checks.gd").new().snapshot(stage.hud.engine)
	model.reset_pose()
	model.animation_player.pause()
	var hand := model.skeleton.find_bone("upper_arm.R")
	var initial_hand := model.skeleton.get_bone_pose(hand)
	visual.animate("physical")
	check.call(model.current_clip == "Attack", "Ataque físico selecciona Attack")
	model.animation_player.advance(0.03) # Consume the 20 ms blend before sampling.
	model.animation_player.seek(0.3, true)
	check.call(not model.skeleton.get_bone_pose(hand).is_equal_approx(initial_hand), "Attack mueve brazo de la cadena que deforma la espada")
	for kind in ["hit", "guard", "knockout"]:
		visual.animate(kind)
		check.call(model.current_clip == {"hit": "Hurt", "guard": "Defend", "knockout": "KO"}[kind], "Evento selecciona clip: " + kind)
	model.reset_pose("KO")
	check.call(not model.animation_player.is_playing() and visual.body.rotation.is_zero_approx(), "KO mantiene pose ósea sin doble giro del cuerpo")
	model.reset_pose("Defend")
	check.call(not model.animation_player.is_playing() and model.current_clip == "Defend", "Defensa mantiene pose final")
	model.reset_pose()
	check.call(model.current_clip == "Idle" and model.skeleton.get_bone_pose(hand).is_equal_approx(initial_hand), "Reset recupera pose inicial")
	check.call(preload("res://tests/guardian_checks.gd").new().snapshot(stage.hud.engine) == before, "Animaciones no cambian PV, PM, RE, turnos ni estados")
	visual.animate("physical")
	stage.hud._restart()
	await tree.process_frame
	check.call(stage.visuals[0].imported_model.current_clip == "Idle" and stage.visuals[0].body.position.is_zero_approx(), "Reinicio durante Attack crea Kael en reposo")
	stage.free()
	await tree.process_frame
	var fallback = preload("res://scenes/battle_3d.tscn").instantiate()
	fallback.use_imported_kael = false
	tree.root.add_child(fallback)
	await tree.process_frame
	check.call(fallback.visuals[0].imported_model == null and fallback.visuals[0].weapon != null, "Inspector permite usar Kael procedural en batalla")
	fallback.free()
	var broken := BattleActorVisual.new()
	broken.kael_asset_path = "res://assets/characters/kael/missing.glb"
	broken.report_asset_warnings = false
	tree.root.add_child(broken)
	broken.build(BattleEngine.Fighter.new(preload("res://data/kael.tres"), false))
	check.call(broken.imported_model == null and broken.weapon != null and broken.kael_load_error.contains("No existe"), "GLB ausente informa y recupera modelo procedural")
	broken.free()
	var player = preload("res://world/exploration_player.gd").new()
	tree.root.add_child(player)
	await tree.process_frame
	check.call(player.model.imported_model != null and player.movement_speed == 4.0, "Exploración reutiliza GLB sin cambiar velocidad")
	var exploration_model: KaelModel = player.model.imported_model
	var other := KaelModel.new()
	tree.root.add_child(other)
	other.load_asset()
	check.call(exploration_model.animation_player.get_animation("Idle") != other.animation_player.get_animation("Idle"), "Instancias tienen clips independientes")
	other.set_pose("KO")
	check.call(exploration_model.current_clip == "Idle", "Pose de otra instancia no afecta exploración")
	other.free()
	player.set_movement_input(Vector2.RIGHT)
	for i in range(3):
		await tree.physics_frame
	check.call(exploration_model.current_clip == "Walk" and player.velocity.x == 4.0, "Movimiento reproduce Walk con velocidad original")
	player.movement_enabled = false
	for i in range(3):
		await tree.physics_frame
	check.call(exploration_model.current_clip == "Idle" and player.velocity.x == 0, "Bloqueo de interacción detiene Walk")
	player.movement_enabled = true
	player.set_movement_input(Vector2.ZERO)
	for i in range(3):
		await tree.physics_frame
	check.call(exploration_model.current_clip == "Idle", "Detener entrada reproduce Idle")
	player.free()
	var setting: Variant = ProjectSettings.get_setting("visuals/kael/use_imported", true)
	ProjectSettings.set_setting("visuals/kael/use_imported", false)
	var old_player = preload("res://world/exploration_player.gd").new()
	tree.root.add_child(old_player)
	await tree.process_frame
	check.call(old_player.model.imported_model == null and old_player.model.weapon != null, "Configuración global permite fallback en exploración")
	old_player.free()
	ProjectSettings.set_setting("visuals/kael/use_imported", setting)
