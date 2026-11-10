class_name ForestArtHD
extends ForestArt
## HD presentation of the Eclipse clearing (iteration 1.3, Forward+).
##
## Keeps the 1.1 composition (same transforms, anchors and colliders) but swaps
## each procedural kit for a Poly Haven CC0 scan prepared by
## tools/blender/prepare_forest_hd.py, re-surfaces the original ruins and props
## with triplanar PBR stone/wood, paints the ground with four PBR layers and adds
## instanced grass, an HDRI sky, volumetric light and modern post-processing.
## Creates no physics bodies.

const HD_DIR := "res://assets/environments/eclipse_forest_hd/"
const GROUND_HD_SHADER := preload("res://world/shaders/forest_hd_ground.gdshader")
const STONE_HD_SHADER := preload("res://world/shaders/forest_hd_stone.gdshader")
const FOLIAGE_HD_SHADER := preload("res://world/shaders/forest_hd_foliage.gdshader")
const GRASS_SHADER := preload("res://world/shaders/forest_hd_grass.gdshader")
const SKY_PATH := HD_DIR + "sky/forest_grove_2k.hdr"
const MASK_RECT := Rect2(-32, -34, 64, 55)

## Old kit -> candidates. "height" (or "width") is the world size before the
## instance's own scale from the 1.1 layout. Variants alternate per instance.
const SWAPS := {
	"TreeBroadA": [{"asset": "island_tree_02", "height": 6.4}, {"asset": "tree_small_02", "height": 6.0}],
	"TreeBroadB": [{"asset": "tree_small_02", "height": 5.6}],
	"TreeBroadC": [{"asset": "island_tree_02", "height": 7.0}],
	"TreeYoung": [{"asset": "tree_small_02", "height": 5.2}],
	"TreeAncient": [{"asset": "jacaranda_tree", "height": 8.2}],
	"PineA": [{"asset": "island_tree_02", "height": 8.6}],
	"PineB": [{"asset": "tree_small_02", "height": 7.4}],
	"PineFar": [{"asset": "island_tree_02", "height": 9.5}, {"asset": "tree_small_02", "height": 8.5}, {"asset": "jacaranda_tree", "height": 8.0}],
	"TreeFarBroad": [{"asset": "island_tree_02", "height": 7.5}],
	"TreeFarBroadB": [{"asset": "tree_small_02", "height": 6.5}],
	"BushA": [{"asset": "shrub_03", "height": 1.0}, {"asset": "shrub_02", "height": 1.1}],
	"BushB": [{"asset": "shrub_03", "height": 0.8}, {"asset": "shrub_02", "height": 0.9}],
	"BushWarm": [{"asset": "shrub_03", "height": 0.95}],
	"Fern": [{"asset": "fern_02", "height": 0.55}],
	"FlowersWhite": [{"asset": "periwinkle_plant", "height": 0.25}],
	"FlowersYellow": [{"asset": "dandelion_01", "height": 0.3}],
	"FlowersRed": [{"asset": "periwinkle_plant", "height": 0.25}],
	"Lupins": [{"asset": "nettle_plant", "height": 0.6}],
	"Mushrooms": [{"asset": "dry_branches_medium_01", "width": 0.8}],
	"RockA": [{"asset": "boulder_01", "width": 1.7}],
	"RockB": [{"asset": "rock_moss_set_01", "width": 1.6}],
	"RockSmall": [{"asset": "stone_01", "width": 0.7}, {"asset": "rock_07", "width": 0.6}, {"asset": "rock_09", "width": 0.6}],
	"Log": [{"asset": "dead_tree_trunk", "width": 2.6}],
}
## Kits dropped in HD: replaced by instanced grass.
const DROP := ["Grass", "GrassTall"]
## Hero trees on the gameplay colliders: their foliage dithers around the player.
const HD_REVEAL := ["TreeBroadA", "TreeBroadB", "TreeBroadC", "TreeYoung", "TreeAncient", "PineA", "PineB"]
const SHADOW_KITS := ["TreeBroadA", "TreeBroadB", "TreeBroadC", "TreeYoung", "TreeAncient", "PineA", "PineB", "PineFar", "TreeFarBroad",
	"TreeFarBroadB", "RockA", "RockB", "Log", "ColumnTall", "ColumnShort", "ColumnStub", "Wall", "WallLow", "Arch", "Steps", "PropCamp",
	"PropTablet", "PropCrystalRock", "BushA", "BushB", "BushWarm"]
