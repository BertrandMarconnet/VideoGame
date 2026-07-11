class_name PlayerController
extends CharacterBody3D

signal health_changed(value: float)
signal flashlight_changed(enabled: bool)
signal status_message(text: String)
signal prop_thrown(mass_value: float)
signal died

var factory: FactoryGenerator
var camera: Camera3D
var flashlight: SpotLight3D
var interaction_ray: RayCast3D
var held_prop: GrabbableProp
var health := 100.0
var move_speed := 4.4
var sprint_speed := 7.1
var jump_velocity := 5.2
var gravity := 9.8
var mouse_sensitivity := 0.0022
var pitch := 0.0
var flashlight_on := true
var mobile_move := Vector2.ZERO
var mobile_look := Vector2.ZERO
var mobile_sprint := false
var controls_enabled := true
var distance_travelled := 0.0
var sprint_time := 0.0
var flashlight_toggles := 0
var abrupt_turn_score := 0.0
var freeze_after_sound := 0.0
var last_position := Vector3.ZERO
var current_prompt := ""
var impact_cooldown := 0.0

func configure(world_factory: FactoryGenerator) -> void:
	factory = world_factory

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 2 | 4
	add_child(WorldUtil.capsule_collision(0.34, 1.25))
	var collider := get_child(0) as CollisionShape3D
	collider.position.y = 0.94
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 1.68, 0.0)
	camera.current = true
	camera.fov = 72.0
	add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.position = Vector3(0.1, -0.08, -0.1)
	flashlight.light_color = Color(0.76, 0.88, 1.0)
	flashlight.light_energy = 5.8
	flashlight.spot_range = 30.0
	flashlight.spot_angle = 46.0
	flashlight.shadow_enabled = false
	camera.add_child(flashlight)
	interaction_ray = RayCast3D.new()
	interaction_ray.name = "InteractionRay"
	interaction_ray.target_position = Vector3(0.0, 0.0, -4.2)
	interaction_ray.collide_with_bodies = true
	interaction_ray.collide_with_areas = true
	camera.add_child(interaction_ray)
	last_position = global_position

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative * mouse_sensitivity)
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
	if event.is_action_pressed("interact") or event.is_action_pressed("secondary"):
		interact_or_grab()
	if event.is_action_pressed("throw"):
		throw_or_strike()
	if event.is_action_pressed("barricade"):
		try_barricade()

func _physics_process(delta: float) -> void:
	impact_cooldown = maxf(0.0, impact_cooldown - delta)
	abrupt_turn_score = lerpf(abrupt_turn_score, 0.0, delta * 0.55)
	if mobile_look.length_squared() > 0.0:
		_apply_look(mobile_look * 0.012)
		mobile_look = Vector2.ZERO
	if not is_on_floor():
		velocity.y -= gravity * delta
	if controls_enabled and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var input_vec := mobile_move if mobile_move.length() > keyboard.length() else keyboard
	var direction := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	var sprinting := controls_enabled and (Input.is_action_pressed("sprint") or mobile_sprint)
	var target_speed := sprint_speed if sprinting else move_speed
	if not controls_enabled:
		direction = Vector3.ZERO
	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, 20.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, 20.0 * delta)
		if sprinting:
			sprint_time += delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
	move_and_slide()
	distance_travelled += global_position.distance_to(last_position)
	last_position = global_position
	_update_prompt()

func _apply_look(relative: Vector2) -> void:
	var old_yaw := rotation.y
	rotate_y(-relative.x)
	pitch = clampf(pitch - relative.y, -1.35, 1.35)
	camera.rotation.x = pitch
	abrupt_turn_score = maxf(abrupt_turn_score, absf(rotation.y - old_yaw) * 9.0)

func set_mobile_move(value: Vector2) -> void:
	mobile_move = value

func add_mobile_look(value: Vector2) -> void:
	mobile_look += value

func mobile_jump() -> void:
	if is_on_floor() and controls_enabled:
		velocity.y = jump_velocity

func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	flashlight.visible = flashlight_on
	flashlight_toggles += 1
	flashlight_changed.emit(flashlight_on)

func interact_or_grab() -> void:
	if not controls_enabled:
		return
	if held_prop:
		held_prop.release()
		held_prop = null
		status_message.emit("Objet déposé.")
		return
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return
	var collider := interaction_ray.get_collider()
	if collider and collider.has_method("interact"):
		collider.interact(self)
		return
	if collider is GrabbableProp:
		held_prop = collider
		held_prop.grab(self)
		status_message.emit("%s saisi — clic pour lancer." % held_prop.prop_kind)

func throw_or_strike() -> void:
	if not controls_enabled or impact_cooldown > 0.0:
		return
	impact_cooldown = 0.32
	if held_prop:
		var prop := held_prop
		held_prop = null
		prop.throw_from(-camera.global_transform.basis.z)
		prop_thrown.emit(prop.mass)
		return
	interaction_ray.force_raycast_update()
	if interaction_ray.is_colliding():
		var collider := interaction_ray.get_collider()
		var hit_point := interaction_ray.get_collision_point()
		if collider and collider.has_method("receive_impact"):
			collider.receive_impact(16.0, hit_point, -camera.global_transform.basis.z * 5.0)
		elif collider and collider.get_parent() and collider.get_parent().has_method("receive_impact"):
			collider.get_parent().receive_impact(16.0, hit_point, -camera.global_transform.basis.z * 5.0)

func try_barricade() -> void:
	if factory and held_prop and factory.repair_nearest_breach(global_position, held_prop):
		held_prop = null
		status_message.emit("Brèche renforcée.")
	else:
		status_message.emit("Approchez-vous d'une brèche avec une caisse, une tôle ou un débris.")

func receive_damage(amount: float, source: String = "robot") -> void:
	health = maxf(0.0, health - amount)
	health_changed.emit(health)
	status_message.emit("Impact de %s — intégrité %.0f%%" % [source, health])
	if health <= 0.0:
		died.emit()

func _update_prompt() -> void:
	current_prompt = ""
	if not controls_enabled:
		return
	interaction_ray.force_raycast_update()
	if interaction_ray.is_colliding():
		var collider := interaction_ray.get_collider()
		if collider and collider.has_method("get_prompt"):
			current_prompt = collider.get_prompt()
		elif collider is GrabbableProp:
			current_prompt = "E — saisir %s" % collider.prop_kind

func get_behavior_snapshot() -> Dictionary:
	return {
		"distance": distance_travelled,
		"sprint_time": sprint_time,
		"flashlight_toggles": flashlight_toggles,
		"abrupt_turn_score": abrupt_turn_score,
		"flashlight_on": flashlight_on,
		"speed": Vector2(velocity.x, velocity.z).length(),
		"health": health,
		"carrying": held_prop != null
	}
