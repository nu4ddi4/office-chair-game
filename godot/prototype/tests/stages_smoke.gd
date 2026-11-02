extends Node

var capture_directory = ""
var failures = []

func check(value: bool, message: String):
	if not value: failures.append(message)

func capture(game, name: String):
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless": return
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_directory.path_join(name+".png"))
	print("STAGE_CAPTURE ",name)

func enter(game, command: String):
	if game.ui.mode == "field": game.ui.open_terminal()
	game.ui.command_input.text = command
	game.ui.command_input.text_submitted.emit(command)

func aim(game, position: Vector3, subject: Vector3):
	game.player.global_position = position
	game.player.velocity = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	game.player.camera.look_at(subject)

func keypress(code: int):
	var key = InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	Input.flush_buffered_events()
	await get_tree().process_frame
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await get_tree().process_frame

func run(game: InvestigationPrototype):
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prototype-capture-dir="):
			capture_directory = argument.trim_prefix("--prototype-capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_directory)
	await get_tree().process_frame
	var ui = game.ui as TerminalStagesUI
	var world = game.stage_world
	var touch_default = game.controls.touch_enabled
	check(ui != null and ui.mode == "main_menu" and not game.player.enabled,"New campaign opens the main menu")
	await capture(game,"00-main-menu")
	ui.entry.new_game.pressed.emit()
	check(ui.mode == "intro","A short introduction precedes the print room")
	await capture(game,"01-intro")
	ui.entry.finish_intro()
	check(ui.mode == "field" and game.player.camera.get_parent() == game.player and absf(game.player.camera.position.z) < .01,"Stage starts in first person")
	check(game.content.stages.size() == 1 and not game.targets.has("shutdown_pc"),"Old stages and rooftop course are removed")
	await field_hud_checks(game)
	world.key = ""
	world.prepare_stage()
	await capture(game,"office-character")
	ui.open_stage_picker()
	check(ui.picks.get_child_count() == 1,"Stage selection exposes only the new stage")
	await capture(game,"06-stages")
	ui.begin_stage()
	enter(game,"cat missing")
	check(game.state.stage.phase == "playing" and game.state.stage.blasts == 0,"Typos and missing files are recoverable")
	await capture(game,"02-practice")
	enter(game,"help")
	await get_tree().process_frame
	if not game.controls.mobile: check(ui.command_input.has_focus(),"Terminal retains focus after Enter")
	check(ui.terminal.get_parsed_text().contains("print <file>"),"Help describes command syntax")
	ui.command_input.text = "print clockout.form"
	ui.command_input.grab_focus()
	await keypress(KEY_ENTER)
	check(game.controls.keyboard_seen and game.state.stage.print.job == "running" and game.state.stage.phase == "playing","Real Enter submits a print job without clearing the stage")
	if game.state.stage.print.job != "running": enter(game,"print clockout.form")
	await capture(game,"03-terminal")
	var before = world.chair.position
	await get_tree().create_timer(.16).timeout
	check(world.chair.position == before and game.state.stage.print.stacks == 0,"Reading the terminal freezes hazards and paper growth")
	enter(game,"exit")
	check(ui.mode == "field" and game.player.enabled,"Exit returns directly to movement")
	await get_tree().create_timer(5.0).timeout
	check(game.state.stage.print.stacks == 3 and game.state.stage.print.seen,"Printing creates three finite physical paper steps")
	check(world.chair.position.distance_to(world.point("chair_start")) > 1.8,"Actual office chair moves along the paper path")
	aim(game,world.to_global(Vector3(1.2,.02,3.2)),world.printer.global_position+Vector3(0,1.4,1.0))
	await capture(game,"05-paper-flood")
	var pedal = game.targets.print_pause
	aim(game,world.to_global(world.point("pedal")+Vector3(.7,-.25,.6)),pedal.global_position)
	for frame in range(4): await get_tree().physics_frame
	game.player.update_target()
	check(pedal.reachable(),"Physical pause pedal is reachable without touching paper piles")
	game._use("print_pause","print",true)
	check(game.state.stage.print.job == "paused","Physical pedal pauses the same print job")
	await get_tree().create_timer(1.0).timeout
	check(game.state.stage.print.tail and world.trailing_bundle.visible,"The trailing paper bundle plays after stopping")
	var frozen = world.chair.position
	var scene_time = world.scene_time
	ui.open_pause()
	await get_tree().create_timer(.15).timeout
	check(world.chair.position == frozen and world.scene_time == scene_time,"Pause freezes all moving props")
	ui.close()
	# Traverse the real collision steps with the player's actual jump and walk inputs.
	game.player.global_position = world.to_global(Vector3(.55,.03,4.4))
	game.player.rotation = Vector3(0,world.rotation.y,0)
	game.player.camera.rotation = Vector3.ZERO
	for frame in range(20): await get_tree().physics_frame
	var completed_jumps = 0
	for i in range(3):
		var destination = world.pile_bodies[i].position.z
		Input.action_press("forward")
		Input.action_press("jump")
		await get_tree().physics_frame
		Input.action_release("jump")
		for frame in range(80):
			await get_tree().physics_frame
			if world.to_local(game.player.global_position).z <= destination+.02: break
		Input.action_release("forward")
		for frame in range(40): await get_tree().physics_frame
		if game.player.is_on_floor() and game.player.global_position.y > .28*(i+1): completed_jumps += 1
	check(completed_jumps == 3,"All paper steps are climbable with real movement and jump input: "+str(game.player.global_position))
	var form = game.targets.print_form
	game.player.camera.look_at(form.global_position)
	for frame in range(3): await get_tree().physics_frame
	check(form.reachable(),"Original form can be reached from the upper paper step")
	game._use("print_form","print",true)
	check(game.state.stage.print.document == "held" and world.held_sheet.visible,"Taking the physical form puts it in the hand")
	await capture(game,"form-in-hand")
	world.drop_form()
	check(game.state.stage.print.document == "tray","Dropping cannot lose the original form")
	game._use("print_form","print",true)
	var tray = game.targets.print_delivery
	aim(game,world.to_global(world.to_local(tray.global_position)+Vector3(0,-.98,1.1)),tray.global_position)
	for frame in range(5): await get_tree().physics_frame
	check(tray.reachable(),"Delivery tray has a usable approach")
	var directory = game.store.directory
	var blocker = directory.path_join("blocked-print-completion")
	var file = FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	game.store.directory = blocker
	game._use("print_delivery","print",true)
	check(game.state.stage.phase == "playing" and game.state.stage.print.document == "delivered","Failed completion save preserves the form and prevents advancement")
	game.store.directory = directory
	DirAccess.remove_absolute(blocker)
	game._use("print_delivery","print",true)
	if game.state.stage.phase != "clear": print("PRINT_COMPLETION_DIAG ",JSON.stringify({"stage":game.state.stage,"reachable":tray.reachable(),"mode":ui.mode,"error":game.store.error,"valid":TerminalStagesEngine.valid_progress(game.state.stage),"notice":ui.message.text}))
	check(game.state.stage.phase == "clear" and ui.mode == "result","Delivery and a successful save complete the physical task")
	await capture(game,"04-clear")
	ui.next_stage()
	check(game.state.stage.phase == "complete","There is no old second stage after completion")
	await capture(game,"08-finish")
	var decoded = InvestigationSaveCodec.decode(InvestigationSaveCodec.encode(game.state,game.content),game.content)
	check(decoded.has("state") and decoded.state.stage == game.state.stage,"New physical progress survives a save round trip")
	ui.retry_stage()
	check(game.state.stage.print == TerminalStagesEngine.fresh_print() and world.chair.position == world.point("chair_start"),"Replay restores the room and its props")
	# Fast cancellation must leave a second, real route to the original sheet.
	enter(game,"print clockout.form")
	enter(game,"cancel R41")
	ui.close()
	var cart = game.targets.print_cart
	aim(game,world.to_global(world.to_local(cart.global_position)+Vector3(1.15,-.48,.55)),cart.global_position)
	for frame in range(4): await get_tree().physics_frame
	game._use("print_cart","print",true)
	check(game.state.stage.print.cart and world.cart_steps[2].collision_layer != 0,"Early cancellation can unfold an alternate service stair")
	await capture(game,"service-cart")
	game.player.global_position = world.to_global(Vector3(.55,.03,3.4))
	game.player.rotation = Vector3(0,world.rotation.y,0)
	game.player.camera.rotation = Vector3.ZERO
	game.player.velocity = Vector3.ZERO
	for frame in range(20): await get_tree().physics_frame
	var cart_jumps = 0
	for i in range(3):
		var destination = world.cart_steps[i].position.z
		Input.action_press("forward")
		Input.action_press("jump")
		await get_tree().physics_frame
		Input.action_release("jump")
		for frame in range(80):
			await get_tree().physics_frame
			if world.to_local(game.player.global_position).z <= destination+.02: break
		Input.action_release("forward")
		for frame in range(40): await get_tree().physics_frame
		if game.player.is_on_floor() and game.player.global_position.y > .28*(i+1): cart_jumps += 1
	check(cart_jumps == 3,"Early-cancel service stairs can actually be climbed: "+str(game.player.global_position))
	game.player.camera.look_at(form.global_position)
	for frame in range(3): await get_tree().physics_frame
	game._use("print_form","print",true)
	check(game.state.stage.print.document == "held","Early cancellation remains solvable through the alternate stairs")

	var npc = game.targets.print_seo
	aim(game,world.to_global(world.point("seo")+Vector3(.65,.02,.1)),npc.global_position)
	for frame in range(5): await get_tree().physics_frame
	await keypress(KEY_F)
	check(ui.mode == "stage_dialogue" and is_instance_valid(ui.stage_choices) and ui.stage_choices.get_child_count() == 3,"Print room has optional NPC conversation without a right-answer quiz")
	if ui.mode != "stage_dialogue":
		print("PRINT_NPC_DIAG ",JSON.stringify({"position":str(game.player.global_position),"target":str(game.player.target),"reachable":npc.reachable()}))
		ui.talk_to("print_seo")
	await capture(game,"npc-conversation")
	ui.stage_choices.get_child(2).pressed.emit()
	check(ui.mode == "field" and game.player.enabled,"NPC choices return to movement")
	ui.open_terminal()
	await keypress(KEY_ESCAPE)
	check(ui.mode == "field","Escape closes the terminal")
	ui.toggle()
	check(ui.mode == "pause","The next Escape opens pause")
	ui.open_tablet(4)
	await get_tree().process_frame
	var review = load("res://prototype/tests/smoke.gd").new()
	add_child(review)
	await review.settings_dialog_checks(game,failures)
	ui.settings_screen.select_category("general")
	await get_tree().process_frame
	check(ui.channel_setting.item_count == 2,"Update channel setting is preserved")
	await capture(game,"07-settings")
	ui.toggle()
	var original_size = game.get_window().size
	for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(540,960)]:
		game.get_window().size = dimensions
		game._fit_screen()
		ui.fit_screen()
		ui.begin_stage()
		ui.open_terminal()
		await get_tree().process_frame
		await get_tree().process_frame
		check(game.safe_rect().grow(1).encloses(ui.command_input.get_global_rect()),"Terminal input fits "+str(dimensions))
		await capture(game,"terminal-%dx%d" % [dimensions.x,dimensions.y])
		ui.close()
		ui.open_pause()
		ui.open_tablet(4)
		await get_tree().process_frame
		check(ui.settings_screen.get_visible_rect().grow(1).encloses(ui.settings_screen.save_button.get_global_rect()),"Settings save fits "+str(dimensions))
		await capture(game,"settings-%dx%d" % [dimensions.x,dimensions.y])
		ui.settings_screen.close_editor()
	game.get_window().size = original_size
	game._fit_screen()
	await get_tree().create_timer(1.05).timeout
	print("INVESTIGATION_SMOKE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"platform":OS.get_name(),"mobile":game.controls.mobile,"touchDefault":touch_default,"keyboardDetected":game.controls.keyboard_seen,"stages":1,"paperJumps":completed_jumps,"cartJumps":cart_jumps,"blasts":0}))
	get_tree().quit(0 if failures.is_empty() else 1)

func field_hud_checks(game):
	var ui = game.ui
	var original_size = game.get_window().size
	for dimensions in [Vector2i(1226,1033),Vector2i(1280,720),Vector2i(960,540),Vector2i(540,960)]:
		game.get_window().size = dimensions
		game._fit_screen()
		ui.fit_screen()
		game.ui.notice("서유진: 서류 나오면 부르세요.")
		for frame in range(3): await get_tree().physics_frame
		ui.fit_field_overlays()
		await get_tree().process_frame
		var bounds = game.safe_rect().grow(1)
		check(ui.field_objective.size.x >= 300 and bounds.encloses(ui.field_objective.get_global_rect()),"Objective stays horizontal at "+str(dimensions))
		check(ui.toast.size.x >= 300 and ui.toast.size.y < 180 and bounds.encloses(ui.toast.get_global_rect()),"NPC subtitle stays readable at "+str(dimensions))
		for overlay in [ui.field_objective,ui.toast,ui.prompt_panel,ui.update_hud,ui.dot]: check(ignores_pointer(overlay),"Passive HUD ignores pointer")
		if not game.controls.mobile and DisplayServer.get_name() != "headless":
			game.player.application_focused = true
			game.player.capture_suspended = false
			game.player.set_enabled(true)
			var before = game.player.rotation.y
			var motion = InputEventMouseMotion.new()
			motion.position = get_viewport().get_final_transform()*ui.field_objective.get_global_rect().get_center()
			motion.global_position = motion.position
			motion.relative = get_viewport().get_final_transform().basis_xform(Vector2(3,0))
			Input.parse_input_event(motion)
			Input.flush_buffered_events()
			await get_tree().process_frame
			check(absf(game.player.rotation.y-before+3*game.player.sensitivity) < .0001,"Mouse look continues over HUD")
		await capture(game,"field-%dx%d" % [dimensions.x,dimensions.y])
	game.get_window().size = original_size
	game._fit_screen()
	ui.fit_screen()

func ignores_pointer(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE: return false
	for child in node.get_children():
		if not ignores_pointer(child): return false
	return true
