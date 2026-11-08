extends RefCounted

func run(tree: SceneTree, check: Callable) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/kael/kael_manifest.json"))
	check.call(FileAccess.get_sha256("res://tools/blender/kael_art.py") == manifest.art_script_sha256, "Arte reproducible coincide con manifiesto")
	check.call(FileAccess.get_sha256("res://assets/characters/kael/kael_atlas.png") == manifest.atlas_sha256, "Atlas editable coincide con exportación")
	check.call(FileAccess.get_sha256("res://assets/characters/kael/v08/kael.blend") == manifest.source_v08_sha256, "Rig fuente 0.8 conservado sin cambios")
	var current := KaelModel.new()
	var previous := KaelModel.new()
	tree.root.add_child(current)
	tree.root.add_child(previous)
	check.call(current.load_asset() and previous.load_asset("res://assets/characters/kael/v08/kael.glb"), "Ambos GLB disponibles para comparación explícita")
	var same_rest := current.skeleton.get_bone_count() == previous.skeleton.get_bone_count()
	for i in range(current.skeleton.get_bone_count()):
		same_rest = same_rest and current.skeleton.get_bone_name(i) == previous.skeleton.get_bone_name(i) and current.skeleton.get_bone_rest(i).is_equal_approx(previous.skeleton.get_bone_rest(i))
	check.call(same_rest, "Contrato y reposo del esqueleto 0.8 preservados")
	for clip in KaelModel.REQUIRED:
		var a := current.animation_player.get_animation(clip)
		var b := previous.animation_player.get_animation(clip)
		var same := is_equal_approx(a.length, b.length) and a.get_track_count() == b.get_track_count()
		for track in range(a.get_track_count()):
			same = same and a.track_get_path(track) == b.track_get_path(track) and a.track_get_key_count(track) == b.track_get_key_count(track)
			for key in range(a.track_get_key_count(track)):
				same = same and a.track_get_key_value(track, key) == b.track_get_key_value(track, key)
		check.call(same, "Clip original preservado: " + clip)
	var surfaces := 0
	var triangles := 0
	var vertices := 0
	var materials: Array[Material] = []
	var valid := true
	var textures: Array[Texture2D] = []
	for mesh: MeshInstance3D in current.asset.find_children("*", "MeshInstance3D", true, false):
		valid = valid and mesh.skin != null and mesh.get_node(mesh.skeleton) == current.skeleton
		surfaces += mesh.mesh.get_surface_count()
		for surface in range(mesh.mesh.get_surface_count()):
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
			if not materials.has(material):
				materials.append(material)
			if not textures.has(material.albedo_texture):
				textures.append(material.albedo_texture)
	check.call(valid, "Mallas finitas, UV completos, pesos normalizados, materiales opacos texturados y skin válido")
	check.call(surfaces == 4 and materials.size() == 2, "Dos materiales compartidos y cuatro superficies sustituyen las 17 anteriores")
	check.call(textures.size() == 1 and textures[0].get_width() == 1024 and textures[0].get_height() == 1024, "Un atlas 1024 compartido entre cuerpo y espada")
	check.call(triangles == manifest.exported_triangles and triangles <= 12000 and vertices == manifest.exported_vertices, "Presupuesto medido sobre geometría importada coincide con GLB")
	var file := FileAccess.open(KaelModel.ASSET_PATH, FileAccess.READ)
	file.seek(12)
	var length := file.get_32()
	file.get_32()
	var gltf: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	check.call(gltf.images.size() == 1 and gltf.images[0].has("bufferView") and not gltf.images[0].has("uri") and not gltf.buffers[0].has("uri"), "GLB incluye textura y buffer sin rutas externas")
	current.free()
	previous.free()
	var version: Variant = ProjectSettings.get_setting("visuals/kael/asset_version", "0.9")
	ProjectSettings.set_setting("visuals/kael/asset_version", "0.8")
	var stage = preload("res://scenes/battle_3d.tscn").instantiate()
	tree.root.add_child(stage)
	await tree.process_frame
	check.call(stage.visuals[0].imported_model.asset.scene_file_path.ends_with("/v08/kael.glb"), "Selector global permite comparar el GLB 0.8 en batalla")
	stage.free()
	var player = preload("res://world/exploration_player.gd").new()
	tree.root.add_child(player)
	await tree.process_frame
	check.call(player.model.imported_model.asset.scene_file_path.ends_with("/v08/kael.glb"), "Selector global permite comparar el GLB 0.8 en exploración")
	player.free()
	ProjectSettings.set_setting("visuals/kael/asset_version", version)
