extends SceneTree
# Apply bounded forces to a loaded chair to verify all authored routes against
# real collision geometry. Hand-driven movement is covered by physics.gd.
var game: OfficeChairChaos
var failures=[]
func _initialize(): call_deferred("drive")
func drive():
	RenderingServer.set_render_loop_enabled(false)
	game=load("res://chaos/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.store.data.unlocked=6
	for id in range(1,7):
		game.start_mission(id)
		for i in range(120): await physics_frame
		if id in [2,6]: game.interact()
		var last_index=0
		var stuck=0
		for i in range(36000):
			if game.run.phase!="playing": break
			var goal=ChaosMissions.point(game.run.mission.route[game.run.index].at)
			var at=game.chair.global_position
			var offset=goal-at; offset.y=0
			var desired=offset.normalized()*minf(1.1,offset.length()*1.5)
			game.chair.apply_central_force(((desired-Vector3(game.chair.linear_velocity.x,0,game.chair.linear_velocity.z))*190).limit_length(320))
			for door in game.office.doors:
				if door.leaf.global_position.distance_to(at)<2 and i%120==0: door.interact(at)
			if game.run.index!=last_index:
				last_index=game.run.index; stuck=0
			else: stuck+=1
			if i%2400==0: print("ROUTE ",JSON.stringify({"mission":id,"t":i/120,"index":game.run.index,"chair":str(at),"seated":game.boss.seated,"coffee":game.coffee.amount}))
			if stuck>18000: break
			await physics_frame
		var success=game.run.phase=="success"
		if not success: failures.append({"mission":id,"index":game.run.index,"reason":game.run.reason,"chair":str(game.chair.position)})
		print("ROUTE_COMPLETE ",JSON.stringify({"mission":id,"passed":success,"time":game.run.elapsed,"falls":game.run.falls}))
	print("CHAOS_ROUTES ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	paused=false; game.queue_free(); await process_frame; await process_frame; quit(0 if failures.is_empty() else 1)
