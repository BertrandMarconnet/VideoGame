extends RefCounted
## One readable HUD, one modal at a time, touch geometry recomputed on resize.

var game: Node3D
var hud: PanelContainer
var bars: Label
var notice: Label
var action_back: ColorRect
var dialogs: Array[Dictionary] = []
var _playing := false
var _viewport_size := Vector2.ZERO

func install(scene: Node3D) -> void:
	game = scene
	hud = PanelContainer.new()
	hud.name = "CompactHUDV20"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.03, 0.035, 0.82)
	style.border_color = Color(0.40, 0.61, 0.59, 0.55)
	style.border_width_left = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	hud.add_theme_stylebox_override("panel", style)
	game.hud_layer.add_child(hud)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	hud.add_child(box)
	for label: Label in [game.phase_label, game.objective_label]:
		label.reparent(box)
		label.custom_minimum_size = Vector2.ZERO
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 2
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 14)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars = Label.new()
	bars.name = "PlayerVitals"
	bars.add_theme_font_size_override("font_size", 12)
	bars.modulate = Color(0.7, 0.87, 0.79)
	box.add_child(bars)
	notice = game.status_label
	notice.reparent(box)
	notice.custom_minimum_size = Vector2.ZERO
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.max_lines_visible = 2
	notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	notice.add_theme_font_size_override("font_size", 12)
	# Old layered panels remain as data sources, but no longer cover the viewport.
	(game.health_progress.get_parent().get_parent() as Control).hide()
	for panel: Control in [game.act1_objective_back_v18, game.act1_status_back_v18]:
		if panel:
			panel.hide()
	_add_quality_setting()
	for panel: Control in [game.start_panel, game.intro_panel, game.pause_panel, game.win_panel, game.tablet_panel]:
		_wrap_dialog(panel)
	_build_actions()
	if game.mobile_layer:
		game.mobile_layer.z_index = 30
		for control in game.mobile_layer.get_children():
			if control is Button:
				(control as Button).tooltip_text = ""
			elif control is TouchScreenButton:
				(control as TouchScreenButton).passby_press = false

func _add_quality_setting() -> void:
	var content := game.pause_panel.get_child(0) as VBoxContainer
	var options := OptionButton.new()
	options.name = "GraphicsQualityV20"
	for title in ["Automatique", "Économie", "Équilibré", "Détaillé"]:
		options.add_item(title)
	options.custom_minimum_size.y = 44
	options.item_selected.connect(game._apply_quality_v20)
	var row: HBoxContainer = game._setting_row("Graphismes", options)
	content.add_child(row)
	content.move_child(row, 2)
	game.brightness_slider.min_value = 0.85
	game.brightness_slider.max_value = 1.65
	game.brightness_slider.step = 0.05

