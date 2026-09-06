extends RefCounted
## Spatial correction pass for the active Act I factory.
## The pass keeps mission objects and robot systems intact while replacing the
## straight-through visual connectors with offset junctions, a compact secured
## operations hub and a crouch-only destructible maintenance shortcut.

const HUB_GATE_SCRIPT := preload("res://scripts/visual/secure_hub_gate_v21.gd")


func install(scene: Node3D, visuals: Object) -> Node3D:
	var previous := scene.get_node_or_null("FactoryLayoutV21")
	if previous:
		previous.queue_free()

	_remove_legacy_connectors(scene)
	_remove_center_obstacles(scene)
	_relocate_transverse_props(scene)

	var root := Node3D.new()
	root.name = "FactoryLayoutV21"
	root.set_meta("layout_version", "v21_non_linear")
	scene.add_child(root)

	_build_compact_hub(scene, root, visuals)
	_build_offset_junctions(root, visuals)
	_build_secret_maintenance_route(scene, root, visuals)
	_build_wayfinding(root, visuals)

	scene.set_meta("factory_layout_v21_ready", true)
	return root


func _remove_legacy_connectors(scene: Node3D) -> void:
	var legacy := scene.get_node_or_null("IndustrialVisualsV20")
	if legacy:
		for child in legacy.get_children():
			if String(child.name).begins_with("ServiceCorridor_"):
				child.queue_free()


func _remove_center_obstacles(scene: Node3D) -> void:
	for candidate in scene.get_children():
		if not candidate is Node3D:
			continue
		var node := candidate as Node3D
		var label := String(node.name)
		if label in ["ControlWallL", "ControlWallR"]:
			node.queue_free()
		elif label == "Console" and node.global_position.z > -9.5 and node.global_position.z < -5.5:
			node.queue_free()
		elif label == "Screen" and node.global_position.z > -9.5 and node.global_position.z < -5.5:
			node.queue_free()
		elif label == "ArchiveShelf":
			node.queue_free()
		elif "AssemblyPartition" in label:
			node.queue_free()


func _relocate_transverse_props(scene: Node3D) -> void:
	var moved := 0
	for candidate in scene.find_children("*", "RigidBody3D", true, false):
		var body := candidate as RigidBody3D
		var p := body.global_position
		# v20 created eight props in a literal wall across z=-55.
		if absf(p.z + 55.0) < 1.2 and absf(p.x) < 7.0:
			var side := -1.0 if moved % 2 == 0 else 1.0
			body.global_position = Vector3(side * (12.8 + float(moved % 3) * 0.7), maxf(0.75, p.y), -51.8 - float(moved) * 0.8)
			moved += 1


func _build_compact_hub(scene: Node3D, root: Node3D, visuals: Object) -> void:
	var hub := Node3D.new()
	hub.name = "S01_CompactOperationsHubV21"
	root.add_child(hub)

	var concrete := _surface(visuals, "concrete")
	var floor_mat := _surface(visuals, "floor")
	var steel := _surface(visuals, "steel")
	var paint := _surface(visuals, "paint")
	var rubber := _surface(visuals, "rubber")

	# 13.3 x 10.8 m instead of the old 26 x 18 m open hall.
	_static_box(hub, Vector3(13.3, 0.18, 10.8), Vector3(-6.05, 0.09, -10.1), floor_mat, "HubFloorV21")
	_static_box(hub, Vector3(13.3, 0.20, 10.8), Vector3(-6.05, 3.55, -10.1), concrete, "HubCeilingV21")
	_static_box(hub, Vector3(0.28, 3.55, 10.8), Vector3(-12.70, 1.78, -10.1), concrete, "HubWestWallV21")

	# South wall, closed except for service cable penetrations represented visually.
	_static_box(hub, Vector3(13.3, 3.55, 0.28), Vector3(-6.05, 1.78, -4.70), concrete, "HubSouthWallV21")

	# East wall faces the lateral vestibule. The gap is a real doorway at z=-13.4.
	_static_box(hub, Vector3(0.28, 3.55, 7.15), Vector3(0.60, 1.78, -8.28), concrete, "HubEastWallSouthV21")
	_static_box(hub, Vector3(0.28, 3.55, 0.60), Vector3(0.60, 1.78, -15.20), concrete, "HubEastWallNorthV21")
	_static_box(hub, Vector3(0.48, 3.55, 0.22), Vector3(0.38, 1.78, -11.84), steel, "HubDoorJambSouthV21")
	_static_box(hub, Vector3(0.48, 3.55, 0.22), Vector3(0.38, 1.78, -14.96), steel, "HubDoorJambNorthV21")
	_static_box(hub, Vector3(0.48, 0.28, 3.35), Vector3(0.38, 3.42, -13.40), steel, "HubDoorHeaderV21")

	# North wall opens into the factory through an offset passage instead of a full-width hall.
	_static_box(hub, Vector3(4.65, 3.55, 0.28), Vector3(-10.38, 1.78, -15.50), concrete, "HubNorthWallWestV21")
	_static_box(hub, Vector3(5.10, 3.55, 0.28), Vector3(-1.95, 1.78, -15.50), concrete, "HubNorthWallEastV21")

	# New compact furniture. These are deliberately against walls; no desk crosses a route.
	for index in range(3):
		var x := -9.4 + float(index) * 3.15
		_static_box(hub, Vector3(2.45, 0.86, 0.82), Vector3(x, 0.43, -6.65), rubber, "HubConsoleV21")
		_visual_box(hub, Vector3(1.65, 0.62, 0.055), Vector3(x, 1.13, -7.02), paint, "HubCRTGlowV21")
	for index in range(2):
		_static_box(hub, Vector3(0.65, 1.75, 0.42), Vector3(-11.90, 0.88, -7.4 - float(index) * 2.3), steel, "HubCabinetV21")

	# Keep the actual mission terminal but move it inside the reduced room.
	var uplink_value = scene.get("uplink_terminal")
	if uplink_value is Node3D:
		var uplink := uplink_value as Node3D
		uplink.global_position = Vector3(-5.9, 1.10, -8.85)
		uplink.rotation_degrees.y = 0.0

	var gate := HUB_GATE_SCRIPT.new()
	gate.name = "SecureHubGateV21"
	hub.add_child(gate)
	gate.configure(
		scene,
		Vector3(0.58, 1.62, -13.40),
		Vector3(0.32, 3.16, 2.92),
		Vector3(0.0, 0.0, -3.25),
		steel,
		"S-01 OPERATIONS"
	)

	_label(hub, "S-01 // OPERATIONS HUB", Vector3(-6.1, 3.05, -4.50), 32, Color(0.64, 0.92, 0.86))
	_label(hub, "AUTHORIZED STAFF ONLY", Vector3(-6.1, 2.62, -4.50), 18, Color(0.95, 0.45, 0.18))


