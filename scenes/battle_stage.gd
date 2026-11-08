extends Node3D

signal battle_finished(result: int)

@export_range(0.01, 2.0) var animation_time_scale: float = 1.0

@onready var hud = $Overlay/HUD
var visuals: Array[BattleActorVisual] = []
var event_queue: Array[Dictionary] = []
var played_events: Array[Dictionary] = []
var playing: bool = false
var _generation: int = 0
var _actors: Node3D
var _effects: Node3D
var _links: Node3D
var _ignar: Node3D
var _announced_result: bool = false

func configure_encounter(heroes: Array[CombatantData], enemies: Array[CombatantData], run: PartyState) -> void:
	# Configure the existing controller before entering the tree. Standalone scenes
	# retain their original defaults and test-party buttons.
	var controller = get_node("Overlay/HUD")
	controller.encounter_heroes = heroes
	controller.encounter_enemies = enemies
	controller.run = run
	controller.encounter_mode = true

func _ready() -> void:
	_build_arena()
	hud.engine.battle_event.connect(_on_event)
	hud.updated.connect(_on_updated)
	hud.battle_reset.connect(_reset_visuals)
	_reset_visuals()

func _build_arena() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("202e40")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b4c9df")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -28, 0)
	light.light_color = Color("ffdfad")
	light.light_energy = 1.1
	light.shadow_enabled = false
	add_child(light)
	var camera := Camera3D.new()
	camera.name = "BattleCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.5
	camera.position = Vector3(0, 10, 16)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var stone := BattleActorVisual._material(Color("697a76"))
	BattleActorVisual._box(self, Vector3(12.8, 0.3, 8.5), Vector3(0, -0.2, 0), stone)
	var tile := BattleActorVisual._material(Color("82908a"))
	for x in range(-5, 6, 2):
		for z in range(-3, 4, 2):
			BattleActorVisual._box(self, Vector3(1.8, 0.04, 1.8), Vector3(x, -0.025, z), tile)
	for x in [-5.6, 5.6]:
		for z in [-3.5, 3.5]:
			BattleActorVisual._box(self, Vector3(0.8, 0.3, 0.8), Vector3(x, 0.15, z), stone)
			BattleActorVisual._box(self, Vector3(0.5, 1.4 if z < 0 else 0.7, 0.5), Vector3(x, 0.7 if z < 0 else 0.35, z), stone)
	_actors = Node3D.new()
	add_child(_actors)
	_effects = Node3D.new()
	add_child(_effects)
	_links = Node3D.new()
	add_child(_links)

func _reset_visuals() -> void:
	_generation += 1
	_announced_result = false
	playing = false
	event_queue.clear()
	played_events.clear()
	_clear(_actors)
	_clear(_effects)
	_clear(_links)
	_ignar = null
	visuals.clear()
	var enemy_count := 0
	var hero_count := 0
	for f in hud.engine.fighters:
		if f.enemy:
			enemy_count += 1
		else:
			hero_count += 1
	var hero_slot := 0
	var enemy_slot := 0
	for fighter in hud.engine.fighters:
		var visual := BattleActorVisual.new()
		_actors.add_child(visual)
		visual.build(fighter)
		var slot := enemy_slot if fighter.enemy else hero_slot
		var count := enemy_count if fighter.enemy else hero_count
		var x := 3.1 if fighter.enemy else (-2.6 if slot % 2 == 1 else -3.9)
		visual.home = Vector3(x, 0, (slot - (count - 1) * 0.5) * 1.6)
		visual.position = visual.home
		visuals.append(visual)
		if fighter.enemy:
			enemy_slot += 1
		else:
			hero_slot += 1
	hud.presentation_busy = false
	_sync_state()
	hud.unlock_actions()

