class_name ChaosSave
extends RefCounted

var directory = "user://"
var error = ""
var data = fresh()

static func settings_defaults() -> Dictionary:
	return {"sensitivity":.0022,"hold_grip":false,"fov":70.0,"shake":true,"volume":.65,"subtitle_size":24,"quality":1,"keys":{}}

static func fresh() -> Dictionary:
	return {"version":ChaosTuning.SAVE_VERSION,"unlocked":1,"completed":[],"records":{},"resume":{},"settings":settings_defaults()}

static func number(value, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value>=minimum and value<=maximum

static func valid(candidate) -> bool:
	if not candidate is Dictionary: return false
	for key in fresh():
		if not candidate.has(key): return false
	if candidate.version!=ChaosTuning.SAVE_VERSION or not number(candidate.unlocked,1,6) or int(candidate.unlocked)!=candidate.unlocked: return false
	if not candidate.completed is Array or not candidate.records is Dictionary or not candidate.resume is Dictionary or not candidate.settings is Dictionary: return false
	for item in candidate.completed:
		if not number(item,1,6) or int(item)!=item: return false
	var s: Dictionary = candidate.settings
	for key in settings_defaults():
		if not s.has(key): return false
	if not number(s.sensitivity,.0005,.008) or not number(s.fov,60,90) or not number(s.volume,0,1): return false
	if not number(s.subtitle_size,18,36) or not number(s.quality,0,2): return false
	if not s.hold_grip is bool or not s.shake is bool or not s.keys is Dictionary: return false
	for key in s.keys:
		if key not in ["forward","back","left","right","sprint","brace","interact","reset"] or not number(s.keys[key],1,4194400): return false
	var resume: Dictionary = candidate.resume
	if not resume.is_empty():
		for key in ["mission","checkpoint","coffee","remaining","elapsed","falls","damage","retries","refilled"]:
			if not resume.has(key): return false
		if not number(resume.mission,1,candidate.unlocked) or int(resume.mission)!=resume.mission: return false
		var missions = ChaosMissions.load_all()
		if not number(resume.checkpoint,0,missions[int(resume.mission)-1].route.size()-1) or int(resume.checkpoint)!=resume.checkpoint: return false
		if not number(resume.coffee,0,100) or not number(resume.remaining,-1,90) or not number(resume.elapsed,0,1e8) or not resume.refilled is bool: return false
		for key in ["falls","damage","retries"]:
			if not number(resume[key],0,1e12): return false
	for key in candidate.records:
		if key not in ["1","2","3","4","5","6"]: return false
		var record = candidate.records[key]
		if not record is Dictionary or not record.has_all(["time","medals"]) or not number(record.time,0,1e8): return false
		if not record.medals is Array or record.medals.size()!=3: return false
		for medal in record.medals:
			if not medal is bool: return false
	return true

func load_progress() -> bool:
	var path = directory.path_join("progress.json")
	if not FileAccess.file_exists(path): return true
	var parsed = read_json(path)
	if valid(parsed): data = parsed; return true
	var backup = read_json(directory.path_join("progress.backup.json")) if FileAccess.file_exists(directory.path_join("progress.backup.json")) else null
	if valid(backup):
		data = backup; error = "이전 정상 저장을 불러왔습니다."; return true
	error = "저장 파일을 읽지 못했습니다. 원본을 보존하고 새 진행을 사용합니다."
	DirAccess.copy_absolute(path,directory.path_join("progress.invalid.%d.json" % Time.get_unix_time_from_system()))
	return false

func write() -> bool:
	if not valid(data): error = "진행 상태가 유효하지 않아 저장하지 못했습니다."; return false
	DirAccess.make_dir_recursive_absolute(directory)
	var path = directory.path_join("progress.json")
	var temp = directory.path_join("progress.tmp")
	var file = FileAccess.open(temp,FileAccess.WRITE)
	if file==null: error = "저장 파일을 열 수 없습니다."; return false
	file.store_string(JSON.stringify(data)); file.flush()
	var code = file.get_error(); file.close()
	if code!=OK: error = "저장 공간을 확인해 주세요."; return false
	if FileAccess.file_exists(path):
		var old = read_json(path)
		if valid(old):
			if DirAccess.copy_absolute(path,directory.path_join("progress.backup.json"))!=OK:
				error = "이전 저장을 백업하지 못했습니다."; return false
	if DirAccess.rename_absolute(temp,path)!=OK: error = "진행 파일 교체에 실패했습니다."; return false
	error = ""; return true

func complete(run: ChaosMissionRun):
	var id = int(run.mission.id)
	if id not in data.completed: data.completed.append(id)
	data.unlocked = mini(6,maxi(int(data.unlocked),id+1))
	var key = str(id)
	var medals = run.medals()
	if data.records.has(key):
		for i in range(3): medals[i] = medals[i] or data.records[key].medals[i]
	data.records[key] = {"time":minf(run.elapsed,float(data.records.get(key,{}).get("time",1e8))),"medals":medals}
	data.resume = {}


static func read_json(path: String):
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK: return null
	return parser.data
