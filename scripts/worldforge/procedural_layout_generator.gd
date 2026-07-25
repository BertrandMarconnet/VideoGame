class_name WorldForgeProceduralGenerator
extends RefCounted

const CONFIG_PATH := "res://config/worldforge_modules.json"
const GENERATED_ROOT_NAME := "WorldForgeGenerated"

var _config: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _material_cache: Dictionary = {}
var _manifest: Dictionary = {}

func configure(seed_value: int) -> void:
	_rng.seed = seed_value
	_config = _load_config()
	_manifest = {
		"schema_version": 1,
		"seed": seed_value,
		"generator": "worldforge_constraint_layout_v1",
		"generated_at_unix": int(Time.get_unix_time_from_system()),
		"modules": [],
		"placed_nodes": 0,
		"rejected_candidates": 0,
		"story_path_preserved": true
	}

func generate(scene_root: Node3D, seed_value: int) -> Dictionary:
	configure(seed_value)
	_clear_previous(scene_root)
	var generated_root := Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	generated_root.set_meta("worldforge_generated", true)
	generated_root.set_meta("worldforge_seed", seed_value)
	scene_root.add_child(generated_root)

	var map_cfg := _config.get("map", {}) as Dictionary
	var sector_count := int(map_cfg.get("sector_count", 8))
	var sector_start_z := float(map_cfg.get("sector_start_z", -25.0))
	var spacing := float(map_cfg.get("sector_spacing", 16.5))
	var previous_by_side := {"left": "", "right": ""}

	for sector_index in range(sector_count):
		var sector_z := sector_start_z - float(sector_index) * spacing
		var heavy_used := false
		for side_name in ["left", "right"]:
			var module := _pick_module(String(previous_by_side[side_name]), heavy_used)
			if module.is_empty():
				continue
			var module_id := String(module.get("id", "empty_tension"))
			if bool(module.get("requires_wall", false)):
				heavy_used = true
			var side_sign := -1.0 if side_name == "left" else 1.0
			var record := _build_module(generated_root, scene_root, module_id, side_sign, sector_z, sector_index)
			record["side"] = side_name
			record["sector"] = sector_index
			record["event_tags"] = module.get("event_tags", [])
			(_manifest["modules"] as Array).append(record)
			previous_by_side[side_name] = module_id

	_reseed_existing_props(scene_root)
	_manifest["placed_nodes"] = generated_root.get_child_count()
	return _manifest.duplicate(true)

func get_manifest() -> Dictionary:
	return _manifest.duplicate(true)

func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return _fallback_config()
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return _fallback_config()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else _fallback_config()

func _fallback_config() -> Dictionary:
	return {
		"map": {
			"width": 34.0,
			"length": 176.0,
			"floor_y": 0.0,
			"ceiling_y": 8.1,
			"safe_corridor_half_width": 4.2,
			"sector_start_z": -25.0,
			"sector_spacing": 16.5,
			"sector_count": 8
		},
		"modules": [
			{"id":"open_storage","weight":1.2,"requires_wall":false,"event_tags":["loot"]},
			{"id":"maintenance_cell","weight":1.0,"requires_wall":true,"event_tags":["repair"]},
			{"id":"observation_lab","weight":0.8,"requires_wall":true,"event_tags":["camera"]},
			{"id":"destroyed_office","weight":0.9,"requires_wall":true,"event_tags":["lore"]},
			{"id":"cable_bay","weight":0.8,"requires_wall":false,"event_tags":["electric"]},
			{"id":"empty_tension","weight":0.6,"requires_wall":false,"event_tags":["silence"]}
		]
	}

func _clear_previous(scene_root: Node3D) -> void:
	var previous := scene_root.get_node_or_null(GENERATED_ROOT_NAME)
	if previous != null:
		previous.free()

func _pick_module(previous_id: String, heavy_already_used: bool) -> Dictionary:
	var candidates: Array = []
	var total_weight := 0.0
	for entry_variant in _config.get("modules", []):
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var module_id := String(entry.get("id", ""))
		if module_id == previous_id:
			continue
		if heavy_already_used and bool(entry.get("requires_wall", false)):
			continue
		var weight := maxf(float(entry.get("weight", 1.0)), 0.01)
		candidates.append({"entry": entry, "weight": weight})
		total_weight += weight
	if candidates.is_empty():
		return {"id":"empty_tension","weight":1.0,"requires_wall":false,"event_tags":["silence"]}
	var roll := _rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for candidate in candidates:
		cursor += float(candidate["weight"])
		if roll <= cursor:
			return (candidate["entry"] as Dictionary).duplicate(true)
	return (candidates.back()["entry"] as Dictionary).duplicate(true)