func _build_offset_junctions(root: Node3D, visuals: Object) -> void:
	var concrete := _surface(visuals, "concrete")
	var steel := _surface(visuals, "steel")
	var floor_mat := _surface(visuals, "floor")
	var paint := _surface(visuals, "paint")
	var junctions: Array[Dictionary] = [
		{"z": -22.5, "opening_x": 6.0, "name": "J1 LOGISTICS", "arrow": "→"},
		{"z": -58.0, "opening_x": -6.0, "name": "J2 ASSEMBLY", "arrow": "←"},
		{"z": -92.0, "opening_x": 5.5, "name": "J3 ARCHIVES", "arrow": "→"},
		{"z": -126.0, "opening_x": -5.5, "name": "J4 FOUNDRY", "arrow": "←"},
	]
	for index in range(junctions.size()):
		var data := junctions[index]
		var z := float(data["z"])
		var opening_x := float(data["opening_x"])
		var junction := Node3D.new()
		junction.name = "OffsetJunctionV21_%d" % index
		root.add_child(junction)

		# Cross-bulkhead split around a 6 m doorway. Openings alternate left/right,
		# breaking the 176 m line of sight while retaining a generous Jolt route.
		var open_half := 3.05
		var left_edge := -16.55
		var right_edge := 16.55
		var open_left := opening_x - open_half
		var open_right := opening_x + open_half
		var left_span := open_left - left_edge
		var right_span := right_edge - open_right
		if left_span > 0.2:
			_static_box(junction, Vector3(left_span, 3.75, 0.30), Vector3(left_edge + left_span * 0.5, 1.88, z), concrete, "BulkheadLeftV21")
		if right_span > 0.2:
			_static_box(junction, Vector3(right_span, 3.75, 0.30), Vector3(open_right + right_span * 0.5, 1.88, z), concrete, "BulkheadRightV21")
		_static_box(junction, Vector3(6.35, 0.30, 0.34), Vector3(opening_x, 3.60, z), steel, "BulkheadLintelV21")
		_static_box(junction, Vector3(0.24, 3.55, 5.4), Vector3(opening_x - 3.18, 1.78, z), steel, "ConnectorWallLeftV21")
		_static_box(junction, Vector3(0.24, 3.55, 5.4), Vector3(opening_x + 3.18, 1.78, z), steel, "ConnectorWallRightV21")
		_static_box(junction, Vector3(6.60, 0.18, 5.4), Vector3(opening_x, 3.58, z), concrete, "ConnectorCeilingV21")
		_visual_box(junction, Vector3(5.4, 0.016, 5.1), Vector3(opening_x, 0.012, z), floor_mat, "ConnectorFloorWearV21")
		_visual_box(junction, Vector3(0.10, 0.018, 5.1), Vector3(opening_x, 0.025, z), paint, "RouteMarkV21")
		_label(junction, "%s  %s" % [String(data["name"]), String(data["arrow"])], Vector3(opening_x, 3.10, z + 0.18), 24, Color(0.76, 0.88, 0.76))


