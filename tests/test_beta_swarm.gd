extends SceneTree
## Multi-agent regression test built from the user-reported blocked entrance video.
## It samples the exact gameplay capsule through the onboarding route and repeats
## structural audits after several WorldForge seeds. Any blocker prevents Web deployment.

var game: Node3D
var player: CharacterBody3D
var failures: Array[String] = []
var screenshots := not DisplayServer.get_name() == "headless"
var last_walk_blocker := "none"

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _check(ok: bool, message: String) -> void:
	if ok:
		return
	failures.append(message)
	push_error("BETA_SWARM_FAIL " + message)

func _capture(label: String) -> void:
	if not screenshots:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/beta-swarm")
	root.get_texture().get_image().save_png("res://build/beta-swarm/%s.png" % label)

func _player_capsule_blocker(at: Vector3) -> Node:
	var collision_shape := player.find_child("*", true, false) as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return null
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = Transform3D(player.global_transform.basis, at)
	query.collision_mask = player.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]
	for robot_body in game.get("robots") as Array:
		if robot_body is CollisionObject3D:
			query.exclude.append((robot_body as CollisionObject3D).get_rid())
	var drone := game.get("drone") as CollisionObject3D
	if drone != null:
		query.exclude.append(drone.get_rid())
	for hit in game.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var collider := hit.get("collider") as Node
		if collider == null:
			continue
		var node_name := String(collider.name)
		if node_name.contains("Floor") or node_name.contains("Ceiling"):
			continue
		if node_name in ["ServiceDoorOuterV18", "BlastDoorInnerV18", "HubLeftShutterV21", "HubRightShutterV21"]:
			continue
		if bool(collider.get_meta("facility_door", false)) or bool(collider.get_meta("fnaf_shutter", false)):
			continue
		return collider
	return null

