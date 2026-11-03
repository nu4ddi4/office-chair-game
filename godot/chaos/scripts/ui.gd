class_name ChaosUI
extends CanvasLayer

var game
var root: Control
var hud: Control
var overlay: ColorRect
var panel: PanelContainer
var column: VBoxContainer
var objective: Label
var status: Label
var hands: Label
var hint: Label
var subtitle: Label
var subtitle_left = 0.0
var progress: ProgressBar
var rebinding = ""
var mode = "main"

func setup(owner):
	game = owner
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	root = Control.new(); add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansKR.ttf")
	theme.default_font_size = 19
	var style = StyleBoxFlat.new()
	style.bg_color = Color("203239")
	style.border_color = Color("738b87")
	style.set_border_width_all(1); style.set_corner_radius_all(5)
	style.content_margin_left = 20; style.content_margin_right = 20
	style.content_margin_top = 10; style.content_margin_bottom = 10
	theme.set_stylebox("normal","Button",style)
	var hover = style.duplicate(); hover.bg_color = Color("39535a"); hover.border_color = Color("e8bf75")
	theme.set_stylebox("hover","Button",hover); theme.set_stylebox("focus","Button",hover)
	theme.set_stylebox("pressed","Button",hover)
	root.theme = theme
	hud = Control.new(); root.add_child(hud); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective = _label(hud,"",Vector2(28,22),24)
	objective.add_theme_color_override("font_color",Color("ffe2a1"))
	status = _label(hud,"",Vector2(28,65),19)
	hands = _label(hud,"",Vector2(28,100),18)
	hint = _label(hud,"",Vector2(0,-80),20)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -88; hint.offset_bottom = -45
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle = _label(hud,"",Vector2.ZERO,24)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_top = -170; subtitle.offset_bottom = -100
	subtitle.offset_left = 100; subtitle.offset_right = -100
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var crosshair = _label(hud,"·",Vector2.ZERO,32)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -10; crosshair.offset_top = -20
	progress = ProgressBar.new(); hud.add_child(progress)
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	progress.offset_left = -100; progress.offset_right = 100; progress.offset_top = -30; progress.offset_bottom = -22
	progress.show_percentage = false; progress.max_value = 1; progress.visible = false
	overlay = ColorRect.new(); root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(.025,.055,.065,.88)
	var center = CenterContainer.new(); overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new(); center.add_child(panel)
	panel.custom_minimum_size.x = 640
	var box = StyleBoxFlat.new(); box.bg_color = Color("13242c"); box.set_corner_radius_all(10)
	box.set_content_margin_all(28); panel.add_theme_stylebox_override("panel",box)
	column = VBoxContainer.new(); panel.add_child(column)
	column.add_theme_constant_override("separation",9)

func _label(parent: Node, text: String, at: Vector2, size: int) -> Label:
	var label = Label.new(); parent.add_child(label)
	label.text = text; label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
	label.add_theme_constant_override("shadow_offset_x",1); label.add_theme_constant_override("shadow_offset_y",2)
	return label

func clear(title: String, body: String):
	for child in column.get_children():
		column.remove_child(child); child.queue_free()
	var tag = _label(column,"OFFICE CHAIR CHAOS  /  사내 운행  ·  "+str(ProjectSettings.get_setting("application/config/version")),Vector2.ZERO,14)
	tag.add_theme_color_override("font_color",Color("e8bf75"))
	var heading = _label(column,title,Vector2.ZERO,34)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var description = _label(column,body,Vector2.ZERO,18)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(580,0)
	var spacer = Control.new(); spacer.custom_minimum_size.y = 8; column.add_child(spacer)
	overlay.show(); hud.hide()
	game.clear_inputs()
	game.get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.audio.update_rolling(0)

func button(text: String, callback: Callable, disabled = false) -> Button:
	var result = Button.new(); result.text = text; result.disabled = disabled
	result.custom_minimum_size.y = 44
	column.add_child(result); result.pressed.connect(callback)
	return result

