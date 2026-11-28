extends Node3D

const DESK_TOP = 0.80
const START = Vector3(0, DESK_TOP + 0.005, 0.30)
const SPAWNS = [
	[Vector3(-0.70, 0.85, 0.16), Vector3(0.64, 0.85, 0.04)],
	[Vector3(0.65, 0.85, 0.22), Vector3(-0.65, 0.85, -0.04)],
]
const DESTINATIONS = [Vector3(0.57, 0.818, -0.31), Vector3(-0.48, 0.817, -0.32)]
const SIZES = [Vector3(0.073, 0.018, 0.036), Vector3(0.13, 0.022, 0.095)]
const COLORS = [Color("#256ea7"), Color("#f4df89")]

var props: Array[Node3D] = []

func build(graphics: bool) -> void:
	_solid(Vector3(0, 0.76, 0), Vector3(1.90, 0.08, 1.10), Color("#bf895a"), graphics)
	_solid(Vector3(0.61, 0.92, -0.48), Vector3(0.39, 0.24, 0.10), Color("#364b4c"), graphics)
	if graphics:
		_box(self, Vector3(0.61, 0.95, -0.426), Vector3(0.32, 0.14, 0.008), Color("#89cabe"))
		_box(self, DESTINATIONS[0] - Vector3.UP * 0.014, Vector3(0.15, 0.008, 0.13), COLORS[0])
		_box(self, DESTINATIONS[1] - Vector3.UP * 0.014, Vector3(0.25, 0.008, 0.19), COLORS[1])
		_box(self, Vector3(0, -0.02, 0), Vector3(10, 0.04, 8), Color("#827a69"))
		var light = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-57, -30, 0)
		light.light_energy = 1.15
		light.shadow_enabled = true
		add_child(light)
		var world = WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color("#435b59")
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color("#e3e9dc")
		world.environment.ambient_light_energy = 0.7
		add_child(world)
	for i in range(SIZES.size()):
		var prop: Node3D
		if graphics:
			prop = Node3D.new()
			_box(prop, Vector3.ZERO, SIZES[i], COLORS[i])
			if i == 0:
				_box(prop, Vector3(0.043, 0, 0), Vector3(0.018, 0.012, 0.028), Color("#d1d9dc"))
		else:
			var body = RigidBody3D.new()
			body.collision_layer = 2
			body.collision_mask = 3
			body.mass = 0.06 if i == 0 else 0.12
			body.continuous_cd = true
			_attach_collision(body, SIZES[i])
			prop = body
		add_child(prop)
		props.append(prop)
		prop.position = SPAWNS[0][i]

func _solid(at: Vector3, size: Vector3, color: Color, graphics: bool) -> void:
	var body = StaticBody3D.new()
	body.position = at
	_attach_collision(body, size)
	add_child(body)
	if graphics:
		_box(body, Vector3.ZERO, size, color)

func _attach_collision(body: CollisionObject3D, size: Vector3) -> void:
	var shape = BoxShape3D.new()
	shape.size = size
	var collider = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var box = BoxMesh.new()
	box.size = size
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	var visual = MeshInstance3D.new()
	visual.mesh = box
	visual.material_override = material
	visual.position = at
	parent.add_child(visual)
