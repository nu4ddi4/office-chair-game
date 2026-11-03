class_name OfficeChairChaos
extends Node3D

const DEFAULT_KEYS = {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"brace":KEY_SPACE,"interact":KEY_E,"reset":KEY_R}
var store = ChaosSave.new()
var missions: Array
var run: ChaosMissionRun
var checkpoint_state: Dictionary = {}
var stage: Node3D
var office: ChaosOffice
var player: ChaosRagdoll
var boss: ChaosRagdoll
var chair: ChaosChair
var coffee: ChaosCoffee
var camera: Camera3D
var audio: ChaosAudio
var ui: ChaosUI
var updates: ChaosUpdater
var yaw = 0.0
var pitch = .36
var look_idle = 0.0
var reset_hold = 0.0
var distance_timer = 0.0
var escaping = false
var ready_for_play = false
var qa = false
var camera_target = Vector3.ZERO
var shake = 0.0
var previous_chair_velocity = Vector3.ZERO
var impact_cooldown = 0.0
var package_frames = 0
var exit_point = Vector3(-24,0,19)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	qa = "--chaos-test" in OS.get_cmdline_user_args()
	if qa: store.directory = "user://qa-%d" % OS.get_process_id()
	store.load_progress()
	missions = ChaosMissions.load_all()
	_setup_input()
	stage = Node3D.new(); stage.name = "NewGame"; stage.process_mode = Node.PROCESS_MODE_PAUSABLE; add_child(stage)
	office = ChaosOffice.new(); stage.add_child(office)
	office.build("--blockout" in OS.get_cmdline_user_args())
	chair = ChaosChair.new(); chair.name = "OfficeChair"; stage.add_child(chair)
	chair.restore(Vector3(-24,.02,14),0)
	player = ChaosRagdoll.new(); player.name = "Employee"; stage.add_child(player)
	player.build(Vector3(-24,0,15.1)); player.chair = chair
	boss = ChaosRagdoll.new(); boss.name = "Manager"; stage.add_child(boss)
	boss.build(Vector3(-24,0,14),true); boss.sit(chair)
	coffee = ChaosCoffee.new(); stage.add_child(coffee); coffee.setup(boss)
	camera = Camera3D.new(); add_child(camera); camera.current = true; camera.far = 1600; camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera_target = player.center()+Vector3(0,.45,0); _update_camera(1)
	audio = ChaosAudio.new(); stage.add_child(audio)
	ui = ChaosUI.new(); add_child(ui); ui.setup(self)
	boss.fell.connect(_boss_fell)
	player.fell.connect(func(): audio.play("impact",.5))
	office.prop_damaged.connect(func(price):
		if run!=null and run.phase=="playing": run.damage += price; audio.play("impact",.6))
	updates = ChaosUpdater.new(); add_child(updates); updates.setup(self)
	if not qa: updates.installer_ready.connect(updates.launch_installer)
	updates.changed.connect(func():
		if ui.mode=="updates": ui.refresh_updates()
		elif ui.mode=="main" and updates.state=="available": ui.main_menu())
	apply_settings(); ui.main_menu(); ready_for_play = true
	_report_update_health.call_deferred()
	print("CHAOS_READY ",JSON.stringify({"engine":Engine.get_version_info().string,"detailed":office.detailed,"bodies":player.bodies.size()+boss.bodies.size()+office.props.size()+office.doors.size()+2,"user_dir":OS.get_user_data_dir()}))
	var args = OS.get_cmdline_user_args()
	if qa and "--mission" in args:
		var at = args.find("--mission")
		if at+1<args.size():
			var id = clampi(int(args[at+1]),1,6)
			store.data.unlocked = maxi(id,int(store.data.unlocked)); start_mission(id)

func _setup_input():
	for key in DEFAULT_KEYS:
		var action = "chaos_"+key
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event = InputEventKey.new(); event.physical_keycode = keycode(key)
		InputMap.action_add_event(action,event)

