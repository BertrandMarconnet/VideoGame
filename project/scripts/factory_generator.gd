class_name FactoryGenerator
extends Node3D

signal console_activated(console_id: String)
signal structure_changed(description: String)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var astar: AStar3D = AStar3D.new()
var nav_positions: Dictionary = {}
var dynamic_links: Dictionary = {}
var spawn_points: Dictionary = {}
var semantic_rooms: Array[Node3D] = []
var consoles: Dictionary = {}
var breached_positions: Array[Vector3] = []
var layout_variant: int = 0

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


func get_spawn_position(id_value: String) -> Vector3:
	return spawn_points.get(id_value, Vector3.ZERO) as Vector3


func get_semantic_rooms() -> Array[Node3D]:
	return semantic_rooms


func get_console(id_value: String) -> ControlConsole:
	return consoles.get(id_value) as ControlConsole


func get_navigation_path(from_position: Vector3, to_position: Vector3) -> PackedVector3Array:
	if astar.get_point_count() == 0:
		return PackedVector3Array([to_position])
	var from_id: int = astar.get_closest_point(from_position)
	var to_id: int = astar.get_closest_point(to_position)
	var result: PackedVector3Array = astar.get_point_path(from_id, to_id)
	if result.is_empty():
		return PackedVector3Array([to_position])
	return result


func get_stalking_point(player_position: Vector3, min_distance: float = 12.0) -> Vector3:
	var best: Vector3 = Vector3(0.0, 0.0, -30.0)
	var best_score: float = -99999.0
	for key in nav_positions:
		var point: Vector3 = nav_positions[key] as Vector3
		var distance: float = point.distance_to(player_position)
		if distance < min_distance or distance > 35.0:
			continue
		var score: float = distance + rng.randf_range(-8.0, 8.0)
		if score > best_score:
			best_score = score
			best = point
	return best


func open_dynamic_link(link_id: String) -> void:
	if link_id.is_empty() or not dynamic_links.has(link_id):
		return
	var link_data: Array = dynamic_links[link_id] as Array
	var point_a: int = int(link_data[0])
	var point_b: int = int(link_data[1])
	if not astar.are_points_connected(point_a, point_b):
		astar.connect_points(point_a, point_b, true)
	var breach_position: Vector3 = (
		astar.get_point_position(point_a) + astar.get_point_position(point_b)
	) * 0.5
	breached_positions.append(breach_position)
	structure_changed.emit("Une brèche modifie les itinéraires des unités.")


func repair_nearest_breach(player_position: Vector3, held: GrabbableProp) -> bool:
	if held == null or breached_positions.is_empty():
		return false
	var nearest: Vector3 = breached_positions[0]
	var best_distance: float = player_position.distance_to(nearest)
	for point in breached_positions:
		var distance: float = player_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			nearest = point
	if best_distance > 4.0:
		return false
	var panel: DestructiblePanel = DestructiblePanel.new()
	panel.configure(
		self,
		"",
		Vector3(2.0, 2.4, 0.24),
		nearest + Vector3.UP * 1.2,
		mat_rust,
		"metal"
	)
	panel.max_health = 55.0 + held.mass * 2.0
	panel.health = panel.max_health
	add_child(panel)
	held.queue_free()
	breached_positions.erase(nearest)
	structure_changed.emit("Brèche condamnée avec un élément du décor.")
	return true


