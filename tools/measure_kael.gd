extends SceneTree

# Native glTF parse/scene generation; excludes editor startup and LOD generation.
func _initialize() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.handle_binary_image_mode = GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED
	var start := Time.get_ticks_usec()
	var error := document.append_from_file(KaelModel.ASSET_PATH, state)
	if error != OK:
		printerr("Importación GLB fallida: " + str(error))
		quit(1)
		return
	var scene := document.generate_scene(state)
	var milliseconds := (Time.get_ticks_usec() - start) / 1000.0
	if scene == null:
		quit(1)
		return
	print("Importación nativa GLTFDocument + generate_scene: %.2f ms; excluye editor/LOD; %s" % [milliseconds, DisplayServer.get_name()])
	var textures: Array[Texture2D] = []
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for i in range(mesh.mesh.get_surface_count()):
			var mat := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if mat != null and mat.albedo_texture != null and not textures.has(mat.albedo_texture):
				textures.append(mat.albedo_texture)
	for texture in textures:
		var image := texture.get_image()
		print("Textura: %dx%d; formato Image %d; datos CPU %d bytes; mipmaps %d. No equivale a VRAM medida." % [texture.get_width(), texture.get_height(), image.get_format(), image.get_data_size(), image.get_mipmap_count()])
	scene.free()
	quit()