func _build_module(generated_root: Node3D, scene_root: Node3D, module_id: String, side_sign: float, sector_z: float, sector_index: int) -> Dictionary:
	var anchor_x := side_sign * 10.2
	var anchor := Vector3(anchor_x, 0.0, sector_z)
	var before := generated_root.get_child_count()
	match module_id:
		"open_storage":
			_build_open_storage(generated_root, scene_root, anchor, side_sign)
		"maintenance_cell":
			_build_maintenance_cell(generated_root, scene_root, anchor, side_sign)
		"observation_lab":
			_build_observation_lab(generated_root, scene_root, anchor, side_sign)
		"destroyed_office":
			_build_destroyed_office(generated_root, scene_root, anchor, side_sign)
		"cable_bay":
			_build_cable_bay(generated_root, scene_root, anchor, side_sign)
		_:
			_build_empty_tension(generated_root, scene_root, anchor, side_sign)
	return {
		"id": module_id,
		"anchor": [anchor.x, anchor.y, anchor.z],
		"node_count": generated_root.get_child_count() - before,
		"variant": _rng.randi_range(0, 999999),
		"sector": sector_index
	}

func _build_open_storage(parent: Node3D, scene_root: Node3D, anchor: Vector3, side_sign: float) -> void:
	for index in range(_rng.randi_range(2, 5)):
		var size := Vector3(_rng.randf_range(0.8, 1.5), _rng.randf_range(0.7, 1.4), _rng.randf_range(0.8, 1.5))
		var at := anchor + Vector3(_rng.randf_range(-2.2, 2.2), size.y * 0.5 + 0.04, _rng.randf_range(-3.6, 3.6))
		_try_static_box(parent, scene_root, size, at, "WF_StorageCrate", "prop", _material("crate"))
	if _rng.randf() < 0.55:
		var rack_at := anchor + Vector3(side_sign * 2.3, 1.45, 0.0)
		_try_static_box(parent, scene_root, Vector3(0.5, 2.9, 6.4), rack_at, "WF_StorageRack", "prop", _material("dark_metal"))

func _build_maintenance_cell(parent: Node3D, scene_root: Node3D, anchor: Vector3, side_sign: float) -> void:
	_build_side_room_shell(parent, scene_root, anchor, side_sign, "Maintenance")
	var bench_at := anchor + Vector3(side_sign * 2.0, 0.65, 0.8)
	_try_static_box(parent, scene_root, Vector3(2.8, 1.3, 1.0), bench_at, "WF_MaintenanceBench", "prop", _material("dark_metal"))
	var panel_at := anchor + Vector3(side_sign * 3.25, 1.7, -1.7)
	_try_static_box(parent, scene_root, Vector3(0.25, 1.7, 1.1), panel_at, "WF_MaintenancePanel", "wall_asset", _material("console"))
	_add_event_anchor(parent, anchor + Vector3(0.0, 1.0, 0.0), ["repair", "electric", "ambush"])

func _build_observation_lab(parent: Node3D, scene_root: Node3D, anchor: Vector3, side_sign: float) -> void:
	_build_side_room_shell(parent, scene_root, anchor, side_sign, "Observation")
	var desk_at := anchor + Vector3(side_sign * 1.5, 0.58, 0.0)
	_try_static_box(parent, scene_root, Vector3(3.1, 1.15, 1.2), desk_at, "WF_ObservationDesk", "prop", _material("console"))
	var screen_at := desk_at + Vector3(-side_sign * 0.35, 1.05, -0.35)
	var screen := _try_visual_box(parent, scene_root, Vector3(1.5, 0.75, 0.08), screen_at, "WF_ObservationScreen", _material("screen"))
	if screen != null:
		screen.set_meta("worldforge_event", "camera_feed")
	_add_event_anchor(parent, anchor + Vector3(0.0, 1.2, 0.0), ["archive", "camera", "athena"])

