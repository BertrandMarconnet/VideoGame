extends Node
## FNAF-inspired surveillance loop for the final v21 factory.
## One live camera feed is rendered at a low Web-friendly resolution. The player
## trades electrical power for information and for two physical hub shutters.

var game: Node3D
var player: CharacterBody3D
var surveillance_open := false
var power := 100.0
var camera_index := 0
var camera_view: SubViewport
var camera_3d: Camera3D
var overlay: Control
var feed: TextureRect
var cam_label: Label
var power_label: Label
var threat_label: Label
var story_label: Label
var cam_button: Button
var ui_frame: VBoxContainer
var left_shutter: AnimatableBody3D
var right_shutter: AnimatableBody3D
var left_closed := false
var right_closed := false
var alert_cooldown := 0.0
var _saved_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _worldforge_generation_id := 0

var camera_nodes: Array[Dictionary] = [
	{"name":"CAM 01 // S-01", "position":Vector3(0.0, 2.7, -18.8), "look":Vector3(0.0, 1.2, -13.0)},
	{"name":"CAM 02 // WEST HALL", "position":Vector3(-5.5, 2.8, -28.0), "look":Vector3(-5.5, 1.0, -44.0)},
	{"name":"CAM 03 // LOGISTICS", "position":Vector3(-13.8, 2.7, -27.0), "look":Vector3(-10.8, 1.0, -33.0)},
	{"name":"CAM 04 // ARCHIVES", "position":Vector3(-13.8, 2.7, -42.0), "look":Vector3(-10.8, 1.0, -48.0)},
	{"name":"CAM 05 // EAST HALL", "position":Vector3(5.5, 2.8, -28.0), "look":Vector3(5.5, 1.0, -44.0)},
	{"name":"CAM 06 // ASSEMBLY", "position":Vector3(13.8, 2.7, -27.0), "look":Vector3(10.8, 1.0, -33.0)},
	{"name":"CAM 07 // POWER", "position":Vector3(13.8, 2.7, -43.0), "look":Vector3(10.8, 1.0, -48.0)},
	{"name":"CAM 08 // NORTH RELAY", "position":Vector3(4.8, 2.8, -78.0), "look":Vector3(0.0, 1.0, -84.0)},
]

var route_nodes := {
	"HUB_L": Vector3(-4.8, 1.0, -22.8),
	"HUB_R": Vector3(4.8, 1.0, -22.8),
	"W1": Vector3(-5.5, 1.0, -31.0),
	"W2": Vector3(-5.5, 1.0, -45.0),
	"W3": Vector3(-5.5, 1.0, -61.0),
	"NW": Vector3(-5.5, 1.0, -69.0),
	"NE": Vector3(5.5, 1.0, -69.0),
	"E3": Vector3(5.5, 1.0, -61.0),
	"E2": Vector3(5.5, 1.0, -45.0),
	"E1": Vector3(5.5, 1.0, -31.0),
	"RELAY_TURN": Vector3(6.0, 1.0, -74.0),
	"RELAY": Vector3(0.0, 1.0, -84.0),
}

var route_edges := {
	"HUB_L": ["W1"], "W1": ["HUB_L", "W2"], "W2": ["W1", "W3"],
	"W3": ["W2", "NW"], "NW": ["W3", "NE"],
	"NE": ["NW", "E3", "RELAY_TURN"], "E3": ["NE", "E2"],
	"E2": ["E3", "E1"], "E1": ["E2", "HUB_R"], "HUB_R": ["E1"],
	"RELAY_TURN": ["NE", "RELAY"], "RELAY": ["RELAY_TURN"],
}

func configure(game_scene: Node3D) -> void:
	game = game_scene
	player = game.get("player") as CharacterBody3D
	name = "FNAFSurveillanceV21"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_input()
	_open_hub_halls()
	_build_shutters()
	_build_camera_view()
	_build_ui()
	game.set_meta("fnaf_surveillance_open", false)
	game.set_meta("fnaf_power_v21", power)
	print("BLACKOUT_FNAF_SURVEILLANCE_V21_READY")

func _open_hub_halls() -> void:
	# The new hub uses two lateral approaches. Remove only the obsolete outer
	# pieces of the former north wall so the left/right hall openings are broad,
	# visible and never read as a wall dropped in the middle of the corridor.
	for label in ["HubNorthOuterLeftV21", "HubNorthOuterRightV21"]:
		var wall := game.find_child(label, true, false)
		if wall is Node3D:
			(wall as Node3D).queue_free()

