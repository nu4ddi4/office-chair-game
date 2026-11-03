extends SceneTree

var failures: Array = []
var checks = 0
var scene: Node3D

func _initialize():
	run.call_deferred()

func check(value: bool, label: String):
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func frames(count: int):
	for i in count: await physics_frame

func key(code: Key, down: bool):
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func tap(code: Key):
	key(code,true)
	await process_frame
	key(code,false)
	await process_frame

func run():
	scene = load("res://scenes/office.tscn").instantiate()
	root.add_child(scene)
	await frames(3)
	scene.set_paused(false)
	await frames(25)
	var actor = scene.player
	check(scene.world.model != null,"authored office loads")
	check(scene.world.doors.size() == 3,"all three authored doors are present")
	check(actor.camera.current,"map camera stays in first person")
	check(actor.is_on_floor() and absf(actor.position.y)<.08,"authored spawn has floor support")
	var start = actor.position
	Input.action_press("move_forward")
	await frames(100)
	Input.action_release("move_forward")
	await frames(8)
	check(actor.position.z < start.z-.5,"WASD moves the camera body")
	check(actor.position.z > 10.10,"closed entry door blocks walking")
	actor.ray.force_raycast_update()
	await frames(2)
	check(actor.target == scene.world.doors.DOOR_Main,"door is reachable through the camera ray")
	await tap(KEY_F)
	await frames(70)
	check(absf(scene.world.doors.DOOR_Main.pivot.rotation.y)>deg_to_rad(70),"F opens the door")
	Input.action_press("move_forward")
	await frames(100)
	Input.action_release("move_forward")
	await frames(8)
	check(actor.position.z<9.0,"opened entry door permits passage")
	check(actor.is_on_floor(),"office interior supports the player")
	var floor_y = actor.position.y
	var peak = floor_y
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	for i in 105:
		await physics_frame
		peak = maxf(peak,actor.position.y)
	check(peak>floor_y+.4,"Space jumps above the floor")
	check(actor.is_on_floor() and absf(actor.position.y-floor_y)<.08,"jump lands without falling through the map")
	await tap(KEY_ESCAPE)
	check(scene.paused and scene.menu.visible and not actor.enabled,"Esc opens an accessible pause menu")
	var paused_position = actor.position
	Input.action_press("move_forward")
	await frames(24)
	Input.action_release("move_forward")
	check(actor.position.distance_to(paused_position)<.001,"paused movement is blocked")
	await tap(KEY_ESCAPE)
	check(not scene.paused and actor.enabled,"Esc returns to map exploration")
	var rendered = "--rendered" in OS.get_cmdline_user_args()
	if rendered:
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"resuming restores mouse capture")
		var yaw = actor.rotation.y
		var motion = InputEventMouseMotion.new()
		motion.relative = Vector2(60,0)
		Input.parse_input_event(motion)
		await process_frame
		check(absf(actor.rotation.y-yaw)>.05,"mouse look works over the HUD")
		actor.rotation = Vector3.ZERO
		actor.camera.look_at(Vector3(-5,1.4,3))
		var args = OS.get_cmdline_user_args()
		var directory = args[args.find("--capture-dir")+1]
		DirAccess.make_dir_recursive_absolute(directory)
		await capture(directory.path_join("office-map.png"))
		DisplayServer.window_set_size(Vector2i(1226,1033))
		await frames(8)
		await tap(KEY_ESCAPE)
		await frames(4)
		var viewport_rect = Rect2(Vector2.ZERO,root.get_visible_rect().size)
		check(viewport_rect.encloses(scene.menu.get_global_rect()),"pause menu fits a tall desktop window")
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"pause releases the mouse")
		await capture(directory.path_join("pause-menu.png"))
	var result = {"passed":failures.is_empty(),"checks":checks,"failures":failures,"rendered":rendered,"doors":scene.world.doors.size()}
	print("MAP_SMOKE "+JSON.stringify(result))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func capture(path: String):
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+path.get_file())
