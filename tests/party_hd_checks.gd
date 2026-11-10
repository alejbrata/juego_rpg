extends RefCounted
## Iteration 1.4: semirealistic party assembled from Quaternius packs that the user
## installs locally (git-ignored). The fallback and repository hygiene are always
## checked; the models themselves only when they are installed.

const HEROES := ["kael", "lyra", "nira"]
const HANDS := {"kael": "hand_r", "lyra": "hand_l", "nira": "hand_l"}
const PS1 := preload("res://tests/party_ps1_checks.gd")
var _check: Callable
var _tree: SceneTree

func check(condition: bool, description: String) -> void:
	_check.call(condition, "Grupo HD: " + description)

## Checks that run when the packs are missing (fresh clone): the rest are skipped.
static func installed() -> bool:
	for hero: String in HEROES:
		if not ResourceLoader.exists(KaelModel.HD_PATHS[hero], "PackedScene"):
			return false
	return true

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_check = verify
	var previous: Variant = ProjectSettings.get_setting("visuals/party/style", "current")
	var imported := []
	for hero in ["lyra", "nira"]:
		imported.append(ProjectSettings.get_setting("visuals/%s/use_imported" % hero, false))
		ProjectSettings.set_setting("visuals/%s/use_imported" % hero, true)
	check(String(previous) == "hd", "el proyecto arranca con el grupo HD")
	var ignored := FileAccess.get_file_as_string("res://.gitignore").split("\n", false).has("assets/third_party/")
	var inside := true
	for hero: String in HEROES:
		inside = inside and String(KaelModel.HD_PATHS[hero]).begins_with("res://assets/third_party/party_hd/")
	check(ignored and inside, "modelos de terceros solo en la carpeta ignorada por Git")
	ProjectSettings.set_setting("visuals/party/style", "hd")
	var fallback := true
	for hero: String in HEROES:
		fallback = fallback and KaelModel.styled_path(hero, "actual", {hero: "res://assets/third_party/party_hd/ausente.gltf"}) == "actual"
	check(fallback, "sin paquetes instalados cada héroe conserva su modelo actual")
	var others := true
	for style in ["current", "ps1"]:
		ProjectSettings.set_setting("visuals/party/style", style)
		for hero: String in HEROES:
			others = others and KaelModel.styled_path(hero, "actual") == ("actual" if style == "current" else KaelModel.PS1_PATHS[hero])
	check(others, "los estilos 'current' y 'ps1' no cambian")
	if not installed():
		print("Grupo HD: paquetes Quaternius no instalados (tools/install_quaternius.py); se omiten las comprobaciones de los modelos.")
	else:
		ProjectSettings.set_setting("visuals/party/style", "hd")
		for hero: String in HEROES:
			check_asset(hero)
		await check_battle()
		await check_exploration()
	ProjectSettings.set_setting("visuals/party/style", previous)
	for i in 2:
		ProjectSettings.set_setting("visuals/%s/use_imported" % ["lyra", "nira"][i], imported[i])

func load_model(hero: String) -> KaelModel:
	var model: KaelModel
	if hero == "kael":
		model = KaelModel.new()
		_tree.root.add_child(model)
		model.load_asset(KaelModel.styled_path("kael", KaelModel.ASSET_PATH))
	else:
		model = CompanionModel.new()
		model.hero_id = hero
		_tree.root.add_child(model)
		model.load_asset()
	return model

