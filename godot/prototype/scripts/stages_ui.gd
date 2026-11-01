class_name TerminalStagesUI
extends InvestigationUI

var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var result_next: Button
var result_retry: Button
var result_menu: Button
var stage_picker: PanelContainer
var picks: VBoxContainer
var flash: ColorRect
var burst_count = 0
var effects: Node3D
var shock: Tween
var flights: Array[Tween] = []
var current_attempt = ""
var stage_choices: VBoxContainer
var stage_scroll: ScrollContainer

func setup(controller: InvestigationPrototype):
	game = controller
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = InvestigationTheme.build(game.controls.mobile)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().gui_embed_subwindows = true
	modal = panel(0,0,1,1)
	field_objective = PanelContainer.new()
	field_objective.theme_type_variation = "HudPanel"
	root.add_child(field_objective)
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation",6)
	field_objective.add_child(info)
	hud = label(info,"","SectionLabel")
	guide = label(info,"")
	guide.add_theme_font_size_override("font_size",16)
	prompt_panel = PanelContainer.new()
	prompt_panel.theme_type_variation = "KeyCapPanel"
	root.add_child(prompt_panel)
	prompt = label(prompt_panel,"")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.hide()
	dot = Crosshair.new()
	dot.size = Vector2(28,28)
	root.add_child(dot)
	dot.hide()
	toast = PanelContainer.new()
	toast.theme_type_variation = "HudPanel"
	root.add_child(toast)
	toast.hide()
	message = label(toast,"")
	update_hud = PanelContainer.new()
	update_hud.theme_type_variation = "HudPanel"
	root.add_child(update_hud)
	update_hud.hide()
	var updates_box = VBoxContainer.new()
	update_hud.add_child(updates_box)
	update_hud_label = label(updates_box,"")
	update_hud_bar = ProgressBar.new()
	updates_box.add_child(update_hud_bar)
	build_settings_references()
	super._build_terminal()
	command_input.keep_editing_on_text_submit = true
	terminal_sidebar.get_child(0).text = "이번 PC"
	result_panel = panel(.12,.55,.88,.95)
	var result_box = VBoxContainer.new()
	result_box.add_theme_constant_override("separation",12)
	result_panel.add_child(result_box)
	result_title = label(result_box,"","TitleLabel")
	result_body = label(result_box,"")
	result_next = button(result_box,"다음 업무",next_stage,"PrimaryButton")
	result_retry = button(result_box,"다시 도전",retry_stage,"PrimaryButton")
	for node in [result_next,result_retry]: node.custom_minimum_size.y = 48
	result_menu = button(result_box,"메뉴",open_pause)
	stage_picker = panel(.16,.08,.84,.92)
	var selector = VBoxContainer.new()
	stage_picker.add_child(selector)
	heading(selector,"스테이지 선택")
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selector.add_child(scroll)
	picks = VBoxContainer.new()
	picks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(picks)
	button(selector,"메뉴",open_pause)
	entry = TerminalStageEntry.new()
	entry.build(self)
	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1,.5,.1,0)
	root.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for overlay in [field_objective,prompt_panel,toast,update_hud,dot]: ignore_pointer(overlay)
	fit_screen()
	refresh()
	entry.show_menu(false)

func build_settings_references():
	var hidden = VBoxContainer.new()
	root.add_child(hidden)
	hidden.hide()
	touch_setting = CheckButton.new()
	update_setting = CheckButton.new()
	preview_setting = CheckButton.new()
	for node in [touch_setting,update_setting,preview_setting]: hidden.add_child(node)
	touch_setting.toggled.connect(game.controls.set_touch)
	update_setting.toggled.connect(game.controls.set_automatic_updates)
	preview_setting.toggled.connect(game.controls.set_beta_preview)
	input_status = label(hidden,"")
	update_status = label(hidden,"")
	update_bar = ProgressBar.new()
	hidden.add_child(update_bar)
	update_check = button(hidden,"업데이트 확인",game.check_updates)
	update_download = button(hidden,"설치",func(): if game.updater != null: game.updater.request_install())

func stage_definition() -> Dictionary: return game.content.stages[int(game.state.stage.index)-1]

func guide_info() -> Dictionary:
	return {"title":"STAGE %02d · %s" % [game.state.stage.index,stage_definition().title],"text":stage_definition().goal,"target":stage_definition().get("npc",stage_definition().device)}

func objective_info() -> Dictionary: return guide_info()
func investigation_assigned() -> bool: return false
func sync_memo(): pass

