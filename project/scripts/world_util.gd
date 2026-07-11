class_name WorldUtil
extends RefCounted

static func material(color: Color, metallic: float = 0.0, roughness: float = 0.72, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat

static func box_mesh(size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	node.mesh = mesh
	return node

static func cylinder_mesh(radius: float, height: float, mat: Material, segments: int = 10) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.material = mat
	node.mesh = mesh
	return node

static func sphere_mesh(radius: float, mat: Material, segments: int = 10, rings: int = 6) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	mesh.material = mat
	node.mesh = mesh
	return node

static func box_collision(size: Vector3) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	node.shape = shape
	return node

static func capsule_collision(radius: float, height: float) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	node.shape = shape
	return node

static func static_box(parent: Node, node_name: String, size: Vector3, at: Vector3, mat: Material, collision: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.add_child(box_mesh(size, mat))
	if collision:
		body.add_child(box_collision(size))
	parent.add_child(body)
	return body

static func label3d(text_value: String, at: Vector3, color_value: Color = Color(0.35, 0.9, 1.0), size: int = 34) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = at
	label.modulate = color_value
	label.font_size = size
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return label