func main_menu():
	mode = "main"
	clear("김 대리,\n나 좀 밀어봐","부장님은 걷지 않습니다.\n김 대리는 제대로 걷지 못합니다.\n\n기본: WASD 이동 · 의자 뒤에서 E로 손잡이 잡기\n밀기: W/S 전후진 · A/D 조향 · Shift 부스트")
	button("계속하기",func(): game.continue_game(),game.store.data.resume.is_empty() and game.store.data.completed.is_empty())
	if not game.store.error.is_empty(): _label(column,game.store.error,Vector2.ZERO,16)
	button("새 게임",confirm_new)
	button("미션 선택",missions)
	button("설정",settings)
	button("크레딧",credits)
	button("종료",func(): game.get_tree().quit())

func confirm_new():
	if game.store.data.completed.is_empty() and game.store.data.resume.is_empty(): game.new_game(); return
	mode = "confirm"
	clear("처음부터 출근할까요?","현재 진행과 미션 기록이 초기화됩니다. 설정은 유지됩니다.")
	button("처음부터 시작",func(): game.new_game())
	button("돌아가기",main_menu).grab_focus()

func field():
	mode = "field"; rebinding = ""
	overlay.hide(); hud.show()
	game.get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func pause_menu():
	mode = "pause"
	clear("잠깐 정차","부장님도 잠시 기다립니다.")
	button("계속하기",field).grab_focus()
	button("체크포인트로 복구",func(): game.retry())
	button("설정",settings)
	button("미션 선택",missions)
	button("메인 화면",func(): game.persist_checkpoint(); main_menu())

func missions():
	mode = "missions"
	clear("오늘의 업무","완료한 업무는 다시 도전할 수 있습니다.")
	for definition in game.missions:
		var id = int(definition.id)
		var record: Dictionary = game.store.data.records.get(str(id),{})
		var text = "%02d  %s" % [id,definition.title]
		if not record.is_empty(): text += "   %d초 · %d/3" % [int(record.time),record.medals.count(true)]
		button(text,func(): game.start_mission(id),id>game.store.data.unlocked)
	button("돌아가기",func(): pause_menu() if game.run!=null and (game.run.phase=="playing" or game.escaping) else main_menu())

func settings():
	mode = "settings"
	clear("설정","키 변경은 버튼을 누른 뒤 새 키를 입력하세요. Esc로 취소합니다.")
	var values: Dictionary = game.store.data.settings
	_slider("마우스 감도",values.sensitivity,.0005,.008,.0001,func(v): values.sensitivity=v)
	_slider("시야각",values.fov,60,90,1,func(v): values.fov=v)
	_slider("음량",values.volume,0,1,.05,func(v): values.volume=v)
	_slider("자막 크기",values.subtitle_size,18,36,1,func(v): values.subtitle_size=int(v))
	button("잡기 방식: "+("누르는 동안" if values.hold_grip else "클릭으로 유지"),func(): values.hold_grip=not values.hold_grip; settings())
	button("화면 흔들림: "+("켜짐" if values.shake else "꺼짐"),func(): values.shake=not values.shake; settings())
	button("그래픽: "+["낮음","중간","높음"][int(values.quality)],func(): values.quality=(int(values.quality)+1)%3; settings())
	button("키 변경",key_settings)
	button("저장하고 돌아가기",func(): game.apply_settings(); game.store.write(); pause_menu() if game.run!=null and (game.run.phase=="playing" or game.escaping) else main_menu())

func _slider(title: String, value: float, minimum: float, maximum: float, step: float, changed: Callable):
	var row = HBoxContainer.new(); column.add_child(row)
	var name_label = _label(row,title,Vector2.ZERO,17); name_label.custom_minimum_size.x = 155
	var slider = HSlider.new(); row.add_child(slider)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum; slider.max_value = maximum; slider.step = step; slider.value = value
	slider.value_changed.connect(changed)

func key_settings():
	mode = "keys"
	clear("키 변경","변경할 항목을 선택하세요. 마우스 양손 잡기는 고정입니다.")
	var names = {"forward":"앞으로","back":"뒤로","left":"왼쪽","right":"오른쪽","sprint":"달리기 / 부스트","brace":"버티기 / 일어나기","interact":"상황별 행동","reset":"체크포인트 복구"}
	for key in names:
		button(names[key]+"  ·  "+OS.get_keycode_string(game.keycode(key)),func(): rebinding=key; say("사용할 키를 눌러 주세요. Esc로 취소",30))
	button("돌아가기",func(): game.apply_settings(); settings())

