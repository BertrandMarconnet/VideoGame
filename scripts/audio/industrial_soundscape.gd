extends Node3D
## Bounded spatial sound bank; no music or network dependency.
signal cue_emitted(kind: String, at: Vector3)
var bank: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []
var events: Dictionary = {}
var ambient: Array[AudioStreamPlayer3D] = []
var time := 0.0
var cursor := 0

func configure() -> void:
	for kind in ["Footstep_L", "Footstep_R", "ServoShoulder", "ServoHip", "MetalScrape", "JawClick", "Impact", "Grab", "DoorHit", "Shutdown", "Radio", "Vent", "Transformer"]:
		bank[kind] = _wave(kind)
	for index in range(10):
		var voice := AudioStreamPlayer3D.new()
		voice.set_meta("pooled_voice", true)
		voice.max_distance = 35.0
		voice.unit_size = 5.0
		voice.volume_db = -15
		add_child(voice)
		voices.append(voice)
	for at in [Vector3(12, 2.3, -46), Vector3(-3, 2.8, -40), Vector3(0, 2.8, -85)]:
		var motor := AudioStreamPlayer3D.new()
		motor.position = at
		motor.stream = bank["Transformer" if ambient.is_empty() else "Vent"]
		motor.max_distance = 22.0
		motor.unit_size = 3.0
		motor.volume_db = -25
		add_child(motor)
		ambient.append(motor)
		motor.play()

func emit(kind: String, at: Vector3, gain := 0.0) -> void:
	if not bank.has(kind) or voices.is_empty():
		return
	var voice := voices[cursor % voices.size()]
	cursor += 1
	voice.stop()
	voice.global_position = at
	voice.stream = bank[kind]
	voice.volume_db = -15 + gain
	voice.play()
	events[kind] = int(events.get(kind, 0)) + 1
	cue_emitted.emit(kind, at)

func tick(delta: float, active: bool) -> void:
	time += delta
	for index in range(ambient.size()):
		# Deliberate gaps: machinery winds down instead of a permanent music bed.
		ambient[index].volume_db = -25 if active and fmod(time + index * 6, 43.0) < 30.0 else -65

func _wave(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var looping := kind in ["Vent", "Transformer"]
	var duration := 2.0 if looping else (1.1 if kind in ["Shutdown", "Radio", "MetalScrape"] else 0.35)
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = kind.hash()
	var low := 0.0
	for index in range(count):
		var t := float(index) / rate
		var progress := t / duration
		low = lerpf(low, random.randf_range(-1, 1), 0.13)
		var value := low * 0.3
		if kind in ["Footstep_L", "Footstep_R", "Impact", "DoorHit", "Grab"]:
			value = sin(TAU * 72 * t) * exp(-t * 19) * 0.6 + low * exp(-t * 24)
		elif kind in ["ServoShoulder", "ServoHip", "JawClick"]:
			value = sin(TAU * (160 * t + 130 * t * t)) * 0.22 + low * 0.10
		elif kind == "Shutdown":
			value = sin(TAU * (240 * t - 92 * t * t)) * 0.35
		elif kind == "Transformer":
			value = sin(TAU * 50 * t) * 0.26 + sin(TAU * 100 * t) * 0.08 + low * 0.04
		elif kind == "Vent":
			value = low * (0.15 + sin(TAU * 12 * t) * 0.05)
		elif kind == "Radio":
			value = low * 0.38 + sin(TAU * 790 * t) * 0.06 * maxf(0, sin(TAU * 4 * t))
		var envelope := 1.0 if looping else minf(t * 160, 1.0) * pow(1.0 - progress, 1.3)
		data.encode_s16(index * 2, int(clampf(value * envelope, -0.95, 0.95) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream
