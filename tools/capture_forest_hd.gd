extends SceneTree
## Real-render captures of the HD Eclipse clearing (iteration 1.3, Forward+).
## godot --path . --script res://tools/capture_forest_hd.gd [-- --out=res://... --quick]
## Desktop metrics only; not a mobile benchmark.

var OUT := "res://docs/previews/forest-hd/"
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

func zone(hd: bool) -> Node3D:
	ProjectSettings.set_setting("visuals/forest/renovated", true)
	ProjectSettings.set_setting("visuals/forest/hd", hd)
	var scene: Node3D = load("res://scenes/forest_zone.tscn").instantiate()
	scene.session.mission.intro_seen = true
	root.add_child(scene)
	return scene

func save(file: String, settle: int = 24) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + file + ".png")
	print("captura ", file)

func measure(label: String) -> void:
	for i in 30:
		await process_frame
	var start := Time.get_ticks_usec()
	var frames := 120
	for i in frames:
		await process_frame
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	metrics[label] = {
		"viewport": [root.size.x, root.size.y],
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"video_mem_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"desktop_fps_vsync": snappedf(frames / elapsed, 0.1),
		"adapter": RenderingServer.get_video_adapter_name(),
	}

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var quick := "--quick" in OS.get_cmdline_user_args()
	for hd in ([true] if quick else [false, true]):
		var label := "hd" if hd else "renovated"
		root.size = Vector2i(1280, 720)
		var scene := zone(hd)
		await process_frame
		var sizes := [Vector2i(1280, 720)] if quick else [Vector2i(1280, 720), Vector2i(960, 640), Vector2i(800, 450)]
		for size in sizes:
			root.size = size
			await save("%s-%dx%d" % [label, size.x, size.y])
		root.size = Vector2i(1280, 720)
		if not quick:
			await measure(label)
			if hd:
				metrics[label]["art"] = scene.get_node("ForestArt").stats
		await views(scene, label)
		scene.free()
		await process_frame
	if not quick:
		var file := FileAccess.open(OUT + "metrics.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(metrics, "\t") + "\n")
	quit()

## Close views for inspection (the gameplay camera is restored afterwards).
func views(scene: Node3D, label: String) -> void:
	var camera: Camera3D = scene.get_node("ForestCamera")
	var keep := camera.transform
	var player: Node3D = scene.player
	var shots := [
		["ruins", Vector3(0, 3.2, 3.5), Vector3(0, 1.2, -4.0)],
		["camp", Vector3(-1.5, 2.6, 6.0), Vector3(-4.5, 0.6, 2.0)],
		["crystal", Vector3(6.0, 2.4, 2.4), Vector3(3.1, 0.6, -0.5)],
		["player", player.global_position + Vector3(1.6, 1.5, 3.2), player.global_position + Vector3(0, 0.9, 0)],
	]
	for shot in shots:
		camera.look_at_from_position(shot[1], shot[2])
		await save("%s-view-%s" % [label, shot[0]])
	camera.transform = keep
