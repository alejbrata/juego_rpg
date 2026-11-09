extends SceneTree

const OUT := "res://docs/previews/kael-reference/"
const CANDIDATE := "res://assets/characters/kael/reference_study/kael.glb"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Se requiere render real para evaluar el arte.")
		quit(1)
		return
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 900)
	var studio = load("res://scenes/kael_reference_preview.tscn").instantiate()
	root.add_child(studio)
	await process_frame
	for version in ["before", "after"]:
		if not studio.load_character(KaelModel.ASSET_PATH if version == "before" else CANDIDATE):
			quit(1)
			return
		studio.model.animation_player.pause()
		studio.full_view()
		await save(version + "-full")
		studio.face_view()
		await save(version + "-face-same-camera")
		if version == "before":
			# Additional portrait framing: the old head is much larger. Preserve
			# the identical-camera capture above, and show its whole face here.
			studio.camera.position = Vector3(0.45, 1.88, 1.65)
			studio.camera.look_at(Vector3(0, 1.82, 0))
		await save(version + "-face")
		if version == "after":
			studio.full_view()
			for angle in [0, 90, 180, 270]:
				studio.model.rotation_degrees.y = angle
				await save("turn-" + str(angle))
			studio.model.rotation.y = 0
			for clip in KaelModel.REQUIRED:
				var ap: AnimationPlayer = studio.model.animation_player
				studio.model.reset_pose()
				ap.play(clip, 0)
				ap.advance(0)
				ap.seek(ap.get_animation(clip).length * (1.0 if clip in ["Defend", "KO"] else 0.3), true)
				ap.pause()
				await save(clip.to_lower())
	studio.free()
	await process_frame
	if not await capture_game():
		quit(1)
		return
	await comparison_sheet()
	print("Capturas de estudio en " + OUT)
	quit()

func capture_game() -> bool:
	ProjectSettings.set_setting("visuals/kael/use_imported", true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(960, 640)
	for version in ["before", "after"]:
		ProjectSettings.set_setting("visuals/kael/asset_version", "0.9" if version == "before" else "reference-study")
		var battle = load("res://scenes/battle_3d.tscn").instantiate()
		battle.camera_motion_enabled = false
		root.add_child(battle)
		await process_frame
		var actor: BattleActorVisual = battle.visuals[0]
		if actor.imported_model == null or (version == "after" and actor.imported_model.asset.scene_file_path != CANDIDATE):
			printerr("No se permite capturar un fallback como candidato")
			battle.free()
			return false
		actor.imported_model.animation_player.pause()
		for size in [Vector2i(960, 640), Vector2i(1280, 720), Vector2i(800, 450)]:
			root.size = size
			await save(version + "-battle-" + str(size.x) + "x" + str(size.y))
		battle.free()
		await process_frame
		root.size = Vector2i(960, 640)
		var zone = load("res://scenes/forest_zone.tscn").instantiate()
		zone.session.mission.intro_seen = true
		root.add_child(zone)
		await process_frame
		zone.player.set_movement_input(Vector2.ZERO)
		for i in range(3):
			await physics_frame
		if zone.player.model.imported_model == null or (version == "after" and zone.player.model.imported_model.asset.scene_file_path != CANDIDATE):
			zone.free()
			return false
		await save(version + "-exploration")
		var cam: Camera3D = zone.get_node("ForestCamera")
		cam.size = 4.5
		cam.position = zone.player.position + Vector3(2, 3.3, 3)
		cam.look_at(zone.player.position + Vector3.UP)
		await save(version + "-exploration-detail")
		zone.free()
		await process_frame
	return true

func comparison_sheet() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 1000)
	var layout := Control.new()
	root.add_child(layout)
	var background := ColorRect.new()
	background.color = Color("171d29")
	background.size = Vector2(1280, 1000)
	layout.add_child(background)
	for row in range(2):
		for col in range(2):
			var label := Label.new()
			label.text = ("Anterior · 0.9" if col == 0 else "Candidato · lámina de Kael") + (" · cuerpo" if row == 0 else " · retrato reencuadrado")
			label.position = Vector2(col * 640 + 18, row * 500 + 10)
			label.add_theme_font_size_override("font_size", 22)
			layout.add_child(label)
			var view := TextureRect.new()
			view.texture = ImageTexture.create_from_image(Image.load_from_file(OUT + ("before" if col == 0 else "after") + ("-full.png" if row == 0 else "-face.png")))
			view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			view.position = Vector2(col * 640, row * 500 + 42)
			view.size = Vector2(640, 450)
			layout.add_child(view)
	await save("comparison")
	layout.free()

func save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT + label + ".png")
	if error != OK:
		printerr("No se pudo guardar: " + label)
		quit(1)