## Extra CC0 dressing placed around trunks / ruins (Godot X, Z, yaw, size).
const EXTRAS := [
	["root_cluster_01", Vector2(-7.0, -4.5), 0.4, 1.8], ["root_cluster_01", Vector2(3.4, -5.2), 2.2, 1.6],
	["root_cluster_01", Vector2(-7.4, 0.0), 4.1, 1.7], ["pine_roots", Vector2(7.2, 0.0), 1.0, 2.0],
	["tree_stump_01", Vector2(-5.9, -5.9), 0.7, 0.9], ["tree_stump_01", Vector2(6.1, 5.6), 2.4, 0.8],
	["dry_branches_medium_01", Vector2(-6.2, 3.4), 1.1, 1.2], ["dry_branches_medium_01", Vector2(5.4, -1.0), 3.0, 1.0],
	["rock_moss_set_02", Vector2(-8.6, -5.6), 0.3, 2.2], ["rock_moss_set_02", Vector2(8.7, 5.7), 2.0, 2.0],
	["stone_fire_pit", Vector2(-3.55, 2.7), 0.0, 0.9],
]

var _kit_cache := {}
## Full tree mesh -> thinned "far" mesh (tools/blender/thin_trees_hd.py).
var _far_of := {}
var _grass_material: ShaderMaterial
var _textures := {}

static func enabled() -> bool:
	return ForestArt.enabled() and bool(ProjectSettings.get_setting("visuals/forest/hd", false))

func build() -> void:
	_make_materials()
	var source: Node3D = load(SCENE_PATH).instantiate()
	var groups := {}
	var order: Array = []
	var counter := {}
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node
		var kit := String(instance.mesh.resource_name).trim_prefix("eclipse_clearing_")
		var far := String(instance.name).begins_with("Far_")
		if DROP.has(kit):
			continue
		var at := _relative_transform(instance, source)
		if NARRATIVE_PROPS.has(kit):
			at.origin = _narrative_anchor(NARRATIVE_PROPS[kit])
		var mesh: Mesh
		var label := kit
		if SWAPS.has(kit):
			var options: Array = SWAPS[kit]
			var n: int = counter.get(kit, 0)
			counter[kit] = n + 1
			var swap: Dictionary = options[n % options.size()]
			var variants := _hd_variants(swap.asset, kit in HD_REVEAL and not far)
			if variants.is_empty():
				continue
			mesh = variants[_pick(at.origin, variants.size())]
			label = swap.asset
			at = _fit(at, mesh, swap)
		else:
			mesh = _dress_hd(instance.mesh, kit)
		var key := "%s|%s|%d" % [label, far, mesh.get_instance_id()]
		if not groups.has(key):
			groups[key] = {"mesh": mesh, "kit": kit, "label": label, "far": far, "transforms": []}
			order.append(key)
		groups[key].transforms.append(at)
	source.free()
	for extra in EXTRAS:
		var variants := _hd_variants(extra[0], false)
		if variants.is_empty():
			continue
		var mesh: Mesh = variants[_pick(Vector3(extra[1].x, 0, extra[1].y), variants.size())]
		var at := Transform3D(Basis(Vector3.UP, extra[2]), Vector3(extra[1].x, 0, extra[1].y))
		at = _fit(at, mesh, {"width": extra[3]})
		var key := "%s|extra|%d" % [extra[0], mesh.get_instance_id()]
		if not groups.has(key):
			groups[key] = {"mesh": mesh, "kit": "Extra", "label": extra[0], "far": false, "transforms": []}
			order.append(key)
		groups[key].transforms.append(at)
	for key in order:
		var group: Dictionary = groups[key]
		_emit(group)
	_add_grass()
	_add_motes("RuinMotes", Vector3(0, 0.9, -3.4), Vector3(2.4, 0.7, 1.8), 24, Color(1.0, 0.86, 0.5))
	_add_motes("CrystalMotes", _narrative_anchor("crystal") + Vector3(0, 0.8, 0), Vector3(0.7, 0.5, 0.7), 10, Color(0.78, 0.68, 1.0))
	_add_crystal_light()

