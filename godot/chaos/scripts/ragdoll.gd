class_name ChaosRagdoll
extends Node3D

signal fell
signal grip_changed

var bodies: Dictionary = {}
var offsets: Dictionary = {}
var rest_angles: Dictionary = {}
var joints: Array[Joint3D] = []
var grips: Array = [null, null]
var grip_anchors: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var grip_strain = [0.0, 0.0]
var boss = false
var seated = false
var fallen = false
var fall_time = 0.0
var desired_velocity = Vector3.ZERO
var facing = 0.0
var bracing = false
var phase = 0.0
var enabled = true
var lean = 0.0
var chair: RigidBody3D
var seat_joint: PinJoint3D
var grounded = false
var slippery = false
var gesture = ""
var gesture_time = 0.0
var seat_grace = 0.0
var pushing = false
var seat_risk = 0.0
var seat_acceleration = Vector3.ZERO
var previous_seat_velocity = Vector3.ZERO

func build(at: Vector3, is_boss = false, yaw = 0.0):
	boss = is_boss
	facing = yaw
	var shirt = Color("af765c") if boss else Color("3d8397")
	var skin = Color("edbb96")
	_part("pelvis", Vector3(0,.92,0), .17,.26,14,Color("283c4a"))
	_part("torso", Vector3(0,1.28,0), .29 if boss else .22,.62,20,shirt)
	_part("head", Vector3(0,1.76,-.01), .19,.41,4,skin)
	for side in [-1,1]:
		var suffix = "l" if side == -1 else "r"
		_part("thigh_"+suffix,Vector3(side*.16,.66,0),.10,.46,4,Color("283c4a"))
		_part("shin_"+suffix,Vector3(side*.16,.30,0),.085,.38,2,Color("283c4a"))
		_part("foot_"+suffix,Vector3(side*.16,.085,-.08),.10,.2,1,Color("16212b"))
		_part("upper_"+suffix,Vector3(side*.37,1.30,0),.085,.43,2,shirt)
		_part("lower_"+suffix,Vector3(side*.41,.96,0),.075,.36,1.5,shirt)
		_part("hand_"+suffix,Vector3(side*.42,.72,0),.105,.22,.5,skin)
	for key in bodies:
		for other in bodies:
			if key != other: bodies[key].add_collision_exception_with(bodies[other])
	reset_pose(at,yaw,false)
	_joint("pelvis","torso",Vector3(0,1.05,0),at,yaw,.7)
	_joint("torso","head",Vector3(0,1.56,0),at,yaw,.65)
	for side in [-1,1]:
		var s = "l" if side == -1 else "r"
		_joint("pelvis","thigh_"+s,Vector3(side*.16,.87,0),at,yaw,1.65)
		_joint("thigh_"+s,"shin_"+s,Vector3(side*.16,.46,0),at,yaw,1.6)
		_joint("shin_"+s,"foot_"+s,Vector3(side*.16,.13,0),at,yaw,.7)
		_joint("torso","upper_"+s,Vector3(side*.30,1.48,0),at,yaw,2.3)
		_joint("upper_"+s,"lower_"+s,Vector3(side*.40,1.11,0),at,yaw,1.7)
		_joint("lower_"+s,"hand_"+s,Vector3(side*.42,.80,0),at,yaw,1.0)
	# Facial features follow actual head motion; the camera stays level.
	for side in [-1,1]:
		ChaosShapes.capsule(bodies.head,Vector3(side*.075,.025,-.173),.024,.055,Color("17242b"))
		ChaosShapes.box(bodies.head,Vector3(side*.075,.085,-.17),Vector3(.085,.018,.025),Color("402f28"))
	ChaosShapes.box(bodies.head,Vector3(0,-.075,-.181),Vector3(.07,.015,.018),Color("6d4039"))
	ChaosShapes.capsule(bodies.head,Vector3(0,.12,.015),.19,.22,Color("2c2725"))
	ChaosShapes.box(bodies.torso,Vector3(0,.03,-.22),Vector3(.065,.33,.025),Color("edb74d"))
	ChaosShapes.box(bodies.torso,Vector3(-.13,.02,-.20),Vector3(.10,.13,.025),Color("e8efe9"))
	for s in ["l","r"]:
		ChaosShapes.box(bodies["foot_"+s],Vector3(0,-.025,-.07),Vector3(.22,.13,.34),Color("16212b"))

