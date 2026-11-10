class_name ChaosClutter
extends Node3D

# Desk-top props (phones, mugs, papers, binders ...) are static scenery until a
# chair slams into their desk. Then they wake up as small rigid bodies, fly off
# in the direction of the hit, settle and freeze where they land. Only a few are
# awake at a time so the active-body budget holds. Checkpoint restore puts every
# prop back exactly where it was.

signal damaged(price: int)
signal knocked(speed: float)
const KINDS = {
	"Phone": {"mass": .9, "price": 15000},
	"Mug": {"mass": .35, "price": 3000},
	"PenCup": {"mass": .3, "price": 1000},
	"vintage_stapler": {"mass": .4, "price": 2000},
	"Clipboard": {"mass": .3, "price": 0},
	"binder_notebook": {"mass": .5, "price": 0},
	"Document": {"mass": .1, "price": 0},
	"BinderRow": {"mass": 1.6, "price": 0},
}
const MAX_AWAKE = 12
var desks: Array = []   # {"bounds": AABB}
var items: Array = []   # {"mesh","parent","xform","desk","kind","body","since","settled"}
var knocks = 0

# Desk colliders cover the monitors too (1.48 m tall), which would bury the props.
# Split each into the desk slab (up to the desk top) and a strip behind the screens.
func desk_collision(node: MeshInstance3D, body: StaticBody3D) -> bool:
	var bounds: AABB = node.global_transform*node.mesh.get_aabb()
	var group = node.get_parent()
	var screens = group.find_children("*Screen*","MeshInstance3D",true,false)
	if screens.is_empty() or bounds.size.y<1.0: return false
	var top = ChaosTuning.DESK_TOP
	var slab = AABB(bounds.position,Vector3(bounds.size.x,top-bounds.position.y,bounds.size.z))
	var strip = AABB()
	for i in range(screens.size()):
		var box: AABB = screens[i].global_transform*screens[i].mesh.get_aabb()
		strip = box if i==0 else strip.merge(box)
	strip = strip.grow(.04)
	strip.position.y = top; strip.size.y = bounds.end.y-top
	var inverse = node.global_transform.affine_inverse()
	for box in [slab,strip]:
		ChaosShapes.collision(body,box.size,inverse*box.get_center())
	body.set_meta("desk",desks.size())
	desks.append({"bounds":slab})
	return true

func collect(scene: Node):
	for node in scene.find_children("DECOR_Chaos_*","MeshInstance3D",true,false):
		var kind = _kind(str(node.name))
		if kind.is_empty(): continue
		var at: Vector3 = node.global_position
		if at.y<ChaosTuning.DESK_TOP-.04 or at.y>ChaosTuning.DESK_TOP+.08: continue
		for d in range(desks.size()):
			var b: AABB = desks[d].bounds
			if at.x>b.position.x-.05 and at.x<b.end.x+.05 and at.z>b.position.z-.05 and at.z<b.end.z+.05:
				items.append({"mesh":node,"parent":node.get_parent(),"xform":node.global_transform,"desk":d,"kind":kind,"body":null,"since":0.0,"settled":false})
				break

func _kind(name: String) -> String:
	for kind in KINDS:
		if name.begins_with("DECOR_Chaos_"+kind+"_"): return kind
	return ""

func awake_count() -> int:
	var count = 0
	for item in items:
		if item.body!=null and not item.settled: count += 1
	return count

func knock(desk: int, velocity: Vector3):
	var speed = Vector3(velocity.x,0,velocity.z).length()
	if speed<ChaosTuning.CLUTTER_KNOCK_SPEED: return
	knocks += 1
	knocked.emit(speed)
	var rng = RandomNumberGenerator.new(); rng.seed = 7919*knocks+desk
	var direction = Vector3(velocity.x,0,velocity.z).normalized()
	for item in items:
		if item.desk!=desk or item.body!=null: continue
		if awake_count()>=MAX_AWAKE: _settle_oldest()
		var spec: Dictionary = KINDS[item.kind]
		var body = RigidBody3D.new(); add_child(body)
		body.mass = spec.mass
		body.collision_layer = ChaosTuning.OBJECT
		body.collision_mask = ChaosTuning.FLOOR|ChaosTuning.OBJECT|ChaosTuning.ACTOR
		body.continuous_cd = true
		body.linear_damp = .1; body.angular_damp = .4
		var mesh: MeshInstance3D = item.mesh
		body.global_transform = mesh.global_transform
		mesh.reparent(body,true)
		var box: AABB = mesh.mesh.get_aabb()
		ChaosShapes.collision(body,Vector3(maxf(box.size.x,.03),maxf(box.size.y,.02),maxf(box.size.z,.03)),box.get_center())
		var push = speed*rng.randf_range(.35,.8)
		body.linear_velocity = direction*push+Vector3.UP*minf(speed,4)*rng.randf_range(.25,.6)+Vector3(rng.randf_range(-.4,.4),0,rng.randf_range(-.4,.4))
		body.angular_velocity = Vector3(rng.randf_range(-8,8),rng.randf_range(-6,6),rng.randf_range(-8,8))
		item.body = body; item.since = 0.0; item.settled = false
		if int(spec.price)>0 and speed>=ChaosTuning.CLUTTER_BREAK_SPEED: damaged.emit(int(spec.price))

func _settle_oldest():
	var oldest = null
	for item in items:
		if item.body!=null and not item.settled and (oldest==null or item.since>oldest.since): oldest = item
	if oldest!=null: _settle(oldest)

func _settle(item: Dictionary):
	item.settled = true
	item.body.freeze = true

func _physics_process(delta):
	for item in items:
		if item.body==null or item.settled: continue
		item.since += delta
		var body: RigidBody3D = item.body
		if body.global_position.y< -2 or (item.since>.6 and (body.sleeping or body.linear_velocity.length()<.04)) or item.since>8:
			_settle(item)

func restore():
	for item in items:
		if item.body==null: continue
		var mesh: MeshInstance3D = item.mesh
		mesh.reparent(item.parent,false)
		mesh.global_transform = item.xform
		item.body.queue_free()
		item.body = null; item.settled = false
	knocks = 0
