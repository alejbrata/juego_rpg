extends SceneTree
## Real-render captures and render metrics of the Eclipse clearing.
## godot --path . --script res://tools/capture_forest.gd [-- --only=before|after --out=res://...]
## Requires a real display (not headless). Metrics are desktop measurements,
## not a mobile benchmark.

var OUT := "res://docs/previews/forest/"
var metrics := {}

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Las capturas exigen render real")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			OUT = arg.substr(6)
	call_deferred("capture")

func zone(renovated: bool) -> Node3D:
	ProjectSettings.set_setting("visuals/forest/renovated", renovated)
	var scene: Node3D = load("res://scenes/forest_zone.tscn").instantiate()
	scene.session.mission.intro_seen = true
	root.add_child(scene)
	return scene

func save(file: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + file + ".png")
	print("captura ", file)

func measure(label: String) -> void:
	for i in 30:
		await process_frame
	var start := Time.get_ticks_usec()
	var frames := 180
	for i in frames:
		await process_frame
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	metrics[label] = {
		"viewport": [root.size.x, root.size.y],
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"video_mem_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"texture_mem_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"buffer_mem_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0, 0.1),
		"desktop_fps_vsync": snappedf(frames / elapsed, 0.1),
		"adapter": RenderingServer.get_video_adapter_name(),
	}

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	for renovated in [false, true]:
		var label := "after" if renovated else "before"
		if not only.is_empty() and only != label:
			continue
		root.size = Vector2i(1280, 720)
		var scene := zone(renovated)
		await process_frame
		for size in [Vector2i(1280, 720), Vector2i(960, 640), Vector2i(800, 450)]:
			root.size = size
			await save("%s-%dx%d" % [label, size.x, size.y])
		root.size = Vector2i(1280, 720)
		await measure(label)
		if renovated:
			metrics.after["art"] = scene.get_node("ForestArt").stats
			await views(scene)
		scene.free()
		await process_frame
	var file := FileAccess.open(OUT + "metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t") + "\n")
	quit()

func views(scene: Node3D) -> void:
	var camera: Camera3D = scene.get_node("ForestCamera")
	var hud: Array[CanvasLayer] = []
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		hud.append(layer)
	# Kael walking the main trail, in the default gameplay framing.
	scene.player.position = Vector3(-2.6, 0.05, 1.3)
	scene.player.model.rotation.y = atan2(1, -0.4)
	await save("after-kael-trail")
	var original := camera.transform
	# Same angle as the legacy capture: orthographic, size 18, from (0, 17, 18).
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18
	camera.look_at_from_position(Vector3(0, 17, 18), Vector3.ZERO)
	scene.player.position = GameSession.SPAWN
	await save("after-legacy-angle")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	for layer in hud:
		layer.visible = false
	var shots := {
		"after-overview": [Vector3(0, 21, 17), Vector3(0, 0, -2.5), 46.0],
		"after-path": [Vector3(-7.5, 4.2, 9.5), Vector3(0.5, 0.6, -1.5), 50.0],
		"after-ruins": [Vector3(2.5, 3.6, 3.2), Vector3(-0.6, 1.8, -5.5), 55.0],
		"after-sentinels": [Vector3(-1.5, 6.5, 6.5), Vector3(3.0, 0.4, -1.4), 48.0],
		"after-lighting": [Vector3(6.5, 2.2, 7.5), Vector3(-1.5, 1.6, -3.5), 52.0],
	}
	scene.player.position = Vector3(-2.2, 0.05, 2.4)
	for file in shots:
		var shot: Array = shots[file]
		camera.fov = shot[2]
		camera.look_at_from_position(shot[0], shot[1])
		await save(file)
	camera.transform = original
	camera.fov = ForestArt.CAMERA_FOV
	for layer in hud:
		layer.visible = true
