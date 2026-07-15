class_name MaterialResponseDB
extends RefCounted

const DATABASE_PATH := "res://data/material_response_db.json"

var _materials: Dictionary = {}

func _init() -> void:
	_load_database()

func _load_database() -> void:
	if not FileAccess.file_exists(DATABASE_PATH):
		push_warning("Material response database missing: %s" % DATABASE_PATH)
		return
	var file := FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to open material response database")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_materials = (parsed as Dictionary).get("materials", {}) as Dictionary

func get_profile(material_id: String) -> Dictionary:
	if _materials.has(material_id):
		return (_materials[material_id] as Dictionary).duplicate(true)
	return {
		"base_health": 50.0,
		"density": 1.0,
		"fracture": "generic",
		"damage_multipliers": {
			"flashlight_bash": 0.35,
			"plank": 0.6,
			"crowbar": 1.0,
			"thrown_prop": 0.8,
			"specter_charge": 2.0
		}
	}

func damage_multiplier(material_id: String, tool_id: String, damage_type := "impact") -> float:
	var profile := get_profile(material_id)
	var multipliers := profile.get("damage_multipliers", {}) as Dictionary
	if multipliers.has(tool_id):
		return maxf(float(multipliers[tool_id]), 0.0)
	if multipliers.has(damage_type):
		return maxf(float(multipliers[damage_type]), 0.0)
	return 1.0

func base_health(material_id: String) -> float:
	return maxf(float(get_profile(material_id).get("base_health", 50.0)), 1.0)

func fracture_mode(material_id: String) -> String:
	return String(get_profile(material_id).get("fracture", "generic"))

func is_structural(material_id: String) -> bool:
	return fracture_mode(material_id) == "structural"
