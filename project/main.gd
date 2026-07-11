extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var robot: CharacterBody3D
var flashlight: SpotLight3D
var paused := false
var elapsed := 0.0
var left_touch := -1
var right_touch := -1
var left_origin := Vector2.ZERO
var touch_move := Vector2.ZERO

func _ready():
    _build_world()
    _build_ui()
    if not DisplayServer.is_touchscreen_available():
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_world():
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("081018")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("91b6c6")
    env.ambient_light_energy = 0.75
    env.fog_enabled = true
    env.fog_light_color = Color("172733")
    env.fog_density = 0.014
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.45
    world_env.environment = env
    add_child(world_env)

    var moon := DirectionalLight3D.new()
    moon.light_color = Color("a7d8ef")
    moon.light_energy = 0.9
    moon.rotation_degrees = Vector3(-55, -25, 0)
    add_child(moon)

    _box(Vector3(0,-0.5,-55), Vector3(30,1,120), Color("252b31"), true)
    for x in [-15.0,15.0]:
        _box(Vector3(x,4,-55), Vector3(1,9,120), Color("343b43"), true)
    for z in range(0,-111,-10):
        _box(Vector3(0,8,z), Vector3(30,0.35,0.8), Color("48525b"), false)
        var light := OmniLight3D.new()
        light.position = Vector3(0,6,z)
        light.light_color = Color("f5c57c")
        light.light_energy = 2.0
        light.omni_range = 13
        add_child(light)
    for z in range(-10,-100,-18):
        for x in [-8.0,8.0]:
            _box(Vector3(x,1.1,z), Vector3(5,2.2,3), Color("17232b"), true)
            _box(Vector3(x,2.4,z), Vector3(4.2,0.4,2.2), Color("9b6a2d"), false)
    for z in range(-15,-95,-20):
        for x in [-12.0,12.0]:
            _box(Vector3(x,2,z), Vector3(2,4,7), Color("37434c"), true)

    player = CharacterBody3D.new()
    player.position = Vector3(0,1.1,4)
    add_child(player)
    var player_col := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.45
    capsule.height = 1.8
    player_col.shape = capsule
    player.add_child(player_col)

    camera = Camera3D.new()
    camera.position = Vector3(0,0.65,0)
    player.add_child(camera)
    flashlight = SpotLight3D.new()
    flashlight.light_color = Color("d6ecff")
    flashlight.light_energy = 7.0
    flashlight.spot_range = 28
    flashlight.spot_angle = 35
    camera.add_child(flashlight)

    robot = CharacterBody3D.new()
    robot.position = Vector3(0,1.1,-74)
    add_child(robot)
    _robot_mesh(robot)

func _box(pos:Vector3,size:Vector3,color:Color,collision:bool):
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.45
    mat.roughness = 0.7
    mesh.material_override = mat
    add_child(mesh)
    if collision:
        var body := StaticBody3D.new()
        body.position = pos
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.add_child(shape_node)
        add_child(body)

func _robot_mesh(root:Node3D):
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color("6b747b")
    metal.metallic = 0.95
    metal.roughness = 0.28
    var parts = [
        [Vector3(0,1.15,0),Vector3(0.85,1.3,0.45)],
        [Vector3(0,2.15,0),Vector3(0.55,0.45,0.5)],
        [Vector3(-0.55,0.35,0),Vector3(0.25,1.4,0.25)],
        [Vector3(0.55,0.35,0),Vector3(0.25,1.4,0.25)],
        [Vector3(-0.75,1.1,0),Vector3(0.22,1.25,0.22)],
        [Vector3(0.75,1.1,0),Vector3(0.22,1.25,0.22)]
    ]
    for part in parts:
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = part[1]
        mi.mesh = bm
        mi.position = part[0]
        mi.material_override = metal
        root.add_child(mi)
    for x in [-0.16,0.16]:
        var eye := OmniLight3D.new()
        eye.position = Vector3(x,2.18,-0.25)
        eye.light_color = Color.RED
        eye.light_energy = 2.5
        eye.omni_range = 3
        root.add_child(eye)

