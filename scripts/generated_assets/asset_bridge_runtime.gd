extends "res://scripts/generated_assets/asset_bridge_autoload.gd"

const ROBOT_ASSET_CANDIDATES := {
	"specter": ["specter_05", "specter_5"],
	"crawler": ["crawler_07", "crawler_7"]
}

func _register_candidate(node: Node) -> void:
	if bridge == null or bridge.world_root == null:
		return
	if node is CharacterBody3D and node.get_meta("robot", false):
		_register_current_robot(node as CharacterBody3D)
	elif node is Node3D and node.get_meta("destructible", false) and node.get_node_or_null("DestructibleComponent") == null:
		var material_id := String(node.get_meta("material_id", "metal_light"))
		var health := float(node.get_meta("health", 0.0))
		bridge.register_static_destructible(node as Node3D, material_id, health)
	if node is Node3D and node.name == "GeneratedVisual":
		var owner := node.get_parent()
		if owner != null:
			var asset_id := String(owner.get_meta("generated_asset_id", ""))
			if asset_id.is_empty() and owner.get_parent() != null:
				asset_id = String(owner.get_parent().get_meta("generated_asset_id", ""))
			if not asset_id.is_empty():
				_attach_audio(node as Node3D, get_asset(asset_id))
	elif node is Node3D and node.has_meta("generated_asset_id"):
		_attach_audio(node as Node3D, get_asset(String(node.get_meta("generated_asset_id", ""))))

func _register_current_robot(robot: CharacterBody3D) -> void:
	if robot == null or bridge.registered.has(robot.get_instance_id()):
		return
	var personality := String(robot.get_meta("personality", "crawler"))
	var asset_id := _resolve_robot_asset_id(personality)
	var entry := get_asset(asset_id)
	robot.set_meta("generated_asset_id", asset_id)
	if not entry.is_empty():
		var integration := String(entry.get("integration", "catalog_only"))
		if integration == "replace_procedural" or integration == "bridge_module":
			bridge.call("_attach_generated_visual", robot, entry)
	var fallback_id := "specter_5" if personality == "specter" else "crawler_7"
	var fallback_profile: Dictionary = bridge.call("_fallback_robot_profile", fallback_id) as Dictionary
	var profile: Dictionary = bridge.call("_load_damage_profile", entry, fallback_profile) as Dictionary
	profile["category"] = "robot_biped" if personality == "specter" else "robot_quadruped"
	bridge.call("_attach_component", robot, profile)
	bridge.registered[robot.get_instance_id()] = asset_id
	call_deferred("_finalize_current_robot", robot, asset_id)

func _resolve_robot_asset_id(personality: String) -> String:
	var key := "specter" if personality == "specter" else "crawler"
	var candidates: Array = ROBOT_ASSET_CANDIDATES[key]
	for candidate_variant in candidates:
		var candidate := String(candidate_variant)
		if has_asset(candidate):
			return candidate
	return String(candidates[0])

func _finalize_current_robot(robot: CharacterBody3D, asset_id: String) -> void:
	if not is_instance_valid(robot):
		return
	var generated := robot.get_node_or_null("GeneratedVisual") as Node3D
	if generated == null:
		generated = robot.find_child("GeneratedVisual", true, false) as Node3D
	if generated == null:
		return
	generated.set_meta("generated_asset_id", asset_id)
	_attach_audio(generated, get_asset(asset_id))
	_enforce_robot_visual_replacement(robot)
	robot.set_meta("generated_visual_asset_id", asset_id)
	robot.set_meta("generated_visual_replacement_finalized", true)
