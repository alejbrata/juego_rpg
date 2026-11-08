class_name StylizedModels
extends RefCounted

static var _materials: Dictionary[String, StandardMaterial3D] = {}

# Native, original low-poly geometry. No imported meshes, textures or runtime AI.
static func mat(hex: String, glow: bool = false) -> StandardMaterial3D:
	var key := hex + ("_glow" if glow else "")
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(hex)
	result.roughness = 0.85
	if glow:
		result.emission_enabled = true
		result.emission = Color(hex)
		result.emission_energy_multiplier = 0.65
	_materials[key] = result
	return result

static func batch_static(parent: Node3D, exclude: Array[Node3D] = []) -> void:
	# Merge only immutable geometry by material. Keep animated weapons/capes as
	# nodes. Vertex normals are transformed explicitly; no textures are required.
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(parent, exclude, meshes)
	var groups: Dictionary = {}
	for mesh in meshes:
		var material: Material = mesh.material_override
		var key := material.get_instance_id()
		if not groups.has(key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"surface": surface, "material": material}
		var transform := parent.global_transform.affine_inverse() * mesh.global_transform
		var normal_basis := transform.basis.inverse().transposed()
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(count):
			var index := indices[i] if not indices.is_empty() else i
			groups[key].surface.set_normal((normal_basis * normals[index]).normalized())
			groups[key].surface.add_vertex(transform * vertices[index])
		mesh.get_parent().remove_child(mesh)
		mesh.queue_free()
	for group in groups.values():
		var merged := BattleActorVisual._mesh(parent, group.surface.commit(), Vector3.ZERO, group.material)
		merged.name = "GeometryBatch"
	parent.set_meta("source_mesh_count", meshes.size())

static func _collect_meshes(parent: Node3D, exclude: Array[Node3D], result: Array[MeshInstance3D]) -> void:
	for child in parent.get_children():
		if not child is Node3D:
			continue
		if exclude.has(child):
			continue
		if child is MeshInstance3D:
			result.append(child)
		elif child is Node3D:
			_collect_meshes(child, exclude, result)

static func rock(parent: Node3D, at: Vector3, size: Vector3, material: Material, seed_value: int = 0) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 7
	var rings := 4
	for ring in range(rings):
		for segment in range(segments):
			var points: Array[Vector3] = []
			for ij in [Vector2i(ring, segment), Vector2i(ring, segment + 1), Vector2i(ring + 1, segment), Vector2i(ring + 1, segment + 1)]:
				var phi := PI * float(ij.x) / rings
				var theta := TAU * float(ij.y) / segments + 0.13 * sin(ij.x * 3.0 + seed_value)
				var uneven := 1.0 + 0.08 * sin((ij.y % segments) * 2.7 + ij.x * 1.3 + seed_value)
				points.append(Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * size * 0.5 * uneven)
			for tri in [[0, 1, 2], [1, 3, 2]]:
				var normal := (points[tri[1]] - points[tri[0]]).cross(points[tri[2]] - points[tri[0]]).normalized()
				# Godot treats clockwise winding as the front face; keep the
				# explicitly calculated outward normal while reversing vertices.
				for index in [tri[0], tri[2], tri[1]]:
					surface.set_normal(normal)
					surface.add_vertex(points[index])
	return BattleActorVisual._mesh(parent, surface.commit(), at, material)