func _install_input() -> void:
	if not InputMap.has_action("camera_network"):
		InputMap.add_action("camera_network")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	InputMap.action_add_event("camera_network", key)

func _build_shutters() -> void:
	left_shutter = _make_shutter("HubLeftShutterV21", Vector3(-4.85, 5.2, -21.36))
	right_shutter = _make_shutter("HubRightShutterV21", Vector3(4.85, 5.2, -21.36))
	game.add_child(left_shutter)
	game.add_child(right_shutter)

func _make_shutter(label: String, at: Vector3) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = label
	body.position = at
	body.sync_to_physics = true
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("fnaf_shutter", true)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.65, 3.35, 0.28)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var box := BoxMesh.new()
	box.size = Vector3(2.65, 3.35, 0.24)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.095, 0.105, 0.11)
	material.metallic = 0.88
	material.roughness = 0.42
	mesh.material_override = material
	body.add_child(mesh)
	return body

func _build_camera_view() -> void:
	camera_view = SubViewport.new()
	camera_view.name = "SecurityFeedViewportV21"
	camera_view.size = Vector2i(512, 288)
	camera_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	camera_view.world_3d = game.get_world_3d()
	add_child(camera_view)
	camera_3d = Camera3D.new()
	camera_3d.name = "SecurityCameraV21"
	camera_3d.fov = 68.0
	camera_3d.far = 120.0
	camera_view.add_child(camera_3d)
	_apply_camera_node()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FNAFSurveillanceUIV21"
	layer.layer = 240
	add_child(layer)
	cam_button = Button.new()
	cam_button.text = "CAM"
	cam_button.name = "CameraNetworkButtonV21"
	cam_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cam_button.position = Vector2(-112.0, 20.0)
	cam_button.size = Vector2(92.0, 52.0)
	cam_button.focus_mode = Control.FOCUS_NONE
	cam_button.pressed.connect(toggle_surveillance)
	layer.add_child(cam_button)
	overlay = Control.new()
	overlay.name = "CameraOverlayV21"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.005, 0.008, 0.01, 0.93)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(backdrop)
	ui_frame = VBoxContainer.new()
	ui_frame.set_anchors_preset(Control.PRESET_CENTER)
	ui_frame.size = Vector2(720.0, 500.0)
	ui_frame.custom_minimum_size = Vector2(720.0, 500.0)
	overlay.add_child(ui_frame)
	var header := HBoxContainer.new()
	ui_frame.add_child(header)
	cam_label = Label.new()
	cam_label.text = "CAM 01 // S-01"
	cam_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cam_label.add_theme_font_size_override("font_size", 18)
	header.add_child(cam_label)
	power_label = Label.new()
	power_label.text = "POWER 100%"
	power_label.add_theme_font_size_override("font_size", 18)
	header.add_child(power_label)
	feed = TextureRect.new()
	feed.custom_minimum_size = Vector2(720.0, 405.0)
	feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	feed.texture = camera_view.get_texture()
	ui_frame.add_child(feed)
	threat_label = Label.new()
	threat_label.text = "MOTION // NONE"
	threat_label.add_theme_font_size_override("font_size", 15)
	ui_frame.add_child(threat_label)
	story_label = Label.new()
	story_label.text = "S-01: surveillez les halls. Ne laissez pas les deux accès sans contrôle."
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.add_theme_font_size_override("font_size", 14)
	ui_frame.add_child(story_label)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	ui_frame.add_child(controls)
	_add_button(controls, "◀ CAM", previous_camera)
	_add_button(controls, "CAM ▶", next_camera)
	_add_button(controls, "LOCK L", toggle_left_shutter)
	_add_button(controls, "LOCK R", toggle_right_shutter)
	_add_button(controls, "FERMER", toggle_surveillance)
	_reflow_overlay()

