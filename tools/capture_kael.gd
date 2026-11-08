extends SceneTree

# Real-render comparison, deliberately unavailable in headless mode.
# godot --path . --script res://tools/capture_kael.gd -- --output docs/previews
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("La comparación requiere render real, sin --headless.")
		quit(1)
		return
	var output := ProjectSettings.globalize_path("user://kael_comparison")
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--output":
		output = ProjectSettings.globalize_path(args[1]) if args[1].begins_with("res://") else (args[1] if args[1].is_absolute_path() else ProjectSettings.globalize_path("res://" + args[1]))
	DirAccess.make_dir_recursive_absolute(output)
	for imported in [false, true]:
		var stage = preload("res://scenes/battle_3d.tscn").instantiate()
		stage.use_imported_kael = imported
		stage.camera_motion_enabled = false
		root.add_child(stage)
		await process_frame
		await process_frame
		var actor: BattleActorVisual = stage.visuals[0]
		if imported and actor.imported_model == null:
			printerr("No se ha cargado el GLB: no se presentará el fallback como resultado nuevo.")
			stage.free()
			quit(1)
			return
		actor.set_process(false)
		if imported:
			actor.imported_model.animation_player.pause()
		var prefix := "kael-after" if imported else "kael-before"
		await _capture(output.path_join(prefix + ".png"))
		stage.hud.visible = false
		for i in range(1, stage.visuals.size()):
			stage.visuals[i].visible = false
		actor.nameplate.visible = false
		var target := actor.home + Vector3.UP * 1.1
		stage.camera.position = target + Vector3(2.6, 1.1, 4.5)
		stage.camera.look_at(target)
		await _capture(output.path_join(prefix + "-detail.png"))
		stage.free()
		await process_frame
	print("Capturas reales guardadas en: " + output)
	quit()

func _capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
