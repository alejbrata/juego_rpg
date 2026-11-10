extends Node3D

signal battle_finished(result: int)

@export_range(0.01, 2.0) var animation_time_scale: float = 1.0
@export var camera_motion_enabled: bool = true
@export var skip_animations: bool = false
@export var use_imported_kael: bool = true

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
var _target_hints: Node3D
var _marker_materials := {}
# 1.7 presentation layer: effects, sounds, screen-space numbers, camera trauma.
var vfx: CombatVFX
var sfx: CombatAudio
var numbers: CombatNumbers
var _cue: Dictionary = {}
var _cue_actor: int = -1
var _settle_until: int = 0
var _trauma: float = 0.0
var _shake_clock: float = 0.0
var _shaking: bool = false
var _summon_circle: Node3D
const SHAKE_OFFSET := 0.11   # camera offset (m) at full trauma; decays in ~0.3 s

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
	vfx = CombatVFX.new(_effects, camera)
	sfx = CombatAudio.new()
	sfx.name = "CombatAudio"
	add_child(sfx)
	numbers = CombatNumbers.new()
	numbers.camera = camera
	$Overlay.add_child(numbers)
	$Overlay.move_child(numbers, 0)
	hud.sfx = sfx
	hud.engine.battle_event.connect(_on_event)
	hud.updated.connect(_on_updated)
	hud.battle_reset.connect(_reset_visuals)
	hud.target_preview.connect(_preview_target)
	if hud.has_signal("targets_offered"):
		hud.targets_offered.connect(_offer_targets)
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
	# 1.5: selected target ring coloured by side; faint rings on every valid target.
	_marker_materials = {true: StylizedModels.mat("e07a5f", true), false: StylizedModels.mat("7cc6b6", true)}
	_target_hints = Node3D.new()
	_target_hints.name = "TargetHints"
	add_child(_target_hints)

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
	_summon_circle = null
	_cue = {}
	_settle_until = 0
	if numbers != null:
		numbers.clear()
	if sfx != null:
		sfx.stop_all()
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
		visual.prefer_imported_kael = use_imported_kael
		_actors.add_child(visual)
		visual.build(fighter)
		var slot := enemy_slot if fighter.enemy else hero_slot
		var count := enemy_count if fighter.enemy else hero_count
		var positions: Array[Vector3] = [Vector3(-1.8, 0, 1.0), Vector3(-5.6, 0, -2.3), Vector3(-5.2, 0, 2.4)]
		visual.home = Vector3(2.5, 0, (slot - (count - 1) * 0.5) * 2.6 - 0.4) if fighter.enemy else positions[slot % positions.size()]
		visual.facing_yaw = -0.8 if fighter.enemy else 0.9
		visual.position = visual.home
		if not fighter.enemy and visual.nameplate != null:
			visual.nameplate.visible = false
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
		_clear(_target_hints)
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

func _process(delta: float) -> void:
	_update_shake(delta)
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
	# 1.7: let gestures that outlive their event (an attacker returning home after
	# the blow landed) finish before poses are re-synchronised.
	var remaining := (_settle_until - Time.get_ticks_msec()) / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout
		if generation != _generation:
			return
	playing = false
	_sync_state()
	hud.unlock_actions()

