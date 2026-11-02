class_name OfficeStageWorld
extends Node3D

class PrintTarget extends InvestigationTarget:
	var action_text = ""
	var reach = 1.5
	var half_size = Vector3(.25,.25,.25)
	var actor: LabPlayer
	func reachable() -> bool:
		var point = to_local(actor.camera.global_position)
		if point.distance_to(point.clamp(-half_size,half_size)) > reach: return false
		var query = PhysicsRayQueryParameters3D.create(actor.camera.global_position,global_position,6,[actor.get_rid()])
		query.collide_with_areas = true
		var hit = actor.get_world_3d().direct_space_state.intersect_ray(query)
		return not hit.is_empty() and hit.collider == self
	func get_interaction_prompt() -> String:
		return label+"\n"+("F — "+action_text if reachable() else "가까이 다가가세요")

var game: InvestigationPrototype
var key = ""
var layout: Dictionary
var printer: Node3D
var chair: AnimatableBody3D
var pile_bodies: Array[AnimatableBody3D] = []
var pile_meshes: Array[MeshInstance3D] = []
var pile_shapes: Array[BoxShape3D] = []
var cart_steps: Array[StaticBody3D] = []
var cart_rails: Array[MeshInstance3D] = []
var sheet: Node3D
var held_sheet: Node3D
var delivered_sheet: Node3D
var trailing_bundle: Node3D
var brake_pad: MeshInstance3D
var status_text: Label3D
var light_material: StandardMaterial3D
var particles: Array[MeshInstance3D] = []
var print_targets: Dictionary = {}
var roller: AudioStreamPlayer3D
var scene_time = -1.0
var stack_time = 0.0
var tail_time = -1.0
var trailing_time = -1.0
var scene_cue = false
var last_job = "none"
var visual_signature = ""
var active_time = 0.0
var idle_notice = false
var origin = Vector3.ZERO
var busy_sound: AudioStreamWAV
var paper_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var casing_material: StandardMaterial3D
var steel_material: StandardMaterial3D

func vec(values: Array) -> Vector3: return Vector3(values[0],values[1],values[2])
func point(id: String) -> Vector3: return vec(layout[id])

func setup(owner: InvestigationPrototype):
	game = owner
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://prototype/content/print_layout.json"))
	origin = vec(layout.dummy_origin)
	if game.detailed_world:
		origin = game.investigation_environment.anchors[layout.anchor].global_position+vec(layout.offset)
	global_position = origin
	rotation.y = deg_to_rad(layout.yaw)
	for target in game.targets.values(): target.collision_layer = 0
	paper_material = material(Color("e9e7df"))
	dark_material = material(Color("1a252c"))
	casing_material = material(Color("d5d9d8"))
	steel_material = material(Color("6c7e84"),.65)
	build_printer()
	build_console()
	build_piles()
	build_cart()
	build_delivery()
	build_chairs()
	build_person()
	held_sheet = make_sheet(game.player.camera,Vector3(.38,-.31,-.85))
	held_sheet.scale = Vector3.ONE*.55
	held_sheet.rotation_degrees = Vector3(65,-10,-8)
	held_sheet.hide()
	busy_sound = synth(110,.4,.055,true)
	roller = AudioStreamPlayer3D.new()
	printer.add_child(roller)
	roller.position = Vector3(0,1,0)
	roller.stream = busy_sound
	roller.bus = "SFX"
	roller.unit_size = 3.5
	roller.max_distance = 18
	roller.volume_db = -26
	game.player.empty_interaction_requested.connect(drop_form)

