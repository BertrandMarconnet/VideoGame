class_name FactoryGenerator
extends Node3D

signal console_activated(console_id: String)
signal structure_changed(description: String)

var rng := RandomNumberGenerator.new()
var astar := AStar3D.new()
var nav_positions: Dictionary = {}
var dynamic_links: Dictionary = {}
var spawn_points: Dictionary = {}
var semantic_rooms: Array[Node3D] = []
var consoles: Dictionary = {}
var breached_positions: Array[Vector3] = []
var layout_variant := 0

var mat_floor: StandardMaterial3D
var mat_wall: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_rust: StandardMaterial3D
var mat_safety: StandardMaterial3D
var mat_screen: StandardMaterial3D
var mat_glass: StandardMaterial3D

func generate(seed_value: int) -> void:
	rng.seed = seed_value
	layout_variant = absi(seed_value) % 3
	_create_materials()
	_create_shell()
	_create_navigation_graph()
	_create_control_room()
	_create_sector_logistics()
	_create_sector_assembly()
	_create_sector_archives()
	_create_sector_foundry()
	_create_secret_route()
	_create_lights()
	spawn_points["player"] = Vector3(0.0, 1.0, 9.0)
	spawn_points["specter"] = Vector3(-8.0, 0.0, -62.0)
	spawn_points["crawler"] = Vector3(8.0, 0.0, -116.0)
	spawn_points["ram"] = Vector3(0.0, 0.0, -151.0)
	spawn_points["mimic"] = Vector3(10.0, 0.0, -88.0)

func get_spawn_position(id: String) -> Vector3:
	return spawn_points.get(id, Vector3.ZERO)

func get_semantic_rooms() -> Array[Node3D]:
	return semantic_rooms

func get_console(id: String) -> ControlConsole:
	return consoles.get(id) as ControlConsole

func get_path(from_position: Vector3, to_position: Vector3) -> PackedVector3Array:
	if astar.get_point_count() == 0:
		return PackedVector3Array([to_position])
	var from_id := astar.get_closest_point(from_position)
	var to_id := astar.get_closest_point(to_position)
	var path := astar.get_point_path(from_id, to_id)
	if path.is_empty():
		return PackedVector3Array([to_position])
	return path

func get_stalking_point(player_position: Vector3, min_distance: float = 12.0) -> Vector3:
	var best := Vector3(0.0, 0.0, -30.0)
	var best_score := -99999.0
	for key in nav_positions:
		var point: Vector3 = nav_positions[key]
		var dist := point.distance_to(player_position)
		if dist < min_distance or dist > 35.0:
			continue
		var score := dist + rng.randf_range(-8.0, 8.0)
		if score > best_score:
			best_score = score
			best = point
	return best

func open_dynamic_link(link_id: String) -> void:
	if not dynamic_links.has(link_id):
		return
	var data: Array = dynamic_links[link_id]
	var a: int = data[0]
	var b: int = data[1]
	if not astar.are_points_connected(a, b):
		astar.connect_points(a, b, true)
	breached_positions.append((astar.get_point_position(a) + astar.get_point_position(b)) * 0.5)
	structure_changed.emit("Une brèche modifie les itinéraires des unités.")

func repair_nearest_breach(player_position: Vector3, held: GrabbableProp) -> bool:
	if held == null or breached_positions.is_empty():
		return false
	var nearest := breached_positions[0]
	var best := player_position.distance_to(nearest)
	for point in breached_positions:
		var distance := player_position.distance_to(point)
		if distance < best:
			best = distance
			nearest = point
	if best > 4.0:
		return false
	var panel := DestructiblePanel.new()
	panel.configure(self, "", Vector3(2.0, 2.4, 0.24), nearest + Vector3.UP * 1.2, mat_rust, "metal")
	panel.max_health = 55.0 + held.mass * 2.0
	panel.health = panel.max_health
	add_child(panel)
	held.queue_free()
	breached_positions.erase(nearest)
	structure_changed.emit("Brèche condamnée avec un élément du décor.")
	return true

