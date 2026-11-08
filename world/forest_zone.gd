extends Node3D

signal encounter_requested(encounter: EncounterData)
signal new_game_requested

@export var encounters: Array[EncounterData] = []
var session := GameSession.new()
var player: CharacterBody3D
var markers: Dictionary[String, Node3D] = {}
var encounter_armed: bool = true
var info: Label
var hint: Label

func _ready() -> void:
	_build_environment()
	player = preload("res://world/exploration_player.gd").new()
	player.name = "Leader"
	player.position = session.leader_position
	add_child(player)
	for encounter in encounters:
		if not encounter.validation_error().is_empty():
			push_error(encounter.validation_error())
			continue
		_build_marker(encounter)
	_build_hud()
	refresh_from_session()

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("263e43")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8d5d0")
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("ffe1b0")
	sun.light_energy = 0.9
	add_child(sun)
	var camera := Camera3D.new()
	camera.name = "ForestCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18
	camera.position = Vector3(0, 17, 18)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	_solid_box("Ground", Vector3(18, 0.4, 14), Vector3(0, -0.2, 0), Color("62765d"))
	var path := BattleActorVisual._material(Color("a59976"))
	BattleActorVisual._box(self, Vector3(14, 0.02, 2), Vector3(0, 0.015, 1), path)
	BattleActorVisual._box(self, Vector3(2, 0.02, 6), Vector3(-5, 0.02, 2.5), path)
	var stone := Color("7f8a81")
	_solid_box("WestBoundary", Vector3(0.5, 0.9, 14), Vector3(-8.75, 0.45, 0), stone)
	_solid_box("EastBoundary", Vector3(0.5, 0.9, 14), Vector3(8.75, 0.45, 0), stone)
	_solid_box("NorthBoundary", Vector3(18, 0.9, 0.5), Vector3(0, 0.45, -6.75), stone)
	_solid_box("SouthBoundary", Vector3(18, 0.9, 0.5), Vector3(0, 0.45, 6.75), stone)
	_solid_box("RockA", Vector3(1.2, 0.9, 0.9), Vector3(-1.3, 0.45, 4.8), Color("738582"))
	_solid_box("RockB", Vector3(1, 1.1, 1.2), Vector3(4.3, 0.55, 3.3), Color("738582"))
	for at in [Vector3(-7, 0, -4.5), Vector3(-7.4, 0, 0), Vector3(-7.3, 0, 4.8), Vector3(-3.5, 0, -4.7), Vector3(0, 0, -5), Vector3(3.4, 0, -5.2), Vector3(7.1, 0, -4.6), Vector3(7.2, 0, 0), Vector3(7.2, 0, 4.7)]:
		_tree(at)
	for at in [Vector3(-2.7, 0, -1.5), Vector3(2.1, 0, -1.5)]:
		_solid_box("RuinedColumn", Vector3(0.65, 1.8, 0.65), at + Vector3.UP * 0.9, stone)
		BattleActorVisual._box(self, Vector3(1, 0.25, 1), at + Vector3.UP * 1.9, BattleActorVisual._material(stone))

func _solid_box(label: String, size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	BattleActorVisual._box(body, size, Vector3.ZERO, BattleActorVisual._material(color))
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body

func _tree(at: Vector3) -> void:
	var trunk := _solid_box("TreeTrunk", Vector3(0.5, 2.2, 0.5), at + Vector3.UP * 1.1, Color("725c43"))
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.2
	crown.height = 2.6
	crown.radial_segments = 7
	BattleActorVisual._mesh(trunk, crown, Vector3.UP * 1.3, BattleActorVisual._material(Color("365d4e")))

func _build_marker(encounter: EncounterData) -> void:
	var marker := Node3D.new()
	marker.name = encounter.id
	marker.position = encounter.map_position
	add_child(marker)
	markers[encounter.id] = marker
	var actor := BattleActorVisual.new()
	marker.add_child(actor)
	actor.build(BattleEngine.Fighter.new(encounter.enemies[0], true))
	actor.scale = Vector3.ONE * 0.7
	actor.caption.visible = false
	actor.turn_ring.visible = false
	actor.shield.visible = false
	var ring := CylinderMesh.new()
	ring.top_radius = encounter.detection_radius
	ring.bottom_radius = encounter.detection_radius
	ring.height = 0.025
	ring.radial_segments = 24
	var material := BattleActorVisual._material(Color(0.95, 0.62, 0.26, 0.22), true)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	BattleActorVisual._mesh(marker, ring, Vector3.UP * 0.025, material)
	var label := Label3D.new()
	label.text = encounter.label
	label.position.y = 2.1
	label.font_size = 32
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	marker.add_child(label)
	var area := Area3D.new()
	area.name = "EncounterArea"
	area.collision_layer = 0
	area.collision_mask = 2
	marker.add_child(area)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = encounter.detection_radius
	collider.shape = shape
	collider.position.y = 0.8
	area.add_child(collider)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body == player:
			request_encounter(encounter))

func request_encounter(encounter: EncounterData) -> bool:
	if not encounter_armed or session.mode != GameSession.Mode.EXPLORING or session.defeated_encounters.has(encounter.id) or not encounters.has(encounter):
		return false
	var offset := player.position - encounter.map_position
	if Vector2(offset.x, offset.z).length() > encounter.detection_radius + 0.35:
		return false
	encounter_armed = false
	player.movement_enabled = false
	player.velocity = Vector3.ZERO
	encounter_requested.emit(encounter)
	return true

func refresh_from_session() -> void:
	for id in session.defeated_encounters:
		if markers.has(id):
			var marker := markers[id]
			marker.get_node("EncounterArea").set_deferred("monitoring", false)
			marker.visible = false
			markers.erase(id)
			marker.queue_free()
	encounter_armed = true
	player.movement_enabled = true
	player.clear_movement_input()
	player.velocity = Vector3.ZERO
	var carrier := "sin portador"
	for hero in session.heroes:
		var guardian := session.party.guardian_for(hero.id)
		if guardian != null and guardian.id == "ignar":
			carrier = hero.label
	var progress := session.party.progress("ignar")
	info.text = "Bosque del Eclipse · Claro de las ruinas\nKael · Lyra · Nira    RE %d/100 · Ignar → %s · Nv %d · %d PA · Encuentros %d/%d" % [session.party.resonance, carrier, progress.level(session.party.definition("ignar")), progress.affinity, session.defeated_encounters.size(), encounters.size()]
	if session.defeated_encounters.size() == encounters.size():
		hint.text = "Claro despejado. Fin de la zona de prueba.\nWASD / flechas: mover a Kael · Nueva partida: repetir"
	else:
		hint.text = "%s\nWASD / flechas: mover a Kael · Los círculos naranjas activan encuentros" % session.message

func _build_hud() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)
	info = Label.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info.offset_left = 18
	info.offset_right = -18
	info.offset_top = 14
	info.offset_bottom = 100
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_outline_color", Color("182a30"))
	info.add_theme_constant_override("outline_size", 6)
	root.add_child(info)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 18
	hint.offset_right = -220
	hint.offset_top = -92
	hint.offset_bottom = -8
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_constant_override("outline_size", 5)
	root.add_child(hint)
	var restart := Button.new()
	restart.text = "Nueva partida"
	restart.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	restart.offset_left = -200
	restart.offset_top = -62
	restart.offset_right = -16
	restart.offset_bottom = -14
	restart.pressed.connect(func() -> void: new_game_requested.emit())
	root.add_child(restart)
