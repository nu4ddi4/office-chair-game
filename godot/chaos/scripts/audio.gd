class_name ChaosAudio
extends Node

# All sound is synthesized at start-up (no audio files): filtered noise for
# rolling casters, impacts, coffee and the office room tone; inharmonic partials
# for ceramic and plastic breaks; a small formant voice for the boss's
# mumbled lines. Several variations per sound avoid machine-gun repetition.

const RATE = 22050
const VOWELS = [[730,1090],[530,1840],[270,2290],[570,840],[300,870],[660,1700]]
var voices: Array[AudioStreamPlayer] = []
var volume = .65
var last_speech = 0.0
var rolling: AudioStreamPlayer
var sloshing: AudioStreamPlayer
var ambience: AudioStreamPlayer
var speech: AudioStreamPlayer
var silent = false
var bank: Dictionary = {}
var rng = RandomNumberGenerator.new()
var spill_cooldown = 0.0

func _ready():
	var args = OS.get_cmdline_args()
	var driver = args.find("--audio-driver")
	var user_args = OS.get_cmdline_user_args()
	silent = ("--chaos-test" in user_args and "--audible-qa" not in user_args) or (driver>=0 and driver+1<args.size() and args[driver+1]=="Dummy")
	rng.seed = 4711
	for i in range(6):
		var player = AudioStreamPlayer.new()
		add_child(player); voices.append(player)
	rolling = AudioStreamPlayer.new(); add_child(rolling)
	sloshing = AudioStreamPlayer.new(); add_child(sloshing)
	speech = AudioStreamPlayer.new(); add_child(speech)
	ambience = AudioStreamPlayer.new(); add_child(ambience)
	ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	if silent: return
	bank = ChaosAudio.synthesize()
	rolling.stream = bank.rolling[0]
	sloshing.stream = bank.slosh[0]
	ambience.stream = bank.ambience[0]
	ambience.volume_db = linear_to_db(maxf(.001,volume*.22))
	ambience.play()

func _process(delta):
	spill_cooldown = maxf(0,spill_cooldown-delta)
	if not silent and is_instance_valid(ambience): ambience.volume_db = linear_to_db(maxf(.001,volume*.22))

# ---------------------------------------------------------------- playback

func play(kind: String, force = 1.0):
	if silent or volume<=0: return
	if kind=="speech": speak("음음 음"); return
	var choices: Array = bank.get(kind,bank.get("impact",[]))
	if choices.is_empty(): return
	var voice: AudioStreamPlayer = voices[0]
	for candidate in voices:
		if not candidate.playing: voice = candidate; break
	voice.stream = choices[rng.randi()%choices.size()]
	voice.pitch_scale = rng.randf_range(.92,1.08)*(1.15-.25*clampf(force,0,1) if kind=="impact" else 1.0)
	voice.volume_db = linear_to_db(maxf(.001,volume*clampf(force,.1,1)))
	voice.play()

func spill(amount: float):
	if spill_cooldown>0: return
	spill_cooldown = .35
	play("spill",clampf(.4+amount*.3,.4,1))

# A short mumbled line, one syllable per couple of characters.
func speak(text: String, pitch = 1.0):
	if silent or volume<=0: return
	var letters = text.replace(" ","").length()
	var count = clampi(int(letters/2.2),2,12)
	speech.stream = _wav(ChaosAudio.babble(count,115.0*pitch,text.ends_with("?"),rng.randi()))
	speech.volume_db = linear_to_db(maxf(.001,volume*.75))
	speech.play()

func update_rolling(speed: float):
	if silent: return
	if speed>.15 and volume>0:
		if not rolling.playing: rolling.play()
		rolling.volume_db = linear_to_db(maxf(.001,minf(speed*.09,.42)*volume))
		rolling.pitch_scale = .7+minf(speed,6)*.16
	else: rolling.stop()

