extends Node3D

const START = Vector3(-6.1, 0.003, 1.40)
const FIRST_TABLE = Vector3(-2.66, 0.803, 0.48)
const SECOND_TABLE = Vector3(1.63, 0.803, 0.45)
const DRAWER_HANDLE = Vector3(-4.14, 0.10, 0.10)
const DRAWER_CLIP = Vector3(-3.83, 0.30, 0.03)
const LEFT_GRIP = Vector3(-0.44, 0.85, -0.27)
const RIGHT_GRIP = Vector3(-0.44, 0.85, 0.12)
const CABLE_TOP = Vector3(2.68, 0.80, 0.53)
const CABLE_BOTTOM = Vector3(2.96, 0.003, 0.53)
const EXIT = Vector3(4.77, 0.003, 1.48)

const FLOOR = Color("#ac9d83")
const WALL = Color("#ebe1cb")
const WOOD = Color("#ca925c")
const METAL = Color("#434f50")
const PARTITION = Color("#688b87")
const PAPER = Color("#e7daba")
const DRAWER_COLOR = Color("#eeb559")
const BINDER_COLOR = Color("#417aa1")

var graphics = false
var drawer: AnimatableBody3D
var bridge: AnimatableBody3D
var employee: Node3D
var hand: MeshInstance3D
var eyes: Array[MeshInstance3D] = []
var cups: Array[MeshInstance3D] = []
var markers: Array[MeshInstance3D] = []
var marker_colors: Array[StandardMaterial3D] = []

func build(render_graphics: bool) -> void:
	graphics = render_graphics
	solid(Vector3(-0.8, -0.13, 0), Vector3(12.8, 0.26, 6.8), FLOOR)
	for z in [-3.4, 3.4]:
		solid(Vector3(-0.8, 1.25, z), Vector3(12.8, 2.5, 0.16), WALL)
	for x in [-7.2, 5.6]:
		solid(Vector3(x, 1.25, 0), Vector3(0.16, 2.5, 6.8), WALL)
	partition(Vector3(-4.97, 0, 1.66), 0.10, 1.75)
	partition(Vector3(-5.61, 0, 0.44), 1.72, 0.10)
	partition(Vector3(-1.54, 0, 1.31), 2.72, 0.105)
	partition(Vector3(2.15, 0, 1.78), 2.28, 0.105)
	# Raised leaves leave a low passage under the last partition.
	solid(Vector3(4.39, 0.75, 1.42), Vector3(0.10, 1.18, 1.12), PARTITION)
	solid(Vector3(4.39, 0.09, 0.91), Vector3(0.23, 0.18, 0.12), METAL)
	solid(Vector3(4.39, 0.09, 1.93), Vector3(0.23, 0.18, 0.12), METAL)
	desk(-1.52)
	desk(1.52)
	# Distinct tabletop cover and fixed climbing steps.
	for x in [-1.85, 1.76]:
		solid(Vector3(x, 0.84, 0.03), Vector3(0.40, 0.08, 0.29), METAL)
		solid(Vector3(x, 1.08, -0.10), Vector3(0.44, 0.40, 0.08), METAL)
		solid(Vector3(x, 1.08, -0.056), Vector3(0.39, 0.33, 0.016), Color("#9db6aa"))
		solid(Vector3(x - 0.54, 0.89, 0.31), Vector3(0.27, 0.18, 0.30), PAPER)
	solid(Vector3(-3.40, 0.335, -0.04), Vector3(0.57, 0.67, 0.72), METAL)
	solid(Vector3(-4.07, 0.058, -0.13), Vector3(0.17, 0.116, 0.24), PAPER)
	solid(Vector3(-3.82, 0.195, -0.28), Vector3(0.32, 0.39, 0.24), Color("#947259"))
	solid(Vector3(-3.81, 0.27, -0.54), Vector3(0.33, 0.54, 0.24), PAPER)
	solid(Vector3(-3.02, 0.37, -0.20), Vector3(0.32, 0.74, 0.44), PAPER)
	for at in [Vector3(-5.89, 0.26, -0.31), Vector3(-4.36, 0.26, 1.5), Vector3(3.54, 0.32, 1.66)]:
		solid(at, Vector3(0.48, at.y * 2.0, 0.48), Color("#af8055"))

	drawer = moving(Vector3(-3.49, 0.199, 0), Vector3(0.35, 0.112, 0.27), DRAWER_COLOR)
	bridge = moving(Vector3(-0.70, 0.82, -0.08), Vector3(0.66, 0.039, 0.31), BINDER_COLOR)
	if not graphics:
		return
	_environment()
	_display_props()
	_build_employee()

