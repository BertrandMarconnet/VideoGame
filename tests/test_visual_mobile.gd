extends SceneTree
## Integration checks against the actual scene, physics and responsive controls.
## Run with --headless --script res://tests/test_visual_mobile.gd -- --touch-ui.
## With a display, this also saves real game captures under build/visual-v20/.

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
		push_error("V20_CHECK_FAILED " + message)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/visual-v20")
	root.get_texture().get_image().save_png("res://build/visual-v20/%s.png" % label)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	await _frames(65)
	_check(game.has_node("IndustrialVisualsV20"), "Industrial world did not load")
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
	for sample in [
		{"name": "exterior", "at": Vector3(4, 0.95, 17), "yaw": -12.0},
		{"name": "airlock", "at": Vector3(10.5, 0.95, -2.6), "yaw": 0.0},
		{"name": "corridor", "at": Vector3(0, 0.95, -20.1), "yaw": 0.0},
		{"name": "assembly", "at": Vector3(-2.5, 0.95, -67), "yaw": 30.0},
		{"name": "maintenance", "at": Vector3(-12, 0.95, -26.8), "yaw": 68.0},
	]:
		game.player.global_position = sample["at"]
		game.player.rotation_degrees = Vector3(0, float(sample["yaw"]), 0)
		game.camera.rotation = Vector3.ZERO
		await _frames(10)
		await _capture(String(sample["name"]))
	await _check_corridors()
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
	print("V20_VISUAL_MOBILE_CHECKS ", "PASS" if failures.is_empty() else failures)
	game.queue_free()
	game = null
	await _frames(3)
	quit(0 if failures.is_empty() else 1)

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

func _check_corridors() -> void:
	paused = false
	await physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.exclude = [game.player.get_rid()]
	query.collision_mask = 1
	for z in [-22.5, -58.0, -92.0, -126.0]:
		for offset in [-1.0, 0.0, 1.0]:
			query.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.95, z + offset))
			var hits: Array[Dictionary] = game.get_world_3d().direct_space_state.intersect_shape(query)
			_check(hits.is_empty(), "Player capsule blocked in corridor at z=%s" % (z + offset))

func _check_dialog_text(panel: Control) -> void:
	for candidate in panel.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control is Label and control.is_visible_in_tree():
			_check(control.size.y >= 16, "Dialog text collapsed: " + (control as Label).text.left(30))
			_check(control.size.x >= 100, "Dialog label wraps letter by letter: " + (control as Label).text.left(30))
