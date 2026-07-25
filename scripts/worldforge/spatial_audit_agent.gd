class_name WorldForgeSpatialAuditAgent
extends RefCounted

const MAP_HALF_WIDTH := 16.4
const MAP_MIN_Z := -174.0
const MAP_MAX_Z := -1.0
const FLOOR_Y := 0.0
const CEILING_Y := 8.1

var _issues: Array[Dictionary] = []
var _stats: Dictionary = {}

func audit(scene_root: Node3D) -> Dictionary:
	_issues.clear()
	_stats = {
		"nodes_scanned": 0,
		"generated_nodes": 0,
		"spatial_issues": 0,
		"animation_issues": 0,
		"audio_issues": 0,
		"ui_issues": 0,
		"duplicate_visuals": 0
	}
	_audit_spatial_nodes(scene_root)
	_audit_generated_overlaps(scene_root)
	_audit_robots(scene_root)
	_audit_audio(scene_root)
	_audit_ui(scene_root)
	return {
		"schema_version": 1,
		"agent": "worldforge_spatial_audit_agent_v1",
		"audited_at_unix": int(Time.get_unix_time_from_system()),
		"stats": _stats.duplicate(true),
		"severity": _summary_severity(),
		"issues": _issues.duplicate(true)
	}

func _audit_spatial_nodes(scene_root: Node3D) -> void:
	for candidate in scene_root.find_children("*", "Node3D", true, false):
		if not candidate is Node3D:
			continue
		var node := candidate as Node3D
		_stats["nodes_scanned"] = int(_stats["nodes_scanned"]) + 1
		if bool(node.get_meta("worldforge_generated", false)):
			_stats["generated_nodes"] = int(_stats["generated_nodes"]) + 1
		var pos := node.global_position
		if bool(node.get_meta("worldforge_generated", false)) and (absf(pos.x) > MAP_HALF_WIDTH or pos.z < MAP_MIN_Z or pos.z > MAP_MAX_Z):
			_add_issue("high", "out_of_bounds", node, "Élément généré hors des limites jouables.", {"position": _vec3(pos)})
		if bool(node.get_meta("worldforge_floor_bound", false)):
			var size := _node_size(node)
			var expected_y := FLOOR_Y + size.y * 0.5
			if absf(pos.y - expected_y) > 0.22:
				_add_issue("medium", "unsupported_floor_asset", node, "Objet supposé posé au sol mais décalé verticalement.", {"expected_y": expected_y, "actual_y": pos.y})
		if bool(node.get_meta("worldforge_ceiling_bound", false)):
			if absf(pos.y - (CEILING_Y - 0.7)) > 0.45:
				_add_issue("medium", "misaligned_ceiling_asset", node, "Élément de plafond mal aligné.", {"actual_y": pos.y})
		if node is MeshInstance3D and (node as MeshInstance3D).mesh == null:
			_add_issue("high", "missing_mesh", node, "MeshInstance3D sans ressource de maillage.")
		if node is CollisionShape3D and (node as CollisionShape3D).shape == null:
			_add_issue("high", "missing_collision_shape", node, "CollisionShape3D sans forme.")

func _audit_generated_overlaps(scene_root: Node3D) -> void:
	var cells: Dictionary = {}
	var generated: Array[Node3D] = []
	for candidate in scene_root.find_children("*", "Node3D", true, false):
		if candidate is Node3D and bool(candidate.get_meta("worldforge_generated", false)) and bool(candidate.get_meta("worldforge_replaceable", false)):
			generated.append(candidate as Node3D)
	for node in generated:
		var box := _node_aabb(node)
		if box.size.length_squared() < 0.001:
			continue
		var key := Vector2i(int(floor(box.get_center().x / 4.0)), int(floor(box.get_center().z / 4.0)))
		for gx in range(key.x - 1, key.x + 2):
			for gz in range(key.y - 1, key.y + 2):
				var neighbour_key := Vector2i(gx, gz)
				for other_variant in cells.get(neighbour_key, []):
					var other := other_variant as Node3D
					if other == null or not is_instance_valid(other):
						continue
					var other_box := _node_aabb(other)
					var intersection := box.intersection(other_box)
					if intersection.size.x > 0.12 and intersection.size.y > 0.12 and intersection.size.z > 0.12:
						_add_issue("medium", "generated_overlap", node, "Deux éléments générés s'interpénètrent.", {"other_path": str(other.get_path()), "penetration": _vec3(intersection.size)})
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(node)

func _audit_robots(scene_root: Node3D) -> void:
	for candidate in scene_root.find_children("*", "CharacterBody3D", true, false):
		if not candidate is CharacterBody3D or not bool(candidate.get_meta("robot", false)):
			continue
		var robot := candidate as CharacterBody3D
		var generated_visuals := robot.find_children("GeneratedVisual*", "Node3D", true, false)
		if generated_visuals.size() > 1:
			_stats["duplicate_visuals"] = int(_stats["duplicate_visuals"]) + generated_visuals.size() - 1
			_add_issue("high", "duplicate_robot_visual", robot, "Plusieurs modèles visuels sont attachés au même robot.", {"count": generated_visuals.size()})
		var procedural := robot.find_child("ProceduralVisual", true, false)
		var generated := robot.find_child("GeneratedVisual", true, false)
		if generated != null and procedural != null and procedural is Node3D and (procedural as Node3D).visible:
			_add_issue("high", "procedural_generated_superposition", robot, "Le placeholder procédural reste visible sous le modèle généré.")
		if generated != null:
			var animation_player := generated.find_child("AnimationPlayer", true, false)
			if animation_player == null or not animation_player is AnimationPlayer:
				_stats["animation_issues"] = int(_stats["animation_issues"]) + 1
				_add_issue("high", "missing_robot_animation_player", robot, "Modèle robot sans AnimationPlayer détectable.")
			else:
				var required := ["Idle-loop", "Walk-loop", "Run-loop", "Attack", "Shutdown"]
				for clip in required:
					if not (animation_player as AnimationPlayer).has_animation(clip):
						_stats["animation_issues"] = int(_stats["animation_issues"]) + 1
						_add_issue("medium", "missing_animation_clip", robot, "Animation requise absente : %s" % clip, {"clip": clip})

