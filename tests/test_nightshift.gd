extends SceneTree
var game: Node3D
var failures: Array[String] = []
var screenshots := not DisplayServer.get_name() == "headless"
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for i in range(count):
		await process_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("NIGHTSHIFT_FAIL " + message)
func capture(label: String) -> void:
	if screenshots:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/nightshift/%s.png" % label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/nightshift")
	root.size = Vector2i(1280,720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(100)
	game._start_game()
	game._finish_intro_v12()
	await frames(20)
	game.shift.restart()
	await frames(20)
	# Every robot must have an imported mesh and real clips after a clean import.
	for subject in game.robots:
		var visual: Node3D = subject.get_node_or_null("GeneratedVisual")
		check(visual != null, "imported robot visual " + subject.name)
		check(not subject.find_children("*", "AnimationPlayer", true, false).is_empty(), "imported animation player " + subject.name)
		if visual:
			var bridge = root.get_node("GeneratedAssetBridge").bridge
			var bounds: AABB = bridge._combined_aabb(visual)
			var bottom: float = visual.position.y + bounds.position.y * visual.scale.y
			var capsule: CapsuleShape3D = subject.get_node("GameplayCollision").shape
			check(absf(bottom + capsule.height * 0.5) < 0.08, "robot feet aligned to collision " + subject.name)
	var shift: Node = game.shift
	var nav: RefCounted = shift.navigation
	var audit: Array = nav.audit()
	var file := FileAccess.open("res://build/nightshift/navigation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(audit,"  "))
	file.close()
	check(audit.is_empty(), "structural route audit: " + str(audit.slice(0,8)))
	for key in nav.points:
		check(not nav.path(nav.points.HUB, nav.points[key], false).is_empty(), "disconnected room " + key)
	var cams: Node = game.fnaf_surveillance_v21
	check(not nav.clear_ray(Vector3(0,1,-24),Vector3(0,1,-85),nav._actors()), "old uninterrupted central spine removed")
	check(cams.camera_nodes.size() == 8, "eight live cameras")
	# Prudent profile: feed dwell, power drain, shutters and circuit isolation.
	cams.toggle_surveillance()
	shift.tick(2.1)
	cams.camera_index = 1
	shift.tick(2.1)
	check(shift.watched.size() == 2, "feed observation unlocks diagnosis")
	var before: float = cams.power
	cams._process(1.0)
	check(cams.power < before, "surveillance consumes electricity")
	shift.toggle_circuit()
	check(shift.circuit_isolated, "circuit control")
	await capture("10-camera-ui")
	cams.toggle_surveillance()
	# Speedrunner: cannot skip physical tasks or report remotely.
	shift.finish_at_hub()
	check(not game.win_panel.visible, "report rejects incomplete mission")
	# Explorer: actual CharacterBody movement around the loop, doors and rooms.
	game.set_physics_process(false)
	for robot_body in game.robots:
		robot_body.position = Vector3(-12, 1, -63)
	for door in shift.details.doors:
		door.opened = true
	await frames(100)
	var route := ["HUB","HL","WL","W1","LOGISTICS","W1","W2","ARCHIVES","W2","W3","MAINTENANCE","W3","NW","NE","R1","R2","RELAY","R2","R1","NE","E3","TEST","E3","E2","POWER","E2","E1","ASSEMBLY","E1","ER","HR","HUB"]
	game.player.position = nav.points.HUB
	for key in route:
		var destination: Vector3 = nav.points[key]
		for frame in range(240):
			var offset: Vector3 = destination - game.player.position
			offset.y = 0
			if offset.length() < 0.3:
				break
			game.player.velocity = offset.normalized() * 6
			game.player.velocity.y = -1
			game.player.move_and_slide()
			await physics_frame
		check(Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length() < 0.4, "physical walking blocked: " + key + " at " + str(game.player.position))
	# Aggressive: real breakable door loses health and moves out of its frame.
	var door: AnimatableBody3D = shift.details.doors[0]
	door.opened = false
	await frames(80)
	door.take_hit(80)
	await frames(90)
	check(door.broken and door.position.y > 4, "door destruction opens physical passage")
	check(shift.sound.events.get("DoorHit",0) > 0, "door animation sound emitted")
	# Panicked: noisy movement leaves only a heard location in enemy memory.
	var robot: CharacterBody3D = game.robots[0]
	robot.position = Vector3(-5.55,1,-45)
	shift.make_noise(Vector3(-5.55,1,-40), 12)
	check(shift.enemies.states[robot].memory > 0, "enemy hears physical noise")
	game.player.position = Vector3(5.55,1,-40)
	check(not shift.enemies._sees_player(robot), "opaque core prevents enemy wall vision")
	# M-04 opens by localized destruction and is traversable only in a crouch.
	for panel_name in ["SecretMaintenanceV21", "M04ExitGrille"]:
		for body in game.find_children(panel_name + "_Cell*", "StaticBody3D", true, false):
			game._damage_destructible(body, 500, body.global_position)
	await frames(12)
	game.player.position = Vector3(-5.55,0.95,-53)
	Input.action_press("crouch")
	for step in range(20):
		game._update_crouch_v19(0.05)
	for step in range(160):
		game.player.velocity = Vector3(4,-1,0)
		game.player.move_and_slide()
		await physics_frame
	check(game.player.position.x > 3.8, "M-04 physical crouched crossing " + str(game.player.position))
	Input.action_release("crouch")
	game.player.position = Vector3(0,0.95,-18)
	for step in range(20):
		game._update_crouch_v19(0.05)
	# A closed shutter must physically stop a pursuing robot.
	cams.left_closed = true
	await frames(90)
	robot.position = Vector3(-4.85,1,-23)
	for step in range(55):
		robot.velocity = Vector3(0,-1,4)
		robot.move_and_slide()
		await physics_frame
	check(robot.position.z < -21.4, "closed shutter blocks robot " + str(robot.position))
	cams.left_closed = false
	# Distinct imported and authored animation clips are playable.
	for clip in ["Idle", "Head scan", "Walk", "Limp", "Run", "Turn", "Door interaction", "Climb", "Attack", "Hit reaction", "Knockdown", "Recovery", "Shutdown"]:
		game._set_robot_animation(robot, clip)
		check(String(robot.get_meta("generated_animation", "")).contains(clip), "animation resolves " + clip)
		await frames(2)
	# Each mission completes only after its own physical tasks and returns to hub.
	for night in range(1,6):
		game.current_round = night
		shift.restart()
		shift.watched = {0:true,1:true}
		for key in shift.MISSIONS[night-1]:
			shift.interact(shift.details.interactables[key])
		shift.finish_at_hub()
		check(game.win_panel.visible, "night %d completes" % night)
	check(not shift.ending.is_empty(), "fifth night resolves a narrative ending")
	game.current_round = 1
	shift.restart()
	game.set_physics_process(false)
	for sample in [
		["01-hub",Vector3(0,0.95,-18),Vector3(0,1.4,-11.8)],
		["02-west-hall",Vector3(-5.55,0.95,-24),Vector3(-5.55,1.3,-45)],
		["03-logistics",Vector3(-8.7,0.95,-34),Vector3(-13,1.2,-28)],
		["04-east-hall",Vector3(5.55,0.95,-39),Vector3(5.55,1.4,-60)],
		["05-assembly",Vector3(9,0.95,-35),Vector3(12,1.5,-30)],
		["06-archives",Vector3(-9,0.95,-47),Vector3(-13,1.3,-42)],
		["07-power",Vector3(9,0.95,-48),Vector3(14,1.3,-44)],
		["08-relay",Vector3(0,0.95,-81),Vector3(0,1.3,-87.8)],
		["09-secret",Vector3(-2,0.35,-53),Vector3(0,0.7,-55)],
		["11-chase",Vector3(-5.55,0.95,-40),Vector3(-5.55,1.3,-45)],
		["12-destruction",Vector3(-5.55,0.95,-33.5),Vector3(-10,1.3,-33.5)]
	]:
		if sample[0] == "11-chase":
			robot.position = Vector3(-5.55,1,-44)
			robot.rotation.y = PI
			game._set_robot_animation(robot,"Run-loop")
		game.player.position = sample[1]
		game.camera.global_position = sample[1] + Vector3.UP * (0.35 if sample[0] == "09-secret" else 0.65)
		game.camera.look_at(sample[2])
		await frames(12)
		await capture(sample[0])
	root.size = Vector2i(390,844)
	game.player.position = Vector3(0,0.95,-18)
	cams.toggle_surveillance()
	await frames(20)
	var rect: Rect2 = cams.ui_frame.get_global_rect()
	check(rect.position.x >= 0 and rect.end.x <= 391 and rect.end.y <= 845, "mobile CCTV fits viewport " + str(rect))
	for button in cams.ui_frame.find_children("*","Button",true,false):
		check(button.size.y >= 43, "mobile button hit area: " + button.text)
	await capture("13-mobile-camera")
	cams.toggle_surveillance()
	await frames(10)
	await capture("14-mobile-hud")
	root.size = Vector2i(1280,720)
	var forge: Node = root.get_node("WorldForgeRuntime")
	forge.set_developer_mode(true)
	forge.open_developer_editor()
	await frames(12)
	var editor_rect: Rect2 = forge.developer_editor.panel.get_global_rect()
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(editor_rect), "editor panel fits viewport " + str(editor_rect))
	check(forge.developer_editor._asset_ids.size() >= 2, "editor catalogue loaded")
	check(forge.developer_editor.room_selector.item_count >= 9, "editor room selection")
	var obstruction: StaticBody3D = game.fnaf_factory_v21._static_box(game,Vector3(1,2,1),Vector3(-5.55,1,-30),game.visuals_v20.surface("paint"),"AuditProbe")
	await physics_frame
	var detected: Array = game.shift.navigation.audit()
	check(not detected.is_empty(), "audit detects an introduced blocked passage")
	obstruction.queue_free()
	var floating := MeshInstance3D.new()
	floating.mesh = BoxMesh.new()
	floating.position = Vector3(13,3,-28)
	floating.set_meta("worldforge_generated",true)
	floating.set_meta("worldforge_floor_bound",true)
	floating.set_meta("size",Vector3.ONE)
	game.add_child(floating)
	forge.run_audit(true)
	check(absf(floating.position.y-0.5)<0.01, "auto fix restores unsupported floor object")
	floating.queue_free()
	await frames(3)
	forge.developer_editor._audit()
	var audit_file := FileAccess.open("res://build/nightshift/editor-audit.json",FileAccess.WRITE)
	audit_file.store_string(JSON.stringify(forge.last_report,"  "))
	audit_file.close()
	await capture("15-editor-audit")
	forge.developer_editor.hide()
	if screenshots:
		var performance := FileAccess.open("res://build/nightshift/performance.json",FileAccess.WRITE)
		performance.store_string(JSON.stringify({"fps":Engine.get_frames_per_second(), "renderer":RenderingServer.get_video_adapter_name(), "objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "note":"Native automation; not a physical phone measurement"}))
		performance.close()
	print("NIGHTSHIFT_TESTS ", "PASS" if failures.is_empty() else failures)
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
