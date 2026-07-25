extends Node

const BridgeScript := preload("res://scripts/generated_assets/asset_bridge.gd")
const GeneratedAudioScript := preload("res://scripts/generated_assets/generated_asset_audio.gd")

var bridge: Variant
var _scan_scheduled := false

func _ready() -> void:
	name = "GeneratedAssetBridge"
	process_mode = Node.PROCESS_MODE_ALWAYS
	bridge = BridgeScript.new()
	bridge.name = "RuntimeBridge"
	add_child(bridge)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	await get_tree().process_frame
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		await get_tree().process_frame
		scene = get_tree().current_scene as Node3D
	if scene == null:
		push_warning("GeneratedAssetBridge could not find the current 3D scene")
		return
	_ensure_initialized(scene)
	_scan_scene(scene)

func _ensure_initialized(scene: Node3D) -> void:
	if bridge == null:
		return
	if bridge.world_root == null:
		bridge.initialize(scene)

func _on_node_added(_node: Node) -> void:
	if _scan_scheduled:
		return
	_scan_scheduled = true
	call_deferred("_rescan_current_scene")

func _rescan_current_scene() -> void:
	_scan_scheduled = false
	var scene := get_tree().current_scene as Node3D
	if scene != null:
		_ensure_initialized(scene)
		_scan_scene(scene)

func _scan_scene(root: Node) -> void:
	_register_candidate(root)
	for node in root.find_children("*", "Node", true, false):
		_register_candidate(node)

func _register_candidate(node: Node) -> void:
	if bridge == null or bridge.world_root == null:
		return
	if node is CharacterBody3D and node.get_meta("robot", false):
		var robot := node as CharacterBody3D
		var personality := String(robot.get_meta("personality", "crawler"))
		bridge.register_robot(robot, personality)
		_force_preferred_robot_visual(robot, personality)
		call_deferred("_enforce_robot_visual_replacement", robot)
	elif node is Node3D and node.get_meta("destructible", false) and node.get_node_or_null("DestructibleComponent") == null:
		var material_id := String(node.get_meta("material_id", "metal_light"))
		var health := float(node.get_meta("health", 0.0))
		bridge.register_static_destructible(node as Node3D, material_id, health)

	if node is Node3D and node.has_meta("generated_asset_id"):
		_attach_audio(node as Node3D, get_asset(String(node.get_meta("generated_asset_id", ""))))
	elif node is Node3D and node.name == "GeneratedVisual":
		var current := node.get_parent()
		while current != null and not current.has_meta("generated_asset_id"):
			current = current.get_parent()
		if current != null:
			_attach_audio(node as Node3D, get_asset(String(current.get_meta("generated_asset_id", ""))))

func _force_preferred_robot_visual(robot: CharacterBody3D, personality: String) -> void:
	var preferred := _preferred_robot_entry(personality)
	if preferred.is_empty():
		return
	var preferred_id := String(preferred.get("id", ""))
	var current := robot.get_node_or_null("GeneratedVisual") as Node3D
	if current == null:
		current = robot.find_child("GeneratedVisual", true, false) as Node3D
	var current_id := String(current.get_meta("generated_asset_id", "")) if current != null else ""
	if current_id == preferred_id:
		robot.set_meta("generated_asset_id", preferred_id)
		return
	robot.set_meta("generated_asset_id", preferred_id)
	bridge.call("_attach_generated_visual", robot, preferred)

func _preferred_robot_entry(personality: String) -> Dictionary:
	var category := "robot_biped" if personality == "specter" else "robot_quadruped"
	var preferred_ids := ["specter_5", "specter_05"] if personality == "specter" else ["crawler_7", "crawler_07"]
	var best: Dictionary = {}
	var best_score := -1
	for asset_id in preferred_ids:
		var entry := get_asset(asset_id)
		if entry.is_empty() or String(entry.get("category", "")) != category:
			continue
		var usage := entry.get("reference_usage", {}) as Dictionary
		var images_used := int(usage.get("images_used", 0))
		var score := images_used * 20
		if String(entry.get("integration", "")) == "replace_procedural":
			score += 8
		if not String(entry.get("audio_profile", "")).is_empty():
			score += 4
		score += (entry.get("animations", []) as Array).size()
		if score > best_score:
			best = entry
			best_score = score
	return best

func _enforce_robot_visual_replacement(robot: CharacterBody3D) -> void:
	if not is_instance_valid(robot):
		return
	var generated := robot.get_node_or_null("GeneratedVisual") as Node3D
	if generated == null:
		generated = robot.find_child("GeneratedVisual", true, false) as Node3D
	if generated == null:
		return
	generated.visible = true
	_remove_procedural_visual(robot, generated)
	await get_tree().process_frame
	if is_instance_valid(robot) and is_instance_valid(generated):
		_remove_procedural_visual(robot, generated)
		robot.set_meta("generated_visual_replacement_finalized", true)

