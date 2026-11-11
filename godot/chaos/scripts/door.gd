class_name ChaosDoor
extends Node3D

signal slammed(strength: float)
signal banged(strength: float)
var leaf: RigidBody3D
var touching: Dictionary = {}
var bang_cooldown = 0.0
var hinge: HingeJoint3D
var closing = false
var opened_for = 0.0
var origin_yaw = 0.0

func build(at: Vector3, yaw: float, width = 1.6, auto_close = true):
	global_position = at
	rotation.y = yaw
	origin_yaw = yaw
	closing = auto_close
	var mount = StaticBody3D.new()
	mount.collision_layer = 0
	add_child(mount)
	leaf = ChaosShapes.rigid(self,Vector3(width/2,1.1,0),Vector3(width-.06,2.2,.075),ChaosTuning.DOOR_MASS,Color("a9bbbd"))
	leaf.collision_layer = ChaosTuning.DOOR
	leaf.name = "DoorLeaf"
	leaf.add_to_group("chaos_grabbable")
	leaf.set_meta("grip_points",[Vector3(width/2-.14,0,-.09),Vector3(width/2-.14,0,.09)])
	ChaosShapes.box(leaf,Vector3(width/2-.14,0,-.08),Vector3(.06,.18,.07),Color("edbb55"))
	ChaosShapes.box(leaf,Vector3(0,.22,-.045),Vector3(width-.25,1.15,.01),Color("d0e0de"))
	hinge = HingeJoint3D.new()
	add_child(hinge)
	hinge.position = Vector3(0,1.1,0)
	hinge.rotation.x = PI/2
	hinge.node_a = hinge.get_path_to(mount)
	hinge.node_b = hinge.get_path_to(leaf)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT,true)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER,-1.7)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER,1.7)

func interact(from: Vector3):
	var side = signf((global_basis.inverse()*(from-global_position)).z)
	leaf.apply_torque_impulse(Vector3.UP*side*25)
	opened_for = 2.5

# Anything leaning on the leaf (the chair, the boss's knees, the employee) swings
# it open in the push direction and keeps the closer off while in contact.
func _physics_process(delta):
	if leaf == null: return
	opened_for = maxf(0,opened_for-delta)
	bang_cooldown = maxf(0,bang_cooldown-delta)
	var now: Dictionary = {}
	for body in leaf.get_colliding_bodies():
		if body is RigidBody3D and body.collision_layer & (ChaosTuning.OBJECT|ChaosTuning.ACTOR):
			var side = signf((global_basis.inverse()*(body.global_position-global_position)).z)
			leaf.apply_torque(Vector3.UP*side*ChaosTuning.DOOR_PUSH_ASSIST)
			opened_for = maxf(opened_for,1.2)
			now[body.get_instance_id()] = true
			if body is ChaosChair and not touching.has(body.get_instance_id()): _slam(body,side)
	touching = now
	# The leaf hitting its stop after a hard swing.
	var angle = wrapf(leaf.global_rotation.y-origin_yaw,-PI,PI)
	var spin = absf(leaf.angular_velocity.y)
	if absf(angle)>ChaosTuning.DOOR_STOP_ANGLE and spin>ChaosTuning.DOOR_BANG_SPIN and bang_cooldown<=0:
		bang_cooldown = .6
		banged.emit(clampf(spin/6.0,.3,1.0))

# First contact of a moving chair: throw the leaf open, kick the chair back a
# little and report how hard it was. The boss's seat allowance absorbs the kick.
func _slam(chair: RigidBody3D, side: float):
	var normal = global_basis.z
	var speed = absf(chair.linear_velocity.dot(normal))
	if speed<ChaosTuning.DOOR_SLAM_SPEED: return
	leaf.apply_torque_impulse(Vector3.UP*side*speed*ChaosTuning.DOOR_SLAM_TORQUE)
	var travel = normal*signf(chair.linear_velocity.dot(normal))
	chair.apply_central_impulse(-travel*speed*chair.mass*ChaosTuning.DOOR_SLAM_PUSHBACK)
	opened_for = maxf(opened_for,2.0)
	slammed.emit(clampf((speed-ChaosTuning.DOOR_SLAM_SPEED)/3.0+.3,.3,1.0))
	if closing and opened_for<=0:
		var angle = wrapf(leaf.global_rotation.y-origin_yaw,-PI,PI)
		leaf.apply_torque(Vector3.UP*(-angle*8.0-leaf.angular_velocity.y*3.0))

func restore():
	# Re-seat the hinge around the teleported leaf so the joint starts from the closed pose.
	hinge.node_b = NodePath()
	leaf.global_transform = global_transform*Transform3D(Basis.IDENTITY,Vector3(leaf.get_child(0).shape.size.x/2+.03,1.1,0))
	hinge.node_b = hinge.get_path_to(leaf)
	leaf.linear_velocity = Vector3.ZERO; leaf.angular_velocity = Vector3.ZERO
	# A restored leaf must be awake, or it ignores the next push until something else wakes it.
	leaf.sleeping = false; opened_for = 0.0; touching = {}
	leaf.reset_physics_interpolation()