func create_runtime_prop(kind: String, at: Vector3) -> GrabbableProp:
	var prop := GrabbableProp.new()
	var size := Vector3(0.7, 0.6, 0.7)
	var mass_value := 9.0
	var mat: Material = mat_metal
	match kind:
		"crate":
			size = Vector3(0.78, 0.62, 0.78); mass_value = 13.0; mat = mat_dark
		"toolbox":
			size = Vector3(0.52, 0.28, 0.32); mass_value = 6.0; mat = mat_rust
		"pipe":
			size = Vector3(0.18, 0.18, 1.45); mass_value = 8.0; mat = mat_metal
		"panel":
			size = Vector3(1.0, 0.12, 0.75); mass_value = 12.0; mat = mat_rust
	prop.configure(kind, size, mat, mass_value)
	add_child(prop)
	prop.global_position = at
	return prop

func _create_materials() -> void:
	mat_floor = WorldUtil.material(Color(0.085, 0.095, 0.105), 0.28, 0.78)
	mat_wall = WorldUtil.material(Color(0.17, 0.19, 0.205), 0.10, 0.72)
	mat_metal = WorldUtil.material(Color(0.22, 0.24, 0.26), 0.78, 0.30)
	mat_dark = WorldUtil.material(Color(0.055, 0.065, 0.075), 0.55, 0.48)
	mat_rust = WorldUtil.material(Color(0.33, 0.105, 0.045), 0.35, 0.77)
	mat_safety = WorldUtil.material(Color(0.82, 0.39, 0.035), 0.26, 0.52)
	mat_screen = WorldUtil.material(Color(0.01, 0.05, 0.065), 0.15, 0.25, Color(0.05, 0.75, 1.0), 2.2)
	mat_glass = WorldUtil.material(Color(0.18, 0.38, 0.46, 0.28), 0.05, 0.08)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_floor.uv1_scale = Vector3(8.0, 8.0, 8.0)
	mat_wall.uv1_scale = Vector3(4.0, 4.0, 4.0)
	mat_metal.uv1_scale = Vector3(3.0, 3.0, 3.0)
	mat_safety.uv1_scale = Vector3(2.0, 2.0, 2.0)

func _create_shell() -> void:
	WorldUtil.static_box(self, "Floor", Vector3(36.0, 1.0, 182.0), Vector3(0.0, -0.5, -73.0), mat_floor)
	WorldUtil.static_box(self, "WestOuter", Vector3(1.0, 7.0, 182.0), Vector3(-18.5, 3.0, -73.0), mat_wall)
	WorldUtil.static_box(self, "EastOuter", Vector3(1.0, 7.0, 182.0), Vector3(18.5, 3.0, -73.0), mat_wall)
	WorldUtil.static_box(self, "SouthOuter", Vector3(38.0, 7.0, 1.0), Vector3(0.0, 3.0, 18.0), mat_wall)
	WorldUtil.static_box(self, "NorthOuter", Vector3(38.0, 7.0, 1.0), Vector3(0.0, 3.0, -164.0), mat_wall)
	for z in range(14, -162, -8):
		WorldUtil.static_box(self, "CeilingBeam_%d" % z, Vector3(36.0, 0.22, 0.32), Vector3(0.0, 5.7, float(z)), mat_dark, false)

func _create_navigation_graph() -> void:
	var id := 0
	for z in range(10, -158, -8):
		for x in [-10.0, 0.0, 10.0]:
			var point := Vector3(x, 0.0, float(z))
			astar.add_point(id, point)
			nav_positions[id] = point
			id += 1
	var rows := 21
	for row in range(rows):
		for col in range(3):
			var current := row * 3 + col
			if col < 2:
				astar.connect_points(current, current + 1, true)
			if row < rows - 1:
				astar.connect_points(current, current + 3, true)
	dynamic_links["secret_archive"] = [25, 35]

func _semantic_room(node_name: String, semantic: String, at: Vector3, size: Vector3) -> Node3D:
	var room := Node3D.new()
	room.name = node_name
	room.position = at
	room.set_meta("semantic_type", semantic)
	room.set_meta("size", size)
	add_child(room)
	semantic_rooms.append(room)
	return room

