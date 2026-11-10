extends SceneTree

var game: OfficeChairChaos
var failures: Array[String] = []
var checks = 0
var employee_falls = 0
var metrics = {}
var capture_dir = ""

func _initialize(): call_deferred("run_tests")
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label)
func frames(count: int):
	RenderingServer.set_render_loop_enabled(false)
	for i in range(count): await physics_frame
func capture(label: String):
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	RenderingServer.set_render_loop_enabled(true)
	await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.get_texture().get_image().save_png(capture_dir.path_join(label+".png"))
	RenderingServer.set_render_loop_enabled(false)

func fixture(at = Vector3(-22,.015,0), heading = -PI/2):
	game.clear_inputs(); game.start_mission(1)
	game.player.release_all(); game.boss.detach_seat(false)
	game.chair.restore(at,heading)
	game.player.reset_pose(at+Basis(Vector3.UP,heading)*Vector3(0,0,1),heading,false)
	game.boss.sit(game.chair); game.coffee.restore(100)
	game.yaw = heading; game.look_idle = 10
	await frames(120)
	employee_falls = 0

func key(action: String, pressed = true):
	if pressed: Input.action_press("chaos_"+action)
	else: Input.action_release("chaos_"+action)

# Corridor coworkers: a slow approach makes them step aside, a boost does not.
func approach(walker: ChaosWalker, speed: float, frames_max: int, shot = "") -> Dictionary:
	var result = {"dodge":0.0,"closest":99.0,"bumped":false}
	var hit = func(): result.bumped = true
	walker.bumped.connect(hit)
	for i in range(frames_max):
		var offset = walker.global_position-game.chair.global_position; offset.y = 0
		var velocity = Vector3(game.chair.linear_velocity.x,0,game.chair.linear_velocity.z)
		game.chair.apply_central_force(((offset.normalized()*speed-velocity)*400).limit_length(900))
		if not shot.is_empty() and walker.dodge>.55 and result.dodge<=.55: await capture(shot)
		result.dodge = maxf(result.dodge,walker.dodge)
		result.closest = minf(result.closest,offset.length())
		await frames(1)
	walker.bumped.disconnect(hit)
	return result

# Coffee rocks like a spring: jerking in time with the wave spills even at normal
# speed, and reversing makes the casters flop round with a sideways shove.
func rhythm_and_caster_checks():
	await fixture(); game.interact(); await frames(2)
	key("forward"); await frames(240)
	for i in range(4):
		key("forward",false); key("back"); await frames(28); key("back",false); key("forward"); await frames(28)
	metrics.rhythm_slosh = game.coffee.peak_slosh; metrics.rhythm_coffee = game.coffee.amount
	check(metrics.rhythm_slosh>1.2 and game.coffee.amount<97,"jerking in time with the wave spills coffee at normal speed")
	game.clear_inputs()
	await fixture(); game.interact(); await frames(2)
	key("forward"); await frames(240); key("forward",false); key("back")
	var flop = 0.0; var shove = 0.0
	for i in range(120):
		await frames(1)
		flop = maxf(flop,game.chair.caster_misalign)
		shove = maxf(shove,absf(game.chair.linear_velocity.dot(game.chair.global_basis.x)))
	metrics.caster_flop_deg = rad_to_deg(flop); metrics.caster_shove = shove
	check(flop>2.5 and shove>.2,"reversing flops the casters round with a sideways shove")
	game.clear_inputs()

# Ramming a desk wakes its props, they settle, cost money, and a restore puts them back.
func clutter_checks():
	var clutter: ChaosClutter = game.office.clutter
	check(clutter.desks.size()>=40 and clutter.items.size()>=200,"desk props are registered")
	await fixture(Vector3(-23.4,.015,-17.0),PI/2); game.interact(); await frames(2)
	key("forward"); key("sprint")
	for i in range(240):
		await frames(1)
		if clutter.knocks>0: break
	await frames(300); game.clear_inputs()
	var moved = 0
	for item in clutter.items:
		if item.body!=null and item.mesh.global_position.distance_to(item.xform.origin)>.15: moved += 1
	metrics.clutter_moved = moved; metrics.clutter_damage = game.run.damage
	check(moved>=3 and game.run.damage>0,"ramming a desk knocks its props off and costs money")
	check(clutter.awake_count()<=ChaosClutter.MAX_AWAKE,"woken props settle within the body budget")
	game.retry(); await frames(3)
	var home = 0
	for item in clutter.items:
		if item.body==null and item.mesh.global_position.distance_to(item.xform.origin)<.001: home += 1
	check(home==clutter.items.size(),"a checkpoint restore puts every desk prop back")