## Trees are separate instances so per-instance mesh LOD applies; small repeated
## props are merged into MultiMeshes.
func _emit(group: Dictionary) -> void:
	var mesh: Mesh = group.mesh
	var kit: String = group.kit
	var distant_tree := (bool(group.far) or kit.contains("Far")) and (kit.begins_with("Tree") or kit.begins_with("Pine"))
	var shadows: bool = (SHADOW_KITS.has(kit) and not distant_tree) or (kit == "Extra" and group.label != "dry_branches_medium_01")
	var shadow_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var transforms: Array = group.transforms
	var triangles := _triangles(mesh)
	var tree := kit.begins_with("Tree") or kit.begins_with("Pine")
	var far_mesh: Mesh = _far_of.get(mesh)
	var distant := bool(group.far) or kit.contains("Far")
	if far_mesh != null and distant:
		mesh = far_mesh
		triangles = _triangles(mesh)
	if transforms.size() == 1 or tree:
		for t in transforms:
			var single := MeshInstance3D.new()
			single.name = kit if kit != "Extra" else group.label.to_pascal_case()
			single.mesh = mesh
			single.transform = t
			single.cast_shadow = shadow_mode
			add_child(single, true)
			stats.single_meshes += 1
			if far_mesh != null and not distant and shadows:
				# Shadow maps render every caster up to four times (cascades):
				# the thinned tree casts, the full one only draws.
				single.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var caster := MeshInstance3D.new()
				caster.name = single.name + "Shadow"
				caster.mesh = far_mesh
				caster.transform = t
				caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				add_child(caster, true)
				stats["shadow_proxies"] = int(stats.get("shadow_proxies", 0)) + 1
	else:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = transforms.size()
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = ("Far" if group.far else "") + (kit if kit != "Extra" else group.label.to_pascal_case()) + "Set"
		instance.multimesh = multimesh
		instance.cast_shadow = shadow_mode
		add_child(instance, true)
		stats.multimeshes += 1
	stats.instances += transforms.size()
	stats.triangles += triangles * transforms.size()
	stats.surfaces += mesh.get_surface_count()

## Keeps position + yaw + the layout's uniform scale, then sizes the scan.
func _fit(at: Transform3D, mesh: Mesh, swap: Dictionary) -> Transform3D:
	var layout_scale := at.basis.get_scale().x
	var aabb := mesh.get_aabb()
	var k := 1.0
	if swap.has("height"):
		k = float(swap.height) / maxf(aabb.size.y, 0.01)
	else:
		k = float(swap.width) / maxf(maxf(aabb.size.x, aabb.size.z), 0.01)
	var yaw := at.basis.get_euler().y
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * layout_scale * k), at.origin)

## Stable per-position variant choice (no visible repetition pattern).
static func _pick(at: Vector3, count: int) -> int:
	return int(absf(sin(at.x * 12.9898 + at.z * 78.233) * 43758.5453)) % count

## Every MeshInstance3D of a prepared GLB is one variant (origin at its base).
func _hd_variants(asset: String, reveal: bool) -> Array:
	var key := asset + ("|reveal" if reveal else "")
	if _kit_cache.has(key):
		return _kit_cache[key]
	var result := []
	var path := HD_DIR + "models/" + asset + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("Falta el recurso HD " + path)
		_kit_cache[key] = result
		return result
	var scene: Node = load(path).instantiate()
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
		for i in mesh.get_surface_count():
			var imported := mesh.surface_get_material(i) as StandardMaterial3D
			if imported != null:
				_mip_material(imported)
			if imported != null and imported.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				mesh.surface_set_material(i, _foliage_from(imported, asset, reveal))
		result.append(mesh)
	scene.free()
	_attach_far(asset, result)
	_kit_cache[key] = result
	return result

## Thinned versions share the full model's materials (matched by surface name)
## and keep their alpha-tested leaf cards intact: automatic LOD would collapse
## them, so the far GLBs are imported without LODs.
func _attach_far(asset: String, near: Array) -> void:
	var path := HD_DIR + "models/" + asset + "_far.glb"
	if not ResourceLoader.exists(path):
		return
	var scene: Node = load(path).instantiate()
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	for i in mini(meshes.size(), near.size()):
		var far: Mesh = (meshes[i] as MeshInstance3D).mesh.duplicate()
		var source: Mesh = near[i]
		var by_name := {}
		for s in source.get_surface_count():
			by_name[source.surface_get_name(s)] = source.surface_get_material(s)
		for s in far.get_surface_count():
			far.surface_set_material(s, by_name.get(far.surface_get_name(s), source.surface_get_material(mini(s, source.get_surface_count() - 1))))
		_far_of[source] = far
	scene.free()