func material(color: Color, metallic = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .75
	m.metallic = metallic
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	n.position = pos
	return n

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	n.position = pos
	return n

func solid(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.collision_layer = 5
	body.collision_mask = 0
	parent.add_child(body)
	body.position = pos
	collision(body,size)
	return body

func collision(body: CollisionObject3D, size: Vector3) -> BoxShape3D:
	var shape = CollisionShape3D.new()
	var bounds = BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	body.add_child(shape)
	return bounds

func lettering(parent: Node3D, text: String, pos: Vector3, scale_factor = .0028, ink = Color("1e3038")) -> Label3D:
	var label = Label3D.new()
	parent.add_child(label)
	label.position = pos
	label.text = text
	label.font = load("res://assets/fonts/NotoSansKR.ttf")
	label.font_size = 36
	label.pixel_size = scale_factor
	label.modulate = ink
	label.outline_size = 0
	label.no_depth_test = false
	return label

func target(id: String, label: String, action: String, pos: Vector3, size: Vector3, reach: float, parent: Node3D = null) -> PrintTarget:
	if parent == null: parent = self
	var t = PrintTarget.new()
	t.logical_id = id
	t.kind = "print"
	t.label = label
	t.action_text = action
	t.reach = reach
	t.half_size = size*.5
	t.actor = game.player
	t.collision_layer = 2
	t.collision_mask = 0
	parent.add_child(t)
	t.position = pos
	collision(t,size)
	t.used.connect(game._use)
	game.targets[id] = t
	print_targets[id] = t
	return t

func build_printer():
	printer = Node3D.new()
	add_child(printer)
	printer.position = point("printer")
	box(printer,Vector3(0,.72,0),Vector3(1.35,1.42,1.13),casing_material)
	solid(printer,Vector3(0,.72,0),Vector3(1.35,1.44,1.13))
	box(printer,Vector3(0,.12,.02),Vector3(1.4,.13,1.17),dark_material)
	for y in [.38,.73,1.08]:
		box(printer,Vector3(0,y,.578),Vector3(1.19,.29,.035),casing_material)
		box(printer,Vector3(0,y+.07,.61),Vector3(.52,.035,.055),dark_material)
		box(printer,Vector3(0,y-.15,.603),Vector3(1.22,.012,.012),steel_material)
	box(printer,Vector3(0,1.5,-.06),Vector3(1.48,.17,1.25),dark_material)
	box(printer,Vector3(0,1.64,-.12),Vector3(1.38,.12,1.08),casing_material)
	box(printer,Vector3(0,1.39,.65),Vector3(1.12,.10,.23),dark_material)
	box(printer,Vector3(-.42,2.12,-.36),Vector3(.28,.85,.32),casing_material)
	box(printer,Vector3(.42,2.12,-.36),Vector3(.28,.85,.32),casing_material)
	box(printer,Vector3(0,2.12,-.49),Vector3(.65,.80,.08),dark_material)
	for i in range(5): box(printer,Vector3(0,1.85+i*.14,-.435),Vector3(.61,.045,.025),steel_material)
	box(printer,Vector3(0,2.57,-.20),Vector3(1.34,.10,.9),dark_material)
	box(printer,Vector3(0,2.63,-.43),Vector3(1.28,.06,.4),casing_material)
	lettering(printer,"PR-01",Vector3(-.31,1.83,.439),.0022)
	status_text = lettering(printer,"READY",Vector3(.30,1.72,.449),.0016,Color("29c7af"))
	light_material = material(Color("32b9a4"))
	light_material.emission_enabled = true
	light_material.emission = Color("32b9a4")
	box(printer,Vector3(.55,1.73,.40),Vector3(.06,.05,.04),light_material)
	for x in [-.55,.55]:
		for z in [-.45,.45]: cylinder(printer,Vector3(x,.07,z),.065,.13,dark_material)
	box(self,point("pedal")-Vector3(0,.17,0),Vector3(.44,.12,.5),dark_material)
	box(self,point("pedal")-Vector3(0,.09,0),Vector3(.34,.07,.38),material(Color("d9a43d")))
	lettering(self,"일시정지",point("pedal")+Vector3(0,-.04,.15),.0011)
	target("print_pause","PR-01", "일시정지",point("pedal"),Vector3(.48,.4,.55),1.6)
	print_targets.print_pause.action_text = "일시정지"
	sheet = make_sheet(printer,Vector3(0,2.65,.03))
	target("print_form","퇴근 신청서","회수",Vector3(0,2.68,.03),Vector3(.64,.08,.55),.95,printer)
	for i in range(10):
		var n = box(printer,Vector3.ZERO,Vector3(.23,.009,.32),paper_material)
		particles.append(n)
	trailing_bundle = Node3D.new()
	printer.add_child(trailing_bundle)
	for i in range(5):
		box(trailing_bundle,Vector3((i%2)*.015,i*.018,0),Vector3(.7,.015,.42),paper_material)
	trailing_bundle.hide()

func build_console():
	var desk = Node3D.new()
	add_child(desk)
	desk.position = point("console")
	box(desk,Vector3(0,.82,0),Vector3(1.30,.08,.82),material(Color("a99f8b")))
	solid(desk,Vector3(0,.42,0),Vector3(1.30,.86,.82))
	for x in [-.55,.55]: box(desk,Vector3(x,.4,0),Vector3(.065,.8,.66),steel_material)
	box(desk,Vector3(0,1.27,-.13),Vector3(.98,.58,.07),dark_material)
	box(desk,Vector3(0,1.27,-.085),Vector3(.9,.49,.018),material(Color("07191b")))
	box(desk,Vector3(0,.96,-.13),Vector3(.06,.21,.06),steel_material)
	box(desk,Vector3(0,.87,-.13),Vector3(.37,.035,.25),dark_material)
	box(desk,Vector3(0,.88,.20),Vector3(.63,.035,.22),dark_material)
	for row in range(3):
		for col in range(10): box(desk,Vector3(-.27+col*.058,.902,.13+row*.06),Vector3(.045,.012,.04),steel_material)
	lettering(desk,"PR-01 / LOCAL\n\nREADY\noperator@print:~$",Vector3(0,1.27,-.068),.0013,Color("83d5bd"))
	target("print_console","출력 단말","터미널",Vector3(0,1.24,-.02),Vector3(.98,.65,.20),2.4,desk)

func build_piles():
	for i in range(3):
		var body = AnimatableBody3D.new()
		body.collision_layer = 5
		body.collision_mask = 0
		body.sync_to_physics = false
		add_child(body)
		body.position = vec(layout.piles[i])+Vector3(0,.02,0)
		pile_shapes.append(collision(body,Vector3(1.12,.025,1.02)))
		var mesh = box(body,Vector3.ZERO,Vector3(1.12,1,1.02),paper_material)
		mesh.scale.y = .025
		pile_meshes.append(mesh)
		pile_bodies.append(body)
		for side in [-1,1]:
			box(self,vec(layout.piles[i])+Vector3(side*.57,.045,0),Vector3(.025,.09,1.08),steel_material)
		# Thin dark lines make each slab read as stacked paper, without hundreds of bodies.
		for row in range(12):
			var line = box(body,Vector3(0,0,.514),Vector3(1.10,.006,.005),material(Color("9b9e98")))
			line.set_meta("paper_row",row)

func build_cart():
	var base = point("cart")
	for x in [-.38,.38]:
		cart_rails.append(box(self,base+Vector3(x,1.05,.1),Vector3(.035,.035,2.7),steel_material))
		for z in [-1.2,1.4]: cart_rails.append(box(self,base+Vector3(x,.54,z),Vector3(.035,1.02,.035),steel_material))
	for i in range(3):
		var step = solid(self,base+Vector3(0,.175*(i+1),1.7-i*.85),Vector3(.85,.35*(i+1),.73))
		box(step,Vector3(0,.175*(i+1)-.025,0),Vector3(.86,.05,.74),material(Color("b3b8b3")))
		cart_steps.append(step)
	box(self,base+Vector3(0,.18,2.15),Vector3(.8,.30,.16),dark_material)
	target("print_cart","점검 발판차","펼치기",base+Vector3(0,.5,1.95),Vector3(.8,.6,.4),1.8)

func build_delivery():
	var table = Node3D.new()
	add_child(table)
	table.position = point("delivery")
	box(table,Vector3(0,.84,0),Vector3(.78,.06,.85),material(Color("a99f8b")))
	solid(table,Vector3(0,.42,0),Vector3(.78,.86,.85))
	for x in [-.32,.32]: box(table,Vector3(x,.4,0),Vector3(.04,.8,.69),steel_material)
	box(table,Vector3(0,.89,0),Vector3(.50,.045,.62),dark_material)
	lettering(table,"결재 서류\n접수함",Vector3(0,1.17,-.27),.0020)
	box(table,Vector3(0,1.17,-.30),Vector3(.7,.43,.025),casing_material)
	delivered_sheet = make_sheet(table,Vector3(0,.93,0))
	target("print_delivery","결재 서류 접수함","서류 놓기",Vector3(0,1.0,.03),Vector3(.68,.45,.65),1.5,table)

func build_chairs():
	chair = AnimatableBody3D.new()
	chair.collision_layer = 5
	chair.collision_mask = 0
	chair.sync_to_physics = false
	add_child(chair)
	chair.position = point("chair_start")
	var shape = CollisionShape3D.new()
	var bounds = BoxShape3D.new()
	bounds.size = Vector3(.66,.85,.66)
	shape.shape = bounds
	shape.position.y = .44
	chair.add_child(shape)
	make_chair(chair)
	brake_pad = box(chair,Vector3(.42,.16,.20),Vector3(.18,.07,.28),material(Color("d9a43d")))
	target("print_brake","의자 브레이크","잠그기",Vector3(.4,.30,.2),Vector3(.3,.5,.35),1.6,chair)
	var end = point("chair_end")
	for x in [-.4,.4]: box(self,end+Vector3(x,.7,.42),Vector3(.045,1.4,.055),steel_material)
	box(self,end+Vector3(0,1.4,.42),Vector3(.85,.045,.055),steel_material)

func make_chair(parent: Node3D):
	if game.detailed_world:
		var source = game.world.model.find_child("CORP_Staff_Chair_13",true,false)
		if source != null:
			var copy = source.duplicate(0)
			parent.add_child(copy)
			copy.position = Vector3.ZERO
			return
	box(parent,Vector3(0,.48,0),Vector3(.57,.10,.53),dark_material)
	box(parent,Vector3(0,.83,-.22),Vector3(.58,.61,.08),dark_material)
	cylinder(parent,Vector3(0,.27,0),.045,.4,steel_material)
	for i in range(5):
		var leg = Node3D.new()
		parent.add_child(leg)
		leg.rotation.y = i*TAU/5
		box(leg,Vector3(0,.10,.19),Vector3(.035,.04,.37),steel_material)
		var wheel = cylinder(leg,Vector3(0,.07,.36),.065,.045,dark_material)
		wheel.rotation.x = PI/2

func build_person():
	if game.detailed_world:
		var old = game.investigation_environment.model.find_child("NPC_seo",true,false)
		if old != null:
			var copy = old.duplicate(0)
			for body in copy.find_children("*","PhysicsBody3D",true,false): body.free()
			add_child(copy)
			copy.position = point("seo")
			copy.rotation.y = .35
			old.hide()
			for body in old.find_children("*","PhysicsBody3D",true,false): body.collision_layer = 0
	else:
		box(self,point("seo")+Vector3(0,.8,0),Vector3(.5,1.6,.4),material(Color("526b70")))
	var npc = target("print_seo","서유진 · 정비 담당","대화",point("seo")+Vector3(0,1,0),Vector3(.65,1.7,.55),2.4)
	npc.kind = "npc"
	solid(self,point("seo")+Vector3(0,.85,0),Vector3(.55,1.7,.45))

func make_sheet(parent: Node3D, pos: Vector3) -> Node3D:
	var paper = Node3D.new()
	parent.add_child(paper)
	paper.position = pos
	box(paper,Vector3.ZERO,Vector3(.42,.012,.55),paper_material)
	var words = lettering(paper,"퇴근 신청서\n\n신청인: 신입사원\n\n결재: 미접수",Vector3(0,.009,0),.00082)
	words.rotation.x = -PI/2
	return paper

func prepare_stage():
	var current = str(game.state.stage.attempt)
	if key == current: return
	key = current
	var p = game.state.stage.print
	scene_time = 4.1 if p.seen else -1
	stack_time = 0
	tail_time = -1
	trailing_time = 1 if p.tail else -1
	last_job = p.job
	active_time = 0
	idle_notice = false
	visual_signature = ""
	chair.position = point("chair_end") if p.seen and not p.braked else point("chair_start")
	for i in range(3): set_pile(i,.35*(i+1) if p.stacks > i else .025)
	game.player.global_position = to_global(vec(layout.spawn))
	game.player.velocity = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	var direction = print_targets.print_console.global_position-game.player.global_position
	game.player.rotation.y = atan2(-direction.x,-direction.z)
	game.player.camera.look_at(print_targets.print_console.global_position)
	sync_visuals()

func use(id: String):
	if not print_targets.has(id): return
	var t = print_targets[id]
	if not t.reachable(): game.ui.notice("조금 더 가까이 다가가세요."); return
	match id:
		"print_seo": game.ui.talk_to(id); return
		"print_console": game.ui.open_terminal(); return
		"print_pause": event("pause")
		"print_brake": event("brake"); tone(260,.08)
		"print_cart": event("cart"); tone(180,.16)
		"print_form": event("take",true); tone(620,.08)
		"print_delivery":
			if game.state.stage.print.document == "held": event("deliver",true)
			finish()
	sync_visuals()

func event(id: String, reachable = false) -> Dictionary:
	return game.dispatch({"type":"print.event","payload":{"event":id,"reachable":reachable}})

func drop_form():
	if game.ui.mode != "field" or game.state.stage.print.document != "held": return
	event("drop")
	game.ui.notice("서류를 상부 트레이에 올려 두었습니다.")
	sync_visuals()

func finish():
	if not TerminalStagesEngine.ready_to_finish(game.state.stage): return
	if game.commit_stage_transition({"type":"print.finish"}):
		tone(740,.18)
		game.ui.command_result({"code":"STAGE_CLEAR"})

func sync_visuals():
	var p = game.state.stage.print
	var signature = JSON.stringify(p)
	if signature == visual_signature: return
	visual_signature = signature
	sheet.visible = p.document == "tray"
	held_sheet.visible = p.document == "held"
	delivered_sheet.visible = p.document == "delivered"
	print_targets.print_form.collision_layer = 2 if sheet.visible else 0
	print_targets.print_delivery.collision_layer = 2 if p.document in ["held","delivered"] else 0
	print_targets.print_delivery.action_text = "완료 확인" if p.document == "delivered" else "서류 놓기 / 출력 종료"
	print_targets.print_pause.collision_layer = 2 if p.job in ["running","paused"] else 0
	print_targets.print_pause.action_text = "출력 재개" if p.job == "paused" else "일시정지"
	print_targets.print_brake.action_text = "풀기" if p.braked else "잠그기"
	print_targets.print_cart.action_text = "펼쳐짐" if p.cart else "펼치기"
	brake_pad.rotation.x = -.3 if p.braked else 0.0
	for i in range(3):
		cart_steps[i].visible = p.cart
		cart_steps[i].collision_layer = 5 if p.cart else 0
	for rail in cart_rails: rail.visible = p.cart
	status_text.text = "READY" if p.job == "none" else p.job.to_upper()
	light_material.emission = Color("e1ae48") if p.job == "paused" else Color("32b9a4")
	if p.job != last_job:
		if p.job == "running" and last_job == "none": tone(760,.12)
		last_job = p.job

func set_pile(i: int, height: float):
	pile_bodies[i].position.y = height*.5+.015
	pile_shapes[i].size.y = height
	pile_meshes[i].scale.y = height
	for child in pile_bodies[i].get_children():
		if child is MeshInstance3D and child.has_meta("paper_row"):
			child.position.y = -height*.5+height*(float(child.get_meta("paper_row"))+1)/13

func _physics_process(delta):
	if game == null or game.ui == null or game.ui.root == null: return
	var active = game.ui.mode == "field" and game.player.enabled and game.state.stage.phase == "playing" and game.player.application_focused
	if is_instance_valid(roller):
		if active and game.state.stage.print.job == "running":
			if not roller.playing: roller.play()
			roller.stream_paused = false
		else: roller.stream_paused = true
	if not active: return
	active_time += delta
	sync_visuals()
	var p = game.state.stage.print
	if not idle_notice:
		idle_notice = true
		game.ui.notice("서유진: 퇴근 신청서 한 장만 뽑아 주세요.")
	if p.job == "running":
		if not p.seen:
			event("scene")
			scene_time = 0
			scene_cue = false
		stack_time += delta
		if stack_time >= 1.5 and p.stacks < 3:
			stack_time -= 1.5
			event("stack")
		if scene_time >= 0 and not p.braked: scene_time += delta
		if not p.braked and scene_time > 1.5:
			var motion = clampf((scene_time-1.5)/1.7,0,1)
			chair.position = point("chair_start").lerp(point("chair_end"),motion)
			if motion >= 1 and not scene_cue:
				scene_cue = true
				tone(130,.15)
			if chair.global_position.distance_to(game.player.global_position+Vector3(0,.4,0)) < .9:
				game.player.move_and_collide(global_basis*Vector3(.35,0,.3)*delta)
	if p.job in ["paused","cancelled"] and not p.tail:
		if tail_time < 0: tail_time = 0
		tail_time += delta
		if tail_time >= .55:
			event("tail")
			trailing_time = 0
			tone(100,.16)
	for i in range(3):
		var desired = .35*(i+1) if p.stacks > i else .025
		var h = move_toward(pile_shapes[i].size.y,desired,delta*.65)
		set_pile(i,h)
	for i in range(particles.size()):
		var n = particles[i]
		n.visible = p.job == "running"
		var f = fmod(active_time*.65+i*.13,1.0)
		n.position = Vector3(sin(i*2.1)*.12,1.39-f*1.26,.7+f*1.4)
		n.rotation = Vector3(f*.5,sin(i)*.15,f*.3)
	if trailing_time >= 0:
		trailing_time = minf(1.0,trailing_time+delta)
		trailing_bundle.show()
		trailing_bundle.position = Vector3(0,lerpf(1.4,.07,trailing_time),.8+trailing_time*.9)
		trailing_bundle.rotation.x = trailing_time*.18
		if trailing_time-delta < .9 and trailing_time >= .9:
			game.ui.notice("서유진: 한 장은 한 장인데, 배송을 여러 번 하네요.")
	if game.player.global_position.y < -.5:
		game.player.global_position = to_global(vec(layout.spawn))
		game.player.velocity = Vector3.ZERO

func synth(frequency: float, duration: float, noise = 0.0, loop = false) -> AudioStreamWAV:
	var data = PackedByteArray()
	var count = int(22050*duration)
	data.resize(count*2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 411
	for i in range(count):
		var envelope = 1.0 if loop else pow(1.0-float(i)/count,2)
		var value = (sin(TAU*frequency*i/22050)*.25+rng.randf_range(-noise,noise))*envelope
		data.encode_s16(i*2,int(value*18000))
	var sound = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	sound.data = data
	if loop:
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_end = count
	return sound

func tone(frequency: float, duration: float):
	var sound = AudioStreamPlayer3D.new()
	printer.add_child(sound)
	sound.position = Vector3(0,1.2,.3)
	sound.stream = synth(frequency,duration)
	sound.bus = "SFX"
	sound.unit_size = 4
	sound.volume_db = -11
	sound.finished.connect(sound.queue_free)
	sound.play()