func _part(key: String, at: Vector3, radius: float, height: float, weight: float, color: Color):
	var body = RigidBody3D.new()
	body.name = key
	body.mass = weight * (4.0/3.0 if boss else 1.0)
	body.collision_layer = ChaosTuning.ACTOR
	body.collision_mask = 15
	body.continuous_cd = true
	body.linear_damp = .15
	body.angular_damp = .6
	body.can_sleep = boss
	if boss:
		var contact = PhysicsMaterial.new()
		contact.friction = .28; contact.rough = true
		body.physics_material_override = contact
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height,2*radius)
	shape.shape = capsule
	body.add_child(shape)
	add_child(body)
	ChaosShapes.capsule(body,Vector3.ZERO,radius,height,color)
	bodies[key] = body
	offsets[key] = at
	rest_angles[key] = 0.0
	if boss: body.add_to_group("chaos_grabbable")

func _joint(a: String, b: String, anchor: Vector3, origin: Vector3, yaw: float, limit: float):
	var joint = Generic6DOFJoint3D.new()
	add_child(joint)
	joint.global_position = origin + Basis(Vector3.UP,yaw)*anchor
	joint.node_a = joint.get_path_to(bodies[a])
	joint.node_b = joint.get_path_to(bodies[b])
	for axis in ["x","y","z"]:
		joint.call("set_flag_"+axis,Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT,true)
		joint.call("set_param_"+axis,Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT,0.0)
		joint.call("set_param_"+axis,Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT,0.0)
		joint.call("set_flag_"+axis,Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT,true)
		joint.call("set_param_"+axis,Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT,-limit)
		joint.call("set_param_"+axis,Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT,limit)
	joints.append(joint)

func reset_pose(origin: Vector3, yaw: float, sitting: bool):
	release_all()
	facing = yaw
	fallen = false
	fall_time = 0
	phase = 0
	lean = 0; gesture = ""; gesture_time = 0
	for key in bodies:
		var p: Vector3 = offsets[key]
		var angle = 0.0
		if sitting:
			if key.begins_with("thigh"):
				p = Vector3(p.x,.72,-.22); angle = PI/2
			elif key.begins_with("shin"): p = Vector3(p.x,.42,-.43)
			elif key.begins_with("foot"): p = Vector3(p.x,.16,-.49)
			elif key.begins_with("upper"): p += Vector3(0,-.02,-.11); angle = .55
			elif key.begins_with("lower"): p += Vector3(0,.07,-.28); angle = .65
			elif key.begins_with("hand"): p += Vector3(0,.17,-.37)
			else: p.y -= .08
		var body: RigidBody3D = bodies[key]
		body.global_transform = Transform3D(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,angle),origin+Basis(Vector3.UP,yaw)*p)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false
		body.reset_physics_interpolation()
	desired_velocity = Vector3.ZERO
	pushing = false
	seat_grace = 1.2

func sit(on_chair: RigidBody3D):
	detach_seat(false)
	chair = on_chair
	reset_pose(chair.global_position,chair.rotation.y,true)
	for body in bodies.values(): body.add_collision_exception_with(chair)
	seat_joint = PinJoint3D.new()
	add_child(seat_joint)
	seat_joint.global_position = bodies.pelvis.global_position
	seat_joint.node_a = seat_joint.get_path_to(chair)
	seat_joint.node_b = seat_joint.get_path_to(bodies.pelvis)
	seated = true
	seat_risk = 0; seat_acceleration = Vector3.ZERO
	previous_seat_velocity = chair.linear_velocity
	for body in bodies.values(): body.remove_from_group("chaos_grabbable")

func detach_seat(announce = true):
	if is_instance_valid(seat_joint):
		seat_joint.node_a = NodePath(); seat_joint.node_b = NodePath(); seat_joint.queue_free()
	seat_joint = null
	if is_instance_valid(chair):
		for body in bodies.values(): body.remove_collision_exception_with(chair)
	var was = seated
	seated = false
	seat_risk = 0
	for body in bodies.values():
		if boss and not body.is_in_group("chaos_grabbable"): body.add_to_group("chaos_grabbable")
	if was and announce: fell.emit()

func _seat_dynamics(delta: float):
	var velocity_change = chair.linear_velocity-previous_seat_velocity
	previous_seat_velocity = chair.linear_velocity
	seat_acceleration = seat_acceleration.lerp(velocity_change/maxf(delta,.001),1-exp(-delta/0.10))
	if seat_grace>0: return
	var local_accel = chair.global_basis.inverse()*seat_acceleration
	var angle = rad_to_deg(acos(clampf(chair.global_basis.y.dot(Vector3.UP),-1,1)))
	var turn_load = Vector2(chair.linear_velocity.x,chair.linear_velocity.z).length()*absf(chair.angular_velocity.y)
	var stress = maxf(0,maxf(absf(local_accel.x),turn_load)-ChaosTuning.SEAT_SIDE_ACCEL)
	stress += maxf(0,local_accel.z-ChaosTuning.SEAT_BRAKE_ACCEL)
	stress += maxf(0,angle-30)*.12
	seat_risk = clampf(seat_risk+(stress if stress>.05 else -2.0)*delta,0,1.5)
	var impact = velocity_change.length()>ChaosTuning.SEAT_COLLISION_DELTA and (chair.linear_velocity-velocity_change).length()>2.0
	if impact or seat_risk>ChaosTuning.SEAT_RISK_LIMIT or angle>58:
		var outward = chair.global_basis.x*signf(chair.angular_velocity.y)*minf(turn_load*.22,2)
		var throw_velocity = -seat_acceleration.limit_length(12)*.16+outward+Vector3.UP*1.3
		detach_seat()
		for body in bodies.values(): body.apply_central_impulse(throw_velocity*body.mass)