# The swish follows how fast the coffee surface is moving.
func update_slosh(surface_speed: float, fullness: float):
	if silent: return
	var level = clampf(surface_speed*.12+maxf(0,fullness-.4)*.35,0,.8)
	if level>.03 and volume>0:
		if not sloshing.playing: sloshing.play()
		sloshing.volume_db = linear_to_db(maxf(.001,level*volume))
		sloshing.pitch_scale = .85+clampf(fullness,0,1)*.4
	else: sloshing.stop()

func _exit_tree():
	for player in voices+[rolling,sloshing,speech,ambience]:
		if is_instance_valid(player): player.stop(); player.stream = null

# ---------------------------------------------------------------- synthesis

static func synthesize() -> Dictionary:
	var r = RandomNumberGenerator.new(); r.seed = 20261111
	var out = {}
	out.impact = []; out.grip = []; out.spill = []; out.shatter = []; out.clatter = []
	for v in range(4): out.impact.append(_wav(_impact(r,v)))
	for v in range(3): out.grip.append(_wav(_grip(r)))
	for v in range(3): out.spill.append(_wav(_spill(r)))
	for v in range(3): out.shatter.append(_wav(_ceramic(r)))
	for v in range(3): out.clatter.append(_wav(_plastic(r)))
	out.success = [_wav(_chime())]
	out.failure = [_wav(_trombone())]
	out.rolling = [_wav(_rolling(r),true)]
	out.slosh = [_wav(_slosh(r),true)]
	out.ambience = [_wav(_room(r),true)]
	return out

