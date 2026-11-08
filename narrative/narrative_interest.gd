class_name NarrativeInterest
extends Node3D

var id: String
var title: String
var interaction_radius: float
var available: bool = true
var examined: bool = false
var caption: Label3D
var ring: MeshInstance3D
var _energy: Node3D
var _phase: float = 0.0

func configure(definition: Dictionary) -> void:
	id = definition.id
	title = definition.title
	position = definition.position
	interaction_radius = definition.radius

func _ready() -> void:
	var stone := StylizedModels.mat("899184")
	var cloth := StylizedModels.mat("9d9276")
	var wood := StylizedModels.mat("66503d")
	match id:
		"camp":
			BattleActorVisual._box(self, Vector3(1.25, 0.12, 0.65), Vector3(0, 0.09, 0), cloth)
			StylizedModels.rock(self, Vector3(-0.47, 0.22, 0), Vector3(0.28, 0.3, 0.6), cloth)
			BattleActorVisual._box(self, Vector3(0.46, 0.4, 0.4), Vector3(0.65, 0.2, -0.45), wood)
			StylizedModels.gem(self, Vector3(0.18, 0.2, 0.08), Vector3(0.17, 0.08, 0.17), StylizedModels.mat("cdb37e"))
			for i in range(5):
				var angle := i * TAU / 5
				StylizedModels.rock(self, Vector3(cos(angle) * 0.34, 0.1, sin(angle) * 0.34 - 0.9), Vector3(0.23, 0.2, 0.25), stone, i)
			StylizedModels.rod(self, Vector3(-0.2, 0.1, -1), Vector3(0.2, 0.1, -0.8), 0.07, wood)
		"crystal":
			StylizedModels.rock(self, Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.8), stone)
			for i in range(3):
				var angle := i * TAU / 3
				StylizedModels.rod(self, Vector3(cos(angle) * 0.25, 0.07, sin(angle) * 0.25), Vector3(cos(angle) * 0.9, 0.035, sin(angle) * 0.9), 0.035, StylizedModels.mat("464438"))
			_energy = Node3D.new()
			_energy.position.y = 0.65
			add_child(_energy)
			StylizedModels.gem(_energy, Vector3.ZERO, Vector3(0.3, 0.85, 0.3), StylizedModels.mat("b1a0d9", true))
		"inscription":
			var tablet := BattleActorVisual._box(self, Vector3(0.85, 0.95, 0.22), Vector3(0, 0.5, 0), stone)
			tablet.rotation.x = -0.12
			for i in range(5):
				var glyph := BattleActorVisual._box(self, Vector3(0.35 + 0.12 * sin(i), 0.025, 0.03), Vector3(0, 0.75 - i * 0.12, 0.15), StylizedModels.mat("516b62"))
				glyph.rotation.z = 0.14 * (1 if i % 2 == 0 else -1)
		"anomaly":
			_energy = Node3D.new()
			add_child(_energy)
			StylizedModels.ring(_energy, Vector3(0, 0.05, 0), 0.7, StylizedModels.mat("a098bc", true))
			for i in range(4):
				StylizedModels.gem(_energy, Vector3(cos(i * TAU / 4) * 0.35, 0.4, sin(i * TAU / 4) * 0.35), Vector3(0.08, 0.24, 0.08), StylizedModels.mat("bab0dc", true))
	ring = StylizedModels.ring(self, Vector3(0, 0.04, 0), 0.5, StylizedModels.mat("c8bb8e", true))
	ring.visible = false
	caption = Label3D.new()
	caption.text = title
	caption.position = Vector3(0, 0.15, 1.9)
	caption.font_size = 27
	caption.pixel_size = 0.011
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.no_depth_test = true
	caption.visible = false
	add_child(caption)
	if id == "anomaly":
		set_available(false)

func in_range(player_position: Vector3) -> bool:
	var offset := player_position - position
	return available and absf(offset.y) < 2 and Vector2(offset.x, offset.z).length() <= interaction_radius

func set_available(value: bool) -> void:
	available = value
	visible = value

func show_prompt(value: bool) -> void:
	ring.visible = value and available
	caption.visible = value and available
	caption.text = title + (" · Revisar" if examined else "")

func reveal_energy() -> void:
	if _energy != null:
		_energy.scale = Vector3.ONE * 1.4

func _process(delta: float) -> void:
	if _energy != null and available:
		_phase += delta
		_energy.rotation.y += delta * 0.35
		_energy.position.y = (0.65 if id == "crystal" else 0.0) + sin(_phase * 1.8) * 0.05