func _physics_process(delta):
	if not enabled or bodies.is_empty(): return
	seat_grace = maxf(0,seat_grace-delta)
	gesture_time = maxf(0,gesture_time-delta)
	if gesture_time<=0: gesture = ""
	var pelvis: RigidBody3D = bodies.pelvis
	var torso: RigidBody3D = bodies.torso
	phase += delta * (8.0+minf(desired_velocity.length(),8)*.8 if desired_velocity.length() > .15 else 1.0)
	if boss:
		if seated and is_instance_valid(chair):
			facing = chair.rotation.y
			_seat_dynamics(delta)
			if seated: _pose(true,delta)
		return
	var ray = PhysicsRayQueryParameters3D.create(pelvis.global_position,pelvis.global_position-Vector3(0,1.5,0),ChaosTuning.FLOOR)
	var ground = get_world_3d().direct_space_state.intersect_ray(ray)
	grounded = not ground.is_empty() and ground.normal.dot(Vector3.UP)>.65
	var tilt = rad_to_deg(acos(clampf(torso.global_basis.y.dot(Vector3.UP),-1,1)))
	fall_time = fall_time+delta if tilt > ChaosTuning.FALL_ANGLE else 0.0
	if fall_time > ChaosTuning.FALL_DELAY and not fallen:
		fallen = true; fell.emit()
	var recover = (bracing or pushing) and grounded
	if grounded and (not fallen or recover):
		var target_y: float = ground.position.y + (.80 if bracing and not fallen else .93)
		var force_y = (target_y-pelvis.global_position.y)*2600.0-pelvis.linear_velocity.y*280.0+588.0
		pelvis.apply_central_force(Vector3(0,clampf(force_y,-350,2400 if pushing else 1900),0))
		if recover and tilt < 28: fallen = false; fall_time = 0
	var velocity_error = desired_velocity-Vector3(pelvis.linear_velocity.x,0,pelvis.linear_velocity.z)
	if grounded: pelvis.apply_central_force((velocity_error*(340.0 if pushing else 310.0 if bracing else 65.0 if slippery else 210.0)).limit_length(1050.0 if pushing else 520.0 if bracing else 440.0))
	_pose(false,delta)
	_update_grips(delta)
	for body in bodies.values():
		body.linear_velocity = body.linear_velocity.limit_length(18)
		body.angular_velocity = body.angular_velocity.limit_length(22)

func _pose(sitting: bool, _delta: float):
	var moving = minf(desired_velocity.length()/ChaosTuning.WALK_SPEED,1.5)
	var base = Basis(Vector3.UP,facing)
	var local_velocity = base.inverse()*desired_velocity
	for key in bodies:
		var angle = 0.0
		var roll = 0.0
		var strength = 75.0
		if key == "torso":
			angle = clampf(-local_velocity.z*.065,-.35,.35) + sin(phase*.65)*.025 + lean
			roll = clampf(-local_velocity.x*.065,-.22,.22) + sin(phase*.4)*.035
			strength = 340.0 if pushing else 245.0 if bracing else 170.0
		elif key == "pelvis": strength = 280.0 if pushing else 200.0
		elif key == "head": strength = 18.0; angle = -.05
		elif key.begins_with("thigh"):
			angle = PI/2 if sitting else sin(phase+(PI if key.ends_with("r") else 0.0))*.52*moving
			strength = 48.0
		elif key.begins_with("shin"):
			angle = 0.0 if sitting else -maxf(0,sin(phase+(PI if key.ends_with("r") else 0.0)))*.55*moving
			strength = 32.0
		elif key.begins_with("foot"): strength = 18.0
		elif key.begins_with("upper") or key.begins_with("lower"):
			var index = 0 if key.ends_with("l") else 1
			angle = .65 if sitting else (.9 if grips[index]!=null else -sin(phase+PI*index)*.30*moving)
			strength = 32.0 if pushing else 19.0
			if sitting and gesture=="point" and index==0: angle = 1.5
			if sitting and gesture=="drink" and index==1: angle = 1.15 if key.begins_with("upper") else 1.7
		elif key.begins_with("hand"): strength = 4.0
		if fallen and not bracing: strength *= .08
		var target = base*Basis.from_euler(Vector3(angle,0,roll))
		var body: RigidBody3D = bodies[key]
		var error = (target*body.global_basis.inverse()).get_rotation_quaternion().normalized()
		if error.w < 0: error = -error
		var axis = Vector3(error.x,error.y,error.z)
		var torque = axis*strength*2.0-body.angular_velocity*sqrt(strength)*.65
		body.apply_torque(torque.limit_length(strength*1.5))