func _foliage_from(imported: StandardMaterial3D, asset: String, reveal: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FOLIAGE_HD_SHADER
	material.set_shader_parameter("albedo_tex", imported.albedo_texture)
	material.set_shader_parameter("albedo_color", imported.albedo_color)
	material.set_shader_parameter("normal_tex", imported.normal_texture)
	material.set_shader_parameter("has_normal", imported.normal_texture != null)
	material.set_shader_parameter("orm_tex", imported.roughness_texture)
	material.set_shader_parameter("has_orm", imported.roughness_texture != null)
	material.set_shader_parameter("alpha_cut", clampf(imported.alpha_scissor_threshold, 0.3, 0.6))
	var big := asset.contains("tree") or asset.contains("jacaranda")
	material.set_shader_parameter("wind_strength", 0.06 if big else 0.04)
	material.set_shader_parameter("wind_height", 8.0 if big else 0.8)
	material.set_shader_parameter("flutter", 0.15 if big else 0.3)
	if reveal:
		material.set_shader_parameter("reveal_radius", 2.2)
		_reveal_materials.append(material)
	return material

var _reveal_materials: Array[ShaderMaterial] = []

func _tex(set_name: String, map: String) -> Texture2D:
	var path := "%stextures/%s/%s_%s_2k.jpg" % [HD_DIR, set_name, set_name, map]
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]

func _make_materials() -> void:
	var ground := ShaderMaterial.new()
	ground.shader = GROUND_HD_SHADER
	ground.set_shader_parameter("mask", load(HD_DIR + "ground_mask.png"))
	ground.set_shader_parameter("mask_rect", Vector4(MASK_RECT.position.x, MASK_RECT.position.y, MASK_RECT.size.x, MASK_RECT.size.y))
	for layer in [["floor", "forest_leaves_02"], ["meadow", "leafy_grass"], ["trail", "rocky_trail"], ["plaza", "mossy_cobblestone"]]:
		ground.set_shader_parameter(layer[0] + "_albedo", _tex(layer[1], "diff"))
		ground.set_shader_parameter(layer[0] + "_normal", _tex(layer[1], "nor_gl"))
		ground.set_shader_parameter(layer[0] + "_orm", _tex(layer[1], "arm"))
	var stone := ShaderMaterial.new()
	stone.shader = STONE_HD_SHADER
	stone.set_shader_parameter("detail_albedo", _tex("medieval_blocks_05", "diff"))
	stone.set_shader_parameter("detail_normal", _tex("medieval_blocks_05", "nor_gl"))
	stone.set_shader_parameter("detail_orm", _tex("medieval_blocks_05", "arm"))
	stone.set_shader_parameter("moss_albedo", _tex("mossy_rock", "diff"))
	stone.set_shader_parameter("moss_normal", _tex("mossy_rock", "nor_gl"))
	var wood := stone.duplicate()
	wood.set_shader_parameter("detail_albedo", _tex("medieval_wood", "diff"))
	wood.set_shader_parameter("detail_normal", _tex("medieval_wood", "nor_gl"))
	wood.set_shader_parameter("detail_orm", _tex("medieval_wood", "arm"))
	wood.set_shader_parameter("moss_amount", 0.2)
	wood.set_shader_parameter("scale", 0.9)
	var plant := stone.duplicate()
	plant.set_shader_parameter("tint_strength", 1.0)
	plant.set_shader_parameter("moss_amount", 0.0)
	materials = {"Ground": ground, "Stone": stone, "Bark": wood, "Foliage": plant, "Plant": plant, "Bloom": plant}
	_grass_material = ShaderMaterial.new()
	_grass_material.shader = GRASS_SHADER

func _dress_hd(source: Mesh, kit: String) -> Mesh:
	var mesh: Mesh = source.duplicate()
	for i in mesh.get_surface_count():
		var imported := mesh.surface_get_material(i)
		var key := imported.resource_name if imported != null else ""
		var material: Material = materials.get(key, materials.Stone)
		if kit == "Terrain":
			material = materials.Ground
		mesh.surface_set_material(i, material)
	return mesh