func refresh():
	if terminal_objective == null: return
	var task = guide_info()
	source.text = "PC-%02d / OFFICE OS" % game.state.stage.index
	terminal_objective.text = task.title+"\n\n"+task.text
	terminal_compact_objective.text = task.title+"\n"+task.text
	hud.text = task.title
	guide.text = task.text
	fit_field_overlays.call_deferred()
	refresh_settings()

func refresh_input_hints(): refresh()

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if mode == "terminal": open_pause()
		else: toggle()
		get_viewport().set_input_as_handled()

func _terminal_input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		command_input.accept_event()
		open_pause()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
		command_input.accept_event()
		if not event.echo: execute_command()
	else: super._terminal_input(event)

func restore_terminal_focus():
	if mode == "terminal" and game.state.stage.phase == "playing":
		command_input.grab_focus()
		command_input.caret_column = command_input.text.length()


func _show(next_mode: String, window: Control):
	if is_instance_valid(settings_screen): settings_screen.close_editor(true)
	remember_terminal_draft()
	var focused = get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()
	hide_keyboard()
	for item in [modal,terminal_panel,entry.panel,result_panel,stage_picker]:
		if is_instance_valid(item): item.hide()
	field_objective.hide()
	toast.hide()
	update_hud.hide()
	mode = next_mode
	get_viewport().disable_3d = next_mode in ["main_menu","intro","pause","stages"]
	modal_open = true
	dot.hide()
	prompt_panel.hide()
	game.player.set_enabled(false)
	game.controls.release_touches()
	window.show()

func resume_session():
	if game.blocked_save or not game.session_available: return
	match game.state.stage.phase:
		"clear","complete","exploded": show_result()
		_: begin_stage()

func begin_stage():
	clear_effects()
	game.context = stage_definition().device
	game.stage_world.prepare_stage()
	var attempt = "%d:%d" % [game.state.stage.index,game.state.stage.attempt]
	if current_attempt != attempt:
		terminal_buffers.clear()
		terminal_drafts.clear()
		command_history.clear()
		current_attempt = attempt
	enter_field()

func show_terminal():
	terminal_context = game.context
	_show("terminal",terminal_panel)
	command_input.text = terminal_drafts.get(game.context,"")
	history_index = command_history.get(game.context,[]).size()
	history_draft = command_input.text
	if not terminal_buffers.has(game.context): terminal_buffers[game.context] = [{"kind":"banner","text":"OFFICE OS / PC-%02d\nType help for commands.\n" % game.state.stage.index}]
	refresh()
	render_terminal()
	if not game.controls.mobile: command_input.grab_focus()

func open_terminal(): show_terminal()
func close():
	if is_instance_valid(settings_screen) and settings_screen.visible: settings_screen.close_editor(); return
	if mode == "main_menu": return
	if mode == "pause": resume_session(); return
	if mode == "intro": entry.show_menu(false); return
	enter_field()

func enter_field():
	_show("field",field_objective)
	modal_open = false
	get_viewport().disable_3d = false
	game.player.set_enabled(true)
	dot.show()
	refresh()

func open_briefing(): entry.show_intro()

func open_tablet(index = 3):
	if index == 4: open_rebinding()
	else: open_stage_picker()

func open_stage_picker():
	clear(picks)
	for i in range(TerminalStagesEngine.COUNT):
		var chosen = i+1
		var b = button(picks,"%02d   %s" % [chosen,game.content.stages[i].title if chosen <= game.state.stage.get("entered",maxi(int(game.state.stage.index),game.state.stage.cleared.size())) else "???"],func():
			game.dispatch({"type":"stage.select","payload":{"index":chosen}})
			game.save_now()
			game.stage_world.key = ""
			current_attempt = ""
			begin_stage())
		b.disabled = chosen > game.state.stage.unlocked
		b.custom_minimum_size.y = 52
	_show("stages",stage_picker)

func reset_session():
	if is_instance_valid(settings_screen): settings_screen.close_editor(true)
	clear_effects()
	terminal_buffers.clear()
	terminal_drafts.clear()
	command_history.clear()
	current_attempt = ""
	entry.intro_seen = false
	entry.show_intro()

func execute_command():
	if mode != "terminal" or game.state.stage.phase != "playing": return
	var command = command_input.text.strip_edges()
	if command.is_empty(): return
	command_input.clear()
	history_draft = ""
	var history = command_history.get(game.context,[])
	if history.is_empty() or history[-1] != command: history.append(command)
	if history.size() > 80: history.pop_front()
	command_history[game.context] = history
	history_index = history.size()
	match command.to_lower():
		"exit","logout": open_pause()
		"clear","cls": clear_terminal()
		"history": print_output(command,"\n".join(history))
		_: game.command(command)
	if mode == "terminal": restore_terminal_focus.call_deferred()

