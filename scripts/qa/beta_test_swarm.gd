class_name BlackoutBetaTestSwarm
extends Node
## Runtime safety + deterministic beta-test agents.
## Safe fixes are applied automatically. Unsafe authored blockers are reported so CI blocks deployment.

const ENTRY_POINTS: Array[Vector3] = [
	Vector3(10.5, 1.05, 2.6),
	Vector3(10.5, 1.05, -1.0),
	Vector3(10.5, 1.05, -5.2),
	Vector3(10.5, 1.05, -10.9),
	Vector3(10.5, 1.05, -12.8),
	Vector3(9.1, 1.05, -13.4),
	Vector3(7.45, 1.05, -13.4),
	Vector3(5.8, 1.05, -14.8),
	Vector3(3.2, 1.05, -16.5),
	Vector3(0.0, 1.05, -18.0),
]

var game: Node3D
var last_report: Dictionary = {}
var _worldforge_id := 0
var _elapsed := 0.0
var _repair_count := 0

func configure(game_scene: Node3D) -> void:
	game = game_scene
	name = "BetaTestSwarmV22"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_repair_known_entry_regression()
	_install_entry_guidance()
	game.set_meta("beta_swarm_v22_ready", true)
	call_deferred("_deferred_first_audit")
	print("BLACKOUT_BETA_SWARM_V22_READY")

func _deferred_first_audit() -> void:
	await get_tree().physics_frame
	_repair_generated_route_blockers()
	last_report = audit_now()

func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	# Act I's service airlock is authored lazily when the campaign starts, after
	# this agent is first configured. Repair the known video regression as soon
	# as that late-authored node appears, before the player can reach it.
	if game.find_child("VestibuleNorthWallV18", true, false) != null:
		_repair_known_entry_regression()
	_elapsed += delta
	if _elapsed < 0.6:
		return
	_elapsed = 0.0
	var generated := game.get_node_or_null("WorldForgeGenerated")
	var current_id := generated.get_instance_id() if generated != null else 0
	if current_id != 0 and current_id != _worldforge_id:
		_worldforge_id = current_id
		_repair_generated_route_blockers()
		last_report = audit_now()

func _repair_known_entry_regression() -> void:
	# Video regression: this legacy wall sits <1 m after the inner blast door and
	# makes the vestibule look/behave like a dead end. v21 uses the lateral turn.
	for candidate in game.find_children("VestibuleNorthWallV18", "StaticBody3D", true, false):
		var wall := candidate as StaticBody3D
		wall.set_meta("beta_swarm_safe_fix", "remove_obsolete_entry_blocker")
		wall.collision_layer = 0
		wall.collision_mask = 0
		for shape_node in wall.find_children("*", "CollisionShape3D", true, false):
			(shape_node as CollisionShape3D).disabled = true
		for mesh_node in wall.find_children("*", "MeshInstance3D", true, false):
			(mesh_node as MeshInstance3D).visible = false
		wall.queue_free()
		_repair_count += 1
	var console := game.find_child("SentinelVestibuleConsoleV18", true, false)
	if console is Node3D:
		var spatial := console as Node3D
		if spatial.global_position.distance_to(Vector3(8.6, 0.0, -14.85)) < 1.5:
			spatial.global_position = Vector3(10.0, 0.0, -14.75)
			spatial.set_meta("beta_swarm_safe_fix", "wall_side_console")
			_repair_count += 1

func _install_entry_guidance() -> void:
	if game.get_node_or_null("BetaSwarmEntryGuideV22") != null:
		return
	var root := Node3D.new()
	root.name = "BetaSwarmEntryGuideV22"
	game.add_child(root)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.04, 0.32, 0.30)
	material.emission_enabled = true
	material.emission = Color(0.02, 0.20, 0.17)
	material.emission_energy_multiplier = 0.7
	material.roughness = 0.8
	for data in [
		[Vector3(10.5, 0.045, -12.1), Vector3(0.10, 0.018, 2.0), 0.0],
		[Vector3(9.0, 0.045, -13.4), Vector3(3.0, 0.018, 0.10), 0.0],
		[Vector3(7.2, 0.045, -14.1), Vector3(2.2, 0.018, 0.10), -35.0],
	]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = data[1] as Vector3
		mesh.mesh = box
		mesh.material_override = material
		mesh.position = data[0] as Vector3
		mesh.rotation_degrees.y = float(data[2])
		root.add_child(mesh)
	var label := Label3D.new()
	label.text = "S-01 CONTROL  ←"
	label.font_size = 25
	label.pixel_size = 0.003
	label.modulate = Color(0.55, 0.95, 0.84)
	label.position = Vector3(10.7, 2.45, -13.5)
	label.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	root.add_child(label)

func audit_now() -> Dictionary:
	var agents: Array[Dictionary] = []
	var entry_issues := _audit_entry_route()
	agents.append(_agent_result("ENTRY_SENTINEL", entry_issues))
	var route_issues: Array = []
	var shift_value = game.get("shift")
	if shift_value is Node:
		var navigation = (shift_value as Node).get("navigation")
		if navigation != null and navigation.has_method("audit"):
			route_issues = navigation.call("audit") as Array
	agents.append(_agent_result("ROUTE_EXPLORER", route_issues))
	var security_issues: Array = []
	var director := game.get_node_or_null("FNAFSurveillanceV21")
	if director == null:
		security_issues.append({"code":"missing_surveillance"})
	else:
		var cameras = director.get("camera_nodes")
		if not cameras is Array or (cameras as Array).size() != 8:
			security_issues.append({"code":"camera_count", "count":(cameras as Array).size() if cameras is Array else 0})
		if game.get_node_or_null("HubLeftShutterV21") == null or game.get_node_or_null("HubRightShutterV21") == null:
			security_issues.append({"code":"missing_shutter"})
	agents.append(_agent_result("SECURITY_GUARD", security_issues))
	var geometry_issues := _audit_oversized_route_geometry()
	agents.append(_agent_result("GEOMETRY_WATCH", geometry_issues))
	var failures := 0
	for agent in agents:
		if not bool(agent.get("pass", false)):
			failures += 1
	return {
		"schema_version": 2,
		"system": "blackout_beta_swarm_v22",
		"agents": agents,
		"pass": failures == 0,
		"failed_agents": failures,
		"safe_repairs": _repair_count,
		"entry_route": ENTRY_POINTS,
	}

