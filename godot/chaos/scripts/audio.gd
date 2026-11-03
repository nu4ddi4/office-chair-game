class_name ChaosAudio
extends Node

var voices: Array[AudioStreamPlayer] = []
var volume = .65
var last_speech = 0.0
var rolling: AudioStreamPlayer
var silent = false

func _ready():
	var args = OS.get_cmdline_args()
	var driver = args.find("--audio-driver")
	var user_args = OS.get_cmdline_user_args()
	silent = ("--chaos-test" in user_args and "--audible-qa" not in user_args) or (driver>=0 and driver+1<args.size() and args[driver+1]=="Dummy")
	for i in range(4):
		var player = AudioStreamPlayer.new()
		add_child(player); voices.append(player)
	rolling = AudioStreamPlayer.new()
	add_child(rolling)
	if not silent: rolling.stream = tone(65,.30,.16,true)

func tone(frequency: float, seconds: float, power = .25, loop = false) -> AudioStreamWAV:
	var rate = 22050
	var buffer = PackedByteArray()
	buffer.resize(int(rate*seconds)*2)
	for i in range(buffer.size()/2):
		var t = float(i)/rate
		var envelope = 1.0 if loop else sin(PI*t/seconds)*exp(-t*5)
		var sample = (sin(TAU*frequency*t)+sin(TAU*frequency*1.51*t)*.3)*power*envelope
		buffer.encode_s16(i*2,int(clampf(sample,-1,1)*32700))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = buffer
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = buffer.size()/2
	return stream

func play(kind: String, force = 1.0):
	if silent or volume<=0: return
	var voice: AudioStreamPlayer = voices[0]
	for candidate in voices:
		if not candidate.playing: voice = candidate; break
	var frequency = {"speech":135.0,"impact":82.0,"spill":410.0,"success":660.0,"failure":100.0,"grip":240.0}.get(kind,160.0)
	voice.stream = tone(frequency,.22 if kind!="success" else .55,.23)
	voice.volume_db = linear_to_db(maxf(.001,volume*clampf(force,.1,1)))
	voice.play()

func update_rolling(speed: float):
	if silent: return
	if speed>.15 and volume>0:
		if not rolling.playing: rolling.play()
		rolling.volume_db = linear_to_db(maxf(.001,minf(speed*.025,.12)*volume))
		rolling.pitch_scale = .8+minf(speed,5)*.12
	else: rolling.stop()


func _exit_tree():
	for voice in voices:
		voice.stop(); voice.stream = null
	if is_instance_valid(rolling): rolling.stop(); rolling.stream = null
