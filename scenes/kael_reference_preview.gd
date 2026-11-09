extends Node3D

# Independent visual review scene. Never writes game settings or persistent state.
const CANDIDATE := "res://assets/characters/kael/reference_study/kael.glb"
@export_file("*.glb") var candidate_path: String = CANDIDATE
@export_file("*.glb") var comparison_path: String = KaelModel.ASSET_PATH
@export var polished_view := false
var model: KaelModel
var camera: Camera3D
var hud: CanvasLayer
var status: Label
var current_path: String = CANDIDATE
var rotating := false

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("171d29")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b6c5dd")
	world.environment.ambient_light_energy = 0.30
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(world)
	_light(Vector3(-35, -35, 0), Color("fff0db"), 0.80, true)
	_light(Vector3(-15, 130, 0), Color("a4c9ff"), 0.65, false)
	_light(Vector3(15, 30, 0), Color("d1dced"), 0.12, false)
	var floor_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.25
	cylinder.bottom_radius = 1.30
	cylinder.height = 0.045
	cylinder.radial_segments = 64
	floor_mesh.mesh = cylinder
	floor_mesh.position.y = -0.023
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3b4350")
	mat.roughness = 0.95
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 32
	camera.near = 0.02
	add_child(camera)
	camera.current = true
	full_view()
	_build_hud()
	load_character(candidate_path)

func _light(degrees: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = degrees
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.shadow_enabled = shadows
	add_child(lamp)

func load_character(path: String) -> bool:
	var next := KaelModel.new()
	add_child(next)
	if not next.load_asset(path):
		next.queue_free()
		status.text = "ERROR: no se pudo cargar " + path
		return false
	if is_instance_valid(model):
		model.free()
	model = next
	current_path = path
	status.text = "KAEL · " + path.get_base_dir().get_file() + " · revisión artística"
	return true

func full_view() -> void:
	camera.position = Vector3(2.0, 1.35, 4.2)
	camera.look_at(Vector3(0, 1.0, 0))
	if polished_view:
		camera.position = Vector3(2.25, 1.6, 4.7)
		camera.look_at(Vector3(0, 1.1, 0))

func face_view() -> void:
	camera.position = Vector3(0.22, 1.76, 0.80)
	camera.look_at(Vector3(0, 1.72, 0))
	if polished_view:
		camera.position = Vector3(0.24, 2.05, 1.1)
		camera.look_at(Vector3(0, 1.98, 0))

func _process(delta: float) -> void:
	if rotating and is_instance_valid(model):
		model.rotation.y += delta * 0.45

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 20)
	layout.add_child(status)
	var sub := Label.new()
	sub.text = "Malla local · luz de estudio · sin cambios en el juego"
	sub.add_theme_color_override("font_color", Color("a5b5cb"))
	layout.add_child(sub)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(spacer)
	var actions := HFlowContainer.new()
	for clip in KaelModel.REQUIRED:
		_button(actions, clip, func(): _preview_clip(clip))
	layout.add_child(actions)
	var views := HFlowContainer.new()
	_button(views, "Cuerpo", full_view)
	_button(views, "Rostro", face_view)
	_button(views, "Girar / parar", func(): rotating = not rotating)
	_button(views, "Frente", func(): model.rotation.y = 0; rotating = false)
	_button(views, "Anterior / candidato", func(): load_character(comparison_path if current_path == candidate_path else candidate_path))
	layout.add_child(views)
	var play := HFlowContainer.new()
	_button(play, "Probar combate", func(): _play("res://scenes/battle_3d.tscn"))
	_button(play, "Probar exploración", func(): _play("res://scenes/forest_exploration.tscn"))
	layout.add_child(play)

func _play(scene_path: String) -> void:
	ProjectSettings.set_setting("visuals/kael/use_imported", true)
	ProjectSettings.set_setting("visuals/kael/asset_version", "polished" if current_path.contains("/polished/") else ("reference-study" if current_path == CANDIDATE else "0.9"))
	if current_path.contains("/retro/"):
		ProjectSettings.set_setting("visuals/kael/asset_version", "retro")
	get_tree().change_scene_to_file(scene_path)

func _preview_clip(clip: String) -> void:
	model.reset_pose()
	if clip in ["Attack", "Hurt"]:
		model.play_action(clip, model.animation_player.get_animation(clip).length)
	else:
		model.set_pose(clip)

func _button(parent: Control, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(action)
	parent.add_child(button)
