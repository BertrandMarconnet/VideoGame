extends RefCounted
## Final v21 playable factory layout.
## Replaces the straight 176 m interior read with a compact surveillance hub,
## two lateral halls, side rooms, a north loop and a destructible secret route.

const WALL_HEIGHT := 3.8
const HUB_CENTER := Vector3(0.0, 0.0, -16.0)

func install(scene: Node3D, visuals: Object) -> Node3D:
	var previous := scene.get_node_or_null("FactoryFNAFV21")
	if previous:
		previous.queue_free()
	var old_v21 := scene.get_node_or_null("FactoryLayoutV21")
	if old_v21:
		old_v21.queue_free()
	_cleanup_legacy_interior(scene)

	var root := Node3D.new()
	root.name = "FactoryFNAFV21"
	root.set_meta("layout_version", "v21_fnaf_final")
	scene.add_child(root)

	var concrete := _surface(visuals, "concrete")
	var steel := _surface(visuals, "steel")
	var floor_mat := _surface(visuals, "floor")
	var paint := _surface(visuals, "paint")
	var rubber := _surface(visuals, "rubber")

	_build_security_hub(scene, root, concrete, steel, floor_mat, paint, rubber)
	_build_lateral_halls(root, concrete, steel, floor_mat, paint)
	_build_side_rooms(root, concrete, steel, floor_mat, paint, rubber)
	_build_north_loop(scene, root, concrete, steel, floor_mat, paint)
	_build_secret_route(scene, root, concrete, steel, floor_mat, paint)
	_build_decor(root, visuals)
	_relocate_mission_nodes(scene)
	_relocate_dynamic_props(scene)

	scene.set_meta("factory_layout_v21_ready", true)
	scene.set_meta("factory_fnaf_v21_ready", true)
	return root

func _cleanup_legacy_interior(scene: Node3D) -> void:
	var removable := [
		"ControlFloor", "ControlWallL", "ControlWallR", "AssemblyPartition",
		"ArchiveShelf", "Conveyor", "RecorderVault", "SecretFloor", "SecretShell",
		"SecretBack", "SecretWall"
	]
	for label in removable:
		for node in scene.find_children(label + "*", "", true, false):
			if node is Node3D:
				(node as Node3D).queue_free()
	# Remove the old large machines/racks/cabinets that visually preserve the
	# straight warehouse. The v21 layout adds fewer props inside real rooms.
	for token in ["Machine", "RackShelf", "RackPost", "ArchiveCabinet", "FoundryPress"]:
		for node in scene.find_children(token + "*", "", true, false):
			if node is Node3D and not bool(node.get_meta("robot", false)):
				(node as Node3D).queue_free()

