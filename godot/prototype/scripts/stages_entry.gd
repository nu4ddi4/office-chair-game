class_name TerminalStageEntry
extends InvestigationEntryScreen

func build(owner: InvestigationUI):
	super.build(owner)
	introduction.get_child(introduction.get_child_count()-1).hide()

func show_menu(paused: bool):
	super.show_menu(paused)
	title.text = "일시정지" if paused else "퇴근.exe"
	description.text = "STAGE %02d · %s" % [ui.game.state.stage.index,ui.game.content.stages[int(ui.game.state.stage.index)-1].title] if paused else "퇴근 신청서, 한 장만."
	if not paused and ui.game.legacy_progress: description.text += "\n새 게임을 시작하면 이전 진행을 보관합니다."
	new_game.text = "처음부터" if ui.game.session_available else "시작하기"
	tablet.text = "스테이지 선택"
	tablet.visible = true
	tablet.disabled = not ui.game.session_available

func show_intro():
	super.show_intro()
	title.text = "퇴근.exe"
	description.text = "오늘의 업무 · 출력실"

func refresh_intro():
	intro_progress.text = "첫 출근 / 출력실"
	intro_title.text = "한 장이면 됩니다"
	intro_body.text = "첫 출근. 퇴근 신청서를 한 장 출력해 달라는 부탁을 받았습니다.\n출력실의 서유진이 기다리고 있습니다.\n\nWASD 이동 · 마우스 시점 · F 상호작용 · Space 점프\n터미널에서는 help로 명령을 확인하세요."
	intro_previous.text = "메인 화면"
	intro_next.text = "출근하기"

func previous_intro(): show_menu(false)
func next_intro(): finish_intro()
func finish_intro():
	intro_seen = true
	ui.call("begin_stage")