func _create_control_room() -> void:
	var room := _semantic_room("S01_ControlRoom", "control_room", Vector3(0.0, 0.0, 7.0), Vector3(20.0, 5.0, 18.0))
	WorldUtil.static_box(room, "WestWall", Vector3(0.4, 5.0, 18.0), Vector3(-10.0, 2.5, 0.0), mat_wall)
	WorldUtil.static_box(room, "EastWall", Vector3(0.4, 5.0, 18.0), Vector3(10.0, 2.5, 0.0), mat_wall)
	WorldUtil.static_box(room, "NorthWallA", Vector3(7.0, 5.0, 0.4), Vector3(-6.5, 2.5, -9.0), mat_wall)
	WorldUtil.static_box(room, "NorthWallB", Vector3(7.0, 5.0, 0.4), Vector3(6.5, 2.5, -9.0), mat_wall)
	for i in range(5):
		var desk := WorldUtil.static_box(room, "Desk_%d" % i, Vector3(2.4, 0.85, 0.9), Vector3(-6.0 + i * 3.0, 0.43, 2.2), mat_dark)
		var screen := WorldUtil.box_mesh(Vector3(1.55, 0.72, 0.06), mat_screen)
		screen.position = Vector3(0.0, 0.88, -0.35)
		desk.add_child(screen)
	_create_console("briefing", "ÉCRAN DE RONDE", Vector3(-5.8, 0.58, 11.0), PI)
	_create_console("door_control", "PORTE S-01", Vector3(0.0, 0.58, 11.0), PI)
	_create_console("uplink", "UPLINK BLACKOUT", Vector3(5.8, 0.58, 11.0), PI)
	WorldUtil.static_box(room, "ServerRackA", Vector3(2.0, 3.3, 1.1), Vector3(-8.5, 1.65, -4.8), mat_dark)
	WorldUtil.static_box(room, "ServerRackB", Vector3(2.0, 3.3, 1.1), Vector3(8.5, 1.65, -4.8), mat_dark)

func _create_sector_logistics() -> void:
	var room := _semantic_room("Logistics", "logistics", Vector3(0.0, 0.0, -25.0), Vector3(34.0, 5.0, 34.0))
	for side in [-1.0, 1.0]:
		for i in range(5):
			_create_rack(room, Vector3(side * 12.5, 0.0, -11.0 + i * 6.0))
	for i in range(10):
		create_runtime_prop("crate" if i % 2 == 0 else "toolbox", Vector3(rng.randf_range(-13.0, 13.0), 0.7, rng.randf_range(-39.0, -12.0)))
	WorldUtil.static_box(room, "LoadingGate", Vector3(7.0, 4.0, 0.35), Vector3(0.0, 2.0, -17.0), mat_dark)

func _create_sector_assembly() -> void:
	var room := _semantic_room("Assembly", "assembly", Vector3(0.0, 0.0, -66.0), Vector3(34.0, 5.0, 42.0))
	for lane in [-8.5, 0.0, 8.5]:
		for i in range(5):
			_create_conveyor(room, Vector3(lane, 0.5, -16.0 + i * 8.0))
	for i in range(8):
		_create_robot_arm(room, Vector3(-13.0 if i % 2 == 0 else 13.0, 0.0, -17.0 + i * 4.8))
	var relay_a_x := -12.5 if layout_variant != 1 else 12.5
	var relay_a_facing := PI * 0.5 if relay_a_x < 0.0 else -PI * 0.5
	_create_console("relay_a", "RELAIS A", Vector3(relay_a_x, 0.58, -47.0), relay_a_facing)
	for i in range(6):
		create_runtime_prop("pipe" if i % 2 else "panel", Vector3(rng.randf_range(-11.0, 11.0), 0.9, rng.randf_range(-82.0, -51.0)))

func _create_sector_archives() -> void:
	var room := _semantic_room("Archives", "archives", Vector3(0.0, 0.0, -103.0), Vector3(34.0, 5.0, 28.0))
	for x in [-12.0, -7.0, 7.0, 12.0]:
		for z in [-10.0, -3.5, 3.5, 10.0]:
			_create_rack(room, Vector3(x, 0.0, z))
	var recorder_x := [-7.5, 0.0, 7.5][layout_variant]
	_create_console("black_box", "ENREGISTREUR NOIR", Vector3(recorder_x, 0.58, -103.0), 0.0)
	WorldUtil.static_box(room, "ArchiveCage", Vector3(7.0, 3.2, 0.2), Vector3(0.0, 1.6, 10.5), mat_glass)

