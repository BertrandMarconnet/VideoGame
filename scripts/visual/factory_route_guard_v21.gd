extends RefCounted
## Deterministic circulation safety pass for the v21 factory.
## It removes the obsolete oversized control-room floor collision and moves
## procedural physics props away from the guaranteed player routes. Static
## architecture remains untouched: the integration test validates it separately.

const PROTECTED_ROUTES: Array[Vector3] = [
	Vector3(6.0, 0.0, -22.5),
	Vector3(-6.0, 0.0, -58.0),
	Vector3(5.5, 0.0, -92.0),
	Vector3(-5.5, 0.0, -126.0),
]


func apply(scene: Node3D) -> void:
	_cleanup_hub_floors(scene)
	var moved := 0
	for candidate in scene.find_children("*", "RigidBody3D", true, false):
		var body := candidate as RigidBody3D
		var p := body.global_position
		if not _blocks_guaranteed_route(p):
			continue
		var destination_x := 14.2 if p.x >= 0.0 else -14.2
		# M-04 occupies the west wall strip; crawlspace blockers go east instead.
		if _blocks_crawlspace(p):
			destination_x = 14.2
		body.global_position = Vector3(
			destination_x,
			maxf(0.75, p.y),
			p.z + float((moved % 3) - 1) * 1.15
		)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		moved += 1
	scene.set_meta("factory_route_guard_v21_moved", moved)
	scene.set_meta("factory_route_guard_v21_ready", true)


func _blocks_guaranteed_route(p: Vector3) -> bool:
	# v20 created eight props as a literal barrier across z=-55.
	if absf(p.z + 55.0) < 1.3 and absf(p.x) < 7.2:
		return true
	for route in PROTECTED_ROUTES:
		if absf(p.z - route.z) < 3.8 and absf(p.x - route.x) < 3.8:
			return true
	return _blocks_crawlspace(p)


func _blocks_crawlspace(p: Vector3) -> bool:
	return absf(p.x + 14.05) < 1.55 and p.z < -123.6 and p.z > -136.4


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