func _remove_procedural_visual(robot: CharacterBody3D, generated: Node3D) -> void:
	var procedural := robot.get_node_or_null("ProceduralVisual") as Node3D
	if procedural != null and procedural != generated and not generated.is_ancestor_of(procedural):
		procedural.visible = false
		procedural.process_mode = Node.PROCESS_MODE_DISABLED
		for child in procedural.find_children("*", "GeometryInstance3D", true, false):
			var geometry := child as GeometryInstance3D
			if geometry != null:
				geometry.visible = false
				geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		procedural.queue_free()
	for candidate in robot.find_children("GeneratedVisual*", "Node3D", true, false):
		var visual := candidate as Node3D
		if visual != null and visual != generated and not generated.is_ancestor_of(visual):
			visual.queue_free()
	for child in robot.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		if geometry == null or geometry == generated or generated.is_ancestor_of(geometry):
			continue
		geometry.visible = false
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.set_meta("hidden_by_generated_asset", true)

func _attach_audio(target: Node3D, entry: Dictionary) -> void:
	if target == null or entry.is_empty() or target.get_node_or_null("GeneratedAssetAudio") != null:
		return
	var profile_path := String(entry.get("audio_profile", ""))
	if profile_path.is_empty() or not FileAccess.file_exists(profile_path):
		return
	var component := GeneratedAudioScript.new()
	component.name = "GeneratedAssetAudio"
	target.add_child(component)
	component.call_deferred("configure", profile_path)

func reload_catalog() -> void:
	if bridge == null:
		return
	bridge.call("_reload_catalog")

func has_asset(asset_id: String) -> bool:
	return bool(bridge.has_asset(asset_id)) if bridge != null else false

func get_asset(asset_id: String) -> Dictionary:
	return bridge.get_asset(asset_id) as Dictionary if bridge != null else {}

func list_assets(category := "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if bridge == null:
		return result
	for asset_id in bridge.catalog.keys():
		var entry := bridge.get_asset(String(asset_id)) as Dictionary
		if category.is_empty() or String(entry.get("category", "")) == category:
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("id", "")) < String(b.get("id", "")))
	return result

func apply_damage(target: Node, context: Dictionary) -> Dictionary:
	return bridge.apply_damage(target, context) if bridge != null else {"handled": false}

func get_speed_multiplier(target: Node) -> float:
	return bridge.get_speed_multiplier(target) if bridge != null else 1.0

func get_movement_mode(target: Node) -> String:
	return bridge.get_movement_mode(target) if bridge != null else "normal"

func is_detection_enabled(target: Node) -> bool:
	return bridge.is_detection_enabled(target) if bridge != null else true

func is_disabled(target: Node) -> bool:
	return bridge.is_disabled(target) if bridge != null else false

func register_destructible(target: Node3D, material_id: String, health := 0.0, zone_id := "core") -> void:
	if bridge == null or target == null:
		return
	_ensure_initialized(target)
	bridge.register_static_destructible(target, material_id, health, zone_id)

func create_segmented_wall(parent: Node3D, at: Vector3, size: Vector3, material_id: String, label: String) -> Node3D:
	if bridge == null:
		return null
	_ensure_initialized(parent)
	return bridge.create_segmented_wall(parent, at, size, material_id, label)

func spawn_asset(asset_id: String, parent: Node3D, transform_value := Transform3D.IDENTITY) -> Node3D:
	if bridge == null or parent == null:
		return null
	_ensure_initialized(parent)
	var instance := bridge.spawn_asset(asset_id, parent, transform_value) as Node3D
	if instance != null:
		instance.set_meta("generated_asset_id", asset_id)
		_attach_audio(instance, get_asset(asset_id))
	return instance

func spawn_fps_viewmodel(asset_id: String, camera: Camera3D, local_transform := Transform3D.IDENTITY) -> Node3D:
	if camera == null:
		return null
	var entry := get_asset(asset_id)
	if entry.is_empty() or String(entry.get("category", "")) != "fps_viewmodel":
		push_warning("Asset %s is not an FPS viewmodel" % asset_id)
		return null
	var instance := spawn_asset(asset_id, camera, local_transform)
	if instance == null:
		return null
	instance.name = "GeneratedFPSViewmodel_%s" % asset_id
	instance.set_meta("generated_fps_viewmodel", true)
	for node in instance.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry != null:
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func replace_visual(target: Node3D, asset_id: String, preserve_collisions := true) -> Node3D:
	if target == null:
		return null
	var instance := spawn_asset(asset_id, target, Transform3D.IDENTITY)
	if instance == null:
		return null
	instance.name = "GeneratedVisual_%s" % asset_id
	for child in target.get_children():
		if child == instance or child.name == "DestructibleComponent":
			continue
		if preserve_collisions and (child is CollisionShape3D or child is CollisionObject3D):
			continue
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	return instance