func _add_button(parent: Control, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(112.0, 46.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if not _game_active():
		return
	if event.is_action_pressed("camera_network"):
		toggle_surveillance()
		get_viewport().set_input_as_handled()
		return
	if not surveillance_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			previous_camera()
		elif event.keycode == KEY_E:
			next_camera()
		elif event.keycode == KEY_1:
			toggle_left_shutter()
		elif event.keycode == KEY_2:
			toggle_right_shutter()

func _process(delta: float) -> void:
	_reconcile_worldforge_if_needed()
	cam_button.visible = _game_active() and not get_tree().paused
	alert_cooldown = maxf(0.0, alert_cooldown - delta)
	if not _game_active():
		if surveillance_open:
			_close_surveillance()
		return
	if surveillance_open and player:
		for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "crouch"]:
			Input.action_release(action)
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		_reflow_overlay()
	var drain := 0.012
	if surveillance_open:
		drain += 0.065
	if left_closed:
		drain += 0.085
	if right_closed:
		drain += 0.085
	power = maxf(0.0, power - drain * delta * (1.0 + float(game.get("current_round")) * 0.12))
	if power <= 0.0:
		left_closed = false
		right_closed = false
		if surveillance_open:
			_close_surveillance()
		if alert_cooldown <= 0.0 and game.has_method("_show_status"):
			alert_cooldown = 5.0
			game.call("_show_status", "S-01 // POWER FAILURE — shutters released.")
	_update_shutter(left_shutter, left_closed, delta)
	_update_shutter(right_shutter, right_closed, delta)
	game.set_meta("fnaf_power_v21", power)
	if surveillance_open:
		_update_overlay()
	_check_hub_threat()

func _reflow_overlay() -> void:
	if ui_frame == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_value := minf(1.0, minf(viewport_size.x / 760.0, viewport_size.y / 550.0))
	ui_frame.scale = Vector2.ONE * scale_value
	ui_frame.position = -ui_frame.size * 0.5 * scale_value

func _game_active() -> bool:
	if game == null or not is_instance_valid(game):
		return false
	var value = game.get("game_started")
	return bool(value) if value != null else false

func toggle_surveillance() -> void:
	if not surveillance_open:
		_open_surveillance()
	else:
		_close_surveillance()

func _open_surveillance() -> void:
	if not _game_active() or get_tree().paused or power <= 0.0:
		return
	surveillance_open = true
	game.set_meta("fnaf_surveillance_open", true)
	overlay.visible = true
	camera_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_saved_mouse_mode = Input.mouse_mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_camera_node()
	if game.has_method("_show_status"):
		game.call("_show_status", "SENTINEL // réseau caméra actif — consommation électrique accrue.")

func _close_surveillance() -> void:
	surveillance_open = false
	game.set_meta("fnaf_surveillance_open", false)
	overlay.visible = false
	camera_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _game_active() and not get_tree().paused:
		Input.set_mouse_mode(_saved_mouse_mode)

func previous_camera() -> void:
	camera_index = wrapi(camera_index - 1, 0, camera_nodes.size())
	_apply_camera_node()

func next_camera() -> void:
	camera_index = wrapi(camera_index + 1, 0, camera_nodes.size())
	_apply_camera_node()

func _apply_camera_node() -> void:
	if camera_3d == null or camera_nodes.is_empty():
		return
	var data := camera_nodes[camera_index]
	camera_3d.global_position = data["position"] as Vector3
	camera_3d.look_at(data["look"] as Vector3, Vector3.UP)
	if cam_label:
		cam_label.text = String(data["name"])

func toggle_left_shutter() -> void:
	if power > 0.0:
		left_closed = not left_closed

func toggle_right_shutter() -> void:
	if power > 0.0:
		right_closed = not right_closed

func _update_shutter(shutter: AnimatableBody3D, closed: bool, delta: float) -> void:
	if shutter == null:
		return
	var target_y := 1.7 if closed else 5.2
	var p := shutter.position
	p.y = move_toward(p.y, target_y, delta * 4.4)
	shutter.position = p

func _update_overlay() -> void:
	power_label.text = "POWER %03d%%" % int(power)
	var closest := 999.0
	var closest_name := "NONE"
	for robot in game.get("robots"):
		if robot is Node3D and is_instance_valid(robot) and (robot as Node3D).visible:
			var distance := (robot as Node3D).global_position.distance_to(camera_3d.global_position)
			if distance < closest:
				closest = distance
				closest_name = String((robot as Node3D).name)
	threat_label.text = "MOTION // %s // %02d m" % [closest_name, int(closest)] if closest < 40.0 else "MOTION // NONE"
	var round_value := int(game.get("current_round"))
	match round_value:
		1:
			story_label.text = "RONDE 1 // Calibrez les caméras et activez le relais nord. Les mouvements cessent lorsqu'ils sont observés."
		2:
			story_label.text = "RONDE 2 // ATHENA teste vos habitudes. Évitez de garder toujours la même caméra ouverte."
		3:
			story_label.text = "RONDE 3 // CRAWLER-7 privilégie les angles morts et les halls non verrouillés."
		4:
			story_label.text = "RONDE 4 // Les dégâts et la fatigue rendent certains signaux caméra peu fiables."
		_:
			story_label.text = "RONDE 5 // DELTA approche. Gérez le peu d'énergie restant et choisissez quand quitter S-01."

func _check_hub_threat() -> void:
	if alert_cooldown > 0.0 or player == null:
		return
	for robot in game.get("robots"):
		if not robot is Node3D or not is_instance_valid(robot):
			continue
		var p := (robot as Node3D).global_position
		if p.z > -28.0 and absf(p.x) < 8.0:
			var protected := (p.x < 0.0 and left_closed) or (p.x >= 0.0 and right_closed)
			if not protected:
				alert_cooldown = 3.2
				if game.has_method("_show_status"):
					game.call("_show_status", "S-01 // PROXIMITY ALERT — un hall est ouvert.")
				return

func is_robot_observed(robot: Node3D) -> bool:
	if not surveillance_open or camera_3d == null or robot == null or not robot.visible:
		return false
	var to_robot := robot.global_position - camera_3d.global_position
	if to_robot.length() > 34.0:
		return false
	var forward := -camera_3d.global_transform.basis.z
	if forward.dot(to_robot.normalized()) < 0.62:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera_3d.global_position, robot.global_position + Vector3.UP * 0.4)
	if player:
		query.exclude = [player.get_rid()]
	var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == robot