func _clear(parent: Node3D) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _on_event(event: Dictionary) -> void:
	if not playing and event_queue.is_empty():
		var actor_id: int = event.get("actor_id", -1)
		hud.presentation_actor = hud.engine.fighters[actor_id].data.label if actor_id >= 0 else "Ignar"
	event_queue.append(event.duplicate(true))
	hud.set_presentation_busy(true)

func _on_updated() -> void:
	if playing or not event_queue.is_empty():
		hud.set_presentation_busy(true)
	else:
		_sync_state()
		_announce_result()

func _announce_result() -> void:
	if not _announced_result and hud.engine.phase in [BattleEngine.Phase.VICTORY, BattleEngine.Phase.DEFEAT]:
		_announced_result = true
		battle_finished.emit(hud.engine.phase)

func _sync_state() -> void:
	if visuals.size() != hud.engine.fighters.size():
		return
	_clear(_links)
	for i in range(visuals.size()):
		var fighter: BattleEngine.Fighter = hud.engine.fighters[i]
		var guardian := hud.run.guardian_for(fighter.data.id) as GuardianData if not fighter.enemy else null
		var protected_by := ""
		for protector in hud.engine.fighters:
			if protector.protection_target == i and protector.hp > 0:
				protected_by = protector.data.label
		var protects := ""
		if fighter.protection_target >= 0 and fighter.hp > 0:
			protects = hud.engine.fighters[fighter.protection_target].data.label
			_link(visuals[i].home, visuals[fighter.protection_target].home)
		var active: bool = hud.engine.phase in [BattleEngine.Phase.WAITING_PLAYER, BattleEngine.Phase.ENEMY_TURN] and hud.engine.current_id() == i
		visuals[i].sync(fighter, "Ignar" if guardian != null and guardian.id == "ignar" else (guardian.label if guardian != null else ""), active, protected_by, protects)

func _link(from: Vector3, to: Vector3) -> void:
	if from.is_equal_approx(to):
		return
	var line := CylinderMesh.new()
	line.top_radius = 0.025
	line.bottom_radius = 0.025
	line.height = from.distance_to(to)
	line.radial_segments = 6
	var mesh := BattleActorVisual._mesh(_links, line, (from + to) * 0.5 + Vector3.UP * 0.8, BattleActorVisual._material(Color("84d5ff"), true))
	mesh.quaternion = Quaternion(Vector3.UP, (to - from).normalized())

func _process(_delta: float) -> void:
	if not playing and not event_queue.is_empty():
		_drain_events()

func _drain_events() -> void:
	playing = true
	var generation := _generation
	while not event_queue.is_empty():
		var event: Dictionary = event_queue.pop_front()
		played_events.append(event.duplicate(true))
		var duration := _play_event(event)
		await get_tree().create_timer(maxf(0.001, duration * animation_time_scale)).timeout
		if generation != _generation:
			return # Restart canceled the old visual sequence, never the engine.
	playing = false
	_sync_state()
	hud.unlock_actions()