func keycode(action: String) -> int:
	return int(store.data.settings.keys.get(action,DEFAULT_KEYS[action]))

func key_hint(action: String) -> String: return OS.get_keycode_string(keycode(action))

func rebind(action: String, key: int):
	if key in [KEY_ESCAPE,0]: return
	var previous = keycode(action)
	for other in DEFAULT_KEYS:
		if other!=action and keycode(other)==key: store.data.settings.keys[other]=previous
	store.data.settings.keys[action] = key; _setup_input()

func apply_settings():
	_setup_input()
	var settings: Dictionary = store.data.settings
	camera.fov = settings.fov; audio.volume = settings.volume
	ui.subtitle.add_theme_font_size_override("font_size",settings.subtitle_size)
	var quality = int(settings.quality)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if quality==0 else Viewport.MSAA_2X
	for child in office.get_children():
		if child is DirectionalLight3D: child.shadow_enabled = quality>0

func new_game():
	var settings: Dictionary = store.data.settings.duplicate(true)
	store.data = ChaosSave.fresh(); store.data.settings = settings; start_mission(1)

func continue_game():
	if not store.data.resume.is_empty(): start_mission(int(store.data.resume.mission),store.data.resume.duplicate(true))
	elif store.data.completed.size()==6: ui.missions()
	else: start_mission(int(store.data.unlocked))

func start_mission(id: int, saved: Dictionary = {}):
	if id<1 or id>int(store.data.unlocked): return
	run = ChaosMissionRun.new(); run.begin(missions[id-1],saved); escaping = false
	checkpoint_state = run.snapshot(float(saved.get("coffee",0 if run.mission.get("requires_refill",false) else 100)))
	_restore_checkpoint(); ui.field(); ui.say(run.mission.intro,6); persist_checkpoint()

func _checkpoint_origin() -> Vector3:
	if run.checkpoint==0: return ChaosMissions.point(run.mission.start)
	return ChaosMissions.point(run.mission.route[run.checkpoint-1].at)

func _restore_checkpoint():
	player.release_all(); boss.release_all(); boss.detach_seat(false); office.restore()
	var origin = _checkpoint_origin()+Vector3(0,.015,0)
	var destination = ChaosMissions.point(run.mission.route[run.checkpoint].at)
	var direction = destination-origin; direction.y = 0
	var facing = atan2(-direction.x,-direction.z) if direction.length()>.1 else 0.0
	chair.restore(origin,facing)
	player.reset_pose(origin+Basis(Vector3.UP,facing)*Vector3(0,0,1.0),facing,false)
	boss.sit(chair); coffee.restore(float(checkpoint_state.coffee))
	run.index = run.checkpoint; run.park_time = 0; run.phase = "playing"; run.reason = ""
	run.remaining = float(checkpoint_state.remaining); run.refilled = bool(checkpoint_state.refilled)
	office.hazards = run.mission.get("hazards",false)
	yaw = facing; pitch = .36; camera_target = player.center()+Vector3(0,.5,0); _update_camera(1)
	reset_hold = 0; previous_chair_velocity = Vector3.ZERO; impact_cooldown = 1; _update_goal()
	look_idle = 0

func retry():
	if run==null: return
	run.retries += 1; escaping = false; _restore_checkpoint(); ui.field(); ui.say("괜찮아. 회사 물건이잖아.",3)

func persist_checkpoint() -> bool:
	if run==null or checkpoint_state.is_empty() or run.phase=="success": return store.write()
	var saved = checkpoint_state.duplicate(true)
	saved.elapsed = run.elapsed; saved.falls = run.falls; saved.damage = run.damage; saved.retries = run.retries
	store.data.resume = saved
	var saved_ok = store.write()
	if not saved_ok and ui!=null: ui.say(store.error,6)
	return saved_ok

