class_name WorldForgeEventDirector
extends Node

var scene_root: Node3D
var player: Node3D
var seed_value := 0
var _rng := RandomNumberGenerator.new()
var _anchors: Array[Node3D] = []
var _triggered: Dictionary = {}
var _refresh_elapsed := 0.0

func configure(root: Node3D, seed: int) -> void:
	scene_root = root
	seed_value = seed
	_rng.seed = seed
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = scene_root.find_child("Player", true, false) as Node3D
	_refresh_anchors()

func _process(delta: float) -> void:
	if scene_root == null or player == null or not is_instance_valid(scene_root) or not is_instance_valid(player):
		return
	var game_started_value = scene_root.get("game_started")
	if game_started_value == null or not bool(game_started_value) or get_tree().paused:
		return
	_refresh_elapsed += delta
	if _refresh_elapsed >= 4.0:
		_refresh_elapsed = 0.0
		_refresh_anchors()
	for anchor in _anchors:
		if not is_instance_valid(anchor):
			continue
		var key := str(anchor.get_path())
		if bool(_triggered.get(key, false)):
			continue
		if player.global_position.distance_to(anchor.global_position) <= 5.5:
			_triggered[key] = true
			_trigger_anchor(anchor)

func _refresh_anchors() -> void:
	_anchors.clear()
	if scene_root == null:
		return
	for candidate in scene_root.find_children("WF_EventAnchor", "Node3D", true, false):
		if candidate is Node3D:
			_anchors.append(candidate as Node3D)

func _trigger_anchor(anchor: Node3D) -> void:
	var tags_value = anchor.get_meta("event_tags", [])
	var tags: Array = tags_value if tags_value is Array else []
	if tags.is_empty():
		return
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value ^ int(anchor.get_meta("event_seed", anchor.get_instance_id()))
	var tag := String(tags[local_rng.randi_range(0, tags.size() - 1)])
	match tag:
		"electric", "darkness":
			_trigger_electric_event(anchor, local_rng)
		"ambush", "stalker":
			_trigger_stalker_event(anchor)
		"hallucination", "false_signal":
			_trigger_false_signal(local_rng)
		"camera", "athena":
			_trigger_athena_observation(local_rng)
		"archive", "lore":
			_trigger_archive_trace(local_rng)
		"drone":
			_show_status("KITE-01 détecte un conduit actif derrière la cloison.")
		"noise":
			_show_status("IMPACT MÉTALLIQUE À PROXIMITÉ — origine non confirmée.")
		_:
			_trigger_silence_event(anchor)
	anchor.set_meta("worldforge_event_triggered", true)
	anchor.set_meta("worldforge_event_selected", tag)

func _trigger_electric_event(anchor: Node3D, local_rng: RandomNumberGenerator) -> void:
	var affected := 0
	for candidate in scene_root.find_children("*", "OmniLight3D", true, false):
		if candidate is OmniLight3D and (candidate as OmniLight3D).global_position.distance_to(anchor.global_position) < 14.0:
			var light := candidate as OmniLight3D
			var original_energy := light.light_energy
			light.light_energy = original_energy * local_rng.randf_range(0.05, 0.28)
			var tween := create_tween()
			tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_interval(local_rng.randf_range(0.12, 0.42))
			tween.tween_property(light, "light_energy", original_energy, local_rng.randf_range(0.18, 0.55))
			affected += 1
			if affected >= 3:
				break
	_set_beep(local_rng.randf_range(420.0, 980.0), 0.38)
	_show_status("SURTENSION LOCALE — éclairage et capteurs brièvement instables.")

func _trigger_stalker_event(anchor: Node3D) -> void:
	var nearest: CharacterBody3D = null
	var nearest_distance := INF
	for candidate in scene_root.find_children("*", "CharacterBody3D", true, false):
		if candidate is CharacterBody3D and bool(candidate.get_meta("robot", false)):
			var distance := (candidate as CharacterBody3D).global_position.distance_to(anchor.global_position)
			if distance < nearest_distance:
				nearest = candidate as CharacterBody3D
				nearest_distance = distance
	if nearest != null:
		nearest.set_meta("worldforge_event_boost_until", Time.get_ticks_msec() + 9000)
		nearest.set_meta("attack_cd", 0.0)
		if scene_root.has_method("_set_robot_animation"):
			scene_root.call("_set_robot_animation", nearest, "Run-loop")
	_show_status("ATHENA : « Quelque chose a appris votre trajet. »")
	_set_beep(180.0, 0.28)

func _trigger_false_signal(local_rng: RandomNumberGenerator) -> void:
	var messages := [
		"CAM 04 : silhouette détectée — confirmation impossible.",
		"RELAIS NORD : réponse reçue avant l'envoi de la requête.",
		"KITE-01 : mouvement derrière vous. Aucun écho thermique.",
		"ATHENA : « Je n'ai pas généré ce message. »"
	]
	_show_status(String(messages[local_rng.randi_range(0, messages.size() - 1)]))
	_set_beep(local_rng.randf_range(260.0, 620.0), 0.22)

func _trigger_athena_observation(local_rng: RandomNumberGenerator) -> void:
	var lines := [
		"ATHENA : « Cette salle n'était pas dans mon plan précédent. »",
		"ATHENA : « Votre manière d'explorer modifie mes hypothèses. »",
		"ATHENA : « Je conserve les chemins que vous évitez. »"
	]
	var line := String(lines[local_rng.randi_range(0, lines.size() - 1)])
	if scene_root.get("athena_last_line") != null:
		scene_root.set("athena_last_line", line.replace("ATHENA : ", ""))
	_show_status(line)

func _trigger_archive_trace(local_rng: RandomNumberGenerator) -> void:
	var fragments := [
		"ARCHIVE PARTIELLE : PERSEUS / cellule spatiale adaptative.",
		"NOTE TECHNIQUE : les plans étaient recomposés après chaque audit nocturne.",
		"JOURNAL CORROMPU : l'usine ne doit jamais présenter deux fois le même trajet."
	]
	_show_status(String(fragments[local_rng.randi_range(0, fragments.size() - 1)]))
	_set_beep(740.0, 0.16)

func _trigger_silence_event(anchor: Node3D) -> void:
	anchor.set_meta("worldforge_silence_until", Time.get_ticks_msec() + 7000)
	_show_status("Le bruit de fond de l'usine vient de s'arrêter.")

func _show_status(message: String) -> void:
	if scene_root != null and scene_root.has_method("_show_status"):
		scene_root.call("_show_status", message)

func _set_beep(frequency: float, duration: float) -> void:
	if scene_root == null:
		return
	if scene_root.get("status_beep_frequency") != null:
		scene_root.set("status_beep_frequency", frequency)
	if scene_root.get("status_beep_remaining") != null:
		scene_root.set("status_beep_remaining", duration)
