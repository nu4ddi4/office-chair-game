class_name ChaosProp
extends RigidBody3D

signal damaged(price: int)
var start: Transform3D
var broken = false
var price = 15000
var original_color = Color("b79669")
var grace = 1.5

func build(at: Vector3, kind = 0):
	mass = 2 if kind==0 else 5
	collision_layer = ChaosTuning.OBJECT
	collision_mask = 15
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = .3
	angular_damp = .5
	global_position = at
	ChaosShapes.collision(self,Vector3(.45,.5,.4))
	original_color = Color("b79669") if kind==0 else Color("43545f")
	ChaosShapes.box(self,Vector3.ZERO,Vector3(.45,.5,.4),original_color)
	ChaosShapes.box(self,Vector3(0,.255,0),Vector3(.09,.008,.4),Color("e4d5b3"))
	start = global_transform
	add_to_group("chaos_grabbable")
	body_entered.connect(_impact)

func _physics_process(delta): grace = maxf(0,grace-delta)

func _impact(_other: Node):
	if not broken and grace<=0 and linear_velocity.length()>2.8:
		broken = true
		damaged.emit(price)
		get_child(1).material_override = ChaosShapes.material(Color("776b60"))

func restore():
	global_transform = start
	linear_velocity = Vector3.ZERO; angular_velocity = Vector3.ZERO
	broken = false; grace = 1.5
	get_child(1).material_override.albedo_color = original_color
	reset_physics_interpolation()
