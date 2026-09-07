extends AnimatableBody3D
var opened := false
var broken := false
var health := 70.0
var closed_at := Vector3.ZERO
var game: Node3D

func configure(scene: Node3D, at: Vector3) -> void:
	game = scene
	position = at
	closed_at = at
	sync_to_physics = true
	set_meta("facility_door", true)
	set_meta("destructible", true)
	set_meta("size", Vector3(0.20, 2.7, 2.65))
	var mesh := MeshInstance3D.new()
	mesh.mesh = game.visuals_v20.bevel_box(Vector3(0.20, 2.7, 2.65), 0.04)
	mesh.material_override = game.visuals_v20.surface("paint")
	add_child(mesh)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.20, 2.7, 2.65)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

func toggle() -> void:
	if broken:
		return
	opened = not opened
	if game.shift:
		game.shift.sound.emit("MetalScrape", global_position)
		game.shift.make_noise(global_position, 12)

func take_hit(amount: float) -> void:
	health -= amount
	if game.shift:
		game.shift.make_noise(global_position, 26)
		game.shift.sound.emit("DoorHit", global_position, 3)
	if health <= 0:
		broken = true
		opened = true
		set_meta("destructible", false)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var target := closed_at + Vector3.UP * (3.15 if opened else 0.0)
	# Avoid trapping the player while a shutter descends.
	if not opened and game.player and absf(game.player.position.x - closed_at.x) < 0.6 and absf(game.player.position.z - closed_at.z) < 1.65:
		return
	position = position.move_toward(target, delta * 3.0)
