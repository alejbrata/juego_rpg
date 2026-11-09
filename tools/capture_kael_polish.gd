extends SceneTree

var OUT := "res://docs/previews/kael-polish/"
var PATHS := {
	"before": "res://assets/characters/kael/reference_study/kael.glb",
	"after": "res://assets/characters/kael/polished/kael.glb",
}

func _initialize() -> void:
	if "--retro" in OS.get_cmdline_user_args():
		OUT = "res://docs/previews/kael-retro/"
		PATHS = {"before": "res://assets/characters/kael/polished/kael.glb", "after": "res://assets/characters/kael/retro/kael.glb"}
	if DisplayServer.get_name() == "headless":
		printerr("Esta comparación exige render real")
		quit(1)
		return
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	ProjectSettings.set_setting("visuals/kael/use_imported", true)
	for version in ["before", "after"]:
		var selector: String = PATHS[version].get_base_dir().get_file().replace("reference_study", "reference-study")
		ProjectSettings.set_setting("visuals/kael/asset_version", selector)
		root.size = Vector2i(960, 640)
		var stage = load("res://scenes/battle_3d.tscn").instantiate()
		stage.camera_motion_enabled = false
		root.add_child(stage)
		await process_frame
		var actor: BattleActorVisual = stage.visuals[0]
		assert(actor.imported_model != null and actor.imported_model.asset.scene_file_path == PATHS[version])
		for visual in stage.visuals:
			visual.set_process(false)
		actor.imported_model.reset_pose()
		actor.imported_model.animation_player.pause()
		for size in [Vector2i(960, 640), Vector2i(1280, 720), Vector2i(800, 450)]:
			root.size = size
			await save(version + "-battle-" + str(size.x) + "x" + str(size.y))
		root.size = Vector2i(960, 640)
		stage.hud.visible = false
		actor.nameplate.visible = false
		for i in range(1, stage.visuals.size()):
			stage.visuals[i].visible = false
		full_camera(stage, actor)
		await save(version + "-full")
		if "--retro" in OS.get_cmdline_user_args():
			var center := actor.home + Vector3.UP * 1.1
			stage.camera.position = center + Vector3(3.2, 0.7, -2.4)
			stage.camera.look_at(center)
			await save(version + "-profile")
			stage.camera.position = center + Vector3(-2.4, 0.7, -3.2)
			stage.camera.look_at(center)
			await save(version + "-back")
		var target := actor.home + Vector3.UP * 1.85
		stage.camera.position = target + Vector3(1.15, 0.10, 1.45)
		stage.camera.look_at(target)
		await save(version + "-face-torso")
		full_camera(stage, actor)
		for clip in ["Attack", "Defend", "Hurt", "KO"]:
			var ap := actor.imported_model.animation_player
			actor.imported_model.reset_pose()
			ap.play(clip, 0)
			ap.advance(0)
			ap.seek(ap.get_animation(clip).length * (1.0 if clip in ["Defend", "KO"] else 0.42), true)
			ap.pause()
			await save(version + "-" + clip.to_lower())
			if clip == "Attack" and version == "after":
				for phase in [0.30, 0.55, 0.72]:
					ap.seek(ap.get_animation(clip).length * phase, true)
					await save("after-attack-" + str(int(phase * 100)))
		stage.free()
		await process_frame
		var zone = load("res://scenes/forest_zone.tscn").instantiate()
		zone.session.mission.intro_seen = true
		root.add_child(zone)
		await process_frame
		assert(zone.player.model.imported_model.asset.scene_file_path == PATHS[version])
		zone.player.set_movement_input(Vector2.ZERO)
		for i in range(5):
			await physics_frame
		await save(version + "-exploration")
		var start: Vector3 = zone.player.position
		zone.player.set_movement_input(Vector2.RIGHT)
		for i in range(18):
			await physics_frame
		var cam: Camera3D = zone.get_node("ForestCamera")
		cam.size = 4.8
		cam.position = start + Vector3(3.5, 3.3, 3)
		cam.look_at(start + Vector3(0.8, 1.1, 0))
		zone.player.set_physics_process(false)
		zone.player.model.imported_model.animation_player.pause()
		await save(version + "-exploration-walk")
		zone.free()
		await process_frame
	await sheet()
	if "--retro" in OS.get_cmdline_user_args():
		await sheet(true)
	print("KAEL_POLISH_CAPTURES " + OUT)
	quit()

func full_camera(stage: Node3D, actor: BattleActorVisual) -> void:
	var target := actor.home + Vector3.UP * 1.1
	stage.camera.position = target + Vector3(2.4, 0.7, 3.2)
	stage.camera.look_at(target)

func sheet(face_only: bool = false) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440, 510 if face_only else 1020)
	var layout := Control.new()
	root.add_child(layout)
	var bg := ColorRect.new()
	bg.color = Color("17232a")
	bg.size = Vector2(root.size)
	layout.add_child(bg)
	for row in range(1 if face_only else 2):
		for col in range(2):
			var label := Label.new()
			label.text = ("Antes · pulido" if col == 0 else "Después · retro JRPG") if "--retro" in OS.get_cmdline_user_args() else ("Antes · referencia" if col == 0 else "Después · pulido")
			label.text += " · rostro" if face_only else (" · batalla" if row == 0 else " · cuerpo")
			label.position = Vector2(col * 720 + 16, row * 510 + 8)
			label.add_theme_font_size_override("font_size", 25)
			layout.add_child(label)
			var view := TextureRect.new()
			var suffix := "-face-torso.png" if face_only else ("-battle-960x640.png" if row == 0 else "-full.png")
			view.texture = ImageTexture.create_from_image(Image.load_from_file(OUT + ("before" if col == 0 else "after") + suffix))
			view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			view.position = Vector2(col * 720, row * 510 + 38)
			view.size = Vector2(720, 470)
			layout.add_child(view)
	await save("face-comparison" if face_only else "comparison")
	layout.free()

func save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT + label + ".png")
	assert(error == OK, "No se pudo guardar captura: " + label)
