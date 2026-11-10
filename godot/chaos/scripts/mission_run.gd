class_name ChaosMissionRun
extends RefCounted

var mission: Dictionary
var index = 0
var checkpoint = 0
var elapsed = 0.0
var remaining = -1.0
var falls = 0
var damage = 0
var retries = 0
var park_time = 0.0
var phase = "playing"
var reason = ""
var refilled = false

func begin(definition: Dictionary, saved: Dictionary = {}):
	mission = definition
	index = int(saved.get("checkpoint",0))
	checkpoint = index
	elapsed = float(saved.get("elapsed",0))
	falls = int(saved.get("falls",0)); damage = int(saved.get("damage",0)); retries = int(saved.get("retries",0))
	remaining = float(saved.get("remaining",mission.budget))
	refilled = bool(saved.get("refilled",not mission.get("requires_refill",false)))
	phase = "playing"; park_time = 0; reason = ""

func tick(delta: float, at: Vector3, speed: float, seated: bool, coffee: float, temperature = ChaosTuning.COFFEE_HOT) -> String:
	if phase!="playing": return ""
	elapsed += delta
	if remaining>=0:
		remaining = maxf(0,remaining-delta)
		if remaining<=0: return fail("회의 시간이 지났습니다.")
	var waypoint: Dictionary = mission.route[index]
	var target = ChaosMissions.point(waypoint.at)
	if Vector2(at.x-target.x,at.z-target.z).length()>waypoint.get("radius",1.65):
		park_time = 0; return ""
	if not seated or not refilled:
		park_time = 0; return ""
	var last = index==mission.route.size()-1
	if last and speed>=ChaosTuning.PARK_SPEED:
		park_time = 0; return ""
	park_time += delta
	if park_time < (ChaosTuning.PARK_HOLD if last else .18): return ""
	park_time = 0
	if last:
		if coffee<float(mission.min_coffee): return fail("커피가 부족합니다. 최소 %d%%가 필요합니다." % mission.min_coffee)
		if temperature<float(mission.get("min_temp",0)): return fail("커피가 식었습니다. %d°C 이상이어야 합니다." % int(mission.min_temp))
		phase = "success"; return "success"
	index += 1
	if waypoint.get("checkpoint",false):
		checkpoint = index
		if float(mission.budget)>0: remaining = float(mission.budget)
		return "checkpoint"
	return "waypoint"

func boss_fell() -> String:
	if phase!="playing": return ""
	falls += 1
	if mission.get("strict_after",-1)>=0 and index>=int(mission.strict_after):
		return fail("이 구간에서는 부장님을 떨어뜨리면 안 됩니다.")
	return "fall"

func fail(message: String) -> String:
	phase = "failure"; reason = message
	return "failure"

func snapshot(coffee: float, temperature = ChaosTuning.COFFEE_HOT) -> Dictionary:
	return {"mission":int(mission.id),"checkpoint":checkpoint,"coffee":clampf(coffee,0,100),"temperature":clampf(temperature,ChaosTuning.COFFEE_AMBIENT,ChaosTuning.COFFEE_HOT),"remaining":remaining,"elapsed":elapsed,"falls":falls,"damage":damage,"retries":retries,"refilled":refilled}

func medals() -> Array:
	return [elapsed<=float(mission.target_time),falls==0,damage<=int(mission.damage_budget)]
