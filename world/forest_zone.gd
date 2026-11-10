extends Node3D

signal encounter_requested(encounter: EncounterData)
signal new_game_requested

@export var encounters: Array[EncounterData] = []
var session := GameSession.new()
var player: CharacterBody3D
var followers: PartyFollowers
var markers: Dictionary[String, Node3D] = {}
var encounter_armed: bool = true
var info: Label
var hint: Label
var dialogue: DialogueBox
var objective_label: Label
var interests: Dictionary[String, NarrativeInterest] = {}
var interact_button: Button
var _nearest_interest: String = ""
var _restart_button: Button
var _hud_root: Control
var _location_panel: PanelContainer
var _objective_box: VBoxContainer
var _menu_button: Button
var _menu_panel: PanelContainer
var _toast: PanelContainer
var _toast_tween: Tween
var joystick: TouchJoystick
var touch_ui := false
var _fingers: TouchControls.SecondaryFingers

func _ready() -> void:
	_build_environment()
	player = preload("res://world/exploration_player.gd").new()
	player.name = "Leader"
	player.position = session.leader_position
	add_child(player)
	# 1.4: Lyra and Nira follow the leader's path (presentation only, HD party).
	if PartyFollowers.enabled():
		followers = PartyFollowers.new()
		followers.name = "Followers"
		add_child(followers)
		followers.setup(player, player.model.position.y)
	var art := get_node_or_null("ForestArt") as ForestArt
	if art != null:
		art.reveal_subject = player
	for encounter in encounters:
		if not encounter.validation_error().is_empty():
			push_error(encounter.validation_error())
			continue
		_build_marker(encounter)
	_build_hud()
	_build_narrative()
	refresh_from_session()
	if not session.mission.intro_seen:
		_open_dialogue("intro", "El Bosque del Eclipse", true)

func _build_environment() -> void:
	if ForestArt.enabled():
		_build_renovated_environment()
		return
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

# Renovated art (1.1): identical gameplay colliders, presentation from ForestArt.
# Positions, sizes and layers are the same as the legacy branch below.
func _build_renovated_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	add_child(environment)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	var camera := Camera3D.new()
	camera.name = "ForestCamera"
	add_child(camera)
	var art: ForestArt = ForestArtHD.new() if ForestArtHD.enabled() else ForestArt.new()
	add_child(art)
	art.build()
	art.configure_environment(environment.environment, sun)
	art.configure_camera(camera)
	camera.current = true
	_solid_box("Ground", Vector3(18, 0.4, 14), Vector3(0, -0.2, 0), Color.BLACK, false)
	_solid_box("WestBoundary", Vector3(0.5, 0.9, 14), Vector3(-8.75, 0.45, 0), Color.BLACK, false)
	_solid_box("EastBoundary", Vector3(0.5, 0.9, 14), Vector3(8.75, 0.45, 0), Color.BLACK, false)
	_solid_box("NorthBoundary", Vector3(18, 0.9, 0.5), Vector3(0, 0.45, -6.75), Color.BLACK, false)
	_solid_box("SouthBoundary", Vector3(18, 0.9, 0.5), Vector3(0, 0.45, 6.75), Color.BLACK, false)
	_solid_box("RockA", Vector3(1.2, 0.9, 0.9), Vector3(-1.3, 0.45, 4.8), Color.BLACK, false)
	_solid_box("RockB", Vector3(1, 1.1, 1.2), Vector3(4.3, 0.55, 3.3), Color.BLACK, false)
	for at in [Vector3(-7, 0, -4.5), Vector3(-7.4, 0, 0), Vector3(-7.3, 0, 4.8), Vector3(-3.5, 0, -4.7), Vector3(0, 0, -5), Vector3(3.4, 0, -5.2), Vector3(7.1, 0, -4.6), Vector3(7.2, 0, 0), Vector3(7.2, 0, 4.7)]:
		_solid_box("TreeTrunk", Vector3(0.5, 2.2, 0.5), at + Vector3.UP * 1.1, Color.BLACK, false)
	for at in [Vector3(-2.7, 0, -1.5), Vector3(2.1, 0, -1.5)]:
		_solid_box("RuinedColumn", Vector3(0.65, 1.8, 0.65), at + Vector3.UP * 0.9, Color.BLACK, false)

