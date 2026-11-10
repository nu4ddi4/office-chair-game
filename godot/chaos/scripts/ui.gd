class_name ChaosUI
extends CanvasLayer

# Menus are paperwork: a warm sheet with an approval block (결재란) on a dimmed
# office. The field HUD uses a sticky note for the objective, a dark glass card
# with a live coffee mug, an LCD segment timer and key caps for controls.

var game
var root: Control
var hud: Control
var overlay: Control
var frame: VBoxContainer
var sheet: PanelContainer
var column: VBoxContainer
var approvals: Array[ChaosStamp] = []
var doc_number: Label
var stamp_layer: Control
var subtitle: Label
var subtitle_panel: Control
var subtitle_left = 0.0
var progress: ProgressBar
var rebinding = ""
var mode = "main"
var update_label: Label
var update_progress: ProgressBar
var update_check_button: Button
var update_install_button: Button
var sheet_tween: Tween
# Field HUD
var note: PanelContainer
var note_mission: Label
var note_step: Label
var note_distance: Label
var clock: PanelContainer
var clock_label: Label
var damage_chip: PanelContainer
var damage_label: Label
var update_chip: Label
var coffee_card: PanelContainer
var cup: ChaosCoffeeCup
var coffee_amount: Label
var coffee_need: Label
var coffee_heat: Label
var coffee_state: Label
var speed_box: VBoxContainer
var speed_label: Label
var boost_pill: PanelContainer
var alert: Label
var controls_holder: CenterContainer
var hints_holder: CenterContainer
var controls_key = ""
var hints_key = ""
var alert_time = 0.0

func setup(owner):
	game = owner
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	root = Control.new(); add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ChaosStyle.build_theme()
	_build_hud()
	_build_overlay()

# ---------------------------------------------------------------- HUD

