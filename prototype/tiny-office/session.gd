extends Node3D

const Office = preload("res://office.gd")
const Runner = preload("res://runner.gd")
const Run = preload("res://run.gd")
const View = preload("res://view.gd")
const PROTOCOL = "tiny-office-2"
const DEFAULT_PORT = 30820
const INPUT_CHANNEL = 1
const STATE_CHANNEL = 2
const MAX_BUFFER = 48
const SHIFT_ROUNDS = 3
const INTERMISSION_SECONDS = 5.0

enum Phase { LOBBY, PLAYING, ROUND_RESULT, SHIFT_RESULT }

var server_mode = false
var office: Node3D
var view: CanvasLayer
var run
var runners: Array = []
var peer_ids: Array[int] = []
var seats := [0, 0]
var phase := Phase.LOBBY
var shift_round := 0
var shift_elapsed := 0.0
var completed_tasks := 0
var intermission := 0.0
var room_key = ""
var auth_nonces: Dictionary = {}
var crypto = Crypto.new()
var longest_step_usec = 0
var slot = -1
var round_id = 0
var current_round = false
var server_frame = 0
var incoming: Array = [{}, {}]
var input_age = [0.0, 0.0]
var received: Array = []
var latest_state: Array = []
var history: Array = []
var seq = 0
var jump_count = 0
var camera_yaw = -PI / 2.0
var camera_pitch = -0.12
var first_person = false
var remote_position = Vector3.ZERO
var remote_direction = Vector2.ZERO
var remote_visible := false
var suppress_input = false

func _ready() -> void:
	server_mode = OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_user_args()
	office = Office.new()
	add_child(office)
	office.build(not server_mode)
	multiplayer.peer_connected.connect(_peer_joined)
	multiplayer.peer_disconnected.connect(_peer_left)
	if server_mode:
		Engine.max_fps = 60
		_open_server()
		return
	_install_controls()
	view = View.new()
	add_child(view)
	view.configure(self)
	multiplayer.connected_to_server.connect(func():
		if not current_round:
			view.show_wait("방 정보를 받는 중입니다.")
	)
	multiplayer.connection_failed.connect(_connection_lost.bind("서버에 접속하지 못했습니다. 주소와 방 키를 확인해 주세요."))
	multiplayer.server_disconnected.connect(_connection_lost.bind("서버 연결이 끝났습니다."))

func _install_controls() -> void:
	var keys = {&"forward": KEY_W, &"back": KEY_S, &"left": KEY_A, &"right": KEY_D, &"jump": KEY_SPACE, &"grip": KEY_E, &"camera": KEY_V}
	for key in keys:
		InputMap.add_action(key)
		var event = InputEventKey.new()
		event.physical_keycode = keys[key]
		InputMap.action_add_event(key, event)

func _open_server() -> void:
	var args = OS.get_cmdline_user_args()
	var path = "server.cfg"
	var flag = args.find("--config")
	if flag >= 0:
		if flag + 1 == args.size():
			_boot_error("--config needs a filesystem path")
			return
		path = args[flag + 1]
	var config = ConfigFile.new()
	if config.load(path) != OK:
		_boot_error("Cannot read " + path + ". Copy server.example.cfg and set a room key.")
		return
	room_key = str(config.get_value("server", "room_key", ""))
	var port = int(config.get_value("server", "port", DEFAULT_PORT))
	var bind_address = str(config.get_value("server", "bind_address", "*"))
	if not valid_key(room_key) or port < 1 or port > 65535:
		_boot_error("Set a room key of 16–64 ASCII letters, digits, hyphens or underscores and a valid UDP port.")
		return
	multiplayer.auth_callback = _authorize_client
	multiplayer.auth_timeout = 5.0
	multiplayer.server_relay = false
	var endpoint = ENetMultiplayerPeer.new()
	endpoint.set_bind_ip(bind_address)
	var err = endpoint.create_server(port, 2, 3)
	if err != OK:
		_boot_error("Could not open UDP port %d: %s" % [port, error_string(err)])
		return
	multiplayer.multiplayer_peer = endpoint
	print("TINY_OFFICE_READY protocol=%s bind=%s udp=%d player_limit=2 physics_hz=%d" % [PROTOCOL, bind_address, port, Engine.physics_ticks_per_second])

func _boot_error(message: String) -> void:
	printerr("TINY_OFFICE_SERVER: " + message)
	get_tree().quit(1)

func valid_key(value: String) -> bool:
	if value.length() < 16 or value.length() > 64:
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_":
			return false
	return true