func _play_event(event: Dictionary) -> float:
	var kind: String = event.type
	var actor_id: int = event.get("actor_id", -1)
	var target_id: int = event.get("target_id", -1)
	for visual in visuals:
		visual.time_scale = animation_time_scale
	match kind:
		"action":
			var visual := visuals[actor_id]
			var direction := (visuals[target_id].home - visual.home).normalized()
			visual.animate(event.effect, direction)
			if event.effect != "physical":
				_burst(visual.home + Vector3.UP, _effect_color(event.effect, event.element), 0.6)
			return 0.38
		"damage", "summon_effect":
			var color := _effect_color("magic", event.element) if event.element != "physical" else Color("fff2b0")
			visuals[target_id].flash(color)
			visuals[target_id].animate("knockout" if event.hp_after == 0 else "hit")
			_burst(visuals[target_id].home + Vector3.UP, color, 0.75 if kind == "summon_effect" else 0.4)
			_floating(visuals[target_id].home, "-%d%s" % [event.hp_lost if kind == "summon_effect" else event.amount, "  DEF ↓" if kind == "summon_effect" else ""], color)
			return 0.38
		"heal":
			visuals[target_id].flash(Color("70ffac"))
			_burst(visuals[target_id].home + Vector3.UP, Color("70ffac"), 0.7)
			_floating(visuals[target_id].home, "+%d PV" % event.amount, Color("70ffac"))
			return 0.38
		"intercept":
			var protector_id: int = event.protector_id
			var destination := visuals[target_id].home.lerp(visuals[actor_id].home, 0.28)
			var tween := visuals[protector_id].create_tween()
			tween.tween_property(visuals[protector_id], "position", destination, 0.2 * animation_time_scale)
			_floating(destination, "¡Protección!", Color("84d5ff"))
			return 0.24
		"summon_appear":
			_show_ignar()
			_floating(Vector3(0, 0, 0), "IGNAR · Juicio de Ceniza", Color("ffbf68"))
			return 0.65
		"summon_disappear":
			if is_instance_valid(_ignar):
				var tween := _ignar.create_tween()
				tween.tween_property(_ignar, "scale", Vector3.ONE * 0.01, 0.25 * animation_time_scale)
				tween.tween_callback(_ignar.queue_free)
			_ignar = null
			return 0.28
	return 0.08

func _effect_color(effect: String, element: String) -> Color:
	if effect == "heal":
		return Color("70ffac")
	if effect in ["guard", "protect"]:
		return Color("84d5ff")
	return {"fire": Color("ff803f"), "ice": Color("83d9ff"), "neutral": Color("d1a1ff")}.get(element, Color("dfc77b"))

func _burst(at: Vector3, color: Color, radius: float) -> void:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 12
	shape.rings = 6
	var mat := BattleActorVisual._material(Color(color, 0.6), true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var burst := BattleActorVisual._mesh(_effects, shape, at, mat)
	burst.scale = Vector3.ONE * 0.2
	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * 1.3, 0.35 * animation_time_scale)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35 * animation_time_scale)
	tween.chain().tween_callback(burst.queue_free)

func _floating(at: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at + Vector3.UP * 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.pixel_size = 0.008
	label.outline_size = 5
	label.modulate = color
	label.no_depth_test = true
	_effects.add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.7, 0.5 * animation_time_scale)
	tween.tween_property(label, "modulate:a", 0.0, 0.5 * animation_time_scale)
	tween.chain().tween_callback(label.queue_free)

func _show_ignar() -> void:
	_ignar = Node3D.new()
	_ignar.position = Vector3(0, 0.6, 0)
	_effects.add_child(_ignar)
	var ember := BattleActorVisual._material(Color("d85829"))
	var core := BattleActorVisual._material(Color("ffba54"), true)
	BattleActorVisual._box(_ignar, Vector3(1.15, 1.3, 0.8), Vector3(0, 0.9, 0), ember)
	BattleActorVisual._box(_ignar, Vector3(0.8, 0.55, 1.0), Vector3(0, 1.65, 0.15), ember)
	BattleActorVisual._box(_ignar, Vector3(0.45, 0.75, 0.83), Vector3(0, 1, 0.05), core)
	for side in [-1, 1]:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.22
		horn.height = 0.8
		horn.radial_segments = 6
		BattleActorVisual._mesh(_ignar, horn, Vector3(side * 0.4, 2.1, 0), core).rotation.z = -side * 0.3
		BattleActorVisual._box(_ignar, Vector3(0.45, 0.8, 0.5), Vector3(side * 0.85, 0.8, 0), ember)
	var light := OmniLight3D.new()
	light.light_color = Color("ff853d")
	light.light_energy = 1.6
	light.omni_range = 5
	_ignar.add_child(light)
	_ignar.scale = Vector3.ONE * 0.05
	_ignar.create_tween().tween_property(_ignar, "scale", Vector3.ONE * 1.3, 0.4 * animation_time_scale)