func solid(at: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	add_child(body)
	body.position = at
	_attach_box(body, size, color)

func moving(at: Vector3, size: Vector3, color: Color) -> AnimatableBody3D:
	var body = AnimatableBody3D.new()
	body.sync_to_physics = false
	add_child(body)
	body.position = at
	_attach_box(body, size, color)
	return body

func _attach_box(body: CollisionObject3D, size: Vector3, color: Color) -> void:
	var shape = BoxShape3D.new()
	shape.size = size
	var collider = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	if graphics:
		box(body, Vector3.ZERO, size, color)

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = material
	parent.add_child(instance)
	instance.position = at
	return instance

func partition(at: Vector3, width: float, depth: float) -> void:
	solid(at + Vector3.UP * 0.70, Vector3(width, 1.32, depth), PARTITION)
	solid(at + Vector3.UP * 0.021, Vector3(width + 0.034, 0.042, depth + 0.029), METAL)

func desk(x: float) -> void:
	solid(Vector3(x, 0.775, 0), Vector3(2.56, 0.05, 1.40), WOOD)
	for dx in [-1.16, 1.16]:
		for z in [-0.60, 0.60]:
			solid(Vector3(x + dx, 0.375, z), Vector3(0.09, 0.75, 0.09), METAL)

func _environment() -> void:
	var world_light = WorldEnvironment.new()
	world_light.environment = Environment.new()
	world_light.environment.background_mode = Environment.BG_COLOR
	world_light.environment.background_color = Color("#a4b5ab")
	world_light.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_light.environment.ambient_light_color = Color("#fff2e0")
	world_light.environment.ambient_light_energy = 0.67
	add_child(world_light)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -28, 0)
	light.light_energy = 0.72
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 12
	add_child(light)

func _display_props() -> void:
	for x in range(-6, 6):
		for z in range(-3, 4):
			if ((x + z) % 2) == 0:
				box(self, Vector3(x, 0.0005, z), Vector3(0.992, 0.001, 0.992), FLOOR.lightened(0.065))
	for x in [-4.60, -2.15, 0.3, 2.75]:
		box(self, Vector3(x, 1.57, -3.307), Vector3(1.55, 0.91, 0.005), Color("#a5bfc1"))
	box(self, Vector3(2.82, 0.41, 0.53), Vector3(0.022, 0.82, 0.02), Color("#d98c4a"))
	box(self, EXIT + Vector3.UP * 0.008, Vector3(0.33, 0.012, 0.35), Color("#76c6a3"))
	for at in [DRAWER_HANDLE, DRAWER_CLIP, LEFT_GRIP, RIGHT_GRIP, CABLE_TOP, CABLE_BOTTOM, EXIT]:
		var marker = box(self, at + Vector3.UP * 0.025, Vector3(0.036, 0.033, 0.036), Color("#ffe275"))
		markers.append(marker)
		marker_colors.append(marker.material_override)
	for i in range(2):
		var cup = box(self, Vector3.ZERO, Vector3(0.23, 0.17, 0.23), Color(0.58, 0.86, 0.96, 0.33))
		box(cup, Vector3(0, 0.086, 0), Vector3(0.239, 0.011, 0.239), Color("#9bd1de"))
		cup.visible = false
		cups.append(cup)

func _build_employee() -> void:
	employee = Node3D.new()
	add_child(employee)
	box(employee, Vector3(0, 1.17, 0), Vector3(0.47, 0.55, 0.28), Color("#55727a"))
	box(employee, Vector3(0, 1.57, 0.018), Vector3(0.25, 0.28, 0.25), Color("#ddb18c"))
	box(employee, Vector3(0, 1.72, -0.01), Vector3(0.27, 0.07, 0.26), Color("#423a3a"))
	for side in [-1, 1]:
		box(employee, Vector3(side * 0.116, 0.47, 0), Vector3(0.19, 0.88, 0.19), METAL)
		box(employee, Vector3(side * 0.116, 0.055, 0.045), Vector3(0.20, 0.11, 0.28), Color("#2a3536"))
		eyes.append(box(employee, Vector3(side * 0.057, 1.60, 0.148), Vector3(0.028, 0.029, 0.010), Color("#342e2e")))
	hand = box(self, Vector3.ZERO, Vector3(0.15, 0.12, 0.18), Color("#ddb18c"))

func set_puzzles(drawer_fraction: float, bridge_fraction: float) -> void:
	drawer.position.x = lerpf(-3.49, -3.83, drawer_fraction)
	bridge.position.x = lerpf(-0.70, 0.0, bridge_fraction)

func show_staff(at: Vector3, facing: float, warning: float, reach: Vector3) -> void:
	employee.position = at
	employee.rotation.y = facing
	var shoulder = at + Basis(Vector3.UP, facing) * Vector3(0.26, 1.22, 0.08)
	hand.position = shoulder.lerp(reach + Vector3.UP * 0.15, warning)
	for eye in eyes:
		eye.scale.y = 1.0 + warning * 0.75

func show_cup(slot: int, at: Vector3, active: bool) -> void:
	cups[slot].visible = active
	cups[slot].position = at + Vector3.UP * 0.085

func show_markers(locked: bool, bridged: bool, checkpoint: int, focus: int) -> void:
	for i in range(markers.size()):
		var active = (i < 2 and not locked) or (i in [2, 3] and not bridged and checkpoint >= 1) or (i >= 4 and checkpoint >= 2)
		markers[i].visible = active
		marker_colors[i].albedo_color = Color("#afffe4") if i == focus else Color("#ffe275")
