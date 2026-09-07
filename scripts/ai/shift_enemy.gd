extends RefCounted
## Enemy knowledge is acquired only through sight, sound and camera exposure.
var game: Node3D
var director: Node
var states: Dictionary = {}

func reset() -> void:
	states.clear()
	for index in range(game.robots.size()):
		var robot: CharacterBody3D = game.robots[index]
		robot.position = Vector3(-5.55 if index == 0 else 5.55, 1.0, -61)
		robot.velocity = Vector3.ZERO
		robot.visible = true
		var damage := robot.find_child("DestructibleComponent",true,false)
		if damage:
			damage.configure(damage.profile)
		for mesh in robot.find_children("*","MeshInstance3D",true,false):
			if not mesh.get_meta("hidden_by_generated_asset",false):
				mesh.show()
		# Imported GLB collision bodies must not form a second unmoving robot shell.
		for imported in robot.find_children("*", "PhysicsBody3D", true, false):
			imported.collision_layer = 0
			imported.collision_mask = 0
		robot.set_meta("stun", 0.0)
		robot.set_meta("attack_cd", 0.0)
		states[robot] = {"state":"IDLE", "memory":0.0, "last":robot.position, "goal":robot.position, "clock":0.0, "path":[], "step":0, "cooldown":0.0, "observed":0.0, "patrol":index * 3, "animation":""}

func hear(at: Vector3, radius: float) -> void:
	for robot: CharacterBody3D in states:
		if robot.position.distance_to(at) <= radius:
			states[robot]["last"] = at
			states[robot]["memory"] = 7.0
			states[robot]["state"] = "INVESTIGATE"
			states[robot]["clock"] = 0.0

func update(delta: float) -> void:
	for robot: CharacterBody3D in states:
		if not is_instance_valid(robot):
			continue
		var s: Dictionary = states[robot]
		var component := robot.find_child("DestructibleComponent", true, false)
		if component and bool(component.get("disabled")):
			_transition(robot, s, "SHUTDOWN", "Shutdown")
			continue
		if director.night_time < (30.0 if game.current_round == 1 else 8.0):
			_transition(robot, s, "IDLE", "Head scan")
			continue
		s["cooldown"] = maxf(0, float(s["cooldown"]) - delta)
		var stunned := maxf(0, float(robot.get_meta("stun", 0.0)) - delta)
		robot.set_meta("stun", stunned)
		if stunned > 0:
			_transition(robot, s, "DAMAGED", "Knockdown" if stunned > 1.2 else "Hit reaction")
			continue
		var distance := robot.position.distance_to(game.player.position)
		var sees := _sees_player(robot)
		s["memory"] = maxf(0, float(s["memory"]) - delta)
		if sees:
			s["last"] = game.player.position
			s["memory"] = 10.0
			s["state"] = "CHASE" if game.current_round > 1 or director.night_time > 95 else "STALK"
		var observed: bool = game.fnaf_surveillance_v21.is_robot_observed(robot)
		if observed:
			s["observed"] = float(s["observed"]) + delta
		if observed and robot == game.robots[0] and (game.current_round < 4 or float(s["observed"]) < 3.0):
			_transition(robot, s, "HIDE", "Head scan")
			robot.velocity = Vector3.ZERO
			continue
		if sees and distance < 1.5 and float(s["cooldown"]) <= 0:
			_transition(robot, s, "ATTACK", "Attack")
			s["cooldown"] = 2.3
			game._hurt_player(8.0 + game.current_round, "Une pince heurte votre épaule. Reculez vers une porte.")
			director.sound.emit("Impact", robot.position, 3)
			continue
		if float(s["cooldown"]) > 1.65:
			continue
		s["clock"] = float(s["clock"]) - delta
		if float(s["clock"]) <= 0:
			s["clock"] = 0.8
			var goal: Vector3 = s["last"]
			if float(s["memory"]) <= 0:
				var patrol := ["W3", "W2", "W1", "WL", "NW", "NE", "E3", "E2", "E1", "ER", "R1", "RELAY"]
				if robot.position.distance_to(s["goal"]) < 1.3:
					s["patrol"] = (int(s["patrol"]) + 1) % patrol.size()
				goal = director.navigation.points[patrol[int(s["patrol"])]]
				s["state"] = "PATROL"
			else:
				s["state"] = "CHASE" if sees else "SEARCH"
			s["goal"] = goal
			s["path"] = director.navigation.path(robot.position, goal, false)
			s["step"] = 1 if (s["path"] as Array).size() > 1 else 0
		var route: Array = s["path"]
		while int(s["step"]) < route.size() and robot.position.distance_to(route[int(s["step"])]) < 0.85:
			s["step"] = int(s["step"]) + 1
		var target: Vector3 = route[int(s["step"])] if int(s["step"]) < route.size() else robot.position
		var direction := target - robot.position
		direction.y = 0
		var speed: float = 2.5 + game.current_round * 0.16 if sees else 1.6
		var mode: String = game._robot_movement_mode(robot)
		speed *= game._robot_damage_speed(robot)
		if mode == "crawl":
			speed = minf(speed, 1.2)
		var clip := "Crawl-loop" if mode == "crawl" else ("Run-loop" if sees else "Walk-loop")
		if speed < 1.5 and mode != "crawl":
			clip = "Limp"
		if direction.length() > 0.1:
			robot.velocity.x = direction.normalized().x * speed
			robot.velocity.z = direction.normalized().z * speed
			robot.rotation.y = lerp_angle(robot.rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 5))
			robot.velocity.y -= delta * 18
			robot.move_and_slide()
			_transition(robot, s, String(s["state"]), clip)
			for index in range(robot.get_slide_collision_count()):
				var hit := robot.get_slide_collision(index).get_collider() as Node
				if hit is RigidBody3D and float(s["cooldown"]) <= 0:
					(hit as RigidBody3D).apply_central_impulse(direction.normalized() * 7)
					_transition(robot, s, "ATTACK", "Door interaction")
					director.sound.emit("Impact", robot.position)
					s["cooldown"] = 1.4
				if hit and (hit.get_meta("facility_door", false) or hit.get_meta("fnaf_shutter", false)) and float(s["cooldown"]) <= 0:
					_transition(robot, s, "ATTACK", "Door interaction")
					director.sound.emit("DoorHit", robot.position, 4)
					s["cooldown"] = 2.5
					if hit.has_method("take_hit"):
						hit.take_hit(15.0)
					else:
						game.fnaf_surveillance_v21.power = maxf(0, game.fnaf_surveillance_v21.power - 1.0)
		else:
			_transition(robot, s, "LISTEN", "Head scan")
		robot.set_meta("ai_state", s["state"])

func _sees_player(robot: CharacterBody3D) -> bool:
	var difference: Vector3 = game.player.position - robot.position
	if difference.length() > 23 or not game._robot_detection_enabled(robot):
		return false
	if difference.length() > 3 and (-robot.transform.basis.z).dot(difference.normalized()) < 0.25:
		return false
	var query := PhysicsRayQueryParameters3D.create(robot.position + Vector3.UP * 0.5, game.player.position + Vector3.UP * 0.35, 1, [robot.get_rid()])
	var result := game.get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result["collider"] == game.player

func _transition(robot: CharacterBody3D, state: Dictionary, name_value: String, clip: String) -> void:
	state["state"] = name_value
	robot.set_meta("ai_state", name_value)
	if String(state["animation"]) != clip:
		state["animation"] = clip
		game._set_robot_animation(robot, clip)
