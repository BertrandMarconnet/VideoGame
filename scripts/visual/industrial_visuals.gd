extends RefCounted
## Shared, bounded geometry and materials for the Compatibility/Web renderer.
## No external service, runtime download, or extra physics bodies for small details.

var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _textures: Dictionary = {}

func material(color: Color, metallic: float, roughness: float, emission: Color) -> StandardMaterial3D:
	var key := "%s/%.3f/%.3f/%s" % [color.to_html(), metallic, roughness, emission.to_html()]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# A fully metallic surface without a reflection probe reads as black on WebGL.
	mat.metallic = minf(metallic, 0.68)
	mat.roughness = clampf(roughness, 0.24, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.0
	_materials[key] = mat
	return mat

func surface(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind] as StandardMaterial3D
	var palette := {"concrete": Color(0.38, 0.40, 0.37), "floor": Color(0.27, 0.30, 0.29), "steel": Color(0.36, 0.43, 0.44), "paint": Color(0.29, 0.43, 0.40), "rubber": Color(0.16, 0.18, 0.19)}
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palette.get(kind, Color(0.4, 0.42, 0.4))
	mat.albedo_texture = _surface_texture(kind)
	mat.metallic = 0.42 if kind in ["steel", "paint"] else 0.03
	mat.roughness = 0.54 if kind == "steel" else 0.84
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * (0.5 if kind == "floor" else 0.65)
	_materials[kind] = mat
	return mat

func _surface_texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind] as Texture2D
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 1987
	noise.frequency = 0.13
	for y in range(256):
		for x in range(256):
			var value := 0.84 + noise.get_noise_2d(float(x), float(y)) * 0.13
			if kind == "floor":
				if x % 128 < 2 or y % 128 < 2:
					value *= 0.56
				elif x % 128 == 3 or y % 128 == 3:
					value = 0.99
			elif kind in ["steel", "paint"]:
				value += 0.035 * sin(float(y) * 2.8)
				if x < 3 or y < 3:
					value *= 0.54
				for corner in [Vector2(12, 12), Vector2(244, 12), Vector2(12, 244), Vector2(244, 244)]:
					var distance := Vector2(x, y).distance_squared_to(corner)
					if distance < 12.0:
						value = 0.38
					elif distance < 23.0:
						value = 0.96
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_textures[kind] = texture
	return texture

func bevel_box(size: Vector3, amount := 0.06) -> ArrayMesh:
	var radius := minf(amount, minf(size.x, minf(size.y, size.z)) * 0.22)
	var key := "%s/%.4f" % [size, radius]
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var inner := half - Vector3.ONE * radius
	for normal in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var u := Vector3.RIGHT if absf(normal.x) < 0.5 else Vector3.BACK
		var v: Vector3 = normal.cross(u)
		var hu: float = half.dot(u.abs())
		var hv: float = half.dot(v.abs())
		var hn: float = half.dot(normal.abs())
		var us := [-hu, -hu + radius, hu - radius, hu]
		var vs := [-hv, -hv + radius, hv - radius, hv]
		for row in range(3):
			for col in range(3):
				for cell in [Vector2i(col, row), Vector2i(col, row + 1), Vector2i(col + 1, row), Vector2i(col + 1, row), Vector2i(col, row + 1), Vector2i(col + 1, row + 1)]:
					var point: Vector3 = normal * hn + u * us[cell.x] + v * vs[cell.y]
					var closest := point.clamp(-inner, inner)
					var vertex_normal := (point - closest).normalized()
					tool.set_normal(vertex_normal)
					tool.set_uv(Vector2(us[cell.x] / maxf(hu * 2.0, 0.001) + 0.5, vs[cell.y] / maxf(hv * 2.0, 0.001) + 0.5))
					tool.add_vertex(closest + vertex_normal * radius)
	tool.index()
	tool.generate_tangents()
	var mesh := tool.commit()
	_meshes[key] = mesh
	return mesh

