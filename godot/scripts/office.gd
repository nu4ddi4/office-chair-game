extends Node3D

var player: LabPlayer
var world: LabWorld
var paused = false
var menu: Control
var shade: ColorRect
var resume_button: Button
var prompt: Label

func _ready():
	player = LabPlayer.new()
	player.name = "MapCamera"
	add_child(player)
	world = LabWorld.new()
	world.name = "Office"
	add_child(world)
	world.setup(player)
	_build_ui()
	set_paused(false)

func _build_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var help = Label.new()
	help.text = "WASD Move  |  Mouse Look  |  Space Jump  |  F Door  |  Esc Menu"
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	help.offset_left = 24
	help.offset_right = -24
	help.offset_top = 20
	help.offset_bottom = 70
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.add_theme_font_size_override("font_size",18)
	canvas.add_child(help)
	var crosshair = Label.new()
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -12
	crosshair.offset_top = -12
	crosshair.offset_right = 12
	crosshair.offset_bottom = 12
	canvas.add_child(crosshair)
	prompt = Label.new()
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -200
	prompt.offset_right = 200
	prompt.offset_top = -62
	prompt.offset_bottom = -30
	canvas.add_child(prompt)
	shade = ColorRect.new()
	shade.color = Color(0,0,0,.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(shade)
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_top = -120
	panel.offset_right = 180
	panel.offset_bottom = 120
	canvas.add_child(panel)
	menu = panel
	var margin = MarginContainer.new()
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	margin.add_child(column)
	var title = Label.new()
	title.text = "Office Map"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",24)
	column.add_child(title)
	resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.custom_minimum_size.y = 48
	resume_button.pressed.connect(func(): set_paused(false))
	column.add_child(resume_button)
	var quit = Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size.y = 48
	quit.pressed.connect(func(): get_tree().quit())
	column.add_child(quit)

func set_paused(value: bool):
	paused = value
	menu.visible = value
	shade.visible = value
	world.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	player.set_enabled(not value)
	if value: resume_button.grab_focus()
	else: resume_button.release_focus()

func _unhandled_key_input(event):
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		set_paused(not paused)
		get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and player != null and menu != null:
		set_paused(true)

func _process(_delta):
	prompt.text = player.target.get_interaction_prompt() if not paused and player.target != null else ""
