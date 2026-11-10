class_name ChaosCoffeeCup
extends Control

# Side view of the boss's mug for the HUD. The surface is driven by the same
# slosh value the game uses to spill, so "about to overflow" on screen means
# it really is about to overflow. Level = amount, tint and steam = temperature.

var coffee: ChaosCoffee
var chair: RigidBody3D
var minimum = 0.0
var show_heat = false
var tilt = 0.0
var tilt_velocity = 0.0
var phase = 0.0
var drops: Array = []
var flash = 0.0
const INSIDE = Rect2(26,30,84,98)
const CUP = Color("ece5d6")
const HOT = Color("5b3417")
const COLD = Color("7a6656")

func setup(source: ChaosCoffee, vehicle: RigidBody3D):
	coffee = source; chair = vehicle
	custom_minimum_size = Vector2(150,150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	coffee.spilled.connect(_on_spilled)

func _on_spilled(amount: float):
	if drops.size()>40: return
	var side = 1.0 if tilt<0 else -1.0
	for i in range(clampi(int(amount*3)+1,1,3)):
		var x = INSIDE.position.x+(INSIDE.size.x+4 if side>0 else -4)
		drops.append({"p":Vector2(x,INSIDE.position.y-2),"v":Vector2(side*randf_range(25,70),randf_range(-60,-10)),"life":.9})

func _process(delta):
	if coffee==null or not is_visible_in_tree(): return
	var forward = -chair.global_basis.z; forward.y = 0
	var push = coffee.filtered_acceleration.dot(forward.normalized()) if forward.length()>.01 else 0.0
	# Liquid lags behind the push: accelerating tips it back (left), braking forward (right).
	var target = clampf(-push*.22,-1,1)
	tilt_velocity += ((target-tilt)*55-tilt_velocity*6)*delta
	tilt = clampf(tilt+tilt_velocity*delta,-1.3,1.3)
	phase += delta*(5.5+coffee.fullness()*5)
	flash = flash+delta*10 if coffee.fullness()>=ChaosTuning.COFFEE_SLOSH_WARN else 0.0
	for drop in drops:
		drop.v.y += 420*delta; drop.p += drop.v*delta; drop.life -= delta
	drops = drops.filter(func(d): return d.life>0)
	queue_redraw()

func _surface(level_y: float, height: float, x: float) -> float:
	var half = INSIDE.size.x/2
	var u = (x-INSIDE.position.x-half)/half
	var wave = sin(phase+u*2.6)*.38+sin(phase*1.7-u*4.1)*.12
	return level_y-height*(clampf(tilt,-1,1)*u+wave)/1.3

func _draw():
	if coffee==null: return
	var top = INSIDE.position.y; var bottom = INSIDE.end.y
	var left = INSIDE.position.x; var right = INSIDE.end.x
	var full = coffee.amount/100.0
	# A full mug still leaves headroom so the slosh can be seen reaching the rim.
	var level_y = bottom-(bottom-top)*.66*full
	var headroom = level_y-top
	var height = clampf(coffee.fullness(),0,1.4)*headroom
	var heat = clampf((coffee.temperature-ChaosTuning.COFFEE_AMBIENT)/(ChaosTuning.COFFEE_HOT-ChaosTuning.COFFEE_AMBIENT),0,1)
	var liquid = COLD.lerp(HOT,heat) if show_heat else HOT
	# Inner shadow of the mug.
	draw_rect(INSIDE,Color(.09,.07,.06,.55))
	if coffee.amount>.5:
		var points = PackedVector2Array()
		var surface = PackedVector2Array()
		var x = left
		while x<=right+.1:
			var y = clampf(_surface(level_y,height,x),top-10,bottom)
			surface.append(Vector2(x,y)); x += 3
		points.append_array(surface)
		points.append(Vector2(right,bottom)); points.append(Vector2(left,bottom))
		draw_colored_polygon(points,liquid)
		draw_polyline(surface,liquid.lightened(.35),2.2,true)
		# Spill over the lip when the crest passes the rim.
		for edge in [surface[0],surface[-1]]:
			if edge.y<top:
				var outward = -1.0 if edge.x<left+1 else 1.0
				draw_line(Vector2(edge.x,top-2),Vector2(edge.x+outward*5,top+18),liquid,4,true)
	if minimum>0:
		var min_y = bottom-(bottom-top)*.66*minimum/100.0
		draw_dashed_line(Vector2(left-2,min_y),Vector2(right+2,min_y),Color(ChaosStyle.STAMP,.95),2,5)
	# Mug body: thick walls, rounded base and a handle.
	var warn = coffee.fullness()>=ChaosTuning.COFFEE_SLOSH_WARN
	var outline = CUP.lerp(ChaosStyle.DANGER,.5+.5*sin(flash)) if warn else CUP
	var wall = 7.0
	draw_line(Vector2(left-wall/2,top-6),Vector2(left-wall/2,bottom-6),outline,wall,true)
	draw_line(Vector2(right+wall/2,top-6),Vector2(right+wall/2,bottom-6),outline,wall,true)
	draw_arc(Vector2(left+10,bottom-6),10+wall/2,PI/2,PI,10,outline,wall,true)
	draw_arc(Vector2(right-10,bottom-6),10+wall/2,0,PI/2,10,outline,wall,true)
	draw_line(Vector2(left+10,bottom+wall/2+4),Vector2(right-10,bottom+wall/2+4),outline,wall,true)
	draw_arc(Vector2(right+wall+9,top+44),20,-PI/2,PI/2,20,outline,wall,true)
	draw_line(Vector2(left-wall,top-6),Vector2(right+wall,top-6),outline.darkened(.08),3,true)
	# Steam fades out as the coffee cools.
	if show_heat and heat>.35 and coffee.amount>.5:
		var alpha = clampf((heat-.35)/.45,0,1)*.55
		for k in range(3):
			var base_x = left+INSIDE.size.x*(.28+k*.22)
			var line = PackedVector2Array()
			for j in range(9):
				var y = top-10-j*3.2
				line.append(Vector2(base_x+sin(phase*.45+j*.7+k*1.9)*4,y))
			draw_polyline(line,Color(1,1,1,alpha*(1-.07*k)),2,true)
	for drop in drops:
		draw_circle(drop.p,2.6,Color(liquid,clampf(drop.life*1.6,0,1)))