func _update_goal():
	var waypoint: Dictionary = run.mission.route[run.index]
	office.set_goal(ChaosMissions.point(waypoint.at),waypoint.label)

func _physics_process(delta):
	if not ready_for_play or ui.mode!="field" or get_tree().paused or run==null: return
	var axes = Input.get_vector("chaos_left","chaos_right","chaos_forward","chaos_back")
	player.bracing = Input.is_action_pressed("chaos_brace")
	_update_locomotion(delta,axes)
	office.apply_hazards(player,chair); office.apply_hazards(boss,chair)
	if escaping:
		if player.center().distance_to(exit_point+Vector3(0,.92,0))<1.8: _finish()
	else: _handle_progress(run.tick(delta,chair.global_position,chair.linear_velocity.length(),boss.seated,coffee.amount))
	if Input.is_action_pressed("chaos_reset"):
		reset_hold += delta
		if reset_hold>=1: retry()
	else: reset_hold = 0
	if chair.global_position.y< -3 or player.center().y< -3 or boss.center().y< -3:
		retry(); ui.say("여긴 지하 주차장이 아닌데.")
	distance_timer += delta
	if distance_timer>.4: distance_timer=0; office.update_distance(player.center())
	impact_cooldown = maxf(0,impact_cooldown-delta)
	var acceleration = (chair.linear_velocity-previous_chair_velocity).length()/delta
	if acceleration>40 and impact_cooldown<=0:
		shake = .08 if store.data.settings.shake else 0
		audio.play("impact",minf(acceleration/100,1)); impact_cooldown=.5
	previous_chair_velocity=chair.linear_velocity; audio.update_rolling(chair.linear_velocity.length())
	if "--package-smoke" in OS.get_cmdline_user_args():
		package_frames += 1
		if package_frames >= 240:
			var passed = boss.seated and not player.fallen and player.center().y>.65 and office.detailed and FileAccess.file_exists("res://chaos/resources/update_helper.ps1")
			print("CHAOS_PACKAGE_SMOKE ",JSON.stringify({"passed":passed}))
			get_tree().quit(0 if passed else 1)

func _update_locomotion(delta: float, axes: Vector2):
	var both_handles = player.grips[0]==chair and player.grips[1]==chair
	if not both_handles or player.fallen or chair.global_basis.y.dot(Vector3.UP)<.6:
		player.pushing = false
	elif not player.pushing and player.at_chair_back():
		player.pushing = true
		chair.drive_heading = chair.rotation.y
	chair.driving = player.pushing
	chair.boosting = false
	if player.pushing:
		var throttle = -Input.get_axis("chaos_forward","chaos_back")
		var steer = Input.get_axis("chaos_left","chaos_right")
		chair.drive(delta,throttle,steer,Input.is_action_pressed("chaos_sprint"),player.bracing)
		var rear = chair.global_basis*Vector3(0,0,ChaosTuning.PUSH_FOLLOW_DISTANCE)
		var error = chair.global_position+rear-player.center(); error.y = 0
		var following = chair.linear_velocity+chair.angular_velocity.cross(rear)+error*4.5
		player.desired_velocity = Vector3(following.x,0,following.z).limit_length(10)
		player.facing = lerp_angle(player.facing,chair.rotation.y,1-exp(-delta*12))
		if look_idle<=0: yaw = lerp_angle(yaw,chair.rotation.y,1-exp(-delta*3))
	else:
		var speed = ChaosTuning.BRACE_SPEED if player.bracing else ChaosTuning.RUN_SPEED if Input.is_action_pressed("chaos_sprint") else ChaosTuning.WALK_SPEED
		player.desired_velocity = Basis(Vector3.UP,yaw)*Vector3(axes.x,0,axes.y)*speed
		if axes.length()>.05: player.facing = lerp_angle(player.facing,yaw,1-exp(-delta*6))
		chair.braked = player.bracing and (player.grips[0]==chair or player.grips[1]==chair)

