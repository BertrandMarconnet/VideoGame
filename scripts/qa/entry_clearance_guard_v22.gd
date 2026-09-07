class_name BlackoutEntryClearanceGuardV22
extends Node
## Hard safety guard for the Act I onboarding path.
## Legacy vestibule closure walls are no longer part of the playable route.

const REMOVED_BLOCKERS := [
	"VestibuleNorthWallV18",
	"VestibuleSouthWallV18",
	"VestibuleEndWallV18",
]

var game: Node3D
var removed_count := 0

func configure(game_scene: Node3D) -> void:
	game = game_scene
	name = "EntryClearanceGuardV22"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_clear_legacy_blockers()
	print("BLACKOUT_ENTRY_CLEARANCE_GUARD_V22_READY")

func _process(_delta: float) -> void:
	_clear_legacy_blockers()

func _clear_legacy_blockers() -> void:
	if game == null or not is_instance_valid(game):
		return
	for blocker_name in REMOVED_BLOCKERS:
		for candidate in game.find_children(blocker_name, "StaticBody3D", true, false):
			var body := candidate as StaticBody3D
			if body.has_meta("entry_clearance_removed_v22"):
				continue
			body.set_meta("entry_clearance_removed_v22", true)
			body.collision_layer = 0
			body.collision_mask = 0
			for shape_node in body.find_children("*", "CollisionShape3D", true, false):
				(shape_node as CollisionShape3D).set_deferred("disabled", true)
			for mesh_node in body.find_children("*", "MeshInstance3D", true, false):
				(mesh_node as MeshInstance3D).visible = false
			body.queue_free()
			removed_count += 1
			if game != null:
				game.set_meta("entry_clearance_removed_v22", removed_count)
			print("BLACKOUT_ENTRY_CLEARANCE_REMOVED ", blocker_name)