func _play_event(event: Dictionary) -> float:
	var kind: String = event.type
	var actor_id: int = event.get("actor_id", -1)
	var target_id: int = event.get("target_id", -1)
	for visual in visuals:
		visual.time_scale = animation_time_scale
	vfx.time_scale = animation_time_scale
	numbers.time_scale = animation_time_scale
	match kind:
		"action":
			return _play_action(event, actor_id, target_id)
		"damage", "summon_effect":
			return _play_hit(event, kind, target_id)
		"heal":
			var target := visuals[target_id]
			target.flash(Color("70ffac"))
			vfx.heal(target.home + Vector3.UP)
			sfx.play("heal")
			numbers.show_text(_number_anchor(target_id), "+%d" % event.amount, "heal")
			return 0.62
		"intercept":
			var protector_id: int = event.protector_id
			var destination := visuals[target_id].home.lerp(visuals[actor_id].home, 0.28)
			var tween := visuals[protector_id].create_tween()
			tween.tween_property(visuals[protector_id], "position", destination, 0.2 * animation_time_scale)
			var toward := (visuals[actor_id].home - destination).normalized()
			vfx.later(0.16, func() -> void: vfx.guard(destination, toward))
			sfx.play("guard")
			numbers.show_text(destination + Vector3.UP * 2.4, "¡Protección!", "status")
			return 0.24
		"summon_appear":
			_camera_pulse(38, false)
			_summon_circle = vfx.summon_circle(Vector3(0.2, 0, -0.8))
			_show_ignar()
			if _ignar is IgnarModel:
				vfx.dress_ignar(_ignar, (_ignar as IgnarModel).head_anchor, (_ignar as IgnarModel).chest_anchor)
			else:
				vfx.dress_ignar(_ignar)
			sfx.play("summon")
			_shake(0.45)
			numbers.show_text(Vector3(0.2, 1.4, -0.8), "IGNAR · Juicio de Ceniza", "summon")
			return 0.75
		"summon_disappear":
			_restore_camera(false)
			vfx.fade_out(_summon_circle, 0.35)
			_summon_circle = null
			if is_instance_valid(_ignar):
				var tween := _ignar.create_tween()
				tween.tween_property(_ignar, "scale", Vector3.ONE * 0.01, 0.25 * animation_time_scale)
				tween.tween_callback(_ignar.queue_free)
			_ignar = null
			return 0.28
	return 0.08

## Gesture of the acting fighter. Returns when the next event (impact, heal) should
## play: the moment of contact for blows, the end of the cast for spells.
func _play_action(event: Dictionary, actor_id: int, target_id: int) -> float:
	var visual := visuals[actor_id]
	var target := visuals[target_id]
	var actor_enemy: bool = hud.engine.fighters[actor_id].enemy
	_cue = CombatCues.for_action(event, actor_enemy)
	_cue_actor = actor_id
	var direction := (target.home - visual.home).normalized() if target != visual else _facing(visual)
	visual.animate(event.effect, direction)
	var clip := visual.presentation_duration(event.effect)
	if float(_cue.get("zoom", 0.0)) > 0.0:
		_camera_pulse(float(_cue.zoom))
	if not String(_cue.get("cast", "")).is_empty():
		sfx.play(_cue.cast)
	match String(event.effect):
		"physical":
			_hold(clip)
			return clip * float(_cue.get("contact", 0.5))
		"magic":
			var travel := minf(0.3, clip * 0.4)
			var release := clip - travel
			var hand := visual.hand_point(direction)
			var aim := target.home + Vector3.UP * 1.25
			if event.element == "ice":
				vfx.ice_charge(hand, visual.home, release)
				vfx.later(release, func() -> void: vfx.ice_bolt(hand, aim, travel))
			else:
				vfx.fire_charge(hand, visual.home, release)
				vfx.later(release, func() -> void: vfx.fire_bolt(hand, aim, travel))
			sfx.play_later("swing", release * animation_time_scale, _valid_now(_generation))
			return clip + 0.02
		"heal":
			vfx.heal_glow(visual.hand_point(direction), clip * 0.8)
			return clip + 0.02
		_:
			# Support without its own engine event: the effect lands on the target
			# at the apex of the gesture (Protección, Impulso, Defender).
			var apex := clip * 0.45
			var effect: String = event.effect
			var status_color: Color = CombatCues.STATUS_COLORS.get(effect, Color.WHITE)
			vfx.support_glow(visual.hand_point(direction), Color(status_color.r * 2.0, status_color.g * 2.0, status_color.b * 2.0, 0.9), apex)
			var impact_sound := String(_cue.get("impact", "guard"))
			vfx.later(apex, func() -> void:
				match effect:
					"protect":
						vfx.protect(target.home)
					"haste":
						vfx.haste(target.home)
					_:
						vfx.guard(target.home, _facing(target))
				sfx.play(impact_sound)
				numbers.show_text(_number_anchor(target_id), String(CombatCues.STATUS_TEXT.get(effect, "")), "status"))
			return maxf(clip, apex + 0.5) + 0.02

