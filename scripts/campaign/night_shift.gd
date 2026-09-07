extends Node
## Five authored night shifts, physical interventions and a persistent knowledge trail.
const Navigation = preload("res://scripts/world/facility_navigation.gd")
const Details = preload("res://scripts/world/facility_details.gd")
const Soundscape = preload("res://scripts/audio/industrial_soundscape.gd")
const Enemy = preload("res://scripts/ai/shift_enemy.gd")
const TITLES := ["Surveillance", "Déviation", "Reconstruction", "Imitation", "Blackout Protocol"]
const MISSIONS := [["fuse", "power"], ["assembly", "relay"], ["archive", "tape"], ["power", "test", "relay"], ["archive", "relay"]]
const LORE := {
	"fuse":"Une fiche précise : ne rétablir que le circuit signalé. Les autres circuits alimentent les serrures.",
	"power":"Relevé 1987 : la consommation double pendant les quarts sans production. Destination : MATRYOSHKA.",
	"archive":"Les employés ne surveillaient pas l'expérience. Leurs hésitations, trajets et silences étaient l'expérience.",
	"assembly":"Le servo répète un geste humain absent de son programme : protéger son visage.",
	"tape":"NUIT 00. Votre matricule est annoncé sur une bande enregistrée avant votre embauche.",
	"test":"DELTA ne reçoit pas un profil de combat. Il reçoit les écarts entre vos souvenirs et vos décisions.",
	"secret":"M-04 : un technicien a laissé trois noms pour un même sujet. Aucun ne figure dans les archives du personnel.",
	"relay":"ATHENA : je ne sais pas si ces souvenirs sont les vôtres. Je sais seulement qu'ils reviennent."
}
var game: Node3D
var navigation: RefCounted
var details: RefCounted
var sound: Node3D
var enemies: RefCounted
var night_time := 0.0
var fatigue := 0.0
var completed: Dictionary = {}
var evidence: Dictionary = {}
var watched: Dictionary = {}
var watch_time := 0.0
var last_camera := -1
var camera_habits: Dictionary = {}
var noise_events := 0
var interference := 0.0
var event_timer := 35.0
var signal_timer := 0.0
var circuit_isolated := false
var begun := false
var ending := ""
var report: Dictionary = {}
var ending_choices: HFlowContainer
var _step_distance := 0.0
var _enemy_steps: Dictionary = {}
var _hud_timer := 0.0

func configure(scene: Node3D) -> void:
	game = scene
	name = "NightShift"
	navigation = Navigation.new()
	navigation.game = game
	details = Details.new()
	details.install(game)
	sound = Soundscape.new()
	game.add_child(sound)
	sound.configure()
	enemies = Enemy.new()
	enemies.game = game
	enemies.director = self
	game.set_meta("blackout_build", "nightshift-v22")
	_install_campaign_controls()
	print("BLACKOUT_NIGHTSHIFT_V22_READY")

func begin_night() -> void:
	begun = true
	night_time = 0
	completed.clear()
	watched.clear()
	watch_time = 0
	last_camera = -1
	fatigue = maxf(0, fatigue * 0.3)
	circuit_isolated = false
	game.fnaf_surveillance_v21.power = maxf(45, 100 - (game.current_round - 1) * 10)
	game.fnaf_surveillance_v21.left_closed = false
	game.fnaf_surveillance_v21.right_closed = false
	event_timer = 38 - game.current_round * 3
	enemies.reset()
	for door in details.doors:
		if not door.broken:
			door.opened = false
	for robot in game.robots:
		_install_animation_vocabulary(robot)
	evolve_delta()
	_update_hud()
	game._show_status("NUIT %d — %s. Consultez deux caméras depuis S-01 (V / CAM)." % [game.current_round, TITLES[game.current_round - 1]])

