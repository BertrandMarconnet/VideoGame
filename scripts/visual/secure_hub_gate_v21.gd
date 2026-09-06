extends AnimatableBody3D
## S-01 operations gate. It starts locked and only opens after the technician
## explicitly validates the local badge reader. The body itself slides, so the
## collision always matches the visible door in Godot/Jolt and Web builds.

var game: Node3D
var player: CharacterBody3D
var closed_position := Vector3.ZERO
var open_position := Vector3.ZERO
var authorized := false
var door_mesh: MeshInstance3D
var status_light: MeshInstance3D
var status_material: StandardMaterial3D
var prompt_label: Label3D
var _hint_cooldown := 0.0
var _route_guard_done := false


func configure(
	game_scene: Node3D,
	at: Vector3,
	size_value: Vector3,
	slide_vector: Vector3,
	material_value: Material,
	gate_label: String
) -> void:
	game = game_scene
	player = game.get("player") as CharacterBody3D
	position = at
	closed_position = at
	open_position = at + slide_vector
	collision_layer = 1
	collision_mask = 1
	sync_to_physics = true

	var shape := BoxShape3D.new()
	shape.size = size_value
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var mesh_shape := BoxMesh.new()
	mesh_shape.size = size_value
	door_mesh = MeshInstance3D.new()
	door_mesh.name = "SecureHubGateMeshV21"
	door_mesh.mesh = mesh_shape
	door_mesh.material_override = material_value
	add_child(door_mesh)

	var inset_shape := BoxMesh.new()
	inset_shape.size = Vector3(size_value.x + 0.035, size_value.y * 0.72, size_value.z * 0.64)
	var inset := MeshInstance3D.new()
	inset.name = "SecureHubGateInsetV21"
	inset.mesh = inset_shape
	var inset_material := StandardMaterial3D.new()
	inset_material.albedo_color = Color(0.055, 0.065, 0.07)
	inset_material.metallic = 0.54
	inset_material.roughness = 0.58
	inset.material_override = inset_material
	add_child(inset)

	var lamp_shape := BoxMesh.new()
	lamp_shape.size = Vector3(size_value.x + 0.06, 0.12, 0.28)
	status_light = MeshInstance3D.new()
	status_light.name = "SecureHubGateStatusV21"
	status_light.mesh = lamp_shape
	status_light.position = Vector3(-size_value.x * 0.55, size_value.y * 0.31, 0.0)
	status_material = StandardMaterial3D.new()
	status_material.albedo_color = Color(0.32, 0.03, 0.02)
	status_material.emission_enabled = true
	status_material.emission = Color(0.85, 0.035, 0.015)
	status_material.emission_energy_multiplier = 1.25
	status_light.material_override = status_material
	add_child(status_light)

	prompt_label = Label3D.new()
	prompt_label.name = "SecureHubGateLabelV21"
	prompt_label.text = "%s\nBADGE REQUIRED — E" % gate_label
	prompt_label.font_size = 34
	prompt_label.pixel_size = 0.0022
	prompt_label.position = Vector3(-size_value.x * 0.62, size_value.y * 0.12, 0.0)
	prompt_label.rotation_degrees.y = 90.0
	prompt_label.modulate = Color(1.0, 0.42, 0.22)
	prompt_label.outline_size = 0
	add_child(prompt_label)

	add_to_group("secure_hub_gate_v21")


func _physics_process(delta: float) -> void:
	if not _route_guard_done:
		_apply_route_guard()
	if not is_instance_valid(player):
		if game:
			player = game.get("player") as CharacterBody3D
		return
	_hint_cooldown = maxf(0.0, _hint_cooldown - delta)
	var distance := player.global_position.distance_to(global_position)

	if not authorized and distance < 2.7:
		if Input.is_action_just_pressed("interact"):
			authorized = true
			if game:
				game.set_meta("s01_hub_authorized_v21", true)
				if game.has_method("_show_status"):
					game.call("_show_status", "S-01 : badge technicien validé — porte du hub déverrouillée.")
			_update_status(true)
		elif _hint_cooldown <= 0.0 and game and game.has_method("_show_status"):
			_hint_cooldown = 2.4
			game.call("_show_status", "S-01 verrouillé — approchez le lecteur et appuyez sur E.")

	var should_open := authorized and distance < 3.4
	var target := open_position if should_open else closed_position
	position = position.move_toward(target, delta * 2.65)


func _apply_route_guard() -> void:
	if not game:
		return
	_route_guard_done = true
	var hub_floor := game.find_child("HubFloorV21", true, false)
	if hub_floor is StaticBody3D:
		(hub_floor as StaticBody3D).position.y = -0.10

	var protected_routes: Array[Vector3] = [
		Vector3(6.0, 0.0, -22.5),
		Vector3(-6.0, 0.0, -58.0),
		Vector3(5.5, 0.0, -92.0),
		Vector3(-5.5, 0.0, -126.0),
	]
	var moved := 0
	for candidate in game.find_children("*", "RigidBody3D", true, false):
		var body := candidate as RigidBody3D
		var p := body.global_position
		var blocks_route := absf(p.z + 55.0) < 1.3 and absf(p.x) < 7.2
		if not blocks_route:
			for route in protected_routes:
				if absf(p.z - route.z) < 3.8 and absf(p.x - route.x) < 3.8:
					blocks_route = true
					break
		if not blocks_route:
			continue
		var side := -1.0 if p.x < 0.0 else 1.0
		if absf(p.x) < 0.5:
			side = -1.0 if moved % 2 == 0 else 1.0
		body.global_position = Vector3(
			side * (13.0 + float(moved % 4) * 0.65),
			maxf(0.75, p.y),
			p.z + float((moved % 3) - 1) * 1.15
		)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		moved += 1
	game.set_meta("factory_route_guard_v21_moved", moved)


func _update_status(is_authorized: bool) -> void:
	if status_material:
		status_material.albedo_color = Color(0.03, 0.28, 0.08) if is_authorized else Color(0.32, 0.03, 0.02)
		status_material.emission = Color(0.08, 0.92, 0.22) if is_authorized else Color(0.85, 0.035, 0.015)
	if prompt_label:
		prompt_label.text = "S-01 OPERATIONS\nAUTHORIZED" if is_authorized else "S-01 OPERATIONS\nBADGE REQUIRED — E"
		prompt_label.modulate = Color(0.3, 1.0, 0.48) if is_authorized else Color(1.0, 0.42, 0.22)
