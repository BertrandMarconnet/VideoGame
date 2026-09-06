extends SceneTree
## Integration checks against the actual scene, physics and responsive controls.
## Run with --headless --script res://tests/test_visual_mobile.gd -- --touch-ui.
## With a display, this also saves real game captures under build/visual-v21/.

var game: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("V21_CHECK_FAILED " + message)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/visual-v21")
	root.get_texture().get_image().save_png("res://build/visual-v21/%s.png" % label)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	await _frames(65)
	_check(game.has_node("IndustrialVisualsV20"), "Industrial world did not load")
	_check(game.has_node("FactoryLayoutV21"), "Coherent factory layout v21 did not load")
	_check(bool(game.get_meta("factory_layout_v21_ready", false)), "Factory layout v21 readiness flag missing")
	_check(bool(game.get_meta("factory_route_guard_v21_ready", false)), "Factory route guard v21 did not run")
	_check(game.find_child("ControlFloor", true, false) == null, "Legacy oversized ControlFloor still exists")
	_check_dialog_text(game.start_panel)
	await _capture("desktop-menu")
	for size in [Vector2i(390, 844), Vector2i(667, 375)]:
		root.size = size
		await _frames(8)
		_check_dialog_text(game.start_panel)
		await _capture("menu-%dx%d" % [size.x, size.y])
	root.size = Vector2i(1280, 720)
	await _frames(8)
	game._start_game()
	await _frames(12)
	await _capture("desktop-intro")
	game._finish_intro_v12()
	await _frames(20)
	game.set_physics_process(false)
	_check(game.game_started, "Campaign did not start")
	_check(game.get_meta("v20_art_finished", false), "Act I materials were not finalized")
	await _check_secure_hub_gate()
	for sample in [
		{"name": "exterior", "at": Vector3(4, 0.95, 17), "yaw": -12.0},
		{"name": "airlock", "at": Vector3(10.5, 0.95, -2.6), "yaw": 0.0},
		{"name": "compact-hub", "at": Vector3(-5.8, 0.95, -9.2), "yaw": 28.0},
		{"name": "junction-logistics", "at": Vector3(6.0, 0.95, -20.2), "yaw": 0.0},
		{"name": "assembly", "at": Vector3(-2.5, 0.95, -67), "yaw": 30.0},
		{"name": "secret-room", "at": Vector3(-10.8, 0.95, -119.0), "yaw": -90.0},
		{"name": "maintenance-crawl", "at": Vector3(-14.05, 0.76, -129.0), "yaw": 180.0},
	]:
		game.player.global_position = sample["at"]
		game.player.rotation_degrees = Vector3(0, float(sample["yaw"]), 0)
		game.camera.rotation = Vector3.ZERO
		await _frames(10)
		await _capture(String(sample["name"]))
	await _check_routes()
	# Inspect the actual skinned campaign robots, without altering the story gates.
	for robot: CharacterBody3D in game.robots:
		var kind := String(robot.get_meta("personality", ""))
		if kind not in ["specter", "crawler"]:
			continue
		var previous := robot.global_transform
		var was_visible := robot.visible
		robot.visible = true
		robot.global_position = Vector3(0, 0.95 if kind == "specter" else 0.55, -39)
		robot.rotation.y = 0.0
		game.player.global_position = Vector3(1.8, 0.95, -34.5)
		game.player.rotation_degrees.y = 22
		game.camera.rotation = Vector3.ZERO
		await _frames(8)
		await _capture("robot-" + kind)
		robot.global_transform = previous
		robot.visible = was_visible
	for size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(360, 640), Vector2i(667, 375)]:
		root.size = size
		await _frames(8)
		game.reflow_interface_v20()
		await _frames(8)
		_check_touch_layout()
		await _capture("mobile-%dx%d" % [size.x, size.y])
		Input.action_press("move_forward")
		game._toggle_tablet_v12()
		await _frames(5)
		_check(not game.responsive_ui_v20.hud.visible, "HUD overlaps tablet")
		_check(not game.mobile_layer.visible, "Touch controls overlap tablet")
		_check(not Input.is_action_pressed("move_forward"), "Movement sticks after opening tablet")
		var close: Control = game.tablet_panel.get_child(game.tablet_panel.get_child_count() - 1)
		_check(Rect2(Vector2.ZERO, Vector2(size)).encloses(close.get_global_rect()), "Tablet close button is outside the viewport")
		await _capture("tablet-%dx%d" % [size.x, size.y])
		game._toggle_tablet_v12()
		game._open_context_menu_v12()
		await _frames(5)
		_check(not game.responsive_ui_v20.hud.visible, "HUD overlaps actions")
		_check(Rect2(Vector2.ZERO, Vector2(size)).encloses(game.context_menu.get_global_rect()), "Actions exceed viewport")
		await _capture("actions-%dx%d" % [size.x, size.y])
		game._close_context_menu_v12()
		game._toggle_pause()
		await _frames(5)
		_check(not game.tablet_open and not game.context_menu_open, "Several modals are open")
		_check_dialog_text(game.pause_panel)
		await _capture("pause-%dx%d" % [size.x, size.y])
		game._toggle_pause()
		await _frames(3)
	# The brightness setting affects the actual Compatibility post-process.
	game._set_brightness(1.35)
	var post := game.get_node("PS1VisualLayer/PS1PostProcess") as ColorRect
	_check(is_equal_approx(float(post.material.get_shader_parameter("brightness")), 1.35), "Brightness has no shader effect")
	game._set_brightness(1.15)
	print("V21_VISUAL_MOBILE_CHECKS ", "PASS" if failures.is_empty() else failures)
	game.queue_free()
	game = null
	await _frames(3)
	quit(0 if failures.is_empty() else 1)