func _build_security_hub(
	scene: Node3D,
	root: Node3D,
	concrete: Material,
	steel: Material,
	floor_mat: Material,
	paint: Material,
	rubber: Material
) -> void:
	var hub := Node3D.new()
	hub.name = "SecurityHubV21"
	root.add_child(hub)
	_visual_box(hub, Vector3(14.0, 0.03, 11.0), Vector3(0.0, 0.02, -16.0), floor_mat, "HubFloorV21")
	# South wall, closed.
	_static_box(hub, Vector3(14.0, WALL_HEIGHT, 0.28), Vector3(0.0, WALL_HEIGHT * 0.5, -10.5), concrete, "HubSouthWallV21")
	# West wall with a 2.6 m service door.
	_static_box(hub, Vector3(0.28, WALL_HEIGHT, 2.8), Vector3(-7.0, WALL_HEIGHT * 0.5, -12.0), concrete, "HubWestSouthV21")
	_static_box(hub, Vector3(0.28, WALL_HEIGHT, 5.2), Vector3(-7.0, WALL_HEIGHT * 0.5, -18.9), concrete, "HubWestNorthV21")
	# East wall keeps the existing service-airlock arrival at z=-13.4.
	_static_box(hub, Vector3(0.28, WALL_HEIGHT, 1.4), Vector3(7.0, WALL_HEIGHT * 0.5, -11.2), concrete, "HubEastSouthV21")
	_static_box(hub, Vector3(0.28, WALL_HEIGHT, 5.0), Vector3(7.0, WALL_HEIGHT * 0.5, -18.5), concrete, "HubEastNorthV21")
	# North wall has two real hall openings, FNAF-style left/right approaches.
	_static_box(hub, Vector3(2.4, WALL_HEIGHT, 0.28), Vector3(-5.8, WALL_HEIGHT * 0.5, -21.5), concrete, "HubNorthOuterLeftV21")
	_static_box(hub, Vector3(5.0, WALL_HEIGHT, 0.28), Vector3(0.0, WALL_HEIGHT * 0.5, -21.5), concrete, "HubNorthCenterV21")
	_static_box(hub, Vector3(2.4, WALL_HEIGHT, 0.28), Vector3(5.8, WALL_HEIGHT * 0.5, -21.5), concrete, "HubNorthOuterRightV21")
	_static_box(hub, Vector3(14.0, 0.22, 11.0), Vector3(0.0, 3.75, -16.0), concrete, "HubCeilingV21")

	# Consoles are wall-side so the center remains readable and navigable.
	for x in [-4.6, -1.6, 1.6, 4.6]:
		_static_box(hub, Vector3(2.3, 0.82, 0.78), Vector3(x, 0.41, -11.6), rubber, "HubConsoleV21")
		_visual_box(hub, Vector3(1.45, 0.62, 0.05), Vector3(x, 1.10, -11.98), paint, "HubCRTGlowV21")
	_label(hub, "S-01 // SECURITY CONTROL", Vector3(0.0, 2.95, -10.32), 31, Color(0.68, 0.95, 0.88))
	_label(hub, "CAMERAS  •  SHUTTERS  •  POWER", Vector3(0.0, 2.52, -10.32), 17, Color(0.96, 0.58, 0.24))

	# Visual shutter frames. The gameplay director creates/moves the actual doors.
	for x in [-4.85, 4.85]:
		_static_box(hub, Vector3(0.20, 3.4, 0.42), Vector3(x - 1.45, 1.7, -21.35), steel, "HubShutterFrameV21")
		_static_box(hub, Vector3(0.20, 3.4, 0.42), Vector3(x + 1.45, 1.7, -21.35), steel, "HubShutterFrameV21")

	var uplink_value = scene.get("uplink_terminal")
	if uplink_value is Node3D:
		var uplink := uplink_value as Node3D
		uplink.global_position = Vector3(-3.2, 1.1, -18.4)
		uplink.rotation_degrees.y = 90.0

func _build_lateral_halls(
	root: Node3D,
	concrete: Material,
	steel: Material,
	floor_mat: Material,
	paint: Material
) -> void:
	var halls := Node3D.new()
	halls.name = "TwinHallsV21"
	root.add_child(halls)
	# Central utility core removes the impossible uninterrupted sightline.
	_static_box(halls, Vector3(6.7, WALL_HEIGHT, 21.0), Vector3(0.0, WALL_HEIGHT * 0.5, -36.0), concrete, "SealedUtilityPlantV22")
	_static_box(halls, Vector3(7.0, WALL_HEIGHT, 0.30), Vector3(0.0, WALL_HEIGHT * 0.5, -24.0), concrete, "UtilityCoreSouthV21")
	_static_box(halls, Vector3(7.0, WALL_HEIGHT, 0.30), Vector3(0.0, WALL_HEIGHT * 0.5, -65.0), concrete, "UtilityCoreNorthV21")
	_static_box(halls, Vector3(0.30, WALL_HEIGHT, 19.0), Vector3(3.5, WALL_HEIGHT * 0.5, -33.5), concrete, "UtilityCoreEastSouthV21")
	_static_box(halls, Vector3(0.30, WALL_HEIGHT, 19.0), Vector3(3.5, WALL_HEIGHT * 0.5, -55.5), concrete, "UtilityCoreEastNorthV21")
	# West core wall contains a destructible maintenance access at z=-53.
	_static_box(halls, Vector3(0.30, WALL_HEIGHT, 23.0), Vector3(-3.5, WALL_HEIGHT * 0.5, -35.5), concrete, "UtilityCoreWestSouthV21")
	_static_box(halls, Vector3(0.30, WALL_HEIGHT, 9.0), Vector3(-3.5, WALL_HEIGHT * 0.5, -60.5), concrete, "UtilityCoreWestNorthV21")

	# Hall floor strips and lane markings make the left/right FNAF routes obvious.
	for x in [-5.55, 5.55]:
		_visual_box(halls, Vector3(3.7, 0.025, 43.0), Vector3(x, 0.02, -44.5), floor_mat, "HallFloorV21")
		_visual_box(halls, Vector3(0.08, 0.018, 40.0), Vector3(x, 0.035, -44.5), paint, "HallGuideV21")
	# Outer hall/room separator walls with doorway gaps rather than free-standing barriers.
	for x in [-7.45, 7.45]:
		for z in [-27.0, -41.0, -55.0]:
			_static_box(halls, Vector3(0.24, WALL_HEIGHT, 6.4), Vector3(x, WALL_HEIGHT * 0.5, z), steel, "HallRoomWallV21")
	_label(halls, "WEST HALL", Vector3(-5.55, 2.7, -25.0), 22, Color(0.78, 0.90, 0.76))
	_label(halls, "EAST HALL", Vector3(5.55, 2.7, -25.0), 22, Color(0.78, 0.90, 0.76))