func _create_sector_foundry() -> void:
	var room := _semantic_room("Foundry", "foundry", Vector3(0.0, 0.0, -140.0), Vector3(34.0, 5.0, 38.0))
	for x in [-10.0, 10.0]:
		for z in [-13.0, 0.0, 13.0]:
			_create_press(room, Vector3(x, 0.0, z))
	var relay_b_x := 12.5 if layout_variant == 0 else -12.5
	var relay_b_facing := -PI * 0.5 if relay_b_x > 0.0 else PI * 0.5
	_create_console("relay_b", "RELAIS B", Vector3(relay_b_x, 0.58, -148.0), relay_b_facing)
	for i in range(8):
		create_runtime_prop("panel" if i % 3 == 0 else "crate", Vector3(rng.randf_range(-13.0, 13.0), 0.8, rng.randf_range(-157.0, -126.0)))

func _create_secret_route() -> void:
	var panel := DestructiblePanel.new()
	panel.name = "SecretArchivePanel"
	var secret_x := -9.7 if layout_variant != 2 else 9.7
	panel.configure(self, "secret_archive", Vector3(3.0, 3.2, 0.34), Vector3(secret_x, 1.6, -91.0), mat_wall, "concrete")
	add_child(panel)
	add_child(WorldUtil.label3d("ACCÈS TECHNIQUE M-04", Vector3(secret_x, 3.55, -90.75), Color(0.9, 0.4, 0.12), 20))

func _create_console(id_value: String, title: String, at: Vector3, facing: float) -> void:
	var console := ControlConsole.new()
	console.configure(id_value, title, at, facing)
	add_child(console)
	console.activated.connect(_on_console_activated)
	consoles[id_value] = console

func _on_console_activated(id_value: String) -> void:
	console_activated.emit(id_value)

func _create_rack(parent: Node3D, at: Vector3) -> void:
	WorldUtil.static_box(parent, "Rack", Vector3(2.6, 3.6, 1.1), at + Vector3.UP * 1.8, mat_metal)
	for y in [0.65, 1.65, 2.65]:
		WorldUtil.static_box(parent, "Shelf", Vector3(2.4, 0.10, 1.0), at + Vector3(0.0, y, 0.0), mat_rust, false)

func _create_conveyor(parent: Node3D, at: Vector3) -> void:
	WorldUtil.static_box(parent, "Conveyor", Vector3(3.2, 0.85, 5.8), at, mat_metal)
	WorldUtil.static_box(parent, "Belt", Vector3(2.9, 0.10, 5.5), at + Vector3.UP * 0.48, mat_dark, false)

func _create_robot_arm(parent: Node3D, at: Vector3) -> void:
	WorldUtil.static_box(parent, "ArmBase", Vector3(0.95, 0.8, 0.95), at + Vector3.UP * 0.4, mat_safety)
	var arm := Node3D.new()
	arm.position = at + Vector3.UP * 1.2
	arm.set_meta("animated_machine", true)
	parent.add_child(arm)
	var segment := WorldUtil.box_mesh(Vector3(0.38, 2.2, 0.38), mat_safety)
	segment.position.y = 0.8
	arm.add_child(segment)
	var tool := WorldUtil.box_mesh(Vector3(1.5, 0.25, 0.25), mat_metal)
	tool.position = Vector3(0.6, 1.85, 0.0)
	arm.add_child(tool)

func _create_press(parent: Node3D, at: Vector3) -> void:
	WorldUtil.static_box(parent, "PressBase", Vector3(4.2, 0.8, 4.0), at + Vector3.UP * 0.4, mat_dark)
	WorldUtil.static_box(parent, "PressFrame", Vector3(3.8, 4.4, 1.0), at + Vector3(0.0, 2.6, 0.0), mat_metal)
	WorldUtil.static_box(parent, "PressHead", Vector3(2.8, 0.65, 2.6), at + Vector3(0.0, 2.1, 0.0), mat_rust)

func _create_lights() -> void:
	for i in range(12):
		var z := 10.0 - i * 14.0
		var light := OmniLight3D.new()
		light.position = Vector3(0.0, 4.8, z)
		light.light_color = Color(0.52, 0.73, 0.92) if i % 3 else Color(1.0, 0.38, 0.18)
		light.light_energy = 1.35 if i % 3 else 1.05
		light.omni_range = 17.0
		light.shadow_enabled = false
		add_child(light)
		var lamp := WorldUtil.box_mesh(Vector3(3.8, 0.08, 0.35), mat_screen if i % 3 else mat_safety)
		lamp.position = Vector3(0.0, 5.35, z)
		add_child(lamp)