func _build_hud():
	hud = Control.new(); root.add_child(hud); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Objective on a sticky note.
	note = PanelContainer.new(); hud.add_child(note)
	note.add_theme_stylebox_override("panel",ChaosStyle.postit())
	note.position = Vector2(36,30); note.rotation = -.025
	note.custom_minimum_size = Vector2(340,0)
	var note_box = VBoxContainer.new(); note.add_child(note_box)
	note_box.add_theme_constant_override("separation",2)
	note_mission = ChaosStyle.label(note_box,"",14,720,ChaosStyle.INK_SOFT)
	note_step = ChaosStyle.label(note_box,"",27,840)
	note_distance = ChaosStyle.label(note_box,"",15,600,ChaosStyle.INK_SOFT)
	# Timer, damage and update notice stacked on the right.
	var right = VBoxContainer.new(); hud.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -36; right.offset_top = 30
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.add_theme_constant_override("separation",10)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock = PanelContainer.new(); right.add_child(clock)
	clock.add_theme_stylebox_override("panel",ChaosStyle.glass(10))
	clock.size_flags_horizontal = Control.SIZE_SHRINK_END
	var clock_box = VBoxContainer.new(); clock.add_child(clock_box)
	clock_box.add_theme_constant_override("separation",-4)
	ChaosStyle.label(clock_box,"구간 남은 시간",13,600,ChaosStyle.ON_GLASS_SOFT)
	clock_label = ChaosStyle.label(clock_box,"00:00",46,820,ChaosStyle.AMBER)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	damage_chip = PanelContainer.new(); right.add_child(damage_chip)
	damage_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	damage_chip.add_theme_stylebox_override("panel",ChaosStyle.margins(ChaosStyle.flat(Color(ChaosStyle.STAMP,.92),6),12,5))
	damage_label = ChaosStyle.label(damage_chip,"",15,760,Color.WHITE)
	update_chip = ChaosStyle.label(right,"",14,600,ChaosStyle.ON_GLASS_SOFT)
	update_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Coffee card with the live mug.
	coffee_card = PanelContainer.new(); hud.add_child(coffee_card)
	coffee_card.add_theme_stylebox_override("panel",ChaosStyle.glass(14))
	coffee_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	coffee_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	coffee_card.offset_left = 36; coffee_card.offset_bottom = -34
	var coffee_row = HBoxContainer.new(); coffee_card.add_child(coffee_row)
	coffee_row.add_theme_constant_override("separation",10)
	cup = ChaosCoffeeCup.new(); coffee_row.add_child(cup)
	cup.setup(game.coffee,game.chair)
	var coffee_text = VBoxContainer.new(); coffee_row.add_child(coffee_text)
	coffee_text.alignment = BoxContainer.ALIGNMENT_CENTER
	coffee_text.custom_minimum_size.x = 150
	coffee_text.add_theme_constant_override("separation",0)
	ChaosStyle.label(coffee_text,"부장님 커피",13,600,ChaosStyle.ON_GLASS_SOFT)
	coffee_amount = ChaosStyle.label(coffee_text,"100%",42,850,ChaosStyle.ON_GLASS)
	coffee_need = ChaosStyle.label(coffee_text,"",14,560,ChaosStyle.ON_GLASS_SOFT)
	coffee_heat = ChaosStyle.label(coffee_text,"",17,760,ChaosStyle.AMBER)
	coffee_state = ChaosStyle.label(coffee_text,"",14,760,ChaosStyle.AMBER)
	# Speed readout while pushing.
	speed_box = VBoxContainer.new(); hud.add_child(speed_box)
	speed_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN; speed_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speed_box.offset_right = -40; speed_box.offset_bottom = -34
	speed_box.add_theme_constant_override("separation",-6)
	speed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boost_pill = PanelContainer.new(); speed_box.add_child(boost_pill)
	boost_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	boost_pill.add_theme_stylebox_override("panel",ChaosStyle.margins(ChaosStyle.flat(ChaosStyle.STAMP,10),12,3))
	ChaosStyle.label(boost_pill,"부스트",15,850,Color.WHITE)
	speed_label = ChaosStyle.label(speed_box,"0.0",54,850,ChaosStyle.ON_GLASS)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var unit = ChaosStyle.label(speed_box,"m/s",16,600,ChaosStyle.ON_GLASS_SOFT)
	unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Alerts about the boss.
	alert = ChaosStyle.label(hud,"",30,900,ChaosStyle.DANGER)
	alert.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	alert.offset_top = 120; alert.offset_left = -300; alert.offset_right = 300
	alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert.add_theme_color_override("font_outline_color",Color(0,0,0,.75)); alert.add_theme_constant_override("outline_size",8)
	var crosshair = ChaosStyle.label(hud,"·",32,700,Color(1,1,1,.8))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -10; crosshair.offset_top = -20
	# Bottom centre: speech bubble, controls, context hints, reset progress.
	var bottom = VBoxContainer.new(); hud.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -28; bottom.offset_left = 360; bottom.offset_right = -360
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation",10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_center = CenterContainer.new(); bottom.add_child(bubble_center)
	bubble_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble = PanelContainer.new(); bubble_center.add_child(bubble)
	var bubble_style = ChaosStyle.margins(ChaosStyle.flat(ChaosStyle.PAPER,16),18,10)
	bubble_style.shadow_color = Color(0,0,0,.4); bubble_style.shadow_size = 14; bubble_style.shadow_offset = Vector2(0,6)
	bubble.add_theme_stylebox_override("panel",bubble_style)
	var bubble_row = HBoxContainer.new(); bubble.add_child(bubble_row)
	bubble_row.add_theme_constant_override("separation",12)
	var name_pill = PanelContainer.new(); bubble_row.add_child(name_pill)
	name_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_pill.add_theme_stylebox_override("panel",ChaosStyle.margins(ChaosStyle.flat(ChaosStyle.STAMP,10),10,2))
	ChaosStyle.label(name_pill,"부장님",14,820,Color.WHITE)
	subtitle = ChaosStyle.label(bubble_row,"",24,560)
	subtitle_panel = bubble_center
	controls_holder = CenterContainer.new(); bottom.add_child(controls_holder)
	controls_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints_holder = CenterContainer.new(); bottom.add_child(hints_holder)
	hints_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var progress_center = CenterContainer.new(); bottom.add_child(progress_center)
	progress_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress = ProgressBar.new(); progress_center.add_child(progress)
	progress.custom_minimum_size = Vector2(220,6)
	progress.show_percentage = false; progress.max_value = 1; progress.visible = false

# ---------------------------------------------------------------- Menus