func _build_side_rooms(
	root: Node3D,
	concrete: Material,
	steel: Material,
	floor_mat: Material,
	paint: Material,
	rubber: Material
) -> void:
	var rooms := Node3D.new()
	rooms.name = "CameraRoomsV21"
	root.add_child(rooms)
	var data := [
		{"name":"CAM 02 // LOGISTICS", "x":-11.6, "z":-31.0, "kind":"crate"},
		{"name":"CAM 03 // ARCHIVES", "x":-11.6, "z":-46.0, "kind":"archive"},
		{"name":"CAM 04 // MAINTENANCE", "x":-11.6, "z":-60.0, "kind":"bench"},
		{"name":"CAM 05 // ASSEMBLY", "x":11.6, "z":-31.0, "kind":"machine"},
		{"name":"CAM 06 // POWER", "x":11.6, "z":-46.0, "kind":"generator"},
		{"name":"CAM 07 // TEST CELL", "x":11.6, "z":-60.0, "kind":"cage"},
	]
	for item in data:
		var x := float(item["x"])
		var z := float(item["z"])
		_visual_box(rooms, Vector3(7.3, 0.025, 12.5), Vector3(x, 0.02, z), floor_mat, "RoomFloorV21")
		_static_box(rooms, Vector3(7.3, WALL_HEIGHT, 0.25), Vector3(x, WALL_HEIGHT * 0.5, z - 6.2), concrete, "RoomEndWallV21")
		_static_box(rooms, Vector3(7.3, WALL_HEIGHT, 0.25), Vector3(x, WALL_HEIGHT * 0.5, z + 6.2), concrete, "RoomEndWallV21")
		_label(rooms, String(item["name"]), Vector3(x, 2.75, z - 5.95), 19, Color(0.78, 0.91, 0.84))
		_build_room_prop(rooms, Vector3(x, 0.0, z), String(item["kind"]), steel, paint, rubber)

func _build_room_prop(
	parent: Node3D,
	at: Vector3,
	kind: String,
	steel: Material,
	paint: Material,
	rubber: Material
) -> void:
	match kind:
		"crate":
			for i in range(4):
				_static_box(parent, Vector3(1.3, 1.0, 1.3), at + Vector3(-2.0 + float(i % 2) * 3.8, 0.5, -1.8 + float(i / 2) * 3.6), rubber, "LogisticsCrateV21")
		"archive":
			for i in range(3):
				_static_box(parent, Vector3(4.6, 2.6, 0.65), at + Vector3(0.0, 1.3, -3.5 + float(i) * 3.4), steel, "ArchiveRackV21")
		"bench":
			_static_box(parent, Vector3(4.8, 1.0, 1.2), at + Vector3(0.0, 0.5, 1.8), steel, "MaintenanceBenchV21")
			_visual_box(parent, Vector3(3.8, 0.08, 0.72), at + Vector3(0.0, 1.1, 1.8), paint, "MaintenanceToolsV21")
		"machine":
			_static_box(parent, Vector3(4.4, 2.4, 4.0), at + Vector3(0.2, 1.2, 0.0), steel, "AssemblyMachineV21")
			_visual_box(parent, Vector3(1.2, 0.8, 0.08), at + Vector3(2.25, 1.6, -1.2), paint, "AssemblyPanelV21")
		"generator":
			for i in range(2):
				_static_box(parent, Vector3(2.5, 2.8, 2.0), at + Vector3(-1.8 + float(i) * 3.6, 1.4, 0.0), steel, "PowerGeneratorV21")
				_visual_box(parent, Vector3(1.4, 0.12, 1.0), at + Vector3(-1.8 + float(i) * 3.6, 1.8, -1.05), paint, "PowerMeterV21")
		"cage":
			for x in [-2.2, 2.2]:
				_static_box(parent, Vector3(0.16, 3.0, 5.0), at + Vector3(x, 1.5, 0.0), steel, "TestCageV21")
			for z in [-2.5, 2.5]:
				_static_box(parent, Vector3(4.6, 3.0, 0.16), at + Vector3(0.0, 1.5, z), steel, "TestCageV21")