func create_runtime_prop(kind: String, at: Vector3) -> GrabbableProp:
	var prop: GrabbableProp = GrabbableProp.new()
	var size_value: Vector3 = Vector3(0.7, 0.6, 0.7)
	var mass_value: float = 9.0
	var material_value: Material = mat_metal
	match kind:
		"crate":
			size_value = Vector3(0.78, 0.62, 0.78)
			mass_value = 13.0
			material_value = mat_dark
		"toolbox":
			size_value = Vector3(0.52, 0.28, 0.32)
			mass_value = 6.0
			material_value = mat_rust
		"pipe":
			size_value = Vector3(0.18, 0.18, 1.45)
			mass_value = 8.0
			material_value = mat_metal
		"panel":
			size_value = Vector3(1.0, 0.12, 0.75)
			mass_value = 12.0
			material_value = mat_rust
	prop.configure(kind, size_value, material_value, mass_value)
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
	mat_screen = WorldUtil.material(
		Color(0.01, 0.05, 0.065),
		0.15,
		0.25,
		Color(0.05, 0.75, 1.0),
		2.2
	)
	mat_glass = WorldUtil.material(Color(0.18, 0.38, 0.46, 0.28), 0.05, 0.08)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _create_shell() -> void:
	WorldUtil.static_box(
		self, "Floor", Vector3(36.0, 1.0, 182.0), Vector3(0.0, -0.5, -73.0), mat_floor
	)
	WorldUtil.static_box(
		self, "WestOuter", Vector3(1.0, 7.0, 182.0), Vector3(-18.5, 3.0, -73.0), mat_wall
	)
	WorldUtil.static_box(
		self, "EastOuter", Vector3(1.0, 7.0, 182.0), Vector3(18.5, 3.0, -73.0), mat_wall
	)
	WorldUtil.static_box(
		self, "SouthOuter", Vector3(38.0, 7.0, 1.0), Vector3(0.0, 3.0, 18.0), mat_wall
	)
	WorldUtil.static_box(
		self, "NorthOuter", Vector3(38.0, 7.0, 1.0), Vector3(0.0, 3.0, -164.0), mat_wall
	)
	for z_value in range(14, -162, -8):
		WorldUtil.static_box(
			self,
			"CeilingBeam_%d" % z_value,
			Vector3(36.0, 0.22, 0.32),
			Vector3(0.0, 5.7, float(z_value)),
			mat_dark,
			false
		)


func _create_navigation_graph() -> void:
	var point_id: int = 0
	for z_value in range(10, -158, -8):
		for x_value in [-10.0, 0.0, 10.0]:
			var point: Vector3 = Vector3(float(x_value), 0.0, float(z_value))
			astar.add_point(point_id, point)
			nav_positions[point_id] = point
			point_id += 1
	var row_count: int = 21
	for row in range(row_count):
		for column in range(3):
			var current: int = row * 3 + column
			if column < 2:
				astar.connect_points(current, current + 1, true)
			if row < row_count - 1:
				astar.connect_points(current, current + 3, true)
	dynamic_links["secret_archive"] = [25, 35]


func _semantic_room(
	node_name: String,
	semantic: String,
	at: Vector3,
	size_value: Vector3
) -> Node3D:
	var room: Node3D = Node3D.new()
	room.name = node_name
	room.position = at
	room.set_meta("semantic_type", semantic)
	room.set_meta("size", size_value)
	add_child(room)
	semantic_rooms.append(room)
	return room


func _create_control_room() -> void:
	var room: Node3D = _semantic_room(
		"S01_ControlRoom", "control_room", Vector3(0.0, 0.0, 7.0), Vector3(20.0, 5.0, 18.0)
	)
	WorldUtil.static_box(room, "WestWall", Vector3(0.4, 5.0, 18.0), Vector3(-10.0, 2.5, 0.0), mat_wall)
	WorldUtil.static_box(room, "EastWall", Vector3(0.4, 5.0, 18.0), Vector3(10.0, 2.5, 0.0), mat_wall)
	WorldUtil.static_box(room, "NorthWallA", Vector3(7.0, 5.0, 0.4), Vector3(-6.5, 2.5, -9.0), mat_wall)
	WorldUtil.static_box(room, "NorthWallB", Vector3(7.0, 5.0, 0.4), Vector3(6.5, 2.5, -9.0), mat_wall)
	for index in range(5):
		var desk: StaticBody3D = WorldUtil.static_box(
			room,
			"Desk_%d" % index,
			Vector3(2.4, 0.85, 0.9),
			Vector3(-6.0 + float(index) * 3.0, 0.43, 2.2),
			mat_dark
		)
		var screen: MeshInstance3D = WorldUtil.box_mesh(Vector3(1.55, 0.72, 0.06), mat_screen)
		screen.position = Vector3(0.0, 0.88, -0.35)
		desk.add_child(screen)
	_create_console("briefing", "ÉCRAN DE RONDE", Vector3(-5.8, 0.58, 11.0), PI)
	_create_console("door_control", "PORTE S-01", Vector3(0.0, 0.58, 11.0), PI)
	_create_console("uplink", "UPLINK BLACKOUT", Vector3(5.8, 0.58, 11.0), PI)