## Impact on the target: effect by cue, sound, shake, hit-stop, reaction, number.
func _play_hit(event: Dictionary, kind: String, target_id: int) -> float:
	var target := visuals[target_id]
	var fighter: BattleEngine.Fighter = hud.engine.fighters[target_id]
	var knocked_out: bool = event.hp_after == 0
	var cue: Dictionary = _cue
	var attacker: BattleActorVisual = visuals[_cue_actor] if kind == "damage" and _cue_actor >= 0 and _cue_actor < visuals.size() else null
	var direction := (target.home - attacker.home).normalized() if attacker != null and attacker != target else -_facing(target)
	var chest := target.home + Vector3.UP * (1.25 if not fighter.enemy else 1.45) - direction * 0.35
	var color := _effect_color("magic", event.element) if event.element != "physical" else Color("fff2b0")
	var heavy := String(cue.get("vfx", "")) == "slash_heavy"
	if kind == "summon_effect" and _ignar is IgnarModel and is_instance_valid(_ignar):
		var model: IgnarModel = _ignar
		model.play("Attack")
		var contact := model.duration("Attack") * model.attack_contact
		var generation := _generation
		var event_copy := event.duplicate()
		vfx.later(contact, func() -> void:
			if generation == _generation:
				_summon_hit(event_copy, target_id))
		_hold(model.duration("Attack"))
		return contact + 0.45
	if kind == "summon_effect":
		vfx.summon_impact(target.home + Vector3.UP)
		sfx.play("fire_impact")
		_shake(0.75)
	else:
		match String(cue.get("vfx", "slash")):
			"fire":
				vfx.fire_burst(chest)
			"ice":
				vfx.ice_burst(chest)
			"slam":
				vfx.slam(chest)
			_:
				vfx.slash(chest, heavy)
				vfx.hit_spark(chest, color, heavy, fighter.enemy)
		sfx.play(String(cue.get("impact", "hit")))
		_shake(float(cue.get("shake", 0.3)) * (1.25 if knocked_out else 1.0))
		var stop := float(cue.get("hit_stop", 0.0))
		if stop > 0.0:
			target.hit_stop(stop)
			if attacker != null:
				attacker.hit_stop(stop)
	target.flash(color)
	target.animate("knockout" if knocked_out else "hit", direction)
	var amount: int = event.hp_lost if kind == "summon_effect" else event.amount
	numbers.show_text(_number_anchor(target_id), str(amount), "summon" if kind == "summon_effect" else CombatCues.damage_style(String(event.element), fighter.enemy, heavy))
	if kind == "summon_effect":
		numbers.show_text(_number_anchor(target_id), "DEF ↓", "status", 0.18)
	if knocked_out:
		vfx.later(0.22, func() -> void: vfx.knockout(target.home))
		sfx.play_later("knockout", 0.18 * animation_time_scale, _valid_now(_generation))
		numbers.show_text(_number_anchor(target_id), "K.O.", "ko", 0.3)
	var reaction := target.presentation_duration("knockout" if knocked_out else "hit")
	_hold(reaction)
	return minf(reaction, 0.5) + 0.02

## Ignar HD's blow on contact: same impact, sound, reaction and numbers as before.
func _summon_hit(event: Dictionary, target_id: int) -> void:
	var target := visuals[target_id]
	vfx.summon_impact(target.home + Vector3.UP)
	sfx.play("fire_impact")
	_shake(0.75)
	target.flash(_effect_color("magic", event.element))
	var knocked_out: bool = event.hp_after == 0
	target.animate("knockout" if knocked_out else "hit", (target.home - IGNAR_SPOT).normalized())
	numbers.show_text(_number_anchor(target_id), str(event.hp_lost), "summon")
	numbers.show_text(_number_anchor(target_id), "DEF ↓", "status", 0.18)
	if knocked_out:
		vfx.later(0.22, func() -> void: vfx.knockout(target.home))
		sfx.play("knockout")
		numbers.show_text(_number_anchor(target_id), "K.O.", "ko", 0.3)

## Where numbers appear: above the head of each fighter.
func _number_anchor(target_id: int) -> Vector3:
	var fighter: BattleEngine.Fighter = hud.engine.fighters[target_id]
	return visuals[target_id].home + Vector3.UP * (2.25 if fighter.enemy else 2.05)

func _facing(visual: BattleActorVisual) -> Vector3:
	return Vector3(sin(visual.facing_yaw), 0, cos(visual.facing_yaw))

func _hold(seconds: float) -> void:
	_settle_until = maxi(_settle_until, Time.get_ticks_msec() + int(seconds * animation_time_scale * 1000.0))

