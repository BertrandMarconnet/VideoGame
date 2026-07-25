extends Node3D

const CLIPS := ["Idle-loop", "Walk-loop", "Run-loop", "Attack", "Shutdown"]

var robot: CharacterBody3D
var status_label: Label

func _ready() -> void:
	_build_environment()
	_build_robot()
	_build_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	_play_clip("Idle-loop")

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.012, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.22, 0.28)
	env.ambient_light_energy = 0.75
	environment.environment = env
	add_child(environment)

	var floor := StaticBody3D.new()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.055, 0.06, 0.065)
	floor_material.metallic = 0.65
	floor_material.roughness = 0.78
	floor_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_mesh.material_override = floor_material
	floor.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(12.0, 0.1, 12.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.05
	floor.add_child(floor_collision)
	add_child(floor)

	var key_light := SpotLight3D.new()
	key_light.position = Vector3(2.6, 4.0, 3.2)
	key_light.rotation_degrees = Vector3(-48.0, 28.0, 0.0)
	key_light.light_color = Color(0.68, 0.82, 1.0)
	key_light.light_energy = 8.0
	key_light.spot_range = 12.0
	key_light.spot_angle = 48.0
	add_child(key_light)

	var alarm_light := OmniLight3D.new()
	alarm_light.position = Vector3(-2.5, 1.4, -1.5)
	alarm_light.light_color = Color(1.0, 0.05, 0.03)
	alarm_light.light_energy = 2.2
	alarm_light.omni_range = 7.0
	add_child(alarm_light)

	var camera := Camera3D.new()
	camera.position = Vector3(3.5, 2.2, 4.8)
	camera.fov = 58.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.65, 0.0), Vector3.UP)

func _build_robot() -> void:
	robot = CharacterBody3D.new()
	robot.name = "CRAWLER-7_Preview"
	robot.set_meta("robot", true)
	robot.set_meta("personality", "crawler")
	robot.set_meta("health", 100.0)
	robot.set_meta("material_id", "metal_armored")
	var collision := CollisionShape3D.new()
	collision.name = "GameplayCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.45, 0.72, 1.75)
	collision.shape = shape
	collision.position.y = 0.36
	robot.add_child(collision)
	var anchor := Node3D.new()
	anchor.name = "GeneratedVisualAnchor"
	robot.add_child(anchor)
	var fallback := Node3D.new()
	fallback.name = "ProceduralVisual"
	var fallback_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.45, 1.4)
	fallback_mesh.mesh = box
	fallback_mesh.position.y = 0.25
	fallback.add_child(fallback_mesh)
	robot.add_child(fallback)
	add_child(robot)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.size = Vector2(610.0, 118.0)
	layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "CRAWLER-07 // GENERATED ASSET PREVIEW"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	status_label = Label.new()
	status_label.text = "Chargement du GLB, du rig, des textures et des sons…"
	content.add_child(status_label)
	var buttons := HBoxContainer.new()
	content.add_child(buttons)
	for clip in CLIPS:
		var button := Button.new()
		button.text = clip.replace("-loop", "")
		button.pressed.connect(_play_clip.bind(clip))
		buttons.add_child(button)
	var back := Button.new()
	back.text = "Retour au jeu"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	buttons.add_child(back)

func _play_clip(clip_name: String) -> void:
	if robot == null:
		return
	var visual := robot.get_node_or_null("GeneratedVisual")
	if visual == null:
		visual = robot.find_child("GeneratedVisual", true, false)
	if visual == null:
		status_label.text = "GLB indisponible : fallback procédural affiché."
		return
	var animation_player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		for candidate in visual.find_children("*", "AnimationPlayer", true, false):
			animation_player = candidate as AnimationPlayer
			break
	if animation_player == null:
		status_label.text = "Modèle chargé, mais aucun AnimationPlayer trouvé."
		return
	var resolved := clip_name
	if not animation_player.has_animation(resolved):
		for animation_name in animation_player.get_animation_list():
			if String(animation_name).to_lower().contains(clip_name.to_lower()):
				resolved = String(animation_name)
				break
	if not animation_player.has_animation(resolved):
		status_label.text = "Animation absente : %s" % clip_name
		return
	animation_player.speed_scale = 1.15 if clip_name == "Run-loop" else 1.0
	animation_player.play(resolved, 0.15)
	status_label.text = "Asset crawler_07 actif — animation : %s" % resolved
