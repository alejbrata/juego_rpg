class_name CombatVFX
extends RefCounted
## Iteration 1.7: reusable combat effect recipes (presentation only).
##
## Every node is created under `root` (the stage's effects layer), so skipping or
## restarting a battle removes all of them at once. Delayed parts are bound to a
## holder node inside `root`, never to the stage, so they can't fire after a skip.
## Cheap on purpose: CPU particles with small counts, a few shared unlit
## materials, procedurally generated alpha textures (assets/fx/textures, made by
## tools/fx/make_fx_textures.py) and at most one short light per impact.
## `quality` scales particle counts: 1.0 on desktop, 0.6 on phones (same shapes,
## colours and timings on both).

const TEX_DIR := "res://assets/fx/textures/"
const BARRIER := preload("res://scenes/fx/barrier.gdshader")

static var _textures := {}
static var _particle_materials := {}
static var _shared := {}

var root: Node3D
var camera: Camera3D
var time_scale: float = 1.0
var quality: float = 1.0

func _init(effects_root: Node3D, view: Camera3D) -> void:
	root = effects_root
	camera = view
	quality = default_quality()

static func default_quality() -> float:
	var setting := String(ProjectSettings.get_setting("visuals/combat_fx/quality", "auto"))
	if setting == "low":
		return 0.6
	if setting == "high":
		return 1.0
	return 0.6 if OS.has_feature("mobile") else 1.0

static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := TEX_DIR + name + ".png"
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]

# ------------------------------------------------------------------ building blocks
func _ts(seconds: float) -> float:
	return maxf(0.001, seconds * time_scale)

## Runs `action` after `delay` (scaled) unless the effects layer was cleared.
func later(delay: float, action: Callable) -> void:
	if delay <= 0.0:
		action.call()
		return
	var holder := Node3D.new()
	holder.name = "Pending"
	root.add_child(holder)
	var tween := holder.create_tween()
	tween.tween_interval(_ts(delay))
	tween.tween_callback(func() -> void:
		action.call()
		holder.queue_free())

func _free_after(node: Node, seconds: float) -> void:
	node.create_tween().tween_interval(_ts(seconds)).finished.connect(node.queue_free)

static func _particle_material(tex: String, additive: bool, stretch: bool, energy: float) -> StandardMaterial3D:
	var key := "%s|%s|%s|%.2f" % [tex, additive, stretch, energy]
	if _particle_materials.has(key):
		return _particle_materials[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(energy, energy, energy, 1.0)
	mat.albedo_texture = texture(tex)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if stretch else BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	_particle_materials[key] = mat
	return mat

static func _gradient(colors: Array) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var values := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / maxf(1.0, colors.size() - 1))
		values.append(colors[i])
	gradient.offsets = offsets
	gradient.colors = values
	return gradient

static func _curve(points: Array) -> Curve:
	var curve := Curve.new()
	for p: Vector2 in points:
		curve.add_point(p)
	return curve

## One particle burst/emitter. Options (all optional): amount, lifetime, explosiveness,
## size, texture, additive, stretch, energy, colors, local, emission ("point",
## "sphere", "ring", "box"), radius, extents, direction, spread, velocity [min,max],
## gravity, damping, radial, scale [min,max], grow, duration (continuous emission).
func particles(at: Vector3, o: Dictionary, parent: Node3D = null) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = maxi(2, roundi(float(o.get("amount", 12)) * quality))
	p.lifetime = float(o.get("lifetime", 0.5))
	var duration := float(o.get("duration", 0.0))
	p.one_shot = duration <= 0.0
	p.explosiveness = float(o.get("explosiveness", 0.9 if duration <= 0.0 else 0.0))
	p.randomness = 0.5
	p.lifetime_randomness = 0.35
	p.speed_scale = 1.0 / maxf(time_scale, 0.001)
	p.local_coords = bool(o.get("local", false))
	var quad := QuadMesh.new()
	quad.size = o.get("size", Vector2(0.2, 0.2))
	quad.material = _particle_material(String(o.get("texture", "soft_dot")), bool(o.get("additive", true)), bool(o.get("stretch", false)), float(o.get("energy", 1.0)))
	p.mesh = o.get("mesh", quad)
	match String(o.get("emission", "point")):
		"sphere":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = float(o.get("radius", 0.4))
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_radius = float(o.get("radius", 0.6))
			p.emission_ring_inner_radius = float(o.get("radius", 0.6)) * 0.85
			p.emission_ring_height = 0.05
		"box":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = o.get("extents", Vector3(1, 0.1, 1))
	p.direction = o.get("direction", Vector3.UP)
	p.spread = float(o.get("spread", 45.0))
	var velocity: Array = o.get("velocity", [1.0, 2.0])
	p.initial_velocity_min = velocity[0]
	p.initial_velocity_max = velocity[1]
	p.gravity = o.get("gravity", Vector3(0, -9.8, 0))
	p.damping_min = float(o.get("damping", 0.0))
	p.damping_max = float(o.get("damping", 0.0))
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0))
	var scale_range: Array = o.get("scale", [0.7, 1.2])
	p.scale_amount_min = scale_range[0]
	p.scale_amount_max = scale_range[1]
	p.scale_amount_curve = _curve([Vector2(0, 0.35), Vector2(0.25, 1.0), Vector2(1, 0.55)]) if o.get("grow", false) else _curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	p.color_ramp = _gradient(o.get("colors", [Color.WHITE, Color(1, 1, 1, 0)]))
	p.particle_flag_align_y = bool(o.get("stretch", false))
	if not o.get("stretch", false) and o.get("spin", false):
		p.angle_min = -180
		p.angle_max = 180
	(parent if parent != null else root).add_child(p)
	p.emitting = true
	if duration > 0.0:
		var stop := p.create_tween()
		stop.tween_interval(_ts(duration))
		stop.tween_callback(func() -> void: p.emitting = false)
		stop.tween_interval(_ts(p.lifetime + 0.1))
		stop.tween_callback(p.queue_free)
	else:
		_free_after(p, p.lifetime + 0.1)
	return p