func _build_overlay():
	overlay = Control.new(); root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = TextureRect.new(); overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0,.48,1])
	gradient.colors = PackedColorArray([Color(.02,.04,.05,.95),Color(.02,.04,.05,.8),Color(.02,.04,.05,.35)])
	var texture = GradientTexture2D.new(); texture.gradient = gradient; texture.width = 256; texture.height = 4
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	frame = VBoxContainer.new(); overlay.add_child(frame)
	frame.anchor_top = 0; frame.anchor_bottom = 1; frame.anchor_left = 0; frame.anchor_right = 0
	frame.offset_top = 40; frame.offset_bottom = -40
	frame.alignment = BoxContainer.ALIGNMENT_CENTER
	sheet = PanelContainer.new(); frame.add_child(sheet)
	sheet.add_theme_stylebox_override("panel",ChaosStyle.paper())
	var doc = VBoxContainer.new(); sheet.add_child(doc)
	doc.add_theme_constant_override("separation",0)
	var header = HBoxContainer.new(); doc.add_child(header)
	var titles = VBoxContainer.new(); header.add_child(titles)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation",2)
	ChaosStyle.label(titles,"OFFICE CHAIR CHAOS  ·  사내 운행 일지",12,780,ChaosStyle.STAMP)
	doc_number = ChaosStyle.label(titles,"",12,500,ChaosStyle.INK_SOFT)
	var block = HBoxContainer.new(); header.add_child(block)
	block.add_theme_constant_override("separation",-1)
	for role in ["담당","과장","부장"]:
		var cell = VBoxContainer.new(); block.add_child(cell)
		cell.add_theme_constant_override("separation",-1)
		var head = PanelContainer.new(); cell.add_child(head)
		head.add_theme_stylebox_override("panel",ChaosStyle.margins(ChaosStyle.flat(ChaosStyle.PAPER_SHADE,0,1,ChaosStyle.INK_FAINT),6,1))
		var role_label = ChaosStyle.label(head,role,11,700,ChaosStyle.INK_SOFT); role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var body = PanelContainer.new(); cell.add_child(body)
		body.add_theme_stylebox_override("panel",ChaosStyle.margins(ChaosStyle.flat(Color(0,0,0,0),0,1,ChaosStyle.INK_FAINT),4,4))
		var mark = ChaosStamp.new().setup("",40,true,ChaosStyle.STAMP,randf_range(-.4,.2))
		body.add_child(mark)
		approvals.append(mark)
	var rule_gap = Control.new(); rule_gap.custom_minimum_size.y = 14; doc.add_child(rule_gap)
	var rule = ColorRect.new(); rule.color = ChaosStyle.STAMP; rule.custom_minimum_size.y = 3; doc.add_child(rule)
	var rule_gap2 = Control.new(); rule_gap2.custom_minimum_size.y = 2; doc.add_child(rule_gap2)
	var rule2 = ColorRect.new(); rule2.color = ChaosStyle.STAMP; rule2.custom_minimum_size.y = 1; doc.add_child(rule2)
	var rule_gap3 = Control.new(); rule_gap3.custom_minimum_size.y = 20; doc.add_child(rule_gap3)
	column = VBoxContainer.new(); doc.add_child(column)
	column.add_theme_constant_override("separation",0)
	stamp_layer = Control.new(); overlay.add_child(stamp_layer)
	stamp_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stamp_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_approvals():
	var done = game.store.data.completed.size()
	var names = ["김","박","최"]
	var earned = [true,done>=3,done>=6]
	for i in range(3):
		approvals[i].text = names[i] if earned[i] else ""
		approvals[i].queue_redraw()
	doc_number.text = "문서번호 OCC-%s  ·  결재 %d/6" % [str(ProjectSettings.get_setting("application/config/version")),done]

func clear(title: String, body: String, width = 620):
	for child in column.get_children():
		column.remove_child(child); child.queue_free()
	for child in stamp_layer.get_children(): child.queue_free()
	frame.offset_left = 120; frame.offset_right = 120+width
	var heading = ChaosStyle.label(column,title,46,900)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_constant_override("line_spacing",-6)
	if not body.is_empty():
		var gap = Control.new(); gap.custom_minimum_size.y = 8; column.add_child(gap)
		var description = ChaosStyle.label(column,body,17,430,ChaosStyle.INK_SOFT)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size = Vector2(width-100,0)
	_space(18)
	_refresh_approvals()
	overlay.show(); hud.hide()
	game.clear_inputs()
	game.get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.audio.update_rolling(0)
	if sheet_tween: sheet_tween.kill()
	if game.qa:
		# QA captures must show the settled sheet, not the first frame of the slide-in.
		sheet.modulate.a = 1; return
	sheet.modulate.a = 0
	frame.offset_left = 92; frame.offset_right = 92+width
	sheet_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sheet_tween.tween_property(sheet,"modulate:a",1.0,.18)
	sheet_tween.tween_property(frame,"offset_left",120.0,.22)
	sheet_tween.tween_property(frame,"offset_right",120.0+width,.22)

func _space(height: float):
	var gap = Control.new(); gap.custom_minimum_size.y = height; column.add_child(gap)

