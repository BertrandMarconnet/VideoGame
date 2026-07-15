class_name GeneratedAssetBridge
extends Node

const CATALOG_PATH := "res://assets/generated/catalog.json"
const DestructibleComponentScript := preload("res://scripts/destruction/destructible_component.gd")
const MaterialResponseDBScript := preload("res://scripts/destruction/material_response_db.gd")

var world_root: Node3D
var catalog: Dictionary = {}
var material_db: Object
var registered: Dictionary = {}

func initialize(root: Node3D) -> void:
	world_root = root
	material_db = MaterialResponseDBScript.new() as Object
	_reload_catalog()

func _reload_catalog() -> void:
	catalog = {}
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("Generated asset catalog not found: %s" % CATALOG_PATH)
		return
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	for entry_variant in (parsed as Dictionary).get("assets", []):
		if entry_variant is Dictionary:
			var entry := entry_variant as Dictionary
			catalog[String(entry.get("id", ""))] = entry

func has_asset(asset_id: String) -> bool:
	return catalog.has(asset_id)

func get_asset(asset_id: String) -> Dictionary:
	return (catalog.get(asset_id, {}) as Dictionary).duplicate(true)

func register_robot(robot: CharacterBody3D, personality: String) -> void:
	if robot == null or registered.has(robot.get_instance_id()):
		return
	var asset_id := "specter_5" if personality == "specter" else "crawler_7"
	var entry := get_asset(asset_id)
	if not entry.is_empty() and String(entry.get("integration", "catalog_only")) == "replace_procedural":
		_attach_generated_visual(robot, entry)
	var profile := _load_damage_profile(entry, _fallback_robot_profile(asset_id))
	profile["category"] = "robot_biped" if personality == "specter" else "robot_quadruped"
	_attach_component(robot, profile)
	robot.set_meta("generated_asset_id", asset_id)
	registered[robot.get_instance_id()] = asset_id

func register_static_destructible(body: Node3D, material_id: String, max_health := 0.0, zone_id := "core") -> void:
	if body == null or registered.has(body.get_instance_id()):
		return
	var health := max_health if max_health > 0.0 else float(material_db.call("base_health", material_id))
	var profile := {
		"schema_version": 1,
		"asset_id": body.name.to_snake_case(),
		"category": "prop",
		"mode": "localized",
		"default_material": material_id,
		"zones": [{
			"id": zone_id,
			"material_id": material_id,
			"max_health": health,
			"detachable": true,
			"node_patterns": ["MeshInstance3D", "*Mesh*", "*Visual*"],
			"on_break": "break"
		}],
		"tool_rules": {}
	}
	_attach_component(body, profile)
	body.set_meta("destructible", true)
	body.set_meta("material_id", material_id)
	registered[body.get_instance_id()] = body.name