func _handle_progress(event: String):
	if event.is_empty(): return
	if event=="failure": audio.play("failure"); ui.result(false); persist_checkpoint(); return
	if event=="success":
		ui.say(run.mission.outro,5)
		if int(run.mission.id)==6:
			escaping=true; player.release_all(); office.set_goal(exit_point,"퇴근 · 출구")
		else: _finish()
		return
	if event=="checkpoint":
		checkpoint_state=run.snapshot(coffee.amount); persist_checkpoint(); ui.say("좋아. 여기서 잠깐만.",2)
	var events: Dictionary=run.mission.get("events",{})
	if events.has(str(run.index)): ui.say(events[str(run.index)],5)
	boss.lean=.10 if run.index%2 else -.06
	boss.gesture="point" if run.index%2 else "drink"; boss.gesture_time=2.5
	_update_goal()

func _boss_fell():
	if run==null or ui.mode!="field": return
	audio.play("impact")
	var event=run.boss_fell()
	if event=="failure": _handle_progress(event)
	else: ui.say("김 대리, 바닥이 생각보다 가깝네.")

func _finish():
	escaping=false; run.phase="success"; store.complete(run)
	if not store.write(): ui.say(store.error,6)
	audio.play("success"); ui.result(true)

func _unhandled_input(event):
	if not ready_for_play: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if ui.mode=="field": persist_checkpoint(); ui.pause_menu()
		elif ui.mode=="pause": ui.field()
		elif ui.mode=="notices": ui.credits()
		elif ui.mode=="credits": ui.main_menu()
		elif ui.mode=="update_confirm": ui.updates_menu()
		elif ui.mode=="updates":
			updates.cancel_download(); ui.settings()
		elif ui.mode=="settings" or ui.mode=="keys":
			apply_settings(); store.write()
			if run!=null and (run.phase=="playing" or escaping): ui.pause_menu()
			else: ui.main_menu()
		get_viewport().set_input_as_handled(); return
	if ui.mode!="field": return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		look_idle = 2.5
		yaw-=event.relative.x*float(store.data.settings.sensitivity)
		pitch=clampf(pitch+event.relative.y*float(store.data.settings.sensitivity),-.20,.85)
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var index=0 if event.button_index==MOUSE_BUTTON_LEFT else 1
		if event.pressed: player.try_grab(index); audio.play("grip",.4)
		elif store.data.settings.hold_grip: player.release(index)
	if event.is_action_pressed("chaos_interact") and not event.is_echo(): interact()

func _process(delta):
	if not ready_for_play or ui.mode!="field": return
	look_idle = maxf(0,look_idle-delta)
	var speed_fov = clampf(chair.linear_velocity.length()/ChaosTuning.PUSH_BOOST_SPEED,0,1)*8 if player.pushing else 0.0
	camera.fov = lerpf(camera.fov,float(store.data.settings.fov)+speed_fov,1-exp(-delta*4))
	_update_camera(delta); shake=maxf(0,shake-delta*.25)

func _update_camera(delta):
	var target=player.center()+Vector3(0,.5,0)
	if boss.seated and player.center().distance_to(boss.center())<3: target=target.lerp(boss.center()+Vector3(0,.45,0),.35)
	camera_target=camera_target.lerp(target,1-exp(-delta*10))
	var desired=camera_target+Basis(Vector3.UP,yaw)*Vector3(1.05,sin(pitch)*3.5,cos(pitch)*3.5)
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new(); sphere.radius = .18
	query.shape = sphere; query.transform = Transform3D(Basis.IDENTITY,camera_target)
	query.motion = desired-camera_target; query.collision_mask = ChaosTuning.FLOOR|ChaosTuning.DOOR
	var fractions = get_world_3d().direct_space_state.cast_motion(query)
	desired = camera_target+query.motion*maxf(0.05,fractions[0]-.015)
	camera.global_position=desired+Vector3(sin(Time.get_ticks_msec()*.045)*shake,cos(Time.get_ticks_msec()*.06)*shake,0)
	if camera.global_position.distance_to(camera_target)>.05: camera.look_at(camera_target)