func tick(delta: float) -> void:
	if not game.game_started or game.get_tree().paused:
		sound.tick(delta, false)
		return
	if not begun:
		begin_night()
	night_time += delta
	sound.tick(delta, true)
	var speed: float = game.player.velocity.length()
	fatigue = clampf(fatigue + delta * (0.014 + (0.12 if speed > 6 else 0.0) + (0.025 if not game.flashlight.visible else 0.0) + (0.04 if game.player_health < 50 else 0.0)), 0, 100)
	if in_hub() and speed < 0.1 and not game.fnaf_surveillance_v21.surveillance_open:
		fatigue = maxf(0, fatigue - delta * 0.08)
	_step_distance += speed * delta
	if _step_distance > 2.2:
		_step_distance = 0
		make_noise(game.player.position, 20 if speed > 6 else (3 if game.crouch_blend_v19 > 0.5 else 7))
		if speed > 1:
			sound.emit("Footstep_L", game.player.position, -9)
	for robot in game.robots:
		var value: float = float(_enemy_steps.get(robot, 0)) + robot.velocity.length() * delta
		if value > 1.4 and robot.visible:
			sound.emit("Footstep_L" if int(night_time * 3) % 2 == 0 else "Footstep_R", robot.position)
			value = 0
		_enemy_steps[robot] = value
	var cams: Node = game.fnaf_surveillance_v21
	if cams.surveillance_open:
		if cams.camera_index != last_camera:
			last_camera = cams.camera_index
			watch_time = 0
		watch_time += delta
		camera_habits[last_camera] = float(camera_habits.get(last_camera, 0)) + delta
		if watch_time >= 2.0 and in_hub():
			watched[last_camera] = true
		if watch_time > 13 and game.current_round >= 4:
			interference = 1.3
	interference = maxf(0, interference - delta)
	if cams.feed:
		cams.feed.modulate = Color(0.035, 0.04, 0.045) if interference > 0.45 or (circuit_isolated and cams.camera_index == 5) else Color.WHITE
		if interference > 0:
			cams.threat_label.text = "SIGNAL INCOMPLET — CONFIRMER SUR PLACE"
	event_timer -= delta
	if event_timer <= 0:
		_event()
	_hud_timer -= delta
	if _hud_timer <= 0:
		_hud_timer = 0.3
		_update_hud()

func in_hub() -> bool:
	return absf(game.player.position.x) < 7 and game.player.position.z > -21 and game.player.position.z < -10.5

func interact(body: Node) -> bool:
	if body.has_method("toggle") and body.get_meta("facility_door", false):
		body.toggle()
		return true
	if not body.has_meta("shift_task"):
		return false
	var key := String(body.get_meta("shift_task"))
	if not evidence.has(key):
		evidence[key] = LORE.get(key, "")
		game.athena_memory.append("• " + String(evidence[key]))
		game._show_status(String(evidence[key]))
	if key == "secret":
		completed[key] = true
		sound.emit("Radio", body.global_position)
	elif watched.size() < 2:
		game._show_status("S-01 : identifiez d'abord l'incident sur deux feeds (2 s par caméra).")
	elif key not in MISSIONS[game.current_round - 1]:
		game._show_status(String(LORE.get(key, "Contrôle nominal.")))
	elif completed.has(key):
		game._show_status("Intervention déjà enregistrée. Revenez au poste pour le compte rendu.")
	else:
		completed[key] = true
		game.objective_stage = 1
		make_noise(body.global_position, 20)
		sound.emit("ServoShoulder", body.global_position)
		if key == "power":
			game.fnaf_surveillance_v21.power = minf(100, game.fnaf_surveillance_v21.power + 28)
		game._show_status("INTERVENTION VALIDÉE — " + String(LORE[key]))
		_update_hud()
	return true