func try_grab(index: int, preferred: RigidBody3D = null) -> bool:
	if grips[index]!=null:
		release(index); return false
	var hand: RigidBody3D = bodies["hand_l" if index==0 else "hand_r"]
	var candidates = [preferred] if preferred != null else get_tree().get_nodes_in_group("chaos_grabbable")
	var best: RigidBody3D
	var best_anchor = Vector3.ZERO
	var distance = ChaosTuning.REACH
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.freeze: continue
		var anchors: Array = candidate.get_meta("grip_points",[Vector3.ZERO])
		for anchor in anchors:
			var point: Vector3 = candidate.global_transform*anchor
			var d = hand.global_position.distance_to(point)
			if d > distance: continue
			var query = PhysicsRayQueryParameters3D.create(hand.global_position,point,ChaosTuning.FLOOR|ChaosTuning.DOOR)
			var hit = get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider != candidate: continue
			distance = d; best = candidate; best_anchor = anchor
	if best == null: return false
	grips[index] = best
	grip_anchors[index] = best_anchor
	hand.add_collision_exception_with(best)
	grip_changed.emit()
	return true

func at_chair_back() -> bool:
	if fallen or not is_instance_valid(chair) or chair.global_basis.y.dot(Vector3.UP)<.65: return false
	var relative = chair.global_basis.inverse()*(center()-chair.global_position)
	return relative.z>.25 and relative.z<1.8 and absf(relative.x)<.95

func can_grab_handles() -> bool:
	if not at_chair_back(): return false
	var anchors = [Vector3(-.28,1.02,.30),Vector3(.28,1.02,.30)]
	for i in range(2):
		var hand: RigidBody3D = bodies["hand_l" if i==0 else "hand_r"]
		var point: Vector3 = chair.global_transform*anchors[i]
		if hand.global_position.distance_to(point)>ChaosTuning.HANDLE_REACH: return false
		var hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(hand.global_position,point,ChaosTuning.FLOOR|ChaosTuning.DOOR))
		if not hit.is_empty(): return false
	return true

func grab_handles() -> bool:
	if not can_grab_handles(): return false
	var anchors = [Vector3(-.28,1.02,.30),Vector3(.28,1.02,.30)]
	release_all()
	for i in range(2):
		grips[i] = chair; grip_anchors[i] = anchors[i]
		bodies["hand_l" if i==0 else "hand_r"].add_collision_exception_with(chair)
	grip_changed.emit()
	return true

func _update_grips(delta: float):
	for i in range(2):
		if not is_instance_valid(grips[i]):
			grips[i] = null; continue
		var hand: RigidBody3D = bodies["hand_l" if i==0 else "hand_r"]
		var other: RigidBody3D = grips[i]
		var point = other.global_transform*grip_anchors[i]
		var offset = point-hand.global_position
		var break_distance = ChaosTuning.PUSH_BREAK_DISTANCE if pushing and other==chair else ChaosTuning.BREAK_DISTANCE
		grip_strain[i] = clampf(offset.length()/break_distance,0,1)
		if offset.length()>break_distance:
			release(i); continue
		var other_velocity = other.linear_velocity+other.angular_velocity.cross(point-other.global_position)
		var force = (offset*650.0+(other_velocity-hand.linear_velocity)*24.0).limit_length(420 if pushing else 330)
		hand.apply_central_force(force)
		other.apply_force(-force,point-other.global_position)
		# The arm reaches towards the anchor; forces, rather than transforms, carry the load.
		var shoulder = bodies.torso.global_position + Basis(Vector3.UP,facing)*Vector3(-.34 if i==0 else .34,.12,0)
		var reach_target = shoulder + (point-shoulder).limit_length(.78)
		hand.apply_central_force(((reach_target-hand.global_position)*280.0-hand.linear_velocity*7.0).limit_length(170))
		if bracing and other == chair:
			other.apply_central_force(-Vector3(other.linear_velocity.x,0,other.linear_velocity.z)*40)

func release(index: int):
	if is_instance_valid(grips[index]):
		bodies["hand_l" if index==0 else "hand_r"].remove_collision_exception_with(grips[index])
	grips[index] = null
	grip_strain[index] = 0
	grip_changed.emit()

func release_all():
	for i in range(2): release(i)

func center() -> Vector3:
	return bodies.pelvis.global_position if not bodies.is_empty() else global_position
