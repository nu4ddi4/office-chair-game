class_name ChaosChair
extends RigidBody3D

var wheels: Array[Node3D] = []
var slippery = false
var braked = false
var driving = false
var drive_heading = 0.0
var boosting = false
# Casters trail the direction of travel and swivel at a limited rate. Until they
# line up, they scrub sideways: the chair slides on its old path for a moment,
# and reversing makes them flop round with a jolt.
var caster_heading = 0.0
var caster_misalign = 0.0
var roll = 0.0
var handles: Array[Node3D] = []
var base_visuals: Array[Node3D] = []

func drive(delta: float, throttle: float, steer: float, boost: bool, brake: bool):
	driving = true
	boosting = boost and throttle>0 and not brake
	braked = brake
	var steer_rate = ChaosTuning.BOOST_STEER_RATE if boosting else ChaosTuning.PUSH_STEER_RATE
	drive_heading -= steer*steer_rate*delta
	var forward = -global_basis.z
	forward.y = 0; forward = forward.normalized()
	var side = global_basis.x
	side.y = 0; side = side.normalized()
	var target_speed = throttle*(ChaosTuning.PUSH_BOOST_SPEED if boosting else ChaosTuning.PUSH_SPEED)
	if throttle<0: target_speed = throttle*ChaosTuning.PUSH_REVERSE_SPEED
	if brake: target_speed = 0
	var cap = ChaosTuning.BRAKE_FORCE if brake else ChaosTuning.BOOST_FORCE if boosting else ChaosTuning.PUSH_FORCE
	var gain = 35.0 if absf(throttle)<.01 and not brake else 210.0
	var force = clampf((target_speed-linear_velocity.dot(forward))*gain,-cap,cap)
	# Propulsion and yaw are independent of where the camera happens to look.
	# The employee's spring grips still transmit load, impacts and grip breakage.
	apply_central_force(forward*force)
	# A little body-side grip remains as a steering assist; the casters do the rest.
	var grip = ChaosTuning.CASTER_BODY_GRIP
	var side_limit = (140.0 if slippery else 620.0)*grip
	apply_central_force(-side*clampf(linear_velocity.dot(side)*(18.0 if slippery else 220.0)*grip,-side_limit,side_limit))
	var yaw_error = wrapf(drive_heading-rotation.y,-PI,PI)
	apply_torque(Vector3.UP*clampf(yaw_error*420-angular_velocity.y*90,-360,360))
	var angular_planar = Vector3(angular_velocity.x,0,angular_velocity.z)
	apply_torque((global_basis.y.cross(Vector3.UP)*180-angular_planar*24).limit_length(150))

func _ready():
	mass = 12
	collision_layer = ChaosTuning.OBJECT
	collision_mask = 15
	continuous_cd = true
	linear_damp = .05
	angular_damp = .25
	contact_monitor = true
	max_contacts_reported = 6
	var mat = PhysicsMaterial.new()
	mat.friction = .035
	mat.bounce = .05
	physics_material_override = mat
	add_to_group("chaos_grabbable")
	set_meta("grip_points",[Vector3(-.28,1.02,.30),Vector3(.28,1.02,.30),Vector3(-.39,.76,0),Vector3(.39,.76,0)])
	ChaosShapes.collision(self,Vector3(.65,.13,.61),Vector3(0,.60,0))
	ChaosShapes.collision(self,Vector3(.62,.57,.13),Vector3(0,.92,.25))
	ChaosShapes.collision(self,Vector3(.72,.16,.72),Vector3(0,.08,0))
	base_visuals.append(ChaosShapes.box(self,Vector3(0,.60,0),Vector3(.65,.13,.61),Color("28353a")))
	base_visuals.append(ChaosShapes.box(self,Vector3(0,.92,.25),Vector3(.62,.57,.13),Color("37545b")))
	base_visuals.append(ChaosShapes.capsule(self,Vector3(0,.32,0),.065,.47,Color("a8b2b6")))
	for side in [-1,1]:
		base_visuals.append(ChaosShapes.box(self,Vector3(side*.38,.80,.02),Vector3(.08,.07,.44),Color("1b2a30")))
		base_visuals.append(ChaosShapes.box(self,Vector3(side*.38,.68,.12),Vector3(.05,.25,.05),Color("a8b2b6")))
		handles.append(ChaosShapes.box(self,Vector3(side*.28,1.02,.33),Vector3(.12,.10,.13),Color("edbb55")))
	for i in range(5):
		var angle = TAU*i/5.0
		var arm = ChaosShapes.box(self,Vector3(sin(angle)*.19,.16,cos(angle)*.19),Vector3(.07,.05,.43),Color("909a9d"))
		arm.rotation.y = angle
		base_visuals.append(arm)
		var wheel = ChaosShapes.capsule(self,Vector3(sin(angle)*.35,.09,cos(angle)*.35),.075,.15,Color("15222a"))
		wheel.rotation.z = PI/2
		wheels.append(wheel)