func _visible(point: Vector3, target: Node=null) -> bool:
	var ray=PhysicsRayQueryParameters3D.create(player.bodies.torso.global_position,point,ChaosTuning.FLOOR|ChaosTuning.DOOR)
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider==target

func context() -> Dictionary:
	if player==null or chair==null or run==null: return {}
	var near=player.center().distance_to(chair.global_position)<2.6
	if near and chair.global_basis.y.dot(Vector3.UP)<.65 and _visible(chair.global_position+Vector3.UP*.8): return {"kind":"right","text":"의자 세우기"}
	if near and not boss.seated and boss.center().distance_to(chair.global_position)<1.5 and chair.linear_velocity.length()<.30 and _visible(chair.global_position+Vector3.UP*.9): return {"kind":"seat","text":"부장님 다시 태우기"}
	if near and coffee.amount<99 and chair.linear_velocity.length()<.25:
		for point in office.coffee_points:
			if point.distance_to(chair.global_position)<3 and _visible(point+Vector3.UP): return {"kind":"coffee","text":"커피 보충"}
	var nearest: ChaosDoor
	var distance=2.1
	for door in office.doors:
		var point: Vector3=door.leaf.global_position
		var d=point.distance_to(player.center())
		if d<distance and _visible(point,door.leaf): nearest=door; distance=d
	if nearest!=null: return {"kind":"door","text":"문 밀기","target":nearest}
	if player.pushing: return {"kind":"release","text":"의자 놓기"}
	if player.can_grab_handles(): return {"kind":"push","text":"손잡이 잡고 앞으로 밀기"}
	return {}

func context_text() -> String:
	var target=context()
	if not target.is_empty(): return key_hint("interact")+" · "+target.text
	if not boss.seated: return "양손으로 부장님을 의자 가까이 옮겨 주세요"
	return "마우스 좌/우 클릭 · 양손 잡기"

func interact():
	var action=context()
	if action.is_empty(): return
	match action.kind:
		"push":
			if player.grab_handles(): audio.play("grip",.6)
		"release": player.release_all()
		"coffee":
			coffee.amount=100; coffee.grace=1; run.refilled=true
			checkpoint_state.coffee=100; checkpoint_state.refilled=true; persist_checkpoint(); ui.say("가득. 아주 가득.")
		"door": action.target.interact(player.center())
		"right", "seat":
			var query=PhysicsShapeQueryParameters3D.new()
			var shape=BoxShape3D.new(); shape.size=Vector3(1.0,1.75,1.15)
			query.shape=shape; query.transform=Transform3D(Basis(Vector3.UP,chair.rotation.y),chair.global_position+Vector3(0,1,0)); query.collision_mask=ChaosTuning.FLOOR|ChaosTuning.DOOR
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): ui.say("여긴 좀 좁네. 넓은 데서 해줘."); return
			player.release_all()
			if action.kind=="right": boss.detach_seat(false); chair.restore(Vector3(chair.global_position.x,.015,chair.global_position.z),chair.rotation.y)
			else: boss.sit(chair); coffee.reconnect(); ui.say("아무도 못 봤지?")

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and ready_for_play:
		clear_inputs()
		if ui.mode=="field": persist_checkpoint(); ui.pause_menu()
	if what==NOTIFICATION_WM_CLOSE_REQUEST and ready_for_play: persist_checkpoint()

func clear_inputs():
	for action in DEFAULT_KEYS: Input.action_release("chaos_"+action)
	reset_hold = 0
	if player!=null:
		player.desired_velocity = Vector3.ZERO
		if store.data.settings.hold_grip: player.release_all()

func _report_update_health():
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	if ready_for_play and office.detailed: updates.write_health()