func _process(_delta: float) -> void:
	if reveal_subject == null or not is_instance_valid(reveal_subject):
		return
	var target := reveal_subject.global_position + Vector3.UP * 0.9
	var camera := get_viewport().get_camera_3d()
	for material in _reveal_materials:
		material.set_shader_parameter("reveal_target", target)
		if camera != null:
			material.set_shader_parameter("reveal_camera", camera.global_position)
	_grass_material.set_shader_parameter("push_position", reveal_subject.global_position)

# --------------------------------------------------------------------- grass
func _add_grass() -> void:
	var mask: Image = (load(HD_DIR + "ground_mask.png") as Texture2D).get_image()
	if mask.is_compressed():
		mask.decompress()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	var transforms: Array[Transform3D] = []
	var tries := 0
	while transforms.size() < 7000 and tries < 60000:
		tries += 1
		var x := rng.randf_range(-11.5, 11.5)
		var z := rng.randf_range(-9.5, 9.0)
		var m := _mask_at(mask, x, z)
		var density := m.g * 0.8 + 0.12 * (1.0 - m.r) * (1.0 - m.b) - m.r * 1.5 - m.b * 1.5
		if absf(x) > 8.6 or absf(z) > 6.6:
			density = 0.5 - m.r  # banks: lush
		if rng.randf() > density:
			continue
		var s := rng.randf_range(0.7, 1.25) * (1.15 if absf(x) > 8.6 or absf(z) > 6.6 else 1.0)
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(x, _ground_y(x, z), z)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _grass_clump()
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = "GrassHD"
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	stats.multimeshes += 1
	stats.instances += transforms.size()
	stats.triangles += _triangles(multimesh.mesh) * transforms.size()

## Gameplay area is flat (y = 0); the banks rise but grass there is sparse.
func _ground_y(x: float, z: float) -> float:
	return 0.0 if absf(x) < 8.45 and absf(z) < 6.45 else 0.02

static func _mask_at(mask: Image, x: float, z: float) -> Color:
	var u := clampi(int((x - MASK_RECT.position.x) / MASK_RECT.size.x * mask.get_width()), 0, mask.get_width() - 1)
	var v := clampi(int((z - MASK_RECT.position.y) / MASK_RECT.size.y * mask.get_height()), 0, mask.get_height() - 1)
	return mask.get_pixel(u, v)

func _grass_clump() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for b in 16:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.17)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var facing := rng.randf() * TAU
		var side := Vector3(cos(facing), 0, sin(facing)) * rng.randf_range(0.009, 0.015)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.18)
		var height := rng.randf_range(0.16, 0.36)
		var rows: Array[Vector3] = []
		for s in 4:
			var t := s / 3.0
			rows.append(base + lean * t * t + Vector3.UP * height * t)
		var normal := side.cross(Vector3.UP).normalized()
		for s in 3:
			var w0 := 1.0 - s / 3.0
			var w1 := 1.0 - (s + 1) / 3.0
			var p0 := rows[s] - side * w0
			var p1 := rows[s] + side * w0
			var p2 := rows[s + 1] + side * w1
			var p3 := rows[s + 1] - side * w1
			for p in [p0, p1, p2, p0, p2, p3]:
				st.set_normal((normal + Vector3.UP * 0.6).normalized())
				st.add_vertex(p)
	var mesh := st.commit()
	mesh.surface_set_material(0, _grass_material)
	return mesh

func _add_crystal_light() -> void:
	var light := OmniLight3D.new()
	light.name = "CrystalGlow"
	light.position = _narrative_anchor("crystal") + Vector3(0, 0.9, 0)
	light.light_color = Color(0.72, 0.6, 1.0)
	light.light_energy = 1.2
	light.omni_range = 3.2
	light.shadow_enabled = false
	add_child(light)

