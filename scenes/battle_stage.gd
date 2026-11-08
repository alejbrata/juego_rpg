extends Node3D

signal battle_finished(result: int)

@export_range(0.01, 2.0) var animation_time_scale: float = 1.0
@export var camera_motion_enabled: bool = true
@export var skip_animations: bool = false

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
var camera: Camera3D
var _camera_home: Transform3D
var _camera_tween: Tween
var _impact_tween: Tween
var _target_marker: MeshInstance3D

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
	hud.target_preview.connect(_preview_target)
	hud.camera_toggled.connect(set_camera_motion_enabled)
	hud.skip_toggled.connect(set_skip_animations)
	hud.camera_option.set_pressed_no_signal(camera_motion_enabled)
	hud.skip_option.set_pressed_no_signal(skip_animations)
	_reset_visuals()

func _build_arena() -> void:
	camera = BattleEnvironment.build(self)
	_camera_home = camera.transform
	_actors = Node3D.new()
	add_child(_actors)
	_effects = Node3D.new()
	add_child(_effects)
	_links = Node3D.new()
	add_child(_links)
	_target_marker = StylizedModels.ring(self, Vector3.ZERO, 0.95, StylizedModels.mat("90c5c1", true))
	_target_marker.visible = false

func _reset_visuals() -> void:
	_generation += 1
	_restore_camera()
	_target_marker.visible = false
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
		var positions: Array[Vector3] = [Vector3(-1.8, 0, 1.0), Vector3(-5.6, 0, -2.3), Vector3(-5.2, 0, 2.4)]
		visual.home = Vector3(2.5, 0, (slot - (count - 1) * 0.5) * 2.6 - 0.4) if fighter.enemy else positions[slot % positions.size()]
		visual.facing_yaw = -0.8 if fighter.enemy else 0.9
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
		hud.presentation_actor_id = actor_id
		hud.presentation_actor = hud.engine.fighters[actor_id].data.label if actor_id >= 0 else "Ignar"
	event_queue.append(event.duplicate(true))
	hud.set_presentation_busy(true)

func _on_updated() -> void:
	if hud.selected == null:
		_target_marker.visible = false
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
	if skip_animations:
		skip_presentation()
		return
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
			if event.effect == "physical" and event.label != "Ataque":
				_camera_pulse(39.5)
			var visual := visuals[actor_id]
			var direction := (visuals[target_id].home - visual.home).normalized()
			visual.animate(event.effect, direction)
			if event.effect != "physical":
				_burst(visual.home + Vector3.UP, _effect_color(event.effect, event.element), 0.6)
			if event.effect == "magic":
				_projectile(visual.home + Vector3.UP * 1.4, visuals[target_id].home + Vector3.UP * 1.3, event.element)
			return 0.38
		"damage", "summon_effect":
			_camera_impact()
			var color := _effect_color("magic", event.element) if event.element != "physical" else Color("fff2b0")
			visuals[target_id].flash(color)
			visuals[target_id].animate("knockout" if event.hp_after == 0 else "hit")
			_burst(visuals[target_id].home + Vector3.UP, color, 0.75 if kind == "summon_effect" else 0.4)
			if event.element == "ice":
				_ice_shards(visuals[target_id].home)
			elif kind == "summon_effect":
				_ember_pillars(visuals[target_id].home)
			_floating(visuals[target_id].home, "-%d%s" % [event.hp_lost if kind == "summon_effect" else event.amount, "  DEF ↓" if kind == "summon_effect" else ""], color)
			return 0.38
		"heal":
			visuals[target_id].flash(Color("70ffac"))
			_burst(visuals[target_id].home + Vector3.UP, Color("70ffac"), 0.7)
			_heal_motes(visuals[target_id].home)
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
			_camera_pulse(38, false)
			_show_ignar()
			_floating(Vector3(0, 1.8, -0.8), "IGNAR · Juicio de Ceniza", Color("ffbf68"), 0.9)
			return 0.65
		"summon_disappear":
			_restore_camera(false)
			if is_instance_valid(_ignar):
				var tween := _ignar.create_tween()
				tween.tween_property(_ignar, "scale", Vector3.ONE * 0.01, 0.25 * animation_time_scale)
				tween.tween_callback(_ignar.queue_free)
			_ignar = null
			return 0.28
	return 0.08

func _preview_target(target_id: int) -> void:
	if target_id >= 0 and target_id < visuals.size():
		_target_marker.position = visuals[target_id].home + Vector3.UP * 0.07
		_target_marker.visible = true

func set_camera_motion_enabled(value: bool) -> void:
	camera_motion_enabled = value
	hud.camera_option.set_pressed_no_signal(value)
	if not value:
		_restore_camera()

func set_skip_animations(value: bool) -> void:
	skip_animations = value
	hud.skip_option.set_pressed_no_signal(value)
	if value:
		skip_presentation()

func skip_presentation() -> void:
	_generation += 1
	while not event_queue.is_empty():
		played_events.append(event_queue.pop_front())
	playing = false
	_clear(_effects)
	_ignar = null
	_restore_camera()
	_sync_state()
	hud.unlock_actions()

