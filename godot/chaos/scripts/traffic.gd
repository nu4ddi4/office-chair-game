class_name ChaosWalker
extends AnimatableBody3D

# A coworker walking a fixed corridor lane. Movement is scripted (no randomness):
# the walker paces between two points and steps aside toward the wall when the
# chair closes in. A fast driver arrives before the walker gets out of the way.

signal bumped
const COLORS = ["5d7f99","9a5f55","6b8a62","8a7a9e","b08a4f","4f6f78"]
var spec: Dictionary = {}
var chair: RigidBody3D
var x = 0.0
var dir = 1.0
var pause = 0.0
var dodge = 0.0
var step = 0.0
var bump_cooldown = 0.0
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var body_pivot: Node3D

func build(definition: Dictionary, target: RigidBody3D, index: int):
	spec = definition; chair = target
	name = "Coworker%d" % index
	collision_layer = ChaosTuning.OBJECT
	collision_mask = 0
	sync_to_physics = true
	ChaosShapes.collision(self,Vector3(.5,1.7,.34),Vector3(0,.85,0))
	body_pivot = Node3D.new(); add_child(body_pivot)
	var shirt = Color(COLORS[index%COLORS.size()])
	ChaosShapes.capsule(body_pivot,Vector3(0,1.12,0),.2,.56,shirt)
	ChaosShapes.capsule(body_pivot,Vector3(0,1.56,0),.16,.34,Color("d9b296"))
	ChaosShapes.capsule(body_pivot,Vector3(0,1.66,.02),.165,.18,Color("3b3029") if index%2 else Color("1f1c1a"))
	for side in [-1,1]:
		var leg = Node3D.new(); body_pivot.add_child(leg); leg.position = Vector3(side*.11,.86,0)
		ChaosShapes.capsule(leg,Vector3(0,-.42,0),.085,.84,Color("2f3b44"))
		legs.append(leg)
		var arm = Node3D.new(); body_pivot.add_child(arm); arm.position = Vector3(side*.27,1.34,0)
		ChaosShapes.capsule(arm,Vector3(0,-.25,0),.065,.5,shirt)
		arms.append(arm)
	match str(spec.get("carry","papers")):
		"box": ChaosShapes.box(body_pivot,Vector3(0,1.02,-.3),Vector3(.42,.3,.32),Color("b79669"))
		"mug": ChaosShapes.capsule(body_pivot,Vector3(.27,.96,-.12),.045,.1,Color("f3e9d4"))
		_: ChaosShapes.box(body_pivot,Vector3(0,1.06,-.24),Vector3(.3,.04,.24),Color("ece6d6"))
	restore()

func _lane() -> float: return float(spec.get("lane",1.6))

func restore():
	var a = float(spec.get("from",-10)); var b = float(spec.get("to",10))
	x = lerpf(a,b,float(spec.get("offset",0)))
	dir = 1.0 if b>=a else -1.0
	pause = 0; dodge = 0; step = 0; bump_cooldown = 0
	_place(_lane(),0.0)
	reset_physics_interpolation()

func _place(z: float, lean: float):
	global_transform = Transform3D(Basis(Vector3.UP,(-PI/2 if dir>0 else PI/2)+lean),Vector3(x,0,z))

func _physics_process(delta):
	if chair==null or spec.is_empty(): return
	var lane = _lane()
	var side = 1.0 if lane>=0 else -1.0
	var aside = side*3.7
	var rel = chair.global_position-global_position; rel.y = 0
	var distance = rel.length()
	var closing = -chair.linear_velocity.dot(rel/distance) if distance>.01 else 0.0
	var threat = distance<ChaosTuning.TRAFFIC_DODGE_RANGE and (closing>.4 or distance<1.7)
	dodge = move_toward(dodge,1.0 if threat else 0.0,ChaosTuning.TRAFFIC_DODGE_SPEED*delta/absf(aside-lane))
	var speed = float(spec.get("speed",1.1))
	var pace = 0.0 if pause>0 else (.25 if threat else 1.0)
	pause = maxf(0,pause-delta)
	x += dir*speed*pace*delta
	var a = float(spec.get("from",-10)); var b = float(spec.get("to",10))
	var low = minf(a,b); var high = maxf(a,b)
	if x>=high and dir>0: x = high; dir = -1; pause = 1.2
	elif x<=low and dir<0: x = low; dir = 1; pause = 1.2
	var z = lerpf(lane,aside,smoothstep(0,1,dodge))
	_place(z,-side*dir*.5*dodge)
	step += delta*(speed*pace*5.0+(3.0 if threat else 0.0))
	for i in range(2):
		var swing = sin(step+PI*i)*(.45 if pace>0 or threat else 0.0)
		legs[i].rotation.x = swing; arms[i].rotation.x = -swing*.6
	body_pivot.position.y = absf(sin(step))*.03
	bump_cooldown = maxf(0,bump_cooldown-delta)
	if distance<1.0 and chair.linear_velocity.length()>1.4 and bump_cooldown<=0:
		bump_cooldown = 2.5; bumped.emit()
