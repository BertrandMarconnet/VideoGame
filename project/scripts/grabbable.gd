class_name GrabbableProp
extends RigidBody3D

@export var prop_kind := "crate"
@export var impact_scale := 1.0
var held := false
var holder: Node3D
var hold_distance := 2.1
var last_speed := 0.0
var original_gravity := 1.0

func configure(kind: String, size: Vector3, mat: Material, mass_value: float = 6.0) -> void:
	prop_kind = kind
	mass = mass_value
	continuous_cd = true
	max_contacts_reported = 8
	contact_monitor = true
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	add_child(WorldUtil.box_mesh(size, mat))
	add_child(WorldUtil.box_collision(size))
	add_to_group("grabbable")

func _ready() -> void:
	original_gravity = gravity_scale
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	last_speed = linear_velocity.length()
	if held and is_instance_valid(holder):
		var camera := holder.get_node_or_null("Camera3D") as Camera3D
		if camera:
			var target := camera.global_position - camera.global_transform.basis.z * hold_distance + Vector3(0.0, -0.12, 0.0)
			var error := target - global_position
			linear_velocity = error * 10.0
			angular_velocity *= 0.68

func grab(new_holder: Node3D) -> void:
	held = true
	holder = new_holder
	gravity_scale = 0.08
	collision_mask = 2 | 4
	linear_damp = 4.5
	angular_damp = 4.0
	sleeping = false

func release() -> void:
	held = false
	holder = null
	gravity_scale = original_gravity
	collision_mask = 1 | 2 | 4
	linear_damp = 0.15
	angular_damp = 0.25

func throw_from(direction: Vector3) -> void:
	release()
	apply_central_impulse(direction.normalized() * clampf(mass * 2.7, 16.0, 58.0))

func _on_body_entered(body: Node) -> void:
	if held or last_speed < 2.7:
		return
	var damage := clampf(mass * last_speed * impact_scale * 0.55, 4.0, 90.0)
	if body.has_method("receive_impact"):
		body.receive_impact(damage, global_position, linear_velocity * mass * 0.12)
	elif body.get_parent() and body.get_parent().has_method("receive_impact"):
		body.get_parent().receive_impact(damage, global_position, linear_velocity * mass * 0.12)