func _audit_audio(scene_root: Node3D) -> void:
	for candidate in scene_root.find_children("*", "AudioStreamPlayer3D", true, false):
		if not candidate is AudioStreamPlayer3D:
			continue
		var player := candidate as AudioStreamPlayer3D
		if player.stream == null:
			_stats["audio_issues"] = int(_stats["audio_issues"]) + 1
			_add_issue("medium", "missing_audio_stream", player, "Source audio 3D sans flux sonore.")
		if player.max_distance <= 0.0 or player.max_distance > 80.0:
			_stats["audio_issues"] = int(_stats["audio_issues"]) + 1
			_add_issue("low", "invalid_audio_range", player, "Portée audio 3D incohérente.", {"max_distance": player.max_distance})
	for candidate in scene_root.find_children("GeneratedVisual*", "Node3D", true, false):
		if candidate is Node3D and candidate.has_meta("generated_asset_id"):
			var audio_component := candidate.get_node_or_null("GeneratedAssetAudio")
			if audio_component == null:
				_stats["audio_issues"] = int(_stats["audio_issues"]) + 1
				_add_issue("low", "generated_audio_component_missing", candidate, "Asset généré sans composant audio synchronisé.")

func _audit_ui(scene_root: Node3D) -> void:
	var viewport_rect := scene_root.get_viewport().get_visible_rect()
	var start_panel = scene_root.get("start_panel")
	var game_started_value = scene_root.get("game_started")
	var game_started := bool(game_started_value) if game_started_value != null else false
	if start_panel is Control and (start_panel as Control).visible:
		var panel := start_panel as Control
		if panel.z_index < 100:
			_stats["ui_issues"] = int(_stats["ui_issues"]) + 1
			_add_issue("high", "start_panel_behind_hud", panel, "Le menu de démarrage peut être recouvert par le HUD.", {"z_index": panel.z_index})
		for child in panel.find_children("*", "Control", true, false):
			if child is Control and (child as Control).visible:
				var rect := (child as Control).get_global_rect()
				if rect.size.x > 4.0 and rect.size.y > 4.0 and not viewport_rect.encloses(rect.grow(-1.0)):
					_stats["ui_issues"] = int(_stats["ui_issues"]) + 1
					_add_issue("medium", "start_ui_outside_viewport", child, "Contrôle du menu hors de la zone visible.", {"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	if not game_started and start_panel is Control and (start_panel as Control).visible:
		for property_name in ["phase_label", "objective_label", "status_label", "health_label", "fear_label", "athena_hud_label", "task_hint_label"]:
			var value = scene_root.get(property_name)
			if value is Control and (value as Control).visible:
				_stats["ui_issues"] = int(_stats["ui_issues"]) + 1
				_add_issue("high", "hud_visible_over_start_menu", value, "Élément HUD visible au-dessus du menu de démarrage.", {"property": property_name})

func _node_size(node: Node3D) -> Vector3:
	var metadata = node.get_meta("size", null)
	if metadata is Vector3:
		return metadata
	var box := _node_aabb(node)
	return box.size if box.size.length_squared() > 0.001 else Vector3.ONE

func _node_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	var inverse := node.global_transform.affine_inverse()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb()
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		if not candidate is MeshInstance3D or (candidate as MeshInstance3D).mesh == null:
			continue
		var mesh := candidate as MeshInstance3D
		var local_box := (inverse * mesh.global_transform) * mesh.get_aabb()
		if not initialized:
			result = local_box
			initialized = true
		else:
			result = result.merge(local_box)
	return node.global_transform * result if initialized else AABB(node.global_position, Vector3.ZERO)

func _add_issue(severity: String, code: String, node: Node, message: String, details := {}) -> void:
	var category := "spatial_issues"
	if code.contains("animation"):
		category = "animation_issues"
	elif code.contains("audio"):
		category = "audio_issues"
	elif code.contains("ui") or code.contains("hud") or code.contains("panel"):
		category = "ui_issues"
	_stats[category] = int(_stats.get(category, 0)) + 1
	_issues.append({
		"severity": severity,
		"code": code,
		"node_path": str(node.get_path()) if node != null and node.is_inside_tree() else "",
		"node_name": node.name if node != null else "",
		"message": message,
		"details": details
	})

func _summary_severity() -> String:
	for issue in _issues:
		if String(issue.get("severity", "")) == "high":
			return "high"
	for issue in _issues:
		if String(issue.get("severity", "")) == "medium":
			return "medium"
	return "low" if not _issues.is_empty() else "clean"

func _vec3(value: Vector3) -> Array:
	return [round(value.x * 1000.0) / 1000.0, round(value.y * 1000.0) / 1000.0, round(value.z * 1000.0) / 1000.0]
