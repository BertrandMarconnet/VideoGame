class_name EnvironmentAgent
extends Node

signal environment_event(text: String)

var factory: FactoryGenerator
var player: PlayerController
var rng := RandomNumberGenerator.new()
var semantic_graph: Dictionary = {}
var adaptation_timer := 0.0
var generated_props := 0
var max_generated_props := 28
var secret_hint_created := false

func configure(world_factory: FactoryGenerator, player_node: PlayerController, seed_value: int) -> void:
	factory = world_factory
	player = player_node
	rng.seed = seed_value ^ 0x5A17
	max_generated_props = 16 if OS.has_feature("web") or OS.has_feature("mobile") else 28
	call_deferred("_scan_and_populate")

func _process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(player):
		return
	adaptation_timer += delta
	if adaptation_timer >= 22.0:
		adaptation_timer = 0.0
		_adapt_environment()

func _scan_and_populate() -> void:
	semantic_graph.clear()
	var rooms := factory.get_semantic_rooms()
	for room in rooms:
		var semantic := String(room.get_meta("semantic_type", "unknown"))
		semantic_graph[room.name] = {
			"semantic": semantic,
			"position": room.global_position,
			"size": room.get_meta("size", Vector3(12.0, 4.0, 12.0)),
			"neighbors": []
		}
	for first_name in semantic_graph:
		for second_name in semantic_graph:
			if first_name == second_name:
				continue
			var first_position: Vector3 = semantic_graph[first_name]["position"]
			var second_position: Vector3 = semantic_graph[second_name]["position"]
			if first_position.distance_to(second_position) < 48.0:
				semantic_graph[first_name]["neighbors"].append(second_name)
	_populate_contextually()

func _populate_contextually() -> void:
	for room_name in semantic_graph:
		if generated_props >= max_generated_props:
			break
		var data: Dictionary = semantic_graph[room_name]
		var semantic := String(data["semantic"])
		var center: Vector3 = data["position"]
		var size: Vector3 = data["size"]
		var budget := _budget_for(semantic)
		for _i in range(budget):
			if generated_props >= max_generated_props:
				break
			var kind := _prop_for(semantic)
			var offset := Vector3(
				rng.randf_range(-size.x * 0.35, size.x * 0.35),
				0.75,
				rng.randf_range(-size.z * 0.35, size.z * 0.35)
			)
			if absf(offset.x) < 2.2:
				offset.x = 3.0 if rng.randf() > 0.5 else -3.0
			factory.create_runtime_prop(kind, center + offset)
			generated_props += 1

func _budget_for(semantic: String) -> int:
	match semantic:
		"control_room": return 2
		"logistics": return 7
		"assembly": return 5
		"archives": return 5
		"foundry": return 5
	return 3

func _prop_for(semantic: String) -> String:
	match semantic:
		"control_room": return "toolbox"
		"logistics": return "crate" if rng.randf() < 0.75 else "panel"
		"assembly": return "pipe" if rng.randf() < 0.6 else "toolbox"
		"archives": return "crate" if rng.randf() < 0.6 else "panel"
		"foundry": return "panel" if rng.randf() < 0.55 else "pipe"
	return "crate"

func _adapt_environment() -> void:
	var snapshot := player.get_behavior_snapshot()
	if not secret_hint_created and float(snapshot["distance"]) > 95.0:
		secret_hint_created = true
		factory.create_runtime_prop("toolbox", Vector3(-8.7, 0.8, -88.5))
		environment_event.emit("L'agent d'environnement a signalé un courant d'air derrière la cloison M-04.")
		return
	if generated_props >= max_generated_props:
		return
	if bool(snapshot["carrying"]):
		factory.create_runtime_prop("panel", player.global_position + Vector3(4.0, 0.8, -5.0))
		environment_event.emit("Une palette automatique a déplacé une tôle vers votre secteur.")
	else:
		factory.create_runtime_prop("toolbox", player.global_position + Vector3(-4.0, 0.7, -7.0))
		environment_event.emit("Le système logistique a réaffecté une boîte à outils.")
	generated_props += 1

func get_semantic_summary() -> Dictionary:
	return semantic_graph.duplicate(true)
