class_name DestructibleComponent
extends Node

signal zone_damaged(zone_id: String, remaining_ratio: float)
signal zone_broken(zone_id: String, effect: String)
signal destruction_state_changed(state: Dictionary)

const MaterialResponseDBScript := preload("res://scripts/destruction/material_response_db.gd")

var material_db: Object
var profile: Dictionary = {}
var zones: Dictionary = {}
var broken_zones: Dictionary = {}
var speed_multiplier := 1.0
var movement_mode := "normal"
var detection_enabled := true
var disabled := false
var debris_parent: Node3D
var max_runtime_debris := 16
var _runtime_debris: Array[RigidBody3D] = []

func _ready() -> void:
	material_db = MaterialResponseDBScript.new() as Object
	debris_parent = get_tree().current_scene as Node3D

func configure(profile_data: Dictionary) -> void:
	profile = profile_data.duplicate(true)
	zones.clear()
	broken_zones.clear()
	speed_multiplier = 1.0
	movement_mode = "normal"
	detection_enabled = true
	disabled = false
	for zone_variant in profile.get("zones", []):
		if not zone_variant is Dictionary:
			continue
		var zone := (zone_variant as Dictionary).duplicate(true)
		var zone_id := String(zone.get("id", "zone_%d" % zones.size()))
		var material_id := String(zone.get("material_id", profile.get("default_material", "metal_light")))
		var fallback_health := float(material_db.call("base_health", material_id))
		var max_health := maxf(float(zone.get("max_health", fallback_health)), 1.0)
		zone["id"] = zone_id
		zone["material_id"] = material_id
		zone["max_health"] = max_health
		zone["health"] = max_health
		zones[zone_id] = zone

func apply_damage(context: Dictionary) -> Dictionary:
	if disabled or zones.is_empty():
		return {"handled": false}
	var zone_id := String(context.get("zone_id", ""))
	if zone_id.is_empty():
		zone_id = _resolve_zone_from_hit(context.get("hit_position", Vector3.ZERO) as Vector3)
	if zone_id.is_empty() or not zones.has(zone_id):
		zone_id = String(zones.keys()[0])
	if broken_zones.has(zone_id):
		return {"handled": true, "zone_id": zone_id, "already_broken": true, "speed_multiplier": speed_multiplier, "movement_mode": movement_mode}
	var zone := zones[zone_id] as Dictionary
	var tool_id := String(context.get("tool_id", "flashlight_bash"))
	var damage_type := String(context.get("damage_type", "impact"))
	var base_damage := maxf(float(context.get("amount", 0.0)), 0.0)
	var material_id := String(zone.get("material_id", profile.get("default_material", "metal_light")))
	var multiplier: float = float(material_db.call("damage_multiplier", material_id, tool_id, damage_type))
	var damage: float = base_damage * multiplier
	if damage <= 0.0:
		return {"handled": true, "zone_id": zone_id, "damage": 0.0, "remaining_ratio": float(zone.get("health", 1.0)) / float(zone.get("max_health", 1.0)), "status": "AUCUN EFFET SUR CE MATÉRIAU"}
	var health := maxf(float(zone.get("health", zone.get("max_health", 1.0))) - damage, 0.0)
	zone["health"] = health
	zones[zone_id] = zone
	var ratio := health / maxf(float(zone.get("max_health", 1.0)), 1.0)
	zone_damaged.emit(zone_id, ratio)
	var broken := false
	if health <= 0.0:
		broken = true
		_break_zone(zone_id, zone, context)
	var result := {
		"handled": true,
		"zone_id": zone_id,
		"damage": damage,
		"remaining_ratio": ratio,
		"broken": broken,
		"speed_multiplier": speed_multiplier,
		"movement_mode": movement_mode,
		"detection_enabled": detection_enabled,
		"disabled": disabled,
		"status": "%s %d%%" % [zone_id.to_upper(), int(ratio * 100.0)]
	}
	destruction_state_changed.emit(get_state())
	return result

func get_state() -> Dictionary:
	return {
		"broken_zones": broken_zones.keys(),
		"speed_multiplier": speed_multiplier,
		"movement_mode": movement_mode,
		"detection_enabled": detection_enabled,
		"disabled": disabled
	}

