extends CanvasLayer

const INK = Color("#213532")
const PAPER = Color("#f1e9d7")
const ACCENT = Color("#22665d")
const MUTED = Color("#4c6159")
const DARK_GLASS = Color(0.084, 0.151, 0.14, 0.93)
const LIGHT_TEXT = Color("#faf4df")

var session: Node3D
var camera: Camera3D
var camera_anchor = Vector3.ZERO
var root: Control
var overlay: Control
var sheet: PanelContainer
var form: VBoxContainer
var hud: Control
var stage_label: Label
var clock_label: Label
var objective: Label
var current_help: Label
var feedback: Label
var address = "127.0.0.1"
var port = "30820"
var room = ""
var screen = ""

func configure(owner_node: Node3D) -> void:
	session = owner_node
	camera = Camera3D.new()
	camera.near = 0.012
	camera.far = 30
	camera.fov = 74
	session.add_child(camera)
	camera.position = Vector3(-1.25, 1.72, 1.65)
	camera.look_at(Vector3(0, 0.80, 0))
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	_build_hud()
	overlay = Control.new()
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.09, 0.15, 0.14, 0.26)
	overlay.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet = PanelContainer.new()
	overlay.add_child(sheet)
	sheet.offset_left = 76
	sheet.offset_top = 73
	sheet.offset_right = 520
	sheet.add_theme_stylebox_override("panel", _box(PAPER, 21))
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 11)
	sheet.add_child(form)
	show_connect("")

func _theme() -> Theme:
	var result = Theme.new()
	result.default_font_size = 16
	if ResourceLoader.exists("res://generated/NotoSansKR.ttf"):
		result.default_font = load("res://generated/NotoSansKR.ttf")
	var fallback = SystemFont.new()
	fallback.font_names = PackedStringArray(["Noto Sans CJK KR", "Malgun Gothic", "Noto Sans KR", "sans-serif"])
	if result.default_font == null:
		result.default_font = fallback
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", LIGHT_TEXT)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_pressed_color", "Button", LIGHT_TEXT)
	result.set_stylebox("normal", "Button", _box(ACCENT, 11, 8))
	result.set_stylebox("hover", "Button", _box(ACCENT.lightened(0.12), 11, 8))
	result.set_stylebox("pressed", "Button", _box(ACCENT.darkened(0.18), 11, 8))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("caret_color", "LineEdit", ACCENT)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_stylebox("normal", "LineEdit", _box(Color("#e4dfcc"), 9, 7))
	return result

func _box(color: Color, pad: float, radius: int = 12) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad * 0.68
	style.content_margin_bottom = pad * 0.68
	return style

func _label(parent: Control, value: String, size: int, color: Color = INK) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _field(parent: Control, caption: String, value: String, limit: int, masked: bool = false) -> LineEdit:
	var stack = VBoxContainer.new()
	parent.add_child(stack)
	_label(stack, caption, 14, MUTED)
	var edit = LineEdit.new()
	edit.text = value
	edit.max_length = limit
	edit.secret = masked
	edit.custom_minimum_size.y = 38
	stack.add_child(edit)
	return edit

