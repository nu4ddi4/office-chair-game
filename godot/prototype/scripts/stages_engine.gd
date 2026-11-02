class_name TerminalStagesEngine
extends InvestigationEngine

const COUNT = 1
const CAMPAIGN_VERSION = 2

static func fresh_print() -> Dictionary:
	return {"job":"none","stacks":0,"document":"none","braked":false,"cart":false,"seen":false,"tail":false}

func create_state() -> Dictionary:
	var s = super.create_state()
	s.stage = {"version":CAMPAIGN_VERSION,"index":1,"unlocked":1,"phase":"playing","cleared":[],"mistakes":0,"blasts":0,"attempt":1,"entered":1,"print":fresh_print()}
	return s

func definition(_s: Dictionary) -> Dictionary: return content.stages[0]

func parse(command: String, _device: String, _state: Dictionary) -> Dictionary:
	return {"type":"stage.command","payload":{"command":command}}

static func ready_to_finish(a: Dictionary) -> bool:
	return a.phase == "playing" and a.print.document == "delivered" and a.print.job == "cancelled"

func step(original: Dictionary, action: Dictionary) -> Dictionary:
	var payload = action.get("payload",{})
	if not payload is Dictionary: return _result(original,"INVALID_ACTION")
	var s = original.duplicate(true)
	var a = s.stage
	var p = a.print
	var kind = action.get("type","")
	if kind in ["stage.retry","stage.select"]:
		if kind == "stage.select" and payload.get("index") != 1: return _result(original,"INVALID_ACTION")
		a.print = fresh_print()
		a.phase = "playing"
		a.attempt = mini(1000000,int(a.attempt)+1)
		return changed(s,"STAGE_RETRY","PR-01 READY")
	if kind == "stage.next":
		if a.phase != "clear": return _result(original,"STAGE_BUSY")
		a.phase = "complete"
		return changed(s,"STAGES_COMPLETE","REQUEST R41 DELIVERED")
	if a.phase != "playing": return _result(original,"STAGE_BUSY","terminal: session closed")
	if kind == "print.finish":
		if not ready_to_finish(a): return _result(original,"STAGE_BUSY")
		a.phase = "clear"
		a.cleared = [1]
		return changed(s,"STAGE_CLEAR","REQUEST R41 DELIVERED")
	if kind == "print.event":
		match payload.get("event",""):
			"scene":
				if p.job != "running" or p.seen: return _result(original,"STAGE_BUSY")
				p.seen = true
			"stack":
				if p.job != "running" or p.stacks >= 3: return _result(original,"STAGE_BUSY")
				p.stacks += 1
			"brake": p.braked = not p.braked
			"cart": p.cart = true
			"pause":
				if p.job not in ["running","paused"]: return _result(original,"STAGE_BUSY")
				p.job = "paused" if p.job == "running" else "running"
			"tail":
				if p.job not in ["paused","cancelled"] or p.tail: return _result(original,"STAGE_BUSY")
				p.tail = true
			"take":
				if p.document != "tray" or payload.get("reachable") != true: return _result(original,"INVALID_ACTION")
				p.document = "held"
			"drop":
				if p.document != "held": return _result(original,"STAGE_BUSY")
				p.document = "tray"
			"deliver":
				if payload.get("reachable") != true or p.document != "held": return _result(original,"INVALID_ACTION")
				p.document = "delivered"
				p.job = "cancelled"
			_: return _result(original,"INVALID_ACTION")
		return changed(s,"PRINT_CHANGED","")
	if kind != "stage.command": return _result(original,"INVALID_ACTION")
	var raw = payload.get("command","")
	if not raw is String or raw.length() > 200: return mistake(s,"command: invalid input")
	var command = " ".join(raw.strip_edges().split(" ",false)).to_lower()
	if command.is_empty(): return _result(original,"STAGE_EMPTY","")
	var words = command.split(" ")
	var stage = definition(s)
	match command:
		"help": return _result(original,"STAGE_OUTPUT",stage.help+"\nclear  history  exit")
		"ls": return _result(original,"STAGE_OUTPUT","\n".join(stage.files.keys()))
		"pwd": return _result(original,"STAGE_OUTPUT","/office/print")
		"status": return _result(original,"STAGE_OUTPUT","PR-01 %s\nTRAY ACK %d\nJOBS %d" % ["READY" if p.job == "none" else p.job.to_upper(),1 if p.document in ["held","delivered"] else 0,1 if p.job in ["running","paused"] else 0])
		"queue": return _result(original,"STAGE_OUTPUT","QUEUE EMPTY" if p.job in ["none","cancelled"] else "JOB  FILE           STATE\nR41  clockout.form  "+p.job.to_upper())
	if words[0] == "cat":
		if words.size() != 2: return mistake(s,"usage: cat <file>")
		if not stage.files.has(words[1]): return mistake(s,"cat: %s: no such file" % words[1])
		return _result(original,"STAGE_OUTPUT",stage.files[words[1]])
	if words[0] == "print":
		if words.size() != 2: return mistake(s,"usage: print <file>")
		if words[1] != "clockout.form": return mistake(s,"print: unsupported document type")
		if p.job != "none": return _result(original,"STAGE_OUTPUT","JOB R41 ALREADY ACCEPTED")
		p.job = "running"
		p.document = "tray"
		return changed(s,"PRINT_SUBMITTED","JOB R41 ACCEPTED\nFILE clockout.form\nCOPIES 1")
	if words[0] in ["pause","resume","cancel"]:
		if words.size() != 2: return mistake(s,"usage: %s <job>" % words[0])
		if words[1] != "r41" or p.job == "none": return mistake(s,"job: not found")
		if p.job == "cancelled": return _result(original,"STAGE_OUTPUT","R41 CANCELLED")
		p.job = "paused" if words[0] == "pause" else "running" if words[0] == "resume" else "cancelled"
		return changed(s,"PRINT_CHANGED","R41 "+p.job.to_upper())
	return mistake(s,"%s: command not found" % words[0])

