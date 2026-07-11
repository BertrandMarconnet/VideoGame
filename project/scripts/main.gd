extends Node3D

var factory: FactoryGenerator
var player: PlayerController
var director: GameDirector
var environment_agent: EnvironmentAgent
var robots: Array[RobotAgent] = []
var mobile_controls: MobileControls
var hud: CanvasLayer
var phase_label: Label
var objective_label: Label
var status_label: Label
var health_label: Label
var fear_label: Label
var prompt_label: Label
var start_panel: Control
var pause_panel: Control
var tablet_panel: Control
var tablet_body: RichTextLabel
var world_environment: WorldEnvironment
var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var game_started := false
var is_mobile := false
var seed_value := 0
var settings := {
	"brightness": 1.35,
	"master": 0.85,
	"music": 0.62,
	"sfx": 0.82,
	"quality": 1
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_inputs()
	seed_value = int(Time.get_unix_time_from_system())
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or DisplayServer.is_touchscreen_available()
	_load_settings()
	_build_environment()
	_build_gameplay()
	_build_audio()
	_build_ui()
	_apply_settings()
	player.controls_enabled = false
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _configure_inputs() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_forward", KEY_Z)
	_bind_key("move_backward", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_left", KEY_Q)
	_bind_key("move_right", KEY_D)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("jump", KEY_SPACE)
	_bind_key("flashlight", KEY_F)
	_bind_key("interact", KEY_E)
	_bind_key("barricade", KEY_B)
	_bind_key("tablet", KEY_TAB)
	_bind_key("pause", KEY_ESCAPE)
	_bind_mouse("throw", MOUSE_BUTTON_LEFT)
	_bind_mouse("secondary", MOUSE_BUTTON_RIGHT)

func _bind_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _bind_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018, 0.026, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.37, 0.47)
	env.ambient_light_energy = 0.70
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(settings["brightness"])
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.12, 0.16)
	env.fog_light_energy = 0.7
	env.fog_density = 0.0035 if is_mobile else 0.0055
	world_environment.environment = env
	add_child(world_environment)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-58.0, -24.0, 0.0)
	fill.light_color = Color(0.45, 0.62, 0.78)
	fill.light_energy = 0.78
	fill.shadow_enabled = false
	add_child(fill)

func _build_gameplay() -> void:
	factory = FactoryGenerator.new()
	factory.name = "Factory"
	add_child(factory)
	factory.generate(seed_value)
	player = PlayerController.new()
	player.name = "Player"
	player.configure(factory)
	add_child(player)
	player.global_position = factory.get_spawn_position("player")
	player.health_changed.connect(_on_health_changed)
	player.status_message.connect(_show_status)
	_create_robot(RobotAgent.Personality.SPECTER, "specter")
	_create_robot(RobotAgent.Personality.CRAWLER, "crawler")
	_create_robot(RobotAgent.Personality.MIMIC, "mimic")
	_create_robot(RobotAgent.Personality.RAM, "ram")
	environment_agent = EnvironmentAgent.new()
	add_child(environment_agent)
	environment_agent.configure(factory, player, seed_value)
	environment_agent.environment_event.connect(_show_status)
	director = GameDirector.new()
	add_child(director)
	director.configure(player, factory, robots)
	director.phase_changed.connect(_on_phase_changed)
	director.objective_changed.connect(_on_objective_changed)
	director.status_message.connect(_show_status)
	director.fear_profile_changed.connect(_on_fear_profile_changed)
	director.mission_complete.connect(_on_mission_complete)

func _create_robot(personality: int, spawn_id: String) -> void:
	var robot := RobotAgent.new()
	robot.name = spawn_id.to_upper()
	add_child(robot)
	robot.configure(player, factory, personality, factory.get_spawn_position(spawn_id))
	robots.append(robot)