func create_segmented_wall(parent: Node3D, at: Vector3, size: Vector3, material_id: String, label: String, cell_target := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = label
	root.position = at
	root.set_meta("generated_wall", true)
	root.set_meta("material_id", material_id)
	parent.add_child(root)
	var horizontal_axis_x := size.x >= size.z
	var wall_width := size.x if horizontal_axis_x else size.z
	var columns := maxi(1, int(ceil(wall_width / maxf(cell_target, 0.4))))
	var rows := maxi(1, int(ceil(size.y / maxf(cell_target, 0.4))))
	var cell_width := wall_width / float(columns)
	var cell_height := size.y / float(rows)
	var thickness := size.z if horizontal_axis_x else size.x
	for row in range(rows):
		for column in range(columns):
			var cell := StaticBody3D.new()
			cell.name = "%s_Cell_%02d_%02d" % [label, row, column]
			var horizontal := -wall_width * 0.5 + cell_width * (float(column) + 0.5)
			cell.position = Vector3(horizontal, -size.y * 0.5 + cell_height * (float(row) + 0.5), 0.0) if horizontal_axis_x else Vector3(0.0, -size.y * 0.5 + cell_height * (float(row) + 0.5), horizontal)
			var cell_size := Vector3(cell_width * 0.97, cell_height * 0.97, thickness) if horizontal_axis_x else Vector3(thickness, cell_height * 0.97, cell_width * 0.97)
			var mesh := MeshInstance3D.new()
			mesh.name = "DZ_wall_%02d_%02d" % [row, column]
			var box_mesh := BoxMesh.new()
			box_mesh.size = cell_size
			mesh.mesh = box_mesh
			mesh.material_override = _wall_material(material_id, row, column)
			cell.add_child(mesh)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = cell_size
			collision.shape = shape
			cell.add_child(collision)
			var zone_id := "cell_%02d_%02d" % [row, column]
			cell.set_meta("damage_zone_id", zone_id)
			cell.set_meta("destructible", not bool(material_db.call("is_structural", material_id)))
			cell.set_meta("material_id", material_id)
			root.add_child(cell)
			var profile := {
				"schema_version": 1,
				"asset_id": label.to_snake_case(),
				"category": "wall",
				"mode": "segmented_wall",
				"default_material": material_id,
				"zones": [{
					"id": zone_id,
					"material_id": material_id,
					"max_health": float(material_db.call("base_health", material_id)),
					"detachable": true,
					"node_patterns": [mesh.name],
					"on_break": "open_hole"
				}],
				"tool_rules": {}
			}
			_attach_component(cell, profile)
	return root

func spawn_asset(asset_id: String, parent: Node3D, transform_value := Transform3D.IDENTITY) -> Node3D:
	var entry := get_asset(asset_id)
	if entry.is_empty():
		return null
	var path := String(entry.get("glb", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	if not resource is PackedScene:
		return null
	var instance := (resource as PackedScene).instantiate() as Node3D
	if instance == null:
		return null
	parent.add_child(instance)
	instance.transform = transform_value
	var profile := _load_damage_profile(entry, {})
	if not profile.is_empty():
		profile["category"] = String(entry.get("category", "prop"))
		_attach_component(instance, profile)
	return instance

func apply_damage(target: Node, context: Dictionary) -> Dictionary:
	var current := target
	for _step in range(5):
		if current == null:
			break
		var component := current.get_node_or_null("DestructibleComponent")
		if component != null and component.has_method("apply_damage"):
			return component.call("apply_damage", context) as Dictionary
		current = current.get_parent()
	return {"handled": false}

func get_speed_multiplier(target: Node) -> float:
	var component := _find_component(target)
	if component == null:
		return 1.0
	return clampf(float(component.get("speed_multiplier")), 0.1, 1.0)

func get_movement_mode(target: Node) -> String:
	var component := _find_component(target)
	return String(component.get("movement_mode")) if component != null else "normal"

func is_detection_enabled(target: Node) -> bool:
	var component := _find_component(target)
	return bool(component.get("detection_enabled")) if component != null else true

func is_disabled(target: Node) -> bool:
	var component := _find_component(target)
	return bool(component.get("disabled")) if component != null else false

func _find_component(target: Node) -> Node:
	var current := target
	for _step in range(5):
		if current == null:
			break
		var component := current.get_node_or_null("DestructibleComponent")
		if component != null:
			return component
		current = current.get_parent()
	return null

func _attach_component(target: Node3D, profile: Dictionary) -> Node:
	var existing := target.get_node_or_null("DestructibleComponent")
	if existing != null:
		existing.call("configure", profile)
		return existing
	var component := DestructibleComponentScript.new()
	component.name = "DestructibleComponent"
	target.add_child(component)
	component.call_deferred("configure", profile)
	return component

func _attach_generated_visual(robot: CharacterBody3D, entry: Dictionary) -> void:
	var path := String(entry.get("glb", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var resource := load(path)
	if not resource is PackedScene:
		return
	var instance := (resource as PackedScene).instantiate() as Node3D
	if instance == null:
		return
	instance.name = "GeneratedVisual"
	robot.add_child(instance)
	var dimensions := entry.get("dimensions_m", {}) as Dictionary
	var target_height := maxf(float(dimensions.get("height", 1.0)), 0.1)
	var bounds := _combined_aabb(instance)
	if bounds.size.y > 0.001:
		var scale_factor := target_height / bounds.size.y
		instance.scale = Vector3.ONE * scale_factor
		instance.position.y = -bounds.position.y * scale_factor
	for child in robot.get_children():
		if child == instance or child is CollisionShape3D or child.name == "DestructibleComponent":
			continue
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false

func _combined_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_box := mesh_instance.transform * mesh_instance.get_aabb()
		if not initialized:
			result = local_box
			initialized = true
		else:
			result = result.merge(local_box)
	return result

func _load_damage_profile(entry: Dictionary, fallback: Dictionary) -> Dictionary:
	var path := String(entry.get("damage_profile", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return fallback.duplicate(true)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback.duplicate(true)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else fallback.duplicate(true)

func _fallback_robot_profile(asset_id: String) -> Dictionary:
	if asset_id == "specter_5":
		return {
			"schema_version": 1,
			"asset_id": asset_id,
			"category": "robot_biped",
			"mode": "detachable",
			"default_material": "metal_armored",
			"zones": [
				{"id":"left_leg","material_id":"metal_light","max_health":35.0,"detachable":true,"node_patterns":["*LeftLeg*","*L_thigh*","*L_shin*","DZ_l_leg_*"],"speed_multiplier":0.65,"on_break":"limp"},
				{"id":"right_leg","material_id":"metal_light","max_health":35.0,"detachable":true,"node_patterns":["*RightLeg*","*R_thigh*","*R_shin*","DZ_r_leg_*"],"speed_multiplier":0.65,"on_break":"limp"},
				{"id":"sensor","material_id":"glass","max_health":18.0,"detachable":false,"node_patterns":["*Eye*","*Sensor*"],"on_break":"disable_detection"},
				{"id":"torso","material_id":"metal_armored","max_health":100.0,"detachable":false,"node_patterns":["*Torso*","DZ_torso_*"],"on_break":"shutdown"}
			],
			"tool_rules": {}
		}
	var zones: Array = []
	for prefix in ["lf", "rf", "lr", "rr"]:
		zones.append({"id":prefix+"_leg","material_id":"metal_light","max_health":28.0,"detachable":true,"node_patterns":["*"+prefix.to_upper()+"*","DZ_"+prefix.to_upper()+"_*"],"speed_multiplier":0.78,"on_break":"reduce_speed"})
	zones.append({"id":"sensor","material_id":"glass","max_health":18.0,"detachable":false,"node_patterns":["*Sensor*","*Lens*"],"on_break":"disable_detection"})
	zones.append({"id":"body","material_id":"metal_armored","max_health":110.0,"detachable":false,"node_patterns":["*Body*","*Torso*","*Spine*"],"on_break":"shutdown"})
	return {"schema_version":1,"asset_id":asset_id,"category":"robot_quadruped","mode":"detachable","default_material":"metal_armored","zones":zones,"tool_rules":{}}

func _wall_material(material_id: String, row: int, column: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var base := Color(0.45, 0.45, 0.43)
	match material_id:
		"drywall": base = Color(0.48, 0.46, 0.42)
		"brick": base = Color(0.34, 0.12, 0.07)
		"concrete": base = Color(0.24, 0.25, 0.24)
		"wood": base = Color(0.28, 0.16, 0.07)
	var variation := 0.92 + float((row * 7 + column * 13) % 9) * 0.012
	material.albedo_color = Color(base.r * variation, base.g * variation, base.b * variation)
	material.roughness = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material
