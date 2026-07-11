class_name RobotAgent
extends CharacterBody3D

enum Personality { SPECTER, CRAWLER, MIMIC, RAM }
enum State { DORMANT, OBSERVE, STALK, CHASE, STUNNED }

signal attacked(robot_name: String)
signal disabled(robot_name: String)

var personality: int = Personality.SPECTER
var state: int = State.DORMANT
var player: PlayerController
var factory: FactoryGenerator
var navigation_path: PackedVector3Array = PackedVector3Array()
var path_index: int = 0
var think_timer: float = 0.0
var attack_cooldown: float = 0.0
var stun_timer: float = 0.0
var integrity: float = 100.0
var lethal: bool = false
var unit_active: bool = false
var speed_walk: float = 2.2
var speed_chase: float = 5.0
var attack_range: float = 1.45
var visual_root: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var jaw: Node3D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_target: Vector3 = Vector3.ZERO


func configure(
	player_node: PlayerController,
	world_factory: FactoryGenerator,
	personality_value: int,
	spawn_position: Vector3
) -> void:
	player = player_node
	factory = world_factory
	personality = personality_value
	global_position = spawn_position
	rng.seed = int(Time.get_ticks_usec()) ^ personality
	_apply_personality_stats()
	_build_body()


func set_active(value: bool, can_kill: bool = false) -> void:
	unit_active = value
	lethal = can_kill
	visible = value
	state = State.OBSERVE if value else State.DORMANT
	set_physics_process(value)


func set_lethal(value: bool) -> void:
	lethal = value


func _ready() -> void:
	set_physics_process(unit_active)


func _apply_personality_stats() -> void:
	match personality:
		Personality.SPECTER:
			speed_walk = 2.0
			speed_chase = 4.7
			integrity = 75.0
			attack_range = 1.35
		Personality.CRAWLER:
			speed_walk = 3.1
			speed_chase = 6.2
			integrity = 62.0
			attack_range = 1.15
		Personality.MIMIC:
			speed_walk = 2.4
			speed_chase = 4.6
			integrity = 52.0
			attack_range = 1.25
		Personality.RAM:
			speed_walk = 1.65
			speed_chase = 3.7
			integrity = 180.0
			attack_range = 1.85


func _physics_process(delta: float) -> void:
	if not unit_active or not is_instance_valid(player):
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
	_animate()


func _think() -> void:
	var distance: float = global_position.distance_to(player.global_position)
	var watched: bool = _is_watched()
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
	var target: Vector3
	if state == State.CHASE:
		target = player.global_position
	else:
		target = factory.get_stalking_point(player.global_position, 9.0)
	if target.distance_to(last_target) > 2.5 or navigation_path.is_empty():
		navigation_path = factory.get_navigation_path(global_position, target)
		path_index = 0
		last_target = target


func _act(delta: float) -> void:
	if state == State.OBSERVE:
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
		move_and_slide()
		return
	if navigation_path.is_empty():
		return
	path_index = clampi(path_index, 0, navigation_path.size() - 1)
	var target: Vector3 = navigation_path[path_index]
	if global_position.distance_to(target) < 1.2 and path_index < navigation_path.size() - 1:
		path_index += 1
		target = navigation_path[path_index]
	var direction: Vector3 = target - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.04:
		direction = direction.normalized()
		var move_speed: float = speed_chase if state == State.CHASE else speed_walk
		velocity.x = move_toward(velocity.x, direction.x * move_speed, delta * 9.0)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, delta * 9.0)
		look_at(global_position + direction, Vector3.UP)
	move_and_slide()
	var distance: float = global_position.distance_to(player.global_position)
	if distance <= attack_range and attack_cooldown <= 0.0:
		attack_cooldown = 1.8 if personality == Personality.RAM else 1.15
		if lethal:
			var damage: float = 15.0
			match personality:
				Personality.CRAWLER:
					damage = 12.0
				Personality.MIMIC:
					damage = 9.0
				Personality.RAM:
					damage = 28.0
			player.receive_damage(damage, get_robot_name())
			attacked.emit(get_robot_name())
		else:
			global_position = factory.get_stalking_point(player.global_position, 18.0)


func receive_impact(
	damage: float,
	_hit_point: Vector3,
	impulse: Vector3 = Vector3.ZERO
) -> void:
	integrity -= damage
	velocity += impulse * 0.12
	state = State.STUNNED
	stun_timer = clampf(damage * 0.035, 0.45, 3.2)
	if integrity <= 0.0:
		unit_active = false
		visible = false
		set_physics_process(false)
		disabled.emit(get_robot_name())


func get_robot_name() -> String:
	match personality:
		Personality.SPECTER:
			return "SPECTER-5"
		Personality.CRAWLER:
			return "CRAWLER-7"
		Personality.MIMIC:
			return "MIMIC-3"
		Personality.RAM:
			return "RAM-9"
	return "UNITÉ"


