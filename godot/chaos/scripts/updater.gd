class_name ChaosUpdater
extends Node

signal changed
signal request_started(url: String)
signal installer_ready
var game
var http: HTTPRequest
var state = "idle"
var status = "업데이트를 확인할 수 있습니다."
var latest: Dictionary = {}
var expected_hash = ""
var download_path = ""
var current_version = ""
var installed = false
var helper_pid = -1
var helper_ready_path = ""
var qa = false
var local_notice = ""
var storage_directory = "user://updates"

func setup(owner):
	game = owner; qa = game.qa
	process_mode = Node.PROCESS_MODE_ALWAYS
	current_version = str(ProjectSettings.get_setting("application/config/version"))
	installed = ChaosUpdatePolicy.installed(OS.get_executable_path().get_base_dir())
	http = HTTPRequest.new(); add_child(http)
	http.timeout = 25
	http.request_completed.connect(_completed)
	if not qa and FileAccess.file_exists("user://updates/status.json"):
		var report = ChaosSave.read_json("user://updates/status.json")
		if report is Dictionary and report.get("state","")=="rollback":
			local_notice = "업데이트에 실패해 이전 버전으로 복구했습니다. 설정에서 다시 확인할 수 있습니다."
			status = local_notice
	if OS.get_name()=="Windows" and not qa and game.store.data.settings.get("auto_updates",true):
		get_tree().create_timer(2,true).timeout.connect(check_for_updates)

func busy() -> bool: return state in ["checking","checksum","downloading","ready","starting","installing"]

func check_for_updates():
	if busy(): return
	state = "checking"; status = "새 버전을 확인하고 있습니다."; changed.emit()
	_request(ChaosUpdatePolicy.RELEASES_URL,1024*1024)

func _request(url: String, limit: int):
	http.body_size_limit = limit; http.download_file = ""; http.timeout = 25
	var error = _send(url,["Accept: application/vnd.github+json","User-Agent: OfficeChairChaos/"+current_version])
	if error!=OK: _fail("업데이트 서버에 연결하지 못했습니다.")

func begin_install():
	if latest.is_empty() or busy(): return
	if OS.get_name()!="Windows" and not qa: _fail("설치형 업데이트는 Windows에서 사용할 수 있습니다."); return
	state = "checksum"; status = "설치 파일을 준비하고 있습니다."; changed.emit()
	_request(latest.checksum_url,65536)

func cancel_download():
	if state not in ["checking","checksum","downloading","ready","starting"]: return
	if state=="starting" and helper_pid>0 and OS.is_process_running(helper_pid): OS.kill(helper_pid)
	http.cancel_request()
	_remove_partial()
	state = "available" if not latest.is_empty() else "idle"
	status = "취소했습니다. 현재 버전을 계속 사용할 수 있습니다."; changed.emit()

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
	if state not in ["checking","checksum","downloading"]: return
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		_fail("업데이트를 받지 못했습니다. 연결을 확인하고 다시 시도해 주세요."); return
	match state:
		"checking":
			var parser = JSON.new()
			if parser.parse(body.get_string_from_utf8())!=OK or not parser.data is Array:
				_fail("업데이트 응답을 읽지 못했습니다."); return
			latest = ChaosUpdatePolicy.select_release(parser.data,current_version)
			state = "available" if not latest.is_empty() else "current"
			status = "새 버전 %s이 있습니다." % latest.version if not latest.is_empty() else "최신 버전입니다."
			changed.emit()
		"checksum":
			expected_hash = ChaosUpdatePolicy.checksum(body.get_string_from_utf8())
			if expected_hash.is_empty(): _fail("설치 파일의 확인 정보를 읽지 못했습니다."); return
			DirAccess.make_dir_recursive_absolute(storage_directory)
			download_path = ProjectSettings.globalize_path(storage_directory.path_join("setup-"+str(latest.version)+".exe"))
			http.download_file = download_path+".part"; http.timeout = 600; http.body_size_limit = ChaosUpdatePolicy.MAX_DOWNLOAD
			state = "downloading"; status = "설치 파일을 다운로드하고 있습니다."; changed.emit()
			if _send(latest.installer_url,["User-Agent: OfficeChairChaos/"+current_version])!=OK: _fail("설치 파일을 다운로드하지 못했습니다.")
		"downloading":
			var partial = download_path+".part"
			if not FileAccess.file_exists(partial) or FileAccess.get_sha256(partial).to_lower()!=expected_hash:
				_fail("설치 파일 확인에 실패했습니다. 현재 버전은 유지됩니다."); return
			if FileAccess.file_exists(download_path): DirAccess.remove_absolute(download_path)
			if DirAccess.rename_absolute(partial,download_path)!=OK: _fail("설치 파일을 저장하지 못했습니다."); return
			_prepare_install()

