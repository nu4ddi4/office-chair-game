class_name ChaosCoffee
extends Node3D

# Coffee only spills when the player's driving makes it slosh over the rim.
# The liquid is a damped spring (about 2 Hz, like a mug of coffee) driven by the
# chair's horizontal acceleration in the chair's own frame. It rocks back and
# forth after a jolt: pushing again on the return swing makes the wave grow,
# easing off in time lets it settle. Spills leave the cup on the crest side.

signal spilled(amount: float)
signal brimming
var amount = 100.0
var temperature = ChaosTuning.COFFEE_HOT
var slosh = 0.0
var slosh_offset = Vector2.ZERO    # crest position, chair frame: x = right, y = forward (rim units)
var slosh_velocity = Vector2.ZERO
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
var mug_model = false
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

# Use the mug model from the office instead of the plain cylinder.
func dress(source: MeshInstance3D):
	if source==null: return
	var shell: MeshInstance3D = cup.get_child(1)
	shell.mesh = source.mesh
	shell.material_override = null
	for i in range(source.get_surface_override_material_count()):
		shell.set_surface_override_material(i,source.get_surface_override_material(i))
	var box: AABB = source.mesh.get_aabb()
	var scale = .14/maxf(box.size.y,.01)
	shell.scale = Vector3.ONE*scale
	shell.position = Vector3(-box.get_center().x*scale,-.07-box.position.y*scale,-box.get_center().z*scale)
	(liquid.mesh as CylinderMesh).top_radius = .034*scale
	(liquid.mesh as CylinderMesh).bottom_radius = .034*scale
	mug_model = true

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
	slosh = 0; slosh_offset = Vector2.ZERO; slosh_velocity = Vector2.ZERO; warned = false
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
	_rock(delta)
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
	liquid.position.y = (-.06+.11*amount/100) if mug_model else (-.065+.125*amount/100)
	liquid.visible = amount>.1
	# The surface leans against the acceleration and grows with the slosh.
	var lean = (_right()*slosh_offset.x+_forward()*slosh_offset.y)*.45
	var local_lean = cup.global_basis.inverse()*lean
	liquid.rotation.x = lerpf(liquid.rotation.x,clampf(local_lean.z,-.6,.6),1-exp(-delta*12))
	liquid.rotation.z = lerpf(liquid.rotation.z,clampf(-local_lean.x,-.6,.6),1-exp(-delta*12))
	droplets.emitting = before-amount>.001
	if before-amount>.001:
		spilled.emit(before-amount)
		drip_time -= delta
		if drip_time <= 0:
			drip_time = .18
			var side = (_right()*slosh_offset.x+_forward()*slosh_offset.y).limit_length(1)*.25
			var mark = ChaosShapes.box(get_parent(),Vector3(cup.global_position.x+side.x,.008,cup.global_position.z+side.z),Vector3(.22,.008,.18),Color("5a3a22"))
			mark.material_override.roughness = .15
			spills.append(mark)
			if spills.size()>24: spills.pop_front().queue_free()

func _forward() -> Vector3:
	var f = -chair.global_basis.z; f.y = 0
	return f.normalized() if f.length()>.01 else Vector3.FORWARD

func _right() -> Vector3:
	var r = chair.global_basis.x; r.y = 0
	return r.normalized() if r.length()>.01 else Vector3.RIGHT

# Spring-damper for the liquid crest. Gentle acceleration below the dead zone
# barely moves it; the excess pushes the liquid the other way and it rocks back.
func _rock(delta: float):
	var a = Vector2(filtered_acceleration.dot(_right()),filtered_acceleration.dot(_forward()))
	# Turning: the cup swings round the turn even while the casters still slide on
	# the old path, so the felt sideways load is speed times yaw rate.
	a.x -= chair.angular_velocity.y*chair.linear_velocity.dot(_forward())*ChaosTuning.COFFEE_TURN_LOAD
	var size = a.length()
	var drive = a*(maxf(0,size-ChaosTuning.COFFEE_SLOSH_DEADZONE)/size) if size>.001 else Vector2.ZERO
	var target = -drive*ChaosTuning.COFFEE_SLOSH_GAIN if boss.seated else Vector2.ZERO
	var w = TAU*ChaosTuning.COFFEE_SLOSH_HZ
	var h = delta/2.0
	for i in range(2):
		var pull = (target-slosh_offset)*w*w-slosh_velocity*2.0*ChaosTuning.COFFEE_SLOSH_DAMPING*w
		slosh_velocity += pull*h
		slosh_offset += slosh_velocity*h
	slosh_offset = slosh_offset.limit_length(ChaosTuning.COFFEE_SLOSH_MAX)
	slosh = slosh_offset.length()

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
	amount = 100; temperature = ChaosTuning.COFFEE_HOT; slosh = 0; slosh_offset = Vector2.ZERO; slosh_velocity = Vector2.ZERO; grace = 1

func restore(value: float, heat = ChaosTuning.COFFEE_HOT):
	amount = clampf(value,0,100)
	temperature = clampf(heat,ChaosTuning.COFFEE_AMBIENT,ChaosTuning.COFFEE_HOT)
	for mark in spills:
		if is_instance_valid(mark): mark.queue_free()
	spills.clear()
	peak_slosh = 0
	reconnect()
