class_name ChaosShapes
extends RefCounted

static func material(color: Color, metal = 0.0, roughness = 0.7) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = roughness
	return mat

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, collider = false) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var result = MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = material(color)
	parent.add_child(result)
	result.position = at
	if collider:
		var body = StaticBody3D.new()
		body.collision_layer = ChaosTuning.FLOOR
		parent.add_child(body)
		body.position = at
		collision(body, size)
	return result

static func collision(body: CollisionObject3D, size: Vector3, at = Vector3.ZERO) -> CollisionShape3D:
	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = at
	body.add_child(shape)
	return shape

static func capsule(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var result = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2)
	mesh.radial_segments = 12
	mesh.rings = 4
	result.mesh = mesh
	result.material_override = material(color)
	parent.add_child(result)
	result.position = at
	return result

static func label(parent: Node3D, text: String, at: Vector3, color = Color.WHITE, size = 44) -> Label3D:
	var result = Label3D.new()
	result.text = text
	result.font = load("res://assets/fonts/NotoSansKR.ttf")
	result.font_size = size
	result.pixel_size = 0.009
	result.modulate = color
	result.outline_size = 4
	result.no_depth_test = false
	parent.add_child(result)
	result.position = at
	return result

static func rigid(parent: Node3D, at: Vector3, size: Vector3, mass_value: float, color: Color) -> RigidBody3D:
	var body = RigidBody3D.new()
	body.mass = mass_value
	body.collision_layer = ChaosTuning.OBJECT
	body.collision_mask = 15
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 4
	parent.add_child(body)
	body.position = at
	collision(body, size)
	box(body, Vector3.ZERO, size, color)
	return body
