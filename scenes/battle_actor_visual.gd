class_name BattleActorVisual
extends Node3D

# Presentation only: receives resolved state and event amounts from BattleEngine.
var body: Node3D
var caption: Label3D
var turn_ring: MeshInstance3D
var shield: MeshInstance3D
var material: StandardMaterial3D
var base_color: Color
var home: Vector3
var time_scale: float = 1.0
var _motion: Tween
var _flash: Tween
var model_pivot: Node3D
var weapon: Node3D
var cape: Node3D
var nameplate: Label3D
var visual_id: String
var facing_yaw: float = 0.0
var _gesture: Tween
var _alive: bool = true
var _idle_clock: float = 0.0
var _defending: bool = false
@export var prefer_imported_kael: bool = true
@export_file("*.glb") var kael_asset_path: String = KaelModel.ASSET_PATH
@export var prefer_imported_companions: bool = true
@export_file("*.glb") var companion_asset_path: String = ""
var imported_model: KaelModel
var report_asset_warnings: bool = true
var kael_load_error: String = ""
var companion_load_error: String = ""

func build(fighter: BattleEngine.Fighter) -> void:
	base_color = Color("6e7b73") if fighter.enemy else {"kael": Color("344b6c"), "lyra": Color("75608e"), "nira": Color("69896a")}.get(fighter.data.id, Color("7c8d96"))
	material = _material(base_color)
	body = Node3D.new()
	body.name = "Pose"
	add_child(body)
	model_pivot = Node3D.new()
	model_pivot.name = "Model"
	body.add_child(model_pivot)
	visual_id = fighter.data.id if not fighter.enemy else "sentinel"
	if fighter.enemy:
		StylizedModels.golem(model_pivot, material)
	elif fighter.data.id == "kael" and prefer_imported_kael and ProjectSettings.get_setting("visuals/kael/use_imported", true) and _build_imported_kael():
		pass
	elif fighter.data.id in ["lyra", "nira"] and prefer_imported_companions and ProjectSettings.get_setting("visuals/%s/use_imported" % fighter.data.id, false) and _build_imported_companion(fighter.data.id):
		pass
	else:
		var parts := StylizedModels.hero(model_pivot, fighter.data.id, material)
		weapon = parts.weapon
		cape = parts.cape
	var ring := TorusMesh.new()
	ring.inner_radius = 0.64
	ring.outer_radius = 0.7
	ring.rings = 24
	ring.ring_segments = 6
	turn_ring = _mesh(self, ring, Vector3(0, 0.05, 0), _material(Color("ead48c"), true))
	var bubble := SphereMesh.new()
	bubble.radius = 0.75
	bubble.height = 1.9
	bubble.radial_segments = 16
	bubble.rings = 8
	var shield_material := _material(Color(0.2, 0.7, 1.0, 0.18), true)
	shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield = _mesh(self, bubble, Vector3(0, 1, 0), shield_material)
	shield.visible = false
	caption = Label3D.new()
	caption.position.y = 3.2 if fighter.enemy else 2.9
	caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.font_size = 32
	caption.pixel_size = 0.007
	caption.outline_size = 10
	caption.modulate = Color("f4f4e8")
	caption.no_depth_test = true
	add_child(caption)
	# Full information remains available for diagnostics/tests, but no longer
	# overlaps the 3D models. Party statistics are displayed in HUD cards.
	caption.visible = false
	nameplate = Label3D.new()
	nameplate.position.y = 3.05 if fighter.enemy else 2.55
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# 1.5: interface typography; compact enemy plate with a dark outline for contrast.
	nameplate.font = EclipseUI.font("bold")
	nameplate.font_size = 30
	nameplate.pixel_size = 0.0085
	nameplate.outline_size = 10
	nameplate.outline_modulate = Color(0.03, 0.06, 0.08, 0.85)
	add_child(nameplate)