func check_asset(hero: String) -> void:
	var path: String = KaelModel.HD_PATHS[hero]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.get_basename() + "_manifest.json"))
	check(FileAccess.get_sha256(path) == manifest.gltf_sha256, hero + ": glTF coincide con su manifiesto de construcción")
	var model := load_model(hero)
	check(model.asset != null and model.asset.scene_file_path == path and model.load_error.is_empty(), hero + ": importación real sin fallback")
	if model.asset == null:
		model.free()
		return
	# Library skeleton shared by base body, outfits and animations.
	var skinned := true
	var triangles := 0
	var textures_ok := true
	var top := 0.0
	var bottom := 0.0
	for mesh: MeshInstance3D in model.asset.find_children("*", "MeshInstance3D", true, false):
		if mesh == model.weapon:
			continue
		skinned = skinned and mesh.skin != null and mesh.get_node(mesh.skeleton) == model.skeleton
		for surface in mesh.mesh.get_surface_count():
			triangles += mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null:
				textures_ok = false
				continue
			for texture: Texture2D in [material.albedo_texture, material.normal_texture]:
				# Separate, imported files: VRAM-compressed with mipmaps (never embedded).
				textures_ok = textures_ok and (texture == null or (texture is CompressedTexture2D and texture.resource_path.begins_with(path.get_base_dir()) and texture.get_image().has_mipmaps()))
	model.reset_pose()
	model.animation_player.stop()
	model.skeleton.reset_bone_poses()
	var extent := skinned_extent(model)
	top = extent.y
	bottom = extent.x
	check(model.skeleton.get_bone_count() == 65 and skinned and model.skeleton.find_bone(HANDS[hero]) >= 0, hero + ": esqueleto de 65 huesos y mallas con piel")
	var attachment := model.weapon.get_parent() as BoneAttachment3D if model.weapon != null else null
	check(attachment != null and attachment.bone_name == HANDS[hero] and model.weapon is MeshInstance3D and (model.weapon as MeshInstance3D).skin == null, hero + ": %s unido a %s" % [model._weapon_name(), HANDS[hero]])
	check(textures_ok, hero + ": texturas importadas comprimidas con mipmaps")
	check(triangles > 15000 and triangles <= 40000 and triangles == int(manifest.triangles) - weapon_triangles(model), hero + ": presupuesto (%d triángulos sin arma)" % triangles)
	check(absf((top - bottom) - float(manifest.height)) < float(manifest.height) * .03, hero + ": altura en reposo %.2f igual a la establecida %.2f" % [top - bottom, float(manifest.height)])
	check(float(manifest.walk_reference_speed) * 2.5 >= 4.0, hero + ": zancada cubre la velocidad de exploración sin resbalar (%.2f m/s)" % float(manifest.walk_reference_speed))
	var clips: Array[String] = model._required_clips()
	var ap := model.animation_player
	var clips_ok := true
	var durations_ok := true
	for clip in clips:
		var animation := ap.get_animation(clip)
		clips_ok = clips_ok and animation != null and animation.loop_mode == (Animation.LOOP_LINEAR if clip in ["Idle", "Walk"] else Animation.LOOP_NONE)
		if animation == null:
			continue
		if clip not in ["Idle", "Walk"]:
			durations_ok = durations_ok and manifest.presentation_durations.has(clip) and model.presentation_duration(clip) > .2
		model.reset_pose()
		ap.play(clip, 0)
		ap.advance(0)
		ap.seek(0, true)
		var first: Array[Transform3D] = []
		for bone in model.skeleton.get_bone_count():
			first.append(model.skeleton.get_bone_pose(bone))
		ap.seek(animation.length * .5, true)
		var moves := false
		for bone in model.skeleton.get_bone_count():
			moves = moves or not first[bone].is_equal_approx(model.skeleton.get_bone_pose(bone))
		clips_ok = clips_ok and moves
	check(clips_ok, hero + ": %d clips con bucle correcto y movimiento" % clips.size())
	check(durations_ok, hero + ": duración de presentación para cada acción")
	var held := true
	for clip in ["KO", "Defend"]:
		model.reset_pose(clip)
		held = held and model.current_clip == clip and not ap.is_playing()
	model.play_action("Attack", .3)
	model.reset_pose()
	check(held and model.current_clip == "Idle" and ap.is_playing(), hero + ": KO/Defend mantienen la pose y reiniciar vuelve a Idle")
	model.free()

