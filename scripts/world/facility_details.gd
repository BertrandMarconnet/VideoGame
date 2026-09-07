extends RefCounted
var game: Node3D
var v: RefCounted
var root: Node3D
var interactables: Dictionary = {}
var doors: Array[AnimatableBody3D] = []
const Door = preload("res://scripts/world/facility_door.gd")
const ITEMS := {
	"fuse": [Vector3(-10.0, 1.05, -28.0), "FUSIBLE DE RECHANGE", "LOGISTICS"],
	"power": [Vector3(14.8, 1.2, -42.0), "CIRCUIT AUXILIAIRE", "POWER"],
	"archive": [Vector3(-14.8, 1.1, -42.0), "DOSSIER MATRYOSHKA", "ARCHIVES"],
	"assembly": [Vector3(14.5, 1.2, -34.8), "SERVO DÉVIANT", "ASSEMBLY"],
	"tape": [Vector3(-10.0, 1.1, -62.5), "BANDE NUIT 00", "MAINTENANCE"],
	"test": [Vector3(9.4, 1.2, -62.5), "CALIBRATION DELTA", "TEST"],
	"secret": [Vector3(0, 0.7, -55), "ARCHIVE M-04", "SECRET"],
	"relay": [Vector3(0, 1.1, -87.8), "RELAIS NORD", "RELAY"],
}

func install(scene: Node3D) -> void:
	game = scene
	v = game.visuals_v20
	root = Node3D.new()
	root.name = "FacilityDetails"
	game.add_child(root)
	game.uplink_terminal.position = Vector3(-3.0, 1.1, -11.8)
	for child in game.uplink_terminal.get_children():
		if child is MeshInstance3D:
			child.hide()
	game.drone_home = Vector3(3.5, 1.5, -16.0)
	game.drone.position = game.drone_home
	for index in range(8):
		var z := -17.0 - index * 9
		for x in [-5.55, 5.55]:
			game._build_ceiling_light(Vector3(x, 3.55, z), index == 5)
			v.cylinder(root, 0.065, 8.7, Vector3(x + 1.42, 3.36, z), v.surface("steel"), "SupplyPipe", Vector3(90, 0, 0))
	for side in [-1.0, 1.0]:
		for z in [-33.5, -47.0, -61.0]:
			var door := Door.new()
			door.name = "RoomDoor_%s_%s" % [side, z]
			root.add_child(door)
			door.configure(game, Vector3(side * 7.45, 1.35, z))
			doors.append(door)
			for offset in [-1.5, 1.5]:
				game.fnaf_factory_v21._static_box(root, Vector3(0.4, 2.9, 0.16), Vector3(side * 7.45, 1.45, z + offset), v.surface("steel"), "IntegratedDoorFrame")
			game.fnaf_factory_v21._static_box(root, Vector3(0.3, 1.05, 2.9), Vector3(side * 7.45, 3.25, z), v.surface("concrete"), "DoorLintel")
		for index in range(3):
			var at := Vector3(side * 15.9, 0, -27.0 - index * 14.5)
			v.cabinet(root, at, -90 * side)
			v.poster(root, at + Vector3(-side * 0.1, 2.6, -2), index, -90 * side)
			v.drum(root, Vector3(side * 14.7, 0, at.z - 5.4), "ServiceDrum")
	v.pump(root, Vector3(13.7, 0, -49.5))
	v.pump(root, Vector3(-12.7, 0, -58.5))
	for child in root.get_children():
		if child is Node3D and not child is PhysicsBody3D:
			child.set_meta("facility_editable", true)
	_hub_details()
	# All tasks have a physical, raycastable control. Terminal collision is kept.
	for key in ITEMS:
		var spec: Array = ITEMS[key]
		var body: StaticBody3D
		if key == "relay":
			body = game.relay_terminal
		else:
			body = game.fnaf_factory_v21._static_box(root, Vector3(0.52, 0.30, 0.35), spec[0], v.surface("paint"), "Task_" + key)
		if key != "relay":
			var base: Vector3 = spec[0]
			v.box(root, Vector3(0.12, base.y - 0.15, 0.15), Vector3(base.x, (base.y - 0.15) / 2, base.z), v.surface("steel"), "TaskPedestal")
			v.box(root, Vector3(0.55, 0.04, 0.4), Vector3(base.x, 0.02, base.z), v.surface("steel"), "TaskFoot")
		body.set_meta("shift_task", key)
		interactables[key] = body
		if key != "relay":
			v.sign_board(root, spec[0] + Vector3(0, 0.52, 0), String(spec[1]), 0, Color(0.8,0.86,0.74), 0.35)
			v.box(root,Vector3(0.06,0.52,0.06),spec[0]+Vector3(0,0.26,0.1),v.surface("steel"),"TaskSignSupport")
	# Breakable window in a framed partition opens a maintenance shortcut.
	game._build_destructible_wall(Vector3(3.5, 0.65, -53), Vector3(0.22, 1.3, 2.4), "M04ExitGrille")
	game.fnaf_factory_v21._static_box(root, Vector3(7.0, 2.4, 0.22), Vector3(0, 2.6, -48.9), v.surface("concrete"), "M04NorthPartition")
	game.fnaf_factory_v21._static_box(root, Vector3(7.0, 3.8, 0.22), Vector3(0, 1.9, -57.1), v.surface("concrete"), "M04SouthPartition")
	game.fnaf_factory_v21._static_box(root, Vector3(7.0, 0.18, 8.0), Vector3(0, 1.48, -53), v.surface("concrete"), "M04CrawlCeiling")
	for body in game.find_children("*", "StaticBody3D", true, false):
		if body.get_meta("destructible", false):
			body.set_meta("noise_radius", 25.0)
	# Give each room a real functioning production detail rather than a bare cube.
	game._build_industrial_arm_v11(Vector3(11.6, 0.85, -31), 1.0)
	preload("res://scripts/visual/facility_furniture.gd").new().install(game)