func _clear_form() -> void:
	for child in form.get_children():
		form.remove_child(child)
		child.queue_free()
	overlay.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_connect(message: String) -> void:
	screen = "connect"
	_clear_form()
	hud.hide()
	_label(form, "SMALL BUSINESS", 39)
	_label(form, "작은 직원들의 세 판짜리 근무조입니다.", 17, MUTED)
	var row = HBoxContainer.new()
	form.add_child(row)
	var host_input = _field(row, "서버 주소", address, 253)
	host_input.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var port_input = _field(row, "UDP 포트", port, 5)
	port_input.custom_minimum_size.x = 88
	var key_input = _field(form, "방 키", room, 64, true)
	if not message.is_empty():
		_label(form, message, 14, Color("#a94d30")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var join = func():
		address = host_input.text.strip_edges()
		port = port_input.text.strip_edges()
		room = key_input.text
		session.connect_room(address, int(port) if port.is_valid_int() else 0, room)
	_button(form, "방 입장", join)
	key_input.text_submitted.connect(func(_value): join.call())
	host_input.grab_focus()

func show_wait(message: String) -> void:
	screen = "wait"
	_clear_form()
	hud.hide()
	_label(form, "서버에 연결 중", 33)
	_label(form, message, 16, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(form, "연결 취소", session.leave_room)

func show_lobby(participants: int, late: bool) -> void:
	screen = "waiting_round" if late else "lobby"
	_clear_form()
	hud.hide()
	_label(form, "근무 대기실", 36)
	_label(form, "참가자 %d/2" % participants, 17, MUTED)
	if late:
		_label(form, "현재 진행 중인 판이 끝나면 합류합니다.", 16, MUTED)
	else:
		_label(form, "혼자 시작하거나 동료를 기다릴 수 있습니다.", 16, MUTED)
		_button(form, "근무 시작", func(): session.request_shift.rpc_id(1, session.round_id))
	_button(form, "방 나가기", session.leave_room)

func show_result(number: int, final: bool, seconds: int, total: int) -> void:
	screen = "shift_result" if final else "round_result"
	_clear_form()
	hud.hide()
	_label(form, "퇴근" if final else "근무 %d/3 완료" % number, 39)
	_label(form, "완료한 업무 %d개 · 근무 시간 %s" % [total, _time(seconds)], 17, MUTED)
	if final:
		_button(form, "새 근무조 시작", func(): session.request_shift.rpc_id(1, session.round_id))
	else:
		_label(form, "잠시 후 다음 판을 시작합니다.", 16, MUTED)
	_button(form, "방 나가기", session.leave_room)

func show_play() -> void:
	screen = "play"
	overlay.hide()
	hud.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_pause(pause: bool) -> void:
	if not pause:
		show_play()
		return
	screen = "pause"
	_clear_form()
	_label(form, "조작 일시 중지", 33)
	_label(form, "근무는 계속 진행됩니다.", 16, MUTED)
	_button(form, "돌아가기", func(): session.suppress_input = false; show_play())
	_button(form, "방 나가기", session.leave_room)

func _build_hud() -> void:
	hud = Control.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card = PanelContainer.new()
	hud.add_child(card)
	card.position = Vector2(28, 25)
	card.custom_minimum_size.x = 352
	card.add_theme_stylebox_override("panel", _box(DARK_GLASS, 17))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content = VBoxContainer.new()
	card.add_child(content)
	var row = HBoxContainer.new()
	content.add_child(row)
	stage_label = _label(row, "", 14, Color("#99dbca"))
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_label = _label(row, "", 14, LIGHT_TEXT)
	objective = _label(content, "", 23, LIGHT_TEXT)
	var bottom = PanelContainer.new()
	hud.add_child(bottom)
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 28
	bottom.offset_top = -108
	bottom.offset_bottom = -25
	bottom.custom_minimum_size.x = 490
	bottom.add_theme_stylebox_override("panel", _box(DARK_GLASS, 16))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hints = VBoxContainer.new()
	bottom.add_child(hints)
	current_help = _label(hints, "", 18, LIGHT_TEXT)
	feedback = _label(hints, "", 13, Color("#abd9cb"))

func _time(seconds: int) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]

func update_round(number: int, complete: Array, holding: int, seconds: int, first_person: bool) -> void:
	stage_label.text = "근무 %d/3" % number
	clock_label.text = _time(seconds)
	objective.text = "%s  USB 연결\n%s  서류 운반" % ["완료" if complete[0] else "□", "완료" if complete[1] else "□"]
	if holding >= 0:
		current_help.text = ("USB" if holding == 0 else "서류") + " · E 놓기 / 왼쪽 클릭 던지기"
	else:
		current_help.text = "E 가까운 물건 잡기 · 같은 색 표식으로 운반"
	feedback.text = "WASD 이동    Space 점프    V %s 전환    Esc 메뉴" % ("3인칭" if first_person else "1인칭")

func reset_camera(at: Vector3) -> void:
	camera_anchor = at + Vector3.UP * 0.108

func follow(at: Vector3, yaw: float, pitch: float, first_person: bool, delta: float) -> void:
	var head = at + Vector3(0, 0.105, 0)
	camera_anchor = head if camera_anchor.distance_to(head) > 0.34 else camera_anchor.lerp(head, 1.0 - exp(-delta * 25))
	var orientation = Basis.from_euler(Vector3(pitch, yaw, 0), EULER_ORDER_YXZ)
	var proposed = camera_anchor if first_person else camera_anchor + orientation * Vector3(0.115, 0.088, 0.425)
	if not first_person:
		var query = PhysicsRayQueryParameters3D.create(head, proposed, 1)
		var obstruction = session.get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty():
			proposed = obstruction.position.move_toward(head, 0.03)
	camera.global_transform = Transform3D(orientation, proposed)
