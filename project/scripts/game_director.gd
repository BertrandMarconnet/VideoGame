class_name GameDirector
extends Node

signal objective_changed(text: String)
signal phase_changed(text: String)
signal status_message(text: String)
signal mission_complete(success: bool, summary: String)
signal fear_profile_changed(profile: String)

var player: PlayerController
var factory: FactoryGenerator
var robots: Array[RobotAgent] = []
var elapsed := 0.0
var phase := 0
var briefing_done := false
var relay_a := false
var black_box := false
var relay_b := false
var uplink_started := false
var uplink_time := 0.0
var fear_profile := "observation"
var fear_timer := 0.0
var haunt_timer := 18.0
var secondary_index := -1

func configure(player_node: PlayerController, world_factory: FactoryGenerator, robot_nodes: Array[RobotAgent]) -> void:
	player = player_node
	factory = world_factory
	robots = robot_nodes
	factory.console_activated.connect(_on_console)
	factory.structure_changed.connect(func(text: String): status_message.emit(text))
	player.died.connect(func(): mission_complete.emit(false, "Le technicien a été neutralisé."))
	for robot in robots:
		robot.set_active(false)
	objective_changed.emit("Consultez l'écran de ronde dans S-01.")
	phase_changed.emit("PHASE 0 — CALIBRATION")

func _process(delta: float) -> void:
	elapsed += delta
	fear_timer += delta
	haunt_timer -= delta
	if fear_timer >= 5.0:
		fear_timer = 0.0
		_update_fear_profile()
	if haunt_timer <= 0.0 and briefing_done and not uplink_started:
		haunt_timer = randf_range(14.0, 28.0)
		_trigger_haunt()
	if uplink_started:
		uplink_time -= delta
		objective_changed.emit("Transmission Blackout : %.0f s — survivez dans S-01." % maxf(0.0, uplink_time))
		if uplink_time <= 0.0:
			uplink_started = false
			mission_complete.emit(true, "Protocole Blackout transmis. Les unités perdent leur réseau de coordination.")

func _on_console(id_value: String) -> void:
	match id_value:
		"briefing":
			if briefing_done:
				status_message.emit("Ordre actif : récupérer l'enregistreur et restaurer les relais.")
				return
			briefing_done = true
			phase = 1
			robots[0].set_active(true, false)
			phase_changed.emit("PHASE 1 — OBSERVATION")
			objective_changed.emit("Traversez la logistique et réparez le relais A.")
			status_message.emit("Une signature optique demeure immobile hors du champ des caméras.")
		"relay_a":
			if not briefing_done:
				status_message.emit("Consultez d'abord le centre de contrôle.")
				return
			relay_a = true
			objective_changed.emit("Atteignez les archives et récupérez l'enregistreur noir.")
			status_message.emit("Relais A restauré. Activité mécanique détectée dans l'assemblage.")
		"black_box":
			if not relay_a:
				status_message.emit("Le verrou des archives dépend du relais A.")
				return
			black_box = true
			phase = 2
			_choose_secondary_robot()
			phase_changed.emit("PHASE 2 — INFILTRATION")
			objective_changed.emit("Descendez à la fonderie et restaurez le relais B.")
			status_message.emit("L'enregistreur contient des traces d'apprentissage comportemental.")
		"relay_b":
			if not black_box:
				status_message.emit("Récupérez d'abord l'enregistreur noir.")
				return
			relay_b = true
			phase = 3
			robots[0].set_lethal(true)
			if secondary_index >= 0:
				robots[secondary_index].set_lethal(true)
			phase_changed.emit("PHASE 3 — RETOUR")
			objective_changed.emit("Revenez à S-01 et lancez l'uplink Blackout.")
			status_message.emit("Les unités ont compris votre trajet de retour.")
		"uplink":
			if not (relay_a and black_box and relay_b):
				status_message.emit("Uplink refusé : relais A, enregistreur et relais B requis.")
				return
			if uplink_started:
				return
			uplink_started = true
			uplink_time = 35.0
			phase = 4
			phase_changed.emit("PHASE 4 — SIÈGE S-01")
			for i in range(robots.size()):
				robots[i].set_active(true, true)
			status_message.emit("Transmission engagée. Les unités convergent vers le centre de contrôle.")
		"door_control":
			status_message.emit("Porte S-01 : verrouillage hydraulique stable. Les parois restent destructibles.")

func _choose_secondary_robot() -> void:
	secondary_index = 2 if fear_profile == "bruit" else 1
	robots[secondary_index].set_active(true, false)
	status_message.emit("Une seconde unité s'adapte au profil de peur : %s." % fear_profile)

func _update_fear_profile() -> void:
	var data := player.get_behavior_snapshot()
	var new_profile := "observation"
	if float(data["abrupt_turn_score"]) > 0.28:
		new_profile = "surveillance"
	elif float(data["sprint_time"]) > elapsed * 0.22:
		new_profile = "poursuite"
	elif int(data["flashlight_toggles"]) > 7:
		new_profile = "obscurite"
	elif float(data["speed"]) < 0.15 and elapsed > 45.0:
		new_profile = "bruit"
	if new_profile != fear_profile:
		fear_profile = new_profile
		fear_profile_changed.emit(fear_profile)

func _trigger_haunt() -> void:
	match fear_profile:
		"obscurite":
			status_message.emit("Microcoupure : une silhouette apparaît dans la lumière de secours.")
			player.flashlight.visible = false
			await get_tree().create_timer(0.45).timeout
			player.flashlight.visible = player.flashlight_on
		"surveillance":
			status_message.emit("Un reflet rouge disparaît au bord de votre champ de vision.")
		"poursuite":
			status_message.emit("Des pas accélèrent dans un couloir parallèle, puis s'arrêtent.")
		"bruit":
			status_message.emit("Une voix de maintenance imite votre dernier ordre depuis les archives.")
		_:
			status_message.emit("Les bras d'assemblage se réorientent sans ordre de production.")

func get_mission_state() -> Dictionary:
	return {
		"briefing": briefing_done,
		"relay_a": relay_a,
		"black_box": black_box,
		"relay_b": relay_b,
		"uplink": uplink_started,
		"fear": fear_profile,
		"phase": phase
	}