func credits():
	mode = "credits"
	clear("함께 만든 사무실","사무실 자산: 기존 프로젝트의 Interior 07을 재배치·확장했습니다.\nOffice Chair — CMHT Oculus / Poly Pizza / CC BY 3.0\n재질·소품 — Poly Haven / CC0\n한국어 폰트 — Noto Sans KR / SIL OFL\n엔진 — Godot / MIT\n전체 출처는 배포 폴더의 CREDITS.txt와 LICENSES.txt에 있습니다.")
	button("돌아가기",main_menu)

func result(success: bool):
	mode = "result"
	var run: ChaosMissionRun = game.run
	if success:
		var medals = run.medals()
		var summary = "운행 시간 %d초  ·  낙하 %d회  ·  복구 %d회\n파손액 %s원  ·  남은 커피 %d%%\n\n%s 정시 운행   %s 무사 운행   %s 알뜰 운행" % [int(run.elapsed),run.falls,run.retries,str(run.damage),int(game.coffee.amount),"●" if medals[0] else "○","●" if medals[1] else "○","●" if medals[2] else "○"]
		clear("정상 퇴근" if int(run.mission.id)==6 else "업무 완료",summary)
		if int(run.mission.id)<6: button("다음 업무",func(): game.start_mission(int(run.mission.id)+1)).grab_focus()
	else:
		clear("잠깐만, 김 대리",run.reason+"\n\n가까운 체크포인트에서 바로 다시 시작합니다.")
		button("재도전",func(): game.retry()).grab_focus()
	button("미션 다시 시작",func(): game.start_mission(int(run.mission.id)))
	button("미션 선택",missions)
	button("메인 화면",main_menu)

func say(text: String, seconds = 4.0):
	subtitle.text = "부장님  ·  "+text
	subtitle_left = seconds
	game.audio.play("speech")

func _process(delta):
	if mode!="field": return
	subtitle_left = maxf(0,subtitle_left-delta)
	subtitle.visible = subtitle_left>0
	if game.run==null: return
	var run: ChaosMissionRun = game.run
	objective.text = "퇴근하세요 · 출구로 이동" if game.escaping else "%02d  %s  /  %s" % [int(run.mission.id),run.mission.title,run.mission.route[run.index].label]
	var text = "거리 %dm" % int(game.player.center().distance_to(game.office.goal.global_position))
	if not game.escaping:
		text += "   커피 %d%%" % int(game.coffee.amount)
		if run.mission.min_coffee>0: text += " / 최소 %d%%" % int(run.mission.min_coffee)
		if run.remaining>=0: text += "   남은 시간 %02d:%02d" % [int(run.remaining)/60,int(run.remaining)%60]
		if not run.refilled: text += "   먼저 커피를 채워 주세요"
	status.text = text
	if game.player.pushing:
		status.text += "   %.1f m/s" % game.chair.linear_velocity.length()
		var mode_text = "부스트" if game.chair.boosting else "양손 밀기"
		hands.text = "%s · %s/%s 전후진 · %s/%s 조향 · %s 제동 · %s 부스트" % [mode_text,game.key_hint("forward"),game.key_hint("back"),game.key_hint("left"),game.key_hint("right"),game.key_hint("brace"),game.key_hint("sprint")]
		if not game.boss.seated: hands.text += "   부장님 낙하!"
		elif game.boss.seat_risk>.25: hands.text += "   부장님 휘청!"
	else:
		hands.text = "왼손 %s    오른손 %s    %s" % [_hand(0),_hand(1),"넘어짐 · Space로 일어나기" if game.player.fallen else "Space 버티기 / Shift 빠르게"]
	hint.text = game.context_text()+"    |    "+game.key_hint("reset")+" 길게: 복구  ·  Esc: 메뉴"
	progress.visible = game.reset_hold>0
	progress.value = game.reset_hold

func _hand(index: int) -> String:
	if game.player.grips[index]==null: return "○"
	return "● 당겨짐" if game.player.grip_strain[index]>.75 else "● 잡는 중"

func _input(event):
	if rebinding.is_empty(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode!=KEY_ESCAPE:
			game.rebind(rebinding,event.physical_keycode)
		rebinding = ""; key_settings(); get_viewport().set_input_as_handled()
