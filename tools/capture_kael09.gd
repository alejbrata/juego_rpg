extends SceneTree

# Same stage, light, scale and camera for the archived 0.8 and new mesh.
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Esta comparación exige render real.")
		quit(1)
		return
	call_deferred("capture")

func capture() -> void:
	# Explicit comparison independent of the user's selected version/fallback.
	# These changes are in memory only; the tool never saves project settings.
	ProjectSettings.set_setting("visuals/kael/use_imported", true)
	ProjectSettings.set_setting("visuals/kael/asset_version", "0.9")
	var before_only := "--before-only" in OS.get_cmdline_user_args()
	for version in ["before", "after"]:
		if before_only and version == "after":
			continue
		var stage = load("res://scenes/battle_3d.tscn").instantiate()
		stage.camera_motion_enabled = false
		root.add_child(stage)
		await process_frame
		var actor: BattleActorVisual = stage.visuals[0]
		if version == "before":
			var old := KaelModel.new()
			actor.model_pivot.add_child(old)
			if not old.load_asset("res://assets/characters/kael/v08/kael.glb"):
				quit(1)
				return
			actor.imported_model.free()
			actor.imported_model = old
			actor.weapon = old.weapon
		if actor.imported_model == null:
			printerr("No se puede comparar un fallback como si fuera GLB.")
			quit(1)
			return
		actor.set_process(false)
		actor.imported_model.reset_pose()
		actor.imported_model.animation_player.pause()
		await save("kael09-" + version + "-battle")
		stage.hud.visible = false
		for i in range(1, stage.visuals.size()):
			stage.visuals[i].visible = false
		actor.nameplate.visible = false
		var target := actor.home + Vector3.UP * 1.1
		stage.camera.position = target + Vector3(2.6, 1.1, 4.5)
		stage.camera.look_at(target)
		await save("kael09-" + version + "-full")
		target = actor.home + Vector3.UP * 1.83
		stage.camera.position = target + Vector3(1.5, 0.10, 1.8)
		stage.camera.look_at(target)
		await save("kael09-" + version + "-face")
		if version == "after":
			target = actor.home + Vector3.UP * 1.1
			stage.camera.position = target + Vector3(2.6, 1.1, 4.5)
			stage.camera.look_at(target)
			for clip in ["Attack", "Walk", "Hurt", "Defend", "KO"]:
				var ap := actor.imported_model.animation_player
				ap.stop()
				ap.play(clip, 0)
				ap.advance(0)
				ap.seek(ap.get_animation(clip).length * (1.0 if clip in ["Defend", "KO"] else 0.27), true)
				ap.pause()
				await save("kael09-" + clip.to_lower())
		stage.free()
		await process_frame
	if not before_only:
		await comparison_sheet()
	print("Comparación 0.9 guardada en docs/previews.")
	quit()

func comparison_sheet() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 960)
	var canvas := Control.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("17232a")
	background.size = Vector2(1280, 960)
	canvas.add_child(background)
	for row in range(2):
		for col in range(2):
			var label := Label.new()
			label.text = ("0.8 · anterior" if col == 0 else "0.9 · atlas + formas revisadas") + (" · cuerpo" if row == 0 else " · rostro")
			label.position = Vector2(col * 640 + 16, row * 480 + 8)
			label.add_theme_font_size_override("font_size", 24)
			canvas.add_child(label)
			var view := TextureRect.new()
			var name := "kael09-" + ("before" if col == 0 else "after") + ("-full" if row == 0 else "-face")
			view.texture = ImageTexture.create_from_image(Image.load_from_file("res://docs/previews/" + name + ".png"))
			view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			view.position = Vector2(col * 640, row * 480 + 44)
			view.size = Vector2(640, 426)
			canvas.add_child(view)
	await save("kael09-comparison")
	canvas.free()

func save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://docs/previews/" + label + ".png")
	if error != OK:
		printerr("No se pudo guardar " + label)
		quit(1)
