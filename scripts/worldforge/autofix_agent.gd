class_name WorldForgeAutoRepairAgent
extends RefCounted

const MAP_HALF_WIDTH := 16.1
const MAP_MIN_Z := -173.0
const MAP_MAX_Z := -2.0
const FLOOR_Y := 0.0
const CEILING_ASSET_Y := 7.4

func repair(scene_root: Node3D, report: Dictionary) -> Dictionary:
	var actions: Array[Dictionary] = []
	for issue_variant in report.get("issues", []):
		if not issue_variant is Dictionary:
			continue
		var issue := issue_variant as Dictionary
		var node_path := String(issue.get("node_path", ""))
		var node := scene_root.get_node_or_null(NodePath(node_path)) if not node_path.is_empty() else null
		var code := String(issue.get("code", ""))
		match code:
			"out_of_bounds":
				if node is Node3D and bool(node.get_meta("worldforge_generated", false)):
					var spatial := node as Node3D
					var before := spatial.global_position
					var after := before
					after.x = clampf(after.x, -MAP_HALF_WIDTH, MAP_HALF_WIDTH)
					after.z = clampf(after.z, MAP_MIN_Z, MAP_MAX_Z)
					spatial.global_position = after
					_actions_append(actions, code, spatial, before, after)
			"unsupported_floor_asset":
				if node is Node3D and bool(node.get_meta("worldforge_generated", false)):
					var spatial := node as Node3D
					var before := spatial.global_position
					var size := _node_size(spatial)
					var after := Vector3(before.x, FLOOR_Y + size.y * 0.5, before.z)
					spatial.global_position = after
					_actions_append(actions, code, spatial, before, after)
			"misaligned_ceiling_asset":
				if node is Node3D and bool(node.get_meta("worldforge_generated", false)):
					var spatial := node as Node3D
					var before := spatial.global_position
					var after := Vector3(before.x, CEILING_ASSET_Y, before.z)
					spatial.global_position = after
					_actions_append(actions, code, spatial, before, after)
			"generated_overlap":
				if node is Node3D and bool(node.get_meta("worldforge_generated", false)):
					_resolve_generated_overlap(scene_root, node as Node3D, issue, actions)
			"procedural_generated_superposition", "duplicate_robot_visual":
				if node != null:
					_repair_robot_visuals(node, actions, code)
			"invalid_audio_range":
				if node is AudioStreamPlayer3D:
					var audio := node as AudioStreamPlayer3D
					var before_range := audio.max_distance
					audio.max_distance = clampf(audio.max_distance, 8.0, 36.0)
					actions.append({"code": code, "node_path": str(audio.get_path()), "before": before_range, "after": audio.max_distance})
			"start_panel_behind_hud", "start_ui_outside_viewport", "hud_visible_over_start_menu":
				_repair_start_ui(scene_root, actions)
	_repair_start_ui(scene_root, actions)
	_repair_all_robot_visuals(scene_root, actions)
	return {
		"schema_version": 1,
		"agent": "worldforge_autofix_agent_v1",
		"repaired_at_unix": int(Time.get_unix_time_from_system()),
		"action_count": actions.size(),
		"actions": actions
	}

func _resolve_generated_overlap(scene_root: Node3D, node: Node3D, issue: Dictionary, actions: Array[Dictionary]) -> void:
	var before := node.global_position
	var side_sign := -1.0 if before.x < 0.0 else 1.0
	var offsets := [
		Vector3(side_sign * 0.7, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.8),
		Vector3(0.0, 0.0, -0.8),
		Vector3(side_sign * 1.4, 0.0, 0.0)
	]
	var details := issue.get("details", {}) as Dictionary
	var other_path := String(details.get("other_path", ""))
	var other := scene_root.get_node_or_null(NodePath(other_path)) if not other_path.is_empty() else null
	for offset in offsets:
		var candidate := before + offset
		candidate.x = clampf(candidate.x, -MAP_HALF_WIDTH, MAP_HALF_WIDTH)
		candidate.z = clampf(candidate.z, MAP_MIN_Z, MAP_MAX_Z)
		if other is Node3D and candidate.distance_to((other as Node3D).global_position) < 0.65:
			continue
		node.global_position = candidate
		_actions_append(actions, "generated_overlap", node, before, candidate)
		return