func _wrap_dialog(panel: Control) -> void:
	var content: VBoxContainer
	for child in panel.get_children():
		if child is VBoxContainer:
			content = child as VBoxContainer
			break
	if content == null:
		return
	panel.z_index = 200
	panel.clip_contents = true
	var scroll := ScrollContainer.new()
	scroll.name = "ResponsiveScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)
	content.reparent(scroll)
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.position = Vector2.ZERO
	content.custom_minimum_size = Vector2.ZERO
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	for candidate in content.find_children("*", "Control", true, false):
		var control := candidate as Control
		control.custom_minimum_size.x = 0
		if control is Label:
			(control as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			# Dialog text must contribute its full wrapped height to the scroll area.
			(control as Label).text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			if control.get_parent() is HBoxContainer:
				control.custom_minimum_size.x = 120
		elif control is Button:
			(control as Button).custom_minimum_size.y = 44
			(control as Button).add_theme_font_size_override("font_size", 14)
			(control as Button).tooltip_text = ""
	# Flow rows wrap tabs and choices without squeezing or clipping their labels.
	for candidate in content.get_children():
		if not candidate is HBoxContainer:
			continue
		var row := candidate as HBoxContainer
		if row.get_child_count() > 0 and row.get_child(0) is Button:
			var flow := HFlowContainer.new()
			flow.alignment = FlowContainer.ALIGNMENT_CENTER
			content.add_child(flow)
			content.move_child(flow, row.get_index())
			for button in row.get_children():
				button.reparent(flow)
				(button as Control).custom_minimum_size.x = 130
			row.queue_free()
	var close: Button
	if panel == game.tablet_panel:
		close = content.get_child(content.get_child_count() - 1) as Button
		close.reparent(panel)
		close.text = "FERMER SENTINEL"
	elif panel == game.pause_panel:
		for button in content.get_children():
			if button is Button and (button as Button).text == "REPRENDRE":
				button.queue_free()
		close = Button.new()
		close.text = "REPRENDRE"
		close.pressed.connect(game._toggle_pause)
		panel.add_child(close)
	if close:
		close.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		close.offset_left = 16
		close.offset_right = -16
		close.offset_top = -60
		close.offset_bottom = -12
		close.custom_minimum_size = Vector2(0, 44)
	dialogs.append({"panel": panel, "content": content, "scroll": scroll, "close": close})

func _build_actions() -> void:
	action_back = ColorRect.new()
	action_back.name = "ActionsBackdrop"
	action_back.color = Color(0.0, 0.012, 0.018, 0.92)
	action_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action_back.z_index = 220
	game.hud_layer.add_child(action_back)
	var menu: PanelContainer = game.context_menu
	menu.reparent(action_back)
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	menu.custom_minimum_size = Vector2.ZERO
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.065)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	menu.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	menu.add_child(box)
	game.context_title = Label.new()
	game.context_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.context_title.max_lines_visible = 2
	game.context_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	game.context_title.custom_minimum_size.y = 48
	game.context_title.add_theme_font_size_override("font_size", 17)
	box.add_child(game.context_title)
	game.context_center_label = Label.new()
	game.context_center_label.hide()
	box.add_child(game.context_center_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	game.context_actions = grid
	box.add_child(grid)
	var close := Button.new()
	close.text = "FERMER LES ACTIONS"
	close.custom_minimum_size.y = 44
	close.pressed.connect(game._close_context_menu_v12)
	box.add_child(close)
	action_back.hide()

func reflow() -> void:
	if game == null or not game.hud_layer:
		return
	var viewport := game.get_viewport().get_visible_rect().size
	_viewport_size = viewport
	var narrow := viewport.x < 600.0
	var low := viewport.y < 500.0
	hud.position = Vector2(12, 12)
	hud.custom_minimum_size = Vector2.ZERO
	hud.size = Vector2(minf(viewport.x - 24, 395.0 if not low else viewport.x * 0.48), 0)
	for record in dialogs:
		var scroll := record["scroll"] as ScrollContainer
		var margin := maxf(16.0, (viewport.x - 900.0) * 0.5)
		scroll.offset_left = margin
		scroll.offset_right = -margin
		scroll.offset_top = 16
		scroll.offset_bottom = -72 if record["close"] != null else -16
		var content := record["content"] as VBoxContainer
		content.custom_minimum_size = Vector2.ZERO
		content.size = Vector2(viewport.x - margin * 2.0, 0)
		for label in content.get_children():
			if label is Label:
				var current := (label as Label).get_theme_font_size("font_size")
				if current > 22:
					(label as Label).add_theme_font_size_override("font_size", 25 if narrow or low else 34)
	game.intro_title_label.custom_minimum_size = Vector2(0, 56)
	game.intro_body_label.custom_minimum_size = Vector2(0, 210 if low else 270)
	game.intro_body_label.scroll_active = true
	game.intro_body_label.add_theme_font_size_override("normal_font_size", 16)
	game.tablet_content.custom_minimum_size = Vector2(0, 180 if low else 300)
	game.tablet_content.scroll_active = true
	game.tablet_title.add_theme_font_size_override("font_size", 20 if narrow or low else 28)
	game.context_menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var menu_width := minf(viewport.x - 32.0, 530.0)
	var menu_height := 136.0 + ceili(float(game.context_actions.get_child_count()) / 2.0) * 56.0
	game.context_menu.custom_minimum_size = Vector2(menu_width, 0)
	game.context_menu.size = Vector2(menu_width, menu_height)
	game.context_menu.position = Vector2((viewport.x - menu_width) * 0.5, maxf(12.0, (viewport.y - menu_height) * 0.5))
	if game.mobile_layer:
		_layout_mobile(viewport)
	var quality: OptionButton = game.pause_panel.find_child("GraphicsQualityV20", true, false)
	if quality:
		quality.select(game.quality_mode_v20)

func _layout_mobile(viewport: Vector2) -> void:
	var portrait := viewport.x < 600.0
	var step := 48.0
	var bottom := viewport.y - 12.0
	var controls := {
		"move_forward": Rect2(60, bottom - 144, 44, 44), "move_back": Rect2(60, bottom - 48, 44, 44),
		"move_left": Rect2(12, bottom - 96, 44, 44), "move_right": Rect2(108, bottom - 96, 44, 44)
	}
	var actions := ["interact", "flashlight", "crouch", "jump", "sprint", "primary", "drone", "drone_down"]
	var columns := 3 if portrait else 4
	var rows := ceili(float(actions.size()) / float(columns))
	for index in range(actions.size()):
		controls[actions[index]] = Rect2(viewport.x - 12.0 - columns * step + (index % columns) * step, bottom - rows * step + floorf(float(index) / columns) * step, 44, 44)
	var names := {"interact": "E", "flashlight": "LAMPE", "crouch": "BAS", "jump": "SAUT", "sprint": "COURIR", "primary": "AGIR", "drone": "KITE", "drone_down": "↓ KITE"}
	for node in game.mobile_layer.get_children():
		if not node is TouchScreenButton:
			continue
		var button := node as TouchScreenButton
		var visual := button.get_meta("visual_v20", null) as Button
		if visual == null:
			continue
		var action := String(button.name).trim_prefix("Touch_")
		var rect: Rect2
		if controls.has(action):
			rect = controls[action]
			if names.has(action):
				visual.text = names[action]
		else:
			rect = Rect2(viewport.x - 60.0, 12 if not portrait else 178.0, 48, 44)
		visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
		visual.custom_minimum_size = rect.size
		visual.position = rect.position
		visual.size = rect.size
		visual.add_theme_font_size_override("font_size", 10 if visual.text.length() > 3 else 17)
		button.position = rect.get_center()
		(button.shape as RectangleShape2D).size = rect.size
	for node in game.mobile_layer.get_children():
		if not node is Button:
			continue
		var button := node as Button
		if button.text not in ["TAB", "◉"]:
			continue
		var offset := 116.0 if button.text == "TAB" else 172.0
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.position = Vector2(viewport.x - offset, 12 if not portrait else 178.0)
		button.custom_minimum_size = Vector2(48, 44)
		button.size = Vector2(48, 44)
	var look: Control = game.mobile_look_pad
	if look:
		look.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var look_height := 112.0 if viewport.y >= 430 else 86.0
		look.custom_minimum_size = Vector2(112, look_height)
		look.size = look.custom_minimum_size
		look.position = Vector2(viewport.x - 132, bottom - rows * step - look_height - 16)
		game._update_mobile_look_knob_v17()

func sync() -> void:
	if game == null:
		return
	var modal: bool = not game.game_started or game.intro_active or game.pause_panel.visible or game.win_panel.visible or game.tablet_open or game.context_menu_open or bool(game.get_meta("fnaf_surveillance_open", false))
	var playing := not modal
	if _playing and not playing:
		game._release_touch_actions_v20()
	_playing = playing
	hud.visible = playing
	game.phase_label.visible = playing
	game.objective_label.visible = playing
	notice.visible = playing and not notice.text.is_empty()
	for control: Control in [game.health_label, game.fear_label, game.athena_hud_label, game.task_hint_label, game.act1_objective_back_v18, game.act1_status_back_v18]:
		if control:
			control.visible = false
	game.drone_overlay.visible = false
	if game.mobile_layer:
		game.mobile_layer.visible = playing
	action_back.visible = game.context_menu_open
	game.context_menu.visible = game.context_menu_open
	bars.text = "SANTÉ %d   ·   ÉNERGIE %d   ·   FATIGUE %d" % [game.player_health, game.fnaf_surveillance_v21.power, game.get_meta("fatigue", 0)]
	if game.drone_active:
		bars.text = "VUE KITE   ·   BAT %d%%   ·   C : RETOUR" % game.drone_battery
