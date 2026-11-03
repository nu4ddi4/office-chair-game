class_name ChaosOffice
extends Node3D

signal prop_damaged(price: int)
var doors: Array[ChaosDoor] = []
var props: Array[ChaosProp] = []
var goal: Node3D
var goal_label: Label3D
var route_markers: Array[Node3D] = []
var wet: MeshInstance3D
var fan: Node3D
var fan_blades: Node3D
var coffee_points: Array[Vector3] = []
var clock = 0.0
var hazards = false
var detailed = false
var lights: Array[OmniLight3D] = []
var background_arms: Array[Node3D] = []

func build(blockout = false):
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://chaos/data/office_layout.json"))
	if not blockout and ResourceLoader.exists("res://assets/models/Office_Chaos.glb"):
		var scene = load("res://assets/models/Office_Chaos.glb").instantiate()
		add_child(scene)
		_import_collisions(scene)
		detailed = true
	else:
		ChaosShapes.box(self,Vector3(0,-.12,0),Vector3(60,.24,42),Color("343f44"),true)
		for wall in layout.walls:
			ChaosShapes.box(self,Vector3(wall.at[0],wall.at[1],wall.at[2]),Vector3(wall.size[0],wall.size[1],wall.size[2]),Color("a9b4b1"),true)
	for spec in layout.doors:
		var door = ChaosDoor.new(); add_child(door)
		door.build(Vector3(spec[0]-.8,0,spec[1]),0,1.6,true)
		doors.append(door)
	for zone in layout.zones:
		var sign_label = ChaosShapes.label(self,zone.name,Vector3(zone.at[0],2.75,5.3 if zone.at[1]>0 else -5.3),Color("f3d494"),36)
		sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	for station in layout.coffee_stations:
		var point = ChaosMissions.point(station)
		coffee_points.append(point)
		ChaosShapes.box(self,point+Vector3(-2,.48,0),Vector3(1.1,.95,.65),Color("8d7052"),true)
		ChaosShapes.box(self,point+Vector3(-2,1.12,0),Vector3(.55,.38,.42),Color("1f313b"))
		ChaosShapes.label(self,"커피 보충 · E",point+Vector3(-2,1.7,0),Color("f4ca78"),30)
	for i in range(12):
		var prop = ChaosProp.new(); add_child(prop)
		var x = [-21,-9,3,15,27][i%5]
		prop.build(Vector3(x,.3,-2.8 if i<6 else 3.0),i%2)
		prop.damaged.connect(func(price): prop_damaged.emit(price))
		props.append(prop)
	wet = ChaosShapes.box(self,Vector3(15,.012,0),Vector3(10,.012,3.5),Color(.38,.61,.66,.65))
	wet.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.material_override.roughness = .12
	ChaosShapes.label(self,"청소 중 · 미끄럼 주의",Vector3(11,1.5,2.5),Color("f4ca78"),32)
	fan = Node3D.new(); add_child(fan); fan.position = Vector3(28,0,-8)
	ChaosShapes.box(fan,Vector3(0,.7,0),Vector3(.25,1.4,.25),Color("5c6868"))
	ChaosShapes.box(fan,Vector3(0,.08,0),Vector3(.8,.15,.8),Color("414f56"))
	fan_blades = Node3D.new(); fan.add_child(fan_blades); fan_blades.position.y = 1.5
	for i in range(3):
		var blade = ChaosShapes.box(fan_blades,Vector3.ZERO,Vector3(.10,1.2,.10),Color("b6c1be"))
		blade.rotation.z = TAU*i/3.0
	ChaosShapes.label(self,"송풍 구간 →",Vector3(24,2.5,-6),Color("f4ca78"),36)
	goal = Node3D.new(); add_child(goal)
	var ring = TorusMesh.new(); ring.inner_radius = 1.1; ring.outer_radius = 1.25
	var marker = MeshInstance3D.new(); marker.mesh = ring; marker.material_override = ChaosShapes.material(Color("edbd5c"))
	goal.add_child(marker); marker.position.y = .025
	goal_label = ChaosShapes.label(goal,"",Vector3(0,2.2,0),Color("ffe2a1"),42)
	goal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	for index in [0,8,17]:
		var point: Array = layout.desks[index]
		_background_worker(Vector3(point[0],0,point[1]+.85))
	_lighting()
	var exterior = load("res://scripts/exterior.gd").new()
	add_child(exterior)
	for child in exterior.get_children():
		if str(child.name) in ["OfficeSlabAndStructure","InteriorSills","MetalTrims","Mullions","ShadowGapsAndSpandrels","SillDrains"]: child.queue_free()

