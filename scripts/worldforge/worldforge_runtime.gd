extends Node

const GeneratorScript := preload("res://scripts/worldforge/procedural_layout_generator.gd")
const AuditAgentScript := preload("res://scripts/worldforge/spatial_audit_agent.gd")
const RepairAgentScript := preload("res://scripts/worldforge/autofix_agent.gd")
const DeveloperEditorScript := preload("res://scripts/worldforge/developer_editor.gd")
const EventDirectorScript := preload("res://scripts/worldforge/world_event_director.gd")

var generator: WorldForgeProceduralGenerator
var audit_agent: WorldForgeSpatialAuditAgent
var repair_agent: WorldForgeAutoRepairAgent
var developer_editor: WorldForgeDeveloperEditor
var event_director: WorldForgeEventDirector
var scene_root: Node3D
var current_seed := 0
var last_manifest: Dictionary = {}
var last_report: Dictionary = {}
var last_repair: Dictionary = {}
var developer_mode := false
var _scene_instance_id := 0
var _bootstrap_pending := false
var _ui_state := ""
var _audit_elapsed := 0.0

func _ready() -> void:
	name = "WorldForgeRuntime"
	process_mode = Node.PROCESS_MODE_ALWAYS
	developer_mode = _detect_developer_mode()
	generator = GeneratorScript.new()
	audit_agent = AuditAgentScript.new()
	repair_agent = RepairAgentScript.new()
	call_deferred("_schedule_bootstrap")

func _process(delta: float) -> void:
	var current := get_tree().current_scene
	var current_id := current.get_instance_id() if current != null else 0
	if current_id != _scene_instance_id and not _bootstrap_pending:
		_schedule_bootstrap()
	if scene_root != null and is_instance_valid(scene_root):
		_maintain_start_ui()
		if developer_mode:
			_audit_elapsed += delta
			if _audit_elapsed >= 20.0:
				_audit_elapsed = 0.0
				run_audit(false)

func _schedule_bootstrap() -> void:
	if _bootstrap_pending:
		return
	_bootstrap_pending = true
	call_deferred("_bootstrap_current_scene")

func _bootstrap_current_scene() -> void:
	var observed_scene := get_tree().current_scene
	var observed_id := observed_scene.get_instance_id() if observed_scene != null else 0
	var resolved_root: Node3D = null
	for _frame in range(240):
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current == null:
			continue
		observed_id = current.get_instance_id()
		if current is Node3D and current.find_child("Player", true, false) != null:
			var boot_overlay := current.find_child("BootOverlay", true, false)
			if boot_overlay == null:
				resolved_root = current as Node3D
				break
	_bootstrap_pending = false
	_scene_instance_id = observed_id
	if resolved_root == null:
		scene_root = null
		return
	_scene_instance_id = resolved_root.get_instance_id()
	scene_root = resolved_root
	_cleanup_scene_services()
	current_seed = _new_launch_seed()
	last_manifest = generator.generate(scene_root, current_seed)
	await get_tree().process_frame
	var result := run_audit(true)
	last_report = result.get("report", {}) as Dictionary
	last_repair = result.get("repair", {}) as Dictionary
	_save_json("user://worldforge/last_manifest.json", last_manifest)
	_save_json("user://worldforge/last_audit.json", last_report)
	_save_json("user://worldforge/last_repair.json", last_repair)
	_setup_event_director()
	_setup_developer_editor()
	print("WORLDFORGE_READY seed=%d modules=%d issues=%d repairs=%d" % [
		current_seed,
		(last_manifest.get("modules", []) as Array).size(),
		(last_report.get("issues", []) as Array).size(),
		int(last_repair.get("action_count", 0))
	])

func regenerate(seed_value: int) -> Dictionary:
	if scene_root == null or not is_instance_valid(scene_root):
		return {"error": "scene_unavailable", "report": {}, "repair": {}}
	current_seed = seed_value if seed_value != 0 else _new_launch_seed()
	last_manifest = generator.generate(scene_root, current_seed)
	_setup_event_director()
	var result := run_audit(true)
	_save_json("user://worldforge/last_manifest.json", last_manifest)
	_save_json("user://worldforge/last_audit.json", result.get("report", {}))
	_save_json("user://worldforge/last_repair.json", result.get("repair", {}))
	return result

func run_audit(auto_fix := false) -> Dictionary:
	if scene_root == null or not is_instance_valid(scene_root):
		return {"error": "scene_unavailable", "report": {}, "repair": {}}
	last_report = audit_agent.audit(scene_root)
	last_repair = {}
	if auto_fix:
		last_repair = repair_agent.repair(scene_root, last_report)
		call_deferred("_post_repair_audit")
	_save_json("user://worldforge/last_audit.json", last_report)
	if auto_fix:
		_save_json("user://worldforge/last_repair.json", last_repair)
	return {"report": last_report.duplicate(true), "repair": last_repair.duplicate(true)}