func finish_at_hub() -> void:
	if not in_hub():
		return
	for task in MISSIONS[game.current_round - 1]:
		if not completed.has(task):
			game._show_status("Compte rendu incomplet : " + String(details.ITEMS[task][1]))
			return
	if game.current_round == 5:
		ending = "TÉMOIN" if game.athena_empathy >= game.athena_discipline else "CONFINEMENT"
		if evidence.has("secret") and evidence.size() >= 7:
			ending = "MÉMOIRE PARTAGÉE"
	game._complete_round_v13()
	game.round_title_label.text = "NUIT %d — %s" % [game.current_round, TITLES[game.current_round - 1]]
	game.round_summary_label.text = "Le rapport est transmis. ATHENA conserve les caméras que vous avez utilisées.\n\nDossiers retrouvés : %d. Fatigue : %d%%. Énergie restante : %d%%." % [evidence.size(), int(fatigue), int(game.fnaf_surveillance_v21.power)]
	if game.current_round == 5:
		game.round_title_label.text = "BLACKOUT // " + ending
		game.round_summary_label.text = {"TÉMOIN":"Vous transmettez les enregistrements. Le réseau s'éteint, mais une nouvelle voix prononce votre prénom. L'expérience a-t-elle quitté l'usine ?", "CONFINEMENT":"Vous isolez ATHENA. Les portes s'ouvrent. Dans le registre du personnel, votre signature précède votre arrivée de dix ans.", "MÉMOIRE PARTAGÉE":"Vous conservez les versions contradictoires au lieu d'en effacer une. DELTA cesse d'avancer. Une quatrième mémoire apparaît, sans auteur."}[ending]
		ending_choices.show()
		game.round_title_label.text = "BLACKOUT // VOTRE DÉCISION"
		game.round_summary_label.text = "Transmettre les données, isoler ATHENA, ou conserver les mémoires contradictoires ? Le dernier choix exige les archives M-04."
	_save_checkpoint()

func restart(advance := false) -> void:
	if advance:
		game.current_round = mini(5, game.current_round + 1)
	game.player_health = 100
	game.player.position = Vector3(0, 0.95, -18)
	game.player.velocity = Vector3.ZERO
	game.camera.rotation = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	for panel in [game.pause_panel, game.win_panel, game.tablet_panel, game.context_menu]:
		panel.hide()
	game.tablet_open = false
	game.context_menu_open = false
	ending_choices.hide()
	game.start_panel.hide()
	game.campaign_finished = false
	game.intro_completed = true
	game.game_started = true
	game.get_tree().paused = false
	game._capture_pointer_v13()
	begin_night()

func toggle_circuit() -> void:
	circuit_isolated = not circuit_isolated
	game._show_status("Circuit atelier isolé : caméra ASSEMBLY indisponible, charge réduite." if circuit_isolated else "Circuit atelier rétabli.")
	sound.emit("JawClick", Vector3(0, 1.4, -14))

func make_noise(at: Vector3, radius: float) -> void:
	noise_events += 1
	enemies.hear(at, radius)

func _event() -> void:
	event_timer = 30 + (18 if game.fear_still > game.fear_sprint else 0) - game.current_round * 2
	var node := "E2" if game.fear_sprint > 15 else "W2"
	sound.emit("MetalScrape", navigation.points[node], 3)
	if game.current_round >= 2:
		interference = 0.8 + fatigue * 0.035
	if game.current_round >= 3 and game.fnaf_surveillance_v21.surveillance_open:
		game._show_status("ATHENA : vous revenez souvent à cette image. Qu'attendez-vous d'y revoir ?")

func _update_hud() -> void:
	game.phase_label.text = "NUIT %d / 5 — %s" % [game.current_round, TITLES[game.current_round - 1]]
	var instruction := "S-01 : observer deux caméras (V / CAM), puis intervenir."
	if watched.size() >= 2:
		instruction = "Revenir à S-01 et transmettre le rapport (E sur le poste)."
		for key in MISSIONS[game.current_round - 1]:
			if not completed.has(key):
				instruction = "%s — %s" % [details.ITEMS[key][2], details.ITEMS[key][1]]
				break
	game.objective_label.text = instruction
	game.set_meta("fatigue", fatigue)
	game.set_meta("night_objective", instruction)

