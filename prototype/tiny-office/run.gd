extends RefCounted

const Desk = preload("res://office.gd")
const REACH = 0.21
const DROP_HEIGHT = Desk.DESK_TOP - 0.12
const GOAL_RADII = [0.075, 0.112]

var office: Node3D
var players: Array
var layout := 0
var complete: Array[bool] = [false, false]
var holders: Array[int] = [-1, -1]
var goals := [0.0, 0.0]
var facing := [Vector3.FORWARD, Vector3.FORWARD]

func reset(round_number: int) -> void:
	layout = (round_number - 1) % Desk.SPAWNS.size()
	complete.assign([false, false])
	holders.assign([-1, -1])
	goals = [0.0, 0.0]
	facing = [Vector3.FORWARD, Vector3.FORWARD]
	for i in range(office.props.size()):
		_place(i, Desk.SPAWNS[layout][i], false)

func interact(seat: int, throwing: bool, aim: Vector3) -> void:
	var held := holders.find(seat)
	if held >= 0:
		_drop(held, aim.normalized() * 1.45 + Vector3.UP * 0.32 if throwing else Vector3.ZERO)
	elif not throwing:
		var target := _near_prop(seat)
		if target >= 0:
			holders[target] = seat
			goals[target] = 0.0
			office.props[target].freeze = true

func release_player(seat: int) -> void:
	var held := holders.find(seat)
	if held >= 0:
		_drop(held, Vector3.ZERO)

func tick(delta: float) -> void:
	for i in range(office.props.size()):
		var prop: RigidBody3D = office.props[i]
		if complete[i]:
			continue
		var seat := holders[i]
		if seat >= 0:
			var actor = players[seat]
			if actor.direction.length_squared() > 0.01:
				facing[seat] = Vector3(actor.direction.x, 0, actor.direction.y).normalized()
			prop.position = actor.position + Vector3.UP * 0.065 + facing[seat] * 0.105
			continue
		if prop.position.y < DROP_HEIGHT:
			_place(i, Desk.SPAWNS[layout][i], false)
			goals[i] = 0.0
			continue
		var goal: Vector3 = Desk.DESTINATIONS[i]
		var offset := prop.position - goal
		if Vector2(offset.x, offset.z).length() <= GOAL_RADII[i] and absf(offset.y) < 0.045 and prop.linear_velocity.length() < 0.20:
			goals[i] += delta
			if goals[i] >= 0.15:
				complete[i] = true
				_place(i, goal, true)
		else:
			goals[i] = 0.0

func snapshot() -> Array:
	var props := []
	for prop in office.props:
		props.append(prop.transform)
	return [complete.duplicate(), props, holders.duplicate()]

func _near_prop(seat: int) -> int:
	var origin: Vector3 = players[seat].position + Vector3.UP * 0.05
	var nearest := -1
	var reach := REACH
	for i in range(office.props.size()):
		if complete[i] or holders[i] >= 0:
			continue
		var distance := origin.distance_to(office.props[i].position)
		if distance < reach:
			reach = distance
			nearest = i
	return nearest

func _drop(i: int, velocity: Vector3) -> void:
	holders[i] = -1
	var prop: RigidBody3D = office.props[i]
	prop.freeze = false
	prop.sleeping = false
	prop.linear_velocity = velocity
	prop.angular_velocity = Vector3.ZERO

func _place(i: int, at: Vector3, stopped: bool) -> void:
	var prop: RigidBody3D = office.props[i]
	prop.freeze = true
	prop.transform = Transform3D(Basis.IDENTITY, at)
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	prop.freeze = stopped
	prop.sleeping = stopped
