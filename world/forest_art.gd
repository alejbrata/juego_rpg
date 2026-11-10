class_name ForestArt
extends Node3D
## Presentation-only dressing of the Eclipse clearing (iteration 1.1).
##
## Loads the original Blender layout, merges every repeated kit mesh into one
## MultiMeshInstance3D (one draw call per mesh surface), swaps imported
## materials for mobile shaders and owns light, atmosphere and camera framing.
## Creates no physics bodies: gameplay colliders stay in forest_zone.gd.

const SCENE_PATH := "res://assets/environments/eclipse_forest/eclipse_clearing.glb"
## Loaded on build only, so the legacy fallback never pays for them.
const PAINT_PATH := "res://assets/environments/eclipse_forest/ground_paint.png"
const DETAIL_PATH := "res://assets/environments/eclipse_forest/ground_detail.png"
const FOLIAGE_SHADER := preload("res://world/shaders/forest_foliage.gdshader")
const GROUND_SHADER := preload("res://world/shaders/forest_ground.gdshader")
const SURFACE_SHADER := preload("res://world/shaders/forest_surface.gdshader")
## Small plants never cast shadows; far trees neither (beyond the shadow range).
const NO_SHADOW := ["BushA", "BushB", "BushWarm", "Grass", "GrassTall", "Fern", "FlowersWhite", "FlowersYellow", "FlowersRed", "Lupins", "Mushrooms", "RockSmall", "Pavement", "Terrain"]

## Narrative props are re-anchored at runtime on ExpeditionStory.POINTS.
const NARRATIVE_PROPS := {"PropCamp": "camp", "PropTablet": "inscription", "PropCrystalRock": "crystal"}

const CAMERA_POSITION := Vector3(0, 18.5, 14.5)
const CAMERA_TARGET := Vector3(0, 0, -0.8)
const CAMERA_FOV := 40.0

## Kits whose crowns can stand between the gameplay camera and the player.
const REVEAL_KITS := ["TreeBroadA", "TreeBroadB", "TreeBroadC", "TreeYoung", "TreeAncient", "PineA", "PineB"]

var materials: Dictionary[String, Material] = {}
## Node whose silhouette must stay readable through hero tree crowns.
var reveal_subject: Node3D
var _reveal: ShaderMaterial
## Rendering statistics of what was built; used by tests and the docs.
var stats := {"multimeshes": 0, "instances": 0, "single_meshes": 0, "triangles": 0, "surfaces": 0}

static func enabled() -> bool:
	return bool(ProjectSettings.get_setting("visuals/forest/renovated", false))

func _init() -> void:
	name = "ForestArt"

func build() -> void:
	_make_materials()
	var source: Node3D = load(SCENE_PATH).instantiate()
	var groups := {}
	var order: Array = []
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node
		var far := String(instance.name).begins_with("Far_")
		var key := "%d|%s" % [instance.mesh.get_instance_id(), far]
		if not groups.has(key):
			groups[key] = {"mesh": instance.mesh, "far": far, "transforms": []}
			order.append(key)
		groups[key].transforms.append(_relative_transform(instance, source))
	for key in order:
		var group: Dictionary = groups[key]
		var kit := String(group.mesh.resource_name).trim_prefix("eclipse_clearing_")
		var mesh: Mesh = _dress_mesh(group.mesh, not group.far and REVEAL_KITS.has(kit))
		var shadows: bool = not group.far and not NO_SHADOW.has(kit)
		var triangles: int = _triangles(mesh)
		if group.transforms.size() == 1:
			var single := MeshInstance3D.new()
			single.name = kit
			single.mesh = mesh
			single.transform = group.transforms[0]
			if NARRATIVE_PROPS.has(kit):
				# Single source of truth for the anchors: the narrative definition.
				single.position = _narrative_anchor(NARRATIVE_PROPS[kit])
			single.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(single)
			stats.single_meshes += 1
		else:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = mesh
			multimesh.instance_count = group.transforms.size()
			for i in group.transforms.size():
				multimesh.set_instance_transform(i, group.transforms[i])
			var instance := MultiMeshInstance3D.new()
			instance.name = ("Far" if group.far else "") + kit + "Set"
			instance.multimesh = multimesh
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
			stats.multimeshes += 1
		stats.instances += group.transforms.size()
		stats.triangles += triangles * group.transforms.size()
		stats.surfaces += mesh.get_surface_count()
	source.free()
	_add_motes("RuinMotes", Vector3(0, 0.9, -3.4), Vector3(2.4, 0.7, 1.8), 18, Color(1.0, 0.86, 0.5))
	_add_motes("CrystalMotes", _narrative_anchor("crystal") + Vector3(0, 0.8, 0), Vector3(0.7, 0.5, 0.7), 8, Color(0.78, 0.68, 1.0))

