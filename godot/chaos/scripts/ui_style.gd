class_name ChaosStyle
extends RefCounted

# Design tokens for the "결재 서류" (office paperwork) look: warm paper sheets,
# navy ink, vermilion approval stamps and yellow sticky notes over a dimmed office.

const INK = Color("1d2a33")
const INK_SOFT = Color(0.114,0.165,0.2,.62)
const INK_FAINT = Color(0.114,0.165,0.2,.32)
const PAPER = Color("f3ede1")
const PAPER_SHADE = Color("e6dece")
const PAPER_LINE = Color("d3c9b4")
const STAMP = Color("c8402f")
const POSTIT = Color("f6d860")
const POSTIT_EDGE = Color("e3c13f")
const GLASS = Color(0.043,0.07,0.086,.82)
const GLASS_EDGE = Color(1,1,1,.10)
const ON_GLASS = Color("eef0ea")
const ON_GLASS_SOFT = Color(0.933,0.941,0.918,.62)
const AMBER = Color("f3b44a")
const OK = Color("6fae73")
const DANGER = Color("e0553e")
const FONT_PATH = "res://assets/fonts/NotoSansKR.ttf"
const WGHT = 2003265652  # OpenType 'wght' tag

static var _fonts = {}

static func font(weight: int) -> Font:
	if not _fonts.has(weight):
		var variation = FontVariation.new()
		variation.base_font = load(FONT_PATH)
		variation.variation_opentype = {WGHT: weight}
		_fonts[weight] = variation
	return _fonts[weight]

static func flat(color: Color, radius = 0, border = 0, border_color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border)
	box.border_color = border_color
	box.anti_aliasing = true
	return box

static func margins(box: StyleBox, horizontal: float, vertical: float) -> StyleBox:
	box.content_margin_left = horizontal; box.content_margin_right = horizontal
	box.content_margin_top = vertical; box.content_margin_bottom = vertical
	return box

static func paper() -> StyleBoxFlat:
	var box = flat(PAPER,4)
	box.shadow_color = Color(0,0,0,.5); box.shadow_size = 26; box.shadow_offset = Vector2(8,14)
	margins(box,46,34)
	return box

static func postit() -> StyleBoxFlat:
	var box = flat(POSTIT,2)
	box.border_width_bottom = 5; box.border_color = POSTIT_EDGE
	box.shadow_color = Color(0,0,0,.35); box.shadow_size = 12; box.shadow_offset = Vector2(4,8)
	margins(box,20,14)
	return box

static func glass(radius = 12) -> StyleBoxFlat:
	var box = flat(GLASS,radius,1,GLASS_EDGE)
	margins(box,18,14)
	return box

static func circle_texture(color: Color, size: int, ring = 0) -> ImageTexture:
	var image = Image.create(size,size,false,Image.FORMAT_RGBA8)
	var center = Vector2(size,size)/2.0
	for y in range(size):
		for x in range(size):
			var d = Vector2(x+.5,y+.5).distance_to(center)
			var a = clampf(size/2.0-d,0,1)
			if ring>0: a *= clampf(d-(size/2.0-ring),0,1)
			image.set_pixel(x,y,Color(color.r,color.g,color.b,color.a*a))
	return ImageTexture.create_from_image(image)