func connect_room(address: String, port: int, key: String) -> void:
	if address.is_empty() or port < 1 or port > 65535 or not valid_key(key):
		view.show_connect("서버 주소·포트와 16~64자 방 키를 확인해 주세요.")
		return
	_close_connection()
	room_key = key
	multiplayer.auth_callback = _authorize_server
	multiplayer.auth_timeout = 5.0
	var endpoint = ENetMultiplayerPeer.new()
	var err = endpoint.create_client(address, port, 3)
	if err != OK:
		view.show_connect("연결을 시작할 수 없습니다. " + error_string(err))
		return
	multiplayer.multiplayer_peer = endpoint
	view.show_wait("서버에 연결하는 중입니다.")

func _authorize_client(id: int, data: PackedByteArray) -> void:
	var nonce: PackedByteArray = auth_nonces.get(id, PackedByteArray())
	auth_nonces.erase(id)
	if nonce.is_empty() or data.size() != 32 or not crypto.constant_time_compare(_room_proof(nonce), data):
		multiplayer.disconnect_peer(id)
		return
	multiplayer.send_auth(id, PROTOCOL.to_ascii_buffer())
	multiplayer.complete_auth(id)

func _authorize_server(id: int, data: PackedByteArray) -> void:
	if id != 1:
		return
	if data.size() == 32:
		multiplayer.send_auth(id, _room_proof(data))
	elif data == PROTOCOL.to_ascii_buffer():
		multiplayer.complete_auth(id)
	else:
		_connection_lost.call_deferred("서버와 게임 빌드가 다릅니다.")

func _room_proof(nonce: PackedByteArray) -> PackedByteArray:
	return crypto.hmac_digest(HashingContext.HASH_SHA256, room_key.to_ascii_buffer(), PROTOCOL.to_ascii_buffer() + nonce)

func _enter_tree() -> void:
	multiplayer.peer_authenticating.connect(_authenticating)
	multiplayer.peer_authentication_failed.connect(_auth_failed)

func _authenticating(id: int) -> void:
	if server_mode:
		var nonce = crypto.generate_random_bytes(32)
		auth_nonces[id] = nonce
		multiplayer.send_auth(id, nonce)

func _auth_failed(id: int) -> void:
	auth_nonces.erase(id)
	if not server_mode:
		_connection_lost.call_deferred("접속을 승인받지 못했습니다. 방 키와 게임 빌드를 확인해 주세요.")

func _peer_joined(id: int) -> void:
	if not server_mode:
		return
	peer_ids.append(id)
	print("TINY_OFFICE_JOIN players=%d" % peer_ids.size())
	_send_room_status()

func _peer_left(id: int) -> void:
	if not server_mode:
		return
	peer_ids.erase(id)
	var seat := seats.find(id)
	if seat >= 0:
		run.release_player(seat)
		seats[seat] = 0
	print("TINY_OFFICE_LEAVE players=%d" % peer_ids.size())
	if peer_ids.is_empty() or (phase == Phase.PLAYING and seats == [0, 0]):
		phase = Phase.LOBBY
		_clear_runners()
		run = null
		seats = [0, 0]
	_send_room_status()

func _send_room_status() -> void:
	for id in peer_ids:
		if phase == Phase.LOBBY:
			room_status.rpc_id(id, round_id, peer_ids.size(), false)
		elif phase == Phase.SHIFT_RESULT:
			show_result.rpc_id(id, round_id, shift_round, true, int(shift_elapsed), completed_tasks)
		elif id not in seats:
			if phase == Phase.ROUND_RESULT:
				show_result.rpc_id(id, round_id, shift_round, false, int(shift_elapsed), completed_tasks)
			else:
				room_status.rpc_id(id, round_id, peer_ids.size(), true)

func leave_room() -> void:
	_connection_lost("연결을 종료했습니다.")

func _close_connection() -> void:
	var connection = multiplayer.multiplayer_peer
	if connection != null:
		connection.close()
		multiplayer.multiplayer_peer = null

func _connection_lost(message: String) -> void:
	_close_connection()
	room_key = ""
	current_round = false
	suppress_input = false
	_clear_runners()
	view.show_connect(message)

@rpc("any_peer", "call_remote", "reliable")
func request_shift(generation: int) -> void:
	if not server_mode or generation != round_id or phase not in [Phase.LOBBY, Phase.SHIFT_RESULT]:
		return
	if multiplayer.get_remote_sender_id() not in peer_ids:
		return
	shift_round = 0
	shift_elapsed = 0.0
	completed_tasks = 0
	_start_server_round()

func _start_server_round() -> void:
	shift_round += 1
	round_id += 1
	server_frame = 0
	longest_step_usec = 0
	phase = Phase.PLAYING
	seats = [0, 0]
	incoming = [{}, {}]
	input_age = [0.0, 0.0]
	for i in range(peer_ids.size()):
		seats[i] = peer_ids[i]
	_spawn_runners(false)
	run = Run.new()
	run.office = office
	run.players = runners
	run.reset(shift_round)
	for i in range(peer_ids.size()):
		begin_round.rpc_id(seats[i], round_id, shift_round, i, peer_ids.size())