# Swap the blocky stand-in for the office chair model from the map. Collision and
# grip points stay the same; the yellow grips remain as the push affordance.
func dress(source: MeshInstance3D):
	if source==null: return
	var shape: AABB = source.mesh.get_aabb()
	var model = MeshInstance3D.new(); add_child(model)
	model.name = "ChairModel"
	model.mesh = source.mesh
	for i in range(source.get_surface_override_material_count()):
		model.set_surface_override_material(i,source.get_surface_override_material(i))
	var basis = Basis(source.global_basis.get_rotation_quaternion())
	var scale = ChaosTuning.CHAIR_MODEL_HEIGHT/maxf(shape.size.y,.01)
	var oriented: AABB = Transform3D(basis.scaled(Vector3.ONE*scale),Vector3.ZERO)*shape
	var bottom = Vector3(oriented.get_center().x,oriented.position.y,oriented.get_center().z)
	model.transform = Transform3D(basis.scaled(Vector3.ONE*scale),-bottom)
	for visual in base_visuals: visual.hide()
	for wheel in wheels: wheel.hide()

func caster_direction() -> Vector3:
	return Vector3(-sin(caster_heading),0,-cos(caster_heading))

func _physics_process(delta):
	var planar = Vector3(linear_velocity.x,0,linear_velocity.z)
	var speed = planar.length()
	var resistance = .13 if slippery else .65
	if braked: resistance += 4.5
	apply_central_force(-planar*mass*resistance)
	if speed>.12:
		var travel = atan2(-planar.x,-planar.z)
		var turn = wrapf(travel-caster_heading,-PI,PI)
		var rate = ChaosTuning.CASTER_SWIVEL*(.35+speed)*delta
		var swing = clampf(turn,-rate,rate)
		caster_heading = wrapf(caster_heading+swing,-PI,PI)
		caster_misalign = absf(wrapf(travel-caster_heading,-PI,PI))
		# Casters swinging round on their offset arms shove the base sideways (caster flop).
		if caster_misalign>ChaosTuning.CASTER_FLOP_ANGLE:
			var rolling_now = caster_direction()
			apply_central_force(Vector3(-rolling_now.z,0,rolling_now.x)*signf(swing)*ChaosTuning.CASTER_FLOP*minf(speed,1.5))
	else: caster_misalign = 0.0
	# Scrub: velocity across the casters' rolling direction is resisted.
	var rolling = caster_direction()
	var across = planar-rolling*planar.dot(rolling)
	var scrub_limit = ChaosTuning.CASTER_SCRUB_LIMIT*(.25 if slippery else 1.0)
	apply_central_force((-across*ChaosTuning.CASTER_SCRUB*(.15 if slippery else 1.0)).limit_length(scrub_limit))
	roll += speed*delta/.075
	var relative = wrapf(caster_heading-rotation.y,-PI,PI)
	for wheel in wheels: wheel.rotation = Vector3(-roll,relative,PI/2)
	linear_velocity = linear_velocity.limit_length(16)
	angular_velocity = angular_velocity.limit_length(12)

func restore(at: Vector3, yaw: float):
	global_transform = Transform3D(Basis(Vector3.UP,yaw),at)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	driving = false; boosting = false; braked = false; drive_heading = yaw
	caster_heading = yaw; caster_misalign = 0.0
	reset_physics_interpolation()