func _import_collisions(node: Node):
	if node is MeshInstance3D and (str(node.name).begins_with("STATIC_") or str(node.name).begins_with("COLLIDER_")):
		var body = StaticBody3D.new()
		body.collision_layer = ChaosTuning.FLOOR
		node.add_child(body)
		var bounds: AABB = node.mesh.get_aabb()
		ChaosShapes.collision(body,bounds.size,bounds.get_center())
		if str(node.name).begins_with("COLLIDER_"): node.hide()
	for child in node.get_children(): _import_collisions(child)

func _lighting():
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("73878e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d1e2e4")
	environment.environment.ambient_light_energy = .45
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun = DirectionalLight3D.new(); add_child(sun)
	sun.rotation_degrees = Vector3(-52,-30,0); sun.light_color = Color("ffe0b0"); sun.light_energy = .65
	sun.shadow_enabled = true
	for x in [-24,-12,0,12,24]:
		for z in [-13,0,13]:
			var lamp = OmniLight3D.new(); add_child(lamp)
			lamp.position = Vector3(x,3.1,z); lamp.omni_range = 11; lamp.light_energy = .65
			lamp.light_color = Color("f3eddd"); lights.append(lamp)
			ChaosShapes.box(self,Vector3(x,3.25,z),Vector3(1.6,.04,.5),Color("fff3d7"))

func set_goal(point: Vector3, title: String):
	goal.position = point
	goal_label.text = title

func restore():
	for door in doors: door.restore()
	for prop in props: prop.restore()
	clock = 0

func _physics_process(delta):
	clock += delta
	for i in range(background_arms.size()): background_arms[i].rotation.x = .9+sin(clock*3+i)*.035
	fan_blades.rotation.z += delta*(22 if hazards else 0)
	wet.visible = hazards
	fan.visible = hazards

func apply_hazards(actor: ChaosRagdoll, chair: ChaosChair):
	var at = chair.global_position
	if not actor.boss: chair.slippery = hazards and at.x>10 and at.x<20 and absf(at.z)<2
	var actor_at = actor.center()
	actor.slippery = hazards and actor_at.x>10 and actor_at.x<20 and absf(actor_at.z)<2
	if hazards and actor.center().x>21 and actor.center().x<27 and actor.center().z<-5 and actor.center().z>-11:
		var pulse = maxf(0,sin(clock*1.2))
		for body in actor.bodies.values(): body.apply_central_force(Vector3.LEFT*body.mass*2.8*pulse)
		if not actor.boss: chair.apply_central_force(Vector3.LEFT*35*pulse)

func update_distance(at: Vector3):
	for prop in props:
		var far = prop.global_position.distance_to(at)>24
		if far!=prop.freeze:
			prop.freeze = far
			if not far: prop.sleeping = false
	for lamp in lights: lamp.visible = lamp.position.distance_to(at)<26


func _background_worker(at: Vector3):
	var worker = Node3D.new(); add_child(worker); worker.position = at
	ChaosShapes.capsule(worker,Vector3(0,1.08,0),.19,.5,Color("66777c"))
	ChaosShapes.capsule(worker,Vector3(0,1.52,0),.17,.36,Color("d9b296"))
	ChaosShapes.capsule(worker,Vector3(0,1.64,.01),.17,.19,Color("3b3029"))
	for side in [-1,1]:
		ChaosShapes.capsule(worker,Vector3(side*.14,.55,-.18),.085,.4,Color("36464e"))
		ChaosShapes.capsule(worker,Vector3(side*.14,.30,-.35),.07,.39,Color("36464e"))
		var arm = Node3D.new(); worker.add_child(arm); arm.position = Vector3(side*.27,1.2,0)
		ChaosShapes.capsule(arm,Vector3(0,-.20,0),.07,.42,Color("66777c"))
		background_arms.append(arm)
