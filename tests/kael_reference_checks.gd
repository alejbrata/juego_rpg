extends RefCounted

const CANDIDATE := "res://assets/characters/kael/reference_study/kael.glb"

func run(tree: SceneTree, check: Callable) -> void:
	var base := CANDIDATE.get_base_dir() + "/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "kael_manifest.json"))
	check.call(FileAccess.get_sha256(CANDIDATE) == manifest.glb_sha256 and FileAccess.get_sha256(base + "kael.blend") == manifest.blend_sha256, "Referencia: fuente y GLB coinciden con manifiesto")
	check.call(FileAccess.get_sha256(base + "kael_atlas.png") == manifest.atlas_sha256 and FileAccess.get_sha256("res://tools/blender/kael_reference_mesh.py") == manifest.mesh_script_sha256, "Referencia: atlas y geometría trazables")
	var file := FileAccess.open(CANDIDATE, FileAccess.READ)
	file.seek(12)
	var length := file.get_32()
	file.get_32()
	var gltf: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	check.call(gltf.images.size() == 1 and gltf.images[0].has("bufferView") and not gltf.images[0].has("uri") and not gltf.buffers[0].has("uri"), "Referencia: GLB autosuficiente sin texturas externas")
	var model := KaelModel.new()
	tree.root.add_child(model)
	var loaded := model.load_asset(CANDIDATE)
	check.call(loaded, "Referencia: carga real mediante adaptador")
	if not loaded:
		model.free()
		return
	var triangles := 0
	var vertices := 0
	var surfaces := 0
	var valid := true
	var textures: Array[Texture2D] = []
	for mesh: MeshInstance3D in model.asset.find_children("*", "MeshInstance3D", true, false):
		valid = valid and mesh.skin != null and mesh.get_node(mesh.skeleton) == model.skeleton
		for surface in range(mesh.mesh.get_surface_count()):
			surfaces += 1
			var arrays := mesh.mesh.surface_get_arrays(surface)
			vertices += arrays[Mesh.ARRAY_VERTEX].size()
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			valid = valid and arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size()
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				valid = valid and point.is_finite()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for i in range(0, weights.size(), 4):
				valid = valid and absf(weights[i] + weights[i+1] + weights[i+2] + weights[i+3] - 1) < 0.001
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			valid = valid and material != null and material.albedo_texture != null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			if material != null and not textures.has(material.albedo_texture):
				textures.append(material.albedo_texture)
	check.call(valid, "Referencia: skin, UV, coordenadas y pesos válidos; materiales opacos")
	check.call(triangles == manifest.triangles and triangles <= 15000 and vertices == manifest.exported_vertices and surfaces == manifest.surfaces, "Referencia: presupuesto real coincide con exportación")
	check.call(textures.size() == 1 and textures[0].get_width() == 1024 and textures[0].get_height() == 1024, "Referencia: atlas compartido 1024")
	var sword := model.weapon as MeshInstance3D
	check.call(sword != null and sword.skin != null and sword.get_node(sword.skeleton) == model.skeleton, "Referencia: espada usa el mismo rig")
	for clip in KaelModel.REQUIRED:
		var ap := model.animation_player
		var animation := ap.get_animation(clip)
		model.reset_pose()
		ap.play(clip, 0)
		ap.advance(0)
		var changing := false
		var finite := true
		var initial: Array[Transform3D] = []
		for bone in range(model.skeleton.get_bone_count()):
			initial.append(model.skeleton.get_bone_pose(bone))
		for fraction in [0.25, 0.5, 0.75, 1.0]:
			ap.seek(animation.length * fraction, true)
			for bone in range(model.skeleton.get_bone_count()):
				var pose := model.skeleton.get_bone_pose(bone)
				finite = finite and pose.is_finite()
				changing = changing or not pose.is_equal_approx(initial[bone])
		check.call(animation.length > 0 and finite and changing, "Referencia: clip con movimiento finito " + clip)
	model.free()
	var previous: Variant = ProjectSettings.get_setting("visuals/kael/asset_version", "0.9")
	ProjectSettings.set_setting("visuals/kael/asset_version", "reference-study")
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	tree.root.add_child(stage)
	await tree.process_frame
	var actor: BattleActorVisual = stage.visuals[0]
	check.call(actor.imported_model != null and actor.imported_model.asset.scene_file_path == CANDIDATE, "Referencia: selector carga candidato en combate")
	var before: Dictionary = preload("res://tests/guardian_checks.gd").new().snapshot(stage.hud.engine)
	for kind in ["physical", "hit", "guard", "knockout"]:
		actor.animate(kind)
	check.call(preload("res://tests/guardian_checks.gd").new().snapshot(stage.hud.engine) == before, "Referencia: presentación no muta combate")
	stage.hud._restart()
	await tree.process_frame
	check.call(stage.visuals[0].imported_model.current_clip == "Idle" and stage.visuals[0].imported_model.asset.scene_file_path == CANDIDATE, "Referencia: reinicio cancela poses y conserva candidato")
	stage.free()
	await tree.process_frame
	var zone = preload("res://scenes/forest_zone.tscn").instantiate()
	zone.session.mission.intro_seen = true
	tree.root.add_child(zone)
	await tree.process_frame
	check.call(zone.player.model.imported_model.asset.scene_file_path == CANDIDATE, "Referencia: exploración carga exactamente el mismo GLB")
	zone.player.set_movement_input(Vector2.RIGHT)
	for i in range(4):
		await tree.physics_frame
	check.call(zone.player.model.imported_model.current_clip == "Walk" and is_equal_approx(zone.player.velocity.x, 4.0), "Referencia: caminar conserva velocidad y reproduce Walk")
	zone.player.set_movement_input(Vector2.ZERO)
	for i in range(4):
		await tree.physics_frame
	check.call(zone.player.model.imported_model.current_clip == "Idle", "Referencia: detenerse vuelve a Idle")
	zone.free()
	ProjectSettings.set_setting("visuals/kael/asset_version", previous)