func _build_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	music_player.stream = _make_procedural_loop("music", 5.0)
	add_child(music_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = &"SFX"
	ambience_player.stream = _make_procedural_loop("ambience", 4.0)
	add_child(ambience_player)

func _make_procedural_loop(kind: String, seconds: float) -> AudioStreamWAV:
	var rate := 11025
	var frame_count := int(rate * seconds)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	for i in range(frame_count):
		var t := float(i) / float(rate)
		var value := 0.0
		if kind == "music":
			var pulse := maxf(0.0, 1.0 - fmod(t * 2.8, 1.0) * 9.0)
			var step := float(int(t * 2.8) % 7)
			value = sin(TAU * (46.0 + step * 1.7) * t) * 0.15
			value += sin(TAU * 92.0 * t) * pulse * 0.16
		else:
			value = sin(TAU * 37.0 * t) * 0.11
			value += sin(TAU * 59.0 * t) * 0.06
			value += sin(t * 127.1 + sin(t * 17.0) * 6.0) * 0.035
		var sample := int(clampf(value, -0.92, 0.92) * 32767.0)
		if sample < 0:
			sample += 65536
		pcm[i * 2] = sample & 255
		pcm[i * 2 + 1] = (sample >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frame_count
	return stream

func _build_ui() -> void:
	hud = CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	phase_label = _hud_label(Vector2(18, 16), "PHASE 0 — CALIBRATION", 17, Color(0.4, 0.88, 1.0))
	objective_label = _hud_label(Vector2(18, 44), "Consultez l'écran de ronde dans S-01.", 14, Color(0.93, 0.96, 0.98))
	status_label = _hud_label(Vector2(18, 70), "", 13, Color(1.0, 0.57, 0.26))
	health_label = _hud_label(Vector2(18, 98), "INTÉGRITÉ 100%", 13, Color(0.5, 1.0, 0.72))
	fear_label = _hud_label(Vector2(18, 122), "PROFIL DE PEUR : CALIBRATION", 11, Color(0.72, 0.77, 0.82))
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-210, -92)
	prompt_label.size = Vector2(420, 42)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 14)
	hud.add_child(prompt_label)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-6, -14)
	crosshair.add_theme_font_size_override("font_size", 22)
	hud.add_child(crosshair)
	_build_start_panel()
	_build_pause_panel()
	_build_tablet_panel()
	if is_mobile:
		mobile_controls = MobileControls.new()
		hud.add_child(mobile_controls)
		mobile_controls.configure(player)
		mobile_controls.pause_requested.connect(_toggle_pause)
		mobile_controls.tablet_requested.connect(_toggle_tablet)
		mobile_controls.visible = false

