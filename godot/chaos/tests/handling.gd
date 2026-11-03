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
	check(metrics.forward_distance>5 and absf(game.chair.position.z)<.65,"W pushes forwards independently of camera yaw")
	check(game.boss.seated and employee_falls==0,"ordinary straight pushing keeps both characters stable")
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
	metrics.boost_employee_falls = employee_falls
	check(metrics.boost_speed>4.5 and metrics.boost_speed>metrics.normal_speed*1.6,"boost produces substantial measurable speed")
	check(employee_falls==0 and not game.player.fallen and game.player.pushing,"four seconds of open straight boost do not topple the employee or break the grip")
	check(game.boss.seated,"straight boosting has a useful safe window")
	check(game.coffee.amount<90 and game.coffee.amount<metrics.normal_coffee-4,"boost visibly spills more coffee than ordinary pushing")
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
	print("CHAOS_HANDLING ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics}))
	game.clear_inputs(); paused = false; game.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