func available_commands() -> Array:
	var rows = []
	for command in ["help","ls","pwd","clear","history","exit"]+stage_definition().outputs.keys(): rows.append({"text":command})
	for filename in stage_definition().files: rows.append({"text":"cat "+filename})
	# Completion covers visible files and read-only commands; action arguments
	# remain the player's input, including the risky stages.
	return rows

func command_result(result: Dictionary):
	if result.code in ["STAGE_CLEAR","STAGE_EXPLODED"]:
		game.save_now()
		show_result()
		if result.code == "STAGE_EXPLODED":
			explode()
			result_panel.hide()
			reveal_failure(game.state.stage.index,game.state.stage.attempt)

func reveal_failure(index: int, attempt: int):
	await get_tree().create_timer(.8).timeout
	if game.state.stage.index == index and game.state.stage.attempt == attempt and game.state.stage.phase == "exploded" and mode == "exploded":
		result_panel.show()

func show_result():
	var phase = game.state.stage.phase
	var failed = phase == "exploded"
	result_title.text = "펑." if failed else "퇴근 성공" if phase == "complete" else "업무 완료"
	result_title.add_theme_color_override("font_color",InvestigationTheme.DANGER if failed else InvestigationTheme.ACCENT)
	result_body.text = stage_definition().failure if failed else "처리한 업무: 6건\n터뜨린 PC: %d대\n내일은 계산기를 드립니다." % game.state.stage.blasts if phase == "complete" else stage_definition().clear
	result_retry.visible = failed
	result_next.visible = phase == "clear"
	result_next.text = "퇴근하기" if game.state.stage.index == TerminalStagesEngine.COUNT else "다음 업무"
	_show("exploded" if failed else "result",result_panel)
	(result_retry if failed else result_next if phase == "clear" else result_menu).grab_focus()

func retry_stage():
	game.dispatch({"type":"stage.retry"})
	game.save_now()
	begin_stage()

func next_stage():
	game.dispatch({"type":"stage.next"})
	game.save_now()
	if game.state.stage.phase == "complete": show_result()
	else: begin_stage()

