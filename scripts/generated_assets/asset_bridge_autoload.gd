extends Node

const BridgeScript := preload("res://scripts/generated_assets/asset_bridge.gd")

var bridge: Variant
var _scan_scheduled := false

func _ready() -> void:
	# Keep the runtime singleton name distinct from the global class at parse time, then expose the
	# stable node path used by gameplay scripts after instantiation.
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
		bridge.register_robot(node as CharacterBody3D, String(node.get_meta("personality", "crawler")))
	elif node is Node3D and node.get_meta("destructible", false) and node.get_node_or_null("DestructibleComponent") == null:
		var material_id := String(node.get_meta("material_id", "metal_light"))
		var health := float(node.get_meta("health", 0.0))
		bridge.register_static_destructible(node as Node3D, material_id, health)

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

func create_segmented_wall(parent: Node3D, at: Vector3, size: Vector3, material_id: String, label: String) -> Node3D:
	if bridge == null:
		return null
	_ensure_initialized(parent)
	return bridge.create_segmented_wall(parent, at, size, material_id, label)

func spawn_asset(asset_id: String, parent: Node3D, transform_value := Transform3D.IDENTITY) -> Node3D:
	if bridge == null:
		return null
	_ensure_initialized(parent)
	return bridge.spawn_asset(asset_id, parent, transform_value)
