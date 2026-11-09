extends SceneTree

# Real Godot viewport recording, with the battle's unchanged lights/environment.
# --write-movie <temporary-path.avi> --fixed-fps 30
const FPS := 30
const SEGMENT_FRAMES := 60
const CLIPS := ["Idle", "Walk", "Attack", "Hurt", "Defend", "KO", "Cast"]
var stage: Node3D
var caption: Label
var frame := 0

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("La captura de movimiento necesita render real")
		quit(1)
		return
	call_deferred("start")

func start() -> void:
	root.size = Vector2i(960, 640)
	ProjectSettings.set_setting("visuals/lyra/use_imported", true)
	ProjectSettings.set_setting("visuals/nira/use_imported", true)
	stage = load("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	root.add_child(stage)
	stage.hud.visible = false
	stage.set_process(false)
	for actor: BattleActorVisual in stage.visuals:
		actor.set_process(false)
		actor.nameplate.visible = false
		actor.turn_ring.visible = false
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(22, 18)
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_constant_override("outline_size", 6)
	layer.add_child(caption)
	process_frame.connect(sample)

func sample() -> void:
	if frame >= CLIPS.size() * SEGMENT_FRAMES * 2:
		quit()
		return
	var hero_index := frame / (CLIPS.size() * SEGMENT_FRAMES) + 1
	var clip: String = CLIPS[(frame / SEGMENT_FRAMES) % CLIPS.size()]
	if clip == "Cast" and hero_index == 2:
		clip = "Support"
	var actor: BattleActorVisual = stage.visuals[hero_index]
	var local_frame := frame % SEGMENT_FRAMES
	var ap: AnimationPlayer = actor.imported_model.animation_player
	if local_frame == 0:
		for other: BattleActorVisual in stage.visuals:
			other.visible = other == actor
		var target := actor.home + Vector3.UP * 1.1
		stage.camera.position = target + Vector3(2.4, .7, 3.2)
		stage.camera.look_at(target)
		actor.imported_model.reset_pose()
		ap.play(clip, 0)
		ap.advance(0)
	var elapsed := float(local_frame) / FPS
	var duration := ap.get_animation(clip).length
	ap.seek(fmod(elapsed, duration) if clip in ["Idle", "Walk"] else minf(elapsed, duration), true)
	ap.pause()
	caption.text = ("LYRA" if hero_index == 1 else "NIRA") + " · " + clip + " · GLB en Godot"
	if clip == "Walk":
		caption.text += " (en el sitio)"
	frame += 1