## Unlit textured quad. mode: "billboard", "ground" (flat on the floor) or "face"
## (faces the camera but keeps a free roll angle, for slashes).
func quad(at: Vector3, size: float, tex: String, color: Color, mode: String = "billboard", additive: bool = true, roll: float = 0.0) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_texture = texture(tex)
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	if mode == "billboard":
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	node.position = at
	if mode == "ground":
		node.position.y = maxf(at.y, 0.04)
		node.rotation = Vector3(-PI * 0.5, randf() * TAU, 0)
	elif mode == "face" and camera != null:
		node.look_at(camera.global_position, Vector3.UP)
		node.rotate_object_local(Vector3.FORWARD, roll)
	return node

## Scale pop + alpha fade on a quad made by quad(); frees it afterwards.
func animate_quad(node: MeshInstance3D, from_scale: float, to_scale: float, grow: float, hold: float, fade: float, delay: float = 0.0) -> void:
	var mat := node.material_override as StandardMaterial3D
	var alpha := mat.albedo_color.a
	node.scale = Vector3.ONE * from_scale
	var tween := node.create_tween()
	if delay > 0.0:
		node.visible = false
		tween.tween_interval(_ts(delay))
		tween.tween_callback(func() -> void: node.visible = true)
	tween.tween_property(node, "scale", Vector3.ONE * to_scale, _ts(grow)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tween.tween_interval(_ts(hold))
	tween.tween_method(func(a: float) -> void: mat.albedo_color.a = a, alpha, 0.0, _ts(fade))
	tween.tween_callback(node.queue_free)

func flash_light(at: Vector3, color: Color, energy: float, light_range: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	light.position = at
	root.add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, _ts(seconds)).set_ease(Tween.EASE_IN)
	tween.tween_callback(light.queue_free)

func ground_ring(at: Vector3, color: Color, radius: float, seconds: float = 0.35, tex: String = "ring") -> void:
	animate_quad(quad(at, 2.0, tex, color, "ground"), 0.2, radius, seconds * 0.6, 0.0, seconds * 0.6)

static func shared_material(key: String) -> StandardMaterial3D:
	if _shared.has(key):
		return _shared[key]
	var mat := StandardMaterial3D.new()
	match key:
		"stone":
			mat.albedo_color = Color("6d665c")
			mat.roughness = 0.95
		"ice":
			mat.albedo_color = Color(0.62, 0.88, 1.0, 0.85)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color("4fc3ff")
			mat.emission_energy_multiplier = 1.2
			mat.roughness = 0.08
			mat.metallic_specular = 1.0
			mat.rim_enabled = true
			mat.rim = 0.8
	_shared[key] = mat
	return mat

static func _spike_mesh(height: float, radius: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 5
	mesh.rings = 1
	return mesh

# ------------------------------------------------------------------ physical
## Sword sweep crossing the target (two crossing arcs when heavy).
func slash(at: Vector3, heavy: bool, color: Color = Color(2.2, 2.0, 1.6)) -> void:
	var size := 2.5 if heavy else 1.8
	var first := quad(at, size, "slash", color, "face", true, randf_range(-0.5, 0.2))
	animate_quad(first, 0.55, 1.05, 0.07, 0.03, 0.14)
	if heavy:
		var second := quad(at, size * 0.9, "slash", color, "face", true, PI + randf_range(-0.3, 0.3))
		animate_quad(second, 0.55, 1.05, 0.07, 0.03, 0.16, 0.06)

## Contact flash, sparks and (on stone) chips and dust.
func hit_spark(at: Vector3, color: Color, heavy: bool, stone: bool) -> void:
	animate_quad(quad(at, 1.7 if heavy else 1.15, "spark_star", Color(color.r * 2.6, color.g * 2.4, color.b * 2.0, 1.0)), 0.15, 1.0, 0.05, 0.02, 0.12)
	particles(at, {"amount": 22 if heavy else 14, "lifetime": 0.32, "explosiveness": 1.0, "size": Vector2(0.05, 0.42),
		"stretch": true, "energy": 2.2, "spread": 180.0, "velocity": [6.0, 11.0] if heavy else [5.0, 9.0], "damping": 6.0,
		"gravity": Vector3(0, -12, 0), "scale": [0.6, 1.1], "colors": [Color(1, 0.97, 0.85), color, Color(color, 0)]})
	if stone:
		var chip := BoxMesh.new()
		chip.size = Vector3(0.09, 0.07, 0.08)
		chip.material = shared_material("stone")
		particles(at, {"mesh": chip, "amount": 14 if heavy else 7, "lifetime": 0.7, "explosiveness": 1.0, "spread": 75.0,
			"direction": Vector3(0.4, 1, 0), "velocity": [3.0, 6.5], "gravity": Vector3(0, -16, 0), "scale": [0.6, 1.4],
			"colors": [Color.WHITE, Color.WHITE]})
		particles(at - Vector3(0, 0.6, 0), {"amount": 7 if heavy else 4, "lifetime": 0.7, "size": Vector2(0.9, 0.9), "additive": false,
			"spread": 85.0, "velocity": [0.6, 1.4], "gravity": Vector3(0, 0.4, 0), "damping": 1.5, "grow": true, "spin": true,
			"colors": [Color(0.55, 0.5, 0.42, 0.55), Color(0.5, 0.46, 0.4, 0.0)]})
	if heavy:
		ground_ring(Vector3(at.x, 0.05, at.z), Color(1.6, 1.3, 0.8, 0.8), 1.4, 0.32)

## Enemy blow landing on a hero: warmer sparks, dust ring, no stone chips.
func slam(at: Vector3) -> void:
	hit_spark(at, Color("ff9a6b"), false, false)
	ground_ring(Vector3(at.x, 0.05, at.z), Color(1.2, 0.8, 0.6, 0.6), 1.1, 0.3)

# ------------------------------------------------------------------ fire (Llama)
func fire_charge(hand: Vector3, feet: Vector3, seconds: float) -> void:
	var orb := quad(hand, 0.9, "soft_dot", Color(2.4, 0.95, 0.25, 1.0))
	orb.scale = Vector3.ONE * 0.05
	var tween := orb.create_tween()
	tween.tween_property(orb, "scale", Vector3.ONE * 0.75, _ts(seconds)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(orb.queue_free)
	particles(hand, {"duration": seconds, "amount": 18, "lifetime": 0.42, "emission": "sphere", "radius": 0.55,
		"texture": "flame", "size": Vector2(0.24, 0.32), "energy": 1.6, "spread": 30.0, "velocity": [0.2, 0.6],
		"radial": -4.0, "gravity": Vector3(0, 1.2, 0), "grow": true,
		"colors": [Color(1.0, 0.9, 0.55), Color(1.0, 0.5, 0.12), Color(0.8, 0.15, 0.05, 0.6), Color(0.3, 0.05, 0.0, 0.0)]})
	animate_quad(quad(feet, 2.0, "ring_thin", Color(2.0, 0.9, 0.3, 0.8), "ground"), 0.3, 0.75, seconds, 0.0, 0.25)

func fire_bolt(from: Vector3, to: Vector3, seconds: float) -> void:
	var bolt := Node3D.new()
	root.add_child(bolt)
	bolt.position = from
	var core := MeshInstance3D.new()
	core.mesh = QuadMesh.new()
	(core.mesh as QuadMesh).size = Vector2(0.8, 0.8)
	core.material_override = _particle_material("soft_dot", true, false, 3.0)
	core.material_override = core.material_override.duplicate()
	(core.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	(core.material_override as StandardMaterial3D).vertex_color_use_as_albedo = false
	(core.material_override as StandardMaterial3D).albedo_color = Color(2.4, 1.1, 0.3)
	bolt.add_child(core)
	var trail := particles(Vector3.ZERO, {"duration": seconds, "amount": 30, "lifetime": 0.3, "texture": "flame",
		"size": Vector2(0.42, 0.52), "energy": 1.5, "spread": 180.0, "velocity": [0.2, 0.7], "gravity": Vector3(0, 1.5, 0), "grow": true,
		"additive": false, "colors": [Color(1.0, 0.75, 0.3, 0.9), Color(1.0, 0.4, 0.06, 0.8), Color(0.6, 0.1, 0.02, 0.0)]}, bolt)
	trail.local_coords = false
	var lift := Vector3.UP * 0.9
	var tween := bolt.create_tween()
	tween.tween_method(func(t: float) -> void:
		var a := from.lerp(from + (to - from) * 0.5 + lift, t)
		var b := (from + (to - from) * 0.5 + lift).lerp(to, t)
		bolt.position = a.lerp(b, t), 0.0, 1.0, _ts(seconds)).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: core.visible = false)
	tween.tween_interval(_ts(0.35))
	tween.tween_callback(bolt.queue_free)

func fire_burst(at: Vector3, big: bool = false) -> void:
	var feet := Vector3(at.x, 0.05, at.z)
	var k := 1.4 if big else 1.0
	flash_light(at, Color("ff7a2a"), 4.0 if big else 3.0, 7.0 if big else 5.5, 0.5)
	animate_quad(quad(at, 2.2 * k, "soft_dot", Color(1.6, 0.6, 0.15, 0.9)), 0.3, 1.0, 0.05, 0.0, 0.2)
	# Flame body: opaque-ish orange/red tongues, so fire reads as fire in daylight.
	particles(at - Vector3(0, 0.55, 0), {"amount": 22 if not big else 36, "lifetime": 0.7, "explosiveness": 0.8, "emission": "sphere",
		"radius": 0.45 * k, "texture": "flame", "size": Vector2(0.85, 1.1) * k, "additive": false,
		"spread": 40.0, "velocity": [1.4, 3.2], "gravity": Vector3(0, 2.0, 0), "damping": 2.0, "grow": true,
		"colors": [Color(1.0, 0.78, 0.3, 0.95), Color(1.0, 0.45, 0.08, 0.9), Color(0.75, 0.16, 0.03, 0.7), Color(0.2, 0.06, 0.04, 0.0)]})
	# Hot core on top (additive, modest energy).
	particles(at - Vector3(0, 0.35, 0), {"amount": 14 if not big else 22, "lifetime": 0.45, "explosiveness": 0.9, "emission": "sphere",
		"radius": 0.3 * k, "texture": "flame", "size": Vector2(0.6, 0.8) * k, "energy": 1.2,
		"spread": 35.0, "velocity": [1.2, 2.6], "gravity": Vector3(0, 2.0, 0), "grow": true,
		"colors": [Color(1.0, 0.85, 0.45), Color(1.0, 0.45, 0.1, 0.8), Color(0.6, 0.12, 0.0, 0.0)]})
	particles(at, {"amount": 26 if big else 16, "lifetime": 0.9, "explosiveness": 0.95, "size": Vector2(0.04, 0.24), "stretch": true,
		"energy": 2.0, "spread": 70.0, "velocity": [3.0, 6.5], "gravity": Vector3(0, -4, 0), "damping": 1.0,
		"colors": [Color(1.0, 0.85, 0.4), Color(1.0, 0.4, 0.05), Color(0.8, 0.15, 0.0, 0.0)]})
	particles(at + Vector3(0, 0.5, 0), {"amount": 7, "lifetime": 1.1, "size": Vector2(1.0, 1.0), "additive": false, "spread": 40.0,
		"velocity": [0.5, 1.1], "gravity": Vector3(0, 0.6, 0), "grow": true, "spin": true,
		"colors": [Color(0.18, 0.13, 0.12, 0.0), Color(0.16, 0.12, 0.11, 0.45), Color(0.15, 0.12, 0.11, 0.0)]})
	animate_quad(quad(feet, 3.6 if big else 2.6, "lava_cracks", Color(2.2, 0.7, 0.15, 1.0), "ground"), 0.7, 1.0, 0.08, 0.3, 0.6)
	ground_ring(feet, Color(1.9, 0.6, 0.15, 0.9), 1.8 if big else 1.3, 0.4)

# ------------------------------------------------------------------ ice (Escarcha)
func ice_charge(hand: Vector3, feet: Vector3, seconds: float) -> void:
	particles(hand, {"duration": seconds, "amount": 20, "lifetime": 0.4, "emission": "sphere", "radius": 1.0,
		"size": Vector2(0.13, 0.13), "energy": 2.2, "velocity": [0.0, 0.1], "radial": -10.0, "gravity": Vector3.ZERO,
		"colors": [Color(0.7, 0.95, 1.0, 0.0), Color(0.85, 0.98, 1.0), Color(0.5, 0.85, 1.0, 0.0)]})
	var crystal := MeshInstance3D.new()
	crystal.mesh = _spike_mesh(0.42, 0.1)
	crystal.material_override = shared_material("ice")
	root.add_child(crystal)
	crystal.position = hand
	crystal.scale = Vector3.ONE * 0.05
	var tween := crystal.create_tween().set_parallel(true)
	tween.tween_property(crystal, "scale", Vector3.ONE, _ts(seconds))
	tween.tween_property(crystal, "rotation:y", TAU, _ts(seconds))
	tween.chain().tween_callback(crystal.queue_free)
	var sigil := quad(feet, 2.2, "frost", Color(0.9, 1.7, 2.4, 0.85), "ground")
	animate_quad(sigil, 0.3, 0.8, seconds * 0.6, seconds * 0.4, 0.25)
	sigil.create_tween().tween_property(sigil, "rotation:y", sigil.rotation.y + 1.2, _ts(seconds + 0.25))

func ice_bolt(from: Vector3, to: Vector3, seconds: float) -> void:
	var bolt := Node3D.new()
	root.add_child(bolt)
	bolt.position = from
	var spike := MeshInstance3D.new()
	spike.mesh = _spike_mesh(0.8, 0.14)
	spike.material_override = shared_material("ice")
	spike.rotation.x = -PI * 0.5   # point along -Z, which look_at aims at the target
	bolt.add_child(spike)
	bolt.look_at_from_position(from, to, Vector3.UP)
	var trail := particles(Vector3.ZERO, {"duration": seconds, "amount": 26, "lifetime": 0.35, "size": Vector2(0.16, 0.16),
		"energy": 2.0, "spread": 180.0, "velocity": [0.1, 0.4], "gravity": Vector3(0, -0.5, 0),
		"colors": [Color(0.9, 1.0, 1.0), Color(0.55, 0.85, 1.0, 0.6), Color(0.4, 0.7, 1.0, 0.0)]}, bolt)
	trail.local_coords = false
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "position", to, _ts(seconds)).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(spike, "rotation:y", TAU * 2, _ts(seconds))
	tween.tween_callback(func() -> void: spike.visible = false)
	tween.tween_interval(_ts(0.4))
	tween.tween_callback(bolt.queue_free)

func ice_burst(at: Vector3) -> void:
	var feet := Vector3(at.x, 0.0, at.z)
	flash_light(at, Color("8fdcff"), 2.5, 5.0, 0.35)
	animate_quad(quad(at, 1.6, "spark_star", Color(1.8, 2.3, 2.8, 1.0)), 0.2, 1.0, 0.05, 0.02, 0.14)
	var count := 7 if quality >= 0.9 else 5
	for i in count:
		var angle := float(i) / count * TAU + randf_range(-0.25, 0.25)
		var height := randf_range(1.0, 1.9)
		var spike := MeshInstance3D.new()
		spike.mesh = _spike_mesh(height, randf_range(0.17, 0.27))
		spike.material_override = shared_material("ice")
		root.add_child(spike)
		var offset := Vector3(cos(angle), 0, sin(angle)) * randf_range(0.45, 0.8)
		spike.position = feet + offset + Vector3(0, height * 0.5 - 0.15, 0)
		spike.rotation = Vector3(sin(angle) * 0.4, randf() * TAU, -cos(angle) * 0.4)
		spike.scale = Vector3(1, 0.02, 1)
		var tween := spike.create_tween()
		tween.tween_interval(_ts(i * 0.015))
		tween.tween_property(spike, "scale", Vector3.ONE, _ts(0.09)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(_ts(0.32))
		tween.tween_property(spike, "scale", Vector3(0.4, 0.02, 0.4), _ts(0.14)).set_ease(Tween.EASE_IN)
		tween.tween_callback(spike.queue_free)
	later(0.45, func() -> void:
		var shard := _spike_mesh(0.22, 0.06)
		shard.material = shared_material("ice")
		particles(at, {"mesh": shard, "amount": 18, "lifetime": 0.6, "explosiveness": 1.0, "spread": 90.0, "velocity": [2.5, 5.0],
			"gravity": Vector3(0, -14, 0), "scale": [0.6, 1.3], "colors": [Color.WHITE, Color.WHITE]}))
	particles(at - Vector3(0, 0.7, 0), {"amount": 8, "lifetime": 0.9, "size": Vector2(1.1, 1.1), "additive": false, "spread": 80.0,
		"velocity": [0.5, 1.2], "gravity": Vector3(0, 0.2, 0), "damping": 1.0, "grow": true, "spin": true,
		"colors": [Color(0.85, 0.95, 1.0, 0.0), Color(0.85, 0.95, 1.0, 0.45), Color(0.8, 0.92, 1.0, 0.0)]})
	animate_quad(quad(feet, 3.0, "frost", Color(1.0, 1.8, 2.4, 1.0), "ground"), 0.4, 1.0, 0.12, 0.35, 0.5)

# ------------------------------------------------------------------ support
func heal(at: Vector3) -> void:
	var feet := Vector3(at.x, 0.0, at.z)
	var column := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.85
	mesh.height = 3.2
	mesh.radial_segments = 20
	mesh.cap_top = false
	mesh.cap_bottom = false
	column.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = texture("column")
	mat.albedo_color = Color(0.9, 1.7, 1.0, 0.0)
	column.material_override = mat
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(column)
	column.position = feet + Vector3(0, 1.6, 0)
	column.scale = Vector3(0.6, 1, 0.6)
	var tween := column.create_tween()
	tween.tween_property(column, "scale", Vector3.ONE, _ts(0.18)).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(func(a: float) -> void: mat.albedo_color.a = a, 0.0, 0.85, _ts(0.15))
	tween.tween_interval(_ts(0.25))
	tween.tween_method(func(a: float) -> void: mat.albedo_color.a = a, 0.85, 0.0, _ts(0.4))
	tween.tween_callback(column.queue_free)
	particles(feet + Vector3(0, 0.1, 0), {"amount": 22, "lifetime": 0.85, "explosiveness": 0.4, "emission": "ring", "radius": 0.65,
		"size": Vector2(0.13, 0.13), "energy": 2.0, "spread": 8.0, "velocity": [1.4, 2.4], "gravity": Vector3.ZERO,
		"colors": [Color(1.0, 1.0, 0.85), Color(0.6, 1.0, 0.7), Color(0.5, 1.0, 0.65, 0.0)]})
	particles(at, {"amount": 8, "lifetime": 0.5, "explosiveness": 0.2, "emission": "sphere", "radius": 0.75, "texture": "spark_star",
		"size": Vector2(0.38, 0.38), "energy": 2.0, "velocity": [0.1, 0.3], "gravity": Vector3.ZERO, "grow": true,
		"colors": [Color(1.0, 1.0, 0.8, 0.0), Color(1.0, 0.97, 0.75), Color(0.7, 1.0, 0.7, 0.0)]})
	ground_ring(feet, Color(1.0, 1.8, 1.1, 0.9), 1.5, 0.5)

func protect(at: Vector3) -> void:
	_barrier(at + Vector3(0, 1.05, 0), Vector3.ONE, Color(0.45, 0.82, 1.0), 0.75)
	ground_ring(Vector3(at.x, 0.05, at.z), Color(0.7, 1.4, 2.2, 0.9), 1.4, 0.45, "ring_thin")
	particles(at + Vector3(0, 1.0, 0), {"amount": 8, "lifetime": 0.45, "explosiveness": 0.5, "emission": "sphere", "radius": 1.0,
		"texture": "spark_star", "size": Vector2(0.3, 0.3), "energy": 2.0, "velocity": [0.0, 0.2], "gravity": Vector3.ZERO,
		"colors": [Color(0.8, 0.95, 1.0, 0.0), Color(0.85, 0.95, 1.0), Color(0.5, 0.8, 1.0, 0.0)]})

func guard(at: Vector3, toward: Vector3) -> void:
	var front := at + Vector3(0, 1.05, 0) + toward * 0.45
	var shield := _barrier(front, Vector3(0.85, 1.0, 0.32), Color(0.65, 0.85, 1.0), 0.35)
	shield.look_at(front + toward, Vector3.UP)
	ground_ring(Vector3(at.x, 0.05, at.z), Color(0.8, 1.2, 1.8, 0.7), 1.1, 0.3, "ring_thin")

func _barrier(at: Vector3, scale: Vector3, color: Color, hold: float) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.25
	sphere.radial_segments = 24
	sphere.rings = 12
	var mat := ShaderMaterial.new()
	mat.shader = BARRIER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("intensity", 0.0)
	var node := MeshInstance3D.new()
	node.mesh = sphere
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	node.position = at
	node.scale = scale * 0.5
	var tween := node.create_tween()
	tween.tween_property(node, "scale", scale * 1.08, _ts(0.14)).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter("intensity", v), 0.0, 1.25, _ts(0.12))
	tween.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter("sweep", v), 0.0, 1.0, _ts(0.4))
	tween.tween_property(node, "scale", scale, _ts(0.1))
	tween.tween_interval(_ts(hold))
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("intensity", v), 1.25, 0.0, _ts(0.35))
	tween.tween_callback(node.queue_free)
	return node

