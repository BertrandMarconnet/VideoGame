class_name RobotAgent
extends CharacterBody3D

enum Personality { SPECTER, CRAWLER, MIMIC, RAM }
enum State { DORMANT, OBSERVE, STALK, CHASE, STUNNED }

signal attacked(robot_name: String)
signal disabled(robot_name: String)

var personality := Personality.SPECTER
var state := State.DORMANT
var player: PlayerController
var factory: FactoryGenerator
var path := PackedVector3Array()
var path_index := 0
var think_timer := 0.0
var attack_cooldown := 0.0
var stun_timer := 0.0
var integrity := 100.0
var lethal := false
var active := false
var speed_walk := 2.2
var speed_chase := 5.0
var attack_range := 1.45
var visual_root: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var jaw: Node3D
var rng := RandomNumberGenerator.new()
var last_target := Vector3.ZERO

func configure(player_node: PlayerController, world_factory: FactoryGenerator, personality_value: int, spawn: Vector3) -> void:
	player = player_node
	factory = world_factory
	personality = personality_value
	global_position = spawn
	rng.seed = int(Time.get_ticks_usec()) ^ int(personality)
	_apply_personality_stats()
	_build_body()

func set_active(value: bool, can_kill: bool = false) -> void:
	active = value
	lethal = can_kill
	visible = value
	state = State.OBSERVE if value else State.DORMANT

func set_lethal(value: bool) -> void:
	lethal = value

func _apply_personality_stats() -> void:
	match personality:
		Personality.SPECTER:
			speed_walk = 2.0; speed_chase = 4.7; integrity = 75.0; attack_range = 1.35
		Personality.CRAWLER:
			speed_walk = 3.1; speed_chase = 6.2; integrity = 62.0; attack_range = 1.15
		Personality.MIMIC:
			speed_walk = 2.4; speed_chase = 4.6; integrity = 52.0; attack_range = 1.25
		Personality.RAM:
			speed_walk = 1.65; speed_chase = 3.7; integrity = 180.0; attack_range = 1.85

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player):
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if state == State.STUNNED:
		stun_timer -= delta
		velocity = velocity.move_toward(Vector3.ZERO, delta * 8.0)
		move_and_slide()
		if stun_timer <= 0.0:
			state = State.STALK
		return
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = 0.28 if state == State.CHASE else 0.72
		_think()
	_act(delta)
	_animate(delta)

func _think() -> void:
	var distance := global_position.distance_to(player.global_position)
	var watched := _is_watched()
	match personality:
		Personality.SPECTER:
			if watched and distance < 26.0:
				state = State.OBSERVE
				velocity = Vector3.ZERO
				return
			state = State.CHASE if lethal and distance < 10.0 else State.STALK
		Personality.CRAWLER:
			state = State.CHASE if distance < 15.0 else State.STALK
		Personality.MIMIC:
			state = State.CHASE if lethal and distance < 8.0 else State.STALK
		Personality.RAM:
			state = State.CHASE if distance < 18.0 else State.STALK
	var target := player.global_position if state == State.CHASE else factory.get_stalking_point(player.global_position, 9.0)
	if target.distance_to(last_target) > 2.5 or path.is_empty():
		path = factory.get_path(global_position, target)
		path_index = 0
		last_target = target

func _act(delta: float) -> void:
	if state == State.OBSERVE:
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
		move_and_slide()
		return
	if path.is_empty():
		return
	path_index = clampi(path_index, 0, path.size() - 1)
	var target := path[path_index]
	if global_position.distance_to(target) < 1.2 and path_index < path.size() - 1:
		path_index += 1
		target = path[path_index]
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.04:
		direction = direction.normalized()
		var speed := speed_chase if state == State.CHASE else speed_walk
		velocity.x = move_toward(velocity.x, direction.x * speed, delta * 9.0)
		velocity.z = move_toward(velocity.z, direction.z * speed, delta * 9.0)
		look_at(global_position + direction, Vector3.UP)
	move_and_slide()
	var distance := global_position.distance_to(player.global_position)
	if distance <= attack_range and attack_cooldown <= 0.0:
		attack_cooldown = 1.15 if personality != Personality.RAM else 1.8
		if lethal:
			var damage := 15.0
			match personality:
				Personality.CRAWLER: damage = 12.0
				Personality.MIMIC: damage = 9.0
				Personality.RAM: damage = 28.0
			player.receive_damage(damage, get_robot_name())
			attacked.emit(get_robot_name())
		else:
			global_position = factory.get_stalking_point(player.global_position, 18.0)

func receive_impact(damage: float, _hit_point: Vector3, impulse: Vector3 = Vector3.ZERO) -> void:
	integrity -= damage
	velocity += impulse * 0.12
	state = State.STUNNED
	stun_timer = clampf(damage * 0.035, 0.45, 3.2)
	if integrity <= 0.0:
		active = false
		visible = false
		disabled.emit(get_robot_name())

func get_robot_name() -> String:
	match personality:
		Personality.SPECTER: return "SPECTER-5"
		Personality.CRAWLER: return "CRAWLER-7"
		Personality.MIMIC: return "MIMIC-3"
		Personality.RAM: return "RAM-9"
	return "UNITÉ"