func _hud_label(at: Vector2, text_value: String, font_size: int, color_value: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color_value
	hud.add_child(label)
	return label

func _overlay(color_value: Color) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = color_value
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(overlay)
	return overlay

func _center_box(parent: Control, size_value: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = -size_value * 0.5
	box.size = size_value
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(box)
	return box

func _build_start_panel() -> void:
	start_panel = _overlay(Color(0.005, 0.009, 0.014, 0.96))
	var box := _center_box(start_panel, Vector2(660, 460))
	var title := Label.new()
	title.text = "BLACKOUT PROTOCOL\nSTEEL ECHO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31 if is_mobile else 42)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Survival-horror industriel — Godot 4.7 / Jolt\nExplorez, réparez, détruisez et utilisez le décor pour survivre."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16)
	box.add_child(subtitle)
	var play := Button.new()
	play.text = "COMMENCER LA RONDE"
	play.custom_minimum_size = Vector2(320, 56)
	play.pressed.connect(_start_game)
	box.add_child(play)
	var seed_label := Label.new()
	seed_label.text = "GRAINE : %s" % seed_value
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(seed_label)

func _build_pause_panel() -> void:
	pause_panel = _overlay(Color(0.005, 0.009, 0.014, 0.94))
	pause_panel.visible = false
	var box := _center_box(pause_panel, Vector2(540, 610))
	var title := Label.new()
	title.text = "PAUSE / PARAMÈTRES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var resume := Button.new()
	resume.text = "REPRENDRE"
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	box.add_child(_slider_row("Luminosité", 0.75, 2.1, float(settings["brightness"]), _set_brightness))
	box.add_child(_slider_row("Volume général", 0.0, 1.0, float(settings["master"]), _set_master_volume))
	box.add_child(_slider_row("Musique", 0.0, 1.0, float(settings["music"]), _set_music_volume))
	box.add_child(_slider_row("Effets", 0.0, 1.0, float(settings["sfx"]), _set_sfx_volume))
	var quality := OptionButton.new()
	quality.add_item("Performance mobile / Intel UHD", 0)
	quality.add_item("Équilibré", 1)
	quality.add_item("Qualité PC", 2)
	quality.select(int(settings["quality"]))
	quality.item_selected.connect(_set_quality)
	box.add_child(quality)
	var fullscreen := Button.new()
	fullscreen.text = "PLEIN ÉCRAN"
	fullscreen.pressed.connect(_toggle_fullscreen)
	box.add_child(fullscreen)
	var menu := Button.new()
	menu.text = "REVENIR AU MENU PRINCIPAL"
	menu.pressed.connect(_return_to_menu)
	box.add_child(menu)
	var quit := Button.new()
	quit.text = "QUITTER"
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)

func _build_tablet_panel() -> void:
	tablet_panel = _overlay(Color(0.01, 0.025, 0.035, 0.96))
	tablet_panel.visible = false
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 26
	box.offset_top = 24
	box.offset_right = -26
	box.offset_bottom = -24
	tablet_panel.add_child(box)
	var title := Label.new()
	title.text = "TABLETTE DE MAINTENANCE // STEEL ECHO"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	tablet_body = RichTextLabel.new()
	tablet_body.bbcode_enabled = true
	tablet_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tablet_body.add_theme_font_size_override("normal_font_size", 16)
	box.add_child(tablet_body)
	var close := Button.new()
	close.text = "FERMER LA TABLETTE"
	close.pressed.connect(_toggle_tablet)
	box.add_child(close)

func _slider_row(title: String, min_value: float, max_value: float, current: float, callback: Callable) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 180
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.01
	slider.value = current
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return row

func _process(_delta: float) -> void:
	if game_started and not get_tree().paused:
		prompt_label.text = player.current_prompt

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and game_started:
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tablet") and game_started and not pause_panel.visible:
		_toggle_tablet()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and game_started and not get_tree().paused and not is_mobile:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _start_game() -> void:
	game_started = true
	start_panel.visible = false
	pause_panel.visible = false
	tablet_panel.visible = false
	get_tree().paused = false
	player.controls_enabled = true
	if mobile_controls:
		mobile_controls.visible = true
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	music_player.play()
	ambience_player.play()

func _toggle_pause() -> void:
	if not game_started:
		return
	var opening := not pause_panel.visible
	pause_panel.visible = opening
	tablet_panel.visible = false
	get_tree().paused = opening
	player.controls_enabled = not opening
	if mobile_controls:
		mobile_controls.visible = not opening
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if opening or is_mobile else Input.MOUSE_MODE_CAPTURED)
	if not opening:
		_save_settings()

func _toggle_tablet() -> void:
	if not game_started:
		return
	var opening := not tablet_panel.visible
	tablet_panel.visible = opening
	player.controls_enabled = not opening
	if mobile_controls:
		mobile_controls.visible = not opening
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if opening or is_mobile else Input.MOUSE_MODE_CAPTURED)
	if opening:
		_update_tablet()

