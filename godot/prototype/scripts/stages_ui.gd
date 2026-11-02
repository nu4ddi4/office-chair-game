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
	terminal_sidebar.get_child(0).text = "출력실"
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
	channel_setting = OptionButton.new()
	for node in [touch_setting,update_setting,channel_setting]: hidden.add_child(node)
	touch_setting.toggled.connect(game.controls.set_touch)
	update_setting.toggled.connect(game.controls.set_automatic_updates)
	channel_setting.add_item("정식",0)
	channel_setting.add_item("베타",1)
	channel_setting.item_selected.connect(func(index): game.controls.set_update_channel("beta" if index == 1 else "stable"))
	input_status = label(hidden,"")
	update_status = label(hidden,"")
	update_bar = ProgressBar.new()
	hidden.add_child(update_bar)
	update_check = button(hidden,"업데이트 확인",game.check_updates)
	update_download = button(hidden,"설치",func(): if game.updater != null: game.updater.request_install())

func stage_definition() -> Dictionary: return game.content.stages[int(game.state.stage.index)-1]

func guide_info() -> Dictionary:
	var p = game.state.stage.print
	var goal = "퇴근 신청서를 한 장 출력하세요."
	if p.document == "held": goal = "신청서를 결재 서류 접수함에 놓으세요."
	elif p.document == "delivered": goal = "접수함에서 업무 완료를 확인하세요."
	elif p.job != "none": goal = "신청서를 회수하고 출력을 멈추세요."
	return {"title":"STAGE 01 · "+stage_definition().title,"text":goal,"target":""}

func objective_info() -> Dictionary: return guide_info()
func investigation_assigned() -> bool: return false
func sync_memo(): pass

func refresh():
	if terminal_objective == null: return
	var task = guide_info()
	source.text = "PR-01 / LOCAL"
	terminal_objective.text = task.text
	terminal_compact_objective.text = task.text
	hud.text = task.title
	guide.text = task.text
	fit_field_overlays.call_deferred()
	refresh_settings()

func refresh_input_hints(): refresh()

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()

func _terminal_input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		command_input.accept_event()
		close()
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
	if not terminal_buffers.has(game.context): terminal_buffers[game.context] = [{"kind":"banner","text":"PR-01\nREADY\n"}]
	refresh()
	render_terminal()
	if not game.controls.mobile: command_input.grab_focus()

func open_terminal(): show_terminal()
func close():
	if is_instance_valid(settings_screen) and settings_screen.visible: settings_screen.close_editor(); return
	if mode == "main_menu": return
	if mode == "pause": resume_session(); return
	if mode == "intro": entry.show_menu(false); return
	if mode in ["result","exploded"]: open_pause(); return
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
			if not game.commit_stage_transition({"type":"stage.select","payload":{"index":chosen}}): return
			game.stage_world.key = ""
			current_attempt = ""
			begin_stage())
		b.disabled = chosen > game.state.stage.unlocked
		b.custom_minimum_size.y = 52
	_show("stages",stage_picker)

func reset_session():
	game.stage_world.key = ""
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
		"exit","logout": close()
		"clear","cls": clear_terminal()
		"history": print_output(command,"\n".join(history))
		_: game.command(command)
	if mode == "terminal": restore_terminal_focus.call_deferred()

func available_commands() -> Array:
	var rows = []
	for command in ["help","ls","pwd","status","queue","clear","history","exit","pause ","resume ","cancel "]: rows.append({"text":command})
	for filename in stage_definition().files:
		rows.append({"text":"cat "+filename})
		if filename.ends_with(".form"): rows.append({"text":"print "+filename})
	return rows

func command_result(result: Dictionary):
	if result.code == "STAGE_CLEAR": show_result()

func show_result():
	var complete = game.state.stage.phase == "complete"
	result_title.text = "신청서 한 장, 접수 완료" if complete else "출력 업무 완료"
	result_title.add_theme_color_override("font_color",InvestigationTheme.ACCENT)
	result_body.text = "서류도 챙겼고, 프린터도 멈췄습니다.\n오늘의 출력 업무를 마쳤습니다." if complete else stage_definition().clear
	result_retry.visible = true
	result_retry.text = "다시 해 보기"
	result_next.visible = not complete
	result_next.text = "마무리"
	_show("result",result_panel)
	(result_retry if complete else result_next).grab_focus()

func retry_stage():
	if not game.commit_stage_transition({"type":"stage.retry"}): return
	game.stage_world.key = ""
	begin_stage()

func next_stage():
	if not game.commit_stage_transition({"type":"stage.next"}): return
	show_result()

func clear_effects(): pass

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
	clear(modal)
	stage_scroll = ScrollContainer.new()
	stage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(stage_scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",18)
	stage_scroll.add_child(box)
	heading(box,"서유진 · 정비 담당" if id == "print_seo" else game.content.case.npcs[id].name)
	var p = game.state.stage.print
	label(box,"서류 나오면 부르세요." if p.job == "none" else "한 장은 한 장인데, 배송을 여러 번 하네요." if p.document == "tray" else "접수함에 두시면 됩니다.")
	stage_choices = VBoxContainer.new()
	stage_choices.add_theme_constant_override("separation",10)
	box.add_child(stage_choices)
	for line in ["상부 트레이가 꽤 높네요.","의자가 움직이던데요.","알겠습니다."]:
		var selected = line
		var option = button(stage_choices,line,func():
			enter_field()
			if selected.begins_with("상부"): notice("서유진: 점검 발판차도 여기 세워 놨어요.")
			elif selected.begins_with("의자"): notice("서유진: 바퀴는 아직 멀쩡하네요."))
		option.custom_minimum_size.y = 48
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