func _build_ui():
    var layer := CanvasLayer.new()
    layer.name = "UI"
    add_child(layer)
    var title := Label.new()
    title.text = "BLACKOUT PROTOCOL // STEEL ECHO"
    title.position = Vector2(18,16)
    title.add_theme_font_size_override("font_size",18)
    layer.add_child(title)
    var info := Label.new()
    info.text = "Ronde de maintenance : traversez l'usine.\nLe robot s'active après 35 secondes.\nPC : ZQSD/WASD, souris, F, Espace, Échap."
    info.position = Vector2(18,48)
    layer.add_child(info)
    var pause_panel := ColorRect.new()
    pause_panel.name = "PausePanel"
    pause_panel.color = Color(0,0,0,0.8)
    pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_panel.visible = false
    layer.add_child(pause_panel)
    var pause_text := Label.new()
    pause_text.text = "PAUSE\nTouchez ou appuyez sur Échap pour reprendre"
    pause_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    pause_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_panel.add_child(pause_text)
    if DisplayServer.is_touchscreen_available():
        var names = ["SAUT","LAMPE","PAUSE"]
        for i in names.size():
            var button := Button.new()
            button.text = names[i]
            button.size = Vector2(92,64)
            button.position = Vector2(get_viewport().get_visible_rect().size.x - 110, get_viewport().get_visible_rect().size.y - 80 - i*72)
            layer.add_child(button)
            if i == 0:
                button.button_down.connect(func(): Input.action_press("jump"))
                button.button_up.connect(func(): Input.action_release("jump"))
            elif i == 1:
                button.pressed.connect(func(): flashlight.visible = not flashlight.visible)
            else:
                button.pressed.connect(_toggle_pause)

func _input(event):
    if event.is_action_pressed("pause"):
        _toggle_pause()
    if event.is_action_pressed("flashlight"):
        flashlight.visible = not flashlight.visible
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused:
        _look(event.relative)
    if event is InputEventScreenTouch:
        var half := get_viewport().get_visible_rect().size.x * 0.5
        if event.pressed:
            if event.position.x < half and left_touch < 0:
                left_touch = event.index
                left_origin = event.position
            elif right_touch < 0:
                right_touch = event.index
        else:
            if event.index == left_touch:
                left_touch = -1
                touch_move = Vector2.ZERO
            if event.index == right_touch:
                right_touch = -1
    if event is InputEventScreenDrag:
        if event.index == left_touch:
            touch_move = ((event.position-left_origin)/70.0).limit_length(1.0)
        elif event.index == right_touch:
            _look(event.relative*0.55)

func _look(delta:Vector2):
    player.rotate_y(-delta.x*0.0024)
    camera.rotation.x = clamp(camera.rotation.x-delta.y*0.0024,-1.35,1.35)

func _physics_process(delta):
    if paused:
        return
    elapsed += delta
    var input := Input.get_vector("move_left","move_right","move_forward","move_back")
    if touch_move.length() > 0.05:
        input = touch_move
    var dir := (player.transform.basis*Vector3(input.x,0,input.y)).normalized()
    player.velocity.x = dir.x*5.2
    player.velocity.z = dir.z*5.2
    if not player.is_on_floor():
        player.velocity.y -= 18.0*delta
    if Input.is_action_just_pressed("jump") and player.is_on_floor():
        player.velocity.y = 7.2
    player.move_and_slide()
    if elapsed > 35.0:
        var to_player := player.global_position-robot.global_position
        to_player.y = 0
        if to_player.length() > 4.0:
            robot.velocity = to_player.normalized()*1.55
            robot.look_at(player.global_position,Vector3.UP)
        else:
            robot.velocity = Vector3.ZERO
        robot.move_and_slide()

func _toggle_pause():
    paused = not paused
    get_tree().paused = paused
    get_node("UI/PausePanel").visible = paused
    if not DisplayServer.is_touchscreen_available():
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
