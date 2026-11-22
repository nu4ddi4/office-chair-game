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
var danger: ProgressBar
var address = "127.0.0.1"
var port = "30820"
var room = ""
var screen = ""
var footstep: AudioStreamPlayer3D
var last_step = Vector3.ZERO

func configure(owner_node: Node3D) -> void:
	session = owner_node
	camera = Camera3D.new()
	camera.near = 0.012
	camera.far = 30
	camera.fov = 74
	session.add_child(camera)
	camera.position = Vector3(-6.6, 1.12, 2.82)
	camera.look_at(Vector3(-1.6, 0.52, 0.15))
	footstep = AudioStreamPlayer3D.new()
	footstep.stream = _step_sound()
	footstep.unit_size = 1.3
	footstep.max_distance = 6.5
	footstep.max_polyphony = 3
	session.add_child(footstep)
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
	_label(form, "책상 아래", 50)
	_label(form, "두 사람이 함께 사무실을 빠져나오세요.", 17, MUTED)
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
	_button(form, "친구 방 입장", join)
	key_input.text_submitted.connect(func(_value): join.call())
	host_input.grab_focus()

func show_wait(message: String) -> void:
	screen = "wait"
	_clear_form()
	hud.hide()
	_label(form, "친구를 기다리는 중", 33)
	_label(form, message, 16, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(form, "연결 취소", session.leave_room)

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
	_label(form, "친구와 직원은 계속 움직입니다.", 16, MUTED)
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
	danger = ProgressBar.new()
	hints.add_child(danger)
	danger.max_value = 1
	danger.show_percentage = false
	danger.custom_minimum_size.y = 5
	danger.add_theme_stylebox_override("background", _box(Color("#584337"), 0, 3))
	danger.add_theme_stylebox_override("fill", _box(Color("#ffc284"), 0, 3))
	danger.hide()

func update_round(shared: Array, slot: int, target: int, first_person: bool) -> void:
	var section: int = shared[0]
	var seconds: int = int(shared[1])
	var time = "%02d:%02d" % [seconds / 60, seconds % 60]
	stage_label.text = ["바닥 · 1/3", "책상 위 · 2/3", "탈출구 · 3/3"][section]
	clock_label.text = time
	objective.text = ["둘이 첫 책상에 올라가기", "바인더를 놓고 함께 건너기", "둘이 배선 구멍까지 가기"][section]
	var help = [
		"E 길게 · 서랍 열어 두기", "E 길게 · 서랍에 클립 끼우기",
		"E 길게 · 바인더 한쪽 잡기", "E 길게 · 바인더 반대쪽 잡기",
		"E 길게 · 케이블 타고 내려가기", "E 길게 · 케이블 타고 올라가기",
		"", "E 길게 · 컵 들어 올리기",
	]
	var action: int = shared[8][slot]
	current_help.text = help[action] if action >= 0 else ["노란 표식에서 친구와 역할을 나누세요.", "친구와 서로 다른 바인더 손잡이를 잡으세요.", "노란 케이블을 타고 내려가세요."][section]
	feedback.text = "WASD 이동    Space 점프    V %s 전환    Esc 메뉴" % ("3인칭" if first_person else "1인칭")
	danger.visible = false
	if shared[2][slot] == 1:
		current_help.text = "컵에 갇혔습니다. 친구가 구해 줄 수 있습니다."
		if shared[10] > 0:
			current_help.text = "둘 다 잡혔습니다. 직전 구간을 다시 시작합니다."
	elif shared[2][1 - slot] == 1 and action != 7:
		current_help.text = "친구가 잡혔습니다. 투명 컵으로 가세요."
	elif target == slot:
		current_help.text = "직원이 보고 있습니다. 가구 뒤로 숨으세요!"
		danger.visible = true
		danger.value = shared[14] / 1.4
	if shared[9] > 0:
		danger.visible = true
		danger.value = shared[9] / 1.5
	if shared[7] and screen != "finished":
		screen = "finished"
		_clear_form()
		hud.hide()
		_label(form, "둘 다 탈출했습니다", 36)
		_label(form, "걸린 시간  " + time, 18, MUTED)
		_button(form, "같이 다시 하기", func(): session.play_again.rpc_id(1, session.round_id))
		_button(form, "방 나가기", session.leave_room)

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

func employee_audio(at: Vector3) -> void:
	if last_step.distance_to(at) < 0.43:
		return
	if last_step.distance_to(at) < 1.4:
		footstep.position = at
		footstep.play()
	last_step = at

func _step_sound() -> AudioStreamWAV:
	var sample_rate = 16000
	var count = 2560
	var wave = PackedByteArray()
	wave.resize(count * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 664
	for i in range(count):
		var t = float(i) / sample_rate
		var envelope = sin(minf(t / 0.015, 1.0) * PI / 2.0) * exp(-t * 31.0)
		var body = sin(TAU * (52 * t - 42 * t * t)) * 0.56 + rng.randf_range(-0.16, 0.16)
		wave.encode_s16(i * 2, int(body * envelope * 27000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = wave
	return stream