func button(text: String, callback: Callable, disabled = false, primary = false) -> Button:
	var result = Button.new(); result.text = text; result.disabled = disabled
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.custom_minimum_size.y = 50
	if primary:
		result.add_theme_font_override("font",ChaosStyle.font(820))
		result.add_theme_color_override("font_color",ChaosStyle.STAMP)
		result.add_theme_color_override("font_hover_color",ChaosStyle.STAMP)
		result.add_theme_color_override("font_focus_color",ChaosStyle.STAMP)
	column.add_child(result); result.pressed.connect(callback)
	return result

func _form_row() -> HBoxContainer:
	var holder = PanelContainer.new(); column.add_child(holder)
	var line = ChaosStyle.flat(Color(0,0,0,0)); line.border_width_bottom = 1; line.border_color = ChaosStyle.PAPER_LINE
	holder.add_theme_stylebox_override("panel",ChaosStyle.margins(line,16,8))
	var row = HBoxContainer.new(); holder.add_child(row)
	row.add_theme_constant_override("separation",16)
	return row

func _field(name: String, value: String, value_color = ChaosStyle.INK) -> HBoxContainer:
	var row = _form_row()
	var key = ChaosStyle.label(row,name,17,560,ChaosStyle.INK_SOFT); key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ChaosStyle.label(row,value,19,800,value_color)
	return row

func main_menu():
	mode = "main"
	clear("김 대리,\n나 좀 밀어봐","부장님은 걷지 않습니다. 김 대리는 제대로 걷지 못합니다.")
	var keys = ChaosStyle.key_row(column,[["W","A","S","D","이동"],["E","손잡이"],["Shift","부스트"]],true,15)
	keys.add_theme_constant_override("separation",5)
	_space(18)
	var can_continue = not (game.store.data.resume.is_empty() and game.store.data.completed.is_empty())
	var first = button("계속하기",func(): game.continue_game(),not can_continue,can_continue)
	if not game.store.error.is_empty(): ChaosStyle.label(column,game.store.error,15,600,ChaosStyle.STAMP)
	if game.updates!=null and not game.updates.local_notice.is_empty():
		var notice = ChaosStyle.label(column,game.updates.local_notice,15,500,ChaosStyle.INK_SOFT); notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var start = button("새 게임",confirm_new,false,not can_continue)
	button("미션 선택",missions)
	button("설정",settings)
	if game.updates!=null and not game.updates.latest.is_empty(): button("업데이트 "+str(game.updates.latest.version),updates_menu)
	button("크레딧",credits)
	button("종료",func(): game.get_tree().quit())
	(first if can_continue else start).grab_focus()

func confirm_new():
	if game.store.data.completed.is_empty() and game.store.data.resume.is_empty(): game.new_game(); return
	mode = "confirm"
	clear("처음부터 출근할까요?","현재 진행과 미션 기록이 초기화됩니다. 설정은 유지됩니다.",560)
	button("처음부터 시작",func(): game.new_game(),false,true)
	button("돌아가기",main_menu).grab_focus()

func field():
	mode = "field"; rebinding = ""
	for child in stamp_layer.get_children(): child.queue_free()
	overlay.hide(); hud.show()
	game.get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func pause_menu():
	mode = "pause"
	clear("잠깐 정차","부장님도 잠시 기다립니다.",520)
	button("계속하기",field,false,true).grab_focus()
	button("체크포인트로 복구",func(): game.retry())
	button("설정",settings)
	button("미션 선택",missions)
	button("메인 화면",func(): game.persist_checkpoint(); main_menu())

func missions():
	mode = "missions"
	clear("오늘의 업무","완료한 업무는 다시 도전할 수 있습니다. 도장은 정시·무사·알뜰 운행입니다.",780)
	for definition in game.missions:
		var id = int(definition.id)
		var locked = id>int(game.store.data.unlocked)
		var record: Dictionary = game.store.data.records.get(str(id),{})
		var row = button("",func(): game.start_mission(id),locked)
		row.custom_minimum_size.y = 76
		var content = HBoxContainer.new(); row.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 18; content.offset_right = -14
		content.add_theme_constant_override("separation",16)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var number = ChaosStyle.label(content,"%02d" % id,30,900,ChaosStyle.INK_FAINT if locked else ChaosStyle.STAMP)
		number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var texts = VBoxContainer.new(); content.add_child(texts)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL; texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override("separation",0); texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ChaosStyle.label(texts,str(definition.title),20,780,ChaosStyle.INK_FAINT if locked else ChaosStyle.INK)
		var brief = ChaosStyle.label(texts,str(definition.brief),13,450,ChaosStyle.INK_FAINT if locked else ChaosStyle.INK_SOFT)
		brief.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; brief.clip_text = true
		brief.custom_minimum_size.x = 330
		if locked:
			var lock = ChaosStamp.new().setup("미결",78,false,ChaosStyle.INK_FAINT,.06)
			content.add_child(lock); lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			continue
		var medals: Array = record.get("medals",[false,false,false])
		for i in range(3):
			var medal = ChaosStamp.new().setup(["정시","무사","알뜰"][i],44,true,ChaosStyle.STAMP,randf_range(-.35,.25))
			medal.set_inked(not record.is_empty() and medals[i])
			content.add_child(medal); medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var best = ChaosStyle.label(content,"%d초" % int(record.time) if not record.is_empty() else "—",16,700,ChaosStyle.INK_SOFT)
		best.custom_minimum_size.x = 52; best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		best.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_space(10)
	button("돌아가기",func(): pause_menu() if game.run!=null and (game.run.phase=="playing" or game.escaping) else main_menu())