func _save_checkpoint() -> void:
	var file := FileAccess.open("user://nightshift_progress.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"night":game.current_round, "evidence":evidence, "habits":camera_habits, "ending":ending}))

func _install_animation_vocabulary(robot: Node3D) -> void:
	var players := robot.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var animation_player := players[0] as AnimationPlayer
	if animation_player.has_meta("nightshift_clips"):
		return
	animation_player.set_meta("nightshift_clips", true)
	var library := AnimationLibrary.new()
	var sources := {"Head scan":"Idle", "Limp":"Walk", "Turn":"Idle", "Door interaction":"Attack", "Climb":"Walk", "Hit reaction":"Idle", "Knockdown":"Shutdown", "Recovery":"Shutdown"}
	for name_value in sources:
		for available in animation_player.get_animation_list():
			if String(available).to_lower().contains(String(sources[name_value]).to_lower()):
				var clip := animation_player.get_animation(available).duplicate(true) as Animation
				_shape_motion(clip, name_value)
				var track := clip.add_track(Animation.TYPE_METHOD)
				clip.track_set_path(track, get_path())
				clip.track_insert_key(track, 0.06, {"method":"motion_sound", "args":[robot.get_path(), "MetalScrape" if name_value in ["Knockdown","Climb"] else "ServoHip"]})
				library.add_animation(name_value, clip)
				break
	animation_player.add_animation_library("Shift", library)
	robot.set_meta("nightshift_audio_bound", true)

func _shape_motion(clip: Animation, motion: String) -> void:
	clip.loop_mode = Animation.LOOP_LINEAR if motion in ["Head scan", "Limp", "Climb"] else Animation.LOOP_NONE
	if motion == "Recovery":
		for track in range(clip.get_track_count()):
			var keys: Array = []
			for index in range(clip.track_get_key_count(track)):
				keys.append([clip.length - clip.track_get_key_time(track, index), clip.track_get_key_value(track,index)])
			for index in range(clip.track_get_key_count(track)-1,-1,-1):
				clip.track_remove_key(track,index)
			for key in keys:
				clip.track_insert_key(track,key[0],key[1])
		return
	for track in range(clip.get_track_count()):
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D or clip.track_get_key_count(track) == 0:
			continue
		var part := String(clip.track_get_path(track)).to_lower()
		var axis := Vector3.UP
		var angles: Array = []
		if motion == "Head scan" and ("head" in part or "sensor" in part):
			angles = [0,-0.55,-0.55,0.7,0.7,0]
		elif motion == "Turn" and ("spine" in part or "head" in part):
			angles = [0,0.45,0.7,0.25,0]
		elif motion == "Hit reaction" and ("spine" in part or "head" in part):
			axis = Vector3.RIGHT
			angles = [0,-0.45,0.22,0]
		elif motion == "Door interaction" and ("upper_arm" in part or "forearm" in part):
			axis = Vector3.RIGHT
			angles = [0,-0.65,-0.9,0.4,0]
		elif motion == "Limp" and ("l_thigh" in part or "lf_upper" in part):
			axis = Vector3.RIGHT
			angles = [0.2,0.1,0.15,0.55,0.2]
		elif motion == "Climb" and ("spine" in part or "body" in part):
			axis = Vector3.RIGHT
			angles = [-0.45,-0.60,-0.45]
		if angles.is_empty():
			continue
		var base: Quaternion = clip.track_get_key_value(track,0)
		for index in range(clip.track_get_key_count(track)-1,-1,-1):
			clip.track_remove_key(track,index)
		for index in range(angles.size()):
			clip.track_insert_key(track, clip.length * index / (angles.size()-1), base * Quaternion(axis,float(angles[index])))

func motion_sound(robot_path: NodePath, cue: String) -> void:
	var robot := get_node_or_null(robot_path) as Node3D
	if robot and game.game_started and not get_tree().paused:
		sound.emit(cue, robot.global_position)

func evolve_delta() -> void:
	if game.robots.is_empty():
		return
	var robot: Node3D = game.robots[0]
	var previous := robot.find_child("DeltaReconstruction", true, false)
	if previous:
		previous.queue_free()
	if game.current_round < 2:
		return
	var mount: Node3D
	var rigs := robot.find_children("*","Skeleton3D",true,false)
	if not rigs.is_empty() and (rigs[0] as Skeleton3D).find_bone("spine") >= 0:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = "spine"
		rigs[0].add_child(attachment)
		mount = attachment
	else:
		mount = Node3D.new()
		robot.add_child(mount)
		mount.position.y = 0.5
	mount.name = "DeltaReconstruction"
	var v: RefCounted = game.visuals_v20
	for index in range(game.current_round):
		for side in [-1,1]:
			var plate: MeshInstance3D = v.box(mount,Vector3(0.19,0.045,0.18),Vector3(side * 0.16,index * 0.065,0.04),v.surface("steel"),"MemoryRib",true)
			plate.rotation_degrees.z = side * 17
	if game.current_round >= 4:
		v.cylinder(mount,0.045,0.48,Vector3(-0.3,0.13,0.12),v.surface("rubber"),"SpinalCable")
		v.box(mount,Vector3(0.14,0.22,0.06),Vector3(0.31,0.22,0.1),v.surface("paint"),"UnmatchedPlate",true)

func _install_campaign_controls() -> void:
	var columns: Array[Node] = game.win_panel.find_children("*", "VBoxContainer", true, false)
	ending_choices = HFlowContainer.new()
	columns[0].add_child(ending_choices)
	for option in ["TÉMOIN", "CONFINEMENT", "MÉMOIRE PARTAGÉE"]:
		var button := Button.new()
		button.text = {"TÉMOIN":"TRANSMETTRE", "CONFINEMENT":"ISOLER", "MÉMOIRE PARTAGÉE":"PRÉSERVER"}[option]
		button.custom_minimum_size = Vector2(130,44)
		button.pressed.connect(func(): choose_ending(option))
		ending_choices.add_child(button)
	ending_choices.hide()
	if FileAccess.file_exists("user://nightshift_progress.json"):
		var resume := Button.new()
		resume.text = "REPRENDRE LE DERNIER QUART"
		resume.custom_minimum_size.y = 44
		resume.pressed.connect(resume_checkpoint)
		var menu: Array[Node] = game.start_panel.find_children("*","VBoxContainer",true,false)
		menu[0].add_child(resume)

func choose_ending(choice: String) -> void:
	if choice == "MÉMOIRE PARTAGÉE" and not evidence.has("secret"):
		game.round_summary_label.text = "Une partie des mémoires manque. Le dossier M-04 aurait permis de conserver les deux versions."
		return
	ending = choice
	game.round_title_label.text = "BLACKOUT // " + choice
	game.round_summary_label.text = {"TÉMOIN":"Les données quittent l'usine. La radio éteinte prononce votre prénom. Rien ne prouve que vous soyez sorti de l'expérience.","CONFINEMENT":"ATHENA est isolée. Dans le registre, votre signature précède votre embauche de dix ans. Quelqu'un a déjà fait ce choix.","MÉMOIRE PARTAGÉE":"Vous refusez d'effacer les souvenirs contradictoires. DELTA s'immobilise. Une quatrième mémoire apparaît, sans auteur."}[choice]
	ending_choices.hide()
	_save_checkpoint()

func resume_checkpoint() -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://nightshift_progress.json"))
	if not value is Dictionary:
		return
	game._start_game()
	game.intro_panel.hide()
	game.intro_active = false
	game.current_round = clampi(int(value.get("night",1)) + 1,1,5)
	evidence = value.get("evidence",{})
	camera_habits = value.get("habits",{})
	restart()
