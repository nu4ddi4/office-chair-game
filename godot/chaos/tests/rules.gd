extends SceneTree

var failures: Array[String] = []
var checks = 0
func check(value: bool, label: String):
	checks+=1
	if not value: failures.append(label)

func _initialize(): call_deferred("run_tests")

func run_tests():
	var missions=ChaosMissions.load_all()
	check(missions.size()==6,"six authored missions")
	for m in missions:
		var run=ChaosMissionRun.new(); run.begin(m)
		run.refilled=true
		for i in range(m.route.size()):
			var at=ChaosMissions.point(m.route[i].at)
			var event=""
			for n in range(16):
				event=run.tick(.1,at,0,true,100)
				if not event.is_empty(): break
			check(event==("success" if i==m.route.size()-1 else "checkpoint" if m.route[i].get("checkpoint",false) else "waypoint"),"mission %d waypoint %d" % [m.id,i])
		check(run.phase=="success","mission %d finishes" % m.id)
	var timed=ChaosMissionRun.new(); timed.begin(missions[3]); timed.remaining=.01
	check(timed.tick(.02,Vector3.ZERO,0,true,100)=="failure","time expiration")
	var coffee=ChaosMissionRun.new(); coffee.begin(missions[1]); coffee.index=missions[1].route.size()-1; coffee.refilled=true
	check(coffee.tick(2,ChaosMissions.point(missions[1].route[-1].at),0,true,19.9)=="failure","coffee lower boundary")
	coffee.begin(missions[1]); coffee.index=missions[1].route.size()-1; coffee.refilled=true
	check(coffee.tick(2,ChaosMissions.point(missions[1].route[-1].at),.26,true,20)=="","parking speed boundary")
	check(coffee.tick(2,ChaosMissions.point(missions[1].route[-1].at),0,true,20)=="success","coffee exact boundary")
	var strict=ChaosMissionRun.new(); strict.begin(missions[4])
	check(strict.boss_fell()=="fall","practice fall recoverable")
	strict.index=2; check(strict.boss_fell()=="failure","strict fall fails")
	var waiting=ChaosMissionRun.new(); waiting.begin(missions[1])
	check(waiting.tick(2,ChaosMissions.point(missions[1].route[0].at),0,true,100)=="","refill must happen")
	var save=ChaosSave.new(); save.directory="user://rules-%d" % OS.get_process_id()
	check(ChaosSave.valid(save.data),"fresh save valid")
	save.data.resume=coffee.snapshot(20); save.data.unlocked=2
	check(save.write(),"atomic save")
	var loaded=ChaosSave.new(); loaded.directory=save.directory
	check(loaded.load_progress() and loaded.data.resume.coffee==20,"save roundtrip")
	save.data.resume={}; save.complete(coffee)
	check(save.data.unlocked==3 and 2 in save.data.completed,"completion unlocks")
	check(save.write(),"backup save")
	var file=FileAccess.open(save.directory.path_join("progress.json"),FileAccess.WRITE); file.store_string("broken"); file.close()
	check(loaded.load_progress(),"backup recovery")
	var bad=ChaosSave.fresh(); bad.resume={"mission":88}
	check(not ChaosSave.valid(bad),"reject invalid resume")
	bad=ChaosSave.fresh(); bad.settings.fov=999
	check(not ChaosSave.valid(bad),"reject invalid settings")
	bad=ChaosSave.fresh(); bad.records={"1":{"time":"oops","medals":[]}}
	check(not ChaosSave.valid(bad),"reject malformed records")
	print("CHAOS_RULES ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