func _post_repair_audit() -> void:
	if scene_root == null or not is_instance_valid(scene_root):
		return
	last_report = audit_agent.audit(scene_root)
	_save_json("user://worldforge/last_audit.json", last_report)

func save_snapshot() -> String:
	var directory := "user://worldforge/snapshots"
	_ensure_directory(directory)
	var path := "%s/world_%d_%d.json" % [directory, current_seed, int(Time.get_unix_time_from_system())]
	_save_json(path, {
		"schema_version": 1,
		"seed": current_seed,
		"manifest": last_manifest,
		"audit": last_report,
		"repair": last_repair,
		"developer_mode": developer_mode
	})
	return path

func get_current_seed() -> int:
	return current_seed

func get_manifest() -> Dictionary:
	return last_manifest.duplicate(true)

func get_last_report() -> Dictionary:
	return last_report.duplicate(true)

func is_developer_mode() -> bool:
	return developer_mode

func set_developer_mode(enabled: bool) -> void:
	developer_mode = enabled
	if developer_mode:
		_setup_developer_editor()
	elif developer_editor != null:
		developer_editor.visible = false

func _setup_event_director() -> void:
	if scene_root == null:
		return
	if event_director != null and is_instance_valid(event_director):
		event_director.queue_free()
	event_director = EventDirectorScript.new()
	event_director.name = "WorldForgeEventDirector"
	add_child(event_director)
	event_director.configure(scene_root, current_seed)

func _setup_developer_editor() -> void:
	if not developer_mode or scene_root == null:
		return
	if developer_editor != null and is_instance_valid(developer_editor):
		developer_editor.scene_root = scene_root
		developer_editor.call_deferred("_refresh_lists")
		return
	developer_editor = DeveloperEditorScript.new()
	add_child(developer_editor)
	developer_editor.configure(self, scene_root)

func _cleanup_scene_services() -> void:
	_ui_state = ""
	_audit_elapsed = 0.0
	if event_director != null and is_instance_valid(event_director):
		event_director.queue_free()
		event_director = null
	if developer_editor != null and is_instance_valid(developer_editor):
		developer_editor.queue_free()
		developer_editor = null

func _maintain_start_ui() -> void:
	var panel_value = scene_root.get("start_panel")
	if not panel_value is Control:
		return
	var panel := panel_value as Control
	var intro_value = scene_root.get("intro_panel")
	var intro_visible := intro_value is Control and (intro_value as Control).visible
	var game_started_value = scene_root.get("game_started")
	var game_started := bool(game_started_value) if game_started_value != null else false
	var state := "game"
	if not game_started and intro_visible:
		state = "intro"
	elif not game_started and panel.visible:
		state = "menu"
	if state == _ui_state:
		return
	_ui_state = state
	var synthetic_report := {
		"issues": [{
			"severity": "high",
			"code": "start_panel_behind_hud",
			"node_path": str(panel.get_path()),
			"node_name": panel.name,
			"message": "Synchronisation de la couche UI sûre.",
			"details": {}
		}]
	}
	repair_agent.repair(scene_root, synthetic_report)

func _new_launch_seed() -> int:
	var installation_id := _load_or_create_installation_id()
	var current_scene_path := "runtime"
	if get_tree().current_scene != null:
		current_scene_path = get_tree().current_scene.scene_file_path
	var source := "%s|%d|%d|%s" % [
		installation_id,
		int(Time.get_unix_time_from_system() * 1000.0),
		Time.get_ticks_usec(),
		current_scene_path
	]
	var seed_value := abs(hash(source))
	return seed_value if seed_value != 0 else 19870922

func _load_or_create_installation_id() -> String:
	var path := "user://worldforge/installation_id.txt"
	if FileAccess.file_exists(path):
		var existing := FileAccess.open(path, FileAccess.READ)
		if existing != null:
			var existing_value := existing.get_as_text().strip_edges()
			if not existing_value.is_empty():
				return existing_value
	_ensure_directory("user://worldforge")
	var new_value := "%d-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), randi()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(new_value)
	return new_value

func _detect_developer_mode() -> bool:
	if bool(ProjectSettings.get_setting("blackout/worldforge/developer_tools", false)):
		return true
	if OS.is_debug_build() or FileAccess.file_exists("user://worldforge_dev.flag"):
		return true
	if OS.has_feature("web"):
		var query_value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('dev')", true)
		return String(query_value) in ["1", "true", "worldforge"]
	return false

func _save_json(path: String, data: Variant) -> void:
	_ensure_directory(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t", false))

func _ensure_directory(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute)