func settings():
	mode = "settings"
	clear("환경 설정","슬라이더를 움직이거나 오른쪽 값을 눌러 바꾸세요.",680)
	var values: Dictionary = game.store.data.settings
	_slider("마우스 감도",values.sensitivity,.0005,.008,.0001,func(v): values.sensitivity=v,func(v): return "%.1f" % (v*1000))
	_slider("시야각",values.fov,60,90,1,func(v): values.fov=v,func(v): return "%d°" % int(v))
	_slider("음량",values.volume,0,1,.05,func(v): values.volume=v,func(v): return "%d%%" % int(round(v*100)))
	_slider("자막 크기",values.subtitle_size,18,36,1,func(v): values.subtitle_size=int(v),func(v): return "%d" % int(v))
	_choice("잡기 방식","누르는 동안" if values.hold_grip else "클릭으로 유지",func(): values.hold_grip=not values.hold_grip; settings())
	_choice("화면 흔들림","켜짐" if values.shake else "꺼짐",func(): values.shake=not values.shake; settings())
	_choice("그래픽 품질",["낮음","중간","높음"][int(values.quality)],func(): values.quality=(int(values.quality)+1)%3; settings())
	_space(10)
	button("키 변경",key_settings)
	button("업데이트",updates_menu)
	button("저장하고 돌아가기",func(): game.apply_settings(); game.store.write(); pause_menu() if game.run!=null and (game.run.phase=="playing" or game.escaping) else main_menu(),false,true)

func _slider(title: String, value: float, minimum: float, maximum: float, step: float, changed: Callable, shown = null):
	var row = _form_row()
	var name_label = ChaosStyle.label(row,title,17,560,ChaosStyle.INK_SOFT); name_label.custom_minimum_size.x = 150
	var slider = HSlider.new(); row.add_child(slider)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = minimum; slider.max_value = maximum; slider.step = step; slider.value = value
	var readout = ChaosStyle.label(row,"",17,800)
	readout.custom_minimum_size.x = 56; readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var show = func(v): readout.text = shown.call(v) if shown!=null else str(v)
	show.call(value)
	slider.value_changed.connect(changed)
	slider.value_changed.connect(show)

func _choice(title: String, value: String, callback: Callable) -> Button:
	var row = _form_row()
	var name_label = ChaosStyle.label(row,title,17,560,ChaosStyle.INK_SOFT); name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chip = Button.new(); row.add_child(chip)
	chip.theme_type_variation = "Chip"; chip.text = value + "  ›"
	chip.pressed.connect(callback)
	return chip

func key_settings():
	mode = "keys"
	clear("키 변경","바꿀 항목을 누른 뒤 새 키를 입력하세요. Esc로 취소합니다. 마우스 양손 잡기는 고정입니다.",620)
	var names = {"forward":"앞으로","back":"뒤로","left":"왼쪽","right":"오른쪽","sprint":"달리기 / 부스트","brace":"버티기 / 일어나기","interact":"상황별 행동","reset":"체크포인트 복구"}
	for key in names:
		var chip = _choice(names[key],"키를 누르세요" if rebinding==key else OS.get_keycode_string(game.keycode(key)),func(): rebinding=key; key_settings())
		chip.text = chip.text.trim_suffix("  ›")
		if rebinding==key: chip.add_theme_color_override("font_color",ChaosStyle.STAMP)
	_space(10)
	button("돌아가기",func(): rebinding=""; game.apply_settings(); settings())