func _walk_to(destination: Vector3, _max_frames := 260) -> bool:
	# Jolt volume validation with the exact player's CollisionShape3D. Sampling
	# every 18 cm catches a wall/prop before placing the test player there while
	# avoiding false positives from test_move() continuously touching the floor.
	last_walk_blocker = "none"
	var start: Vector3 = player.global_position
	var horizontal := Vector3(destination.x - start.x, 0.0, destination.z - start.z)
	var distance := horizontal.length()
	if distance < 0.01:
		return true
	var steps := maxi(1, ceili(distance / 0.18))
	for step in range(1, steps + 1):
		var target := start.lerp(destination, float(step) / float(steps))
		var blocker := _player_capsule_blocker(target)
		if blocker != null:
			last_walk_blocker = "%s path=%s at=%s" % [blocker.name, blocker.get_path(), target]
			return false
		player.global_position = target
		await physics_frame
	return Vector2(
		player.global_position.x - destination.x,
		player.global_position.z - destination.z
	).length() < 0.22

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/beta-swarm")
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	await _frames(120)
	game._start_game()
	game._finish_intro_v12()
	await _frames(45)
	player = game.get("player") as CharacterBody3D
	var swarm: Node = game.get_node_or_null("BetaTestSwarmV22")
	_check(player != null, "player missing")
	_check(swarm != null, "beta swarm runtime agent missing")
	_check(bool(game.get_meta("beta_swarm_v22_ready", false)), "beta swarm readiness metadata missing")
	_check(game.get_node_or_null("EntryClearanceGuardV22") != null, "entry clearance runtime guard missing")
	if swarm == null or player == null:
		await _finish()
		return

	# Freeze moving gameplay actors while the exact capsule volume is sampled.
	game.set_physics_process(false)
	for robot_body in game.get("robots") as Array:
		if robot_body is CharacterBody3D:
			(robot_body as CharacterBody3D).global_position = Vector3(-12.5, 1.0, -63.0)
	var drone := game.get("drone") as CharacterBody3D
	if drone != null:
		drone.global_position = Vector3(13.0, 2.2, -26.0)
	var outer_door := game.get("act1_outer_door_v18") as AnimatableBody3D
	var inner_door := game.get("act1_inner_door_v18") as AnimatableBody3D
	_check(outer_door != null and inner_door != null, "Act I service airlock doors missing")
	if outer_door != null:
		outer_door.position.x = 12.95
	if inner_door != null:
		inner_door.position.x = 8.05
	await _frames(5)

	# ENTRY SENTINEL — exact public onboarding route.
	player.global_position = Vector3(10.5, 1.1, 2.6)
	player.velocity = Vector3.ZERO
	await _frames(8)
	await _capture("00-service-approach")
	_check(game.find_child("VestibuleNorthWallV18", true, false) == null, "obsolete north vestibule wall still exists")
	_check(game.find_child("VestibuleSouthWallV18", true, false) == null, "obsolete south vestibule wall still exists")
	_check(game.find_child("VestibuleEndWallV18", true, false) == null, "obsolete end vestibule wall still exists")
	_check(await _walk_to(Vector3(10.5, 1.1, -1.0)), "ENTRY_SENTINEL blocked at outer service door: " + last_walk_blocker)
	await _capture("01-airlock-entry")
	_check(await _walk_to(Vector3(10.5, 1.1, -5.3)), "ENTRY_SENTINEL cannot cross decontamination airlock: " + last_walk_blocker)
	_check(await _walk_to(Vector3(10.5, 1.1, -12.7)), "ENTRY_SENTINEL blocked after inner blast door: " + last_walk_blocker)
	await _capture("02-vestibule-open")
	for point: Vector3 in [Vector3(9.1, 1.1, -13.4), Vector3(7.5, 1.1, -13.4), Vector3(5.8, 1.1, -14.8), Vector3(3.2, 1.1, -16.5), Vector3(0.0, 1.1, -18.0)]:
		_check(await _walk_to(point), "ENTRY_SENTINEL route to S-01 blocked near %s by %s" % [point, last_walk_blocker])
	await _capture("03-hub-arrival")
	_check(player.global_position.distance_to(Vector3(0.0, 1.1, -18.0)) < 0.35, "ENTRY_SENTINEL did not reach S-01")

	# ROUTE EXPLORER + GEOMETRY WATCH + SECURITY GUARD.
	var report: Dictionary = swarm.call("audit_now") as Dictionary
	for agent_variant: Variant in report.get("agents", []):
		var agent := agent_variant as Dictionary
		_check(bool(agent.get("pass", false)), "%s failed: %s" % [agent.get("agent", "UNKNOWN"), agent.get("issues", [])])
	var cameras: Node = game.get_node_or_null("FNAFSurveillanceV21")
	_check(cameras != null and (cameras.get("camera_nodes") as Array).size() == 8, "SECURITY_GUARD camera network invalid")

	# WORLD FORGE CHAOS — generated assets must never re-block mandatory paths.
	var forge: Node = root.get_node_or_null("WorldForgeRuntime")
	_check(forge != null, "WORLD_FORGE_CHAOS runtime missing")
	var seed_results: Array[Dictionary] = []
	if forge != null:
		for seed: int in [1987, 19870922, 314159, 8675309]:
			forge.call("regenerate", seed)
			await _frames(12)
			swarm.call("_repair_generated_route_blockers")
			await physics_frame
			var seed_report: Dictionary = swarm.call("audit_now") as Dictionary
			var nav_issues: Array = []
			var shift_value: Node = game.get("shift") as Node
			if shift_value != null:
				var navigation: RefCounted = shift_value.get("navigation") as RefCounted
				if navigation != null:
					nav_issues = navigation.call("audit") as Array
			seed_results.append({"seed":seed, "pass":bool(seed_report.get("pass", false)) and nav_issues.is_empty(), "navigation":nav_issues, "report":seed_report})
			_check(nav_issues.is_empty(), "WORLD_FORGE_CHAOS seed %d blocks authored navigation: %s" % [seed, nav_issues.slice(0, 4)])
			var entry_agent_pass := false
			for agent_variant: Variant in seed_report.get("agents", []):
				var agent := agent_variant as Dictionary
				if String(agent.get("agent", "")) == "ENTRY_SENTINEL":
					entry_agent_pass = bool(agent.get("pass", false))
			_check(entry_agent_pass, "WORLD_FORGE_CHAOS seed %d re-blocks the entrance" % seed)

	var output := FileAccess.open("res://build/beta-swarm/report.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"final_report":report, "seeds":seed_results, "failures":failures}, "  "))
		output.close()
	print("BETA_SWARM ", "PASS" if failures.is_empty() else failures)
	await _finish()

func _finish() -> void:
	game.queue_free()
	game = null
	player = null
	await _frames(3)
	quit(0 if failures.is_empty() else 1)