func _build_secret_maintenance_route(scene: Node3D, root: Node3D, visuals: Object) -> void:
	var concrete := _surface(visuals, "concrete")
	var steel := _surface(visuals, "steel")
	var floor_mat := _surface(visuals, "floor")
	var paint := _surface(visuals, "paint")
	var rubber := _surface(visuals, "rubber")

	# The former hidden room was a dead end. Its rear wall becomes a second
	# destructible threshold leading to a crouch-only service bypass.
	var old_back := scene.find_child("SecretBack", true, false)
	if old_back:
		old_back.queue_free()
	_static_box(root, Vector3(0.42, 3.9, 0.34), Vector3(-15.78, 1.95, -124.0), concrete, "SecretBackLeftV21")
	_static_box(root, Vector3(4.45, 3.9, 0.34), Vector3(-10.23, 1.95, -124.0), concrete, "SecretBackRightV21")
	if scene.has_method("_build_destructible_wall"):
		scene.call(
			"_build_destructible_wall",
			Vector3(-14.05, 1.55, -124.0),
			Vector3(3.05, 3.10, 0.34),
			"SecretMaintenanceExitV21"
		)

	var duct := Node3D.new()
	duct.name = "MaintenanceCrawlRouteV21"
	root.add_child(duct)
	_static_box(duct, Vector3(3.10, 0.12, 12.0), Vector3(-14.05, 0.06, -130.0), floor_mat, "CrawlFloorV21")
	_static_box(duct, Vector3(0.20, 1.72, 12.0), Vector3(-15.58, 0.86, -130.0), steel, "CrawlWallWestV21")
	_static_box(duct, Vector3(0.20, 1.72, 12.0), Vector3(-12.52, 0.86, -130.0), steel, "CrawlWallEastV21")
	_static_box(duct, Vector3(3.10, 0.18, 12.0), Vector3(-14.05, 1.70, -130.0), concrete, "CrawlCeilingV21")
	for index in range(5):
		_visual_box(duct, Vector3(2.55, 0.045, 0.11), Vector3(-14.05, 0.04, -125.4 - float(index) * 2.25), rubber, "CrawlGrateV21")
		_visual_box(duct, Vector3(0.10, 0.10, 1.65), Vector3(-15.34, 1.28, -125.4 - float(index) * 2.25), paint, "CrawlCableV21")
	_label(duct, "M-04 // SERVICE CRAWLSPACE", Vector3(-12.39, 1.20, -128.8), 18, Color(0.95, 0.49, 0.20), Vector3(0.0, -90.0, 0.0))


func _build_wayfinding(root: Node3D, visuals: Object) -> void:
	var paint := _surface(visuals, "paint")
	var floor_mat := _surface(visuals, "floor")
	var nodes: Array[Dictionary] = [
		{"at": Vector3(12.9, 1.8, -31.0), "text": "LOGISTICS / RECEIVING", "yaw": -90.0},
		{"at": Vector3(-12.9, 1.8, -69.0), "text": "ASSEMBLY / CELL B", "yaw": 90.0},
		{"at": Vector3(12.9, 1.8, -105.0), "text": "ARCHIVES / RECORDS", "yaw": -90.0},
		{"at": Vector3(-12.9, 1.8, -142.0), "text": "FOUNDRY / PRESS SHOP", "yaw": 90.0},
	]
	for data in nodes:
		var plate := Node3D.new()
		plate.position = data["at"]
		plate.rotation_degrees.y = float(data["yaw"])
		root.add_child(plate)
		_visual_box(plate, Vector3(2.7, 0.64, 0.04), Vector3.ZERO, paint, "WayfindingPlateV21")
		_label(plate, String(data["text"]), Vector3(0.0, 0.0, 0.028), 20, Color(0.90, 0.87, 0.62))
	# Local floor patches make the branching route readable without a minimap.
	for at in [Vector3(6.0, 0.01, -22.5), Vector3(-6.0, 0.01, -58.0), Vector3(5.5, 0.01, -92.0), Vector3(-5.5, 0.01, -126.0)]:
		_visual_box(root, Vector3(5.2, 0.012, 2.5), at, floor_mat, "RoutePatchV21")


func _surface(visuals: Object, kind: String) -> Material:
	return visuals.call("surface", kind) as Material


func _static_box(
	parent: Node3D,
	size_value: Vector3,
	at: Vector3,
	material_value: Material,
	label: String
) -> StaticBody3D:
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


func _visual_box(
	parent: Node3D,
	size_value: Vector3,
	at: Vector3,
	material_value: Material,
	label: String
) -> MeshInstance3D:
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


func _label(
	parent: Node3D,
	text_value: String,
	at: Vector3,
	font_size_value: int,
	color_value: Color,
	rotation_value := Vector3.ZERO
) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = font_size_value
	label.pixel_size = 0.0021
	label.position = at
	label.rotation_degrees = rotation_value
	label.modulate = color_value
	label.outline_size = 0
	label.visibility_range_end = 36.0
	parent.add_child(label)
	return label
