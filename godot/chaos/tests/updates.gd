extends SceneTree

class FakeGame extends Node:
	var qa = true
	var store = ChaosSave.new()
	var saves = 0
	var allow_save = true
	func persist_checkpoint() -> bool:
		saves += 1
		return allow_save

var failures: Array[String] = []
var checks = 0
var requests: Array[String] = []
var ready_count = 0
var fixture_bytes = "MZverified installer".to_utf8_buffer()
var fixture_hash = ""
var owners: Array[Node] = []
func _initialize(): call_deferred("run_tests")
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label)
func release_info(ver = "0.2.0") -> Dictionary:
	var tag = "OfficeChairChaos-v"+ver
	var prefix = "https://github.com/nu4ddi4/office-zirral/releases/download/"+tag+"/"
	return {"tag_name":tag,"draft":false,"prerelease":false,"assets":[{"name":"OfficeChairChaos-Setup.exe","size":fixture_bytes.size(),"browser_download_url":prefix+"OfficeChairChaos-Setup.exe"},{"name":"SHA256SUMS.txt","size":100,"browser_download_url":prefix+"SHA256SUMS.txt"}]}
func service() -> ChaosUpdater:
	var owner = FakeGame.new(); root.add_child(owner); owners.append(owner)
	var updater = ChaosUpdater.new(); owner.add_child(updater); updater.setup(owner)
	updater.storage_directory = "user://update-tests-%d-%d" % [OS.get_process_id(),owners.size()]
	updater.request_started.connect(func(url): requests.append(url))
	updater.installer_ready.connect(func(): ready_count += 1)
	requests.clear(); ready_count = 0
	return updater
func respond(updater: ChaosUpdater, bytes: PackedByteArray): updater._completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),bytes)
func available(updater: ChaosUpdater):
	updater.check_for_updates(); respond(updater,JSON.stringify([release_info()]).to_utf8_buffer())
func checksum_response(updater: ChaosUpdater): respond(updater,(fixture_hash+"  OfficeChairChaos-Setup.exe\n").to_utf8_buffer())
func partial(updater: ChaosUpdater, bytes: PackedByteArray):
	var file = FileAccess.open(updater.download_path+".part",FileAccess.WRITE)
	file.store_buffer(bytes); file.close()
func run_tests():
	var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(fixture_bytes); fixture_hash = hash.finish().hex_encode()
	check(ChaosUpdatePolicy.newer("0.1.10","0.1.2"),"numeric version comparison")
	check(not ChaosUpdatePolicy.newer("0.1.0","0.1.1"),"no downgrade")
	check(not ChaosUpdatePolicy.newer("1.2.3-beta.1","0.1.1"),"stable versions only")
	var candidate = ChaosUpdatePolicy.select_release([release_info()],"0.1.1")
	check(candidate.get("version","")=="0.2.0","select new product installer")
	var legacy = release_info(); legacy.tag_name="SecurityLab-0.2.0"
	check(ChaosUpdatePolicy.select_release([legacy],"0.1.1").is_empty(),"legacy product ignored")
	var unsafe = release_info(); unsafe.assets[0].browser_download_url="https://example.com/setup.exe"
	check(ChaosUpdatePolicy.select_release([unsafe],"0.1.1").is_empty(),"foreign download rejected")
	unsafe=release_info(); unsafe.assets[0].size="large"
	check(ChaosUpdatePolicy.select_release([unsafe],"0.1.1").is_empty(),"malformed size rejected")
	unsafe=release_info(); unsafe.prerelease=true
	check(ChaosUpdatePolicy.select_release([unsafe],"0.1.1").is_empty(),"prerelease ignored")
	check(ChaosUpdatePolicy.checksum(fixture_hash+" *OfficeChairChaos-Setup.exe\r\n")==fixture_hash,"installer checksum parsing")
	check(ChaosUpdatePolicy.checksum(fixture_hash+" OfficeChairChaos.exe").is_empty(),"checksum must name the installer")
	var updater=service(); available(updater)
	check(updater.state=="available" and requests.size()==1 and ready_count==0,"checking never downloads or installs without consent")
	updater.begin_install(); checksum_response(updater)
	check(updater.state=="downloading" and requests.size()==3,"consent starts checksum and installer requests")
	partial(updater,fixture_bytes); respond(updater,PackedByteArray())
	check(updater.state=="ready" and ready_count==1 and updater.game.saves==1,"verified download saves before handing off to installer")
	updater=service(); available(updater); updater.begin_install(); checksum_response(updater)
	partial(updater,"tampered".to_utf8_buffer()); respond(updater,PackedByteArray())
	check(updater.state=="error" and ready_count==0 and updater.game.saves==0,"corrupt download cannot install")
	check(not FileAccess.file_exists(updater.download_path+".part"),"corrupt partial is removed")
	updater=service(); available(updater); updater.begin_install(); checksum_response(updater)
	partial(updater,fixture_bytes); updater.cancel_download()
	check(updater.state=="available" and ready_count==0 and not FileAccess.file_exists(updater.download_path+".part"),"cancellation keeps the current game and removes partial file")
	updater=service(); updater.game.allow_save=false; available(updater); updater.begin_install(); checksum_response(updater)
	partial(updater,fixture_bytes); respond(updater,PackedByteArray())
	check(updater.state=="error" and ready_count==0,"save failure blocks installation")
	updater=service(); updater.check_for_updates(); updater._completed(HTTPRequest.RESULT_CANT_CONNECT,0,PackedStringArray(),PackedByteArray())
	check(updater.state=="error" and ready_count==0,"offline check leaves game usable")
	var old=ChaosSave.fresh(); old.settings.erase("auto_updates")
	check(ChaosSave.valid(old),"old save remains valid without update setting")
	old.settings.auto_updates="yes"
	check(not ChaosSave.valid(old),"new update preference must be boolean")
	for owner in owners: owner.queue_free()
	await process_frame
	print("CHAOS_UPDATES ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