func haste(at: Vector3) -> void:
	var feet := Vector3(at.x, 0.05, at.z)
	var spin := Node3D.new()
	root.add_child(spin)
	spin.position = feet
	var tween := spin.create_tween()
	tween.tween_property(spin, "rotation:y", TAU * 1.3, _ts(0.75))
	tween.tween_callback(spin.queue_free)
	particles(Vector3.ZERO, {"duration": 0.35, "amount": 26, "lifetime": 0.42, "local": true, "emission": "ring", "radius": 0.75,
		"size": Vector2(0.05, 0.5), "stretch": true, "energy": 2.2, "spread": 6.0, "velocity": [2.6, 3.6], "gravity": Vector3.ZERO,
		"colors": [Color(1.0, 0.95, 0.6), Color(1.0, 0.82, 0.3), Color(1.0, 0.7, 0.2, 0.0)]}, spin)
	for i in 3:
		var chevron := quad(feet + Vector3(0, 0.5 + i * 0.6, 0), 0.85, "chevron", Color(2.8, 2.3, 0.7, 1.0))
		chevron.visible = false
		var rise := chevron.create_tween()
		rise.tween_interval(_ts(0.07 * i))
		rise.tween_callback(func() -> void: chevron.visible = true)
		rise.tween_property(chevron, "position:y", chevron.position.y + 0.65, _ts(0.32)).set_ease(Tween.EASE_OUT)
		rise.parallel().tween_method(func(a: float) -> void: (chevron.material_override as StandardMaterial3D).albedo_color.a = a, 0.95, 0.0, _ts(0.32)).set_ease(Tween.EASE_IN)
		rise.tween_callback(chevron.queue_free)
	ground_ring(feet, Color(2.0, 1.7, 0.6, 0.85), 1.3, 0.3, "ring_thin")