func changed(s: Dictionary, code: String, output: String) -> Dictionary:
	s.revision += 1
	return _result(s,code,output)

func mistake(s: Dictionary, output: String) -> Dictionary:
	s.stage.mistakes = mini(1000000,int(s.stage.mistakes)+1)
	return changed(s,"STAGE_PRACTICE",output)

static func valid_progress(a) -> bool:
	if not a is Dictionary: return false
	if a.get("version") == 1: return valid_legacy(a)
	if a.size() != 10 or a.get("version") != CAMPAIGN_VERSION: return false
	for key in ["index","unlocked","entered"]:
		if a.get(key) != 1: return false
	if a.get("phase") not in ["playing","clear","complete"] or not a.get("cleared") is Array or a.cleared.size() > 1: return false
	if a.cleared.size() == 1 and not InvestigationSaveCodec.whole(a.cleared[0],1,1): return false
	for key in ["mistakes","blasts","attempt"]:
		if not InvestigationSaveCodec.whole(a.get(key),1 if key == "attempt" else 0,1000000): return false
	if a.blasts != 0: return false
	var p = a.get("print")
	if not p is Dictionary or p.size() != 7: return false
	if p.get("job") not in ["none","running","paused","cancelled"] or p.get("document") not in ["none","tray","held","delivered"]: return false
	if not InvestigationSaveCodec.whole(p.get("stacks"),0,3): return false
	for key in ["braked","cart","seen","tail"]:
		if not p.get(key) is bool: return false
	if (p.job == "none") != (p.document == "none"): return false
	if p.job == "none" and (p.stacks != 0 or p.seen or p.tail): return false
	if p.stacks > 0 and not p.seen: return false
	if p.document == "delivered" and p.job != "cancelled": return false
	if a.phase in ["clear","complete"] and (a.cleared.size() != 1 or p.document != "delivered"): return false
	return true

static func valid_legacy(a: Dictionary) -> bool:
	# Read-only compatibility: retired six-stage saves may be preserved, never run as this campaign.
	if a.keys().size() not in [8,9]: return false
	for key in a:
		if key not in ["version","index","unlocked","phase","cleared","mistakes","blasts","attempt","entered"]: return false
	if not InvestigationSaveCodec.whole(a.get("index"),1,6) or not InvestigationSaveCodec.whole(a.get("unlocked"),1,6) or a.index > a.unlocked: return false
	if not a.get("cleared") is Array or a.cleared.size() > 6: return false
	if a.has("entered") and (not InvestigationSaveCodec.whole(a.entered,1,6) or a.entered < maxi(int(a.index),a.cleared.size()) or a.entered > a.unlocked): return false
	if a.get("phase") not in ["playing","clear","exploded","complete"]: return false
	for key in ["mistakes","blasts"]:
		if not InvestigationSaveCodec.whole(a.get(key),0,1000000): return false
	if not InvestigationSaveCodec.whole(a.get("attempt"),1,1000000) or a.blasts > a.mistakes: return false
	for i in range(a.cleared.size()):
		if a.cleared[i] != i+1: return false
	if a.unlocked != mini(6,a.cleared.size()+1): return false
	if a.phase == "exploded" and (a.index < 3 or a.blasts == 0): return false
	if a.phase == "clear" and a.index not in a.cleared: return false
	if a.phase == "complete" and (a.index != 6 or a.cleared.size() != 6): return false
	return true