func _solid_box(label: String, size: Vector3, at: Vector3, color: Color, visible_mesh: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	if visible_mesh:
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
	if dialogue.active or not session.mission.intro_seen or not encounter_armed or session.mode != GameSession.Mode.EXPLORING or session.defeated_encounters.has(encounter.id) or not encounters.has(encounter):
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
	encounter_armed = not dialogue.active and session.mission.intro_seen
	player.movement_enabled = encounter_armed and session.mode == GameSession.Mode.EXPLORING
	player.clear_movement_input()
	player.velocity = Vector3.ZERO
	var carrier := "sin portador"
	for hero in session.heroes:
		var guardian := session.party.guardian_for(hero.id)
		if guardian != null and guardian.id == "ignar":
			carrier = hero.label
	var progress := session.party.progress("ignar")
	info.text = "Bosque del Eclipse · Claro de las ruinas\nGrupo: Kael · Lyra · Nira\nResonancia: RE %d/100\nIgnar → %s · Nv %d · %d PA\nEncuentros superados: %d/%d" % [session.party.resonance, carrier, progress.level(session.party.definition("ignar")), progress.affinity, session.defeated_encounters.size(), encounters.size()]
	if session.defeated_encounters.size() == encounters.size():
		_show_notice("Claro despejado. Las ruinas aún guardan el rastro de la expedición.")
	else:
		_show_notice(session.message)
	_refresh_mission_ui()

## 1.5 exploration HUD: place and objective top-left, a menu with the party
## details and options top-right, a short interaction prompt and fading notices.
## Presentation only: texts come from GameSession/ExpeditionMission as before.
func _build_hud() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = EclipseUI.theme()
	overlay.add_child(root)
	_hud_root = root
	# Place and objective.
	_location_panel = EclipseUI.panel(root, 0.8)
	_location_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var place := VBoxContainer.new()
	place.add_theme_constant_override("separation", 2)
	_location_panel.add_child(place)
	EclipseUI.caption(place, "Bosque del Eclipse")
	EclipseUI.label(place, "Claro de las ruinas", 20, EclipseUI.IVORY, "title")
	_objective_box = VBoxContainer.new()
	_objective_box.add_theme_constant_override("separation", 2)
	place.add_child(_objective_box)
	var rule := ColorRect.new()
	rule.color = Color(EclipseUI.GOLD, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	_objective_box.add_child(rule)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 6)
	_objective_box.add_child(heading)
	UIIcon.make(heading, "technique", EclipseUI.GOLD, 14).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	EclipseUI.caption(heading, "Objetivo")
	objective_label = EclipseUI.label(_objective_box, "", 17, EclipseUI.IVORY, "medium")
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size.x = 280
	# Menu button and panel (party summary, controls, new game).
	_menu_button = Button.new()
	_menu_button.custom_minimum_size = Vector2(EclipseUI.TOUCH, EclipseUI.TOUCH)
	_menu_button.tooltip_text = "Grupo y opciones (Tab)"
	_menu_button.add_theme_stylebox_override("normal", EclipseUI.panel_box(0.8, Color(EclipseUI.GOLD, 0.55), 24))
	_menu_button.add_theme_stylebox_override("hover", EclipseUI.panel_box(0.92, EclipseUI.GOLD, 24))
	_menu_button.add_theme_stylebox_override("pressed", EclipseUI.panel_box(0.95, EclipseUI.GOLD_BRIGHT, 24))
	_menu_button.pressed.connect(toggle_menu)
	root.add_child(_menu_button)
	UIIcon.make(_menu_button, "menu", EclipseUI.IVORY, 22).set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu_panel = EclipseUI.panel(root, 0.95)
	_menu_panel.visible = false
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 6)
	_menu_panel.add_child(menu)
	EclipseUI.caption(menu, "Grupo")
	info = EclipseUI.label(menu, "", 16, EclipseUI.IVORY)
	EclipseUI.caption(menu, "Controles")
	EclipseUI.label(menu, "WASD / flechas: mover\nE: examinar · Tab: este menú\nCírculos naranjas: combate", 15, EclipseUI.IVORY_DIM)
	var restart := Button.new()
	restart.text = "Nueva partida"
	restart.custom_minimum_size = Vector2(220, EclipseUI.TOUCH)
	restart.pressed.connect(func() -> void:
		_menu_panel.visible = false
		new_game_requested.emit())
	menu.add_child(restart)
	_restart_button = restart
	var close := Button.new()
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(220, EclipseUI.TOUCH)
	close.pressed.connect(toggle_menu)
	menu.add_child(close)
	# Fading notice (session messages) bottom-left.
	_toast = EclipseUI.panel(root, 0.82, Color(EclipseUI.GOLD, 0.35))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint = EclipseUI.label(_toast, "", 16, EclipseUI.IVORY)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 300
	hint.visibility_changed.connect(func() -> void: _toast.visible = hint.visible)
	# Interaction prompt: key cap + verb + place, bottom centre.
	interact_button = Button.new()
	interact_button.custom_minimum_size = Vector2(260, 60 if TouchControls.enabled() else 52)
	for state in ["normal", "hover", "pressed", "focus"]:
		var pill := EclipseUI.panel_box(0.9 if state == "normal" else 0.97, Color(EclipseUI.GOLD, 0.8) if state == "normal" else EclipseUI.GOLD_BRIGHT, 26)
		pill.content_margin_left = 54
		pill.content_margin_right = 22
		interact_button.add_theme_stylebox_override(state, pill)
	interact_button.add_theme_font_size_override("font_size", 18)
	interact_button.pressed.connect(func() -> void: interact(_nearest_interest))
	interact_button.visible = false
	root.add_child(interact_button)
	var cap := PanelContainer.new()
	var cap_box := StyleBoxFlat.new()
	cap_box.bg_color = EclipseUI.GOLD
	cap_box.set_corner_radius_all(6)
	cap_box.set_content_margin_all(2)
	cap_box.content_margin_left = 8
	cap_box.content_margin_right = 8
	cap.add_theme_stylebox_override("panel", cap_box)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interact_button.add_child(cap)
	cap.position = Vector2(14, 13)
	EclipseUI.label(cap, "E", 15, EclipseUI.NIGHT, "bold")
	# 1.6 touch: joystick bottom-left, interaction bottom-right, notices on top.
	touch_ui = TouchControls.enabled()
	if touch_ui:
		joystick = TouchJoystick.new()
		joystick.name = "Joystick"
		root.add_child(joystick)
		root.move_child(joystick, 0)
		joystick.moved.connect(_on_joystick_moved)
		joystick.released.connect(func() -> void: player.clear_movement_input())
	_fingers = TouchControls.SecondaryFingers.new()
	_fingers.roots = [root]
	add_child(_fingers)
	root.resized.connect(_layout_hud)
	_layout_hud.call_deferred()

