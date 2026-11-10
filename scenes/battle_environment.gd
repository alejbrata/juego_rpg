class_name BattleEnvironment
extends RefCounted

static func build(parent: Node3D) -> Camera3D:
	if ForestArtHD.enabled():
		return _build_hd(parent)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("344b4e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5ccbd")
	environment.ambient_light_energy = 0.55
	world.environment = environment
	parent.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -32, 0)
	sun.light_color = Color("ffe1b2")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30
	parent.add_child(sun)
	var camera := Camera3D.new()
	camera.name = "BattleCamera"
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 42
	camera.position = Vector3(8.5, 8.2, 13.7)
	parent.add_child(camera)
	camera.look_at(Vector3(-0.6, 0.35, 0))
	camera.current = true
	var ground := CylinderMesh.new()
	ground.top_radius = 8.5
	ground.bottom_radius = 9
	ground.height = 0.6
	ground.radial_segments = 15
	BattleActorVisual._mesh(parent, ground, Vector3(0, -0.34, 0), StylizedModels.mat("516351"))
	var stones: Array[Material] = [StylizedModels.mat("879080"), StylizedModels.mat("778579"), StylizedModels.mat("989780"), StylizedModels.mat("697c70")]
	for i in range(53):
		var angle := i * 2.39996
		var radius := sqrt(float(i)) * 0.98
		var stone := CylinderMesh.new()
		stone.top_radius = 0.64 + 0.18 * sin(i * 4.1)
		stone.bottom_radius = stone.top_radius * 1.08
		stone.height = 0.055
		stone.radial_segments = 5 + i % 3
		var mesh := BattleActorVisual._mesh(parent, stone, Vector3(cos(angle) * radius, -0.01 + 0.012 * sin(i * 3.7), sin(angle) * radius * 0.72), stones[i % stones.size()])
		mesh.scale = Vector3(1.15, 1, 0.8)
		mesh.rotation.y = angle
	var rock_material := StylizedModels.mat("727e73")
	for i in range(12):
		var at := Vector3(-7 + i * 1.25, 0, -4.7 - sin(i * 2.2) * 0.6)
		StylizedModels.rock(parent, at + Vector3.UP * 0.45, Vector3(1.3, 0.9, 0.9), rock_material, i)
	for i in range(15):
		var x := -11.0 + i * 1.55
		var z := -7.5 - (i % 3) * 1.2
		_tree(parent, Vector3(x, 0, z), 1.0 + 0.15 * sin(i * 2.3))
	for x in [-8.5, 8.5]:
		_tree(parent, Vector3(x, 0, -2), 1.15)
		_tree(parent, Vector3(x, 0, 2.5), 0.95)
	for item in [Vector3(-5.8, 0, -3.3), Vector3(-1.6, 0, -4.4), Vector3(3.1, 0, -4.2)]:
		_column(parent, item, 2.1 if item.x < 0 else 1.3)
	var lintel := BattleActorVisual._box(parent, Vector3(4.8, 0.5, 0.75), Vector3(-3.8, 2.25, -3.8), rock_material)
	lintel.rotation.z = -0.07
	for i in range(6):
		StylizedModels.rock(parent, Vector3(-4.3 + i * 1.2, 1.3 + 0.3 * sin(i * 2), -3.5), Vector3.ONE * 0.045, StylizedModels.mat("dac797", true))
	for i in range(25):
		var angle := i * 2.4
		var radius := 5.3 + 0.7 * sin(i * 1.8)
		var at := Vector3(cos(angle) * radius, 0.02, sin(angle) * radius * 0.7)
		var grass := StylizedModels.mat("617d51" if i % 2 == 0 else "80915c")
		for blade in range(3):
			var leaf := StylizedModels.gem(parent, at + Vector3(blade * 0.1, 0.16, 0), Vector3(0.12, 0.37, 0.07), grass)
			leaf.rotation.z = -0.4 + blade * 0.4
	StylizedModels.batch_static(parent)
	return camera

static func _tree(parent: Node3D, at: Vector3, size: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * size
	parent.add_child(root)
	StylizedModels.rod(root, Vector3.ZERO, Vector3(0.1, 3.4, 0), 0.23, StylizedModels.mat("5e5140"))
	StylizedModels.rod(root, Vector3(0, 2.1, 0), Vector3(1, 3.1, 0.1), 0.12, StylizedModels.mat("5e5140"))
	for i in range(3):
		StylizedModels.rock(root, Vector3((i - 1) * 0.85, 3.5 + (i % 2) * 0.6, 0), Vector3(2.6, 2.5, 2.4), StylizedModels.mat(["344e40", "41604a", "526c4d"][i]), i + 4)

static func _column(parent: Node3D, at: Vector3, height: float) -> void:
	var stone := StylizedModels.mat("8a917d")
	BattleActorVisual._box(parent, Vector3(1.05, 0.25, 1.05), at + Vector3.UP * 0.12, stone)
	var shape := CylinderMesh.new()
	shape.top_radius = 0.34
	shape.bottom_radius = 0.42
	shape.height = height
	shape.radial_segments = 8
	BattleActorVisual._mesh(parent, shape, at + Vector3.UP * (height * 0.5 + 0.2), stone)
	StylizedModels.rock(parent, at + Vector3.UP * (height + 0.2), Vector3(0.9, 0.25, 0.85), stone, 3)
	StylizedModels.rod(parent, at + Vector3(0.43, 0.2, 0.12), at + Vector3(0.12, height * 0.8, 0.35), 0.05, StylizedModels.mat("587653"))

## HD arena (1.3): same camera framing; decoration from the HD forest kit.
const HD_PARTY_CAMERA := Vector3(5.4, 5.0, 9.6)
const HD_PARTY_TARGET := Vector3(-1.6, -0.2, 0.0)
static func _build_hd(parent: Node3D) -> Camera3D:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	parent.add_child(world)
	var sun := DirectionalLight3D.new()
	parent.add_child(sun)
	var art := ForestArtHD.new()
	art.name = "ArenaArt"
	parent.add_child(art)
	art.build_battle()
	art.configure_environment(world.environment, sun)
	sun.rotation_degrees = Vector3(-46, -38, 0)
	world.environment.fog_depth_begin = 30.0
	world.environment.fog_depth_end = 80.0
	world.environment.volumetric_fog_density = 0.006
	var camera := Camera3D.new()
	camera.name = "BattleCamera"
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 42
	camera.far = 120.0
	camera.position = Vector3(8.5, 8.2, 13.7)
	var look := Vector3(-0.6, 0.35, 0)
	# 1.4: the detailed HD party is framed closer; other styles keep the 1.3 framing.
	if KaelModel.party_style() == "hd":
		camera.position = HD_PARTY_CAMERA
		look = HD_PARTY_TARGET
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 26.0
	attributes.dof_blur_far_transition = 12.0
	attributes.dof_blur_amount = 0.05
	camera.attributes = attributes
	parent.add_child(camera)
	camera.look_at(look)
	camera.current = true
	return camera
