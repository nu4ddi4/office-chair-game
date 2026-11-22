extends RefCounted

const Map = preload("res://office.gd")
const FREE = 0
const CAUGHT = 1
const CABLE = 2
const REACH = 0.19
const WATCH_TIME = 0.75
const GRAB_TIME = 0.65
const PATROL_SECONDS = 26.0

var office: Node3D
var players: Array
var checkpoint = 0
var elapsed = 0.0
var captives = [FREE, FREE]
var immunity = [0.0, 0.0]
var escape_clock = 0.0
var patrol_clock = 0.0
var capture_cooldown = 0.0
var drawer_locked = false
var bridge_ready = false
var drawer_fraction = 0.0
var bridge_fraction = 0.0
var bridge_hold = 0.0
var rescue_clock = 0.0
var reset_clock = 0.0
var done = false
var focus = [-1, -1]
var cable_clock = [0.0, 0.0]
var cable_must_release = [false, false]
var cable_origin = [Vector3.ZERO, Vector3.ZERO]
var cable_destination = [Vector3.ZERO, Vector3.ZERO]
var staff_at = Vector3.ZERO
var staff_yaw = 0.0
var staff_active = false
var warning_slot = -1
var warning_time = 0.0
var hand_goal = Vector3.ZERO

func reset(section: int) -> void:
	checkpoint = section
	drawer_locked = section > 0
	bridge_ready = section > 1
	drawer_fraction = float(drawer_locked)
	bridge_fraction = float(bridge_ready)
	office.set_puzzles(drawer_fraction, bridge_fraction)
	patrol_clock = 0.0
	capture_cooldown = 0.0
	bridge_hold = 0.0
	rescue_clock = 0.0
	escape_clock = 0.0
	warning_slot = -1
	warning_time = 0.0
	reset_clock = 0.0
	done = false
	for i in range(2):
		captives[i] = FREE
		immunity[i] = 1.75
		cable_must_release[i] = false
		_spawn(i)

func _spawn(slot: int) -> void:
	var safe_spots = [Map.START, Map.FIRST_TABLE, Map.SECOND_TABLE]
	var player = players[slot]
	player.position = safe_spots[checkpoint] + Vector3(0, 0, -0.08 + slot * 0.16)
	player.velocity = Vector3.ZERO
	player.grounded = false
	player.direction = Vector2.ZERO
	player.held = false

func tick(delta: float) -> void:
	if done:
		return
	elapsed += delta
	if captives[0] == CAUGHT and captives[1] == CAUGHT:
		reset_clock += delta
		if reset_clock >= 1.75:
			reset(checkpoint)
		return
	for i in range(2):
		immunity[i] = maxf(0, immunity[i] - delta)
		if not players[i].held:
			cable_must_release[i] = false
		if captives[i] == CABLE:
			_move_on_cable(i, delta)
		if players[i].position.y < -0.45:
			_spawn(i)
		focus[i] = _near_action(i)
	_puzzles(delta)
	_rescue(delta)
	_patrol(delta)
	_progress(delta)

func _near_action(slot: int) -> int:
	if captives[slot] != FREE:
		return -1
	var at: Vector3 = players[slot].position
	var other: int = 1 - slot
	if captives[other] == CAUGHT and _reachable(slot, players[other].position, 0.28):
		return 7
	if not drawer_locked:
		if drawer_fraction > 0.9 and at.y > 0.236 and _reachable(slot, Map.DRAWER_CLIP):
			return 1
		if at.y < 0.095 and _reachable(slot, Map.DRAWER_HANDLE, 0.23):
			return 0
	if checkpoint >= 1 and not bridge_ready:
		if _reachable(slot, Map.LEFT_GRIP, 0.16):
			return 2
		if _reachable(slot, Map.RIGHT_GRIP, 0.16):
			return 3
	if checkpoint >= 2 and not cable_must_release[slot]:
		if at.y > 0.68 and _reachable(slot, Map.CABLE_TOP, 0.19):
			return 4
		if at.y < 0.11 and _reachable(slot, Map.CABLE_BOTTOM, 0.19):
			return 5
	return -1

func _reachable(slot: int, target: Vector3, radius: float = REACH) -> bool:
	var at: Vector3 = players[slot].position + Vector3.UP * 0.063
	var to = target + Vector3.UP * 0.035
	if at.distance_to(to) > radius:
		return false
	# These switch markers may lie against their own prop. Stop just short of the surface.
	var ray_end = to.move_toward(at, 0.021)
	return _clear_ray(at, ray_end)

func _hand_action(slot: int, action: int) -> bool:
	return focus[slot] == action and players[slot].held

func _puzzles(delta: float) -> void:
	var holding_drawer = _hand_action(0, 0) or _hand_action(1, 0)
	if (_hand_action(0, 0) and _hand_action(1, 1)) or (_hand_action(1, 0) and _hand_action(0, 1)):
		drawer_locked = true
	drawer_fraction = move_toward(drawer_fraction, 1.0 if holding_drawer or drawer_locked else 0.0, delta * 3.5)
	var two_hands = (_hand_action(0, 2) and _hand_action(1, 3)) or (_hand_action(1, 2) and _hand_action(0, 3))
	bridge_hold = minf(0.7, bridge_hold + delta) if two_hands else 0.0
	bridge_ready = bridge_ready or bridge_hold >= 0.7
	bridge_fraction = move_toward(bridge_fraction, float(bridge_ready), delta * 2.1)
	office.set_puzzles(drawer_fraction, bridge_fraction)
	for i in range(2):
		if _hand_action(i, 4) or _hand_action(i, 5):
			captives[i] = CABLE
			cable_must_release[i] = true
			cable_clock[i] = 0.0
			cable_origin[i] = players[i].position
			cable_destination[i] = Map.CABLE_BOTTOM + Vector3(0.06, 0, 0) if focus[i] == 4 else Map.CABLE_TOP + Vector3(-0.13, 0.006, 0)

