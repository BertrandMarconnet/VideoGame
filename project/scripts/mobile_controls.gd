class_name MobileControls
extends Control

signal pause_requested
signal tablet_requested

var player: PlayerController
var joystick_touch := -1
var look_touch := -1
var joystick_origin := Vector2.ZERO
var joystick_current := Vector2.ZERO
var look_last := Vector2.ZERO
var joystick_radius := 78.0
var enabled := true
var buttons: Dictionary = {}

func configure(player_node: PlayerController) -> void:
	player = player_node
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_build_buttons()
	queue_redraw()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _build_buttons() -> void:
	_create_button("ACTION", "E", Vector2(-190, -170), Vector2(82, 58), func(): player.interact_or_grab())
	_create_button("OUTIL", "⚒", Vector2(-100, -245), Vector2(82, 58), func(): player.throw_or_strike())
	_create_button("SAUT", "↑", Vector2(-100, -95), Vector2(82, 58), func(): player.mobile_jump())
	_create_button("LAMPE", "☀", Vector2(-280, -95), Vector2(82, 58), func(): player.toggle_flashlight())
	_create_button("TABLETTE", "▣", Vector2(-370, -170), Vector2(82, 58), func(): tablet_requested.emit())
	var sprint := _create_button("COURIR", "≫", Vector2(-280, -245), Vector2(82, 58), func(): pass)
	sprint.button_down.connect(func(): player.mobile_sprint = true)
	sprint.button_up.connect(func(): player.mobile_sprint = false)
	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.name = "PauseMobile"
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.position = Vector2(-72, 18)
	pause.size = Vector2(54, 46)
	pause.modulate = Color(0.82, 0.9, 1.0, 0.82)
	pause.pressed.connect(func(): pause_requested.emit())
	add_child(pause)
	buttons["pause"] = pause

func _create_button(id: String, text_value: String, offset: Vector2, size_value: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text_value
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = offset
	button.size = size_value
	button.modulate = Color(0.75, 0.86, 0.92, 0.72)
	button.pressed.connect(callback)
	add_child(button)
	buttons[id] = button
	return button

func _input(event: InputEvent) -> void:
	if not visible or not enabled or player == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.position.x < size.x * 0.46 and touch.position.y > size.y * 0.38 and joystick_touch == -1:
				joystick_touch = touch.index
				joystick_origin = touch.position
				joystick_current = touch.position
				queue_redraw()
			elif look_touch == -1 and not _over_button(touch.position):
				look_touch = touch.index
				look_last = touch.position
		else:
			if touch.index == joystick_touch:
				joystick_touch = -1
				player.set_mobile_move(Vector2.ZERO)
				queue_redraw()
			if touch.index == look_touch:
				look_touch = -1
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == joystick_touch:
			joystick_current = drag.position
			var delta := (joystick_current - joystick_origin) / joystick_radius
			player.set_mobile_move(delta.limit_length(1.0))
			queue_redraw()
		elif drag.index == look_touch:
			var delta_look := drag.position - look_last
			look_last = drag.position
			player.add_mobile_look(delta_look * 0.9)

func _over_button(point: Vector2) -> bool:
	for key in buttons:
		var button := buttons[key] as Control
		if button.visible and button.get_global_rect().has_point(point):
			return true
	return false

func _draw() -> void:
	if joystick_touch == -1:
		draw_circle(Vector2(105, size.y - 120), 62.0, Color(0.08, 0.18, 0.22, 0.34))
		draw_arc(Vector2(105, size.y - 120), 62.0, 0.0, TAU, 32, Color(0.35, 0.8, 0.95, 0.58), 3.0)
	else:
		draw_circle(joystick_origin, joystick_radius, Color(0.08, 0.18, 0.22, 0.38))
		draw_circle(joystick_origin + (joystick_current - joystick_origin).limit_length(joystick_radius), 30.0, Color(0.35, 0.8, 0.95, 0.68))