## Few additive motes: the only "magic" accent, no dynamic lights.
func _add_motes(label: String, at: Vector3, extents: Vector3, amount: int, color: Color) -> void:
	var motes := CPUParticles3D.new()
	motes.name = label
	motes.position = at
	motes.amount = amount
	motes.lifetime = 5.0
	motes.preprocess = 5.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = extents
	motes.direction = Vector3.UP
	motes.spread = 60.0
	motes.gravity = Vector3(0, 0.03, 0)
	motes.initial_velocity_min = 0.05
	motes.initial_velocity_max = 0.18
	var fade := Curve.new()
	fade.add_point(Vector2(0, 0))
	fade.add_point(Vector2(0.25, 1))
	fade.add_point(Vector2(0.75, 1))
	fade.add_point(Vector2(1, 0))
	motes.scale_amount_curve = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	material.albedo_texture = _mote_texture()
	quad.material = material
	motes.mesh = quad
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)

static func _mote_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 32
	texture.height = 32
	return texture

func configure_environment(environment: Environment, sun: DirectionalLight3D) -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("6f8f86")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9fb9c4")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("86a6a2")
	environment.fog_depth_begin = 25.0
	environment.fog_depth_end = 50.0
	environment.fog_depth_curve = 1.0
	environment.fog_density = 0.85
	environment.fog_sky_affect = 0.0
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_color = Color("ffe0b0")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.72
	sun.shadow_blur = 1.5
	# One orthogonal cascade: the clearing is compact and seen from a fixed camera.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 38.0

func configure_camera(camera: Camera3D) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = CAMERA_FOV
	camera.near = 0.5
	camera.far = 90.0
	camera.position = CAMERA_POSITION
	camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)

func _make_materials() -> void:
	var foliage := ShaderMaterial.new()
	foliage.shader = FOLIAGE_SHADER
	foliage.set_shader_parameter("wind_strength", 0.07)
	foliage.set_shader_parameter("wind_height", 6.0)
	foliage.set_shader_parameter("flutter", 0.18)
	var plant := ShaderMaterial.new()
	plant.shader = FOLIAGE_SHADER
	plant.set_shader_parameter("wind_strength", 0.06)
	plant.set_shader_parameter("wind_height", 0.6)
	plant.set_shader_parameter("flutter", 0.3)
	plant.set_shader_parameter("variation", 0.14)
	var ground := ShaderMaterial.new()
	ground.shader = GROUND_SHADER
	ground.set_shader_parameter("paint", load(PAINT_PATH))
	ground.set_shader_parameter("detail", load(DETAIL_PATH))
	var surface := ShaderMaterial.new()
	surface.shader = SURFACE_SHADER
	_reveal = foliage.duplicate()
	_reveal.set_shader_parameter("reveal_radius", 1.6)
	_reveal.set_shader_parameter("reveal_camera", CAMERA_POSITION)
	_reveal.set_shader_parameter("reveal_target", Vector3(0, -100, 0))
	materials = {"Foliage": foliage, "Plant": plant, "Bloom": plant, "Ground": ground, "Bark": surface, "Stone": surface}

func _dress_mesh(source: Mesh, reveal: bool) -> Mesh:
	var mesh: Mesh = source.duplicate()
	for i in mesh.get_surface_count():
		var imported := mesh.surface_get_material(i)
		var key := imported.resource_name if imported != null else ""
		var material: Material = materials.get(key, materials.Bark)
		mesh.surface_set_material(i, _reveal if reveal and key == "Foliage" else material)
	return mesh

func _process(_delta: float) -> void:
	if reveal_subject != null and is_instance_valid(reveal_subject):
		_reveal.set_shader_parameter("reveal_target", reveal_subject.global_position + Vector3.UP * 0.9)
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_reveal.set_shader_parameter("reveal_camera", camera.global_position)

static func _narrative_anchor(id: String) -> Vector3:
	for point in ExpeditionStory.POINTS:
		if point.id == id:
			return point.position
	push_error("Punto narrativo desconocido: " + id)
	return Vector3.ZERO

static func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result

static func _triangles(mesh: Mesh) -> int:
	var total := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var count: int = (indices as PackedInt32Array).size() if indices != null else 0
		total += (count if count > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total
