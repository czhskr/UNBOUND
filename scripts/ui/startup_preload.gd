class_name StartupPreload
extends Node

## 메인 메뉴 시작 전에 필요한 큰 리소스만 스레드로 읽는다.
## 진행률은 각 리소스의 실제 로드 상태를 합친 값이다.

const MANIFEST: PackedStringArray = [
	"res://assets/audio/bgm/TheVeil.mp3",
	"res://assets/audio/bgm/Rupture.mp3",
	"res://assets/audio/bgm/Revelation.mp3",
	"res://assets/effects/hyper/hyper_001.png",
	"res://assets/effects/hyper/hyper_002.png",
	"res://assets/effects/hyper/hyper_003.png",
	"res://assets/effects/hyper/hyper_004.png",
]

var startup_ready: bool = false
var failed: bool = false
var shown_percent: int = 0
var samples: PackedInt32Array = PackedInt32Array()

var _paths: PackedStringArray = PackedStringArray()
var _progress: Array[float] = []
var _active: bool = false
var _hold_complete: bool = false
var _tracks_session: bool = false


func begin(paths: PackedStringArray = MANIFEST) -> void:
	_paths = paths.duplicate()
	_progress.clear()
	_progress.resize(_paths.size())
	samples = PackedInt32Array([0])
	shown_percent = 0
	startup_ready = false
	failed = false
	_hold_complete = false
	_tracks_session = paths == MANIFEST
	var session := GameSession.get_session()
	if _tracks_session and session != null and session.startup_resources_ready:
		_mark_cached_ready()
		return
	for index in _paths.size():
		var path := _paths[index]
		if ResourceLoader.has_cached(path):
			_progress[index] = 1.0
			continue
		var error := ResourceLoader.load_threaded_request(path)
		if error != OK:
			failed = true
			return
	_active = true
	_publish()


func poll() -> void:
	if not _active or failed or startup_ready:
		return
	var all_done := true
	for index in _paths.size():
		if _progress[index] >= 1.0:
			continue
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(_paths[index], progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(_paths[index])
			_progress[index] = 1.0
		elif status == ResourceLoader.THREAD_LOAD_FAILED or (status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and not ResourceLoader.exists(_paths[index])):
			failed = true
			_active = false
			return
		else:
			all_done = false
			var current := 0.0
			if progress.size() > 0:
				current = float(progress[0])
			_progress[index] = maxf(_progress[index], clampf(current, 0.0, 0.99))
	if all_done and not _hold_complete:
		_hold_complete = true
		_publish(true)
		return
	if _hold_complete:
		_finish()
		return
	_publish(false)


func _mark_cached_ready() -> void:
	for index in _progress.size():
		_progress[index] = 1.0
	shown_percent = 100
	_remember_sample(100)
	_finish()


func _publish(force_complete: bool = false) -> void:
	var sum := 0.0
	for value in _progress:
		sum += value
	var percent := 0
	if _paths.size() > 0:
		percent = int(round(sum / float(_paths.size()) * 100.0))
	if force_complete:
		percent = 100
	elif percent >= 100:
		percent = 99
	percent = clampi(percent, 0, 100)
	if percent < shown_percent:
		percent = shown_percent
	shown_percent = percent
	_remember_sample(percent)


func _finish() -> void:
	shown_percent = 100
	_remember_sample(100)
	startup_ready = true
	_active = false
	var session := GameSession.get_session()
	if session != null and _tracks_session:
		session.startup_resources_ready = true


func _remember_sample(percent: int) -> void:
	if samples.is_empty() or samples[samples.size() - 1] != percent:
		samples.append(percent)


func _process(_delta: float) -> void:
	poll()
