extends RefCounted

var _tree: SceneTree
var _verify: Callable

const ANCHORS := {
	"camp": [Vector3(-4.5, 0, 2), 1.6],
	"crystal": [Vector3(3.1, 0, -.5), 1.5],
	"inscription": [Vector3(-2.4, 0, -2.2), 1.7],
	"anomaly": [Vector3(0, 0, -2.9), 1.7],
}

func check(condition: bool, description: String) -> void:
	_verify.call(condition, "Bosque: " + description)

func collider_snapshot(zone: Node3D) -> Array[String]:
	var result: Array[String] = []
	for body: StaticBody3D in zone.find_children("*", "StaticBody3D", true, false):
		var shapes := body.find_children("*", "CollisionShape3D", true, false)
		for collider: CollisionShape3D in shapes:
			var size: Vector3 = collider.shape.size if collider.shape is BoxShape3D else Vector3.INF
			# Auto-generated node names depend on allocation order and are not a
			# gameplay contract. World transform, dimensions and masks are.
			result.append(str(collider.global_transform) + "|" + str(size) + "|%d|%d|%s" % [body.collision_layer, body.collision_mask, collider.disabled])
	result.sort()
	return result

func expected_colliders() -> Array[String]:
	var definitions := [
		[Vector3(0, -.2, 0), Vector3(18, .4, 14)],
		[Vector3(-8.75, .45, 0), Vector3(.5, .9, 14)],
		[Vector3(8.75, .45, 0), Vector3(.5, .9, 14)],
		[Vector3(0, .45, -6.75), Vector3(18, .9, .5)],
		[Vector3(0, .45, 6.75), Vector3(18, .9, .5)],
		[Vector3(-1.3, .45, 4.8), Vector3(1.2, .9, .9)],
		[Vector3(4.3, .55, 3.3), Vector3(1, 1.1, 1.2)],
		[Vector3(-2.7, .9, -1.5), Vector3(.65, 1.8, .65)],
		[Vector3(2.1, .9, -1.5), Vector3(.65, 1.8, .65)],
	]
	for at in [Vector3(-7, 1.1, -4.5), Vector3(-7.4, 1.1, 0), Vector3(-7.3, 1.1, 4.8), Vector3(-3.5, 1.1, -4.7), Vector3(0, 1.1, -5), Vector3(3.4, 1.1, -5.2), Vector3(7.1, 1.1, -4.6), Vector3(7.2, 1.1, 0), Vector3(7.2, 1.1, 4.7)]:
		definitions.append([at, Vector3(.5, 2.2, .5)])
	var result: Array[String] = []
	for definition: Array in definitions:
		result.append(str(Transform3D(Basis.IDENTITY, definition[0])) + "|" + str(definition[1]) + "|1|0|false")
	result.sort()
	return result

func on_screen(camera: Camera3D, point: Vector3, aspect: float, margin: float) -> bool:
	# Same projection Godot builds for KEEP_HEIGHT cameras at this aspect ratio.
	var projection := Projection.create_perspective(camera.fov, aspect, camera.near, camera.far)
	var view := camera.global_transform.affine_inverse() * point
	var clip := projection * Vector4(view.x, view.y, view.z, 1.0)
	if clip.w <= 0.0:
		return false
	return absf(clip.x / clip.w) < 1.0 - margin and absf(clip.y / clip.w) < 1.0 - margin

func make_zone(renovated: bool) -> Node3D:
	ProjectSettings.set_setting("visuals/forest/renovated", renovated)
	var zone = preload("res://scenes/forest_zone.tscn").instantiate()
	zone.session.mission.intro_seen = true
	_tree.root.add_child(zone)
	return zone

func walk_to(zone: Node3D, target: Vector2) -> bool:
	# Every segment starts at the physical result of the preceding segment.
	# No teleportation, collider changes, speed changes or navigation bypass.
	for frame in range(360):
		var current := Vector2(zone.player.position.x, zone.player.position.z)
		if current.distance_to(target) < .14:
			zone.player.set_movement_input(Vector2.ZERO)
			await _tree.physics_frame
			return zone.player.is_on_floor() and absf(zone.player.position.y) < .15
		zone.player.set_movement_input((target - current).normalized())
		await _tree.physics_frame
	zone.player.set_movement_input(Vector2.ZERO)
	return false