func explode():
	clear_effects()
	burst_count += 1
	effects = Node3D.new()
	game.add_child(effects)
	effects.global_position = game.targets[game.context].global_position
	var debris = BoxMesh.new()
	debris.size = Vector3(.18,.18,.18)
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,.45,.05)
	debris.material = material
	for i in range(12):
		var piece = MeshInstance3D.new()
		piece.mesh = debris
		effects.add_child(piece)
		var flight = create_tween().set_parallel()
		flights.append(flight)
		var direction = Vector3(sin(i*2.4),.5+float(i%3)*.3,cos(i*2.4))
		flight.tween_property(piece,"position",direction*1.7,.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flight.tween_property(piece,"rotation",direction*5,.65)
		flight.tween_property(piece,"scale",Vector3.ZERO,.65)
		flight.finished.connect(piece.queue_free)
	flash.color = Color(1,.45,.05,.75)
	shock = create_tween()
	shock.tween_property(flash,"color:a",0.0,.22)
	game.stage_world.break_computer(game.context)
	game.player.camera.h_offset = .045
	shock.tween_property(game.player.camera,"h_offset",-.035,.05)
	shock.tween_property(game.player.camera,"h_offset",0.0,.1)
	play_boom()

func play_boom():
	var sample = PackedByteArray()
	var count = 11025
	sample.resize(count*2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 718
	for i in range(count):
		var envelope = pow(1.0-float(i)/count,2)
		var value = (rng.randf_range(-1,1)*.65+sin(float(i)*.04)*.35)*envelope
		sample.encode_s16(i*2,int(value*20000))
	var sound = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	sound.data = sample
	var player = AudioStreamPlayer.new()
	player.stream = sound
	player.bus = "SFX"
	player.volume_db = -8
	game.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func clear_effects():
	for flight in flights:
		if flight != null and flight.is_valid(): flight.kill()
	flights.clear()
	if is_instance_valid(effects): effects.queue_free()
	if shock != null: shock.kill()
	if flash != null: flash.color.a = 0
	game.stage_world.restore_view()
	game.player.camera.h_offset = 0
	game.player.camera.v_offset = 0

func fit_screen():
	if root == null or terminal_sidebar == null: return
	var safe = game.safe_rect()
	fit_field_overlays()
	var compact = safe.size.x < 1000
	result_panel.anchor_left = .04 if compact else .12
	result_panel.anchor_right = .96 if compact else .88
	result_panel.anchor_top = .38 if safe.size.y < 640 else .55
	terminal_sidebar.visible = not compact
	terminal_compact_objective.visible = compact
	command_input.custom_minimum_size.y = 48 if game.controls.mobile else 36
	if entry.panel != null: entry.fit()
	if is_instance_valid(settings_screen):
		settings_screen.size = Vector2i(safe.size)
		settings_screen.position = Vector2i(safe.position)
	for popup in root.find_children("*","AcceptDialog",true,false):
		if popup.visible and popup.has_meta("scroll_notice"): fit_notice.call_deferred(popup)
	for window in [terminal_panel,result_panel,stage_picker,modal]:
		window.offset_left = safe.position.x
		window.offset_right = safe.end.x-get_viewport().get_visible_rect().size.x
		window.offset_top = safe.position.y
		window.offset_bottom = safe.end.y-get_viewport().get_visible_rect().size.y

func _process(_delta):
	if game != null and mode == "field":
		super._process(_delta)
	if game == null or mode != "terminal" or not game.controls.mobile or not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): return
	var keyboard = DisplayServer.virtual_keyboard_get_height()
	terminal_compact_objective.visible = keyboard == 0 and game.safe_rect().size.x < 1000
	terminal_sidebar.visible = keyboard == 0 and game.safe_rect().size.x >= 1000
	terminal.custom_minimum_size.y = 24 if keyboard > 0 else 80
	terminal_panel.anchor_bottom = clampf(.94-float(keyboard)/maxf(1,DisplayServer.window_get_size().y),.3,.94)

func talk_to(id: String):
	var definition = stage_definition()
	if definition.get("npc","") != id:
		notice("지금은 내 담당이 아닌데? 담당자를 찾아봐.")
		return
	clear(modal)
	stage_scroll = ScrollContainer.new()
	stage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(stage_scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",18)
	stage_scroll.add_child(box)
	heading(box,game.content.case.npcs[id].name)
	label(box,definition.dialogue)
	stage_choices = VBoxContainer.new()
	stage_choices.add_theme_constant_override("separation",10)
	box.add_child(stage_choices)
	for i in range(definition.choices.size()):
		var choice = i
		var option = button(stage_choices,definition.choices[i],func():
			var result = game.dispatch({"type":"stage.talk","payload":{"choice":choice}})
			command_result(result))
		option.custom_minimum_size.y = 48
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(box,"잠깐만, 다시 생각할게요",enter_field)
	_show("stage_dialogue",modal)

func ignore_pointer(node: Node):
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): ignore_pointer(child)

func fit_field_overlays():
	var safe = game.safe_rect()
	var width = minf(480,safe.size.x-32)
	field_objective.position = safe.position+Vector2(16,16)
	field_objective.custom_minimum_size.x = width
	guide.custom_minimum_size.x = width-36
	hud.custom_minimum_size.x = width-36
	field_objective.size = Vector2(width,0)
	var notice_width = minf(440,safe.size.x-32)
	toast.custom_minimum_size.x = notice_width
	message.custom_minimum_size.x = notice_width-36
	toast.size = Vector2(notice_width,0)
	toast.position = safe.position+Vector2(16,field_objective.get_combined_minimum_size().y+28)
	update_hud.position = Vector2(safe.position.x+16,safe.end.y-80-(160 if game.controls.touch_enabled else 0))
	update_hud_label.custom_minimum_size.x = minf(300,safe.size.x-68)
	place_prompt()

func place_prompt():
	var safe = game.safe_rect()
	var longest = 0.0
	var font = prompt.get_theme_font("font")
	for line in prompt.text.split("\n"):
		longest = maxf(longest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,prompt.get_theme_font_size("font_size")).x)
	var width = clampf(longest+36,220,safe.size.x-32)
	prompt.custom_minimum_size.x = width-36
	prompt_panel.custom_minimum_size.x = width
	prompt_panel.size = Vector2(width,0)
	prompt_panel.reset_size()
	prompt_panel.position = Vector2(safe.position.x+(safe.size.x-prompt_panel.size.x)/2,safe.end.y-prompt_panel.size.y-(192 if game.controls.touch_enabled else 28))

func notice(text: String):
	super.notice(text)
	fit_field_overlays.call_deferred()