func _build_destroyed_office(parent: Node3D, scene_root: Node3D, anchor: Vector3, side_sign: float) -> void:
	_build_side_room_shell(parent, scene_root, anchor, side_sign, "Office")
	for index in range(_rng.randi_range(2, 4)):
		var size := Vector3(_rng.randf_range(1.2, 2.4), _rng.randf_range(0.2, 0.5), _rng.randf_range(0.7, 1.2))
		var at := anchor + Vector3(_rng.randf_range(-2.3, 2.3), size.y * 0.5 + 0.1, _rng.randf_range(-3.0, 3.0))
		var node := _try_static_box(parent, scene_root, size, at, "WF_OfficeDebris", "prop", _material("rust"))
		if node != null:
			node.rotation_degrees.y = _rng.randf_range(-32.0, 32.0)
	_add_event_anchor(parent, anchor + Vector3(0.0, 0.8, 0.0), ["lore", "hallucination", "false_signal"])

func _build_cable_bay(parent: Node3D, scene_root: Node3D, anchor: Vector3, side_sign: float) -> void:
	var ceiling_y := float((_config.get("map", {}) as Dictionary).get("ceiling_y", 8.1))
	for index in range(3):
		var at := Vector3(anchor.x + side_sign * float(index - 1) * 0.7, ceiling_y - 0.7, anchor.z)
		_try_static_box(parent, scene_root, Vector3(0.16, 0.16, 7.0), at, "WF_CableRun", "ceiling_asset", _material("cable"))
	var service_box_at := anchor + Vector3(side_sign * 2.7, 1.15, 1.8)
	_try_static_box(parent, scene_root, Vector3(0.45, 2.3, 1.4), service_box_at, "WF_ServiceBox", "wall_asset", _material("rust"))
	_add_event_anchor(parent, anchor + Vector3(0.0, 1.0, 0.0), ["electric", "darkness", "drone"])

func _build_empty_tension(parent: Node3D, _scene_root: Node3D, anchor: Vector3, _side_sign: float) -> void:
	_add_event_anchor(parent, anchor + Vector3(0.0, 0.8, 0.0), ["silence", "stalker", "false_signal"])
	var marker := Node3D.new()
	marker.name = "WF_EmptyTension"
	marker.position = anchor
	marker.set_meta("worldforge_generated", true)
	marker.set_meta("worldforge_role", "event_only")
	parent.add_child(marker)

func _build_side_room_shell(parent: Node3D, scene_root: Node3D, anchor: Vector3, side_sign: float, label: String) -> void:
	var divider_x := side_sign * 5.7
	for z_offset in [-3.25, 3.25]:
		_try_static_box(parent, scene_root, Vector3(0.26, 3.1, 2.35), Vector3(divider_x, 1.55, anchor.z + z_offset), "WF_%sDivider" % label, "wall", _material("wall"))
	var rear_x := side_sign * 14.8
	_try_static_box(parent, scene_root, Vector3(0.28, 3.1, 8.7), Vector3(rear_x, 1.55, anchor.z), "WF_%sRear" % label, "wall", _material("wall"))
	for z_offset in [-4.25, 4.25]:
		_try_static_box(parent, scene_root, Vector3(9.1, 3.1, 0.28), Vector3(side_sign * 10.25, 1.55, anchor.z + z_offset), "WF_%sSide" % label, "wall", _material("wall"))

func _add_event_anchor(parent: Node3D, at: Vector3, tags: Array) -> void:
	var anchor := Marker3D.new()
	anchor.name = "WF_EventAnchor"
	anchor.position = at
	anchor.set_meta("worldforge_generated", true)
	anchor.set_meta("worldforge_role", "event_anchor")
	anchor.set_meta("event_tags", tags.duplicate())
	anchor.set_meta("event_seed", _rng.randi())
	parent.add_child(anchor)

func _try_static_box(parent: Node3D, scene_root: Node3D, size: Vector3, at: Vector3, label: String, role: String, material: Material) -> StaticBody3D:
	if not _can_place_box(scene_root, size, at):
		_manifest["rejected_candidates"] = int(_manifest.get("rejected_candidates", 0)) + 1
		return null
	var body := StaticBody3D.new()
	body.name = "%s_%06d" % [label, _rng.randi_range(0, 999999)]
	body.position = at
	body.set_meta("worldforge_generated", true)
	body.set_meta("worldforge_replaceable", true)
	body.set_meta("worldforge_role", role)
	body.set_meta("worldforge_floor_bound", role in ["prop", "wall", "wall_asset"])
	body.set_meta("worldforge_ceiling_bound", role == "ceiling_asset")
	body.set_meta("size", size)
	var mesh := MeshInstance3D.new()
	mesh.name = "Visual"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