func heal_glow(hand: Vector3, seconds: float) -> void:
	animate_quad(quad(hand, 0.8, "soft_dot", Color(1.2, 2.0, 1.2, 0.9)), 0.1, 1.0, seconds * 0.7, 0.0, seconds * 0.3)

func support_glow(hand: Vector3, color: Color, seconds: float) -> void:
	animate_quad(quad(hand, 0.7, "soft_dot", color), 0.1, 1.0, seconds * 0.7, 0.0, seconds * 0.3)

# ------------------------------------------------------------------ KO
func knockout(at: Vector3) -> void:
	var feet := Vector3(at.x, 0.05, at.z)
	particles(feet + Vector3(0, 0.1, 0), {"amount": 10, "lifetime": 0.85, "explosiveness": 0.9, "emission": "ring", "radius": 0.45,
		"size": Vector2(0.9, 0.9), "additive": false, "direction": Vector3.UP, "spread": 80.0, "velocity": [0.8, 1.6],
		"gravity": Vector3(0, 0.3, 0), "damping": 1.5, "grow": true, "spin": true,
		"colors": [Color(0.55, 0.5, 0.45, 0.0), Color(0.55, 0.5, 0.45, 0.5), Color(0.5, 0.47, 0.42, 0.0)]})
	ground_ring(feet, Color(0.6, 0.6, 0.65, 0.6), 1.3, 0.5)