func _update_tablet() -> void:
	var state := director.get_mission_state()
	tablet_body.text = "[b]ORDRES DE MISSION[/b]\n\n"
	tablet_body.text += _task("Consulter le briefing S-01", bool(state["briefing"]))
	tablet_body.text += _task("Réparer le relais A", bool(state["relay_a"]))
	tablet_body.text += _task("Récupérer l'enregistreur noir", bool(state["black_box"]))
	tablet_body.text += _task("Réparer le relais B", bool(state["relay_b"]))
	tablet_body.text += "\n[b]ANALYSE COMPORTEMENTALE[/b]\nProfil estimé : [color=#ff8a4c]%s[/color]\n" % state["fear"]
	tablet_body.text += "\n[b]UNITÉS[/b]\nSPECTER-5 : observation visuelle\nCRAWLER-7 : chasse basse\nMIMIC-3 : diversion acoustique\nRAM-9 : destruction lourde\n"
	tablet_body.text += "\n[b]PHYSIQUE[/b]\nE : saisir · clic : lancer/frapper · B : réparer une brèche avec l'objet tenu."

func _task(text_value: String, done: bool) -> String:
	return "%s %s\n" % ["[color=#68ff9c]✓[/color]" if done else "[color=#ffb15c]○[/color]", text_value]

func _set_brightness(value: float) -> void:
	settings["brightness"] = value
	if world_environment.environment:
		world_environment.environment.tonemap_exposure = value

func _set_quality(index: int) -> void:
	settings["quality"] = index
	_apply_quality()

func _apply_quality() -> void:
	var index := int(settings["quality"])
	var scale := 0.62 if index == 0 else (0.82 if index == 1 else 1.0)
	if is_mobile:
		scale = minf(scale, 0.68)
	get_viewport().scaling_3d_scale = scale
	if world_environment.environment:
		world_environment.environment.fog_density = 0.0035 if index == 0 else (0.005 if index == 1 else 0.0065)

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _return_to_menu() -> void:
	game_started = false
	get_tree().paused = true
	pause_panel.visible = false
	tablet_panel.visible = false
	start_panel.visible = true
	player.controls_enabled = false
	if mobile_controls:
		mobile_controls.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _set_master_volume(value: float) -> void:
	settings["master"] = value
	_apply_audio()

func _set_music_volume(value: float) -> void:
	settings["music"] = value
	_apply_audio()

func _set_sfx_volume(value: float) -> void:
	settings["sfx"] = value
	_apply_audio()

func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(0.001, float(settings["master"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.001, float(settings["music"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.001, float(settings["sfx"]))))

func _apply_settings() -> void:
	_set_brightness(float(settings["brightness"]))
	_apply_quality()
	_apply_audio()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		for key in settings:
			settings[key] = config.get_value("settings", key, settings[key])

func _save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("settings", key, settings[key])
	config.save("user://settings.cfg")

func _on_phase_changed(text_value: String) -> void:
	phase_label.text = text_value

func _on_objective_changed(text_value: String) -> void:
	objective_label.text = text_value

func _show_status(text_value: String) -> void:
	status_label.text = text_value
	status_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(status_label, "modulate:a", 0.25, 1.4)

func _on_health_changed(value: float) -> void:
	health_label.text = "INTÉGRITÉ %.0f%%" % value
	health_label.modulate = Color(0.5, 1.0, 0.72) if value > 45.0 else Color(1.0, 0.28, 0.2)

func _on_fear_profile_changed(profile: String) -> void:
	fear_label.text = "PROFIL DE PEUR : %s" % profile.to_upper()

func _on_mission_complete(success: bool, summary: String) -> void:
	get_tree().paused = true
	player.controls_enabled = false
	if mobile_controls:
		mobile_controls.visible = false
	var ending := _overlay(Color(0.005, 0.009, 0.014, 0.97))
	var box := _center_box(ending, Vector2(600, 320))
	var title := Label.new()
	title.text = "PROTOCOLE TRANSMIS" if success else "RONDE INTERROMPUE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var text := Label.new()
	text.text = summary
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var restart := Button.new()
	restart.text = "RECOMMENCER"
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	box.add_child(restart)