func _spawn_runners(graphics: bool) -> void:
	_clear_runners()
	for i in range(2):
		var runner = Runner.new()
		add_child(runner)
		runner.configure(i, graphics)
		runner.position = _spawn_point(i)
		runners.append(runner)

func _spawn_point(seat: int) -> Vector3:
	return Office.START + Vector3(-0.08 + seat * 0.16, 0, 0)

func _clear_runners() -> void:
	for runner in runners:
		remove_child(runner)
		runner.queue_free()
	runners.clear()
	received.clear()
	latest_state.clear()
	history.clear()

@rpc("authority", "call_remote", "reliable")
func room_status(generation: int, participants: int, late: bool) -> void:
	round_id = generation
	current_round = false
	_clear_runners()
	view.show_lobby(participants, late)

@rpc("authority", "call_remote", "reliable")
func begin_round(id: int, number: int, assignment: int, participants: int) -> void:
	round_id = id
	shift_round = number
	slot = assignment
	seq = 0
	jump_count = 0
	suppress_input = false
	camera_yaw = 0.0
	camera_pitch = -0.18
	_spawn_runners(true)
	for i in range(office.props.size()):
		office.props[i].transform = Transform3D(Basis.IDENTITY, Office.SPAWNS[(number - 1) % Office.SPAWNS.size()][i])
	remote_position = runners[1 - slot].position
	remote_direction = Vector2.ZERO
	remote_visible = participants == 2
	current_round = true
	view.show_play()
	view.update_round(shift_round, [false, false], -1, 0, first_person)
	view.reset_camera(runners[slot].position)

@rpc("authority", "call_remote", "reliable")
func show_result(id: int, number: int, final: bool, seconds: int, total: int) -> void:
	round_id = id
	current_round = false
	_clear_runners()
	view.show_result(number, final, seconds, total)

@rpc("any_peer", "call_remote", "reliable")
func interact(id: int, throwing: bool, aim: Vector3) -> void:
	if not server_mode or phase != Phase.PLAYING or id != round_id or not aim.is_finite():
		return
	var seat := seats.find(multiplayer.get_remote_sender_id())
	if seat >= 0:
		run.interact(seat, throwing, aim.limit_length())

@rpc("any_peer", "call_remote", "unreliable_ordered", INPUT_CHANNEL)
func inputs(id: int, commands: Array) -> void:
	if not server_mode or phase != Phase.PLAYING or id != round_id or commands.size() > 4:
		return
	var who := seats.find(multiplayer.get_remote_sender_id())
	if who < 0:
		return
	var ack: int = runners[who].step_id
	for command in commands:
		if typeof(command) != TYPE_ARRAY or command.size() != 3:
			continue
		if typeof(command[0]) != TYPE_INT or typeof(command[1]) != TYPE_VECTOR2 or typeof(command[2]) != TYPE_INT:
			continue
		if command[0] <= ack or command[0] > ack + 180 or not command[1].is_finite():
			continue
		if command[2] < 0 or command[2] > command[0] or incoming[who].size() >= MAX_BUFFER:
			continue
		incoming[who][command[0]] = [command[0], command[1].limit_length(), command[2]]

@rpc("authority", "call_remote", "unreliable_ordered", STATE_CHANNEL)
func state(id: int, bodies: Array, shared: Array) -> void:
	if current_round and id == round_id:
		received = [bodies, shared]

func _physics_process(delta: float) -> void:
	if server_mode:
		if phase == Phase.PLAYING:
			_server_step(delta)
		elif phase == Phase.ROUND_RESULT:
			intermission -= delta
			if intermission <= 0.0:
				_start_server_round()
	elif current_round:
		_client_step(delta)

func _server_step(delta: float) -> void:
	var started_usec = Time.get_ticks_usec()
	shift_elapsed += delta
	for i in range(seats.size()):
		if seats[i] == 0:
			continue
		var actor = runners[i]
		var jump_now := false
		var queued: Dictionary = incoming[i]
		if not queued.is_empty():
			var sequence: int = queued.keys().min()
			var command: Array = queued[sequence]
			queued.erase(sequence)
			actor.step_id = sequence
			actor.direction = command[1]
			jump_now = command[2] > actor.jumps
			actor.jumps = maxi(actor.jumps, command[2])
			input_age[i] = 0.0
		else:
			input_age[i] += delta
			if input_age[i] > 0.15:
				actor.direction = Vector2.ZERO
		actor.move_input(actor.direction, jump_now, delta, run.holders.has(i))
		if actor.position.y < Run.DROP_HEIGHT:
			run.release_player(i)
			actor.position = _spawn_point(i)
			actor.velocity = Vector3.ZERO
			actor.grounded = false
	run.tick(delta)
	if not run.complete.has(false):
		_finish_round()
		return
	server_frame += 1
	if server_frame % 3 == 0:
		var bodies := []
		for actor in runners:
			bodies.append([actor.position, actor.velocity, actor.direction, actor.grounded, actor.step_id, actor.jumps])
		var shared: Array = run.snapshot()
		shared.append(seats.map(func(id): return id != 0))
		shared.append(int(shift_elapsed))
		for id in seats:
			if id != 0:
				state.rpc_id(id, round_id, bodies, shared)
	longest_step_usec = maxi(longest_step_usec, Time.get_ticks_usec() - started_usec)
	if server_frame % 600 == 0:
		print("TINY_OFFICE_TICK max_ms=%.2f budget_ms=16.67" % (longest_step_usec / 1000.0))
		longest_step_usec = 0

