extends SceneTree

const MaterialResponseDBScript := preload("res://scripts/destruction/material_response_db.gd")
const DestructibleComponentScript := preload("res://scripts/destruction/destructible_component.gd")

var failed := false

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("DAMAGE_TEST_FAIL: " + message)

func _run() -> void:
	var database: MaterialResponseDB = MaterialResponseDBScript.new()
	_check(database.damage_multiplier("drywall", "crowbar") > database.damage_multiplier("brick", "crowbar"), "crowbar must be more effective on drywall than brick")
	_check(database.damage_multiplier("brick", "specter_charge") > database.damage_multiplier("brick", "flashlight_bash"), "SPECTER charge must outperform flashlight on brick")
	_check(database.is_structural("concrete"), "concrete must be structural")

	var wall := StaticBody3D.new()
	wall.name = "DamageTestWall"
	root.add_child(wall)
	var mesh := MeshInstance3D.new()
	mesh.name = "DZ_wall_00_00"
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 0.18)
	mesh.mesh = box
	wall.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 0.18)
	collision.shape = shape
	wall.add_child(collision)
	var wall_component: DestructibleComponent = DestructibleComponentScript.new()
	wall_component.name = "DestructibleComponent"
	wall.add_child(wall_component)
	await process_frame
	wall_component.configure({
		"category": "wall",
		"default_material": "drywall",
		"zones": [{
			"id": "cell_00_00",
			"material_id": "drywall",
			"max_health": 20.0,
			"detachable": true,
			"node_patterns": ["DZ_wall_00_00"],
			"on_break": "open_hole"
		}]
	})
	var wall_result := wall_component.apply_damage({
		"zone_id": "cell_00_00",
		"amount": 10.0,
		"tool_id": "crowbar",
		"damage_type": "impact"
	})
	await process_frame
	_check(bool(wall_result.get("broken", false)), "drywall cell must break under the configured crowbar impact")
	_check(collision.disabled, "broken wall cell collision must be disabled to create a real hole")
	_check(not mesh.visible, "broken wall cell mesh must be hidden")

	var specter := CharacterBody3D.new()
	specter.name = "DamageTestSpecter"
	root.add_child(specter)
	var body_collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	body_collision.shape = capsule
	specter.add_child(body_collision)
	for part_name in ["DZ_l_leg_upper", "DZ_r_leg_upper"]:
		var part := MeshInstance3D.new()
		part.name = part_name
		var part_mesh := BoxMesh.new()
		part_mesh.size = Vector3(0.2, 0.8, 0.2)
		part.mesh = part_mesh
		specter.add_child(part)
	var specter_component: DestructibleComponent = DestructibleComponentScript.new()
	specter_component.name = "DestructibleComponent"
	specter.add_child(specter_component)
	await process_frame
	specter_component.configure({
		"category": "robot_biped",
		"default_material": "metal_armored",
		"zones": [
			{"id":"left_leg","material_id":"metal_light","max_health":35.0,"detachable":true,"node_patterns":["DZ_l_leg_*"],"speed_multiplier":0.65,"on_break":"limp"},
			{"id":"right_leg","material_id":"metal_light","max_health":35.0,"detachable":true,"node_patterns":["DZ_r_leg_*"],"speed_multiplier":0.65,"on_break":"limp"}
		]
	})
	specter_component.apply_damage({"zone_id":"left_leg","amount":50.0,"tool_id":"crowbar","damage_type":"impact"})
	specter_component.apply_damage({"zone_id":"right_leg","amount":50.0,"tool_id":"crowbar","damage_type":"impact"})
	await process_frame
	_check(specter_component.movement_mode == "crawl", "SPECTER must switch to crawl after both legs break")
	_check(specter_component.speed_multiplier < 0.5, "two broken legs must substantially reduce movement speed")
	var crawl_capsule := body_collision.shape as CapsuleShape3D
	_check(crawl_capsule != null and crawl_capsule.height < 1.2, "crawl mode must lower the physical capsule")

	wall.queue_free()
	specter.queue_free()
	if failed:
		quit(1)
	else:
		print("DAMAGE_SYSTEM_TEST_OK")
		quit(0)