# --------------------------------------------------------------- environment
func configure_environment(environment: Environment, sun: DirectionalLight3D) -> void:
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load(SKY_PATH)
	sky_material.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.05
	environment.ssao_enabled = true
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 2.2
	environment.ssao_power = 1.6
	# SSIL and four shadow cascades cost ~10 ms on the integrated GPU measured
	# (docs/FOREST_HD.md); the frame keeps SSAO, two cascades and the HDRI ambient.
	environment.ssil_enabled = false
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.1
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("8fa9a0")
	environment.fog_depth_begin = 24.0
	environment.fog_depth_end = 60.0
	environment.fog_density = 0.6
	environment.fog_sky_affect = 0.0
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.012
	environment.volumetric_fog_albedo = Color("e6eadc")
	environment.volumetric_fog_anisotropy = 0.6
	environment.volumetric_fog_length = 48.0
	environment.volumetric_fog_ambient_inject = 0.15
	environment.volumetric_fog_sky_affect = 0.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	environment.adjustment_contrast = 1.04
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_color = Color("ffe2b8")
	sun.light_energy = 2.4
	sun.light_volumetric_fog_energy = 1.6
	sun.light_angular_distance = 1.2
	sun.shadow_enabled = true
	sun.shadow_opacity = 1.0
	sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 32.0
	sun.directional_shadow_blend_splits = true

func configure_camera(camera: Camera3D) -> void:
	super.configure_camera(camera)
	camera.far = 120.0
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 34.0
	attributes.dof_blur_far_transition = 14.0
	attributes.dof_blur_amount = 0.06
	camera.attributes = attributes

## Faceted crystal cluster for the anomaly (presentation of the existing gem; same
## anchor and reveal behaviour in NarrativeInterest). Glassy, emissive, no new symbols.
static func crystal_cluster(parent: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.5, 0.95, 0.78)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.metallic = 0.0
	material.roughness = 0.08
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.emission_enabled = true
	material.emission = Color(0.55, 0.38, 1.0)
	material.emission_energy_multiplier = 1.6
	material.rim_enabled = true
	material.rim = 0.6
	material.rim_tint = 0.3
	var shards := [[Vector3(0, -0.15, 0), Vector3(0.0, 0.0, 0.0), 1.0], [Vector3(0.16, -0.38, 0.05), Vector3(0.0, 0.0, -0.45), 0.6],
		[Vector3(-0.15, -0.4, -0.06), Vector3(0.25, 0.0, 0.5), 0.55], [Vector3(0.02, -0.42, 0.17), Vector3(-0.55, 0.0, 0.1), 0.45],
		[Vector3(-0.05, -0.45, -0.17), Vector3(0.5, 0.3, -0.1), 0.38]]
	for shard in shards:
		var k: float = shard[2]
		var pivot := Node3D.new()
		pivot.position = shard[0]
		pivot.rotation = shard[1]
		parent.add_child(pivot)
		for part in [[0.11 * k, 0.11 * k, 0.7 * k, 0.35 * k], [0.11 * k, 0.0, 0.26 * k, 0.83 * k]]:
			var prism := CylinderMesh.new()
			prism.radial_segments = 6
			prism.rings = 1
			prism.bottom_radius = part[0]
			prism.top_radius = part[1]
			prism.height = part[2]
			prism.material = material
			var piece := MeshInstance3D.new()
			piece.mesh = prism
			piece.position = Vector3.UP * part[3]
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(piece)

static var _rock_cache: Array = []
static var _mip_cache := {}

## GLB-embedded images (embedded_image_handling=3) import without mipmaps:
## minified 1k-2k textures then thrash the GPU cache and shimmer. Each texture
## gets a mipmapped, VRAM-compressed copy once per session.
static func _with_mips(texture: Texture2D, normal := false) -> Texture2D:
	if texture == null:
		return null
	if _mip_cache.has(texture):
		return _mip_cache[texture]
	var image := texture.get_image()
	var result := texture
	if image != null and not image.has_mipmaps():
		image = image.duplicate()
		if image.is_compressed():
			image.decompress()
		image.generate_mipmaps()
		if RenderingServer.get_rendering_device() != null:
			image.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_NORMAL if normal else Image.COMPRESS_SOURCE_GENERIC)
		result = ImageTexture.create_from_image(image)
	_mip_cache[texture] = result
	_mip_cache[result] = result
	return result

static func _mip_material(material: StandardMaterial3D) -> void:
	material.albedo_texture = _with_mips(material.albedo_texture)
	material.normal_texture = _with_mips(material.normal_texture, true)
	material.roughness_texture = _with_mips(material.roughness_texture)
	material.metallic_texture = _with_mips(material.metallic_texture)
	material.ao_texture = _with_mips(material.ao_texture)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