func _restore_camera(immediate: bool = true) -> void:
	if _camera_tween != null:
		_camera_tween.kill()
	if _impact_tween != null:
		_impact_tween.kill()
	if camera == null:
		return
	camera.transform = _camera_home
	camera.h_offset = 0
	camera.v_offset = 0
	if immediate:
		camera.fov = 42
	else:
		_camera_tween = create_tween()
		_camera_tween.tween_property(camera, "fov", 42.0, 0.25 * animation_time_scale)

func _camera_pulse(fov: float, return_home: bool = true) -> void:
	if not camera_motion_enabled:
		return
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_property(camera, "fov", fov, 0.15 * animation_time_scale)
	if return_home:
		_camera_tween.tween_property(camera, "fov", 42.0, 0.2 * animation_time_scale)

func _camera_impact() -> void:
	if camera_motion_enabled:
		if _impact_tween != null:
			_impact_tween.kill()
		camera.h_offset = 0.035
		_impact_tween = camera.create_tween()
		_impact_tween.tween_property(camera, "h_offset", 0.0, 0.12 * animation_time_scale)

func _projectile(from: Vector3, to: Vector3, element: String) -> void:
	var root := Node3D.new()
	root.position = from
	_effects.add_child(root)
	if element == "ice":
		StylizedModels.gem(root, Vector3.ZERO, Vector3(0.25, 0.7, 0.25), StylizedModels.mat("b4e3e8", true)).rotation.z = PI * 0.5
	else:
		StylizedModels.rock(root, Vector3.ZERO, Vector3(0.5, 0.5, 0.5), StylizedModels.mat("ef9a50", true))
		StylizedModels.rock(root, Vector3(-0.25, 0, 0), Vector3(0.35, 0.3, 0.3), StylizedModels.mat("cc623d", true))
	var tween := root.create_tween()
	tween.tween_property(root, "position", to, 0.34 * animation_time_scale)
	tween.tween_callback(root.queue_free)

func _ice_shards(at: Vector3) -> void:
	for i in range(5):
		var angle := i * TAU / 5
		var shard := StylizedModels.gem(_effects, at + Vector3(cos(angle) * 0.6, 0.3, sin(angle) * 0.6), Vector3(0.22, 0.9, 0.25), StylizedModels.mat("b5dde0", true))
		shard.rotation.z = 0.3 * cos(angle)
		var tween := shard.create_tween()
		tween.tween_property(shard, "position:y", 0.8, 0.18 * animation_time_scale)
		tween.tween_property(shard, "scale", Vector3.ONE * 0.01, 0.22 * animation_time_scale)
		tween.tween_callback(shard.queue_free)

func _heal_motes(at: Vector3) -> void:
	for i in range(6):
		var angle := i * TAU / 6
		var mote := StylizedModels.rock(_effects, at + Vector3(cos(angle) * 0.6, 0.2, sin(angle) * 0.6), Vector3.ONE * 0.12, StylizedModels.mat("c8dc9a", true))
		var tween := mote.create_tween()
		tween.tween_property(mote, "position:y", 2.0, 0.36 * animation_time_scale)
		tween.tween_callback(mote.queue_free)

func _ember_pillars(at: Vector3) -> void:
	for i in range(3):
		var rock := StylizedModels.gem(_effects, at + Vector3((i - 1) * 0.45, 0.2, 0.2), Vector3(0.35, 1.5, 0.35), StylizedModels.mat("ed9b49", true))
		var tween := rock.create_tween()
		tween.tween_property(rock, "scale", Vector3(0.1, 0.05, 0.1), 0.35 * animation_time_scale)
		tween.tween_callback(rock.queue_free)

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

func _floating(at: Vector3, text: String, color: Color, duration: float = 0.5) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at + Vector3.UP * 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.pixel_size = 0.008
	label.outline_size = 5
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.07, 0.06, 1)
	label.no_depth_test = true
	_effects.add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.7, duration * animation_time_scale)
	tween.tween_property(label, "modulate:a", 0.0, duration * animation_time_scale)
	tween.tween_property(label, "outline_modulate:a", 0.0, duration * animation_time_scale)
	tween.chain().tween_callback(label.queue_free)

func _show_ignar() -> void:
	_ignar = Node3D.new()
	_ignar.position = Vector3(0.2, -0.2, -0.8)
	_effects.add_child(_ignar)
	StylizedModels.golem(_ignar, StylizedModels.mat("413a3b"), true)
	_ignar.rotation.y = -0.45
	var halo := StylizedModels.ring(_ignar, Vector3(0, 0.02, 0), 1.5, StylizedModels.mat("d99a49", true))
	halo.scale = Vector3(1, 0.5, 1)
	var light := OmniLight3D.new()
	light.light_color = Color("ed8b45")
	light.light_energy = 1.8
	light.omni_range = 7
	_ignar.add_child(light)
	_ignar.scale = Vector3.ONE * 0.05
	_ignar.create_tween().tween_property(_ignar, "scale", Vector3.ONE * 1.55, 0.4 * animation_time_scale)