func _repair_all_robot_visuals(scene_root: Node3D, actions: Array[Dictionary]) -> void:
	for candidate in scene_root.find_children("*", "CharacterBody3D", true, false):
		if candidate is CharacterBody3D and bool(candidate.get_meta("robot", false)):
			_repair_robot_visuals(candidate, actions, "robot_visual_consistency")

func _repair_robot_visuals(robot_node: Node, actions: Array[Dictionary], code: String) -> void:
	var generated := robot_node.find_child("GeneratedVisual", true, false)
	if generated == null:
		var generated_candidates := robot_node.find_children("GeneratedVisual*", "Node3D", true, false)
		if not generated_candidates.is_empty():
			generated = generated_candidates[0]
	if generated == null or not generated is Node3D:
		return
	var generated_3d := generated as Node3D
	generated_3d.visible = true
	var changed := false
	var procedural := robot_node.find_child("ProceduralVisual", true, false)
	if procedural is Node3D:
		(procedural as Node3D).visible = false
		(procedural as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
		(procedural as Node3D).queue_free()
		changed = true
	for candidate in robot_node.find_children("GeneratedVisual*", "Node3D", true, false):
		if candidate is Node3D and candidate != generated_3d and not generated_3d.is_ancestor_of(candidate):
			(candidate as Node3D).queue_free()
			changed = true
	if changed:
		actions.append({"code": code, "node_path": str(robot_node.get_path()), "result": "generated_visual_kept_procedural_removed"})

func _repair_start_ui(scene_root: Node3D, actions: Array[Dictionary]) -> void:
	var panel_value = scene_root.get("start_panel")
	if not panel_value is Control:
		return
	var panel := panel_value as Control
	panel.z_index = 500
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.move_to_front()
	var viewport_size := scene_root.get_viewport().get_visible_rect().size
	var content_width := clampf(viewport_size.x * 0.72, 560.0, 880.0)
	var content_height := clampf(viewport_size.y * 0.76, 430.0, 610.0)
	var content: Control = null
	for child in panel.get_children():
		if child is VBoxContainer:
			content = child as Control
			break
	if content != null:
		content.set_anchors_preset(Control.PRESET_CENTER)
		content.position = Vector2(-content_width * 0.5, -content_height * 0.5)
		content.size = Vector2(content_width, content_height)
		content.custom_minimum_size = Vector2(content_width, content_height)
		for child in content.get_children():
			if child is Label:
				var label := child as Label
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.clip_text = false
				var label_minimum := label.custom_minimum_size
				label_minimum.x = minf(content_width - 36.0, maxf(label_minimum.x, 320.0))
				label.custom_minimum_size = label_minimum
			if child is Button:
				var button := child as Button
				var button_minimum := button.custom_minimum_size
				button_minimum.x = minf(content_width - 48.0, 520.0)
				button.custom_minimum_size = button_minimum
				button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var game_started_value = scene_root.get("game_started")
	var game_started := bool(game_started_value) if game_started_value != null else false
	var intro_value = scene_root.get("intro_panel")
	var intro_visible := intro_value is Control and (intro_value as Control).visible
	var overlay_active := not game_started and (panel.visible or intro_visible)
	for property_name in ["phase_label", "objective_label", "status_label", "health_label", "fear_label", "athena_hud_label", "task_hint_label", "hud_round_label", "hud_seed_label"]:
		var value = scene_root.get(property_name)
		if value is Control:
			(value as Control).visible = not overlay_active
	var mobile_value = scene_root.get("mobile_layer")
	if mobile_value is Control:
		(mobile_value as Control).visible = game_started and not overlay_active
	actions.append({"code": "ui_safe_layout", "node_path": str(panel.get_path()), "overlay_active": overlay_active, "content_size": [content_width, content_height]})

func _node_size(node: Node3D) -> Vector3:
	var value = node.get_meta("size", null)
	if value is Vector3:
		return value
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).get_aabb().size * node.global_transform.basis.get_scale()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			return (child as MeshInstance3D).get_aabb().size * (child as MeshInstance3D).global_transform.basis.get_scale()
	return Vector3.ONE

func _actions_append(actions: Array[Dictionary], code: String, node: Node3D, before: Vector3, after: Vector3) -> void:
	actions.append({
		"code": code,
		"node_path": str(node.get_path()),
		"before": [before.x, before.y, before.z],
		"after": [after.x, after.y, after.z]
	})