## Opaque scanned rock variants (golems, battle arena). Empty if not imported.
static func rock_variants() -> Array:
	if not _rock_cache.is_empty():
		return _rock_cache
	for asset: String in ["rock_moss_set_02", "rock_moss_set_01"]:
		var path: String = HD_DIR + "models/" + asset + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var scene: Node = load(path).instantiate()
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				if mesh.surface_get_material(i) is StandardMaterial3D:
					_mip_material(mesh.surface_get_material(i))
			_rock_cache.append(mesh)
		scene.free()
	return _rock_cache

# ------------------------------------------------------------- battle arena
## Battle backdrop with the same kit (scenes/battle_environment.gd, HD mode).
## Purely decorative: battle positions, camera and effects are unchanged.
const BATTLE_GROUND_OFFSET := Vector2(1.5, -2.0)  # battle XZ -> forest mask XZ
const BATTLE_KEEP_CLEAR := [Vector2(-1.8, 1.0), Vector2(-5.6, -2.3), Vector2(-5.2, 2.4), Vector2(2.5, -0.4), Vector2(2.5, 2.2), Vector2(2.5, -3.0), Vector2(0.2, -0.8)]
const BATTLE_SET := [
	# kit/asset, x, z, yaw, size (height for trees, width otherwise)
	["Wall", -3.6, -5.6, 0.04, 0.0], ["Arch", -8.2, -6.2, 0.35, 0.0], ["ColumnTall", -6.3, -3.9, 0.2, 0.0],
	["ColumnShort", 3.4, -4.6, 1.1, 0.0], ["ColumnStub", -1.2, -4.9, 0.4, 0.0], ["ColumnStub", 6.2, -2.6, 2.0, 0.0],
	["Steps", 0.6, -7.2, 0.0, 0.0], ["WallLow", 5.8, -6.4, -0.3, 0.0], ["Pavement", -1.5, 2.4, 0.0, 0.0],
	["jacaranda_tree", -1.8, -9.8, 0.3, 8.4], ["island_tree_02", -10.5, -5.0, 1.2, 8.0], ["tree_small_02", -6.5, -10.0, 2.1, 7.2],
	["island_tree_02", 4.0, -10.5, 0.7, 8.6], ["tree_small_02", 9.5, -7.0, 4.0, 7.0], ["island_tree_02", -12.0, 2.5, 2.8, 7.6],
	["tree_small_02", 11.5, -1.5, 5.1, 6.6], ["island_tree_02", 13.0, -10.0, 3.3, 9.0], ["tree_small_02", -14.0, -9.0, 0.9, 8.0],
	["rock_moss_set_01", 6.8, -4.2, 0.6, 1.6], ["rock_moss_set_01", -9.2, -2.0, 2.2, 1.8], ["rock_moss_set_02", 8.6, 2.6, 1.4, 1.2],
	["rock_moss_set_02", -8.8, 4.8, 0.2, 1.3], ["boulder_01", -3.0, -7.4, 1.0, 1.4], ["dead_tree_trunk", 7.2, 4.6, 2.6, 2.8],
	["root_cluster_01", -10.5, -4.6, 0.0, 2.2], ["tree_stump_01", 4.8, -7.2, 1.9, 0.9],
]