func _create_sector_logistics() -> void:
	var room: Node3D = _semantic_room(
		"Logistics", "logistics", Vector3(0.0, 0.0, -25.0), Vector3(34.0, 5.0, 34.0)
	)
	for side_value in [-1.0, 1.0]:
		for index in range(5):
			_create_rack(
				room,
				Vector3(float(side_value) * 12.5, 0.0, -11.0 + float(index) * 6.0)
			)
	for index in range(10):
		var kind: String = "crate" if index % 2 == 0 else "toolbox"
		create_runtime_prop(
			kind,
			Vector3(rng.randf_range(-13.0, 13.0), 0.7, rng.randf_range(-39.0, -12.0))
		)


func _create_sector_assembly() -> void:
	var room: Node3D = _semantic_room(
		"Assembly", "assembly", Vector3(0.0, 0.0, -66.0), Vector3(34.0, 5.0, 42.0)
	)
	for lane_value in [-8.5, 0.0, 8.5]:
		for index in range(5):
			_create_conveyor(
				room,
				Vector3(float(lane_value), 0.5, -16.0 + float(index) * 8.0)
			)
	for index in range(8):
		var arm_x: float = -13.0 if index % 2 == 0 else 13.0
		_create_robot_arm(room, Vector3(arm_x, 0.0, -17.0 + float(index) * 4.8))
	var relay_a_x: float = -12.5 if layout_variant != 1 else 12.5
	var relay_a_facing: float = PI * 0.5 if relay_a_x < 0.0 else -PI * 0.5
	_create_console("relay_a", "RELAIS A", Vector3(relay_a_x, 0.58, -47.0), relay_a_facing)


func _create_sector_archives() -> void:
	var room: Node3D = _semantic_room(
		"Archives", "archives", Vector3(0.0, 0.0, -103.0), Vector3(34.0, 5.0, 28.0)
	)
	for x_value in [-12.0, -7.0, 7.0, 12.0]:
		for z_value in [-10.0, -3.5, 3.5, 10.0]:
			_create_rack(room, Vector3(float(x_value), 0.0, float(z_value)))
	var recorder_options: Array[float] = [-7.5, 0.0, 7.5]
	var recorder_x: float = recorder_options[layout_variant]
	_create_console("black_box", "ENREGISTREUR NOIR", Vector3(recorder_x, 0.58, -103.0), 0.0)


func _create_sector_foundry() -> void:
	var room: Node3D = _semantic_room(
		"Foundry", "foundry", Vector3(0.0, 0.0, -140.0), Vector3(34.0, 5.0, 38.0)
	)
	for x_value in [-10.0, 10.0]:
		for z_value in [-13.0, 0.0, 13.0]:
			_create_press(room, Vector3(float(x_value), 0.0, float(z_value)))
	var relay_b_x: float = 12.5 if layout_variant == 0 else -12.5
	var relay_b_facing: float = -PI * 0.5 if relay_b_x > 0.0 else PI * 0.5
	_create_console("relay_b", "RELAIS B", Vector3(relay_b_x, 0.58, -148.0), relay_b_facing)