func _build_north_loop(
	scene: Node3D,
	root: Node3D,
	concrete: Material,
	steel: Material,
	floor_mat: Material,
	paint: Material
) -> void:
	var north := Node3D.new()
	north.name = "NorthLoopV21"
	root.add_child(north)
	_visual_box(north, Vector3(18.0, 0.025, 4.2), Vector3(0.0, 0.02, -69.0), floor_mat, "NorthCrossFloorV21")
	_static_box(north, Vector3(13.0, WALL_HEIGHT, 0.24), Vector3(-2.5, WALL_HEIGHT * 0.5, -71.1), concrete, "NorthCrossWallV21")
	_static_box(north, Vector3(1.0, WALL_HEIGHT, 0.24), Vector3(8.5, WALL_HEIGHT * 0.5, -71.1), concrete, "NorthCrossReturnV22")
	# L-shaped approach to relay room; no direct axial view from the hub.
	_visual_box(north, Vector3(4.0, 0.025, 12.0), Vector3(6.0, 0.02, -75.0), floor_mat, "RelayApproachFloorV21")
	_static_box(north, Vector3(0.24, WALL_HEIGHT, 12.0), Vector3(4.0, WALL_HEIGHT * 0.5, -75.0), steel, "RelayApproachWestV21")
	_static_box(north, Vector3(0.24, WALL_HEIGHT, 12.0), Vector3(8.0, WALL_HEIGHT * 0.5, -75.0), steel, "RelayApproachEastV21")
	_visual_box(north, Vector3(13.0, 0.025, 10.0), Vector3(0.0, 0.02, -84.0), floor_mat, "RelayRoomFloorV21")
	_static_box(north, Vector3(13.0, WALL_HEIGHT, 0.25), Vector3(0.0, WALL_HEIGHT * 0.5, -89.0), concrete, "RelayNorthWallV21")
	_static_box(north, Vector3(0.25, WALL_HEIGHT, 10.0), Vector3(-6.5, WALL_HEIGHT * 0.5, -84.0), concrete, "RelayWestWallV21")
	_static_box(north, Vector3(0.25, WALL_HEIGHT, 10.0), Vector3(6.5, WALL_HEIGHT * 0.5, -84.0), concrete, "RelayEastWallV21")
	_label(north, "CAM 08 // NORTH RELAY", Vector3(0.0, 2.8, -88.75), 22, Color(0.92, 0.47, 0.20))
	_label(north, "NO DIRECT LINE TO S-01", Vector3(0.0, 2.35, -88.75), 15, Color(0.66, 0.78, 0.73))
	var relay_value = scene.get("relay_terminal")
	if relay_value is Node3D:
		var relay := relay_value as Node3D
		relay.global_position = Vector3(0.0, 1.1, -87.8)
		relay.rotation_degrees.y = 180.0
	_visual_box(north, Vector3(0.08, 0.018, 10.0), Vector3(6.0, 0.035, -75.0), paint, "RelayGuideV21")