func _build_imported_kael() -> bool:
	var candidate := KaelModel.new()
	model_pivot.add_child(candidate)
	var selected_path := kael_asset_path
	if selected_path == KaelModel.ASSET_PATH and ProjectSettings.get_setting("visuals/kael/asset_version", "0.9") == "0.8":
		selected_path = "res://assets/characters/kael/v08/kael.glb"
	elif selected_path == KaelModel.ASSET_PATH and ProjectSettings.get_setting("visuals/kael/asset_version", "0.9") == "reference-study":
		selected_path = "res://assets/characters/kael/reference_study/kael.glb"
	elif selected_path == KaelModel.ASSET_PATH and ProjectSettings.get_setting("visuals/kael/asset_version", "0.9") == "polished":
		selected_path = "res://assets/characters/kael/polished/kael.glb"
	elif selected_path == KaelModel.ASSET_PATH and ProjectSettings.get_setting("visuals/kael/asset_version", "0.9") == "retro":
		selected_path = "res://assets/characters/kael/retro/kael.glb"
	# The party style overrides only the default path; explicit paths still win.
	if kael_asset_path == KaelModel.ASSET_PATH:
		selected_path = KaelModel.styled_path("kael", selected_path)
	if not candidate.load_asset(selected_path, report_asset_warnings):
		kael_load_error = candidate.load_error
		model_pivot.remove_child(candidate)
		candidate.free()
		return false
	imported_model = candidate
	weapon = imported_model.weapon
	model_pivot.set_meta("source_mesh_count", imported_model.authored_sections)
	return true

func _build_imported_companion(hero_id: String) -> bool:
	var candidate := CompanionModel.new()
	candidate.hero_id = hero_id
	model_pivot.add_child(candidate)
	if not candidate.load_asset(companion_asset_path, report_asset_warnings):
		companion_load_error = candidate.load_error
		model_pivot.remove_child(candidate)
		candidate.free()
		return false
	imported_model = candidate
	weapon = imported_model.weapon
	model_pivot.set_meta("source_mesh_count", imported_model.authored_sections)
	return true

func _process(delta: float) -> void:
	if imported_model != null or not _alive or body == null or (_motion != null and _motion.is_running()):
		return
	_idle_clock += delta
	body.position.y = sin(_idle_clock * 2.1 + home.z) * 0.018
	if cape != null:
		cape.rotation.x = sin(_idle_clock * 1.7) * 0.035

func sync(fighter: BattleEngine.Fighter, guardian_name: String, active: bool, protected_by: String, protects: String) -> void:
	if _motion != null:
		_motion.kill()
	if _flash != null:
		_flash.kill()
	if _gesture != null:
		_gesture.kill()
	if imported_model != null and imported_model.animation_player != null:
		imported_model.animation_player.speed_scale = 1.0
	if weapon != null and imported_model == null:
		weapon.rotation = Vector3.ZERO
	position = home
	body.rotation = Vector3.ZERO
	body.position = Vector3.ZERO
	body.scale = Vector3.ONE
	material.albedo_color = base_color
	model_pivot.rotation.y = facing_yaw
	_alive = fighter.hp > 0
	_defending = fighter.guarding
	turn_ring.visible = active and fighter.hp > 0
	shield.visible = fighter.guarding and fighter.hp > 0
	var states: Array[String] = []
	if fighter.hp <= 0:
		states.append("INCONSCIENTE")
		if imported_model == null:
			body.rotation.z = PI * 0.5
			body.position.y = 0.18
			body.scale = Vector3.ONE * 0.65
		material.albedo_color = base_color.darkened(0.55)
	if fighter.guarding and fighter.hp > 0:
		states.append("DEFENDIENDO")
		body.rotation.x = -0.08 if imported_model == null else 0.0
		if weapon != null and imported_model == null:
			weapon.rotation.z = -0.45
	if not guardian_name.is_empty():
		states.append("Vínculo: " + guardian_name)
	if protected_by == fighter.data.label and protects == fighter.data.label:
		states.append("Protección propia")
	elif not protected_by.is_empty():
		states.append("Protegido por " + protected_by)
	if not protects.is_empty() and protects != fighter.data.label:
		states.append("Protege a " + protects)
	if fighter.defense_down_rounds > 0:
		states.append("DEF reducida")
	if fighter.haste_rounds > 0:
		states.append("Impulso")
	caption.text = "%s%s\nPV %d/%d · PM %d/%d" % ["▶ " if active else "", fighter.data.label, fighter.hp, fighter.data.max_hp, fighter.mp, fighter.data.max_mp]
	if not states.is_empty():
		caption.text += "\n" + " · ".join(states)
	caption.modulate = Color("ffe3a0") if active else Color("f4f4e8")
	nameplate.text = ("▶ " if active else "") + fighter.data.label
	if fighter.enemy:
		nameplate.text += "\nPV %d/%d%s" % [fighter.hp, fighter.data.max_hp, " · DEF ↓" if fighter.defense_down_rounds > 0 else ""]
	if fighter.hp <= 0:
		nameplate.text += " · KO"
	nameplate.modulate = caption.modulate
	if imported_model != null:
		imported_model.reset_pose("KO" if fighter.hp <= 0 else ("Defend" if fighter.guarding else "Idle"))

func presentation_duration(kind: String) -> float:
	if imported_model == null:
		return 0.36
	var clip := imported_model.clip_for_effect(kind)
	return imported_model.presentation_duration(clip)