func _create_secret_route() -> void:
	var panel: DestructiblePanel = DestructiblePanel.new()
	panel.name = "SecretArchivePanel"
	var secret_x: float = -9.7 if layout_variant != 2 else 9.7
	panel.configure(
		self,
		"secret_archive",
		Vector3(3.0, 3.2, 0.34),
		Vector3(secret_x, 1.6, -91.0),
		mat_wall,
		"concrete"
	)
	add_child(panel)
	add_child(
		WorldUtil.label3d(
			"ACCÈS TECHNIQUE M-04",
			Vector3(secret_x, 3.55, -90.75),
			Color(0.9, 0.4, 0.12),
			20
		)
	)


func _create_console(id_value: String, title: String, at: Vector3, facing: float) -> void:
	var console: ControlConsole = ControlConsole.new()
	console.configure(id_value, title, at, facing)
	add_child(console)
	console.activated.connect(_on_console_activated)
	consoles[id_value] = console


func _on_console_activated(id_value: String) -> void:
	console_activated.emit(id_value)


func _create_rack(parent: Node3D, at: Vector3) -> void:
	WorldUtil.static_box(parent, "Rack", Vector3(2.6, 3.6, 1.1), at + Vector3.UP * 1.8, mat_metal)
	for y_value in [0.65, 1.65, 2.65]:
		WorldUtil.static_box(
			parent,
			"Shelf",
			Vector3(2.4, 0.10, 1.0),
			at + Vector3(0.0, float(y_value), 0.0),
			mat_rust,
			false
		)


func _create_conveyor(parent: Node3D, at: Vector3) -> void:
	WorldUtil.static_box(parent, "Conveyor", Vector3(3.2, 0.85, 5.8), at, mat_metal)
	WorldUtil.static_box(
		parent,
		"Belt",
		Vector3(2.9, 0.10, 5.5),
		at + Vector3.UP * 0.48,
		mat_dark,
		false
	)


func _create_robot_arm(parent: Node3D, at: Vector3) -> void:
	WorldUtil.static_box(
		parent,
		"ArmBase",
		Vector3(0.95, 0.8, 0.95),
		at + Vector3.UP * 0.4,
		mat_safety
	)
	var arm: Node3D = Node3D.new()
	arm.position = at + Vector3.UP * 1.2
	arm.set_meta("animated_machine", true)
	parent.add_child(arm)
	var segment: MeshInstance3D = WorldUtil.box_mesh(Vector3(0.38, 2.2, 0.38), mat_safety)
	segment.position.y = 0.8
	arm.add_child(segment)
	var tool: MeshInstance3D = WorldUtil.box_mesh(Vector3(1.5, 0.25, 0.25), mat_metal)
	tool.position = Vector3(0.6, 1.85, 0.0)
	arm.add_child(tool)


func _create_press(parent: Node3D, at: Vector3) -> void:
	WorldUtil.static_box(parent, "PressBase", Vector3(4.2, 0.8, 4.0), at + Vector3.UP * 0.4, mat_dark)
	WorldUtil.static_box(
		parent,
		"PressFrame",
		Vector3(3.8, 4.4, 1.0),
		at + Vector3(0.0, 2.6, 0.0),
		mat_metal
	)
	WorldUtil.static_box(
		parent,
		"PressHead",
		Vector3(2.8, 0.65, 2.6),
		at + Vector3(0.0, 2.1, 0.0),
		mat_rust
	)


func _create_lights() -> void:
	for index in range(12):
		var z_value: float = 10.0 - float(index) * 14.0
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(0.0, 4.8, z_value)
		light.light_color = (
			Color(0.52, 0.73, 0.92) if index % 3 != 0 else Color(1.0, 0.38, 0.18)
		)
		light.light_energy = 1.35 if index % 3 != 0 else 1.05
		light.omni_range = 17.0
		light.shadow_enabled = false
		add_child(light)
		var lamp_material: Material = mat_screen if index % 3 != 0 else mat_safety
		var lamp: MeshInstance3D = WorldUtil.box_mesh(
			Vector3(3.8, 0.08, 0.35), lamp_material
		)
		lamp.position = Vector3(0.0, 5.35, z_value)
		add_child(lamp)