func _agent_result(agent_name: String, issues: Array) -> Dictionary:
	return {"agent":agent_name, "pass":issues.is_empty(), "issues":issues}

func _audit_entry_route() -> Array:
	var issues: Array = []
	if game.find_child("VestibuleNorthWallV18", true, false) != null:
		issues.append({"code":"obsolete_vestibule_wall_present"})
	for index in range(ENTRY_POINTS.size() - 1):
		var a := ENTRY_POINTS[index]
		var b := ENTRY_POINTS[index + 1]
		var steps := maxi(2, ceili(a.distance_to(b) / 0.38))
		for step in range(steps + 1):
			var point := a.lerp(b, float(step) / float(steps))
			var blocker := blocker_at(point, true)
			if blocker != null:
				issues.append({
					"code":"blocked_entry_route",
					"segment":index,
					"position":[point.x, point.y, point.z],
					"node_path":str(blocker.get_path()),
					"node_name":String(blocker.name),
				})
				break
	return issues

func blocker_at(point: Vector3, ignore_operable_doors := true) -> Node:
	if game == null or game.get_world_3d() == null:
		return null
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.48
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var player_value = game.get("player")
	if player_value is CollisionObject3D:
		query.exclude = [(player_value as CollisionObject3D).get_rid()]
	for hit in game.get_world_3d().direct_space_state.intersect_shape(query, 24):
		var collider := hit.get("collider") as Node
		if collider == null:
			continue
		var node_name := String(collider.name)
		# Actors may cross a route temporarily but must never be diagnosed as walls.
		if collider is CharacterBody3D or bool(collider.get_meta("robot", false)) or bool(collider.get_meta("drone", false)):
			continue
		if ignore_operable_doors and node_name in ["ServiceDoorOuterV18", "BlastDoorInnerV18", "HubLeftShutterV21", "HubRightShutterV21"]:
			continue
		if node_name.contains("Floor") or node_name.contains("Ceiling"):
			continue
		if collider.get_meta("facility_door", false) or collider.get_meta("fnaf_shutter", false):
			continue
		return collider
	return null

func describe_blocker(point: Vector3) -> String:
	var blocker := blocker_at(point, false)
	if blocker == null:
		return "none"
	return "%s path=%s pos=%s" % [blocker.name, blocker.get_path(), (blocker as Node3D).global_position if blocker is Node3D else Vector3.ZERO]

func _repair_generated_route_blockers() -> void:
	if game == null:
		return
	var route_points := _all_critical_route_points()
	var moved := 0
	for candidate in game.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		if not bool(body.get_meta("worldforge_generated", false)) or not bool(body.get_meta("worldforge_replaceable", false)):
			continue
		var size := body.get_meta("size", Vector3.ONE) as Vector3
		if not _object_hits_route(body.global_position, size, route_points):
			continue
		var before := body.global_position
		var side := -13.7 if before.x <= 0.0 else 13.7
		body.global_position = Vector3(side, maxf(size.y * 0.5, 0.15), clampf(before.z, -85.0, -22.0))
		body.set_meta("beta_swarm_relocated", true)
		moved += 1
	_repair_count += moved
	if moved > 0:
		print("BLACKOUT_BETA_SWARM_AUTOFIX moved_generated_blockers=", moved)

func _all_critical_route_points() -> Array[Vector3]:
	var result: Array[Vector3] = ENTRY_POINTS.duplicate()
	var shift_value = game.get("shift")
	if shift_value is Node:
		var navigation = (shift_value as Node).get("navigation")
		if navigation != null:
			var points_value = navigation.get("points")
			if points_value is Dictionary:
				for value in (points_value as Dictionary).values():
					if value is Vector3:
						result.append(value)
	return result

func _object_hits_route(at: Vector3, size: Vector3, route_points: Array[Vector3]) -> bool:
	var radius := 0.62 + maxf(size.x, size.z) * 0.5
	for point in route_points:
		if Vector2(at.x - point.x, at.z - point.z).length() < radius:
			return true
	return false

func _audit_oversized_route_geometry() -> Array:
	var issues: Array = []
	for candidate in game.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		if bool(body.get_meta("worldforge_generated", false)):
			continue
		var size := body.get_meta("size", Vector3.ZERO) as Vector3
		if size == Vector3.ZERO:
			continue
		if maxf(size.x, size.z) < 4.0:
			continue
		for point in ENTRY_POINTS.slice(3):
			var half := Vector2(size.x * 0.5 + 0.4, size.z * 0.5 + 0.4)
			if absf(body.global_position.x - point.x) < half.x and absf(body.global_position.z - point.z) < half.y:
				if not String(body.name).contains("Floor") and not String(body.name).contains("Ceiling"):
					issues.append({"code":"oversized_authored_entry_blocker", "node_path":str(body.get_path()), "size":[size.x,size.y,size.z]})
				break
	return issues
