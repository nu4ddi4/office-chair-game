extends SceneTree

var game: OfficeChairChaos
var failures: Array[String] = []
var checks=0
var metrics={}
var capture_dir=""
func check(value: bool, label: String):
	checks+=1
	if not value: failures.append(label)

func _initialize(): call_deferred("run_tests")
func frames(count: int):
	RenderingServer.set_render_loop_enabled(false)
	for i in range(count): await physics_frame

func capture(name: String):
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	RenderingServer.set_render_loop_enabled(true)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
	RenderingServer.set_render_loop_enabled(false)

func run_tests():
	var args=OS.get_cmdline_user_args()
	if "--capture-dir" in args: capture_dir=args[args.find("--capture-dir")+1]
	game=load("res://chaos/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	check(game.ready_for_play,"scene boot")
	check(game.ui.mode=="main" and paused,"main menu pauses physics")
	await capture("01-menu")
	game.new_game(); await frames(240)
	print("POSE_2S ",JSON.stringify({"player":str(game.player.center()),"boss":str(game.boss.center()),"chair":str(game.chair.position),"fallen":game.player.fallen,"seated":game.boss.seated,"coffee":game.coffee.amount}))
	check(game.player.bodies.size()==15 and game.boss.bodies.size()==15,"two 15-body dolls")
	check(game.boss.seated,"manager stays seated at rest")
	await capture("02-first-mission")
	var start=game.player.center()
	await frames(6960)
	metrics.idle_position=str(game.player.center()); metrics.idle_drift=game.player.center().distance_to(start)
	check(not game.player.fallen and game.player.center().y>.65,"stand upright for sixty seconds")
	check(game.boss.seated,"manager seated for sixty seconds")
	check(game.coffee.amount>90,"quiet coffee does not empty")
	print("IDLE ",JSON.stringify(metrics))
	game.player.reset_pose(Vector3(-24,0,15),0,false)
	game.yaw=0
	Input.action_press("chaos_forward")
	await frames(600)
	Input.action_release("chaos_forward")
	metrics.walk_distance=15-game.player.center().z
	metrics.walk_height=game.player.center().y
	check(metrics.walk_distance>7.5,"walk approximately ten metres")
	check(not game.player.fallen,"normal walking remains recoverable")
	await capture("03-walking")
	game.ui.pause_menu()
	var frozen=game.player.center(); var remaining=game.run.remaining
	await frames(30)
	check(game.player.center().distance_to(frozen)<.001 and game.run.remaining==remaining,"pause freezes rigid bodies and timers")
	Input.action_press("chaos_forward")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused and not Input.is_action_pressed("chaos_forward"),"focus loss clears movement and pauses")
	game.retry(); await frames(90)
	game.interact()
	var left=game.player.grips[0]==game.chair
	var right=game.player.grips[1]==game.chair
	check(left and right,"both hands can reach rear chair handles")
	Input.action_press("chaos_forward"); await frames(300); Input.action_release("chaos_forward")
	metrics.push_distance=14-game.chair.global_position.z
	check(metrics.push_distance>1,"grip forces move loaded chair")
	await capture("04-pushing")
	Input.action_press("chaos_brace"); await frames(240); Input.action_release("chaos_brace")
	await frames(30)
	game.player.release_all()
	game.boss.detach_seat()
	check(not game.boss.seated and game.run.falls>0,"ejection reports recoverable fall")
	check(game.context().get("kind","")=="seat","nearby boss can be reseated")
	game.interact()
	check(game.boss.seated,"reseating restores seat joint")
	game.retry(); await frames(2)
	var count_before=game.stage.get_child_count()
	for i in range(50): game.retry(); await frames(2)
	await frames(5)
	check(game.stage.get_child_count()==count_before,"fifty restores do not leak stage nodes")
	check(game.boss.get_child_count()==30,"seat joints do not accumulate")
	check(game.player.grips[0]==null and game.player.grips[1]==null,"restores release both grips")
	game.store.data.unlocked=6
	for id in range(1,7):
		game.start_mission(id); await frames(120)
		check(game.run.mission.id==id and game.run.phase=="playing","mission %d starts" % id)
		check(game.boss.seated,"mission %d seated spawn" % id)
		if id in [2,6]:
			check(game.context().get("kind","")=="coffee","mission %d refill prompt" % id)
			game.interact(); check(game.run.refilled and game.coffee.amount==100,"mission %d refill" % id)
	game.ui.settings(); await capture("05-settings")
	game.ui.updates_menu(); await capture("09-updates")
	var update_requests = [0]
	game.updates.request_started.connect(func(_url): update_requests[0]+=1)
	game.updates.latest = {"version":"0.2.0"}
	game.ui.confirm_update()
	check(game.ui.mode=="update_confirm" and update_requests[0]==0,"update confirmation does not download before approval")
	game.ui.updates_menu()
	check(update_requests[0]==0 and not game.updates.busy(),"declining an update keeps the current game")
	game.updates.latest = {}; game.ui.settings()
	game.rebind("forward",KEY_UP)
	check(game.keycode("forward")==KEY_UP,"key rebinding")
	game.apply_settings()
	check(game.camera.fov==70,"camera settings")
	metrics.active_bodies=game.player.bodies.size()+game.boss.bodies.size()+game.office.props.size()+game.office.doors.size()+2
	check(metrics.active_bodies<=ChaosTuning.ACTIVE_BODY_BUDGET,"body budget")
	game.ui.field(); game.run.phase="success"; game.escaping=true
	game.player.reset_pose(game.exit_point,0,false)
	await frames(3)
	check(game.ui.mode=="result" and 6 in game.store.data.completed,"walking to exit completes the ending")
	print("CHAOS_PHYSICS ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics}))
	paused=false; game.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
