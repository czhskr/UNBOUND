extends CanvasLayer

## 상하 바와 대사 클릭 영역. 높이와 등장 시간은 최종값이 아니다.

signal advance_requested
signal dismissed

## 1152×648 기준 시험 높이. 최종값이 아니다.
const BAR_HEIGHT := 96.0
## 후보 0.15 / 0.20 / 0.25 중 작업값.
const TWEEN_SECONDS := 0.20

var _catcher_enabled: bool = false
var _tween: Tween

@onready var _top: Control = $TopBar
@onready var _bottom: Control = $BottomBar
@onready var _catcher: Control = $DialogueClickCatcher


func _ready() -> void:
	layer = 50
	_catcher.gui_input.connect(_on_catcher_input)
	_set_catcher_enabled(false)
	_place_bars(false)
	visible = false


func show_bars(immediate: bool) -> void:
	visible = true
	_set_catcher_enabled(true)
	_kill_tween()
	if immediate:
		_place_bars(true)
		return
	_place_bars(false)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_top, "offset_top", 0.0, TWEEN_SECONDS)
	_tween.tween_property(_top, "offset_bottom", BAR_HEIGHT, TWEEN_SECONDS)
	_tween.tween_property(_bottom, "offset_top", -BAR_HEIGHT, TWEEN_SECONDS)
	_tween.tween_property(_bottom, "offset_bottom", 0.0, TWEEN_SECONDS)


func hide_bars(immediate: bool) -> void:
	_kill_tween()
	if immediate or not visible:
		release_overlay()
		dismissed.emit()
		return
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_top, "offset_top", -BAR_HEIGHT, TWEEN_SECONDS)
	_tween.tween_property(_top, "offset_bottom", 0.0, TWEEN_SECONDS)
	_tween.tween_property(_bottom, "offset_top", 0.0, TWEEN_SECONDS)
	_tween.tween_property(_bottom, "offset_bottom", BAR_HEIGHT, TWEEN_SECONDS)
	_tween.chain().tween_callback(_finish_hide)


func release_overlay() -> void:
	_place_bars(false)
	visible = false
	_set_catcher_enabled(false)


func catcher_blocks_mouse() -> bool:
	return _catcher_enabled and _catcher.mouse_filter == Control.MOUSE_FILTER_STOP


func _finish_hide() -> void:
	dismissed.emit()


func _on_catcher_input(event: InputEvent) -> void:
	if not _catcher_enabled or not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	advance_requested.emit()
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _set_catcher_enabled(enabled: bool) -> void:
	_catcher_enabled = enabled
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _place_bars(shown: bool) -> void:
	if shown:
		_top.offset_top = 0.0
		_top.offset_bottom = BAR_HEIGHT
		_bottom.offset_top = -BAR_HEIGHT
		_bottom.offset_bottom = 0.0
		return
	_top.offset_top = -BAR_HEIGHT
	_top.offset_bottom = 0.0
	_bottom.offset_top = 0.0
	_bottom.offset_bottom = BAR_HEIGHT


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