func traffic_checks():
	game.clear_inputs(); game.store.data.unlocked = 6; game.start_mission(4); await frames(30)
	check(game.office.walkers.size()==3,"mission traffic spawns its coworkers")
	var walker: ChaosWalker = game.office.walkers[1]
	var start_x = walker.global_position.x
	await frames(240)
	check(absf(walker.global_position.x-start_x)>1.5,"coworkers walk their corridor lane")
	walker.restore(); walker.pause = 99
	game.chair.restore(walker.global_position+Vector3(-4.5,.015,0),-PI/2)
	game.player.reset_pose(game.chair.global_position+Vector3(-1,0,0),-PI/2,false)
	game.yaw = -PI/2; game.look_idle = 10
	game.boss.sit(game.chair); game.coffee.restore(100); await frames(30)
	var slow = await approach(walker,1.0,420,"10-traffic-dodge")
	metrics.slow_dodge = slow.dodge; metrics.slow_closest = slow.closest
	check(slow.dodge>.8 and not slow.bumped,"a careful approach lets the coworker step aside")
	walker.restore(); walker.pause = 99
	game.chair.restore(walker.global_position+Vector3(-4.5,.015,0),-PI/2)
	game.player.reset_pose(game.chair.global_position+Vector3(-1,0,0),-PI/2,false)
	game.yaw = -PI/2; game.look_idle = 10
	game.boss.sit(game.chair); game.coffee.restore(100); await frames(30)
	var fast = await approach(walker,6.5,150)
	metrics.fast_closest = fast.closest; metrics.fast_bumped = fast.bumped
	check(fast.bumped,"rushing at a coworker collides before they can step aside")
	game.clear_inputs()

func run_tests():
	var args = OS.get_cmdline_user_args()
	if "--capture-dir" in args: capture_dir = args[args.find("--capture-dir")+1]
	game = load("res://chaos/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.player.fell.connect(func(): employee_falls+=1)
	await fixture()
	check(game.context().get("kind","")=="push","E offers the actual rear handles")
	check(not game.boss.bodies.head.is_in_group("chaos_grabbable"),"seated passenger cannot steal a handle grab")
	game.interact(); await frames(2)
	check(game.player.pushing and game.player.grips[0]==game.chair and game.player.grips[1]==game.chair,"E atomically attaches both hands and enters pushing")
	# Look ninety degrees away: forward must continue along the chair, not camera.
	game.yaw = 0; game.look_idle = 10
	key("forward"); await frames(360); key("forward",false)
	metrics.normal_speed = game.chair.linear_velocity.length()
	metrics.forward_distance = game.chair.position.x+22
	metrics.normal_coffee = game.coffee.amount
	metrics.normal_slosh = game.coffee.peak_slosh
	check(metrics.forward_distance>5 and absf(game.chair.position.z)<.65,"W pushes forwards independently of camera yaw")
	check(game.boss.seated and employee_falls==0,"ordinary straight pushing keeps both characters stable")
	check(metrics.normal_coffee>99.5 and metrics.normal_slosh<ChaosTuning.COFFEE_SLOSH_WARN,"smooth pushing does not spill coffee")
	await capture("06-forward-pushing")
	key("right"); await frames(100); key("right",false)
	check(game.boss.seated,"gentle steering does not automatically eject the passenger")
	check(absf(wrapf(game.chair.rotation.y+PI/2,-PI,PI))>.35,"A/D rotates the chair")
	await fixture()
	game.interact(); await frames(2)
	key("forward"); key("sprint")
	await frames(480)
	metrics.boost_speed = game.chair.linear_velocity.length()
	metrics.boost_coffee = game.coffee.amount
	metrics.boost_slosh = game.coffee.peak_slosh
	metrics.boost_employee_falls = employee_falls
	check(metrics.boost_speed>4.5 and metrics.boost_speed>metrics.normal_speed*1.6,"boost produces substantial measurable speed")
	check(employee_falls==0 and not game.player.fallen and game.player.pushing,"four seconds of open straight boost do not topple the employee or break the grip")
	check(game.boss.seated,"straight boosting has a useful safe window")
	check(metrics.boost_slosh>metrics.normal_slosh+.4 and metrics.boost_slosh>=ChaosTuning.COFFEE_SLOSH_WARN,"a boost launch sloshes the coffee to the warning level")
	await capture("07-boost")
	key("right")
	for i in range(240):
		await frames(1)
		if not game.boss.seated: break
	metrics.sharp_turn_ejected = not game.boss.seated
	check(not game.boss.seated,"high speed sharp turns eject the passenger")
	check(game.run.falls>0 and game.boss.bodies.head.is_in_group("chaos_grabbable"),"an ejected passenger becomes recoverable and counts as a fall")
	await frames(45)
	await capture("08-passenger-ejection")
	game.clear_inputs()
	await fixture(Vector3(-18,.015,2),0)
	game.interact(); await frames(2)
	key("forward"); key("sprint")
	for i in range(480):
		await frames(1)
		if not game.boss.seated: break
	check(not game.boss.seated,"a fast frontal collision breaks the seat connection")
	await frames(30)
	metrics.collision_coffee = game.coffee.amount
	check(game.coffee.amount<95,"a collision spills coffee")
	game.clear_inputs()
	await fixture()
	# Exercise the real mouse path without a preferred target parameter.
	for button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var event = InputEventMouseButton.new(); event.button_index = button; event.pressed = true
		game._unhandled_input(event)
	await frames(2)
	check(game.player.pushing,"ordinary mouse grabs select chair handles rather than the seated boss")
	game.player.release(0); await frames(2)
	check(not game.player.pushing and not game.chair.driving,"releasing one hand exits vehicle steering")
	game.player.release_all()
	await frames(240)
	check(game.coffee.amount>98,"idle coffee is not drained by solver noise")
	await rhythm_and_caster_checks()
	await clutter_checks()
	await traffic_checks()
	print("CHAOS_HANDLING ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics}))
	game.clear_inputs(); paused = false; game.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
