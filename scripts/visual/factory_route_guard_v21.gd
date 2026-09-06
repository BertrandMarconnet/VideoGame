extends RefCounted
## Deterministic circulation safety pass for the v21 factory.
## It removes obsolete geometry, preserves the guaranteed player routes and
## reconciles WorldForge generation with the authored v21 circulation graph.

const PROTECTED_ROUTES: Array[Vector3] = [
	Vector3(6.0, 0.0, -22.5),
	Vector3(-6.0, 0.0, -58.0),
	Vector3(5.5, 0.0, -92.0),
	Vector3(-5.5, 0.0, -126.0),
]


func apply(scene: Node3D) -> void:
	_cleanup_hub_floors(scene)
	_open_m04_j4_aperture(scene)
	var removed := _remove_worldforge_route_blockers(scene)
	var moved := _move_dynamic_route_blockers(scene)
	scene.set_meta("factory_route_guard_v21_removed", removed)
	scene.set_meta("factory_route_guard_v21_moved", moved)
	scene.set_meta("factory_route_guard_v21_ready", true)


func _move_dynamic_route_blockers(scene: Node3D) -> int:
	var moved := 0
	for candidate in scene.find_children("*", "RigidBody3D", true, false):
		var body := candidate as RigidBody3D
		var p := body.global_position
		var size := body.get_meta("size", Vector3.ONE) as Vector3
		if not _volume_blocks_guaranteed_route(p, size):
			continue
		var destination_x := 14.2 if p.x >= 0.0 else -14.2
		# M-04 occupies the west wall strip; crawlspace blockers go east instead.
		if _volume_blocks_crawlspace(p, size):
			destination_x = 14.2
		body.global_position = Vector3(
			destination_x,
			maxf(0.75, p.y),
			p.z + float((moved % 3) - 1) * 1.15
		)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.set_meta("factory_route_guard_v21_relocated", true)
		moved += 1
	return moved


func _remove_worldforge_route_blockers(scene: Node3D) -> int:
	var removed := 0
	for candidate in scene.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		if not bool(body.get_meta("worldforge_generated", false)):
			continue
		var size := body.get_meta("size", Vector3.ONE) as Vector3
		if not _volume_blocks_guaranteed_route(body.global_position, size):
			continue
		body.queue_free()
		removed += 1
	return removed


func _volume_blocks_guaranteed_route(p: Vector3, size: Vector3) -> bool:
	# v20 created eight props as a literal barrier across z=-55.
	if absf(p.z + 55.0) < 1.3 + size.z * 0.5:
		if absf(p.x) < 7.2 + size.x * 0.5:
			return true
	for route in PROTECTED_ROUTES:
		var within_x := absf(p.x - route.x) < 3.65 + size.x * 0.5
		var within_z := absf(p.z - route.z) < 3.35 + size.z * 0.5
		if within_x and within_z:
			return true
	return _volume_blocks_crawlspace(p, size)


func _volume_blocks_crawlspace(p: Vector3, size: Vector3) -> bool:
	var within_x := absf(p.x + 14.05) < 1.90 + size.x * 0.5
	var within_z := absf(p.z + 130.0) < 6.35 + size.z * 0.5
	return within_x and within_z


func _cleanup_hub_floors(scene: Node3D) -> void:
	# The original 26 x 18 m ControlFloor conflicts with the reduced S-01 hub and
	# creates a raised collision lip. The factory shell already owns the ground.
	var legacy_floor := scene.find_child("ControlFloor", true, false)
	if legacy_floor:
		legacy_floor.queue_free()

	# Keep the v21 floor as a material overlay only. Ground collision belongs to
	# the original factory Floor, avoiding stacked floor shapes in Godot/Jolt.
	var hub_floor := scene.find_child("HubFloorV21", true, false)
	if hub_floor is StaticBody3D:
		var body := hub_floor as StaticBody3D
		body.collision_layer = 0
		body.collision_mask = 0
		for candidate in body.find_children("*", "CollisionShape3D", true, false):
			(candidate as CollisionShape3D).disabled = true


func _open_m04_j4_aperture(scene: Node3D) -> void:
	# J4 originally filled the whole west side with BulkheadLeftV21, which crossed
	# the authored M-04 crawlspace. Replace only that one slab with two structural
	# pieces and a low lintel, leaving a 3.5 m service opening at x=-14.05.
	var junction := scene.find_child("OffsetJunctionV21_3", true, false) as Node3D
	if junction == null:
		return
	if junction.get_node_or_null("BulkheadM04OuterV21") != null:
		return
	var old := junction.get_node_or_null("BulkheadLeftV21") as StaticBody3D
	if old == null:
		return
	var material: Material = null
	var mesh := old.find_child("*Mesh", true, false) as MeshInstance3D
	if mesh != null:
		material = mesh.material_override
	if material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.18, 0.20, 0.20)
		fallback.roughness = 0.88
		material = fallback
	old.queue_free()
	_make_static_box(
		junction,
		Vector3(0.75, 3.75, 0.30),
		Vector3(-16.175, 1.88, -126.0),
		material,
		"BulkheadM04OuterV21"
	)
	_make_static_box(
		junction,
		Vector3(3.75, 3.75, 0.30),
		Vector3(-10.425, 1.88, -126.0),
		material,
		"BulkheadM04InnerV21"
	)
	_make_static_box(
		junction,
		Vector3(3.50, 2.20, 0.30),
		Vector3(-14.05, 2.65, -126.0),
		material,
		"BulkheadM04LintelV21"
	)


func _make_static_box(
	parent: Node3D,
	size: Vector3,
	at: Vector3,
	material: Material,
	label: String
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.set_meta("layout_role_v21", label)
	body.set_meta("size", size)
	parent.add_child(body)
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = label + "Mesh"
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	return body