static func _wav(samples: PackedFloat32Array, loop = false) -> AudioStreamWAV:
	var buffer = PackedByteArray(); buffer.resize(samples.size()*2)
	for i in range(samples.size()): buffer.encode_s16(i*2,int(clampf(samples[i],-1,1)*32000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = buffer
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream

static func _noise(r: RandomNumberGenerator, n: int) -> PackedFloat32Array:
	var out = PackedFloat32Array(); out.resize(n)
	for i in range(n): out[i] = r.randf_range(-1,1)
	return out

static func _lowpass(x: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a = 1.0-exp(-TAU*cutoff/RATE); var y = 0.0
	var out = PackedFloat32Array(); out.resize(x.size())
	for i in range(x.size()):
		y += a*(x[i]-y); out[i] = y
	return out

static func _highpass(x: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var low = _lowpass(x,cutoff)
	var out = PackedFloat32Array(); out.resize(x.size())
	for i in range(x.size()): out[i] = x[i]-low[i]
	return out

static func _bandpass(x: PackedFloat32Array, center: float, q: float) -> PackedFloat32Array:
	var w = TAU*center/RATE; var alpha = sin(w)/(2*q)
	var b0 = alpha; var a0 = 1+alpha; var a1 = -2*cos(w); var a2 = 1-alpha
	var x1 = 0.0; var x2 = 0.0; var y1 = 0.0; var y2 = 0.0
	var out = PackedFloat32Array(); out.resize(x.size())
	for i in range(x.size()):
		var y = (b0*x[i]-b0*x2-a1*y1-a2*y2)/a0
		x2 = x1; x1 = x[i]; y2 = y1; y1 = y; out[i] = y
	return out

static func _normalize(x: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top = .0001
	for v in x: top = maxf(top,absf(v))
	for i in range(x.size()): x[i] = x[i]/top*peak
	return x

static func _impact(r: RandomNumberGenerator, variant: int) -> PackedFloat32Array:
	var n = int(RATE*.45)
	var body = _lowpass(_noise(r,n),700+variant*260)
	var click = _highpass(_noise(r,n),2500)
	var out = PackedFloat32Array(); out.resize(n)
	var phase = 0.0
	for i in range(n):
		var t = float(i)/RATE
		phase += TAU*(48+55*exp(-t*28))/RATE
		out[i] = body[i]*exp(-t*16)*2.2+sin(phase)*exp(-t*9)*.9+click[i]*exp(-t*160)*.5
	return _normalize(out,.9)

static func _grip(r: RandomNumberGenerator) -> PackedFloat32Array:
	var n = int(RATE*.09)
	var tick = _bandpass(_noise(r,n),r.randf_range(2000,2800),2.0)
	var out = PackedFloat32Array(); out.resize(n)
	var f = r.randf_range(950,1250)
	for i in range(n):
		var t = float(i)/RATE
		out[i] = tick[i]*exp(-t*70)*3+sin(TAU*f*t)*exp(-t*55)*.4
	return _normalize(out,.6)

static func _spill(r: RandomNumberGenerator) -> PackedFloat32Array:
	var n = int(RATE*.55)
	var wash = _bandpass(_noise(r,n),1500,.9)
	var out = PackedFloat32Array(); out.resize(n)
	for i in range(n):
		var t = float(i)/RATE
		out[i] = wash[i]*sin(PI*minf(t/.06,1))*exp(-t*6)*2.5
	for d in range(7):
		var start = int(r.randf_range(.05,.45)*RATE); var f = r.randf_range(1100,2600)
		for i in range(start,mini(start+int(RATE*.05),n)):
			var t = float(i-start)/RATE
			out[i] += sin(TAU*(f+f*1.8*t)*t)*exp(-t*90)*.35
	return _normalize(out,.7)

static func _ceramic(r: RandomNumberGenerator) -> PackedFloat32Array:
	var n = int(RATE*.7)
	var crackle = _highpass(_noise(r,n),3000)
	var partials = [2350.0,3630.0,5110.0,6820.0]
	var out = PackedFloat32Array(); out.resize(n)
	var detune = r.randf_range(.92,1.08)
	for i in range(n):
		var t = float(i)/RATE
		var ring = 0.0
		for k in range(partials.size()): ring += sin(TAU*partials[k]*detune*t)*exp(-t*(8+k*4))/(1+k*.6)
		out[i] = ring*.5+crackle[i]*exp(-t*22)*.8
	for s in range(4):
		var start = int(r.randf_range(.04,.3)*RATE)
		for i in range(start,mini(start+int(RATE*.03),n)): out[i] += crackle[i]*exp(-float(i-start)/RATE*120)
	return _normalize(out,.75)

static func _plastic(r: RandomNumberGenerator) -> PackedFloat32Array:
	var n = int(RATE*.45)
	var thud = _bandpass(_noise(r,n),r.randf_range(700,1100),1.6)
	var out = PackedFloat32Array(); out.resize(n)
	for b in range(3):
		var start = int([0.0,.12,.21][b]*RATE*r.randf_range(.9,1.2))
		for i in range(start,n):
			var t = float(i-start)/RATE
			out[i] += thud[i]*exp(-t*40)*(1.0-b*.3)
	return _normalize(out,.6)

static func _chime() -> PackedFloat32Array:
	var n = int(RATE*1.3)
	var out = PackedFloat32Array(); out.resize(n)
	var notes = [784.0,987.8,1174.7,1568.0]
	for k in range(notes.size()):
		var start = int(k*.09*RATE)
		for i in range(start,n):
			var t = float(i-start)/RATE
			out[i] += (sin(TAU*notes[k]*t)+sin(TAU*notes[k]*2.76*t)*.25+sin(TAU*notes[k]*5.4*t)*.08)*exp(-t*3.2)*.3
	return _normalize(out,.7)

static func _trombone() -> PackedFloat32Array:
	var n = int(RATE*1.1)
	var out = PackedFloat32Array(); out.resize(n)
	var phase = 0.0
	for i in range(n):
		var t = float(i)/RATE
		var f = (330.0-80.0*minf(t/.35,1)) if t<.45 else (233.0-60.0*minf((t-.45)/.6,1))
		phase += TAU*f/RATE
		var tone = 0.0
		for k in range(1,7): tone += sin(phase*k)/k
		var env = minf(t/.03,1)*(1.0 if t<.42 else .8)*(1.0 if t<.45 else exp(-(t-.45)*2.2))
		if t>.4 and t<.45: env *= (.45-t)/.05
		out[i] = tone*env
	return _normalize(_lowpass(out,1400),.6)

# Caster rumble with a tick per floor seam; pitch_scale follows speed.
static func _rolling(r: RandomNumberGenerator) -> PackedFloat32Array:
	var n = RATE
	var brown = PackedFloat32Array(); brown.resize(n)
	var w = _noise(r,n); var y = 0.0
	for i in range(n):
		y = y*.995+w[i]*.06; brown[i] = y
	var rumble = _lowpass(brown,240)
	var ticks = _bandpass(_noise(r,n),1300,3.0)
	var out = PackedFloat32Array(); out.resize(n)
	for i in range(n):
		var beat = fmod(float(i)/RATE,.125)
		out[i] = rumble[i]*1.6+ticks[i]*exp(-beat*90)*.9
	# Fade the loop seam.
	for i in range(400):
		var g = float(i)/400; out[i] *= g; out[n-1-i] *= g
	return _normalize(out,.8)

static func _slosh(r: RandomNumberGenerator) -> PackedFloat32Array:
	var n = int(RATE*1.2)
	var wash = _bandpass(_lowpass(_noise(r,n),1200),520,.7)
	var out = PackedFloat32Array(); out.resize(n)
	for i in range(n):
		var t = float(i)/RATE
		out[i] = wash[i]*(.55+.45*sin(TAU*1.6667*t))
	for i in range(300):
		var g = float(i)/300; out[i] *= g; out[n-1-i] *= g
	return _normalize(out,.8)

# Office room tone: air-conditioning hush and distant keyboard bursts.
static func _room(r: RandomNumberGenerator) -> PackedFloat32Array:
	var n = RATE*8
	var hush = _lowpass(_noise(r,n),320)
	var air = _highpass(_lowpass(_noise(r,n),3500),900)
	var out = PackedFloat32Array(); out.resize(n)
	for i in range(n): out[i] = hush[i]*1.4+air[i]*.12
	var keys = _bandpass(_noise(r,n),3200,2.5)
	for burst in range(4):
		var start = r.randf_range(.6,6.6)
		for k in range(r.randi_range(6,12)):
			var at = int((start+k*r.randf_range(.07,.16))*RATE)
			for i in range(at,mini(at+int(RATE*.012),n)): out[i] += keys[i]*exp(-float(i-at)/RATE*400)*.5
	for i in range(2000):
		var g = float(i)/2000; out[i] *= g; out[n-1-i] *= g
	return _normalize(out,.5)

# Formant "mumble": a buzzy source through two vowel formants per syllable.
static func babble(count: int, pitch: float, question: bool, seed: int) -> PackedFloat32Array:
	var r = RandomNumberGenerator.new(); r.seed = seed
	var out = PackedFloat32Array()
	var phase = 0.0
	for s in range(count):
		var length = r.randf_range(.07,.12)
		var n = int(RATE*length)
		var vowel: Array = VOWELS[r.randi()%VOWELS.size()]
		var f0 = pitch*(1.0+.12*r.randf_range(-1,1))*(1.25 if question and s==count-1 else 1.0-.05*float(s)/count)
		var source = PackedFloat32Array(); source.resize(n)
		for i in range(n):
			phase += f0/RATE
			source[i] = 2.0*(phase-floor(phase))-1.0
		var a = _bandpass(source,vowel[0],5.0); var b = _bandpass(source,vowel[1],7.0)
		var onset = _highpass(_noise(r,n),2000)
		for i in range(n):
			var t = float(i)/RATE
			var env = minf(t/.012,1)*minf((length-t)/.03,1)
			out.append((a[i]*1.0+b[i]*.6)*env+onset[i]*exp(-t*220)*.25)
		for i in range(int(RATE*r.randf_range(.015,.04))): out.append(0.0)
	return _normalize(out,.6)
