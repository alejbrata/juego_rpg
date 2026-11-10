extends SceneTree
## Real-render comparison of the party art styles ("current" vs "ps1").
## godot --path . --script res://tools/capture_party_style.gd [-- --only=ps1 --out=res://...]
## Same battle scene, camera, light, scale and resolutions for both styles.

var OUT := "res://docs/previews/party-ps1/"
const HEROES := ["kael", "lyra", "nira"]

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Las capturas exigen render real")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			OUT = arg.substr(6)
	call_deferred("capture")

func save(file: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + file + ".png")
	print("captura ", file)

func freeze(stage: Node3D, clip: String = "", at: float = 0.0) -> void:
	for actor: BattleActorVisual in stage.visuals:
		actor.set_process(false)
		if actor.imported_model != null:
			actor.imported_model.reset_pose()
			var player := actor.imported_model.animation_player
			if not clip.is_empty() and player.has_animation(clip):
				player.play(clip, 0)
				player.advance(0)
				player.seek(player.get_animation(clip).length * at, true)
			player.pause()

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	for style in ["current", "ps1"]:
		if not only.is_empty() and only != style:
			continue
		ProjectSettings.set_setting("visuals/party/style", style)
		for hero in ["lyra", "nira"]:
			ProjectSettings.set_setting("visuals/%s/use_imported" % hero, true)
		root.size = Vector2i(1280, 720)
		var stage = load("res://scenes/battle_3d.tscn").instantiate()
		stage.camera_motion_enabled = false
		root.add_child(stage)
		await process_frame
		for i in 3:
			var actor: BattleActorVisual = stage.visuals[i]
			assert(actor.imported_model != null, "sin modelo importado para " + HEROES[i])
			if style == "ps1":
				assert(actor.imported_model.asset.scene_file_path == KaelModel.PS1_PATHS[HEROES[i]])
		freeze(stage)
		for size in [Vector2i(1280, 720), Vector2i(960, 640), Vector2i(800, 450)]:
			root.size = size
			await save("%s-battle-%dx%d" % [style, size.x, size.y])
		root.size = Vector2i(960, 640)
		stage.hud.visible = false
		for actor: BattleActorVisual in stage.visuals:
			actor.nameplate.visible = false
		# Party lineup: the three heroes together, enemies hidden.
		for i in stage.visuals.size():
			stage.visuals[i].visible = i < 3
		var centre: Vector3 = (stage.visuals[0].home + stage.visuals[1].home + stage.visuals[2].home) / 3.0 + Vector3.UP * 1.05
		stage.camera.position = centre + Vector3(3.6, 0.9, 4.4)
		stage.camera.look_at(centre)
		await save(style + "-party")
		for i in 3:
			var hero: String = HEROES[i]
			var actor: BattleActorVisual = stage.visuals[i]
			for other: BattleActorVisual in stage.visuals:
				other.visible = other == actor
			var target := actor.home + Vector3.UP * 1.1
			stage.camera.position = target + Vector3(2.4, .7, 3.2)
			stage.camera.look_at(target)
			await save(style + "-" + hero + "-full")
			target = actor.home + Vector3.UP * 1.85
			stage.camera.position = target + Vector3(1.15, 0.10, 1.45)
			stage.camera.look_at(target)
			await save(style + "-" + hero + "-face")
			if style == "ps1":
				var clips := ["Idle", "Walk", "Attack", "Defend", "Hurt", "KO"]
				clips.append("Cast" if hero == "lyra" else ("Support" if hero == "nira" else "Attack"))
				target = actor.home + Vector3.UP * 1.0
				stage.camera.position = target + Vector3(2.6, .6, 3.4)
				stage.camera.look_at(target)
				for clip in clips:
					for at in ([0.32, 0.58] if clip == "Attack" else [1.0 if clip in ["Defend", "KO"] else 0.5]):
						freeze(stage, clip, at)
						await save("ps1-%s-%s-%d" % [hero, clip.to_lower(), int(at * 100)])
		if style == "ps1":
			await motion(stage)
		stage.free()
		await process_frame
	quit()

## Frame sequences of the PS1 clips (assembled into GIFs outside Godot).
func motion(stage: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute(OUT + "motion/")
	root.size = Vector2i(480, 400)
	for i in 3:
		var hero: String = HEROES[i]
		var actor: BattleActorVisual = stage.visuals[i]
		for other: BattleActorVisual in stage.visuals:
			other.visible = other == actor
		var target := actor.home + Vector3.UP * 1.0
		stage.camera.position = target + Vector3(2.4, .55, 3.1)
		stage.camera.look_at(target)
		var clips := ["Walk", "Attack"]
		if hero != "kael":
			clips.append("Cast" if hero == "lyra" else "Support")
		for clip in clips:
			for frame in 12:
				freeze(stage, clip, frame / 11.0 if clip != "Walk" else frame / 12.0)
				await save("motion/%s-%s-%02d" % [hero, clip.to_lower(), frame])
	root.size = Vector2i(960, 640)
