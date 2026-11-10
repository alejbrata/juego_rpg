class_name Portraits
extends RefCounted
## Original portraits rendered once per session from the active hero model (HD,
## current or procedural, whichever the game shows), so they always match the 3D
## character and no external image is needed. Without a renderer (headless) the
## HUD keeps the initial emblem.

const SIZE := 160
static var _cache := {}
static var _pending := {}

static func cached(hero_id: String) -> Texture2D:
	return _cache.get(_key(hero_id))

static func _key(hero_id: String) -> String:
	return "%s|%s" % [hero_id, KaelModel.party_style()]

## Renders the portrait (async, about two frames) and returns it, or null.
static func request(host: Node, hero_id: String, data: CombatantData) -> Texture2D:
	var key := _key(hero_id)
	if _cache.has(key):
		return _cache[key]
	if DisplayServer.get_name() == "headless" or RenderingServer.get_rendering_device() == null or _pending.has(key):
		return null
	_pending[key] = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aab8c8")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-25, 35, 0)
	key_light.light_color = Color("fff1dc")
	key_light.light_energy = 1.3
	viewport.add_child(key_light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 200, 0)
	rim.light_color = Color("9fc3ff")
	rim.light_energy = 0.7
	viewport.add_child(rim)
	var actor := BattleActorVisual.new()
	viewport.add_child(actor)
	actor.build(BattleEngine.Fighter.new(data, false))
	actor.set_process(false)
	for helper in [actor.caption, actor.turn_ring, actor.shield, actor.nameplate]:
		if helper != null:
			helper.visible = false
	if actor.imported_model != null:
		actor.imported_model.reset_pose("Idle")
		actor.imported_model.animation_player.pause()
	# Frame the face from the head bone (skinned AABBs do not follow the pose);
	# procedural fallbacks use the top of their static meshes.
	var face := Vector3.ZERO
	var model := actor.imported_model
	if model != null and model.skeleton != null:
		model.skeleton.force_update_all_bone_transforms()
		for bone_name in ["Head", "head", "Head.001"]:
			var bone := model.skeleton.find_bone(bone_name)
			if bone >= 0:
				face = model.skeleton.global_transform * model.skeleton.get_bone_global_pose(bone).origin + Vector3.UP * 0.13
				break
	if face == Vector3.ZERO:
		var top := 0.0
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			if mesh.is_visible_in_tree():
				top = maxf(top, (mesh.global_transform * mesh.get_aabb()).end.y)
		face = Vector3(0, (top if top > 0.5 else 2.0) * 0.88, 0)
	var forward := actor.model_pivot.global_basis.z.normalized() if actor.model_pivot != null else Vector3.BACK
	var camera := Camera3D.new()
	camera.fov = 24
	viewport.add_child(camera)
	camera.position = face + forward * 1.25 + Vector3(0, 0.05, 0)
	camera.look_at(face, Vector3.UP)
	camera.current = true
	await RenderingServer.frame_post_draw
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	_pending.erase(key)
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