func credits():
	mode = "credits"
	clear("함께 만든 사무실","",620)
	for entry in [["사무실","Interior 07 재배치·확장"],["의자","CMHT Oculus · Poly Pizza · CC BY 3.0"],["재질·소품","Poly Haven · CC0"],["한국어 폰트","Noto Sans KR · SIL OFL"],["엔진","Godot · MIT"]]:
		_field(entry[0],entry[1])
	_space(8)
	var tail = ChaosStyle.label(column,"전체 고지는 설치 폴더의 LICENSES.txt와 아래 화면에서 확인할 수 있습니다.",14,450,ChaosStyle.INK_SOFT)
	tail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tail.custom_minimum_size.x = 520
	_space(12)
	button("전체 라이선스",notices)
	button("돌아가기",main_menu)

func result(success: bool):
	mode = "result"
	var run: ChaosMissionRun = game.run
	var mission = run.mission
	var rows: Array[Control] = []
	if success:
		clear("정상 퇴근" if int(mission.id)==6 else "업무 완료","업무 보고서  ·  %02d %s" % [int(mission.id),mission.title],700)
		var medals = run.medals()
		rows.append(_field("운행 시간","%d초  (목표 %d초)" % [int(run.elapsed),int(mission.target_time)]).get_parent())
		rows.append(_field("부장님 낙하","%d회" % run.falls,ChaosStyle.STAMP if run.falls>0 else ChaosStyle.INK).get_parent())
		rows.append(_field("복구","%d회" % run.retries).get_parent())
		rows.append(_field("파손액","%s원" % _won(run.damage),ChaosStyle.STAMP if run.damage>int(mission.damage_budget) else ChaosStyle.INK).get_parent())
		var coffee_text = "%d%%" % int(game.coffee.amount)
		if mission.has("min_temp"): coffee_text += "  ·  %d°C" % int(game.coffee.temperature)
		rows.append(_field("남은 커피",coffee_text).get_parent())
		_space(18)
		var stamps = HBoxContainer.new(); column.add_child(stamps)
		stamps.add_theme_constant_override("separation",18)
		for i in range(3):
			var holder = VBoxContainer.new(); stamps.add_child(holder)
			holder.add_theme_constant_override("separation",2)
			var medal = ChaosStamp.new().setup(["정시","무사","알뜰"][i],64,true,ChaosStyle.STAMP,randf_range(-.35,.25))
			medal.set_inked(medals[i]); holder.add_child(medal)
			var caption = ChaosStyle.label(holder,["정시 운행","무사 운행","알뜰 운행"][i],12,650,ChaosStyle.INK_SOFT)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rows.append(holder)
		_space(16)
		if int(mission.id)<6: button("다음 업무",func(): game.start_mission(int(mission.id)+1),false,true).grab_focus()
	else:
		clear("잠깐만, 김 대리",run.reason+"\n가까운 체크포인트에서 바로 다시 시작할 수 있습니다.",620)
		button("재도전",func(): game.retry(),false,true).grab_focus()
	button("미션 다시 시작",func(): game.start_mission(int(mission.id)))
	button("미션 선택",missions)
	button("메인 화면",main_menu)
	_reveal(rows,success)

# Report lines appear one by one, then the verdict stamp slams onto the sheet.
func _reveal(rows: Array[Control], success: bool):
	for row in rows: row.modulate.a = 0
	var verdict = ChaosStamp.new().setup("승인" if success else "반려",210,false,ChaosStyle.STAMP if success else ChaosStyle.INK,-.16 if success else .12)
	stamp_layer.add_child(verdict)
	verdict.modulate.a = 0
	# Bound to the stamp: leaving the report screen frees it and cancels the whole sequence.
	var tween = verdict.create_tween()
	for row in rows: tween.tween_property(row,"modulate:a",1.0,.12)
	tween.tween_interval(.12)
	tween.tween_callback(func():
		if not is_instance_valid(verdict): return
		verdict.position = sheet.global_position+Vector2(sheet.size.x-262,sheet.size.y-150)
		verdict.scale = Vector2(2.4,2.4)
		var slam = verdict.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slam.tween_property(verdict,"modulate:a",.92,.12)
		slam.tween_property(verdict,"scale",Vector2.ONE,.2)
		slam.chain().tween_callback(func():
			game.audio.play("impact",.7)
			var shake = verdict.create_tween()
			var base = frame.offset_left
			for k in range(4): shake.tween_property(frame,"offset_left",base+(6 if k%2==0 else -6),.03)
			shake.tween_property(frame,"offset_left",base,.03)))

func _won(value: int) -> String:
	var digits = str(value); var out = ""
	for i in range(digits.length()):
		if i>0 and (digits.length()-i)%3==0: out += ","
		out += digits[i]
	return out