func _move_on_cable(slot: int, delta: float) -> void:
	cable_clock[slot] = minf(1.0, cable_clock[slot] + delta / 1.55)
	var t: float = cable_clock[slot]
	var from: Vector3 = cable_origin[slot]
	var to: Vector3 = cable_destination[slot]
	var edge = Vector3(2.87, 0.81, 0.53)
	var base = Vector3(2.87, 0.005, 0.53)
	if from.y < to.y:
		var temp = edge
		edge = base
		base = temp
	if t < 0.18:
		players[slot].position = from.lerp(edge, t / 0.18)
	elif t < 0.82:
		players[slot].position = edge.lerp(base, (t - 0.18) / 0.64)
	else:
		players[slot].position = base.lerp(to, (t - 0.82) / 0.18)
	if t >= 1.0:
		captives[slot] = FREE
		players[slot].velocity = Vector3.ZERO
		players[slot].grounded = false
		immunity[slot] = 0.55

func _rescue(delta: float) -> void:
	if not (_hand_action(0, 7) or _hand_action(1, 7)):
		rescue_clock = 0.0
		return
	rescue_clock += delta
	if rescue_clock < 1.5:
		return
	for i in range(2):
		if captives[i] == CAUGHT:
			captives[i] = FREE
			immunity[i] = 3.0
			players[i].grounded = false
	rescue_clock = 0.0

func _patrol(delta: float) -> void:
	patrol_clock = fposmod(patrol_clock + delta, PATROL_SECONDS)
	capture_cooldown = maxf(0, capture_cooldown - delta)
	var route = [
		Vector3(-6.4, 0, -1.60), Vector3(-4.0, 0, -1.49), Vector3(-1.72, 0, -1.23),
		Vector3(1.74, 0, -1.20), Vector3(3.72, 0, 0.51), Vector3(3.65, 0, -2.26),
		Vector3(-6.4, 0, -1.60),
	]
	var timeline = [0.0, 4.8, 8.4, 13.4, 17.75, 22.0, PATROL_SECONDS]
	var segment = 0
	while patrol_clock >= timeline[segment + 1]:
		segment += 1
	var progress = (patrol_clock - timeline[segment]) / (timeline[segment + 1] - timeline[segment])
	staff_at = route[segment].lerp(route[segment + 1], smoothstep(0.04, 0.96, progress))
	staff_yaw = -0.85 if segment == 3 else 1.14 if segment == 4 else 0.0
	staff_active = segment > 0 and segment < 5 and capture_cooldown <= 0
	if not staff_active:
		_clear_warning()
		return
	var victim = warning_slot
	if victim < 0 or not _sees(victim):
		victim = -1
		for i in range(2):
			if _sees(i):
				victim = i
				break
	if victim != warning_slot:
		warning_slot = victim
		warning_time = 0.0
	if victim < 0:
		return
	warning_time += delta
	hand_goal = players[victim].position
	if warning_time >= WATCH_TIME + GRAB_TIME:
		captives[victim] = CAUGHT
		_drop_cup(victim)
		players[victim].velocity = Vector3.ZERO
		capture_cooldown = 2.65
		_clear_warning()

func _drop_cup(slot: int) -> void:
	var at: Vector3 = players[slot].position
	var ray = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.012, at - Vector3.UP * 2.0, 1)
	var floor_hit = office.get_world_3d().direct_space_state.intersect_ray(ray)
	if not floor_hit.is_empty():
		players[slot].position = floor_hit.position + Vector3.UP * 0.002

func _clear_warning() -> void:
	warning_slot = -1
	warning_time = 0.0

func _sees(slot: int) -> bool:
	if captives[slot] == CAUGHT or immunity[slot] > 0.0:
		return false
	var at: Vector3 = players[slot].position
	var direction = Vector2(at.x - staff_at.x, at.z - staff_at.z)
	if direction.length_squared() > 2.10 * 2.10:
		return false
	var forward = Vector2(sin(staff_yaw), cos(staff_yaw))
	if direction.normalized().dot(forward) < 0.38:
		return false
	return _clear_ray(staff_at + Vector3.UP * 1.57, at + Vector3.UP * 0.101)

func _clear_ray(from: Vector3, to: Vector3) -> bool:
	var ray = PhysicsRayQueryParameters3D.create(from, to, 1)
	return office.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _progress(delta: float) -> void:
	var a: Vector3 = players[0].position
	var b: Vector3 = players[1].position
	if captives != [FREE, FREE]:
		escape_clock = 0.0
		return
	if checkpoint == 0 and drawer_locked and _on_table(a, false) and _on_table(b, false):
		checkpoint = 1
	elif checkpoint == 1 and bridge_ready and _on_table(a, true) and _on_table(b, true):
		checkpoint = 2
	if checkpoint == 2 and a.distance_to(Map.EXIT) < 0.37 and b.distance_to(Map.EXIT) < 0.37:
		escape_clock += delta
		done = escape_clock > 0.45
	else:
		escape_clock = 0.0

func _on_table(at: Vector3, second: bool) -> bool:
	return at.y > 0.775 and absf(at.z) < 0.71 and (at.x > 0.27 if second else at.x < -0.27 and at.x > -2.78)

func snapshot() -> Array:
	return [checkpoint, elapsed, captives, drawer_locked, bridge_ready, drawer_fraction, bridge_fraction, done, focus,
		rescue_clock, reset_clock, staff_at, staff_yaw, warning_slot, warning_time, hand_goal]