func next_route_target(from_position: Vector3, target_position: Vector3) -> Vector3:
	var start := _nearest_route_node(from_position)
	var goal := _nearest_route_node(target_position)
	if start == goal:
		return target_position
	var queue: Array[String] = [start]
	var came_from := {start: ""}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == goal:
			break
		for neighbor_variant in route_edges.get(current, []):
			var neighbor := String(neighbor_variant)
			if came_from.has(neighbor):
				continue
			came_from[neighbor] = current
			queue.append(neighbor)
	if not came_from.has(goal):
		return target_position
	var step := goal
	while String(came_from.get(step, "")) != start and String(came_from.get(step, "")) != "":
		step = String(came_from[step])
	return route_nodes.get(step, target_position) as Vector3

func _nearest_route_node(position_value: Vector3) -> String:
	var best := "HUB_L"
	var best_distance := INF
	for key in route_nodes.keys():
		var distance := position_value.distance_squared_to(route_nodes[key] as Vector3)
		if distance < best_distance:
			best_distance = distance
			best = String(key)
	return best

func _reconcile_worldforge_if_needed() -> void:
	if game == null:
		return
	var generated := game.get_node_or_null("WorldForgeGenerated")
	if generated == null:
		return
	var generation_id := generated.get_instance_id()
	if generation_id == _worldforge_generation_id:
		return
	_worldforge_generation_id = generation_id
	for node in game.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if bool(body.get_meta("worldforge_generated", false)) and _blocks_route(body.global_position, body.get_meta("size", Vector3.ONE) as Vector3):
			body.queue_free()
	var slot_index := 0
	for node in game.find_children("*", "RigidBody3D", true, false):
		var body := node as RigidBody3D
		var size := body.get_meta("size", Vector3.ONE) as Vector3
		if not _blocks_route(body.global_position, size):
			continue
		var side := -12.2 if slot_index % 2 == 0 else 12.2
		body.global_position = Vector3(side, maxf(body.global_position.y, 0.8), -30.0 - float(slot_index % 6) * 6.0)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		slot_index += 1
	game.set_meta("fnaf_worldforge_reconciled_v21", true)

func _blocks_route(p: Vector3, size: Vector3) -> bool:
	var margin_x := size.x * 0.5 + 0.45
	var margin_z := size.z * 0.5 + 0.45
	var in_hub := absf(p.x) < 7.0 + margin_x and p.z < -10.0 + margin_z and p.z > -22.0 - margin_z
	var west_hall := absf(p.x + 5.55) < 2.1 + margin_x and p.z < -21.0 + margin_z and p.z > -67.0 - margin_z
	var east_hall := absf(p.x - 5.55) < 2.1 + margin_x and p.z < -21.0 + margin_z and p.z > -67.0 - margin_z
	var north_cross := absf(p.z + 69.0) < 2.7 + margin_z and absf(p.x) < 9.0 + margin_x
	var relay_approach := absf(p.x - 6.0) < 2.3 + margin_x and p.z < -68.0 + margin_z and p.z > -81.0 - margin_z
	return in_hub or west_hall or east_hall or north_cross or relay_approach
