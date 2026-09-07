extends SceneTree
## Multi-agent regression test built from the user-reported blocked entrance video.
## It physically walks the onboarding route and repeats structural audits after
## several WorldForge seeds. Any blocker prevents Web deployment.

var game: Node3D
var failures: Array[String] = []
var screenshots := not DisplayServer.get_name() == "headless"

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

func _walk_to(destination: Vector3, max_frames := 260) -> bool:
	for _step in range(max_frames):
		var offset := destination - game.player.global_position
		offset.y = 0.0
		if offset.length() < 0.38:
			return true
		game.player.velocity = offset.normalized() * 4.6
		game.player.velocity.y = -1.0
		game.player.move_and_slide()
		await physics_frame
	return Vector2(
		game.player.global_position.x - destination.x,
		game.player.global_position.z - destination.z
	).length() < 0.45

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/beta-swarm")
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	await _frames(120)
	game._start_game()
	game._finish_intro_v12()
	await _frames(35)
	var swarm := game.get_node_or_null("BetaTestSwarmV22")
	_check(swarm != null, "beta swarm runtime agent missing")
	_check(bool(game.get_meta("beta_swarm_v22_ready", false)), "beta swarm readiness metadata missing")
	if swarm == null:
		await _finish()
		return

	# ENTRY SENTINEL — reproduce the exact public onboarding path instead of
	# teleporting directly into S-01 as the older integration tests did.
	game.player.global_position = Vector3(10.5, 0.95, 3.0)
	game.player.velocity = Vector3.ZERO
	await _frames(20)
	await _capture("00-service-approach")
	_check(game.find_child("VestibuleNorthWallV18", true, false) == null, "obsolete wall still exists immediately after inner blast door")
	_check(await _walk_to(Vector3(10.5, 0.95, -1.0)), "ENTRY_SENTINEL blocked at outer service door: " + String(swarm.call("describe_blocker", game.player.global_position)))
	await _capture("01-airlock-entry")
	_check(await _walk_to(Vector3(10.5, 0.95, -5.3)), "ENTRY_SENTINEL cannot cross decontamination airlock: " + String(swarm.call("describe_blocker", game.player.global_position)))
	# Inner door opens after the pressure-lock dwell.
	await _frames(75)
	_check(await _walk_to(Vector3(10.5, 0.95, -12.7)), "ENTRY_SENTINEL blocked after inner blast door: " + String(swarm.call("describe_blocker", game.player.global_position)))
	await _capture("02-vestibule-open")
	for point in [Vector3(9.1, 0.95, -13.4), Vector3(7.5, 0.95, -13.4), Vector3(5.8, 0.95, -14.8), Vector3(3.2, 0.95, -16.5), Vector3(0.0, 0.95, -18.0)]:
		_check(await _walk_to(point), "ENTRY_SENTINEL route to S-01 blocked near %s by %s" % [point, String(swarm.call("describe_blocker", game.player.global_position))])
	await _capture("03-hub-arrival")
	_check(game.player.global_position.distance_to(Vector3(0.0, 0.95, -18.0)) < 0.65, "ENTRY_SENTINEL did not reach S-01")

	# ROUTE EXPLORER + GEOMETRY WATCH + SECURITY GUARD.
	var report := swarm.call("audit_now") as Dictionary
	for agent_variant in report.get("agents", []):
		var agent := agent_variant as Dictionary
		_check(bool(agent.get("pass", false)), "%s failed: %s" % [agent.get("agent", "UNKNOWN"), agent.get("issues", [])])
	var cameras := game.get_node_or_null("FNAFSurveillanceV21")
	_check(cameras != null and (cameras.get("camera_nodes") as Array).size() == 8, "SECURITY_GUARD camera network invalid")

	# WORLD FORGE CHAOS — future procedural changes must not be able to put a
	# generated wall or prop on a mandatory route. Safe generated blockers are
	# automatically relocated by the runtime swarm before deployment.
	var forge := root.get_node_or_null("WorldForgeRuntime")
	_check(forge != null, "WORLD_FORGE_CHAOS runtime missing")
	var seed_results: Array[Dictionary] = []
	if forge != null:
		for seed in [1987, 19870922, 314159, 8675309]:
			forge.call("regenerate", seed)
			await _frames(12)
			swarm.call("_repair_generated_route_blockers")
			await physics_frame
			var seed_report := swarm.call("audit_now") as Dictionary
			var nav_issues: Array = []
			if game.shift != null and game.shift.navigation != null:
				nav_issues = game.shift.navigation.audit()
			seed_results.append({"seed":seed, "pass":bool(seed_report.get("pass", false)) and nav_issues.is_empty(), "navigation":nav_issues, "report":seed_report})
			_check(nav_issues.is_empty(), "WORLD_FORGE_CHAOS seed %d blocks authored navigation: %s" % [seed, nav_issues.slice(0, 4)])
			var entry_agent_pass := false
			for agent_variant in seed_report.get("agents", []):
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
	await _frames(3)
	quit(0 if failures.is_empty() else 1)