func _is_watched() -> bool:
	if not is_instance_valid(player.camera):
		return false
	var to_robot: Vector3 = (
		global_position + Vector3.UP - player.camera.global_position
	).normalized()
	var forward: Vector3 = -player.camera.global_transform.basis.z.normalized()
	if forward.dot(to_robot) < 0.74:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		player.camera.global_position,
		global_position + Vector3.UP
	)
	query.exclude = [player.get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == self


func _build_body() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	visual_root = Node3D.new()
	visual_root.name = "Chassis"
	add_child(visual_root)
	var metal: StandardMaterial3D = WorldUtil.material(
		Color(0.13, 0.145, 0.16), 0.9, 0.24
	)
	var dark: StandardMaterial3D = WorldUtil.material(
		Color(0.025, 0.03, 0.035), 0.65, 0.48
	)
	var red: StandardMaterial3D = WorldUtil.material(
		Color(0.1, 0.01, 0.01),
		0.3,
		0.4,
		Color(1.0, 0.015, 0.01),
		4.0
	)
	match personality:
		Personality.SPECTER:
			var specter_collision: CollisionShape3D = WorldUtil.capsule_collision(0.28, 1.05)
			specter_collision.position.y = 0.82
			add_child(specter_collision)
			_build_biped(metal, dark, red, 0.78, 1.0, true)
		Personality.CRAWLER:
			var crawler_collision: CollisionShape3D = WorldUtil.box_collision(
				Vector3(0.9, 0.48, 1.15)
			)
			crawler_collision.position.y = 0.38
			add_child(crawler_collision)
			_build_quadruped(metal, dark, red)
		Personality.MIMIC:
			var mimic_collision: CollisionShape3D = WorldUtil.capsule_collision(0.25, 0.72)
			mimic_collision.position.y = 0.57
			add_child(mimic_collision)
			_build_biped(dark, metal, red, 0.62, 0.75, false)
		Personality.RAM:
			var ram_collision: CollisionShape3D = WorldUtil.box_collision(
				Vector3(1.25, 1.5, 1.15)
			)
			ram_collision.position.y = 0.85
			add_child(ram_collision)
			_build_biped(metal, dark, red, 1.25, 1.05, false)


func _build_biped(
	metal: Material,
	dark: Material,
	red: Material,
	width_scale: float,
	height_scale: float,
	elongated: bool
) -> void:
	var hip_y: float = 0.78 * height_scale
	var chest_y: float = 1.42 * height_scale
	visual_root.add_child(
		_part_box(
			Vector3(0.0, hip_y, 0.0),
			Vector3(0.42 * width_scale, 0.28, 0.30),
			dark
		)
	)
	visual_root.add_child(
		_part_box(
			Vector3(0.0, chest_y, 0.0),
			Vector3(0.72 * width_scale, 0.74 * height_scale, 0.34),
			metal
		)
	)
	for x_sign_value in [-1.0, 1.0]:
		var x_sign: float = float(x_sign_value)
		var leg: Node3D = Node3D.new()
		leg.position = Vector3(x_sign * 0.22 * width_scale, 0.65, 0.0)
		leg.add_child(
			_part_box(Vector3.ZERO, Vector3(0.14, 0.78 * height_scale, 0.16), dark)
		)
		visual_root.add_child(leg)
		legs.append(leg)
		var arm_x: float = x_sign * 0.48 * width_scale
		var arm_length: float = 1.05 if elongated else 0.72
		visual_root.add_child(
			_part_box(
				Vector3(arm_x, chest_y - 0.05, 0.0),
				Vector3(0.13, arm_length * height_scale, 0.15),
				dark
			)
		)
	head = Node3D.new()
	head.position = Vector3(0.0, 2.05 * height_scale, 0.0)
	visual_root.add_child(head)
	head.add_child(WorldUtil.sphere_mesh(0.24 * width_scale + 0.08, metal, 12, 7))
	jaw = _part_box(
		Vector3(0.0, -0.18, -0.13),
		Vector3(0.34 * width_scale + 0.12, 0.12, 0.24),
		dark
	)
	head.add_child(jaw)
	head.add_child(
		_part_box(Vector3(0.0, 0.04, -0.25), Vector3(0.24, 0.055, 0.035), red)
	)
	if personality == Personality.RAM:
		visual_root.add_child(
			_part_box(Vector3(0.0, 1.30, -0.48), Vector3(1.2, 0.28, 0.7), metal)
		)


func _build_quadruped(metal: Material, dark: Material, red: Material) -> void:
	visual_root.add_child(
		_part_box(Vector3(0.0, 0.58, 0.0), Vector3(0.72, 0.52, 1.05), metal)
	)
	for x_sign_value in [-1.0, 1.0]:
		for z_sign_value in [-1.0, 1.0]:
			var leg: Node3D = Node3D.new()
			leg.position = Vector3(
				float(x_sign_value) * 0.42,
				0.34,
				float(z_sign_value) * 0.36
			)
			leg.add_child(
				_part_box(Vector3.ZERO, Vector3(0.12, 0.58, 0.12), dark)
			)
			visual_root.add_child(leg)
			legs.append(leg)
	head = Node3D.new()
	head.position = Vector3(0.0, 0.72, -0.72)
	visual_root.add_child(head)
	head.add_child(_part_box(Vector3.ZERO, Vector3(0.56, 0.34, 0.54), metal))
	jaw = _part_box(
		Vector3(0.0, -0.18, -0.18), Vector3(0.48, 0.12, 0.38), dark
	)
	head.add_child(jaw)
	head.add_child(
		_part_box(Vector3(0.0, 0.06, -0.29), Vector3(0.28, 0.05, 0.035), red)
	)


func _part_box(at: Vector3, size_value: Vector3, material_value: Material) -> MeshInstance3D:
	var part: MeshInstance3D = WorldUtil.box_mesh(size_value, material_value)
	part.position = at
	return part


func _animate() -> void:
	var moving: float = Vector2(velocity.x, velocity.z).length()
	var animation_time: float = float(Time.get_ticks_msec()) * 0.009
	for index in range(legs.size()):
		legs[index].rotation.x = (
			sin(animation_time + float(index) * PI)
			* 0.42
			* clampf(moving / maxf(speed_walk, 0.1), 0.0, 1.0)
		)
	if is_instance_valid(jaw):
		jaw.rotation.x = sin(animation_time * 0.55) * 0.10
	if is_instance_valid(head) and is_instance_valid(player):
		var local_target: Vector3 = head.to_local(player.camera.global_position)
		head.rotation.y = clampf(atan2(local_target.x, -local_target.z), -0.8, 0.8)