func animate(kind: String, direction: Vector3 = Vector3.RIGHT) -> void:
	if _motion != null:
		_motion.kill()
	var duration := 0.18 * time_scale
	if imported_model != null:
		var clip := imported_model.clip_for_effect(kind)
		var clip_duration := presentation_duration(kind) * time_scale
		imported_model.play_action(clip, clip_duration)
		if kind == "physical":
			# 1.7: brief wind-up before the lunge (scaled by the model's own lunge, so
			# planted-feet models such as Lyra/Nira still do not slide).
			var lunge := imported_model.lunge_distance
			_motion = create_tween()
			_motion.tween_property(body, "position", -direction * lunge * 0.25, clip_duration * 0.18)
			_motion.tween_property(body, "position", direction * lunge, clip_duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_motion.tween_property(body, "position", Vector3.ZERO, clip_duration * 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		elif kind == "hit":
			_recoil(direction, clip_duration)
		return
	_motion = create_tween()
	if weapon != null and kind in ["physical", "magic", "heal", "haste"]:
		if _gesture != null:
			_gesture.kill()
		_gesture = create_tween()
		_gesture.tween_property(weapon, "rotation:x", -1.1 if kind == "physical" else -0.55, duration)
		_gesture.tween_property(weapon, "rotation:x", 0.0, duration)
	match kind:
		"physical":
			# Wind-up, fast lunge (contact at half the action), eased return: 0.36 s.
			_motion.tween_property(body, "position", -direction * 0.18, duration * 0.4)
			_motion.tween_property(body, "position", direction * 0.7, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_motion.tween_property(body, "position", Vector3.ZERO, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		"magic", "heal", "haste":
			_motion.tween_property(body, "scale", Vector3(1.12, 1.16, 1.12), duration)
			_motion.tween_property(body, "scale", Vector3.ONE, duration)
		"guard", "protect":
			_motion.tween_property(body, "rotation:z", -0.12, duration)
			_motion.tween_property(body, "rotation:z", 0.0, duration)
		"hit":
			_motion.kill()
			_recoil(direction, duration * 2.0)
		"knockout":
			_motion.tween_property(body, "rotation:z", PI * 0.5, duration * 2)
			_motion.parallel().tween_property(body, "scale", Vector3.ONE * 0.65, duration * 2)

## 1.7: pushed away from the blow, a short shudder, then back home.
func _recoil(direction: Vector3, seconds: float) -> void:
	var away := Vector3(direction.x, 0, direction.z).normalized() if direction.length() > 0.01 else Vector3.RIGHT
	var side := away.cross(Vector3.UP).normalized()
	_motion = create_tween()
	_motion.tween_property(body, "position", away * 0.24, seconds * 0.16).set_ease(Tween.EASE_OUT)
	_motion.tween_property(body, "position", away * 0.16 + side * 0.05, seconds * 0.08)
	_motion.tween_property(body, "position", away * 0.18 - side * 0.05, seconds * 0.08)
	_motion.tween_property(body, "position", Vector3.ZERO, seconds * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 1.7: freezes the current animation/motion for an instant on contact.
func hit_stop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var player: AnimationPlayer = imported_model.animation_player if imported_model != null else null
	if player != null:
		player.speed_scale = 0.05
	if _motion != null and _motion.is_valid():
		_motion.set_speed_scale(0.05)
	var resume := create_tween()
	resume.tween_interval(seconds * time_scale)
	resume.tween_callback(func() -> void:
		if player != null and is_instance_valid(player):
			player.speed_scale = 1.0
		if _motion != null and _motion.is_valid():
			_motion.set_speed_scale(1.0))

## 1.7: where spells leave from: the weapon/focus if it exists, else chest height.
func hand_point(direction: Vector3 = Vector3.ZERO) -> Vector3:
	if weapon != null and is_instance_valid(weapon) and weapon.is_inside_tree():
		var at := weapon.global_position
		if at.y > global_position.y + 0.4:
			return at + direction * 0.15
	return global_position + Vector3.UP * 1.3 + direction * 0.35

func flash(color: Color) -> void:
	if imported_model != null:
		imported_model.flash(color, 0.28 * time_scale)
		return
	if _flash != null:
		_flash.kill()
	material.albedo_color = color
	_flash = create_tween()
	_flash.tween_property(material, "albedo_color", base_color, 0.28 * time_scale)

static func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

static func _mesh(parent: Node3D, shape: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = shape
	result.material_override = mat
	result.position = at
	parent.add_child(result)
	return result

static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, shape, at, mat)
