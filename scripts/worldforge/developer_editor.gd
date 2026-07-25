class_name WorldForgeDeveloperEditor
extends CanvasLayer

var coordinator: Node
var scene_root: Node3D
var panel: PanelContainer
var seed_field: LineEdit
var asset_selector: OptionButton
var target_selector: OptionButton
var status_label: RichTextLabel
var _asset_ids: Array[String] = []
var _target_paths: Array[NodePath] = []

func configure(runtime_coordinator: Node, root: Node3D) -> void:
	coordinator = runtime_coordinator
	scene_root = root
	name = "WorldForgeDeveloperEditor"
	layer = 900
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_lists()
	visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F10 and key_event.ctrl_pressed and key_event.shift_pressed:
			visible = not visible
			if visible:
				_refresh_lists()
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "DeveloperPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-460.0, -345.0)
	panel.size = Vector2(440.0, 690.0)
	panel.custom_minimum_size = Vector2(440.0, 690.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.018, 0.024, 0.97)
	style.border_color = Color(0.05, 0.68, 0.84, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "WORLDFORGE // ÉDITEUR DÉVELOPPEUR"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(0.55, 0.9, 1.0)
	column.add_child(title)
	var warning := Label.new()
	warning.text = "Invisible en production. Raccourci : Ctrl + Maj + F10"
	warning.modulate = Color(0.7, 0.74, 0.76)
	warning.add_theme_font_size_override("font_size", 12)
	column.add_child(warning)

	seed_field = LineEdit.new()
	seed_field.placeholder_text = "Seed de génération"
	seed_field.text = str(coordinator.call("get_current_seed")) if coordinator != null else "0"
	column.add_child(_row("Seed", seed_field))

	var seed_buttons := HBoxContainer.new()
	seed_buttons.add_child(_button("Régénérer", _regenerate))
	seed_buttons.add_child(_button("Seed aléatoire", _random_seed))
	column.add_child(seed_buttons)

	asset_selector = OptionButton.new()
	asset_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_row("Asset", asset_selector))
	target_selector = OptionButton.new()
	target_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_row("Cible", target_selector))

	var placement_buttons := HBoxContainer.new()
	placement_buttons.add_child(_button("Placer devant", _spawn_selected_asset))
	placement_buttons.add_child(_button("Remplacer", _replace_selected_target))
	placement_buttons.add_child(_button("Supprimer", _delete_selected_target))
	column.add_child(placement_buttons)

	var nudge_grid := GridContainer.new()
	nudge_grid.columns = 4
	nudge_grid.add_child(_button("X−", func(): _nudge_target(Vector3(-0.25, 0.0, 0.0))))
	nudge_grid.add_child(_button("X+", func(): _nudge_target(Vector3(0.25, 0.0, 0.0))))
	nudge_grid.add_child(_button("Z−", func(): _nudge_target(Vector3(0.0, 0.0, -0.25))))
	nudge_grid.add_child(_button("Z+", func(): _nudge_target(Vector3(0.0, 0.0, 0.25))))
	nudge_grid.add_child(_button("Y−", func(): _nudge_target(Vector3(0.0, -0.10, 0.0))))
	nudge_grid.add_child(_button("Y+", func(): _nudge_target(Vector3(0.0, 0.10, 0.0))))
	nudge_grid.add_child(_button("Rotation +15°", _rotate_target))
	nudge_grid.add_child(_button("Poser au sol", _drop_target_to_floor))
	column.add_child(nudge_grid)

	var agent_buttons := HBoxContainer.new()
	agent_buttons.add_child(_button("Auditer", _audit))
	agent_buttons.add_child(_button("Corriger auto", _autofix))
	agent_buttons.add_child(_button("Sauver manifeste", _save_manifest))
	column.add_child(agent_buttons)

	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.fit_content = false
	status_label.scroll_active = true
	status_label.custom_minimum_size = Vector2(400.0, 250.0)
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_label.text = "[color=#85dfff]WorldForge prêt.[/color]\nLancer un audit avant de publier une nouvelle map."
	column.add_child(status_label)

	var close_button := _button("FERMER L'ÉDITEUR", func(): visible = false)
	column.add_child(close_button)

