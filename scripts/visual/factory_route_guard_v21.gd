extends RefCounted
## Final safety pass for the v21 factory layout.
## Procedural props may decorate work cells, but they must never occupy the
## guaranteed player corridors or re-create a transverse obstacle wall.

func apply(scene: Node3D) -> void:
	_fix_hub_floor(scene)
	var protected_routes: Array[Vector3] = [
		Vector3(6.0, 0.0, -22.5),
		Vector3(-6.0, 0.0, -58.0),
		Vector3(5.5, 0.0, -92.0),
		Vector3(-5.5, 0.0, -126.0),
	]
	var moved := 0
	for candidate in scene.find_children("*", "RigidBody3D", true, false):
		var body := candidate as RigidBody3D
		var p := body.global_position
		var blocks_route := absf(p.z + 55.0) < 1.3 and absf(p.x) < 7.2
		if not blocks_route:
			for route in protected_routes:
				if absf(p.z - route.z) < 3.8 and absf(p.x - route.x) < 3.8:
					blocks_route = true
					break
		if not blocks_route:
			continue
		var side := -1.0 if p.x < 0.0 else 1.0
		if absf(p.x) < 0.5:
			side = -1.0 if moved % 2 == 0 else 1.0
		body.global_position = Vector3(
			side * (13.0 + float(moved % 4) * 0.65),
			maxf(0.75, p.y),
			p.z + float((moved % 3) - 1) * 1.15
		)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		moved += 1
	scene.set_meta("factory_route_guard_v21_moved", moved)

func _fix_hub_floor(scene: Node3D) -> void:
	var hub_floor := scene.find_child("HubFloorV21", true, false)
	if hub_floor is StaticBody3D:
		# The original factory floor already owns collision at y=0. The v21 hub
		# overlay is decorative; sink its collision below that plane to avoid a lip.
		(hub_floor as StaticBody3D).position.y = -0.10