func _valid_now(generation: int) -> Callable:
	return func() -> bool: return generation == _generation and is_inside_tree()

func _preview_target(target_id: int) -> void:
	if target_id >= 0 and target_id < visuals.size():
		_target_marker.position = visuals[target_id].home + Vector3.UP * 0.07
		_target_marker.material_override = _marker_materials.get(hud.engine.fighters[target_id].enemy, null)
		_target_marker.visible = true

func _offer_targets(ids: Array[int]) -> void:
	_clear(_target_hints)
	for id in ids:
		if id >= 0 and id < visuals.size():
			var hint := StylizedModels.ring(_target_hints, visuals[id].home + Vector3.UP * 0.05, 0.75, StylizedModels.mat("efe7d4", true))
			hint.transparency = 0.65

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
	_settle_until = 0
	_clear(_effects)
	_ignar = null
	_summon_circle = null
	if numbers != null:
		numbers.clear()
	if sfx != null:
		sfx.stop_all()
	_restore_camera()
	_sync_state()
	hud.unlock_actions()

func _restore_camera(immediate: bool = true) -> void:
	if _camera_tween != null:
		_camera_tween.kill()
	if _impact_tween != null:
		_impact_tween.kill()
	_trauma = 0.0
	_shaking = false
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
	_shake(0.35)

## 1.7: trauma-based shake (decays by itself, squared for a soft tail). Only when
## camera motion is enabled in the options; never moves the camera's base pose.
func _shake(amount: float) -> void:
	if camera_motion_enabled and amount > 0.0:
		_trauma = clampf(maxf(_trauma, amount), 0.0, 1.0)

func _update_shake(delta: float) -> void:
	if camera == null or (_trauma <= 0.0 and not _shaking):
		return
	if not camera_motion_enabled:
		_trauma = 0.0
	_trauma = maxf(0.0, _trauma - delta / maxf(0.32 * animation_time_scale, 0.001))
	_shake_clock += delta / maxf(animation_time_scale, 0.001)
	var power := _trauma * _trauma * SHAKE_OFFSET
	var offset := Vector3(power * sin(_shake_clock * 61.0) * cos(_shake_clock * 23.0), power * 0.7 * sin(_shake_clock * 47.0 + 1.3), 0.0)
	camera.position = _camera_home.origin + _camera_home.basis * offset
	_shaking = _trauma > 0.0
	if not _shaking:
		camera.position = _camera_home.origin

func _effect_color(effect: String, element: String) -> Color:
	if effect == "heal":
		return Color("70ffac")
	if effect in ["guard", "protect"]:
		return Color("84d5ff")
	return {"fire": Color("ff803f"), "ice": Color("83d9ff"), "neutral": Color("d1a1ff")}.get(element, Color("dfc77b"))

const IGNAR_SPOT := Vector3(0.2, 0, -0.8)
const IGNAR_YAW := 1.2   # HD model faces the enemy side, three-quarter to the camera

func _show_ignar() -> void:
	# 1.7: Ignar HD (same pipeline as the HD party) when available; it drops onto
	# the summoning circle and lands. Otherwise the procedural volcanic golem.
	if IgnarModel.available():
		var model := IgnarModel.new()
		model.name = "IgnarHD"
		_effects.add_child(model)
		if model.load_asset():
			_ignar = model
			model.set_meta("source_mesh_count", maxi(25, model.authored_sections))
			model.position = IGNAR_SPOT + Vector3.UP * 4.0
			model.rotation.y = IGNAR_YAW
			model.set_time_scale(animation_time_scale)
			model.play("Appear")
			var drop := model.create_tween()
			drop.tween_property(model, "position", IGNAR_SPOT, 0.2 * animation_time_scale).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			drop.tween_callback(func() -> void:
				_shake(0.7)
				vfx.knockout(IGNAR_SPOT)
				vfx.ground_ring(IGNAR_SPOT + Vector3.UP * 0.05, Color(2.2, 0.9, 0.3, 0.9), 3.2, 0.5))
			var light := OmniLight3D.new()
			light.light_color = Color("ff8a3a")
			light.light_energy = 2.2
			light.omni_range = 8
			light.position = Vector3(0, 2.6, 1.0)
			model.add_child(light)
			return
		model.queue_free()
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
