class_name ChaosStamp
extends Control

# An inked approval stamp (도장). Round stamps for names and medals,
# rectangular ones for 승인/반려 verdicts. Drawn in code, no textures.

var text = "결재"
var color = ChaosStyle.STAMP
var round_shape = true
var inked = true
var angle = -0.18
var weight = 900

func setup(value: String, diameter: float, is_round = true, tint = ChaosStyle.STAMP, tilt = -0.18) -> ChaosStamp:
	text = value; round_shape = is_round; color = tint; angle = tilt
	custom_minimum_size = Vector2(diameter, diameter if is_round else diameter*.56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = custom_minimum_size/2
	queue_redraw()
	return self

func set_inked(value: bool):
	inked = value; queue_redraw()

func _draw():
	if text.is_empty(): return
	var tint = color if inked else Color(ChaosStyle.INK.r,ChaosStyle.INK.g,ChaosStyle.INK.b,.22)
	var center = size/2
	draw_set_transform(center,angle)
	var line = maxf(2.0,minf(size.x,size.y)*.06)
	var font = ChaosStyle.font(weight)
	if round_shape:
		var radius = minf(size.x,size.y)/2-line
		draw_arc(Vector2.ZERO,radius,0,TAU,48,tint,line,true)
		if size.x>44: draw_arc(Vector2.ZERO,radius-line*1.7,0,TAU,48,Color(tint,tint.a*.55),maxf(1,line*.4),true)
		var font_size = int(radius*(1.05 if text.length()<=1 else .62 if text.length()==2 else .5))
		var width = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,Vector2(-width/2,font_size*.36),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)
	else:
		var half = size/2-Vector2(line,line)
		draw_rect(Rect2(-half,half*2),tint,false,line,true)
		draw_rect(Rect2(-half+Vector2(line*1.6,line*1.6),half*2-Vector2(line*3.2,line*3.2)),Color(tint,tint.a*.6),false,maxf(1,line*.45),true)
		var font_size = int(half.y*1.15)
		var width = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,Vector2(-width/2,font_size*.36),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)
	draw_set_transform(Vector2.ZERO,0)
