extends SceneTree
## Rendered integration test for the final FNAF-style v21 layout.
## Intended to run under xvfb so the CI artifact contains actual game images.

var game: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("V21_FNAF_CHECK_FAILED " + message)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/fnaf-v21")
	root.get_texture().get_image().save_png("res://build/fnaf-v21/%s.png" % label)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	await _frames(100)
	_check(game.has_node("FactoryFNAFV21"), "FNAF factory root missing")
	_check(not game.has_node("FactoryLayoutV21"), "obsolete straight-layout v21 still active")
	_check(bool(game.get_meta("factory_fnaf_v21_ready", false)), "FNAF layout readiness missing")
	var director := game.get_node_or_null("FNAFSurveillanceV21")
	_check(director != null, "surveillance director missing")
	if director != null:
		var cameras = director.get("camera_nodes")
		_check(cameras is Array and (cameras as Array).size() == 8, "camera network must expose 8 feeds")
	await _capture("00-menu")

	game._start_game()
	await _frames(12)
	game._finish_intro_v12()
	await _frames(30)
	_check(game.game_started, "campaign did not start")
	_check(game.relay_terminal.global_position.distance_to(Vector3(0.0, 1.1, -84.0)) < 1.0, "relay terminal was not moved into north relay room")
	_check(game.uplink_terminal.global_position.distance_to(Vector3(-3.2, 1.1, -18.4)) < 1.0, "uplink terminal was not moved into S-01")

	# The old centre line must be physically blocked by a utility core, while both
	# lateral halls and the north cross-route remain passable.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.72
	_check(not _space_clear(Vector3(0.0, 0.93, -40.0), capsule), "factory still exposes an uninterrupted central spine")
	for point in [
		Vector3(-5.55, 0.93, -29.0), Vector3(-5.55, 0.93, -44.0), Vector3(-5.55, 0.93, -62.0),
		Vector3(5.55, 0.93, -29.0), Vector3(5.55, 0.93, -44.0), Vector3(5.55, 0.93, -62.0),
		Vector3(-2.0, 0.93, -69.0), Vector3(5.9, 0.93, -74.0), Vector3(0.0, 0.93, -84.0)
	]:
		_check(_space_clear(point, capsule), "authored FNAF route blocked at %s" % point)

	# Real rendered viewpoints used for visual beta review.
	for sample in [
		{"name":"01-hub", "at":Vector3(0.0, 0.95, -17.8), "yaw":180.0},
		{"name":"02-west-hall", "at":Vector3(-5.55, 0.95, -29.0), "yaw":180.0},
		{"name":"03-logistics", "at":Vector3(-10.2, 0.95, -31.0), "yaw":90.0},
		{"name":"04-east-hall", "at":Vector3(5.55, 0.95, -43.0), "yaw":0.0},
		{"name":"05-power-room", "at":Vector3(10.2, 0.95, -46.0), "yaw":-90.0},
		{"name":"06-north-loop", "at":Vector3(5.8, 0.95, -69.0), "yaw":180.0},
		{"name":"07-relay", "at":Vector3(0.0, 0.95, -82.0), "yaw":180.0},
	]:
		game.player.global_position = sample["at"]
		game.player.velocity = Vector3.ZERO
		game.player.rotation_degrees = Vector3(0.0, float(sample["yaw"]), 0.0)
		game.camera.rotation = Vector3.ZERO
		await _frames(8)
		await _capture(String(sample["name"]))

	if director != null:
		game.player.global_position = Vector3(0.0, 0.95, -17.0)
		var power_before := float(director.get("power"))
		director.call("toggle_surveillance")
		await _frames(12)
		_check(bool(game.get_meta("fnaf_surveillance_open", false)), "camera network did not open")
		_check(float(director.get("power")) < power_before, "camera network does not consume power")
		await _capture("08-camera-network")
		director.call("toggle_left_shutter")
		await _frames(30)
		var shutter := game.get_node_or_null("HubLeftShutterV21") as AnimatableBody3D
		_check(shutter != null and shutter.position.y < 3.0, "left security shutter did not close physically")
		await _capture("09-shutter-closed")
		director.call("toggle_surveillance")

	# Mobile camera overlay must scale into narrow viewports instead of stacking.
	root.size = Vector2i(390, 844)
	await _frames(12)
	if director != null:
		director.call("toggle_surveillance")
		await _frames(8)
		var frame := director.get("ui_frame") as Control
		_check(frame != null and frame.scale.x <= 0.55, "camera UI does not scale for phone width")
		await _capture("10-mobile-camera")
		director.call("toggle_surveillance")

	print("V21_FNAF_CHECKS ", "PASS" if failures.is_empty() else failures)
	game.queue_free()
	game = null
	await _frames(3)
	quit(0 if failures.is_empty() else 1)

func _space_clear(point: Vector3, shape: Shape3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 1
	var excluded: Array[RID] = [game.player.get_rid()]
	for node in game.find_children("*", "RigidBody3D", true, false):
		excluded.append((node as RigidBody3D).get_rid())
	for node in game.find_children("*", "CharacterBody3D", true, false):
		var body := node as CharacterBody3D
		if body != game.player:
			excluded.append(body.get_rid())
	query.exclude = excluded
	return game.get_world_3d().direct_space_state.intersect_shape(query, 16).is_empty()
