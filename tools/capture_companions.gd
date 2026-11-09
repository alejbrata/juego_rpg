extends SceneTree

const OUT := "res://docs/previews/companions/"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Se necesita render real para esta comparación")
		quit(1)
		return
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for after in [false, true]:
		var prefix := "after" if after else "before"
		ProjectSettings.set_setting("visuals/lyra/use_imported", after)
		ProjectSettings.set_setting("visuals/nira/use_imported", after)
		root.size = Vector2i(960, 640)
		var stage = load("res://scenes/battle_3d.tscn").instantiate()
		stage.camera_motion_enabled = false
		root.add_child(stage)
		await process_frame
		for actor: BattleActorVisual in stage.visuals:
			actor.set_process(false)
			if actor.imported_model != null:
				actor.imported_model.reset_pose()
				actor.imported_model.animation_player.pause()
		for size in [Vector2i(960, 640), Vector2i(1280, 720), Vector2i(800, 450)]:
			root.size = size
			await save(prefix + "-battle-" + str(size.x) + "x" + str(size.y))
		root.size = Vector2i(960, 640)
		stage.hud.visible = false
		for id in [1, 2]:
			var hero: String = "lyra" if id == 1 else "nira"
			var actor: BattleActorVisual = stage.visuals[id]
			for other: BattleActorVisual in stage.visuals:
				other.visible = other == actor
			actor.nameplate.visible = false
			view_actor(stage, actor)
			await save(prefix + "-" + hero + "-full")
			var target := actor.home + Vector3.UP * 1.85
			stage.camera.position = target + Vector3(1.15, 0.10, 1.45)
			stage.camera.look_at(target)
			await save(prefix + "-" + hero + "-face")
			view_actor(stage, actor)
			if after:
				assert(actor.imported_model.asset.scene_file_path == "res://assets/characters/%s/%s.glb" % [hero, hero])
				for clip in ["Walk", "Attack", "Defend", "Hurt", "KO", "Cast" if id == 1 else "Support"]:
					actor.imported_model.reset_pose()
					var ap := actor.imported_model.animation_player
					ap.play(clip, 0)
					ap.advance(0)
					ap.seek(ap.get_animation(clip).length * (1.0 if clip in ["Defend", "KO"] else .46), true)
					ap.pause()
					await save(hero + "-" + clip.to_lower())
		stage.free()
		await process_frame
	# Real engine events in the normal presentation queue, with existing effects.
	for action in [["lyra", 0], ["nira", 0], ["lyra", 1], ["nira", 1]]:
		var hero: String = action[0]
		var stage = load("res://scenes/battle_3d.tscn").instantiate()
		stage.camera_motion_enabled = false
		root.add_child(stage)
		await process_frame
		stage.set_process(false)
		var engine: BattleEngine = stage.hud.engine
		var id := 1 if hero == "lyra" else 2
		while engine.current_id() != id:
			if engine.phase == BattleEngine.Phase.ENEMY_TURN:
				engine.step_enemy()
			else:
				assert(engine.act(engine.defend_action(), engine.current_id()).is_empty())
		stage.skip_presentation()
		var ability: BattleAbility = engine.fighters[id].data.abilities[action[1]]
		assert(engine.act(ability, 3 if id == 1 else 0).is_empty())
		stage.hud._refresh()
		stage._drain_events()
		await create_timer(.20 if id == 1 else .32).timeout
		await save(hero + ("-event-battle" if action[1] == 0 else "-event-ice" if id == 1 else "-event-haste"))
		if id == 2 and action[1] == 0:
			await create_timer(.78).timeout
			await save("nira-heal-result")
		while stage.playing:
			await process_frame
		stage.free()
		await process_frame
	await comparison()
	print("COMPANION_CAPTURES " + OUT)
	quit()

func view_actor(stage: Node3D, actor: BattleActorVisual) -> void:
	var target := actor.home + Vector3.UP * 1.1
	stage.camera.position = target + Vector3(2.4, .7, 3.2)
	stage.camera.look_at(target)

func comparison() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440, 1530)
	var layout := Control.new()
	root.add_child(layout)
	var bg := ColorRect.new()
	bg.color = Color("17232a")
	bg.size = Vector2(root.size)
	layout.add_child(bg)
	for row in range(3):
		for col in range(2):
			var label := Label.new()
			label.text = ("Antes" if col == 0 else "Después") + " · " + ["grupo", "Lyra", "Nira"][row]
			label.position = Vector2(col * 720 + 16, row * 510 + 8)
			label.add_theme_font_size_override("font_size", 25)
			layout.add_child(label)
			var view := TextureRect.new()
			var suffix: String = ["-battle-960x640", "-lyra-full", "-nira-full"][row]
			view.texture = ImageTexture.create_from_image(Image.load_from_file(OUT + ("before" if col == 0 else "after") + suffix + ".png"))
			view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			view.position = Vector2(col * 720, row * 510 + 38)
			view.size = Vector2(720, 470)
			layout.add_child(view)
	await save("comparison")
	layout.free()

func save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT + label + ".png") == OK)
