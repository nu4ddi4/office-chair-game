class_name ChaosCoffee
extends Node3D

# Coffee only spills when the player's driving makes it slosh over the rim.
# Slosh builds from the chair's horizontal acceleration (starts, hard braking,
# fast turns, collisions) and settles again during smooth driving.

signal spilled(amount: float)
signal brimming
var amount = 100.0
var temperature = ChaosTuning.COFFEE_HOT
var slosh = 0.0
var peak_slosh = 0.0
var boss: ChaosRagdoll
var chair: RigidBody3D
var liquid: MeshInstance3D
var cup: RigidBody3D
var joint: PinJoint3D
var grace = 1.0
var drip_time = 0.0
var warned = false
var droplets: CPUParticles3D
var spills: Array[Node3D] = []
var previous_velocity = Vector3.ZERO
var filtered_acceleration = Vector3.ZERO

func setup(owner: ChaosRagdoll, on_chair: RigidBody3D):
	boss = owner
	chair = on_chair
	cup = RigidBody3D.new()
	cup.mass = .3
	cup.collision_layer = 0
	cup.collision_mask = 0
	add_child(cup)
	ChaosShapes.collision(cup,Vector3(.12,.16,.12))
	var mesh = CylinderMesh.new()
	mesh.top_radius = .075; mesh.bottom_radius = .055; mesh.height = .16
	var shell = MeshInstance3D.new()
	shell.mesh = mesh; shell.material_override = ChaosShapes.material(Color("f3e9d4"))
	cup.add_child(shell)
	var surface = CylinderMesh.new()
	surface.top_radius = .065; surface.bottom_radius = .065; surface.height = .006
	liquid = MeshInstance3D.new()
	liquid.mesh = surface; liquid.position.y = .06
	liquid.material_override = ChaosShapes.material(Color("59351e"),0,.22)
	cup.add_child(liquid)
	droplets = CPUParticles3D.new()
	cup.add_child(droplets)
	droplets.amount = 24; droplets.lifetime = .5; droplets.emitting = false
	droplets.direction = Vector3(0,1,0); droplets.spread = 70; droplets.gravity = Vector3(0,-9,0)
	droplets.initial_velocity_min = .5; droplets.initial_velocity_max = 1.4
	var drop_mesh = SphereMesh.new(); drop_mesh.radius = .014; drop_mesh.height = .028
	drop_mesh.material = ChaosShapes.material(Color("69472e"))
	droplets.mesh = drop_mesh
	reconnect()

func reconnect():
	if joint != null:
		joint.node_a = NodePath(); joint.node_b = NodePath(); joint.queue_free()
	var hand: RigidBody3D = boss.bodies.hand_r
	cup.global_transform = Transform3D(Basis.IDENTITY,hand.global_position+Vector3(0,.10,0))
	cup.linear_velocity = Vector3.ZERO; cup.angular_velocity = Vector3.ZERO
	joint = PinJoint3D.new()
	add_child(joint)
	joint.global_position = hand.global_position
	joint.node_a = joint.get_path_to(hand); joint.node_b = joint.get_path_to(cup)
	previous_velocity = chair.linear_velocity
	filtered_acceleration = Vector3.ZERO
	slosh = 0; warned = false
	grace = 1

func _physics_process(delta):
	if boss == null: return
	var velocity: Vector3 = chair.linear_velocity
	var raw_acceleration = (velocity-previous_velocity)/maxf(delta,.001)
	raw_acceleration.y = 0
	previous_velocity = velocity
	filtered_acceleration = filtered_acceleration.lerp(raw_acceleration,1-exp(-delta/ChaosTuning.COFFEE_ACCEL_FILTER))
	grace = maxf(0,grace-delta)
	if grace>0: filtered_acceleration = Vector3.ZERO
	temperature = ChaosTuning.COFFEE_AMBIENT+(temperature-ChaosTuning.COFFEE_AMBIENT)*exp(-ChaosTuning.COFFEE_COOLING*delta)
	var excite = filtered_acceleration.length()
	if boss.seated:
		slosh += maxf(0,excite-ChaosTuning.COFFEE_SLOSH_THRESHOLD)*ChaosTuning.COFFEE_SLOSH_GAIN*delta
	slosh = clampf(slosh-slosh*ChaosTuning.COFFEE_SLOSH_SETTLE*delta,0,ChaosTuning.COFFEE_SLOSH_MAX)
	peak_slosh = maxf(peak_slosh,slosh)
	if fullness()>=ChaosTuning.COFFEE_SLOSH_WARN and not warned:
		warned = true; brimming.emit()
	elif fullness()<ChaosTuning.COFFEE_SLOSH_WARN*.6: warned = false
	# The cup itself keeps a damped upright tendency; only a real tip-over pours.
	cup.apply_torque(cup.global_basis.y.cross(Vector3.UP)*.6-cup.angular_velocity*.075)
	var tilt = acos(clampf(cup.global_basis.y.dot(Vector3.UP),-1,1))
	var rate = maxf(0,slosh-rim())*ChaosTuning.COFFEE_OVERFLOW_SPILL
	rate += maxf(0,tilt-ChaosTuning.COFFEE_TILT_THRESHOLD)*ChaosTuning.COFFEE_TILT_SPILL
	if not boss.seated: rate += 35
	var loss = minf(rate,90)*delta if grace<=0 else 0.0
	var before = amount
	amount = clampf(amount-loss,0,100)
	liquid.position.y = -.065+.125*amount/100
	liquid.visible = amount>.1
	# The surface leans against the acceleration and grows with the slosh.
	var lean = -filtered_acceleration.normalized()*minf(slosh,1.2)*.5 if excite>.05 else Vector3.ZERO
	var local_lean = cup.global_basis.inverse()*lean
	liquid.rotation.x = lerpf(liquid.rotation.x,clampf(local_lean.z,-.6,.6),1-exp(-delta*12))
	liquid.rotation.z = lerpf(liquid.rotation.z,clampf(-local_lean.x,-.6,.6),1-exp(-delta*12))
	droplets.emitting = before-amount>.001
	if before-amount>.001:
		spilled.emit(before-amount)
		drip_time -= delta
		if drip_time <= 0:
			drip_time = .18
			var mark = ChaosShapes.box(get_parent(),Vector3(cup.global_position.x,.008,cup.global_position.z),Vector3(.22,.008,.18),Color("5a3a22"))
			mark.material_override.roughness = .15
			spills.append(mark)
			if spills.size()>24: spills.pop_front().queue_free()

# A fuller cup has less headroom: the slosh needed to reach the rim grows as it empties.
func rim() -> float:
	return 1.0+(1.0-amount/100.0)*ChaosTuning.COFFEE_HEADROOM

# 0 = calm surface, 1 = coffee at the rim.
func fullness() -> float:
	return slosh/rim()

func on_puddle(at: Vector3) -> bool:
	for mark in spills:
		if is_instance_valid(mark) and Vector2(mark.global_position.x-at.x,mark.global_position.z-at.z).length()<ChaosTuning.PUDDLE_RADIUS: return true
	return false

func refill():
	amount = 100; temperature = ChaosTuning.COFFEE_HOT; slosh = 0; grace = 1

func restore(value: float, heat = ChaosTuning.COFFEE_HOT):
	amount = clampf(value,0,100)
	temperature = clampf(heat,ChaosTuning.COFFEE_AMBIENT,ChaosTuning.COFFEE_HOT)
	for mark in spills:
		if is_instance_valid(mark): mark.queue_free()
	spills.clear()
	peak_slosh = 0
	reconnect()
