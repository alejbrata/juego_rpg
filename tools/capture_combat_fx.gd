extends SceneTree
## Iteration 1.7: combat presentation clips (attack, spells, support, hits, KO,
## selection, summon). Run under Movie Maker so every frame advances a fixed time:
##   godot --path . --write-movie <dir>/combat.avi --fixed-fps 30 --resolution 1280x720 \
##         --script res://tools/capture_combat_fx.gd
## Prints "CLIP <name> <first_frame> <last_frame>" for tools/combat_fx_clips.py,
## which cuts the AVI (video + audio) into MP4/GIF clips and stills.
## Only the public HUD flow is used; state set-up (HP, Resonance, turn) mirrors the
## existing UI capture tool and never alters rules.

const FPS := 30
var stage
var ui
var engine: BattleEngine

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await process_frame

func run() -> void:
	stage = load("res://scenes/battle_3d.tscn").instantiate()
	root.add_child(stage)
	await frames(10)
	ui = stage.hud
	engine = ui.engine
	await clip("ataque", 0, "Ataque", "Centinela de piedra")
	await clip("golpe-potente", 0, "Golpe potente", "Centinela de piedra")
	await clip("llama", 1, "Llama", "Centinela de piedra")
	await clip("escarcha", 1, "Escarcha", "Centinela de piedra")
	await clip("cura", 2, "Cura", "Kael", func() -> void: engine.fighters[0].hp = 40)
	await clip("proteccion", 0, "Protección", "Lyra")
	await clip("impulso", 2, "Impulso", "Kael")
	await clip("dano-recibido", 3, "", "")
	await clip("ko-heroe", 3, "", "", func() -> void:
		for f in engine.fighters:
			if not f.enemy:
				f.hp = 1)
	await clip("ko-enemigo", 0, "Golpe potente", "Centinela de piedra", func() -> void: engine.fighters[3].hp = 5)
	await selection()
	await clip("invocacion", 1, "Invocar", "", func() -> void: ui.run.resonance = 100)
	quit()

## Brings the turn to `actor_id` through the normal HUD (Defender / enemy step),
## with the presentation skipped, then clears the guard poses for a clean shot.
func advance_to(actor_id: int) -> void:
	ui.run.resonance = 0
	ui._restart()
	await frames(2)
	for i in 12:
		if engine.current_id() == actor_id:
			break
		var buttons: Array = ui.actions.get_children()
		buttons[0 if engine.phase == BattleEngine.Phase.ENEMY_TURN else 1].pressed.emit()
		if ui.targets.visible:
			ui.targets.get_child(0).pressed.emit()
		stage.skip_presentation()
		await frames(1)
	for f in engine.fighters:
		f.guarding = false
	stage._sync_state()
	ui._refresh()

func press(title: String) -> Button:
	for button in ui.actions.get_children():
		var label := String(button.get_meta("title", button.text))
		if label.begins_with(title):
			return button
	return null

func clip(clip_name: String, actor_id: int, action: String, target: String, setup: Callable = Callable()) -> void:
	await advance_to(actor_id)
	if setup.is_valid():
		setup.call()
		stage._sync_state()
		ui._refresh()
	await frames(12)
	var first := Engine.get_frames_drawn()
	if action.is_empty():
		ui.actions.get_child(0).pressed.emit()   # enemy step (also resolves on its own)
	else:
		var button := press(action)
		if button == null:
			printerr("Sin acción ", action)
		else:
			button.pressed.emit()
	await frames(3)
	if ui.targets.visible:
		for button in ui.targets.get_children():
			if String(button.get_meta("title", button.text)) == target:
				button.pressed.emit()
	await frames(int(2.6 * FPS))
	print("CLIP %s %d %d" % [clip_name, first, Engine.get_frames_drawn()])

func selection() -> void:
	await advance_to(1)
	await frames(6)
	var first := Engine.get_frames_drawn()
	press("Llama").pressed.emit()
	await frames(int(1.2 * FPS))
	print("CLIP %s %d %d" % ["seleccion", first, Engine.get_frames_drawn()])
	ui._cancel_selection()
