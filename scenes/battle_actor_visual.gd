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

func build(fighter: BattleEngine.Fighter) -> void:
	base_color = Color("7b8796") if fighter.enemy else {"kael": Color("4c8edb"), "lyra": Color("ba78db"), "nira": Color("4fc5a0")}.get(fighter.data.id, Color("91aacc"))
	material = _material(base_color)
	body = Node3D.new()
	add_child(body)
	if fighter.enemy:
		_box(body, Vector3(1.15, 1.35, 0.8), Vector3(0, 0.9, 0), material)
		_box(body, Vector3(0.75, 0.6, 0.65), Vector3(0, 1.85, 0), material)
		for side in [-1, 1]:
			_box(body, Vector3(0.4, 1.0, 0.45), Vector3(side * 0.85, 0.85, 0), material)
			_box(body, Vector3(0.22, 0.12, 0.05), Vector3(side * 0.19, 1.88, 0.34), _material(Color("ffc56c"), true))
	else:
		var robe := CylinderMesh.new()
		robe.top_radius = 0.25
		robe.bottom_radius = 0.44 if fighter.data.id != "kael" else 0.34
		robe.height = 1.05
		robe.radial_segments = 10
		_mesh(body, robe, Vector3(0, 0.85, 0), material)
		var head := SphereMesh.new()
		head.radius = 0.25
		head.height = 0.5
		head.radial_segments = 12
		head.rings = 6
		_mesh(body, head, Vector3(0, 1.65, 0), _material(Color("e3c5a4")))
		if fighter.data.id == "kael":
			_box(body, Vector3(0.11, 1.1, 0.12), Vector3(0.57, 0.95, 0), _material(Color("d8e1e6")))
			_box(body, Vector3(0.38, 0.09, 0.15), Vector3(0.57, 0.6, 0), material)
		else:
			_box(body, Vector3(0.08, 1.6, 0.08), Vector3(0.55, 1.0, 0), _material(Color("8f7150")))
			_mesh(body, head, Vector3(0.55, 1.85, 0), material).scale = Vector3.ONE * 0.55
	var ring := CylinderMesh.new()
	ring.top_radius = 0.72
	ring.bottom_radius = 0.72
	ring.height = 0.035
	ring.radial_segments = 24
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

func sync(fighter: BattleEngine.Fighter, guardian_name: String, active: bool, protected_by: String, protects: String) -> void:
	if _motion != null:
		_motion.kill()
	if _flash != null:
		_flash.kill()
	position = home
	body.rotation = Vector3.ZERO
	body.position = Vector3.ZERO
	body.scale = Vector3.ONE
	material.albedo_color = base_color
	turn_ring.visible = active and fighter.hp > 0
	shield.visible = fighter.guarding and fighter.hp > 0
	var states: Array[String] = []
	if fighter.hp <= 0:
		states.append("INCONSCIENTE")
		body.rotation.z = PI * 0.5
		body.position.y = 0.18
		body.scale = Vector3.ONE * 0.65
		material.albedo_color = base_color.darkened(0.55)
	if fighter.guarding and fighter.hp > 0:
		states.append("DEFENDIENDO")
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

func animate(kind: String, direction: Vector3 = Vector3.RIGHT) -> void:
	if _motion != null:
		_motion.kill()
	_motion = create_tween()
	var duration := 0.18 * time_scale
	match kind:
		"physical":
			_motion.tween_property(body, "position", direction * 0.65, duration)
			_motion.tween_property(body, "position", Vector3.ZERO, duration)
		"magic", "heal", "haste":
			_motion.tween_property(body, "scale", Vector3(1.12, 1.16, 1.12), duration)
			_motion.tween_property(body, "scale", Vector3.ONE, duration)
		"guard", "protect":
			_motion.tween_property(body, "rotation:z", -0.12, duration)
			_motion.tween_property(body, "rotation:z", 0.0, duration)
		"hit":
			_motion.tween_property(body, "position", Vector3(0.15, 0, 0), duration * 0.5)
			_motion.tween_property(body, "position", Vector3.ZERO, duration * 0.5)
		"knockout":
			_motion.tween_property(body, "rotation:z", PI * 0.5, duration * 2)
			_motion.parallel().tween_property(body, "scale", Vector3.ONE * 0.65, duration * 2)

func flash(color: Color) -> void:
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
