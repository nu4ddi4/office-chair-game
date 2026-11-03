class_name ChaosCoffee
extends Node3D

signal spilled(amount: float)
var amount = 100.0
var previous_velocity = Vector3.ZERO
var boss: ChaosRagdoll
var liquid: MeshInstance3D
var cup: RigidBody3D
var joint: PinJoint3D
var grace = 1.0
var drip_time = 0.0
var droplets: CPUParticles3D
var spills: Array[Node3D] = []

func setup(owner: ChaosRagdoll):
	boss = owner
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
	droplets.amount = 12; droplets.lifetime = .4; droplets.emitting = false
	droplets.direction = Vector3(0,-1,0); droplets.gravity = Vector3(0,-5,0)
	droplets.initial_velocity_min = .2; droplets.initial_velocity_max = .6
	var drop_mesh = SphereMesh.new(); drop_mesh.radius = .012; drop_mesh.height = .024
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
	previous_velocity = hand.linear_velocity
	grace = 1

func _physics_process(delta):
	if boss == null: return
	var velocity: Vector3 = boss.bodies.hand_r.linear_velocity
	var acceleration = (velocity-previous_velocity)/maxf(delta,.001)
	previous_velocity = velocity
	grace = maxf(0,grace-delta)
	var tilt = acos(clampf(cup.global_basis.y.dot(Vector3.UP),-1,1))
	# A damped upright tendency keeps a quiet cup stable while allowing impact spill.
	cup.apply_torque(cup.global_basis.y.cross(Vector3.UP)*.9-cup.angular_velocity*.09)
	var loss = (maxf(0,tilt-.48)*11.0 + maxf(0,Vector2(acceleration.x,acceleration.z).length()-7.5)*.045)*delta if grace<=0 else 0.0
	if not boss.seated and grace<=0: loss += delta*12
	var before = amount
	amount = clampf(amount-loss,0,100)
	liquid.position.y = -.065+.125*amount/100
	liquid.visible = amount>.1
	liquid.rotation.x = clampf(acceleration.z*.006,-.3,.3)
	liquid.rotation.z = clampf(-acceleration.x*.006,-.3,.3)
	droplets.emitting = before-amount>.001
	if before-amount>.001:
		spilled.emit(before-amount)
		drip_time -= delta
		if drip_time <= 0:
			drip_time = .18
			var mark = ChaosShapes.box(get_parent(),Vector3(cup.global_position.x,.008,cup.global_position.z),Vector3(.16,.008,.13),Color("69472e"))
			spills.append(mark)
			if spills.size()>20: spills.pop_front().queue_free()

func restore(value: float):
	amount = clampf(value,0,100)
	for mark in spills:
		if is_instance_valid(mark): mark.queue_free()
	spills.clear()
	reconnect()