static func rod(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = from.distance_to(to)
	cylinder.radial_segments = 7
	var mesh := BattleActorVisual._mesh(parent, cylinder, (from + to) * 0.5, material)
	mesh.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	return mesh

static func gem(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var prism := PrismMesh.new()
	prism.size = size
	var result := BattleActorVisual._mesh(parent, prism, at, material)
	result.rotation.z = PI
	return result

static func ring(parent: Node3D, at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius * 0.88
	shape.outer_radius = radius
	shape.rings = 24
	shape.ring_segments = 6
	return BattleActorVisual._mesh(parent, shape, at, material)

static func hero(parent: Node3D, id: String, cloth: Material) -> Dictionary:
	var skin := mat("e6bc99")
	var leather := mat("574139")
	var metal := mat("9faeb1")
	var gold := mat("c4a46b")
	var hair := mat("51382c" if id == "kael" else ("383047" if id == "lyra" else "aa6745"))
	var dark := mat("232c37")
	var cream := mat("e0d4b5")
	var width := 1.12 if id == "kael" else (0.86 if id == "lyra" else 0.93)
	for side in [-1, 1]:
		rock(parent, Vector3(side * 0.18, 0.48, 0), Vector3(0.25, 0.7, 0.3), dark if id != "nira" else cream, side)
		rock(parent, Vector3(side * 0.19, 0.17, 0.075), Vector3(0.31, 0.35, 0.49), leather, side + 3)
	rock(parent, Vector3(0, 1.12, 0), Vector3(0.76 * width, 0.76, 0.49), cloth)
	BattleActorVisual._box(parent, Vector3(0.68 * width, 0.1, 0.49), Vector3(0, 0.91, 0), leather)
	BattleActorVisual._box(parent, Vector3(0.13, 0.12, 0.04), Vector3(0, 0.91, 0.26), gold)
	for side in [-1, 1]:
		rod(parent, Vector3(side * 0.36 * width, 1.36, 0), Vector3(side * 0.49 * width, 1.03, 0.03), 0.12 if id != "kael" else 0.15, cloth)
		rod(parent, Vector3(side * 0.49 * width, 1.03, 0.03), Vector3(side * 0.52 * width, 0.81, 0.15), 0.095, leather if id == "kael" else cream)
		rock(parent, Vector3(side * 0.52 * width, 0.81, 0.15), Vector3(0.18, 0.22, 0.2), skin)
	rod(parent, Vector3(0, 1.44, 0), Vector3(0, 1.67, 0), 0.12, skin)
	rock(parent, Vector3(0, 1.8, 0), Vector3(0.53, 0.57, 0.47), skin)
	rock(parent, Vector3(0, 1.99, -0.035), Vector3(0.58, 0.3, 0.51), hair)
	for side in [-1, 1]:
		rock(parent, Vector3(side * 0.255, 1.8, 0), Vector3(0.12, 0.19, 0.13), skin)
		BattleActorVisual._box(parent, Vector3(0.115, 0.075, 0.035), Vector3(side * 0.11, 1.83, 0.218), cream)
		BattleActorVisual._box(parent, Vector3(0.045, 0.065, 0.035), Vector3(side * 0.105, 1.83, 0.241), dark)
		var brow := BattleActorVisual._box(parent, Vector3(0.125, 0.035, 0.04), Vector3(side * 0.11, 1.9, 0.23), hair)
		brow.rotation.z = side * (0.12 if id == "kael" else -0.05)
	rock(parent, Vector3(0, 1.76, 0.24), Vector3(0.09, 0.1, 0.09), skin)
	BattleActorVisual._box(parent, Vector3(0.095, 0.018, 0.025), Vector3(0, 1.675, 0.21), leather)
	var cape: Node3D = null
	var weapon := Node3D.new()
	weapon.position = Vector3(0.54 * width, 0.84, 0.17)
	parent.add_child(weapon)
	if id == "kael":
		for side in [-1, 1]:
			rock(parent, Vector3(side * 0.4, 1.37, 0), Vector3(0.39, 0.27, 0.55), metal)
			gem(parent, Vector3(side * 0.14, 2.1, 0), Vector3(0.25, 0.3, 0.3), hair).rotation.z = side * 0.4
		rock(parent, Vector3(0, 1.18, 0.2), Vector3(0.54, 0.45, 0.18), metal)
		rod(weapon, Vector3(0, -0.15, 0), Vector3(0, 0.2, 0), 0.06, leather)
		BattleActorVisual._box(weapon, Vector3(0.4, 0.08, 0.12), Vector3(0, 0.2, 0), gold)
		gem(weapon, Vector3(0, 0.72, 0), Vector3(0.18, 0.95, 0.08), metal).rotation.z = 0
	else:
		cape = _cape(parent, cloth if id == "lyra" else mat("638268"), gold if id == "lyra" else cream)
		for side in [-1, 1]:
			rock(parent, Vector3(side * 0.2, 0.75, -0.04), Vector3(0.43, 0.55, 0.48), cloth if id == "lyra" else cream)
			rock(parent, Vector3(side * 0.22, 1.78 if id == "lyra" else 1.91, -0.1), Vector3(0.24, 0.75 if id == "lyra" else 0.36, 0.33), hair)
		rod(parent, Vector3(-0.28, 1.46, 0.13), Vector3(0, 1.2, 0.28), 0.025, gold if id == "lyra" else cream)
		rod(parent, Vector3(0.28, 1.46, 0.13), Vector3(0, 1.2, 0.28), 0.025, gold if id == "lyra" else cream)
		if id == "lyra":
			gem(parent, Vector3(0, 1.98, 0.22), Vector3(0.13, 0.2, 0.08), gold)
			gem(parent, Vector3(0, 1.2, 0.29), Vector3(0.12, 0.18, 0.08), mat("7abfc5", true))
			rod(weapon, Vector3(0, -0.5, 0), Vector3(0, 1.12, 0), 0.045, leather)
			var halo := ring(weapon, Vector3(0, 1.23, 0), 0.2, gold)
			halo.rotation.x = PI * 0.5
			gem(weapon, Vector3(0, 1.23, 0), Vector3(0.18, 0.34, 0.14), mat("aeb5ee", true))
		else:
			rock(parent, Vector3(0, 1.73, -0.27), Vector3(0.37, 0.47, 0.37), hair)
			gem(parent, Vector3(0.22, 2.07, 0.05), Vector3(0.17, 0.26, 0.08), cloth).rotation.z = -0.5
			rod(weapon, Vector3(0, -0.3, 0), Vector3(0, 0.75, 0), 0.055, leather)
			for side in [-1, 1]:
				rod(weapon, Vector3(0, 0.47, 0), Vector3(side * 0.17, 0.83, 0), 0.03, leather)
				rock(weapon, Vector3(side * 0.17, 0.75, 0), Vector3(0.22, 0.11, 0.09), cloth).rotation.z = side * 0.4
			gem(weapon, Vector3(0, 0.8, 0), Vector3(0.14, 0.24, 0.13), mat("a8db9d", true))
	var moving_parts: Array[Node3D] = [weapon]
	if cape != null:
		moving_parts.append(cape)
	batch_static(parent, moving_parts)
	return {"weapon": weapon, "cape": cape}

static func _cape(parent: Node3D, material: Material, trim: Material) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0, 1.48, -0.2)
	parent.add_child(root)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(-0.29, 0, 0), Vector3(0.29, 0, 0), Vector3(-0.61, -1, -0.22), Vector3(0, -1.08, -0.35), Vector3(0.61, -1, -0.22)]
	for tri in [[0, 2, 3], [0, 3, 1], [1, 3, 4]]:
		for index in tri:
			mesh.add_vertex(points[index])
	mesh.generate_normals()
	var double_sided := material.duplicate() as StandardMaterial3D
	double_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	BattleActorVisual._mesh(root, mesh.commit(), Vector3.ZERO, double_sided)
	rod(root, points[0], points[2], 0.022, trim)
	rod(root, points[1], points[4], 0.022, trim)
	return root

static func golem(parent: Node3D, stone: Material, volcanic: bool = false) -> void:
	var glow := mat("ed9c45" if not volcanic else "ff9a36", true)
	var crack := mat("6da09b" if not volcanic else "ee652b", true)
	var dark := mat("283c3d" if not volcanic else "302c32")
	for side in [-1, 1]:
		rock(parent, Vector3(side * 0.4, 0.24, 0.12), Vector3(0.7, 0.48, 0.92), stone, side)
		rock(parent, Vector3(side * 0.37, 0.66, 0), Vector3(0.56, 0.75, 0.6), stone, side + 2)
		rock(parent, Vector3(side * 0.96, 1.7, -0.02), Vector3(0.83, 0.83, 0.85), stone, side + 4)
		rock(parent, Vector3(side * 1.13, 1.13, 0.05), Vector3(0.68, 0.95, 0.68), stone, side + 6)
		rock(parent, Vector3(side * 1.14, 0.78, 0.17), Vector3(0.75, 0.55, 0.75), stone, side + 1)
		rod(parent, Vector3(side * 0.78, 1.6, 0.33), Vector3(side * 1.13, 1.16, 0.37), 0.035, crack)
	rock(parent, Vector3(0, 1.46, 0), Vector3(1.5, 1.45, 1.05), stone, 5)
	rock(parent, Vector3(0, 2.14, 0.05), Vector3(0.85, 0.7, 0.75), stone, 2)
	for side in [-1, 1]:
		rock(parent, Vector3(side * 0.2, 2.16, 0.37), Vector3(0.3, 0.2, 0.12), dark)
		BattleActorVisual._box(parent, Vector3(0.18, 0.065, 0.04), Vector3(side * 0.19, 2.17, 0.435), glow).rotation.z = side * 0.12
	gem(parent, Vector3(0, 1.53, 0.53), Vector3(0.31, 0.45, 0.12), crack)
	for a in [-1, 1]:
		rod(parent, Vector3(0, 1.35, 0.53), Vector3(a * 0.43, 1.14, 0.43), 0.025, crack)
		rod(parent, Vector3(a * 0.23, 1.8, 0.43), Vector3(a * 0.55, 1.99, 0.29), 0.025, crack)
	if volcanic:
		for side in [-1, 1]:
			gem(parent, Vector3(side * 0.47, 2.6, -0.04), Vector3(0.4, 1.25, 0.45), stone).rotation.z = -side * 0.4
			gem(parent, Vector3(side * 0.94, 2.12, -0.1), Vector3(0.4, 0.8, 0.5), stone).rotation.z = -side * 0.7
	else:
		var moss := mat("5b7454")
		for at in [Vector3(-0.84, 1.99, 0), Vector3(0.35, 2.43, -0.07), Vector3(0.3, 0.43, 0.28)]:
			rock(parent, at, Vector3(0.5, 0.14, 0.36), moss)
	batch_static(parent)
