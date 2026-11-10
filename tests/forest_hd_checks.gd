extends RefCounted
## Iteration 1.3: HD forest (Forward+, CC0 Poly Haven kit) in exploration and battle.
## Reuses the 1.1 helpers (colliders, framing, physical walk) without changing them.

const BASE := preload("res://tests/forest_art_checks.gd")
const HD_DIR := "res://assets/environments/eclipse_forest_hd/"

var _tree: SceneTree
var _verify: Callable
var _base: RefCounted

func check(condition: bool, description: String) -> void:
	_verify.call(condition, "Bosque HD: " + description)

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_verify = verify
	_base = BASE.new()
	_base._tree = tree
	_base._verify = verify
	var previous_hd: Variant = ProjectSettings.get_setting("visuals/forest/hd", false)
	var previous_renovated: Variant = ProjectSettings.get_setting("visuals/forest/renovated", false)
	var original_size := tree.root.size
	tree.root.size = Vector2i(960, 640)
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus", "proyecto configurado con Forward+")

	# --- licences and kit -------------------------------------------------
	var sources: Variant = JSON.parse_string(FileAccess.get_file_as_string(HD_DIR + "sources.json"))
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(HD_DIR + "kit_manifest.json"))
	check(sources is Array and manifest is Dictionary, "procedencia y manifiesto del kit legibles")
	var licensed := {}
	for entry: Dictionary in sources:
		if entry.license == "CC0 1.0" and String(entry.url).begins_with("https://polyhaven.com/a/"):
			licensed[entry.asset] = true
	var used := {}
	for kit: String in ForestArtHD.SWAPS:
		for swap: Dictionary in ForestArtHD.SWAPS[kit]:
			used[swap.asset] = true
	for extra: Array in ForestArtHD.EXTRAS:
		used[extra[0]] = true
	for item: Array in ForestArtHD.BATTLE_SET:
		if ResourceLoader.exists(HD_DIR + "models/" + String(item[0]) + ".glb"):
			used[item[0]] = true
	var all_licensed := true
	var all_present := true
	var budget_ok := true
	for asset: String in used:
		all_licensed = all_licensed and licensed.has(asset)
		all_present = all_present and ResourceLoader.exists(HD_DIR + "models/" + asset + ".glb") and manifest.has(asset)
		if manifest.has(asset):
			for variant: Dictionary in manifest[asset].variants:
				budget_ok = budget_ok and int(variant.triangles) <= 90000
	check(all_licensed, "cada modelo usado figura como CC0 de Poly Haven en sources.json")
	check(all_present, "cada modelo usado existe y está en el manifiesto")
	check(budget_ok, "ninguna variante supera 90000 triángulos")
	var textures_ok := true
	for set_name in ["forest_leaves_02", "leafy_grass", "rocky_trail", "mossy_cobblestone", "medieval_blocks_05", "mossy_rock", "medieval_wood"]:
		textures_ok = textures_ok and licensed.has(set_name) and ResourceLoader.exists("%stextures/%s/%s_diff_2k.jpg" % [HD_DIR, set_name, set_name])
	check(textures_ok and licensed.has("forest_grove") and ResourceLoader.exists(ForestArtHD.SKY_PATH), "texturas PBR y cielo HDRI con licencia registrada")

	# --- exploration -------------------------------------------------------
	ProjectSettings.set_setting("visuals/forest/hd", true)
	var zone: Node3D = _base.make_zone(true)
	await tree.process_frame
	var art := zone.get_node("ForestArt") as ForestArtHD
	check(art != null, "selector HD construye ForestArtHD")
	check(_base.collider_snapshot(zone) == _base.expected_colliders(), "HD conserva los 18 colliders, dimensiones y máscaras")
	check(art.find_children("*", "CollisionObject3D", true, false).is_empty(), "el arte HD no añade cuerpos físicos")
	var camera: Camera3D = zone.get_node("ForestCamera")
	check(camera.position.is_equal_approx(ForestArt.CAMERA_POSITION) and is_equal_approx(camera.fov, ForestArt.CAMERA_FOV), "cámara de juego idéntica a 1.1")
	for aspect in [1.5, 16.0 / 9.0, 20.0 / 9.0]:
		var inside := true
		for position in [GameSession.SPAWN, Vector3(0, 0, 1), Vector3(5, 0, -2.8), Vector3(-8.1, 0, -6.1), Vector3(8.1, 0, 6.1)]:
			inside = inside and _base.on_screen(camera, position, aspect, .02)
		check(inside, "encuadre completo (aspecto %.2f)" % aspect)
	for prop: String in ForestArt.NARRATIVE_PROPS:
		var id: String = ForestArt.NARRATIVE_PROPS[prop]
		var node := art.get_node_or_null(prop) as Node3D
		check(node != null and node.position.is_equal_approx(zone.interests[id].position), "prop narrativo anclado a " + id)
	var shards: Array[Node] = zone.interests.crystal._energy.find_children("*", "MeshInstance3D", true, false)
	check(shards.size() >= 8, "cristal HD con varias facetas en el mismo nodo de energía")
	var scan_meshes := {}
	for cached: Array in art._kit_cache.values():
		for mesh: Mesh in cached:
			scan_meshes[mesh] = true
	for far: Mesh in art._far_of.values():
		scan_meshes[far] = true
	var swapped := 0
	for kit: String in ["TreeAncient", "PineA", "PineB", "RockA", "Log"]:
		var nodes := art.find_children(kit + "*", "GeometryInstance3D", true, false)
		var scanned_kit := not nodes.is_empty()
		for node: GeometryInstance3D in nodes:
			var mesh: Mesh = node.mesh if node is MeshInstance3D else (node as MultiMeshInstance3D).multimesh.mesh
			scanned_kit = scanned_kit and scan_meshes.has(mesh)
		swapped += 1 if scanned_kit else 0
	check(swapped == 5, "árboles, rocas y troncos sustituidos por escaneos (%d/5)" % swapped)
	var mipmapped := not art._kit_cache.is_empty()
	for cached: Array in art._kit_cache.values():
		for mesh: Mesh in cached:
			for i in mesh.get_surface_count():
				var material := mesh.surface_get_material(i)
				var texture: Texture2D = material.albedo_texture if material is StandardMaterial3D else material.get_shader_parameter("albedo_tex")
				mipmapped = mipmapped and (texture == null or texture.get_image().has_mipmaps())
	check(mipmapped, "texturas incrustadas del kit con mipmaps en tiempo de ejecución")
	var far_ok := not art._far_of.is_empty()
	var far_count := 0
	for node: MeshInstance3D in art.find_children("PineFar*", "MeshInstance3D", true, false):
		far_count += 1
		far_ok = far_ok and art._far_of.values().has(node.mesh) and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var proxies := art.find_children("*Shadow*", "MeshInstance3D", true, false)
	for proxy: MeshInstance3D in proxies:
		far_ok = far_ok and proxy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	check(far_ok and far_count > 0 and not proxies.is_empty(), "árboles lejanos aligerados sin sombra y sombras de árboles cercanos con la versión ligera")
	var grass := art.get_node_or_null("GrassHD") as MultiMeshInstance3D
	var mask: Image = (load(HD_DIR + "ground_mask.png") as Texture2D).get_image()
	var on_trail := 0
	if grass != null:
		for i in grass.multimesh.instance_count:
			var at := grass.multimesh.get_instance_transform(i).origin
			if ForestArtHD._mask_at(mask, at.x, at.z).r > .6:
				on_trail += 1
	check(grass != null and grass.multimesh.instance_count > 3000 and on_trail < grass.multimesh.instance_count / 100, "hierba instanciada fuera de los caminos (%d sobre camino)" % on_trail)
	zone.player.position = Vector3(-7.9, .05, -2.2)
	await tree.process_frame
	var reveal_ok := not art._reveal_materials.is_empty()
	for material in art._reveal_materials:
		var target: Vector3 = material.get_shader_parameter("reveal_target")
		reveal_ok = reveal_ok and Vector2(target.x, target.z).is_equal_approx(Vector2(zone.player.global_position.x, zone.player.global_position.z))
	check(reveal_ok, "copas HD se transparentan alrededor de Kael")
	zone.player.position = GameSession.SPAWN
	await tree.physics_frame
	zone.encounter_armed = false
	var walked := true
	for step in [Vector2(-4.5, 2.9), Vector2(-4.3, -2.8), Vector2(0, -2.9), Vector2(3.1, -.5), Vector2(0, 1)]:
		walked = walked and await _base.walk_to(zone, step)
	check(walked, "recorrido físico completo sin bloqueos en HD")
	zone.free()

	# --- golems and battle --------------------------------------------------
	var golem := Node3D.new()
	StylizedModels.golem(golem, StylizedModels.mat("6e7b73"))
	var scanned := 0
	for mesh: MeshInstance3D in golem.find_children("*", "MeshInstance3D", true, false):
		scanned += 1 if ForestArtHD.rock_variants().has(mesh.mesh) else 0
	check(scanned >= 12, "Centinela HD compuesto por rocas escaneadas (%d)" % scanned)
	golem.free()
	var stage = load("res://scenes/battle_3d.tscn").instantiate()
	stage.camera_motion_enabled = false
	tree.root.add_child(stage)
	await tree.process_frame
	var arena := stage.get_node_or_null("ArenaArt") as ForestArtHD
	check(arena != null and arena.find_children("*", "CollisionObject3D", true, false).is_empty(), "arena de batalla HD sin cuerpos físicos")
	check(stage.camera.position.is_equal_approx(Vector3(8.5, 8.2, 13.7)) and is_equal_approx(stage.camera.fov, 42), "batalla conserva cámara y encuadre")
	var homes: Array = stage.visuals.map(func(v): return v.home)
	stage.free()
	ProjectSettings.set_setting("visuals/forest/hd", false)
	var legacy_stage = load("res://scenes/battle_3d.tscn").instantiate()
	legacy_stage.camera_motion_enabled = false
	tree.root.add_child(legacy_stage)
	await tree.process_frame
	check(legacy_stage.get_node_or_null("ArenaArt") == null and homes == legacy_stage.visuals.map(func(v): return v.home), "desactivar HD restaura la arena anterior con las mismas posiciones")
	legacy_stage.free()
	var restored: Node3D = _base.make_zone(true)
	await tree.process_frame
	check(not (restored.get_node("ForestArt") is ForestArtHD), "desactivar HD restaura el bosque 1.1")
	restored.free()

	tree.root.size = original_size
	ProjectSettings.set_setting("visuals/forest/hd", previous_hd)
	ProjectSettings.set_setting("visuals/forest/renovated", previous_renovated)