static func build_theme() -> Theme:
	var theme = Theme.new()
	theme.default_font = font(420)
	theme.default_font_size = 18
	# Menu rows: ruled form lines that light up with a stamp-red margin on hover.
	var row = flat(Color(0,0,0,0)); row.border_width_bottom = 1; row.border_color = PAPER_LINE
	margins(row,16,11)
	var row_hover = flat(PAPER_SHADE); row_hover.border_width_left = 5; row_hover.border_width_bottom = 1
	row_hover.border_color = STAMP; margins(row_hover,22,11); row_hover.content_margin_left = 22
	var row_pressed = row_hover.duplicate(); row_pressed.bg_color = PAPER_LINE
	for state in ["normal","disabled"]: theme.set_stylebox(state,"Button",row)
	theme.set_stylebox("hover","Button",row_hover)
	theme.set_stylebox("focus","Button",row_hover)
	theme.set_stylebox("pressed","Button",row_pressed)
	theme.set_stylebox("hover_pressed","Button",row_pressed)
	theme.set_color("font_color","Button",INK)
	theme.set_color("font_hover_color","Button",INK)
	theme.set_color("font_focus_color","Button",INK)
	theme.set_color("font_pressed_color","Button",INK)
	theme.set_color("font_hover_pressed_color","Button",INK)
	theme.set_color("font_disabled_color","Button",INK_FAINT)
	theme.set_font("font","Button",font(560))
	theme.set_font_size("font_size","Button",20)
	theme.set_constant("h_separation","Button",12)
	# Small value chips used for toggles and key bindings.
	theme.set_type_variation("Chip","Button")
	var chip = margins(flat(PAPER_SHADE,6,1,PAPER_LINE),14,6)
	var chip_hover = margins(flat(Color("fbf6ec"),6,2,STAMP),14,6)
	theme.set_stylebox("normal","Chip",chip); theme.set_stylebox("disabled","Chip",chip)
	theme.set_stylebox("hover","Chip",chip_hover); theme.set_stylebox("focus","Chip",chip_hover)
	theme.set_stylebox("pressed","Chip",chip_hover); theme.set_stylebox("hover_pressed","Chip",chip_hover)
	theme.set_font("font","Chip",font(650)); theme.set_font_size("font_size","Chip",17)
	# Sliders: inked track, stamp-red fill and a round grabber.
	var track = flat(PAPER_LINE,3); track.content_margin_top = 3; track.content_margin_bottom = 3
	var fill = flat(STAMP,3); fill.content_margin_top = 3; fill.content_margin_bottom = 3
	theme.set_stylebox("slider","HSlider",track)
	theme.set_stylebox("grabber_area","HSlider",fill)
	theme.set_stylebox("grabber_area_highlight","HSlider",fill)
	theme.set_icon("grabber","HSlider",circle_texture(INK,20))
	theme.set_icon("grabber_highlight","HSlider",circle_texture(STAMP,22))
	theme.set_icon("grabber_disabled","HSlider",circle_texture(INK_FAINT,20))
	# Progress bars (download, hold-to-reset).
	theme.set_stylebox("background","ProgressBar",flat(Color(0,0,0,.25),3))
	theme.set_stylebox("fill","ProgressBar",flat(AMBER,3))
	theme.set_color("font_color","Label",INK)
	theme.set_stylebox("normal","RichTextLabel",flat(Color(0,0,0,0)))
	theme.set_color("default_color","RichTextLabel",INK)
	theme.set_font("normal_font","RichTextLabel",font(400)); theme.set_font_size("normal_font_size","RichTextLabel",14)
	theme.set_stylebox("panel","ScrollContainer",flat(Color(0,0,0,0)))
	return theme

static func label(parent: Node, text: String, size: int, weight = 420, color = INK) -> Label:
	var result = Label.new(); parent.add_child(result)
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font",font(weight))
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color)
	return result

static func keycap(parent: Node, key: String, light = true) -> PanelContainer:
	var cap = PanelContainer.new(); parent.add_child(cap)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box = flat(PAPER if light else Color("2a3a42"),5,1,PAPER_LINE if light else GLASS_EDGE)
	box.border_width_bottom = 3
	margins(box,9,2)
	cap.add_theme_stylebox_override("panel",box)
	var text = label(cap,key,15,760,INK if light else ON_GLASS)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.custom_minimum_size = Vector2(30,0)
	return cap

# A row of [key] description pairs, e.g. [["W","S","전후진"],["Shift","부스트"]].
static func key_row(parent: Node, groups: Array, light = false, size = 15) -> HBoxContainer:
	var row = HBoxContainer.new(); parent.add_child(row)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",6)
	for i in range(groups.size()):
		var group: Array = groups[i]
		if i>0:
			var gap = Control.new(); gap.custom_minimum_size.x = 14; row.add_child(gap)
		for k in range(group.size()-1): keycap(row,str(group[k]),light)
		label(row,str(group[-1]),size,500,INK if light else ON_GLASS)
	return row