func _build_secret_route(
	scene: Node3D,
	root: Node3D,
	concrete: Material,
	steel: Material,
	floor_mat: Material,
	paint: Material
) -> void:
	var secret := Node3D.new()
	secret.name = "SecretMaintenanceV21"
	root.add_child(secret)
	# Breakable panel connects CAM03/04 side to the utility core.
	if scene.has_method("_build_destructible_wall"):
		scene.call("_build_destructible_wall", Vector3(-3.5, 1.65, -53.0), Vector3(0.34, 3.3, 4.0), "SecretMaintenanceV21")
	_visual_box(secret, Vector3(5.0, 0.025, 8.0), Vector3(-1.0, 0.02, -53.0), floor_mat, "SecretFloorV21")
	_static_box(secret, Vector3(5.0, 1.70, 0.18), Vector3(-1.0, 0.85, -57.0), steel, "SecretLowWallV21")
	_static_box(secret, Vector3(5.0, 0.16, 8.0), Vector3(-1.0, 1.65, -53.0), concrete, "SecretLowCeilingV21")
	_label(secret, "M-04 // CRAWLSPACE", Vector3(1.35, 1.15, -53.0), 16, Color(0.95, 0.48, 0.18), Vector3(0.0, -90.0, 0.0))
	_visual_box(secret, Vector3(0.08, 0.08, 6.5), Vector3(-2.9, 1.2, -53.0), paint, "SecretCableV21")

func _build_decor(root: Node3D, visuals: Object) -> void:
	if visuals.has_method("poster"):
		visuals.call("poster", root, Vector3(-14.75, 1.8, -31.0), 0, 90.0)
		visuals.call("poster", root, Vector3(14.75, 1.8, -46.0), 0, -90.0)
	if visuals.has_method("cabinet"):
		visuals.call("cabinet", root, Vector3(-13.6, 0.12, -64.0), 90.0)
		visuals.call("cabinet", root, Vector3(13.6, 0.12, -36.0), -90.0)

func _relocate_mission_nodes(scene: Node3D) -> void:
	# Specter teleport anchors now match rooms/camera coverage instead of a line.
	scene.set("observation_points", [
		Vector3(-5.5, 1.0, -27.0), Vector3(-11.5, 1.0, -34.0),
		Vector3(5.5, 1.0, -27.0), Vector3(11.5, 1.0, -47.0),
		Vector3(-5.5, 1.0, -63.0), Vector3(6.0, 1.0, -69.0),
		Vector3(0.0, 1.0, -84.0)
	])

func _relocate_dynamic_props(scene: Node3D) -> void:
	var slots := [
		Vector3(-12.0, 0.8, -28.5), Vector3(-12.0, 0.8, -42.0),
		Vector3(-12.0, 0.8, -57.0), Vector3(12.0, 0.8, -28.5),
		Vector3(12.0, 0.8, -42.0), Vector3(12.0, 0.8, -57.0)
	]
	var index := 0
	for node in scene.find_children("*", "RigidBody3D", true, false):
		var body := node as RigidBody3D
		if not bool(body.get_meta("grabbable", false)):
			continue
		var slot: Vector3 = slots[index % slots.size()]
		body.global_position = slot + Vector3(float(index % 2) * 1.2, 0.0, float(index / slots.size()) * 0.7)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		index += 1

func _surface(visuals: Object, kind: String) -> Material:
	return visuals.call("surface", kind) as Material

func _static_box(parent: Node3D, size_value: Vector3, at: Vector3, material_value: Material, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.set_meta("layout_role_v21", label)
	body.set_meta("size", size_value)
	parent.add_child(body)
	var mesh_shape := BoxMesh.new()
	mesh_shape.size = size_value
	var mesh := MeshInstance3D.new()
	mesh.name = label + "Mesh"
	mesh.mesh = mesh_shape
	mesh.material_override = material_value
	body.add_child(mesh)
	var collision_shape := BoxShape3D.new()
	collision_shape.size = size_value
	var collision := CollisionShape3D.new()
	collision.shape = collision_shape
	body.add_child(collision)
	return body

func _visual_box(parent: Node3D, size_value: Vector3, at: Vector3, material_value: Material, label: String) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size_value
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = shape
	mesh.material_override = material_value
	mesh.position = at
	mesh.set_meta("layout_role_v21", label)
	parent.add_child(mesh)
	return mesh

func _label(parent: Node3D, text_value: String, at: Vector3, font_size_value: int, color_value: Color, rotation_value := Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = font_size_value
	label.pixel_size = 0.0022
	label.position = at
	label.rotation_degrees = rotation_value
	label.modulate = color_value
	label.outline_size = 0
	label.visibility_range_end = 38.0
	parent.add_child(label)
	return label