func say(text: String, seconds = 4.0):
	subtitle.text = text
	subtitle_left = seconds
	game.audio.play("speech")

# ---------------------------------------------------------------- Per frame

func _process(delta):
	if mode=="updates": refresh_updates(); return
	if mode=="main" and game.run==null:
		game.yaw += delta*.035; game._update_camera(delta)
	if mode!="field": return
	subtitle_left = maxf(0,subtitle_left-delta)
	subtitle_panel.visible = subtitle_left>0
	if game.run==null: return
	var run: ChaosMissionRun = game.run
	var distance = int(game.player.center().distance_to(game.office.goal.global_position))
	if game.escaping:
		note_mission.text = "%02d  %s" % [int(run.mission.id),run.mission.title]
		note_step.text = "퇴근하세요 · 출구로"
	else:
		note_mission.text = "%02d  %s  ·  %d/%d" % [int(run.mission.id),run.mission.title,run.index+1,run.mission.route.size()]
		note_step.text = run.mission.route[run.index].label
	note_distance.text = "목표까지 %dm" % distance
	clock.visible = run.remaining>=0 and not game.escaping
	if clock.visible:
		clock_label.text = "%02d:%02d" % [int(run.remaining)/60,int(run.remaining)%60]
		var urgent = run.remaining<8
		clock_label.add_theme_color_override("font_color",ChaosStyle.DANGER if urgent and fmod(run.remaining,.5)<.25 else ChaosStyle.AMBER)
	damage_chip.visible = run.damage>0
	if damage_chip.visible: damage_label.text = "파손  %s원" % _won(run.damage)
	update_chip.visible = game.updates!=null and not game.updates.latest.is_empty()
	if update_chip.visible: update_chip.text = "새 버전 %s · 설정에서 업데이트" % str(game.updates.latest.version)
	_update_coffee(run)
	speed_box.visible = game.player.pushing
	if game.player.pushing:
		speed_label.text = "%.1f" % game.chair.linear_velocity.length()
		boost_pill.modulate.a = 1.0 if game.chair.boosting else 0.0
	var warning = ""
	if game.player.pushing and not game.boss.seated: warning = "부장님 낙하!"
	elif game.player.pushing and game.boss.seat_risk>.25: warning = "부장님 휘청!"
	alert_time = alert_time+delta if not warning.is_empty() else 0.0
	alert.text = warning
	alert.modulate.a = .55+.45*absf(sin(alert_time*7))
	alert.add_theme_color_override("font_color",ChaosStyle.DANGER if warning=="부장님 낙하!" else ChaosStyle.AMBER)
	_update_controls()
	progress.visible = game.reset_hold>0
	progress.value = game.reset_hold

func _update_coffee(run: ChaosMissionRun):
	coffee_card.visible = not game.escaping
	if not coffee_card.visible: return
	var coffee: ChaosCoffee = game.coffee
	cup.minimum = float(run.mission.min_coffee)
	cup.show_heat = run.mission.has("min_temp")
	if not run.refilled:
		coffee_amount.text = "비어 있음"
		coffee_need.text = "탕비실에서 E로 채우기"
		coffee_heat.text = ""; coffee_state.text = ""
		return
	coffee_amount.text = "%d%%" % int(coffee.amount)
	var short = coffee.amount<float(run.mission.min_coffee)
	coffee_amount.add_theme_color_override("font_color",ChaosStyle.DANGER if short else ChaosStyle.ON_GLASS)
	coffee_need.text = "최소 %d%%" % int(run.mission.min_coffee) if float(run.mission.min_coffee)>0 else "흘리지 않게 조심"
	if cup.show_heat:
		var need = float(run.mission.min_temp)
		coffee_heat.text = "%d°C  /  최소 %d°C" % [int(coffee.temperature),int(need)]
		var margin = coffee.temperature-need
		coffee_heat.add_theme_color_override("font_color",ChaosStyle.DANGER if margin<0 else ChaosStyle.AMBER if margin<8 else ChaosStyle.OK)
	else: coffee_heat.text = ""
	var level = coffee.fullness()
	coffee_state.text = "넘친다!" if level>=1 else "출렁출렁" if level>=ChaosTuning.COFFEE_SLOSH_WARN else ""
	coffee_state.add_theme_color_override("font_color",ChaosStyle.DANGER if level>=1 else ChaosStyle.AMBER)