func build_battle() -> void:
	_make_materials()
	var ground: ShaderMaterial = materials.Ground.duplicate()
	ground.set_shader_parameter("mask_rect", Vector4(MASK_RECT.position.x - BATTLE_GROUND_OFFSET.x, MASK_RECT.position.y - BATTLE_GROUND_OFFSET.y, MASK_RECT.size.x, MASK_RECT.size.y))
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 80)
	var floor_node := MeshInstance3D.new()
	floor_node.name = "BattleGround"
	floor_node.mesh = plane
	floor_node.position = Vector3(-1, 0, -12)
	floor_node.material_override = ground
	add_child(floor_node)
	var source: Node3D = load(SCENE_PATH).instantiate()
	var kits := {}
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var kit := String((node as MeshInstance3D).mesh.resource_name).trim_prefix("eclipse_clearing_")
		if not kits.has(kit):
			kits[kit] = _dress_hd((node as MeshInstance3D).mesh, kit)
	source.free()
	var groups := {}
	var order: Array = []
	for item in BATTLE_SET:
		var mesh: Mesh
		var at := Transform3D(Basis(Vector3.UP, item[3]), Vector3(item[1], 0, item[2]))
		var kit: String = item[0]
		if kits.has(kit):
			mesh = kits[kit]
		else:
			var variants := _hd_variants(kit, false)
			if variants.is_empty():
				continue
			mesh = variants[_pick(at.origin, variants.size())]
			at = _fit(at, mesh, {"height": item[4]} if kit.contains("tree") and not kit.contains("dead") and not kit.contains("stump") else {"width": item[4]})
			kit = "TreeBroadA" if kit.contains("tree") and not kit.contains("dead") and not kit.contains("stump") else "RockA"
		var key := "%s|%d" % [item[0], mesh.get_instance_id()]
		if not groups.has(key):
			groups[key] = {"mesh": mesh, "kit": kit, "label": item[0], "far": false, "transforms": []}
			order.append(key)
		groups[key].transforms.append(at)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2027
	for i in 46:
		var a := rng.randf() * TAU
		var r := rng.randf_range(7.5, 12.0)
		var p := Vector3(cos(a) * r - 1.5, 0, sin(a) * r * 0.75 - 1.5)
		if p.z > 5.5 or (p.x > 6.0 and p.z > 1.5):
			continue  # keep the camera side open
		var choice: Array = [["shrub_02", 1.0], ["shrub_03", 0.75], ["fern_02", 0.6], ["nettle_plant", 0.55], ["periwinkle_plant", 0.3]][i % 5]
		var variants := _hd_variants(choice[0], false)
		if variants.is_empty():
			continue
		var mesh: Mesh = variants[_pick(p, variants.size())]
		var at := _fit(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), mesh, {"height": choice[1] * rng.randf_range(0.8, 1.25)})
		var key := "%s|%d" % [choice[0], mesh.get_instance_id()]
		if not groups.has(key):
			groups[key] = {"mesh": mesh, "kit": "BushA", "label": choice[0], "far": false, "transforms": []}
			order.append(key)
		groups[key].transforms.append(at)
	# Far forest wall so the backdrop never ends in empty fog.
	for i in 22:
		var a := lerpf(PI * 0.95, PI * 2.05, i / 21.0) + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(17.0, 24.0)
		var p := Vector3(cos(a) * r - 1.0, 0, sin(a) * r * 0.8 - 3.0)
		var asset: String = ["island_tree_02", "tree_small_02", "island_tree_02", "jacaranda_tree"][i % 4]
		var variants := _hd_variants(asset, false)
		if variants.is_empty():
			continue
		var mesh: Mesh = variants[0]
		var at := _fit(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), mesh, {"height": rng.randf_range(8.0, 10.5)})
		var key := "far|%s" % asset
		if not groups.has(key):
			groups[key] = {"mesh": mesh, "kit": "TreeFarBroad", "label": asset, "far": true, "transforms": []}
			order.append(key)
		groups[key].transforms.append(at)
	for key in order:
		_emit(groups[key])
	_add_battle_grass()
	_add_motes("ArenaMotes", Vector3(-1.5, 1.2, -1.5), Vector3(6.0, 1.0, 3.5), 30, Color(1.0, 0.88, 0.55))

func _add_battle_grass() -> void:
	var mask: Image = (load(HD_DIR + "ground_mask.png") as Texture2D).get_image()
	if mask.is_compressed():
		mask.decompress()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var transforms: Array[Transform3D] = []
	var tries := 0
	while transforms.size() < 6500 and tries < 50000:
		tries += 1
		var x := rng.randf_range(-15.0, 11.0)
		var z := rng.randf_range(-12.0, 7.0)
		var m := _mask_at(mask, x + BATTLE_GROUND_OFFSET.x, z + BATTLE_GROUND_OFFSET.y)
		var density := 0.35 + m.g * 0.6 - m.r * 1.4 - m.b * 1.4
		for keep: Vector2 in BATTLE_KEEP_CLEAR:
			if Vector2(x, z).distance_to(keep) < 0.9:
				density = 0.0
		if rng.randf() > density:
			continue
		var s := rng.randf_range(0.75, 1.3)
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(x, 0, z)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _grass_clump()
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = "GrassHD"
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
