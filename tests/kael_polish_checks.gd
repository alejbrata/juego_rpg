extends RefCounted

const PATH := "res://assets/characters/kael/polished/kael.glb"

func run(tree: SceneTree, check: Callable) -> void:
	var base := PATH.get_base_dir() + "/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "kael_manifest.json"))
	check.call(FileAccess.get_sha256(PATH) == manifest.glb_sha256 and FileAccess.get_sha256(base + "kael.blend") == manifest.blend_sha256, "Pulido: fuente y GLB trazables")
	check.call(FileAccess.get_sha256(base + "kael_atlas.png") == manifest.atlas_sha256 and FileAccess.get_sha256("res://tools/blender/polish_kael.py") == manifest.polish_script_sha256, "Pulido: atlas y script trazables")
	check.call(FileAccess.get_sha256("res://assets/characters/kael/reference_study/kael.blend") == manifest.source_blend_sha256 and FileAccess.get_sha256("res://assets/characters/kael/reference_study/kael.glb") == manifest.source_glb_sha256, "Pulido: original conservado")
	var file := FileAccess.open(PATH, FileAccess.READ)
	file.seek(12)
	var length := file.get_32()
	file.get_32()
	var gltf: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	var view: Dictionary = gltf.bufferViews[gltf.images[0].bufferView]
	file.seek(28 + length + int(view.get("byteOffset", 0)))
	var png := file.get_buffer(view.byteLength)
	check.call(png == FileAccess.get_file_as_bytes(base + "kael_atlas.png"), "Pulido: GLB incrusta exactamente el atlas revisado, no el packed antiguo")
	var model := KaelModel.new()
	tree.root.add_child(model)
	check.call(model.load_asset(PATH), "Pulido: importación real")
	var other := KaelModel.new()
	tree.root.add_child(other)
	check.call(other.load_asset(PATH), "Pulido: segunda instancia")
	var triangles := 0
	var vertices := 0
	var surfaces := 0
	var materials: Array[Material] = []
	for mesh: MeshInstance3D in model.asset.find_children("*", "MeshInstance3D", true, false):
		for s in range(mesh.mesh.get_surface_count()):
			surfaces += 1
			var arrays := mesh.mesh.surface_get_arrays(s)
			vertices += arrays[Mesh.ARRAY_VERTEX].size()
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			var material := mesh.mesh.surface_get_material(s) as StandardMaterial3D
			if not materials.has(material):
				materials.append(material)
	check.call(triangles == 12297 and vertices == 14830 and surfaces == 5 and materials.size() == 3 and model.skeleton.get_bone_count() == 17, "Pulido: sin crecimiento de geometría, superficies o rig")
	var shaded := true
	for material: StandardMaterial3D in materials:
		shaded = shaded and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and material.albedo_texture.get_width() == 1024
	check.call(shaded, "Pulido: materiales iluminados y atlas 1024")
	var ap := model.animation_player
	for clip in KaelModel.REQUIRED:
		check.call(ap.has_animation(clip) and not is_same(ap.get_animation(clip), other.animation_player.get_animation(clip)), "Pulido: clip independiente " + clip)
	model.set_walking(true, 1.0)
	check.call(is_equal_approx(ap.speed_scale, 1.2) and other.current_clip == "Idle", "Pulido: zancada sincronizada a 4 m/s sin alterar otra instancia")
	model.set_walking(false)
	check.call(model.current_clip == "Idle" and is_equal_approx(ap.speed_scale, 1.0), "Pulido: detención restaura Idle y velocidad")
	check.call(is_equal_approx(model.presentation_duration("Attack"), .8) and is_equal_approx(model.presentation_duration("KO"), 1.0) and is_zero_approx(model.lunge_distance), "Pulido: tiempos completos y ataque con pies plantados")
	# Evaluate imported skin, not the undeformed Mesh AABB. Half-frame samples
	# exercise interpolation between the author's 60 Hz keys as well.
	for clip in ["Walk", "KO"]:
		model.reset_pose()
		ap.play(clip, 0)
		ap.advance(0)
		var minimum := INF
		var duration := ap.get_animation(clip).length
		for sample in range(int(duration * 120) + 1):
			ap.seek(minf(sample / 120.0, duration), true)
			minimum = minf(minimum, skin_min_y(model))
		print("KAEL_SKIN_MIN_Y ", clip, " ", minimum)
		check.call(minimum >= -0.0001 and minimum < 0.02, "Pulido: skin " + clip + " sobre plano de apoyo (mínimo %.5f)" % minimum)
	for clip in ["Idle", "Walk"]:
		ap.play(clip, 0)
		ap.advance(0)
		ap.seek(0, true)
		var initial: Array[Transform3D] = []
		for b in range(model.skeleton.get_bone_count()):
			initial.append(model.skeleton.get_bone_pose(b))
		ap.seek(ap.get_animation(clip).length - .00001, true)
		var continuous := true
		for b in range(model.skeleton.get_bone_count()):
			continuous = continuous and initial[b].origin.distance_to(model.skeleton.get_bone_pose(b).origin) < .001 and initial[b].basis.get_rotation_quaternion().angle_to(model.skeleton.get_bone_pose(b).basis.get_rotation_quaternion()) < .005
		check.call(continuous, "Pulido: bucle continuo " + clip)
	ap.play("Attack", 0)
	ap.advance(0)
	var weapon_clearance := INF
	for sample in range(49):
		ap.seek(sample / 60.0, true)
		weapon_clearance = minf(weapon_clearance, skin_min_y(model, 0, true))
	check.call(weapon_clearance > .25, "Pulido: espada permanece fuera del corredor central del torso durante Attack")
	model.free()
	other.free()
	var previous: Variant = ProjectSettings.get_setting("visuals/kael/asset_version")
	ProjectSettings.set_setting("visuals/kael/asset_version", "polished")
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	tree.root.add_child(stage)
	await tree.process_frame
	var actor: BattleActorVisual = stage.visuals[0]
	check.call(actor.imported_model.asset.scene_file_path == PATH and actor.imported_model.scale == Vector3.ONE, "Pulido: batalla usa GLB a escala unitaria")
	var snapshot: Dictionary = preload("res://tests/guardian_checks.gd").new().snapshot(stage.hud.engine)
	actor.animate("physical")
	await tree.create_timer(.42).timeout
	check.call(actor.imported_model.current_clip == "Attack" and actor.body.position.is_equal_approx(Vector3.ZERO), "Pulido: ataque no se corta a 0.36 s ni desliza el cuerpo")
	stage.hud._restart()
	await tree.process_frame
	check.call(stage.visuals[0].imported_model.current_clip == "Idle" and preload("res://tests/guardian_checks.gd").new().snapshot(stage.hud.engine) == snapshot, "Pulido: reinicio cancela presentación sin cambiar reglas")
	stage.free()
	var zone = preload("res://scenes/forest_zone.tscn").instantiate()
	zone.session.mission.intro_seen = true
	tree.root.add_child(zone)
	await tree.process_frame
	check.call(zone.player.model.imported_model.asset.scene_file_path == PATH and zone.player.model.imported_model.scale == Vector3.ONE and is_equal_approx(zone.player.model.position.y, .05), "Pulido: exploración comparte asset/escala y apoyo de cápsula")
	zone.player.set_movement_input(Vector2.RIGHT)
	for i in range(10):
		await tree.physics_frame
	check.call(zone.player.model.imported_model.current_clip == "Walk" and is_equal_approx(zone.player.model.imported_model.animation_player.speed_scale, 1.2), "Pulido: locomoción real reproduce Walk a velocidad de desplazamiento")
	zone.player.set_movement_input(Vector2.ZERO)
	for i in range(4):
		await tree.physics_frame
	check.call(zone.player.model.imported_model.current_clip == "Idle", "Pulido: exploración vuelve a Idle")
	zone.free()
	ProjectSettings.set_setting("visuals/kael/asset_version", previous)

func skin_min_y(model: KaelModel, axis: int = 1, weapon_only: bool = false) -> float:
	var result := INF
	model.skeleton.force_update_all_bone_transforms()
	for mesh: MeshInstance3D in model.asset.find_children("*", "MeshInstance3D", true, false):
		if weapon_only and mesh != model.weapon:
			continue
		var transforms: Array[Transform3D] = []
		for bind in range(mesh.skin.get_bind_count()):
			var bone := model.skeleton.find_bone(mesh.skin.get_bind_name(bind))
			if bone < 0:
				bone = mesh.skin.get_bind_bone(bind)
			transforms.append(model.skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
		for s in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for i in range(vertices.size()):
				var p := Vector3.ZERO
				for j in range(4):
					p += (transforms[bones[i * 4 + j]] * vertices[i]) * weights[i * 4 + j]
				result = minf(result, p[axis])
	return result