func _finish_round() -> void:
	completed_tasks += run.complete.size()
	var final := shift_round == SHIFT_ROUNDS
	phase = Phase.SHIFT_RESULT if final else Phase.ROUND_RESULT
	intermission = INTERMISSION_SECONDS
	print("TINY_OFFICE_ROUND round=%d total_tasks=%d" % [shift_round, completed_tasks])
	for id in peer_ids:
		show_result.rpc_id(id, round_id, shift_round, final, int(shift_elapsed), completed_tasks)

func _client_step(delta: float) -> void:
	if not received.is_empty():
		_apply_state(delta)
	seq += 1
	var axis := Vector2.ZERO
	if not suppress_input and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var raw := Input.get_vector("left", "right", "forward", "back")
		var move := Basis(Vector3.UP, camera_yaw) * Vector3(raw.x, 0, raw.y)
		axis = Vector2(move.x, move.z)
		if Input.is_action_just_pressed("camera"):
			first_person = not first_person
		if Input.is_action_just_pressed("jump"):
			jump_count += 1
	var actor = runners[slot]
	actor.move_input(axis, jump_count > actor.jumps, delta, _held_prop() >= 0)
	actor.jumps = jump_count
	actor.direction = axis
	history.append([seq, axis, jump_count])
	if history.size() > MAX_BUFFER:
		history.pop_front()
	inputs.rpc_id(1, round_id, history.slice(maxi(0, history.size() - 4)))

func _apply_state(delta: float) -> void:
	var bodies: Array = received[0]
	latest_state = received[1]
	received.clear()
	var own: Array = bodies[slot]
	var remote: Array = bodies[1 - slot]
	remote_position = remote[0]
	remote_direction = remote[2]
	remote_visible = latest_state[3][1 - slot]
	while not history.is_empty() and history[0][0] <= own[4]:
		history.pop_front()
	var actor = runners[slot]
	actor.position = own[0]
	actor.velocity = own[1]
	actor.grounded = own[3]
	actor.jumps = own[5]
	for command in history:
		actor.move_input(command[1], command[2] > actor.jumps, delta, _held_prop() >= 0)
		actor.jumps = command[2]

func _held_prop() -> int:
	return -1 if latest_state.is_empty() else latest_state[2].find(slot)

func _process(delta: float) -> void:
	if server_mode or not current_round:
		return
	var actor = runners[slot]
	var remote = runners[1 - slot]
	if remote.position.distance_to(remote_position) > 0.48:
		remote.position = remote_position
	else:
		remote.position = remote.position.lerp(remote_position, 1.0 - exp(-delta * 19.0))
	actor.animate_runner(actor.direction, delta, not first_person)
	remote.animate_runner(remote_direction, delta, remote_visible)
	view.follow(actor.position, camera_yaw, camera_pitch, first_person, delta)
	if latest_state.is_empty():
		return
	for i in range(office.props.size()):
		var prop: Node3D = office.props[i]
		var target: Transform3D = latest_state[1][i]
		if prop.position.distance_to(target.origin) > 0.34:
			prop.transform = target
		else:
			prop.transform = prop.transform.interpolate_with(target, 1.0 - exp(-delta * 22.0))
	view.update_round(shift_round, latest_state[0], _held_prop(), latest_state[4], first_person)

func _unhandled_input(event: InputEvent) -> void:
	if server_mode or not current_round:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		suppress_input = not suppress_input
		view.show_pause(suppress_input)
		return
	if suppress_input or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		camera_yaw -= event.relative.x * 0.003
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.003, -1.23, 0.95)
	elif event.is_action_pressed("grip"):
		interact.rpc_id(1, round_id, false, Vector3.ZERO)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var aim := Basis.from_euler(Vector3(camera_pitch, camera_yaw, 0), EULER_ORDER_YXZ) * Vector3.FORWARD
		interact.rpc_id(1, round_id, true, aim)