## Vertical extent of the skinned vertices as rendered (rest pose, world space).
func skinned_extent(model: KaelModel) -> Vector2:
	var low := INF
	var high := -INF
	model.skeleton.force_update_all_bone_transforms()
	for mesh: MeshInstance3D in model.asset.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null:
			continue
		var transforms: Array[Transform3D] = []
		for bind in mesh.skin.get_bind_count():
			var bone := model.skeleton.find_bone(mesh.skin.get_bind_name(bind))
			if bone < 0:
				bone = mesh.skin.get_bind_bone(bind)
			transforms.append(model.skeleton.global_transform * model.skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := bones.size() / maxi(1, points.size())
			for v in range(0, points.size(), 7):
				var y := 0.0
				for k in stride:
					var w := weights[v * stride + k]
					if w > 0.0:
						y += w * (transforms[bones[v * stride + k]] * points[v]).y
				low = minf(low, y)
				high = maxf(high, y)
	return Vector2(low, high)

func weapon_triangles(model: KaelModel) -> int:
	var total := 0
	var mesh := (model.weapon as MeshInstance3D).mesh
	for surface in mesh.get_surface_count():
		total += mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3
	return total

func check_battle() -> void:
	var helper := PS1.new()
	helper._tree = _tree
	helper._check = _check
	var current: Array = await helper.scripted_battle("current")
	var homes: Array = current[2].visuals.map(func(v): return v.home)
	current[2].free()
	var hd: Array = await helper.scripted_battle("hd")
	var stage = hd[2]
	var expected := []
	for hero: String in HEROES:
		expected.append(KaelModel.HD_PATHS[hero])
	check(hd[0] == expected, "batalla carga los tres modelos HD")
	check(current[1] == hd[1], "mismas órdenes producen el mismo estado de combate que con los modelos actuales")
	check(homes == stage.visuals.map(func(v): return v.home), "mismas posiciones de combate")
	var mapping := {"physical": "Attack", "hit": "Hurt", "guard": "Defend", "knockout": "KO"}
	var events := true
	for i in 3:
		var visual: BattleActorVisual = stage.visuals[i]
		for effect: String in mapping:
			visual.animate(effect)
			events = events and visual.imported_model.current_clip == mapping[effect]
	events = events and stage.visuals[1].imported_model.clip_for_effect("magic") == "Cast" and stage.visuals[2].imported_model.clip_for_effect("heal") == "Support"
	check(events, "eventos del motor reproducen sus clips (Cast de Lyra, Support de Nira)")
	stage.hud._restart()
	var after_restart := true
	for i in 3:
		after_restart = after_restart and stage.visuals[i].imported_model.asset.scene_file_path == expected[i] and stage.visuals[i].imported_model.current_clip == "Idle"
	check(after_restart and stage._effects.get_child_count() == 0 and stage.event_queue.is_empty(), "reinicio conserva los modelos HD y limpia la presentación")
	# Closer framing for the HD party: the whole fight stays above the command panel.
	var original_size := _tree.root.size
	var framed: bool = stage.camera.position.is_equal_approx(BattleEnvironment.HD_PARTY_CAMERA) and stage.camera.position.length() < Vector3(8.5, 8.2, 13.7).length() * .8
	for size in [Vector2i(1280, 720), Vector2i(960, 640), Vector2i(800, 450)]:
		_tree.root.size = size
		await _tree.process_frame
		# Projections are in the stretched visible rect (canvas_items, expand).
		var rect: Vector2 = stage.camera.get_viewport().get_visible_rect().size
		for visual: BattleActorVisual in stage.visuals:
			for point in [visual.home, visual.home + Vector3.UP * 2.0]:
				var screen: Vector2 = stage.camera.unproject_position(point)
				framed = framed and screen.x > 0 and screen.x < rect.x and screen.y > rect.y * .1 and screen.y < rect.y * .68
	_tree.root.size = original_size
	check(framed, "cámara de combate más cercana con los cuatro combatientes sobre el panel (3 resoluciones)")
	stage.free()

func check_exploration() -> void:
	var zone = preload("res://scenes/forest_zone.tscn").instantiate()
	zone.session.mission.intro_seen = true
	_tree.root.add_child(zone)
	await _tree.process_frame
	var model: KaelModel = zone.player.model.imported_model
	check(model != null and model.asset.scene_file_path == KaelModel.HD_PATHS.kael, "exploración usa a Kael HD")
	zone.player.set_movement_input(Vector2.RIGHT)
	for i in 6:
		await _tree.physics_frame
	var walking: bool = model.current_clip == "Walk" and zone.player.position.x > GameSession.SPAWN.x
	zone.player.set_movement_input(Vector2.ZERO)
	for i in 3:
		await _tree.physics_frame
	check(walking and model.current_clip == "Idle", "Kael HD camina con la misma física y vuelve a Idle al parar")
	var followers: PartyFollowers = zone.followers
	var members_ok := followers != null and followers.members.size() == 2
	if members_ok:
		for i in 2:
			var member := followers.members[i]
			members_ok = members_ok and member.imported_model != null and member.imported_model.asset.scene_file_path == KaelModel.HD_PATHS[["lyra", "nira"][i]]
	check(members_ok and followers.find_children("*", "CollisionObject3D", true, false).is_empty(), "Lyra y Nira acompañan a Kael en exploración sin cuerpos físicos")
	if not members_ok:
		zone.free()
		return
	zone.player.set_movement_input(Vector2(-1, 0))
	for i in 50:
		await _tree.physics_frame
	var trail_ok := true
	for i in 2:
		var member := followers.members[i]
		var behind := Vector2(member.position.x - zone.player.position.x, member.position.z - zone.player.position.z).length()
		trail_ok = trail_ok and member.imported_model.current_clip == "Walk" and behind > PartyFollowers.GAPS[i] * .8 and behind < PartyFollowers.GAPS[i] + .2
	zone.player.set_movement_input(Vector2.ZERO)
	for i in 3:
		await _tree.physics_frame
	for member in followers.members:
		trail_ok = trail_ok and member.imported_model.current_clip == "Idle"
	check(trail_ok, "seguidores caminan detrás por la estela de Kael y se detienen con él")
	zone.player.position = Vector3(5, zone.player.position.y, -2.8)
	await _tree.physics_frame
	await _tree.physics_frame
	var near := true
	for member in followers.members:
		near = near and Vector2(member.position.x - zone.player.position.x, member.position.z - zone.player.position.z).length() < 3.0
	check(near, "si Kael reaparece en otro punto, el grupo se recoloca con él")
	zone.free()
	ProjectSettings.set_setting("visuals/party/style", "current")
	var legacy = preload("res://scenes/forest_zone.tscn").instantiate()
	legacy.session.mission.intro_seen = true
	_tree.root.add_child(legacy)
	await _tree.process_frame
	check(legacy.followers == null and legacy.get_node_or_null("Followers") == null, "con los modelos anteriores la exploración sigue mostrando solo a Kael")
	legacy.free()
	ProjectSettings.set_setting("visuals/party/style", "hd")