func _on_joystick_moved(vector: Vector2) -> void:
	if player.movement_enabled:
		player.set_movement_input(vector)
	else:
		player.clear_movement_input()

func _layout_hud() -> void:
	if _hud_root == null or not _hud_root.is_inside_tree():
		return
	var m := EclipseUI.safe_margins(_hud_root.get_viewport())
	var area := _hud_root.size
	_location_panel.reset_size()
	_location_panel.position = Vector2(m.left, m.top)
	_menu_button.position = Vector2(area.x - m.right - EclipseUI.TOUCH, m.top)
	_menu_button.size = Vector2(EclipseUI.TOUCH, EclipseUI.TOUCH)
	_menu_panel.reset_size()
	_menu_panel.position = Vector2(area.x - m.right - _menu_panel.get_combined_minimum_size().x, m.top + EclipseUI.TOUCH + 10)
	_toast.reset_size()
	var notice := _toast.get_combined_minimum_size()
	interact_button.reset_size()
	var prompt := interact_button.get_combined_minimum_size()
	if touch_ui:
		# Thumbs: stick on the left, the contextual action on the right.
		_toast.position = Vector2((area.x - notice.x) * 0.5, m.top)
		interact_button.position = Vector2(area.x - m.right - prompt.x, area.y - m.bottom - prompt.y - 12)
		var zone_size := Vector2(minf(area.x * 0.42, 400.0), minf(area.y * 0.6, 330.0))
		joystick.position = Vector2(m.left, area.y - m.bottom - zone_size.y)
		joystick.size = zone_size
		joystick.set_home(joystick.global_position + Vector2(TouchJoystick.RADIUS + 34, zone_size.y - TouchJoystick.RADIUS - 34))
	else:
		_toast.position = Vector2(m.left, area.y - m.bottom - notice.y)
		interact_button.position = Vector2((area.x - prompt.x) * 0.5, area.y - m.bottom - prompt.y - 24)

func toggle_menu() -> void:
	if dialogue != null and dialogue.active:
		return
	_menu_panel.visible = not _menu_panel.visible
	_layout_hud()
	if _menu_panel.visible:
		_restart_button.grab_focus()
	else:
		_menu_button.grab_focus()