func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(78.0, 34.0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(92.0, 36.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button

func _refresh_lists() -> void:
	_refresh_assets()
	_refresh_targets()
	if coordinator != null:
		seed_field.text = str(coordinator.call("get_current_seed"))

func _refresh_assets() -> void:
	asset_selector.clear()
	_asset_ids.clear()
	var bridge := get_node_or_null("/root/GeneratedAssetRuntime")
	if bridge == null or not bridge.has_method("list_assets"):
		asset_selector.add_item("Aucun catalogue chargé")
		return
	var assets: Array = bridge.call("list_assets")
	for entry_variant in assets:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var asset_id := String(entry.get("id", ""))
		if asset_id.is_empty():
			continue
		_asset_ids.append(asset_id)
		asset_selector.add_item("%s  [%s]" % [String(entry.get("name", asset_id)), String(entry.get("category", "asset"))])

func _refresh_targets() -> void:
	target_selector.clear()
	_target_paths.clear()
	if scene_root == null:
		return
	for candidate in scene_root.find_children("*", "Node3D", true, false):
		if not candidate is Node3D:
			continue
		if bool(candidate.get_meta("worldforge_replaceable", false)) or bool(candidate.get_meta("worldforge_generated", false)):
			_target_paths.append(candidate.get_path())
			target_selector.add_item(String(candidate.name))
	if _target_paths.is_empty():
		target_selector.add_item("Aucune cible WorldForge")

func _selected_asset_id() -> String:
	var index := asset_selector.selected
	return _asset_ids[index] if index >= 0 and index < _asset_ids.size() else ""

func _selected_target() -> Node3D:
	var index := target_selector.selected
	if index < 0 or index >= _target_paths.size() or scene_root == null:
		return null
	return scene_root.get_node_or_null(_target_paths[index]) as Node3D

func _regenerate() -> void:
	if coordinator == null:
		return
	var seed_value := int(seed_field.text) if seed_field.text.is_valid_int() else int(Time.get_unix_time_from_system())
	var result: Dictionary = coordinator.call("regenerate", seed_value)
	_log_result("RÉGÉNÉRATION", result)
	_refresh_lists()

func _random_seed() -> void:
	seed_field.text = str(int(Time.get_unix_time_from_system() * 1000.0) ^ randi())
	_regenerate()

func _spawn_selected_asset() -> void:
	var asset_id := _selected_asset_id()
	var bridge := get_node_or_null("/root/GeneratedAssetRuntime")
	if asset_id.is_empty() or bridge == null or scene_root == null:
		_log("Asset ou runtime indisponible.", true)
		return
	var camera := scene_root.get_viewport().get_camera_3d()
	if camera == null:
		_log("Caméra 3D introuvable.", true)
		return
	var at := camera.global_position + (-camera.global_transform.basis.z) * 4.0
	at.y = maxf(at.y, 0.8)
	var transform_value := Transform3D(Basis.IDENTITY, at)
	var instance := bridge.call("spawn_asset", asset_id, scene_root, transform_value) as Node3D
	if instance == null:
		_log("Échec du placement de %s." % asset_id, true)
		return
	instance.set_meta("worldforge_generated", true)
	instance.set_meta("worldforge_replaceable", true)
	instance.set_meta("worldforge_role", "developer_asset")
	_log("Asset %s placé devant la caméra." % asset_id)
	_refresh_targets()

func _replace_selected_target() -> void:
	var target := _selected_target()
	var asset_id := _selected_asset_id()
	var bridge := get_node_or_null("/root/GeneratedAssetRuntime")
	if target == null or asset_id.is_empty() or bridge == null:
		_log("Sélection asset/cible incomplète.", true)
		return
	var instance := bridge.call("replace_visual", target, asset_id, true) as Node3D
	if instance == null:
		_log("Le remplacement a échoué.", true)
		return
	instance.set_meta("worldforge_generated", true)
	instance.set_meta("worldforge_replaceable", true)
	_log("%s remplacé visuellement par %s." % [target.name, asset_id])

func _delete_selected_target() -> void:
	var target := _selected_target()
	if target == null or not bool(target.get_meta("worldforge_generated", false)):
		_log("Seuls les éléments WorldForge peuvent être supprimés ici.", true)
		return
	target.queue_free()
	_log("Élément supprimé : %s" % target.name)
	call_deferred("_refresh_targets")

func _nudge_target(offset: Vector3) -> void:
	var target := _selected_target()
	if target == null:
		return
	target.global_position += offset
	_log("%s déplacé de %s" % [target.name, offset])

func _rotate_target() -> void:
	var target := _selected_target()
	if target == null:
		return
	target.rotation_degrees.y = fmod(target.rotation_degrees.y + 15.0, 360.0)
	_log("Rotation de %s : %.1f°" % [target.name, target.rotation_degrees.y])

func _drop_target_to_floor() -> void:
	var target := _selected_target()
	if target == null:
		return
	var size_value = target.get_meta("size", Vector3.ONE)
	var size := size_value if size_value is Vector3 else Vector3.ONE
	target.global_position.y = size.y * 0.5
	_log("%s reposé au sol." % target.name)

func _audit() -> void:
	if coordinator == null:
		return
	var result: Dictionary = coordinator.call("run_audit", false)
	_log_result("AUDIT", result)

func _autofix() -> void:
	if coordinator == null:
		return
	var result: Dictionary = coordinator.call("run_audit", true)
	_log_result("AUDIT + CORRECTION", result)
	_refresh_targets()

func _save_manifest() -> void:
	if coordinator == null:
		return
	var path := String(coordinator.call("save_snapshot"))
	_log("Snapshot sauvegardé : %s" % path)

func _log_result(title: String, result: Dictionary) -> void:
	var report := result.get("report", result) as Dictionary
	var issue_count := (report.get("issues", []) as Array).size()
	var severity := String(report.get("severity", "n/a"))
	var repair := result.get("repair", {}) as Dictionary
	status_label.text = "[color=#85dfff][b]%s[/b][/color]\nSeed : %s\nSévérité : %s\nAnomalies : %d\nCorrections : %d\n\n%s" % [
		title,
		str(coordinator.call("get_current_seed")),
		severity,
		issue_count,
		int(repair.get("action_count", 0)),
		_issue_summary(report)
	]

func _issue_summary(report: Dictionary) -> String:
	var lines: Array[String] = []
	var issues: Array = report.get("issues", [])
	for index in range(mini(issues.size(), 9)):
		var issue := issues[index] as Dictionary
		lines.append("• [%s] %s — %s" % [String(issue.get("severity", "?")), String(issue.get("node_name", "node")), String(issue.get("message", ""))])
	if issues.size() > 9:
		lines.append("… %d anomalies supplémentaires" % (issues.size() - 9))
	return "\n".join(lines) if not lines.is_empty() else "Aucune anomalie détectée."

func _log(message: String, error := false) -> void:
	status_label.text = ("[color=#ff776d]" if error else "[color=#85dfff]") + message + "[/color]\n" + status_label.text
