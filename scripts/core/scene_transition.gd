class_name SceneFader
extends CanvasLayer

## 장면 전환의 유일한 입구. 전투 노드 참조는 저장하지 않는다.

const MAIN_MENU_PATH := "res://scenes/main/MainMenu.tscn"
const ENTRY_PATH := "res://scenes/hub/Entry.tscn"
const OPENING_PATH := "res://scenes/cutscene/OpeningCutscene.tscn"
const ENDING_PATH := "res://scenes/cutscene/EndingCutscene.tscn"
const TUTORIAL_PATH := "res://scenes/tutorial/Tutorial.tscn"

## 페이지가 덮고 열리는 시간. 최종 연출 속도가 아니다.
@export var fade_out_duration: float = 0.30
@export var fade_in_duration: float = 0.30

var transition_in_progress: bool = false
var accepted_transition_count: int = 0
## 페이지가 화면을 다 덮은 뒤 교체되는 씬. 입장 페이드와 같은 시점을 확인한다.
var covered_scene_path: String = ""


static func get_fader() -> SceneFader:
	return (Engine.get_main_loop() as SceneTree).root.get_node("SceneTransition") as SceneFader

var _fade: ColorRect
var _pending_path: String = ""
var _wipe_token: int = 0
var _tween: Tween


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.name = "PageWipe"
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.visible = false
	add_child(_fade)


func go_to_main_menu() -> void:
	change_scene(MAIN_MENU_PATH)


func go_to_entry() -> void:
	change_scene(ENTRY_PATH)


func go_to_opening() -> void:
	change_scene(OPENING_PATH)


func go_to_ending() -> void:
	change_scene(ENDING_PATH)


func go_to_tutorial() -> void:
	change_scene(TUTORIAL_PATH)


func go_to_stage(stage_id: StringName) -> void:
	if not StageRegistry.has_stage(stage_id):
		push_error("Unknown stage id '%s'." % stage_id)
		_fallback_from_invalid_stage()
		return
	var definition := StageRegistry.get_stage(stage_id)
	if definition == null or not StageRegistry.is_stage_playable(stage_id):
		push_error("Stage '%s' is unavailable." % stage_id)
		_fallback_from_invalid_stage()
		return
	change_scene(definition.scene_path)


func scene_path_for(stage_id: StringName) -> String:
	var definition := StageRegistry.get_stage(stage_id)
	if definition == null:
		return ""
	return definition.scene_path


func _fallback_from_invalid_stage() -> void:
	if transition_in_progress:
		return
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == ENTRY_PATH:
		return
	go_to_entry()


func change_scene(path: String) -> void:
	if transition_in_progress:
		return
	if path.is_empty():
		push_error("Scene transition path is empty.")
		return
	transition_in_progress = true
	accepted_transition_count += 1
	_cancel_dialogue()
	_pending_path = path
	_wipe_token += 1
	_play_page_wipe(_wipe_token)


func _play_page_wipe(token: int) -> void:
	var size := _viewport_size()
	_place_page(size, size.x)
	if _fade != null:
		_fade.visible = true
		_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _slide_page(0.0, fade_out_duration, token)
	if token != _wipe_token:
		return
	await get_tree().process_frame
	if token != _wipe_token:
		return
	var leaving := get_tree().current_scene
	covered_scene_path = "" if leaving == null else leaving.scene_file_path
	var error := get_tree().change_scene_to_file(_pending_path)
	if error != OK:
		push_error("Scene change failed: %s" % _pending_path)
		_finish()
		return
	await _slide_page(-size.x, fade_in_duration, token)
	if token != _wipe_token:
		return
	_finish()


func _slide_page(target_x: float, seconds: float, token: int) -> void:
	if token != _wipe_token or _fade == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var size := _viewport_size()
	var duration := maxf(seconds, 0.01)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_fade, "offset_left", target_x, duration)
	_tween.parallel().tween_property(_fade, "offset_right", target_x + size.x, duration)
	await _tween.finished


func _place_page(size: Vector2, page_x: float) -> void:
	if _fade == null:
		return
	_fade.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fade.anchor_right = 0.0
	_fade.anchor_bottom = 0.0
	_fade.offset_left = page_x
	_fade.offset_top = 0.0
	_fade.offset_right = page_x + size.x
	_fade.offset_bottom = size.y
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(1152.0, 648.0)
	var size := viewport.get_visible_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		return Vector2(1152.0, 648.0)
	return size


func _cancel_dialogue() -> void:
	var dialogue := get_tree().root.get_node_or_null("UnboundDialogue")
	if dialogue != null and dialogue.has_method("cancel"):
		dialogue.call("cancel")


func _finish() -> void:
	_wipe_token += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_pending_path = ""
	transition_in_progress = false
	if _fade != null:
		_fade.visible = false
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var size := _viewport_size()
		_fade.offset_left = -size.x
		_fade.offset_right = 0.0