## Session notices fade out after a few seconds; they come back when they change.
func _show_notice(text: String) -> void:
	if hint.text == text and _toast.modulate.a > 0.0:
		return
	hint.text = text
	_toast.modulate.a = 1.0
	_layout_hud.call_deferred()
	if _toast_tween != null:
		_toast_tween.kill()
	if not is_inside_tree():
		return
	_toast_tween = create_tween()
	_toast_tween.tween_interval(7.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)

func _build_narrative() -> void:
	for definition in ExpeditionStory.POINTS:
		var point := NarrativeInterest.new()
		point.configure(definition)
		interests[point.id] = point
		add_child(point)
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	dialogue = DialogueBox.new()
	overlay.add_child(dialogue)
	dialogue.conversation_closed.connect(_on_dialogue_closed)
	_fingers.roots.append(dialogue)

func _process(_delta: float) -> void:
	_nearest_interest = ""
	var nearest_distance := INF
	if session.mode == GameSession.Mode.EXPLORING and not dialogue.active and session.mission.intro_seen:
		for point in interests.values():
			if point.in_range(player.position):
				var distance: float = point.position.distance_squared_to(player.position)
				if distance < nearest_distance:
					nearest_distance = distance
					_nearest_interest = point.id
	for point in interests.values():
		point.show_prompt(point.id == _nearest_interest)
	interact_button.visible = not _nearest_interest.is_empty()
	if joystick != null:
		joystick.visible = player.movement_enabled and not dialogue.active and not _menu_panel.visible and session.mode == GameSession.Mode.EXPLORING
	if interact_button.visible:
		var prompt := "%s · %s" % ["Revisar" if interests[_nearest_interest].examined else "Examinar", interests[_nearest_interest].title]
		if interact_button.text != prompt:
			interact_button.text = prompt
			_layout_hud.call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and not dialogue.active:
		interact(_nearest_interest)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_TAB, KEY_ESCAPE] and not dialogue.active:
		if event.keycode == KEY_TAB or _menu_panel.visible:
			toggle_menu()
			get_viewport().set_input_as_handled()

func interact(id: String) -> bool:
	if dialogue.active or not session.mission.intro_seen or session.mode != GameSession.Mode.EXPLORING or not interests.has(id) or not interests[id].in_range(player.position):
		return false
	if id == "anomaly":
		if session.mission.completed:
			return _open_dialogue("anomaly_repeat", "Un camino bajo las raíces")
		if not session.mission.revelation_available(session.defeated_encounters):
			return false
		if not _open_dialogue("anomaly", "Bajo las ruinas"):
			return false
		session.mission.begin_revelation(session.defeated_encounters)
		interests[id].reveal_energy()
		return true
	return _open_dialogue(id + ("_repeat" if session.mission.investigated.has(id) else ""), interests[id].title)

func _open_dialogue(id: String, title: String, can_skip: bool = false) -> bool:
	if not dialogue.open(id, title, ExpeditionStory.lines(id), can_skip):
		return false
	player.movement_enabled = false
	player.velocity = Vector3.ZERO
	player.clear_movement_input()
	encounter_armed = false
	interact_button.visible = false
	_restart_button.disabled = true
	_restart_button.visible = false
	hint.visible = false
	_menu_panel.visible = false
	_menu_button.visible = false
	return true

func _on_dialogue_closed(id: String) -> void:
	if id == "intro":
		session.mission.intro_seen = true
	elif id == "anomaly":
		session.mission.finish_revelation()
		session.message = "La aventura continuará en el interior de las ruinas."
	else:
		session.mission.investigate(id)
	_restart_button.disabled = false
	_restart_button.visible = true
	hint.visible = true
	_menu_button.visible = true
	refresh_from_session()

func _refresh_mission_ui() -> void:
	objective_label.text = session.mission.objective(session.defeated_encounters) if session.mission.intro_seen else ""
	_objective_box.visible = not objective_label.text.is_empty()
	_layout_hud.call_deferred()
	for id in interests:
		interests[id].examined = session.mission.investigated.has(id)
	var anomaly := interests["anomaly"]
	anomaly.examined = session.mission.completed
	anomaly.set_available(session.mission.revelation_available(session.defeated_encounters) or session.mission.revelation_started)
	if session.mission.completed:
		_show_notice("La expedición perdida · Completada\nLa aventura continuará en el interior de las ruinas.")