# ------------------------------------------------------------------ Ignar (summon)
## Ground circle from the designer's reference: rune rings and the flame emblem
## over glowing lava cracks. Returns the node so the stage can fade it on exit.
func summon_circle(at: Vector3) -> Node3D:
	var circle := Node3D.new()
	circle.name = "SummonCircle"
	root.add_child(circle)
	circle.position = Vector3(at.x, 0.06, at.z)
	var cracks := quad(Vector3.ZERO, 8.5, "lava_cracks", Color(2.2, 0.75, 0.2, 0.0), "ground")
	cracks.reparent(circle, false)
	var runes := quad(Vector3.ZERO, 6.4, "rune_circle", Color(2.8, 1.45, 0.5, 0.0), "ground")
	runes.reparent(circle, false)
	runes.position.y = 0.02
	runes.rotation.y = 0.0
	for node: MeshInstance3D in [cracks, runes]:
		var mat := node.material_override as StandardMaterial3D
		var tween := node.create_tween()
		node.scale = Vector3.ONE * 0.25
		tween.tween_property(node, "scale", Vector3.ONE, _ts(0.35)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_method(func(a: float) -> void: mat.albedo_color.a = a, 0.0, 1.0, _ts(0.25))
	runes.create_tween().tween_property(runes, "rotation:y", 0.8, _ts(2.0))
	particles(Vector3(0, 0.1, 0), {"duration": 0.9, "amount": 30, "lifetime": 0.9, "emission": "box", "extents": Vector3(2.4, 0.05, 2.4),
		"size": Vector2(0.05, 0.28), "stretch": true, "energy": 2.2, "spread": 10.0, "velocity": [1.5, 3.5], "gravity": Vector3(0, 0.5, 0),
		"colors": [Color(1.0, 0.85, 0.45), Color(1.0, 0.45, 0.1), Color(0.7, 0.15, 0.0, 0.0)]}, circle)
	flash_light(Vector3(at.x, 1.2, at.z), Color("ff7a2e"), 4.0, 9.0, 1.2)
	return circle

func fade_out(node: Node3D, seconds: float) -> void:
	if not is_instance_valid(node):
		return
	var tween := node.create_tween().set_parallel(true)
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mat := child.material_override as StandardMaterial3D
			tween.tween_method(func(a: float) -> void: mat.albedo_color.a = a, mat.albedo_color.a, 0.0, _ts(seconds))
	tween.chain().tween_callback(node.queue_free)

## Lava core in the chest and an ember mane, after the designer's Ignar sheet.
## With the HD model, both follow its head and chest bones (anchors).
func dress_ignar(ignar: Node3D, head: Node3D = null, chest: Node3D = null) -> void:
	var core := quad(Vector3.ZERO, 1.1 if chest == null else 0.9, "soft_dot", Color(2.6, 1.2, 0.35, 1.0))
	core.reparent(chest if chest != null else ignar, false)
	core.position = Vector3(0, 1.53, 0.62) if chest == null else Vector3(0, 0.1, 0.12)
	var pulse := core.create_tween().set_loops(4)
	pulse.tween_property(core, "scale", Vector3.ONE * 1.25, _ts(0.25)).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(core, "scale", Vector3.ONE * 0.9, _ts(0.25)).set_trans(Tween.TRANS_SINE)
	var mane := {"duration": 2.4, "amount": 26, "lifetime": 0.6, "emission": "sphere", "radius": 0.6 if head == null else 0.28,
		"texture": "flame", "size": Vector2(0.5, 0.65), "energy": 1.4, "additive": false, "spread": 25.0, "velocity": [0.6, 1.4],
		"gravity": Vector3(0, 2.0, 0), "grow": true,
		"colors": [Color(1.0, 0.85, 0.4, 0.9), Color(1.0, 0.45, 0.08, 0.85), Color(0.6, 0.1, 0.02, 0.0)]}
	if head != null:
		particles(Vector3(0, 0.12, -0.05), mane, head)
	else:
		particles(Vector3(0, 2.35, -0.1), mane, ignar)

func summon_impact(at: Vector3) -> void:
	fire_burst(at, true)
	var chip := BoxMesh.new()
	chip.size = Vector3(0.14, 0.1, 0.12)
	chip.material = shared_material("stone")
	particles(at, {"mesh": chip, "amount": 16, "lifetime": 0.8, "explosiveness": 1.0, "spread": 70.0, "velocity": [4.0, 7.5],
		"gravity": Vector3(0, -16, 0), "scale": [0.6, 1.5], "colors": [Color.WHITE, Color.WHITE]})
	for i in 3:
		var pillar := MeshInstance3D.new()
		pillar.mesh = _spike_mesh(1.8, 0.32)
		pillar.material_override = StylizedModels.mat("ed9b49", true)
		root.add_child(pillar)
		pillar.position = Vector3(at.x + (i - 1) * 0.55, 0.85, at.z + 0.25)
		pillar.scale = Vector3(1, 0.05, 1)
		var tween := pillar.create_tween()
		tween.tween_property(pillar, "scale", Vector3.ONE, _ts(0.1)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(_ts(0.2))
		tween.tween_property(pillar, "scale", Vector3(0.1, 0.05, 0.1), _ts(0.25))
		tween.tween_callback(pillar.queue_free)
