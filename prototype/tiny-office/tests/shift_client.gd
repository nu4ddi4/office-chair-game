extends SceneTree

const SESSION = preload("res://main.tscn")
const Desk = preload("res://office.gd")

var game: Node
var sequence := 0
var commands: Array = []
var role: String
var failed := false

func _initialize() -> void:
	_test.call_deferred()

func _test() -> void:
	var arguments := OS.get_cmdline_user_args()
	role = arguments[2]
	game = SESSION.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.connect_room("127.0.0.1", int(arguments[0]), arguments[1])
	if role == "partner":
		if not await _until(func(): return game.view.screen == "waiting_round", "late join"):
			return
		print("SHIFT_TEST late_join")
		if not await _until(func(): return game.current_round and game.shift_round == 2 and _ready_state(), "partner entering round two", 25000):
			return
		if not await _grab(1):
			return
		print("SHIFT_TEST partner_holding")
		await create_timer(0.5).timeout
		game.leave_room()
		await create_timer(0.25).timeout
		quit()
		return
	if role == "coworker":
		if not await _until(func(): return game.view.screen == "lobby", "two-player lobby"):
			return
		for number in range(1, 4):
			if not await _until(func(): return game.current_round and game.shift_round == number and _ready_state(), "co-op round start"):
				return
			sequence = 0
			commands.clear()
			if not await _deliver(1):
				return
			if not await _until(func(): return not game.current_round, "co-op round result", 18000):
				return
		print("SHIFT_TEST passed coworker")
		quit()
		return
	if not await _until(func(): return game.view.screen == "lobby", "solo lobby"):
		return
	if role == "duo" and not await _until(func(): return _has_label("참가자 2/2"), "both workers ready"):
		return
	game.request_shift.rpc_id(1, game.round_id)
	for number in range(1, 4):
		if not await _until(func(): return game.current_round and game.shift_round == number and _ready_state(), "round %d start" % number):
			return
		sequence = 0
		commands.clear()
		if number == 1 and role != "duo":
			print("SHIFT_TEST solo_round")
			await create_timer(0.6).timeout
		if number == 2 and role == "primary":
			if not await _until(func(): return _ready_state() and _shared()[2][1] == 1, "partner picked up paper"):
				return
			if not await _until(func(): return _ready_state() and not _shared()[3][1] and _shared()[2][1] == -1, "partner disconnected and released paper"):
				return
			print("SHIFT_TEST partner_left")
		if not await _deliver(0):
			return
		if role != "duo" and not await _deliver(1):
			return
		var screen := "shift_result" if number == 3 else "round_result"
		if not await _until(func(): return game.view.screen == screen, "round %d results" % number):
			return
		if not _has_result(number * 2):
			_fail("Incorrect result total")
			return
	if game.round_id != 3:
		_fail("A round restarted unexpectedly")
		return
	game.request_shift.rpc_id(1, game.round_id)
	if not await _until(func(): return game.current_round and game.round_id == 4 and _ready_state(), "new shift"):
		return
	if game.shift_round != 1 or _shared()[0] != [false, false]:
		_fail("New shift did not reset round and objectives")
		return
	print("SHIFT_TEST passed " + role)
	quit()

func _has_result(total: int) -> bool:
	return _has_label("완료한 업무 %d개" % total)

func _has_label(prefix: String) -> bool:
	for child in game.view.form.get_children():
		if child is Label and child.text.begins_with(prefix):
			return true
	return false

func _ready_state() -> bool:
	return not game.received.is_empty()

func _shared() -> Array:
	return game.received[1]

func _grab(i: int) -> bool:
	var target: Vector3 = _shared()[1][i].origin
	if not await _walk(target):
		return false
	game.interact.rpc_id(1, game.round_id, false, Vector3.ZERO)
	return await _until(func(): return _ready_state() and _shared()[2][i] == game.slot, "grab %d" % i)

func _deliver(i: int) -> bool:
	if not await _grab(i):
		return false
	var goal: Vector3 = Desk.DESTINATIONS[i]
	if not await _walk(goal + Vector3(0, 0, 0.21)):
		return false
	if not await _walk(goal + Vector3(0, 0, 0.10)):
		return false
	game.interact.rpc_id(1, game.round_id, false, Vector3.ZERO)
	return await _until(func(): return not game.current_round or _shared()[0][i], "deliver %d" % i)

func _walk(target: Vector3) -> bool:
	var deadline := Time.get_ticks_msec() + 14000
	var last := Vector3.ZERO
	var ack := 0
	while Time.get_ticks_msec() < deadline and game.current_round:
		if _ready_state():
			var body: Array = game.received[0][game.slot]
			last = body[0]
			ack = body[4]
			var distance := Vector2(target.x - last.x, target.z - last.z)
			sequence += 1
			var axis := Vector2.ZERO if distance.length() <= 0.025 else (distance / 0.09).limit_length()
			commands.append([sequence, axis, 0])
			if commands.size() > 4:
				commands.pop_front()
			game.inputs.rpc_id(1, game.round_id, commands)
			if axis == Vector2.ZERO:
				await create_timer(0.09).timeout
				return true
		await create_timer(0.019).timeout
	_fail("Round %d: could not reach %s from %s (input %d, server %d)" % [game.shift_round, target, last, sequence, ack])
	return false

func _until(condition: Callable, context: String, timeout_ms := 9500) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout
	if condition.call():
		return true
	_fail("Timed out: " + context)
	return false

func _fail(message: String) -> void:
	if not failed:
		failed = true
		printerr("SHIFT_TEST " + role + ": " + message)
		quit(1)