# Key caps are rebuilt only when the shown controls actually change.
func _update_controls():
	var controls: Array = []
	if game.player.pushing:
		controls = [[game.key_hint("forward"),game.key_hint("back"),"전후진"],[game.key_hint("left"),game.key_hint("right"),"조향"],[game.key_hint("brace"),"제동"],[game.key_hint("sprint"),"부스트"]]
	else:
		controls = [["왼손 "+_hand(0)+"   오른손 "+_hand(1)],[game.key_hint("brace"),"일어나기" if game.player.fallen else "버티기"],[game.key_hint("sprint"),"빠르게"]]
	var key = str(controls)
	if key!=controls_key:
		controls_key = key
		for child in controls_holder.get_children(): child.queue_free()
		ChaosStyle.key_row(controls_holder,controls,false,14).modulate.a = .8
	var context = game.context()
	var hints: Array = []
	if not context.is_empty(): hints.append([game.key_hint("interact"),context.text])
	elif not game.boss.seated: hints.append(["양손으로 부장님을 의자 가까이 옮겨 주세요"])
	else: hints.append(["마우스 좌/우","양손 잡기"])
	hints.append([game.key_hint("reset")+" 길게","복구"])
	hints.append(["Esc","메뉴"])
	key = str(hints)
	if key!=hints_key:
		hints_key = key
		for child in hints_holder.get_children(): child.queue_free()
		var holder = PanelContainer.new(); hints_holder.add_child(holder)
		holder.add_theme_stylebox_override("panel",ChaosStyle.margins(ChaosStyle.flat(ChaosStyle.GLASS,18),16,7))
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ChaosStyle.key_row(holder,hints,false,15)

func _hand(index: int) -> String:
	if game.player.grips[index]==null: return "○"
	return "◉" if game.player.grip_strain[index]>.75 else "●"

func _input(event):
	if rebinding.is_empty(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode!=KEY_ESCAPE:
			game.rebind(rebinding,event.physical_keycode)
		rebinding = ""; key_settings(); get_viewport().set_input_as_handled()

func notices():
	mode = "notices"
	clear("라이선스와 출처","사용한 자산·폰트·엔진의 원문 고지입니다.",720)
	var text = RichTextLabel.new(); column.add_child(text)
	text.custom_minimum_size = Vector2(620,380); text.bbcode_enabled = false
	text.text = FileAccess.get_file_as_string("res://assets/credits.txt")+"\n\n"+FileAccess.get_file_as_string("res://LICENSES.txt")+"\n\nNoto Sans KR\n"+FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")
	_space(12)
	button("돌아가기",credits)

func updates_menu():
	mode = "updates"
	clear("업데이트","현재 버전 "+game.updates.current_version+"  ·  "+("설치형" if game.updates.installed else "휴대용"),620)
	update_label = ChaosStyle.label(column,game.updates.status,17,560)
	update_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; update_label.custom_minimum_size.x = 520
	_space(8)
	update_progress = ProgressBar.new(); column.add_child(update_progress)
	update_progress.max_value = 1; update_progress.custom_minimum_size.y = 10; update_progress.show_percentage = false
	_space(10)
	update_check_button = button("업데이트 확인",func(): game.updates.check_for_updates())
	update_install_button = button("다운로드하고 설치",confirm_update,game.updates.latest.is_empty(),true)
	button("다운로드 취소",func(): game.updates.cancel_download())
	var values: Dictionary = game.store.data.settings
	_choice("시작할 때 확인","켜짐" if values.get("auto_updates",true) else "꺼짐",func(): values.auto_updates=not values.get("auto_updates",true); game.store.write(); updates_menu())
	button("돌아가기",func(): game.updates.cancel_download(); settings())
	refresh_updates()

func refresh_updates():
	if mode!="updates" or not is_instance_valid(update_label): return
	update_label.text = game.updates.status
	update_progress.visible = game.updates.state=="downloading"
	update_progress.value = game.updates.progress()
	if is_instance_valid(update_install_button): update_install_button.disabled = game.updates.latest.is_empty() or game.updates.busy()
	if is_instance_valid(update_check_button): update_check_button.disabled = game.updates.busy()

func confirm_update():
	if game.updates.latest.is_empty() or game.updates.busy(): return
	mode = "update_confirm"
	clear("새 버전을 설치할까요?","버전 "+str(game.updates.latest.version)+"을 다운로드합니다. 진행을 저장하고 게임을 종료한 뒤 설치합니다.\n"+("설치 후 게임을 다시 실행합니다. 실패하면 이전 버전으로 복구합니다." if game.updates.installed else "설치 화면에서 설치 위치를 확인할 수 있습니다. 기존 진행은 유지됩니다."),620)
	button("다운로드하고 설치",func(): game.updates.begin_install(); updates_menu(),false,true)
	button("나중에",updates_menu).grab_focus()