func _check_secure_hub_gate() -> void:
	var gate := game.find_child("SecureHubGateV21", true, false)
	_check(gate != null, "Secure S-01 hub gate is missing")
	if gate == null:
		return
	_check(not bool(gate.get("authorized")), "S-01 hub should start locked")
	paused = false
	game.player.global_position = Vector3(2.25, 0.95, -13.4)
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	await physics_frame
	await _frames(3)
	_check(bool(gate.get("authorized")), "S-01 hub badge interaction did not unlock the gate")
	_check(bool(game.get_meta("s01_hub_authorized_v21", false)), "S-01 authorization state was not recorded")

func _check_touch_layout() -> void:
	var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var occupied: Array[Dictionary] = [{"name": "HUD", "rect": game.responsive_ui_v20.hud.get_global_rect()}, {"name": "look", "rect": game.mobile_look_pad.get_global_rect()}]
	for node in game.mobile_layer.get_children():
		if node is TouchScreenButton:
			var touch := node as TouchScreenButton
			var size := (touch.shape as RectangleShape2D).size
			occupied.append({"name": str(touch.name), "rect": Rect2(touch.position - size * 0.5, size)})
		elif node is Button and (node as Button).text in ["TAB", "◉"]:
			occupied.append({"name": (node as Button).text, "rect": (node as Button).get_global_rect()})
	for index in range(occupied.size()):
		var rect: Rect2 = occupied[index]["rect"]
		_check(bounds.encloses(rect), "%s outside %s: %s" % [occupied[index]["name"], bounds.size, rect])
		for other in range(index + 1, occupied.size()):
			_check(not rect.intersects(occupied[other]["rect"]), "%s overlaps %s at %s" % [occupied[index]["name"], occupied[other]["name"], bounds.size])

func _check_routes() -> void:
	paused = false
	await physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.exclude = _dynamic_route_exclusions()
	query.collision_mask = 1
	var route_points := [
		Vector3(-6.2, 0.95, -15.45),
		Vector3(6.0, 0.95, -23.4), Vector3(6.0, 0.95, -22.5), Vector3(6.0, 0.95, -21.6),
		Vector3(-6.0, 0.95, -58.9), Vector3(-6.0, 0.95, -58.0), Vector3(-6.0, 0.95, -57.1),
		Vector3(5.5, 0.95, -92.9), Vector3(5.5, 0.95, -92.0), Vector3(5.5, 0.95, -91.1),
		Vector3(-5.5, 0.95, -126.9), Vector3(-5.5, 0.95, -126.0), Vector3(-5.5, 0.95, -125.1),
	]
	for point in route_points:
		query.transform = Transform3D(Basis.IDENTITY, point)
		var hits: Array[Dictionary] = game.get_world_3d().direct_space_state.intersect_shape(query)
		_check(hits.is_empty(), "Static architecture blocks v21 route at %s: %s" % [point, _hit_names(hits)])

	# Full crouch keeps the player origin near y=1.1 while the collision shape is
	# shifted down by 0.34 m, giving a collider centre around y=0.76 m.
	var crouch_capsule := CapsuleShape3D.new()
	crouch_capsule.radius = 0.34
	crouch_capsule.height = 1.08
	query.shape = crouch_capsule
	for z in [-126.0, -129.0, -132.0, -135.0]:
		query.transform = Transform3D(Basis.IDENTITY, Vector3(-14.05, 0.76, z))
		var crouch_hits: Array[Dictionary] = game.get_world_3d().direct_space_state.intersect_shape(query)
		_check(crouch_hits.is_empty(), "Static architecture blocks crouch route at z=%s: %s" % [z, _hit_names(crouch_hits)])
	_check_procedural_route_guard()

func _dynamic_route_exclusions() -> Array[RID]:
	var excluded: Array[RID] = [game.player.get_rid()]
	for candidate in game.find_children("*", "RigidBody3D", true, false):
		excluded.append((candidate as RigidBody3D).get_rid())
	for candidate in game.find_children("*", "CharacterBody3D", true, false):
		var body := candidate as CharacterBody3D
		if body != game.player:
			excluded.append(body.get_rid())
	return excluded

func _check_procedural_route_guard() -> void:
	var protected_routes: Array[Vector3] = [
		Vector3(6.0, 0.0, -22.5),
		Vector3(-6.0, 0.0, -58.0),
		Vector3(5.5, 0.0, -92.0),
		Vector3(-5.5, 0.0, -126.0),
	]
	for candidate in game.find_children("*", "RigidBody3D", true, false):
		var body := candidate as RigidBody3D
		var p := body.global_position
		var in_old_barrier := absf(p.z + 55.0) < 1.3 and absf(p.x) < 7.2
		_check(not in_old_barrier, "Dynamic prop still recreates the old z=-55 barrier: %s" % body.name)
		for route in protected_routes:
			var blocks := absf(p.z - route.z) < 3.8 and absf(p.x - route.x) < 3.8
			_check(not blocks, "Dynamic prop %s blocks guaranteed v21 route near %s" % [body.name, route])
		var blocks_crawl := absf(p.x + 14.05) < 1.55 and p.z < -123.6 and p.z > -136.4
		_check(not blocks_crawl, "Dynamic prop %s blocks M-04 crawlspace" % body.name)

func _hit_names(hits: Array[Dictionary]) -> String:
	var names: Array[String] = []
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Node:
			names.append(String((collider as Node).name))
		else:
			names.append(str(collider))
	return ", ".join(names)

func _check_dialog_text(panel: Control) -> void:
	for candidate in panel.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control is Label and control.is_visible_in_tree():
			_check(control.size.y >= 16, "Dialog text collapsed: " + (control as Label).text.left(30))
			_check(control.size.x >= 100, "Dialog label wraps letter by letter: " + (control as Label).text.left(30))