func _is_watched() -> bool:
	if not is_instance_valid(player.camera):
		return false
	var to_robot := (global_position + Vector3.UP - player.camera.global_position).normalized()
	var forward := -player.camera.global_transform.basis.z.normalized()
	if forward.dot(to_robot) < 0.74:
		return false
	var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, global_position + Vector3.UP)
	query.exclude = [player.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == self

func _build_body() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	visual_root = Node3D.new()
	visual_root.name = "Chassis"
	add_child(visual_root)
	var metal := WorldUtil.material(Color(0.13, 0.145, 0.16), 0.9, 0.24)
	var dark := WorldUtil.material(Color(0.025, 0.03, 0.035), 0.65, 0.48)
	var red := WorldUtil.material(Color(0.1, 0.01, 0.01), 0.3, 0.4, Color(1.0, 0.015, 0.01), 4.0)
	match personality:
		Personality.SPECTER:
			add_child(WorldUtil.capsule_collision(0.28, 1.05))
			get_child(get_child_count() - 1).position.y = 0.82
			_build_biped(metal, dark, red, 0.78, 1.0, true)
		Personality.CRAWLER:
			add_child(WorldUtil.box_collision(Vector3(0.9, 0.48, 1.15)))
			get_child(get_child_count() - 1).position.y = 0.38
			_build_quadruped(metal, dark, red)
		Personality.MIMIC:
			add_child(WorldUtil.capsule_collision(0.25, 0.72))
			get_child(get_child_count() - 1).position.y = 0.57
			_build_biped(dark, metal, red, 0.62, 0.75, false)
		Personality.RAM:
			add_child(WorldUtil.box_collision(Vector3(1.25, 1.5, 1.15)))
			get_child(get_child_count() - 1).position.y = 0.85
			_build_biped(metal, dark, red, 1.25, 1.05, false)

func _build_biped(metal: Material, dark: Material, red: Material, width_scale: float, height_scale: float, elongated: bool) -> void:
	var hip_y := 0.78 * height_scale
	var chest_y := 1.42 * height_scale
	visual_root.add_child(_part_box(Vector3(0.0, hip_y, 0.0), Vector3(0.42 * width_scale, 0.28, 0.30), dark))
	visual_root.add_child(_part_box(Vector3(0.0, chest_y, 0.0), Vector3(0.72 * width_scale, 0.74 * height_scale, 0.34), metal))
	for x_sign in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(x_sign * 0.22 * width_scale, 0.65, 0.0)
		leg.add_child(_part_box(Vector3.ZERO, Vector3(0.14, 0.78 * height_scale, 0.16), dark))
		visual_root.add_child(leg)
		legs.append(leg)
		var arm_x := x_sign * 0.48 * width_scale
		visual_root.add_child(_part_box(Vector3(arm_x, chest_y - 0.05, 0.0), Vector3(0.13, (1.05 if elongated else 0.72) * height_scale, 0.15), dark))
	head = Node3D.new()
	head.position = Vector3(0.0, 2.05 * height_scale, 0.0)
	visual_root.add_child(head)
	head.add_child(WorldUtil.sphere_mesh(0.24 * width_scale + 0.08, metal, 12, 7))
	jaw = _part_box(Vector3(0.0, -0.18, -0.13), Vector3(0.34 * width_scale + 0.12, 0.12, 0.24), dark)
	head.add_child(jaw)
	var eye := _part_box(Vector3(0.0, 0.04, -0.25), Vector3(0.24, 0.055, 0.035), red)
	head.add_child(eye)
	if personality == Personality.RAM:
		visual_root.add_child(_part_box(Vector3(0.0, 1.30, -0.48), Vector3(1.2, 0.28, 0.7), metal))

func _build_quadruped(metal: Material, dark: Material, red: Material) -> void:
	visual_root.add_child(_part_box(Vector3(0.0, 0.58, 0.0), Vector3(0.72, 0.52, 1.05), metal))
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var leg := Node3D.new()
			leg.position = Vector3(x_sign * 0.42, 0.34, z_sign * 0.36)
			leg.add_child(_part_box(Vector3.ZERO, Vector3(0.12, 0.58, 0.12), dark))
			visual_root.add_child(leg)
			legs.append(leg)
	head = Node3D.new()
	head.position = Vector3(0.0, 0.72, -0.72)
	visual_root.add_child(head)
	head.add_child(_part_box(Vector3.ZERO, Vector3(0.56, 0.34, 0.54), metal))
	jaw = _part_box(Vector3(0.0, -0.18, -0.18), Vector3(0.48, 0.12, 0.38), dark)
	head.add_child(jaw)
	head.add_child(_part_box(Vector3(0.0, 0.06, -0.29), Vector3(0.28, 0.05, 0.035), red))

func _part_box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var part := WorldUtil.box_mesh(size, mat)
	part.position = at
	return part

func _animate(_delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length()
	var time := Time.get_ticks_msec() * 0.009
	for i in range(legs.size()):
		legs[i].rotation.x = sin(time + i * PI) * 0.42 * clampf(moving / maxf(speed_walk, 0.1), 0.0, 1.0)
	if jaw:
		jaw.rotation.x = sin(time * 0.55) * 0.10
	if head and is_instance_valid(player):
		var local_target := head.to_local(player.camera.global_position)
		head.rotation.y = clampf(atan2(local_target.x, -local_target.z), -0.8, 0.8)