func _try_visual_box(parent: Node3D, scene_root: Node3D, size: Vector3, at: Vector3, label: String, material: Material) -> MeshInstance3D:
	if not _can_place_box(scene_root, size, at):
		return null
	var mesh := MeshInstance3D.new()
	mesh.name = "%s_%06d" % [label, _rng.randi_range(0, 999999)]
	mesh.position = at
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.set_meta("worldforge_generated", true)
	mesh.set_meta("worldforge_replaceable", true)
	mesh.set_meta("worldforge_role", "visual")
	mesh.set_meta("size", size)
	parent.add_child(mesh)
	return mesh

func _can_place_box(scene_root: Node3D, size: Vector3, at: Vector3) -> bool:
	var map_cfg := _config.get("map", {}) as Dictionary
	var half_width := float(map_cfg.get("width", 34.0)) * 0.5 - 0.8
	var length := float(map_cfg.get("length", 176.0))
	var safe_corridor := float(map_cfg.get("safe_corridor_half_width", 4.2))
	if absf(at.x) + size.x * 0.5 > half_width:
		return false
	if at.z - size.z * 0.5 < -length + 2.0 or at.z + size.z * 0.5 > -16.0:
		return false
	if absf(at.x) - size.x * 0.5 < safe_corridor and size.y > 1.8:
		return false
	if scene_root.get_world_3d() == null:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(size.x - 0.12, 0.05), maxf(size.y - 0.28, 0.05), maxf(size.z - 0.12, 0.05))
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.13, 0.0))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hits := scene_root.get_world_3d().direct_space_state.intersect_shape(query, 8)
	return hits.is_empty()

func _reseed_existing_props(scene_root: Node3D) -> void:
	var candidates: Array[Node3D] = []
	for node in scene_root.find_children("*", "RigidBody3D", true, false):
		if node is RigidBody3D and bool(node.get_meta("grabbable", false)) and not bool(node.get_meta("worldforge_generated", false)):
			candidates.append(node as Node3D)
	for prop in candidates:
		var size := prop.get_meta("size", Vector3.ONE) as Vector3
		var placed := false
		for _attempt in range(24):
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			var candidate := Vector3(side * _rng.randf_range(6.2, 13.4), size.y * 0.5 + 0.08, _rng.randf_range(-154.0, -23.0))
			if _can_place_box(scene_root, size, candidate):
				prop.global_position = candidate
				prop.rotation_degrees.y = _rng.randf_range(-180.0, 180.0)
				if prop is RigidBody3D:
					(prop as RigidBody3D).linear_velocity = Vector3.ZERO
					(prop as RigidBody3D).angular_velocity = Vector3.ZERO
				prop.set_meta("worldforge_reseeded", true)
				placed = true
				break
		if not placed:
			prop.set_meta("worldforge_reseed_failed", true)

func _material(kind: String) -> StandardMaterial3D:
	if _material_cache.has(kind):
		return _material_cache[kind] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.82
	material.metallic = 0.45
	match kind:
		"crate":
			material.albedo_color = Color(0.19, 0.15, 0.10)
			material.metallic = 0.2
		"wall":
			material.albedo_color = Color(0.13, 0.15, 0.16)
			material.metallic = 0.3
		"console":
			material.albedo_color = Color(0.06, 0.10, 0.12)
			material.metallic = 0.65
		"screen":
			material.albedo_color = Color(0.01, 0.11, 0.13)
			material.emission_enabled = true
			material.emission = Color(0.0, 0.42, 0.52)
			material.emission_energy_multiplier = 1.2
		"rust":
			material.albedo_color = Color(0.22, 0.10, 0.055)
			material.metallic = 0.58
		"cable":
			material.albedo_color = Color(0.025, 0.03, 0.035)
			material.roughness = 0.7
		_:
			material.albedo_color = Color(0.08, 0.10, 0.11)
	_material_cache[kind] = material
	return material
