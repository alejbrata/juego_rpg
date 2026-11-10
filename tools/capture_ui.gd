extends SceneTree
## Real-render captures of the battle and exploration interfaces (iteration 1.5).
## godot --path . --script res://tools/capture_ui.gd -- --tag=after [--out=res://docs/previews/ui/]
## Same scenes, camera and states for every tag, so "before"/"after" compare 1:1.

var OUT := "res://docs/previews/ui/"
var TAG := "after"
const SIZES := {"16x9": Vector2i(1280, 720), "19x9": Vector2i(1560, 720), "960x540": Vector2i(960, 540)}

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Las capturas exigen render real")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			OUT = arg.substr(6)
		elif arg.begins_with("--tag="):
			TAG = arg.substr(6)
	# -- --touch: touch HUD (joystick, right-hand action) as on a phone.
	if TouchControls.enabled():
		TouchControls.configure(self)
	call_deferred("capture")

func save(file: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s%s-%s.png" % [OUT, TAG, file])
	print("captura ", TAG, "-", file)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await battle()
	await exploration()
	quit()

func battle() -> void:
	root.size = SIZES["16x9"]
	var stage = load("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	root.add_child(stage)
	await process_frame
	var ui = stage.hud
	for size_name: String in SIZES:
		root.size = SIZES[size_name]
		await save("battle-" + size_name)
	root.size = SIZES["16x9"]
	# Active hero choosing a target (Lyra's Flame).
	ui._choose(ui.engine.fighters[1].data.abilities[0])
	await save("target")
	ui._cancel_selection()
	# Ally target (Kael's Protection): Lyra acts on the enemy first.
	ui.actions.get_child(0).pressed.emit()
	ui.targets.get_child(0).pressed.emit()
	stage.skip_presentation()
	ui._choose(ui.engine.fighters[0].data.abilities[1])
	await save("target-ally")
	ui._cancel_selection()
	# Resonance full and the summon offered to Ignar's carrier.
	ui._restart()
	ui.run.resonance = 100
	ui._refresh()
	await save("resonance")
	ui.run.resonance = 0
	# Low HP and altered states (presentation of existing engine state only).
	ui._restart()
	ui.engine.fighters[0].hp = 18
	ui.engine.fighters[0].protection_target = 1
	ui.engine.fighters[2].haste_rounds = 2
	ui.engine.fighters[2].hp = 31
	ui.engine.fighters[3].defense_down_rounds = 2
	ui.engine.fighters[3].defense_down_amount = 0.25
	ui._refresh()
	stage._sync_state()
	await save("states")
	for size_name in ["19x9", "960x540"]:
		root.size = SIZES[size_name]
		await save("states-" + size_name)
	root.size = SIZES["16x9"]
	ui.toggle_log()
	await save("log")
	ui.toggle_log()
	stage.free()
	await process_frame

func exploration() -> void:
	root.size = SIZES["16x9"]
	var zone = load("res://scenes/forest_zone.tscn").instantiate()
	root.add_child(zone)
	await process_frame
	await save("dialogue")
	while zone.dialogue.active:
		zone.dialogue.advance()
		await process_frame
	for size_name: String in SIZES:
		root.size = SIZES[size_name]
		await save("exploration-" + size_name)
	root.size = SIZES["16x9"]
	# Next to the camp clue: interaction prompt.
	zone.player.position = zone.interests.camp.position + Vector3(0.9, 0, 0.6)
	for i in 4:
		await physics_frame
	await save("interact")
	if zone.joystick != null:
		for size_name in ["19x9", "960x540"]:
			root.size = SIZES[size_name]
			await save("interact-" + size_name)
		root.size = SIZES["16x9"]
		# Finger resting on the stick (inside the dead zone: the hero stays by the clue).
		var base: Vector2 = zone.joystick.get_global_rect().position + Vector2(120, zone.joystick.size.y - 120)
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = base
		press.pressed = true
		zone.joystick._input(press)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = base + Vector2(0.12, -0.09) * TouchJoystick.RADIUS
		zone.joystick._input(drag)
		await save("joystick-held")
		press.pressed = false
		zone.joystick._input(press)
	zone.interact(zone._nearest_interest)
	await save("dialogue-clue")
	zone.free()
