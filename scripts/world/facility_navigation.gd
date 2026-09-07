extends RefCounted
## Shared authored graph with physical visibility and swept-capsule edge audits.
var game: Node3D
var points := {
	"HUB": Vector3(0, 0.95, -18), "HL": Vector3(-5.55, 0.95, -19.5), "HR": Vector3(5.55, 0.95, -19.5),
	"WL": Vector3(-5.55, 0.95, -23), "ER": Vector3(5.55, 0.95, -23),
	"W1": Vector3(-5.55, 0.95, -33.5), "W2": Vector3(-5.55, 0.95, -47), "W3": Vector3(-5.55, 0.95, -61),
	"E1": Vector3(5.55, 0.95, -33.5), "E2": Vector3(5.55, 0.95, -47), "E3": Vector3(5.55, 0.95, -61),
	"LOGISTICS": Vector3(-9, 0.95, -33.5), "ARCHIVES": Vector3(-9, 0.95, -47), "MAINTENANCE": Vector3(-9, 0.95, -61),
	"ASSEMBLY": Vector3(9, 0.95, -33.5), "POWER": Vector3(9, 0.95, -47), "TEST": Vector3(9, 0.95, -61),
	"NW": Vector3(-5.55, 0.95, -69), "NE": Vector3(5.55, 0.95, -69),
	"R1": Vector3(5.9, 0.95, -74), "R2": Vector3(5.9, 0.95, -82), "RELAY": Vector3(0, 0.95, -84),
}
var edges := [
	["HUB","HL"], ["HUB","HR"], ["HL","WL"], ["HR","ER"],
	["WL","W1"], ["W1","W2"], ["W2","W3"], ["W3","NW"], ["NW","NE"],
	["NE","E3"], ["E3","E2"], ["E2","E1"], ["E1","ER"],
	["W1","LOGISTICS"], ["W2","ARCHIVES"], ["W3","MAINTENANCE"],
	["E1","ASSEMBLY"], ["E2","POWER"], ["E3","TEST"],
	["NE","R1"], ["R1","R2"], ["R2","RELAY"],
]

func clear_ray(a: Vector3, b: Vector3, exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a, b, 1, exclude)
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func nearest(at: Vector3) -> String:
	var best := "HUB"
	var distance := INF
	for key in points:
		var d := at.distance_squared_to(points[key])
		if d < distance:
			distance = d
			best = key
	return best

func path(from: Vector3, to: Vector3, respect_doors := true) -> Array[Vector3]:
	var start := nearest(from)
	var end := nearest(to)
	var queue: Array[String] = [start]
	var previous := {start: ""}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == end:
			break
		for pair in edges:
			var other: String = pair[1] if pair[0] == current else (pair[0] if pair[1] == current else "")
			if other.is_empty() or previous.has(other):
				continue
			if respect_doors and not clear_ray(points[current] + Vector3.UP * 0.3, points[other] + Vector3.UP * 0.3, _actors()):
				continue
			previous[other] = current
			queue.append(other)
	if not previous.has(end):
		return []
	var result: Array[Vector3] = [to]
	var step := end
	while not step.is_empty():
		result.push_front(points[step])
		step = previous[step]
	return result

func _actors() -> Array[RID]:
	var result: Array[RID] = []
	for node in game.find_children("*", "CharacterBody3D", true, false):
		result.append((node as CharacterBody3D).get_rid())
		for child in node.find_children("*", "PhysicsBody3D", true, false):
			result.append(child.get_rid())
	return result

func audit() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.72
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = _actors()
	for candidate in game.find_children("*", "RigidBody3D", true, false):
		query.exclude.append((candidate as RigidBody3D).get_rid())
	for pair in edges:
		var a: Vector3 = points[pair[0]]
		var b: Vector3 = points[pair[1]]
		var steps := ceili(a.distance_to(b) / 0.4)
		for index in range(steps + 1):
			var at := a.lerp(b, float(index) / maxi(1, steps))
			query.transform = Transform3D(Basis.IDENTITY, at)
			var hits := game.get_world_3d().direct_space_state.intersect_shape(query, 16)
			for hit in hits:
				var body := hit["collider"] as Node
				if body.get_meta("fnaf_shutter", false) or body.get_meta("facility_door", false):
					continue
				issues.append({"code":"blocked_route", "edge":pair, "position":at, "node_path":str(body.get_path()), "severity":"error"})
				break
	return issues

func room_for_position(at: Vector3) -> String:
	if at.z > -22:
		return "HUB"
	if at.z < -71:
		return "RELAY"
	if absf(at.x) < 3.7 and at.z < -49 and at.z > -57:
		return "M-04"
	if absf(at.x) <= 7.5:
		return "WEST HALL" if at.x < 0 else "EAST HALL"
	if at.z > -38:
		return "LOGISTICS" if at.x < 0 else "ASSEMBLY"
	var west_room := "ARCHIVES" if at.z > -53 else "MAINTENANCE"
	var east_room := "POWER" if at.z > -53 else "TEST"
	return west_room if at.x < 0 else east_room
