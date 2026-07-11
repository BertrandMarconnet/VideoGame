class_name DestructiblePanel
extends StaticBody3D

signal destroyed(panel: DestructiblePanel)

var max_health := 80.0
var health := 80.0
var panel_size := Vector3(2.2, 2.8, 0.34)
var panel_material: StandardMaterial3D
var material_kind := "concrete"
var factory: Node
var graph_link_id := ""
var broken := false
var marks := 0

func configure(owner_factory: Node, link_id: String, size: Vector3, at: Vector3, mat: StandardMaterial3D, kind: String = "concrete") -> void:
	factory = owner_factory
	graph_link_id = link_id
	panel_size = size
	position = at
	panel_material = mat
	material_kind = kind
	max_health = 65.0 if kind == "glass" else 95.0
	health = max_health
	add_child(WorldUtil.box_mesh(size, mat))
	add_child(WorldUtil.box_collision(size))
	add_to_group("destructible")

func receive_impact(damage: float, hit_point: Vector3, impulse: Vector3 = Vector3.ZERO) -> void:
	if broken:
		return
	health -= damage
	_add_mark(hit_point)
	if health <= 0.0:
		_break_apart(impulse)

func _add_mark(hit_point: Vector3) -> void:
	if marks >= 4:
		return
	marks += 1
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25 + randf() * 0.28, 0.25 + randf() * 0.28)
	var mat := WorldUtil.material(Color(0.02, 0.025, 0.03, 0.86), 0.0, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	mark.mesh = quad
	mark.position = to_local(hit_point) + Vector3(0.0, 0.0, panel_size.z * 0.53)
	mark.rotation.z = randf_range(-1.3, 1.3)
	add_child(mark)

func _break_apart(impulse: Vector3) -> void:
	broken = true
	if factory and factory.has_method("open_dynamic_link"):
		factory.open_dynamic_link(graph_link_id)
	var count := 4 if material_kind == "glass" else 7
	for i in range(count):
		var chunk := GrabbableProp.new()
		var sz := Vector3(panel_size.x / 3.2, panel_size.y / 3.0, panel_size.z * 0.85) * randf_range(0.65, 1.05)
		chunk.configure("debris", sz, panel_material, maxf(1.2, sz.length() * 1.8))
		get_parent().add_child(chunk)
		chunk.global_position = global_position + Vector3(randf_range(-0.7, 0.7), randf_range(-0.8, 0.8), randf_range(-0.2, 0.2))
		chunk.apply_central_impulse(impulse * 0.18 + Vector3(randf_range(-2.0, 2.0), randf_range(1.0, 3.7), randf_range(-2.0, 2.0)))
	destroyed.emit(self)
	queue_free()
