class_name InvestigationUpdates
extends Node

signal changed
const API = "https://api.github.com/repos/nu4ddi4/security-lab-game/releases?per_page=30"
const DOWNLOAD = "https://github.com/nu4ddi4/security-lab-game/releases/download/"
var installed = {}
var platform = OS.get_name()
var status = ""
var download_url = ""
var busy = false
var selected_channel = "stable"
var request_epoch = 0
var request: HTTPRequest

static func version_parts(value: String) -> Array:
	return NativeUpdatePolicy.version_parts(value)

static func newer(a: String, b: String) -> bool:
	return NativeUpdatePolicy.newer(a,b)

# Only newer releases from the selected channel are candidates.
static func select_release(releases: Array, metadata: Dictionary, target: String, channel = "stable") -> Dictionary:
	if channel not in ["stable","beta"]: return {}
	var best = {}
	var prefix = metadata.get("tag_prefix","SecurityLab-")
	for release in releases:
		if not release is Dictionary or release.get("draft",true) != false: continue
		if release.get("prerelease") != (channel=="beta"): continue
		var tag = release.get("tag_name","")
		if not tag is String or not tag.begins_with(prefix): continue
		var version = tag.trim_prefix(prefix)
		if not NativeUpdatePolicy.valid_version(version,channel): continue
		if not newer(version,metadata.get("version","")): continue
		if not best.is_empty() and not newer(version,best.version): continue
		best = {"version":version,"url":""}
		var extension = {"Android":".apk","Windows":".exe"}.get(target,"")
		if extension == "": continue
		var filenames = [tag+"-Portable.exe",tag+".exe"] if target == "Windows" else [tag+extension]
		var assets = release.get("assets",[])
		if not assets is Array: continue
		for filename in filenames:
			var expected_url = DOWNLOAD+tag.uri_encode()+"/"+filename.uri_encode()
			for asset in assets:
				if asset is Dictionary and asset.get("name") == filename and asset.get("state") == "uploaded" and typeof(asset.get("size",0)) in [TYPE_INT,TYPE_FLOAT] and asset.get("size",0) > 0 and asset.get("browser_download_url") == expected_url:
					best.url = expected_url
			if best.url != "": break
	return best

func _ready():
	var metadata = JSON.parse_string(FileAccess.get_file_as_string("res://prototype/version.json"))
	if metadata is Dictionary: installed = metadata
	status = "현재 %s · %s 채널" % [installed.get("version","개발"),"사전 릴리즈" if installed.get("prerelease",true) else "안정"]

func cancel_check():
	request_epoch += 1
	if is_instance_valid(request): request.cancel_request(); request.queue_free()
	busy = false
	download_url = ""

func check(channel = "stable"):
	cancel_check()
	selected_channel = channel
	busy = true
	status = "선택한 채널의 업데이트 확인 중…"
	changed.emit()
	request = HTTPRequest.new()
	request.timeout = 12
	request.body_size_limit = 1024*1024
	request.max_redirects = 0
	add_child(request)
	request.request_completed.connect(_completed.bind(request_epoch))
	var result = request.request(API,PackedStringArray(["Accept: application/vnd.github+json","User-Agent: SecurityLab-update-check"]))
	if result != OK: _failed()

func _failed():
	busy = false
	status = "업데이트를 확인하지 못했습니다. 연결 후 다시 확인하세요."
	changed.emit()

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, generation = -1):
	if generation != -1 and generation != request_epoch: return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200: _failed(); return
	var releases = JSON.parse_string(body.get_string_from_utf8())
	if not releases is Array: _failed(); return
	busy = false
	var candidate = select_release(releases,installed,platform,selected_channel)
	if candidate.is_empty(): status = "%s 채널에 현재 버전보다 새 버전이 없습니다. (%s 유지)" % ["베타" if selected_channel=="beta" else "정식",installed.get("version","")]
	elif candidate.url == "": status = "새 버전 %s · 이 플랫폼의 배포 파일이 아직 없습니다." % candidate.version
	else:
		download_url = candidate.url
		status = "새 버전 %s · 다운로드 후 %s" % [candidate.version,"기존 앱 위에 설치하세요. 저장은 유지됩니다." if platform == "Android" else "게임을 닫고 새 실행 파일로 실행하세요. 저장은 유지됩니다."]
	changed.emit()

func open_download():
	if not download_url.begins_with(DOWNLOAD): return
	if OS.shell_open(download_url) != OK:
		status = "다운로드 페이지를 열지 못했습니다. GitHub 릴리즈에서 파일을 받아 주세요."
		changed.emit()
