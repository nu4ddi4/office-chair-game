class_name LabPlayer
extends CharacterBody3D

var camera: Camera3D
var ray: RayCast3D
var target: LabDoor
var enabled = false
var jump_buffer = 0.0
var coyote_time = 0.0

func _ready():
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = .12
	var capsule = CapsuleShape3D.new()
	capsule.radius = .305
	capsule.height = 1.8
	var shape = CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = .9
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.fov = 72
	camera.far = 1600
	camera.current = true
	add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0,0,-2.65)
	ray.collision_mask = 5
	ray.add_exception(self)
	camera.add_child(ray)
	for spec in [["move_forward",KEY_W],["move_back",KEY_S],["move_left",KEY_A],["move_right",KEY_D],["jump",KEY_SPACE],["interact",KEY_F]]:
		if not InputMap.has_action(spec[0]): InputMap.add_action(spec[0])
		var key = InputEventKey.new()
		key.physical_keycode = spec[1]
		InputMap.action_add_event(spec[0],key)

func set_enabled(value: bool):
	enabled = value
	velocity = Vector3.ZERO
	jump_buffer = 0
	coyote_time = 0
	target = null
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE

func _input(event):
	if enabled and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x*.0018)
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*.0018,-1.42,1.42)
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if enabled and event.is_action_pressed("interact") and not event.is_echo() and target != null:
		target.inspect()
		get_viewport().set_input_as_handled()

func _physics_process(delta):
	if not enabled: return
	jump_buffer = .12 if Input.is_action_just_pressed("jump") else maxf(0,jump_buffer-delta)
	coyote_time = .10 if is_on_floor() else maxf(0,coyote_time-delta)
	if not is_on_floor(): velocity.y -= 16*delta
	if jump_buffer > 0 and coyote_time > 0:
		velocity.y = 4.8
		jump_buffer = 0
		coyote_time = 0
	var axes = Input.get_vector("move_left","move_right","move_forward","move_back")
	var direction = global_basis*Vector3(axes.x,0,axes.y)
	velocity.x = move_toward(velocity.x,direction.x*4.3,24*delta)
	velocity.z = move_toward(velocity.z,direction.z*4.3,24*delta)
	move_and_slide()
	ray.force_raycast_update()
	target = ray.get_collider() as LabDoor
