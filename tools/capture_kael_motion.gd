extends SceneTree

# Use --write-movie <temporary-path.avi> --fixed-fps 30, then encode that capture.
# The displayed character is the imported GLB, sampled through AnimationPlayer.
var studio: Node3D
var frame := 0
const FPS := 30
const SEGMENT_FRAMES := 60
const CLIPS := ["Idle", "Walk", "Attack", "Hurt", "Defend", "KO"]

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("La captura de movimiento necesita render real")
		quit(1)
		return
	call_deferred("start")

func start() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 640)
	var polished := "--polished" in OS.get_cmdline_user_args()
	var scene_path := "res://scenes/kael_polish_preview.tscn" if polished else "res://scenes/kael_reference_preview.tscn"
	if "--retro" in OS.get_cmdline_user_args():
		scene_path = "res://scenes/kael_retro_preview.tscn"
	studio = load(scene_path).instantiate()
	root.add_child(studio)
	if studio.model == null:
		quit(1)
		return
	studio.hud.visible = false
	var layer := CanvasLayer.new()
	studio.add_child(layer)
	var caption := Label.new()
	caption.name = "MotionCaption"
	caption.position = Vector2(22, 18)
	caption.add_theme_font_size_override("font_size", 24)
	layer.add_child(caption)
	studio.set_meta("caption", caption)
	process_frame.connect(sample)

func sample() -> void:
	if frame >= CLIPS.size() * SEGMENT_FRAMES:
		quit()
		return
	var clip: String = CLIPS[frame / SEGMENT_FRAMES]
	var local_frame := frame % SEGMENT_FRAMES
	var ap: AnimationPlayer = studio.model.animation_player
	if local_frame == 0:
		studio.model.reset_pose()
		ap.play(clip, 0)
		ap.advance(0)
	var elapsed := float(local_frame) / FPS
	var length := ap.get_animation(clip).length
	var time := fmod(elapsed, length) if clip in ["Idle", "Walk"] else minf(elapsed, length)
	ap.seek(time, true)
	ap.pause()
	var label: Label = studio.get_meta("caption")
	label.text = "KAEL · " + clip + " · animación provisional"
	frame += 1
