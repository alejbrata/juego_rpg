extends Node3D
## Visor del grupo (1.4): un personaje solo, girando, con todas sus animaciones.
## Abrir scenes/party_hd_preview.tscn y pulsar F6. Solo lectura: no guarda ajustes.
## 1/2/3 o ↑/↓: personaje · ←/→: animación · Espacio: girar/parar · rueda: zoom · arrastrar: rotar.

const HEROES := ["kael", "lyra", "nira"]
const NAMES := {"kael": "Kael (guerrero)", "lyra": "Lyra (maga)", "nira": "Nira (sanadora)"}
const CLIP_NAMES := {"Idle": "Reposo", "Walk": "Caminar", "Attack": "Ataque", "Hurt": "Recibe daño",
	"Defend": "Defensa", "KO": "Derrota", "Cast": "Hechizo", "Support": "Apoyo"}

var pivot := Node3D.new()
var camera := Camera3D.new()
var model: KaelModel
var hero := 0
var clip := 0
var clips: Array[String] = []
var spinning := true
var distance := 4.6
var label := Label.new()
var _wait := 0.0

func _ready() -> void:
	# Only in memory: shows the HD party when installed, the current models otherwise.
	ProjectSettings.set_setting("visuals/party/style", "hd")
	ProjectSettings.set_setting("visuals/lyra/use_imported", true)
	ProjectSettings.set_setting("visuals/nira/use_imported", true)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	if ResourceLoader.exists(ForestArtHD.SKY_PATH):
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load(ForestArtHD.SKY_PATH)
		env.sky.sky_material = panorama
	else:
		env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.2
	disc.bottom_radius = 2.25
	disc.height = 0.04
	disc.radial_segments = 64
	ground.mesh = disc
	ground.position.y = -0.02
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("4a4f43")
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	add_child(ground)
	add_child(pivot)
	camera.fov = 35
	add_child(camera)
	camera.current = true
	var hud := CanvasLayer.new()
	add_child(hud)
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	hud.add_child(label)
	show_hero(0)

func show_hero(index: int) -> void:
	hero = wrapi(index, 0, HEROES.size())
	if model != null:
		model.queue_free()
	var id: String = HEROES[hero]
	if id == "kael":
		model = KaelModel.new()
		pivot.add_child(model)
		model.load_asset(KaelModel.styled_path("kael", "res://assets/characters/kael/retro/kael.glb"))
	else:
		model = CompanionModel.new()
		model.hero_id = id
		pivot.add_child(model)
		model.load_asset()
	clips = model._required_clips() if model.animation_player != null else []
	clip = 0
	play_clip()

func play_clip() -> void:
	if clips.is_empty():
		_update_label()
		return
	clip = wrapi(clip, 0, clips.size())
	var clip_name: String = clips[clip]
	model.reset_pose()
	model.animation_player.speed_scale = 1.0
	model.animation_player.play(clip_name, 0.15)
	_wait = 0.0
	_update_label()

func _update_label() -> void:
	var id: String = HEROES[hero]
	var hd: bool = model != null and model.asset != null and model.asset.scene_file_path == KaelModel.HD_PATHS[id]
	var lines := [NAMES[id] + ("" if hd else "   (modelo anterior: faltan los paquetes HD)")]
	if not clips.is_empty():
		var clip_name: String = clips[clip]
		lines.append("Animación %d/%d: %s (%s)" % [clip + 1, clips.size(), CLIP_NAMES.get(clip_name, clip_name), clip_name])
	lines.append("1/2/3 o ↑/↓ personaje · ←/→ animación · Espacio girar · rueda zoom · arrastrar rotar")
	label.text = "\n".join(lines)

func _process(delta: float) -> void:
	if spinning:
		pivot.rotation.y += delta * 0.5
	var target := Vector3(0, 1.05, 0)
	camera.position = target + Vector3(0, 0.35, distance)
	camera.look_at(target)
	# One-shot clips (attack, KO...) replay after a short pause so they can be watched again.
	if model != null and model.animation_player != null and not clips.is_empty() and not model.animation_player.is_playing():
		_wait += delta
		if _wait > 0.8:
			play_clip()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3:
				show_hero(event.keycode - KEY_1)
			KEY_UP:
				show_hero(hero - 1)
			KEY_DOWN:
				show_hero(hero + 1)
			KEY_RIGHT:
				clip += 1
				play_clip()
			KEY_LEFT:
				clip -= 1
				play_clip()
			KEY_SPACE:
				spinning = not spinning
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(1.2, distance - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(9.0, distance + 0.3)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		spinning = false
		pivot.rotation.y += event.relative.x * 0.01
