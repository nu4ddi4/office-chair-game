class_name ChaosUpdatePolicy
extends RefCounted

const PRODUCT = "OfficeChairChaos"
const REPOSITORY = "nu4ddi4/office-zirral"
const RELEASES_URL = "https://api.github.com/repos/"+REPOSITORY+"/releases?per_page=20"
const INSTALLER = "OfficeChairChaos-Setup.exe"
const STAMP = "office-chair.install.json"
const MAX_DOWNLOAD = 512*1024*1024

static func version(value: String) -> Array:
	var parts = value.split(".")
	if parts.size()!=3: return []
	var result = []
	for part in parts:
		if part.is_empty() or not part.is_valid_int() or part.begins_with("-") or str(int(part))!=part: return []
		result.append(int(part))
	return result

static func newer(candidate: String, current: String) -> bool:
	var a = version(candidate); var b = version(current)
	if a.is_empty() or b.is_empty(): return false
	for i in range(3):
		if a[i]!=b[i]: return a[i]>b[i]
	return false

static func select_release(payload, current: String) -> Dictionary:
	if not payload is Array: return {}
	var best = {}
	for release in payload:
		if not release is Dictionary or release.get("draft",true) or release.get("prerelease",true): continue
		var tag = str(release.get("tag_name",""))
		if not tag.begins_with("OfficeChairChaos-v"): continue
		var candidate = tag.trim_prefix("OfficeChairChaos-v")
		if not newer(candidate,current) or (not best.is_empty() and not newer(candidate,best.version)): continue
		var assets = release.get("assets",[])
		if not assets is Array: continue
		var prefix = "https://github.com/"+REPOSITORY+"/releases/download/"+tag+"/"
		var installer = {}; var checksum = {}
		for asset in assets:
			if not asset is Dictionary: continue
			var name = str(asset.get("name",""))
			if str(asset.get("browser_download_url",""))!=prefix+name: continue
			if name==INSTALLER and ChaosSave.number(asset.get("size",0),1,MAX_DOWNLOAD): installer=asset
			if name=="SHA256SUMS.txt" and ChaosSave.number(asset.get("size",0),1,65536): checksum=asset
		if installer.is_empty() or checksum.is_empty(): continue
		best = {"version":candidate,"tag":tag,"installer_url":prefix+INSTALLER,"checksum_url":prefix+"SHA256SUMS.txt","size":int(installer.size)}
	return best

static func checksum(text: String) -> String:
	var regex = RegEx.new(); regex.compile("^[0-9a-fA-F]{64}$")
	for line in text.split("\n"):
		var fields = line.strip_edges().replace("\t"," ").split(" ",false)
		if fields.size()==2 and fields[1].trim_prefix("*")==INSTALLER and regex.search(fields[0])!=null: return fields[0].to_lower()
	return ""

static func installed(directory: String) -> bool:
	var path = directory.path_join(STAMP)
	if not FileAccess.file_exists(path): return false
	var data = ChaosSave.read_json(path)
	return data is Dictionary and data.get("product","")==PRODUCT and data.get("app_id","")==PRODUCT
