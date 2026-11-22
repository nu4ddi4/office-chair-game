extends CharacterBody3D

const SPEED = 0.88
const GRAVITY = 6.5
const JUMP_SPEED = 1.45
const HEIGHT = 0.12

var direction = Vector2.ZERO
var jumps = 0
var held = false
var step_id = 0
var body_visual: Node3D
var leg_left: Node3D
var leg_right: Node3D
var walk_cycle = 0.0
var grounded = false

func configure(slot: int, visible_runner: bool) -> void:
	collision_layer = 0
	collision_mask = 1
	safe_margin = 0.001
	floor_snap_length = 0.012
	var collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.height = HEIGHT
	capsule.radius = 0.025
	collider.shape = capsule
	collider.position.y = HEIGHT / 2.0
	add_child(collider)
	if not visible_runner:
		return
	body_visual = Node3D.new()
	add_child(body_visual)
	var color = Color("#69dad1") if slot == 0 else Color("#ff9f68")
	_part(Vector3(0, 0.064, 0), Vector3(0.052, 0.057, 0.04), color, body_visual)
	_part(Vector3(0, 0.109, 0), Vector3(0.042, 0.038, 0.041), Color("#f5ceb0"), body_visual)
	_part(Vector3(0, 0.127, 0.003), Vector3(0.044, 0.01, 0.043), color.darkened(0.32), body_visual)
	leg_left = Node3D.new()
	leg_right = Node3D.new()
	for side in [-1, 1]:
		var leg = leg_left if side == -1 else leg_right
		body_visual.add_child(leg)
		leg.position = Vector3(side * 0.014, 0.052, 0)
		_part(Vector3(0, -0.024, 0), Vector3(0.02, 0.047, 0.022), color.darkened(0.5), leg)
		_part(Vector3(side * 0.035, 0.063, 0), Vector3(0.016, 0.046, 0.016), color, body_visual)

func _part(at: Vector3, size: Vector3, color: Color, parent: Node3D) -> void:
	var visual = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	parent.add_child(visual)
	visual.position = at

func move_input(axis: Vector2, jump: bool, delta: float, slow: bool) -> void:
	var speed = SPEED * (0.45 if slow else 1.0)
	velocity.x = axis.x * speed
	velocity.z = axis.y * speed
	if jump and grounded:
		velocity.y = JUMP_SPEED
	elif not grounded:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0
	move_and_slide()
	grounded = is_on_floor()

func animate_runner(motion: Vector2, delta: float, visible_runner: bool) -> void:
	if body_visual == null:
		return
	body_visual.visible = visible_runner
	if motion.length_squared() > 0.01:
		body_visual.rotation.y = lerp_angle(body_visual.rotation.y, atan2(-motion.x, -motion.y), minf(delta * 14, 1))
	var pace = motion.length()
	walk_cycle += delta * (10 + pace * 8)
	var step = sin(walk_cycle) * minf(pace, 1) * 0.63
	leg_left.rotation.x = step
	leg_right.rotation.x = -step
