extends RefCounted

const PATH := "res://assets/characters/kael/retro/kael.glb"
const SOURCE := "res://assets/characters/kael/polished/kael.glb"

func run(tree: SceneTree, check: Callable) -> void:
	var base := PATH.get_base_dir() + "/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "kael_manifest.json"))
	check.call(FileAccess.get_sha256(PATH) == manifest.glb_sha256 and FileAccess.get_sha256(base + "kael.blend") == manifest.blend_sha256, "Retro: fuente y GLB trazables")
	check.call(FileAccess.get_sha256(base + "kael_atlas.png") == manifest.atlas_sha256 and FileAccess.get_sha256("res://tools/blender/style_kael_retro.py") == manifest.style_script_sha256, "Retro: atlas y script trazables")
	check.call(FileAccess.get_sha256(SOURCE) == manifest.source_glb_sha256 and FileAccess.get_sha256(SOURCE.get_base_dir() + "/kael.blend") == manifest.source_blend_sha256, "Retro: polished permanece intacto")
	var file := FileAccess.open(PATH, FileAccess.READ)
	file.seek(12)
	var length := file.get_32()
	file.get_32()
	var gltf: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	var image_view: Dictionary = gltf.bufferViews[gltf.images[0].bufferView]
	file.seek(28 + length + int(image_view.get("byteOffset", 0)))
	check.call(file.get_buffer(image_view.byteLength) == FileAccess.get_file_as_bytes(base + "kael_atlas.png"), "Retro: textura revisada realmente embebida")
	var current := KaelModel.new()
	var source := KaelModel.new()
	tree.root.add_child(current)
	tree.root.add_child(source)
	var loaded := current.load_asset(PATH) and source.load_asset(SOURCE)
	check.call(loaded, "Retro: importación real de ambas versiones")
	if not loaded:
		current.free()
		source.free()
		return
	var face_before := tile_bounds(source, 0)
	var face_after := tile_bounds(current, 0)
	var eye_before := tile_bounds(source, 11)
	var eye_after := tile_bounds(current, 11)
	check.call(face_after.size.x > face_before.size.x * 1.1 and face_after.size.x < face_before.size.x * 1.35, "Retro: cabeza ensanchada en malla importada sin desproporción extrema")
	check.call(eye_after.size.y > eye_before.size.y * 1.3, "Retro: apertura real de ojos mayor, medida por UV de esclerótica")
	var topology := true
	var total_triangles := 0
	var total_surfaces := 0
	for mesh: MeshInstance3D in current.asset.find_children("*", "MeshInstance3D", true, false):
		var original := source.asset.find_child(mesh.name, true, false) as MeshInstance3D
		topology = topology and original != null and mesh.mesh.get_surface_count() == original.mesh.get_surface_count()
		for s in range(mesh.mesh.get_surface_count()):
			total_surfaces += 1
			var arrays := mesh.mesh.surface_get_arrays(s)
			var previous := original.mesh.surface_get_arrays(s)
			total_triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			topology = topology and arrays[Mesh.ARRAY_VERTEX].size() == previous[Mesh.ARRAY_VERTEX].size()
			var mat := mesh.mesh.surface_get_material(s) as StandardMaterial3D
			topology = topology and mat.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and mat.albedo_texture.get_width() == 1024
	check.call(topology and total_triangles == 12297 and total_surfaces == 5, "Retro: geometría y superficies conservadas, materiales iluminados")
	var rig_equal := current.skeleton.get_bone_count() == source.skeleton.get_bone_count()
	for b in range(current.skeleton.get_bone_count()):
		rig_equal = rig_equal and current.skeleton.get_bone_rest(b).is_equal_approx(source.skeleton.get_bone_rest(b))
	check.call(rig_equal, "Retro: rig de reposo conservado para las Actions")
	var ap := current.animation_player
	for clip in KaelModel.REQUIRED:
		var animation := ap.get_animation(clip)
		check.call(animation != null and is_equal_approx(animation.length, source.animation_player.get_animation(clip).length), "Retro: clip y duración conservados " + clip)
	for clip in ["Walk", "KO"]:
		current.reset_pose()
		ap.play(clip, 0)
		ap.advance(0)
		var minimum := INF
		var duration := ap.get_animation(clip).length
		var helper := preload("res://tests/kael_polish_checks.gd").new()
		for sample in range(int(duration * 120) + 1):
			ap.seek(minf(sample / 120.0, duration), true)
			minimum = minf(minimum, helper.skin_min_y(current))
		print("RETRO_SKIN_MIN_Y ", clip, " ", minimum)
		check.call(minimum >= -0.0001 and minimum < .02, "Retro: skin importado " + clip + " sobre suelo entre claves")
	var second := KaelModel.new()
	tree.root.add_child(second)
	second.load_asset(PATH)
	current.reset_pose()
	current.set_walking(true)
	check.call(second.current_clip == "Idle" and not is_same(ap.get_animation("Walk"), second.animation_player.get_animation("Walk")) and is_equal_approx(ap.speed_scale, 1.2), "Retro: locomoción e instancias independientes")
	current.set_walking(false)
	check.call(current.current_clip == "Idle" and is_equal_approx(ap.speed_scale, 1.0), "Retro: transición de parada")
	current.free()
	source.free()
	second.free()
	var setting: Variant = ProjectSettings.get_setting("visuals/kael/asset_version")
	ProjectSettings.set_setting("visuals/kael/asset_version", "retro")
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	tree.root.add_child(stage)
	await tree.process_frame
	check.call(stage.visuals[0].imported_model.asset.scene_file_path == PATH, "Retro: batalla usa variante correcta")
	stage.visuals[0].animate("physical")
	stage.hud._restart()
	await tree.process_frame
	check.call(stage.visuals[0].imported_model.current_clip == "Idle", "Retro: reinicio durante ataque")
	stage.free()
	var zone = preload("res://scenes/forest_zone.tscn").instantiate()
	zone.session.mission.intro_seen = true
	tree.root.add_child(zone)
	await tree.process_frame
	check.call(zone.player.model.imported_model.asset.scene_file_path == PATH and zone.player.model.imported_model.scale == Vector3.ONE, "Retro: misma malla y escala en exploración")
	zone.player.set_movement_input(Vector2.RIGHT)
	for i in range(8):
		await tree.physics_frame
	check.call(zone.player.model.imported_model.current_clip == "Walk" and is_equal_approx(zone.player.velocity.x, 4), "Retro: movimiento real sin cambiar velocidad")
	zone.free()
	ProjectSettings.set_setting("visuals/kael/asset_version", setting)

func tile_bounds(model: KaelModel, tile: int) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.asset.find_children("*", "MeshInstance3D", true, false):
		for s in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			for i in range(points.size()):
				# glTF/Godot flips Blender's V coordinate on export.
				if int(uvs[i].x * 4) + int((1.0 - uvs[i].y) * 4) * 4 != tile:
					continue
				bounds = AABB(points[i], Vector3.ZERO) if first else bounds.expand(points[i])
				first = false
	return bounds
