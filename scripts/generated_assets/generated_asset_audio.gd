class_name GeneratedAssetAudio
extends Node

var profile: Dictionary = {}
var animation_player: AnimationPlayer
var event_players: Dictionary = {}
var previous_animation := ""
var previous_normalized := 0.0
var configured := false

func configure(profile_path: String) -> void:
	if profile_path.is_empty() or not FileAccess.file_exists(profile_path):
		queue_free()
		return
	var file := FileAccess.open(profile_path, FileAccess.READ)
	if file == null:
		queue_free()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		queue_free()
		return
	profile = (parsed as Dictionary).duplicate(true)
	call_deferred("_finish_setup")

func _finish_setup() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		queue_free()
		return
	for candidate in parent_node.find_children("*", "AnimationPlayer", true, false):
		animation_player = candidate as AnimationPlayer
		if animation_player != null:
			break
	_build_players()
	_start_always_events()
	configured = true
	set_process(animation_player != null)

func _build_players() -> void:
	var spatial := bool(profile.get("spatial", true))
	var events := profile.get("events", []) as Array
	for index in range(events.size()):
		var event := events[index] as Dictionary
		var path := String(event.get("stream", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			continue
		var player: Node
		if spatial:
			var player_3d := AudioStreamPlayer3D.new()
			player_3d.max_distance = 28.0
			player_3d.unit_size = 2.0
			player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			player = player_3d
		else:
			player = AudioStreamPlayer.new()
		player.name = "GeneratedAudio_%02d" % index
		player.set("stream", stream)
		player.set("volume_db", float(event.get("volume_db", -6.0)))
		player.set("pitch_scale", float(event.get("pitch_scale", 1.0)))
		add_child(player)
		event_players[index] = player

func _start_always_events() -> void:
	var events := profile.get("events", []) as Array
	for index in range(events.size()):
		var event := events[index] as Dictionary
		if String(event.get("animation", "")) == "__always__":
			_play_event(index, event)

func _process(_delta: float) -> void:
	if not configured or animation_player == null:
		return
	var animation := String(animation_player.current_animation)
	if animation.is_empty():
		_stop_animation_loops(previous_animation)
		previous_animation = ""
		previous_normalized = 0.0
		return
	var length := maxf(animation_player.current_animation_length, 0.0001)
	var normalized := clampf(animation_player.current_animation_position / length, 0.0, 1.0)
	if animation != previous_animation:
		_stop_animation_loops(previous_animation)
		previous_animation = animation
		previous_normalized = -0.001
		_trigger_crossed_events(animation, previous_normalized, normalized, false)
	elif normalized + 0.001 < previous_normalized:
		_trigger_crossed_events(animation, previous_normalized, 1.0, true)
		_trigger_crossed_events(animation, -0.001, normalized, true)
	else:
		_trigger_crossed_events(animation, previous_normalized, normalized, false)
	previous_normalized = normalized

func _trigger_crossed_events(animation: String, start: float, finish: float, _wrapped: bool) -> void:
	var events := profile.get("events", []) as Array
	for index in range(events.size()):
		var event := events[index] as Dictionary
		if not _animation_matches(animation, String(event.get("animation", ""))):
			continue
		var marker := clampf(float(event.get("time_normalized", 0.0)), 0.0, 1.0)
		if marker > start and marker <= finish:
			_play_event(index, event)

func _animation_matches(current: String, requested: String) -> bool:
	var current_key := current.to_lower().replace("-loop", "").replace("_loop", "")
	var requested_key := requested.to_lower().replace("-loop", "").replace("_loop", "")
	return current_key == requested_key or current_key.contains(requested_key) or requested_key.contains(current_key)

func _play_event(index: int, event: Dictionary) -> void:
	var player := event_players.get(index) as Node
	if player == null:
		return
	var looping := bool(event.get("loop", false))
	if looping and bool(player.get("playing")):
		return
	player.call("play")

func _stop_animation_loops(animation: String) -> void:
	if animation.is_empty():
		return
	var events := profile.get("events", []) as Array
	for index in range(events.size()):
		var event := events[index] as Dictionary
		if bool(event.get("loop", false)) and _animation_matches(animation, String(event.get("animation", ""))):
			var player := event_players.get(index) as Node
			if player != null:
				player.call("stop")