func _resolve_zone_from_hit(world_position: Vector3) -> String:
	var owner_3d := get_parent() as Node3D
	if owner_3d == null:
		return ""
	var local := owner_3d.to_local(world_position)
	var category := String(profile.get("category", ""))
	if category == "robot_quadruped":
		var front := "f" if local.z < 0.0 else "r"
		var side := "l" if local.x < 0.0 else "r"
		var candidate := side + front + "_leg"
		if zones.has(candidate):
			return candidate
		if local.y > 0.45 and zones.has("sensor"):
			return "sensor"
		return "body" if zones.has("body") else ""
	if category == "robot_biped":
		if local.y < 0.78:
			var candidate := "left_leg" if local.x < 0.0 else "right_leg"
			if zones.has(candidate):
				return candidate
		if local.y > 1.65 and zones.has("sensor"):
			return "sensor"
		return "torso" if zones.has("torso") else ""
	if category == "wall" and get_parent().has_meta("damage_zone_id"):
		return String(get_parent().get_meta("damage_zone_id"))
	return String(zones.keys()[0]) if not zones.is_empty() else ""

func _break_zone(zone_id: String, zone: Dictionary, context: Dictionary) -> void:
	broken_zones[zone_id] = true
	var effect := String(zone.get("on_break", "break"))
	var patterns := zone.get("node_patterns", []) as Array
	var targets := _find_targets(patterns)
	if bool(zone.get("detachable", false)):
		for target in targets:
			_detach_visual(target, context)
	else:
		for target in targets:
			if is_instance_valid(target):
				target.visible = false
	match effect:
		"reduce_speed", "limp":
			speed_multiplier *= clampf(float(zone.get("speed_multiplier", 0.72)), 0.1, 1.0)
			if broken_zones.size() >= 2 and String(profile.get("category", "")) == "robot_biped":
				movement_mode = "crawl"
				_configure_crawl_collision()
		"disable_detection":
			detection_enabled = false
		"shutdown":
			disabled = true
			movement_mode = "shutdown"
		"open_hole":
			movement_mode = "breached"
			_disable_owner_collisions()
		"unlock":
			movement_mode = "unlocked"
			_disable_owner_collisions()
		"disable_gui":
			detection_enabled = false
		"break":
			_disable_owner_collisions()
	zone_broken.emit(zone_id, effect)

func _find_targets(patterns: Array) -> Array[Node3D]:
	var root := get_parent()
	var found: Array[Node3D] = []
	for pattern_variant in patterns:
		var pattern := String(pattern_variant)
		for node in root.find_children(pattern, "Node3D", true, false):
			if node is Node3D and not found.has(node):
				found.append(node as Node3D)
	return found

func _disable_owner_collisions() -> void:
	var owner_node := get_parent()
	for node in owner_node.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if collision != null:
			collision.set_deferred("disabled", true)
	if owner_node is CollisionObject3D:
		(owner_node as CollisionObject3D).collision_layer = 0
		(owner_node as CollisionObject3D).collision_mask = 0

func _configure_crawl_collision() -> void:
	var owner_node := get_parent()
	for node in owner_node.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if collision == null or not collision.shape is CapsuleShape3D:
			continue
		var old_shape := collision.shape as CapsuleShape3D
		var crawl_shape := old_shape.duplicate() as CapsuleShape3D
		crawl_shape.height = maxf(crawl_shape.radius * 2.2, crawl_shape.height * 0.46)
		collision.shape = crawl_shape
		collision.position.y = -maxf(old_shape.height * 0.18, 0.15)

func _detach_visual(target: Node3D, context: Dictionary) -> void:
	if not is_instance_valid(target):
		return
	var mesh_instance := target as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		target.visible = false
		return
	var rigid := RigidBody3D.new()
	rigid.name = target.name + "_Detached"
	rigid.mass = clampf(float(context.get("mass", 3.0)), 0.5, 18.0)
	rigid.collision_layer = 4
	rigid.collision_mask = 1
	var world_transform := target.global_transform
	var duplicate := MeshInstance3D.new()
	duplicate.mesh = mesh_instance.mesh
	duplicate.material_override = mesh_instance.material_override
	rigid.add_child(duplicate)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var bounds := mesh_instance.get_aabb()
	shape.size = Vector3(maxf(bounds.size.x, 0.08), maxf(bounds.size.y, 0.08), maxf(bounds.size.z, 0.08))
	collision.shape = shape
	rigid.add_child(collision)
	if debris_parent:
		debris_parent.add_child(rigid)
		rigid.global_transform = world_transform
		var impulse := context.get("impulse", Vector3.ZERO) as Vector3
		if impulse.is_zero_approx():
			impulse = Vector3.UP * 2.0
		rigid.apply_central_impulse(impulse)
		_runtime_debris.append(rigid)
		while _runtime_debris.size() > max_runtime_debris:
			var oldest: RigidBody3D = _runtime_debris.pop_front() as RigidBody3D
			if is_instance_valid(oldest):
				oldest.queue_free()
	target.visible = false