func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, label: String, rounded := false) -> MeshInstance3D:
	var shape: Mesh
	if rounded:
		shape = bevel_box(size)
	else:
		var cube := BoxMesh.new()
		cube.size = size
		shape = cube
	return _mesh(parent, shape, at, mat, label)

func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material, label: String, rotation := Vector3.ZERO) -> MeshInstance3D:
	var key := "cylinder/%.3f/%.3f" % [radius, height]
	if not _meshes.has(key):
		var shape := CylinderMesh.new()
		shape.top_radius = radius
		shape.bottom_radius = radius
		shape.height = height
		shape.radial_segments = 16
		shape.rings = 1
		_meshes[key] = shape
	var result := _mesh(parent, _meshes[key], at, mat, label)
	result.rotation_degrees = rotation
	return result

func _mesh(parent: Node3D, shape: Mesh, at: Vector3, mat: Material, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = shape
	node.material_override = mat
	node.position = at
	node.visibility_range_end = 52.0
	parent.add_child(node)
	return node

func wall(parent: Node3D, size: Vector3, at: Vector3, label: String) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.set_meta("size", size)
	body.set_meta("v20_architecture", true)
	parent.add_child(body)
	box(body, size, Vector3.ZERO, surface("concrete"), label + "Mesh").visibility_range_end = 100.0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func sign_board(parent: Node3D, at: Vector3, text_value: String, facing := 0.0, tint := Color(0.75, 0.81, 0.68), board_scale := 1.0) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.y = facing
	root.scale = Vector3.ONE * board_scale
	parent.add_child(root)
	box(root, Vector3(2.3, 0.62, 0.045), Vector3.ZERO, surface("paint"), "SignBack", true)
	var label := Label3D.new()
	label.text = text_value
	label.font_size = 38
	label.pixel_size = 0.0024
	label.position = Vector3(0, 0, 0.03)
	label.modulate = tint
	label.outline_size = 0
	label.no_depth_test = false
	label.visibility_range_end = 35.0
	root.add_child(label)

func poster(parent: Node3D, at: Vector3, index: int, facing := 0.0) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.y = facing
	parent.add_child(root)
	var paper := material(Color(0.80, 0.75, 0.58), 0.0, 0.95, Color.BLACK)
	var ink := material(Color(0.16, 0.24, 0.23), 0.0, 0.9, Color.BLACK)
	box(root, Vector3(0.91, 1.26, 0.012), Vector3.ZERO, paper, "SafetyPoster")
	box(root, Vector3(0.85, 0.25, 0.004), Vector3(0, 0.46, 0.009), ink, "PosterHeader")
	var heading := Label3D.new()
	heading.text = ["SAFETY FIRST", "TOYGUARD", "PERSEUS"][index % 3]
	heading.font_size = 36
	heading.pixel_size = 0.00155
	heading.position = Vector3(0, 0.46, 0.014)
	heading.modulate = Color(0.96, 0.83, 0.54)
	heading.outline_size = 0
	root.add_child(heading)
	var icon := Label3D.new()
	icon.text = ["!", "+", "01"][index % 3]
	icon.font_size = 128
	icon.pixel_size = 0.003
	icon.position = Vector3(0, 0.04, 0.014)
	icon.modulate = Color(0.23, 0.34, 0.3)
	icon.outline_size = 0
	root.add_child(icon)
	var caption := Label3D.new()
	caption.text = ["LOCK OUT BEFORE SERVICE\nEYE PROTECTION REQUIRED", "BUILDING TOMORROW\nSINCE 1964", "RESTRICTED AREA\nREPORT ALL ANOMALIES"][index % 3]
	caption.font_size = 28
	caption.pixel_size = 0.00145
	caption.position = Vector3(0, -0.39, 0.014)
	caption.modulate = Color(0.14, 0.21, 0.2)
	caption.outline_size = 0
	root.add_child(caption)

func drum(parent: Node3D, at: Vector3, label: String) -> void:
	var root := Node3D.new()
	root.name = label
	root.position = at
	parent.add_child(root)
	var paint := surface("paint")
	var steel := surface("steel")
	cylinder(root, 0.32, 0.92, Vector3(0, 0.46, 0), paint, "DrumBody")
	for y in [0.04, 0.3, 0.64, 0.9]:
		cylinder(root, 0.335, 0.025, Vector3(0, y, 0), steel, "DrumRim")
	cylinder(root, 0.045, 0.03, Vector3(0.16, 0.93, 0), steel, "FillCap")
	box(root, Vector3(0.20, 0.2, 0.018), Vector3(0, 0.47, 0.316), material(Color(0.82, 0.62, 0.22), 0.0, 0.8, Color.BLACK), "WarningLabel")

func pump(parent: Node3D, at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "CoolingPump"
	root.position = at
	parent.add_child(root)
	var steel := surface("steel")
	var dark := surface("rubber")
	box(root, Vector3(1.5, 0.14, 0.92), Vector3(0, 0.07, 0), steel, "PumpBase", true)
	cylinder(root, 0.31, 0.94, Vector3(0, 0.49, 0), surface("paint"), "Motor", Vector3(0, 0, 90))
	for x in [-0.34, -0.2, -0.06, 0.08, 0.22, 0.36]:
		cylinder(root, 0.335, 0.035, Vector3(x, 0.49, 0), dark, "CoolingFin", Vector3(0, 0, 90))
	cylinder(root, 0.14, 1.8, Vector3(0.55, 0.9, 0), steel, "Riser")
	cylinder(root, 0.22, 0.065, Vector3(0.55, 1.22, 0), dark, "Flange")
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.15
	wheel.outer_radius = 0.2
	wheel.rings = 16
	wheel.ring_segments = 6
	_mesh(root, wheel, Vector3(0.55, 1.83, 0), material(Color(0.6, 0.16, 0.08), 0.3, 0.62, Color.BLACK), "ValveWheel")
	box(root, Vector3(0.36, 0.025, 0.028), Vector3(0.55, 1.83, 0), steel, "ValveSpoke")

func cabinet(parent: Node3D, at: Vector3, facing: float) -> void:
	var root := Node3D.new()
	root.name = "ElectricalCabinet"
	root.position = at
	root.rotation_degrees.y = facing
	parent.add_child(root)
	var steel := surface("steel")
	box(root, Vector3(0.85, 1.8, 0.34), Vector3(0, 0.9, 0), surface("paint"), "CabinetBody", true)
	box(root, Vector3(0.76, 1.67, 0.045), Vector3(0, 0.9, 0.19), steel, "CabinetDoor", true)
	box(root, Vector3(0.035, 0.18, 0.04), Vector3(0.27, 0.94, 0.23), surface("rubber"), "CabinetHandle")
	for index in range(5):
		box(root, Vector3(0.48, 0.018, 0.015), Vector3(0, 0.34 + index * 0.046, 0.22), surface("rubber"), "VentSlot")

func build_factory_detail(scene: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "IndustrialVisualsV20"
	scene.add_child(root)
	# Four service corridors link existing open production sectors. Door apertures
	# keep the old +/-4 m circulation lanes and the robots' patrol route available.
	for section in [{"z": -22.5, "length": 6.0, "name": "01  LOGISTICS"}, {"z": -58.0, "length": 5.0, "name": "02  ASSEMBLY"}, {"z": -92.0, "length": 5.0, "name": "03  ARCHIVES"}, {"z": -126.0, "length": 5.0, "name": "04  FOUNDRY"}]:
		var z := float(section["z"])
		var length := float(section["length"])
		var sector := Node3D.new()
		sector.name = "ServiceCorridor_%d" % absi(int(z))
		root.add_child(sector)
		for side in [-1.0, 1.0]:
			wall(sector, Vector3(0.24, 3.65, length), Vector3(side * 4.2, 1.825, z), "CorridorWall")
			box(sector, Vector3(0.045, 0.8, length), Vector3(side * 4.05, 0.6, z), surface("paint"), "WallWainscot")
			box(sector, Vector3(0.05, 0.065, length), Vector3(side * 4.02, 1.05, z), surface("steel"), "WallRail")
			cylinder(sector, 0.1, length, Vector3(side * 3.8, 3.13, z), surface("steel"), "OverheadPipe", Vector3(90, 0, 0))
			poster(sector, Vector3(side * 4.045, 2.1, z), absi(int(z)) % 3, -90.0 * side)
		wall(sector, Vector3(8.64, 0.16, length), Vector3(0, 3.73, z), "CorridorCeiling")
		for end in [-1.0, 1.0]:
			var end_z: float = z + end * length * 0.5
			for side in [-1.0, 1.0]:
				box(sector, Vector3(0.18, 3.65, 0.22), Vector3(side * 4.05, 1.82, end_z), surface("steel"), "DoorJamb")
			box(sector, Vector3(8.1, 0.25, 0.22), Vector3(0, 3.52, end_z), surface("steel"), "Lintel")
		sign_board(sector, Vector3(0, 3.2, z + length * 0.5 + 0.14), String(section["name"]))
		box(sector, Vector3(2.4, 0.08, 0.22), Vector3(0, 3.57, z), material(Color(0.78, 0.86, 0.82), 0.0, 0.8, Color(0.6, 0.72, 0.66)), "CorridorLuminaire")
		for side in [-1.0, 1.0]:
			box(sector, Vector3(0.06, 0.008, length), Vector3(side * 3.2, 0.012, z), material(Color(0.7, 0.53, 0.19), 0.0, 0.9, Color.BLACK), "RouteStripe")
	# Small equipment lives in the wall strip; it cannot obstruct a walkable lane.
	for index in range(9):
		var z := -28.0 - float(index) * 15.0
		var side := -1.0 if index % 2 == 0 else 1.0
		var sector := Node3D.new()
		sector.name = "WallEquipment_%d" % index
		root.add_child(sector)
		cabinet(sector, Vector3(side * 16.36, 0, z), -90.0 * side)
		poster(sector, Vector3(-side * 16.6, 2.35, z + 2.0), index, 90.0 * side)
		pump(sector, Vector3(side * 15.65, 0, z - 2.7))
		drum(sector, Vector3(side * 15.8, 0, z + 3.1), "MaintenanceDrum")
	# The added static hardware is merged by material and sector for Web draw calls.
	for sector in root.get_children():
		_merge_details(sector as Node3D)
	return root

func _merge_details(root: Node3D) -> void:
	var groups: Dictionary = {}
	for candidate in root.find_children("*", "MeshInstance3D", true, false):
		var node := candidate as MeshInstance3D
		if node.get_parent() is StaticBody3D:
			continue
		var mat := node.material_override
		if mat == null:
			continue
		if not groups.has(mat):
			groups[mat] = []
		groups[mat].append(node)
	for mat in groups:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node: MeshInstance3D in groups[mat]:
			var transform := root.global_transform.affine_inverse() * node.global_transform
			tool.append_from(node.mesh, 0, transform)
			node.queue_free()
		tool.set_material(mat)
		_mesh(root, tool.commit(), Vector3.ZERO, mat, "BatchedHardware")

func polish_imported(scene: Node3D) -> void:
	# Preserve every authored transform, skin, animation track and damage node.
	for candidate in scene.find_children("*", "MeshInstance3D", true, false):
		var node := candidate as MeshInstance3D
		if node.mesh == null or node.has_meta("v20_materials"):
			continue
		node.set_meta("v20_materials", true)
		for index in range(node.mesh.get_surface_count()):
			var mat := node.get_active_material(index) as StandardMaterial3D
			if mat == null:
				continue
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.metallic = minf(mat.metallic, 0.68)
			if mat.emission_enabled:
				mat.emission_energy_multiplier = minf(mat.emission_energy_multiplier, 1.4)