func finish_dialogue(zone: Node3D) -> bool:
	var remaining := 30
	while zone.dialogue.active and remaining > 0:
		remaining -= 1
		zone.dialogue.advance()
	zone.encounter_armed = false
	return remaining > 0 and not zone.dialogue.active

func run(tree: SceneTree, verify: Callable) -> void:
	_tree = tree
	_verify = verify
	var previous: Variant = ProjectSettings.get_setting("visuals/forest/renovated", false)
	var original_size := tree.root.size
	tree.root.size = Vector2i(960, 640)
	var legacy := make_zone(false)
	await tree.process_frame
	check(collider_snapshot(legacy) == expected_colliders(), "fallback conserva los 18 colliders originales")
	var legacy_camera: Camera3D = legacy.get_node("ForestCamera")
	check(legacy_camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(legacy_camera.size, 18) and legacy_camera.position.is_equal_approx(Vector3(0, 17, 18)), "fallback conserva cámara original")
	check(legacy.get_node_or_null("ForestArt") == null, "selector desactivado conserva presentación anterior")
	legacy.free()
	var zone := make_zone(true)
	await tree.process_frame
	check(collider_snapshot(zone) == expected_colliders(), "renovación mantiene transformaciones, dimensiones y máscaras físicas")
	check(zone.encounters.size() == 2 and zone.encounters[0].map_position == Vector3(0, 0, 1) and zone.encounters[1].map_position == Vector3(5, 0, -2.8) and is_equal_approx(zone.encounters[0].detection_radius, 1) and is_equal_approx(zone.encounters[1].detection_radius, 1), "centinelas conservan anclas y radios de encuentro")
	check(zone.interests.size() == ANCHORS.size(), "cuatro puntos narrativos, sin nuevos elementos funcionales")
	for id: String in ANCHORS:
		var point: NarrativeInterest = zone.interests[id]
		check(point.position == ANCHORS[id][0] and is_equal_approx(point.interaction_radius, ANCHORS[id][1]), "posición y alcance originales de " + id)
	check(not zone.interests.anomaly.visible and not zone.interests.anomaly.available, "decoración de la anomalía permanece oculta sin requisitos")
	var camera: Camera3D = zone.get_node("ForestCamera")
	# Moderate framing change (perspective, higher): screen axes still match the
	# world-aligned WASD/touch movement, and the camera stays fixed.
	check(camera.current and camera.projection == Camera3D.PROJECTION_PERSPECTIVE and camera.basis.x.dot(Vector3.RIGHT) > .999 and absf(camera.basis.z.x) < .001, "cámara fija conserva ejes de control")
	# Projection checked per aspect ratio (headless viewports keep the base size):
	# 960x640, 16:9 (1280x720 / 800x450), 4:3 tablets and 20:9 phones.
	for aspect in [1.5, 16.0 / 9.0, 4.0 / 3.0, 20.0 / 9.0]:
		var inside := true
		# Gameplay anchors plus the four corners the player can physically reach.
		for position in [GameSession.SPAWN, Vector3(0, 0, 1), Vector3(5, 0, -2.8), Vector3(-2.4, 0, -2.2), Vector3(3.1, 0, -.5), Vector3(0, 0, -2.9), Vector3(-8.1, 0, -6.1), Vector3(8.1, 0, -6.1), Vector3(-8.1, 0, 6.1), Vector3(8.1, 0, 6.1)]:
			for height in [0.0, 1.8]:
				inside = inside and on_screen(camera, position + Vector3.UP * height, aspect, .02)
		check(inside, "zona transitable completa y anclas en encuadre (aspecto %.2f)" % aspect)
	check(zone.player.model.imported_model.asset.scene_file_path == "res://assets/characters/kael/retro/kael.glb" and is_equal_approx(zone.player.movement_speed, 4), "Kael y velocidad de exploración conservados")
	var art: ForestArt = zone.get_node("ForestArt")
	check(art.find_children("*", "CollisionObject3D", true, false).is_empty(), "el arte no añade cuerpos físicos ni áreas")
	# Narrative props follow ExpeditionStory anchors; the legacy boxes are not doubled.
	for prop: String in ForestArt.NARRATIVE_PROPS:
		var id: String = ForestArt.NARRATIVE_PROPS[prop]
		var node := art.get_node_or_null(prop) as Node3D
		check(node != null and node.position.is_equal_approx(zone.interests[id].position), "prop renovado anclado al punto narrativo " + id)
		check(zone.interests[id].find_children("*", "MeshInstance3D", true, false).size() <= (3 if id == "crystal" else 1), "sin primitivas provisionales duplicadas en " + id)
	check(zone.interests.crystal._energy != null and zone.interests.anomaly._energy != null, "cristal y anomalía conservan su energía animada")
	# Hero crowns can cover reachable edges from the fixed camera: the see-through
	# must follow the player, otherwise Kael disappears under the canopy.
	zone.player.position = Vector3(-7.9, .05, -2.2)
	await tree.process_frame
	var reveal: ShaderMaterial = art._reveal
	var target: Vector3 = reveal.get_shader_parameter("reveal_target")
	check(Vector2(target.x, target.z).is_equal_approx(Vector2(zone.player.global_position.x, zone.player.global_position.z)) and absf(target.y - zone.player.global_position.y - .9) < .2 and float(reveal.get_shader_parameter("reveal_radius")) > 1.0 and (reveal.get_shader_parameter("reveal_camera") as Vector3).is_equal_approx(camera.global_position), "transparencia de copas sigue a Kael desde la cámara real")
	var revealed := 0
	for instance in art.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = instance.mesh if instance is MeshInstance3D else (instance.multimesh.mesh if instance is MultiMeshInstance3D else null)
		if mesh != null and mesh.get_surface_count() > 1 and mesh.surface_get_material(1) == reveal:
			revealed += 1
	check(revealed >= 7, "copas principales usan el material con transparencia (%d)" % revealed)
	zone.player.position = GameSession.SPAWN
	# Mobile budget guard (measured, not a device test): instancing must hold.
	check(art.stats.triangles < 320000 and art.stats.surfaces < 90 and art.stats.multimeshes >= 20, "presupuesto: %d triángulos, %d superficies, %d multimeshes" % [art.stats.triangles, art.stats.surfaces, art.stats.multimeshes])
	await tree.physics_frame
	var requests: Array[String] = []
	zone.encounter_requested.connect(func(encounter: EncounterData): requests.append(encounter.id))
	zone.encounter_armed = false
	for step: Dictionary in [
		{"at": Vector2(-4.5, 2.9), "clue": "camp"},
		{"at": Vector2(-4.3, -2.8)},
		{"at": Vector2(-2.4, -2.8), "clue": "inscription"},
		{"at": Vector2(0, -2.9)},
		{"at": Vector2(0, -.1)},
		{"at": Vector2(3.1, -.5), "clue": "crystal"},
		{"at": Vector2(5, -2.8)},
		{"at": Vector2(0, 1)},
	]:
		var reached := await walk_to(zone, step.at)
		check(reached, "recorrido físico sin bloqueo hasta " + str(step.at))
		if not reached:
			break
		if step.has("clue"):
			check(zone.interests[step.clue].in_range(zone.player.position) and zone.interact(step.clue), "pista accesible tras caminar: " + step.clue)
			check(finish_dialogue(zone), "interacción termina y restaura movimiento: " + step.clue)
	check(zone.session.mission.all_clues() and requests.is_empty() and zone.session.defeated_encounters.is_empty() and zone.session.party.resonance == 0 and zone.session.party.progress("ignar").affinity == 0, "recorrido investiga tres pistas sin simular victorias ni alterar progresión")
	zone.free()
	tree.root.size = original_size
	ProjectSettings.set_setting("visuals/forest/renovated", previous)