func _prepare_install():
	if not game.persist_checkpoint(): _fail("진행을 저장하지 못해 설치를 중단했습니다."); return
	state = "ready"; status = "설치 파일을 확인했습니다."; changed.emit(); installer_ready.emit()

func launch_installer():
	if OS.get_name()!="Windows" or state!="ready": return
	if expected_hash.is_empty() or FileAccess.get_sha256(download_path).to_lower()!=expected_hash:
		_fail("설치 파일이 변경되어 설치를 중단했습니다."); return
	var executable = download_path
	var arguments = PackedStringArray()
	if installed:
		var root = ProjectSettings.globalize_path("user://updates")
		var helper = root.path_join("update-helper.ps1")
		var script = FileAccess.open(helper,FileAccess.WRITE)
		if script==null: _fail("업데이트 도구를 준비하지 못했습니다."); return
		script.store_string(FileAccess.get_file_as_string("res://chaos/resources/update_helper.ps1")); script.flush()
		var script_error = script.get_error(); script.close()
		if script_error!=OK: _fail("업데이트 도구를 저장하지 못했습니다."); return
		var nonce = str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
		helper_ready_path = root.path_join("helper-ready-"+nonce+".json")
		var request_path = root.path_join("request-"+nonce+".json")
		var request_file = FileAccess.open(request_path,FileAccess.WRITE)
		if request_file==null: _fail("업데이트 요청을 저장하지 못했습니다."); return
		request_file.store_string(JSON.stringify({"product":ChaosUpdatePolicy.PRODUCT,"installer":download_path,"install_dir":OS.get_executable_path().get_base_dir(),"sha256":expected_hash,"version":latest.version,"parent_pid":OS.get_process_id(),"ready_file":helper_ready_path})); request_file.flush()
		var request_error = request_file.get_error(); request_file.close()
		if request_error!=OK: _fail("업데이트 요청을 저장하지 못했습니다."); return
		executable = OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		arguments = PackedStringArray(["-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",helper,"-RequestPath",request_path])
	helper_pid = OS.create_process(executable,arguments)
	if helper_pid<0: _fail("설치 프로그램을 시작하지 못했습니다."); return
	if installed:
		state = "starting"; status = "업데이트 도구를 준비하고 있습니다."; changed.emit()
		_wait_for_helper()
	else:
		state = "installing"; changed.emit(); game.get_tree().quit()

func progress() -> float:
	if state!="downloading" or latest.is_empty(): return 0
	return clampf(float(http.get_downloaded_bytes())/maxf(1,float(latest.size)),0,1)

func _remove_partial():
	if not download_path.is_empty() and FileAccess.file_exists(download_path+".part"): DirAccess.remove_absolute(download_path+".part")

func _fail(message: String):
	_remove_partial(); state = "error"; status = message; http.timeout = 25; changed.emit()

func write_health():
	var args = OS.get_cmdline_user_args()
	if "--update-health-file" not in args or OS.get_name()!="Windows" or not installed: return
	var index = args.find("--update-health-file")
	if index+1>=args.size(): return
	var path = args[index+1].replace("\\","/").simplify_path()
	var root = ProjectSettings.globalize_path("user://updates").replace("\\","/").simplify_path()
	var name = path.get_file()
	if path.get_base_dir().to_lower()!=root.to_lower() or not name.begins_with("health-") or not name.ends_with(".json"): return
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"product":ChaosUpdatePolicy.PRODUCT,"version":current_version})); file.flush(); file.close()
		DirAccess.rename_absolute(path+".tmp",path)

func _send(url: String, headers: PackedStringArray) -> Error:
	request_started.emit(url)
	if qa: return OK
	return http.request(url,headers)

func _wait_for_helper():
	for i in range(100):
		if state!="starting": return
		if FileAccess.file_exists(helper_ready_path):
			var report = ChaosSave.read_json(helper_ready_path)
			if report is Dictionary and report.get("product","")==ChaosUpdatePolicy.PRODUCT:
				DirAccess.remove_absolute(helper_ready_path)
				state = "installing"; status = "저장했습니다. 설치 후 게임을 다시 시작합니다."; changed.emit()
				game.get_tree().quit(); return
		if not OS.is_process_running(helper_pid): break
		await get_tree().create_timer(.1,true).timeout
	if helper_pid>0 and OS.is_process_running(helper_pid): OS.kill(helper_pid)
	_fail("업데이트 도구를 시작하지 못했습니다. 현재 버전을 계속 사용할 수 있습니다.")
