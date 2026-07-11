class_name ControlConsole
extends StaticBody3D

signal activated(console_id: String)
var console_id := ""
var title := "CONSOLE"
var used := false
var glow: StandardMaterial3D

func configure(id_value: String, title_value: String, at: Vector3, facing_y: float = 0.0) -> void:
	console_id = id_value
	title = title_value
	position = at
	rotation.y = facing_y
	var dark := WorldUtil.material(Color(0.055, 0.075, 0.09), 0.62, 0.55)
	glow = WorldUtil.material(Color(0.02, 0.08, 0.09), 0.2, 0.1, Color(0.08, 0.75, 1.0), 2.3)
	add_child(WorldUtil.box_mesh(Vector3(1.45, 1.15, 0.8), dark))
	add_child(WorldUtil.box_collision(Vector3(1.45, 1.15, 0.8)))
	var screen := WorldUtil.box_mesh(Vector3(1.08, 0.52, 0.05), glow)
	screen.position = Vector3(0.0, 0.18, -0.43)
	add_child(screen)
	add_child(WorldUtil.label3d(title, Vector3(0.0, 0.88, 0.0), Color(0.35, 0.9, 1.0), 24))
	add_to_group("interactable")

func get_prompt() -> String:
	return "E — %s" % title

func interact(_player: Node) -> void:
	used = true
	if glow:
		glow.emission = Color(0.2, 1.0, 0.45)
	activated.emit(console_id)