func _hub_details() -> void:
	v.box(root, Vector3(3.6, 0.12, 0.8), Vector3(0, 0.82, -11.8), v.surface("paint"), "RadioDesk", true)
	for x in [-1.5, 1.5]:
		v.box(root, Vector3(0.08, 0.76, 0.6), Vector3(x, 0.38, -11.8), v.surface("steel"), "DeskLeg")
	var warm: StandardMaterial3D = v.material(Color(0.30, 0.22, 0.12), 0.1, 0.7, Color.BLACK)
	v.box(root, Vector3(0.42, 0.19, 0.27), Vector3(0.2, 0.97, -11.8), v.surface("rubber"), "Radio", true)
	for i in range(5):
		v.box(root, Vector3(0.22, 0.013, 0.013), Vector3(0.2, 0.93 + i * 0.023, -11.96), v.surface("steel"), "RadioGrille")
	v.cylinder(root, 0.07, 0.16, Vector3(-1, 0.96, -11.8), warm, "TechnicianMug")
	v.box(root, Vector3(0.25, 0.008, 0.35), Vector3(1, 0.91, -11.9), warm, "ShiftNotebook")
	v.sign_board(root, Vector3(3, 2.4, -10.72), "NUIT / 23:47\nBADGE : MERCER", 180)
	# Schematic comes from the same room graph as gameplay.
	var plan := "S-01\nOUEST : LOGISTIQUE / ARCHIVES\nEST : ASSEMBLAGE / ÉNERGIE\nBOUCLE NORD : RELAIS\nM-04 : MAINTENANCE"
	var label: Label3D = game.fnaf_factory_v21._label(root, plan, Vector3(-5.8, 2.1, -10.72), 28, Color(0.64, 0.83, 0.74), Vector3(0, 180, 0))
	label.pixel_size = 0.0027
