class_name DialogueCinematicController
extends Node

## 현재 장면의 카메라만 움직인다. 대사 데이터는 다루지 않는다.

signal restore_finished

## 현재 줌에 곱하는 후보 1.10 / 1.15 / 1.20 중 작업값.
const ZOOM_MULTIPLIER := 1.15
## 이동 시간 후보 0.15 / 0.20 / 0.30 중 작업값.
const MOVE_SECONDS := 0.20
const WORLD_SIZE := Vector2(384.0, 216.0)

var move_count: int = 0

var _camera: Camera2D
var _holding: bool = false
var _speaker: StringName = &""
var _origin_position: Vector2 = Vector2.ZERO
var _origin_offset: Vector2 = Vector2.ZERO
var _origin_zoom: Vector2 = Vector2.ONE
var _tween: Tween


func _ready() -> void:
	var parent_node := get_parent()
	if parent_node != null:
		_camera = parent_node.get_node_or_null("World/Camera2D") as Camera2D
		if _camera == null:
			_camera = parent_node.get_node_or_null("Camera2D") as Camera2D


func is_holding_camera() -> bool:
	return _holding


func is_moving() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func origin_position() -> Vector2:
	return _origin_position


func origin_zoom() -> Vector2:
	return _origin_zoom


func focus_speaker(speaker_id: StringName, anchor: Node2D) -> void:
	if speaker_id == &"system":
		return
	if _holding and speaker_id == _speaker:
		return
	if _camera == null or anchor == null:
		return
	if not _holding:
		_capture()
	_holding = true
	_speaker = speaker_id
	_kill_tween()
	move_count += 1
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_camera, "position", _frame_target(anchor), MOVE_SECONDS)
	_tween.tween_property(_camera, "zoom", _origin_zoom * ZOOM_MULTIPLIER, MOVE_SECONDS)


func restore(immediate: bool) -> void:
	_speaker = &""
	_kill_tween()
	if not _holding or _camera == null:
		_holding = false
		restore_finished.emit()
		return
	if immediate:
		_apply_origin()
		_holding = false
		restore_finished.emit()
		return
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_camera, "position", _origin_position, MOVE_SECONDS)
	_tween.tween_property(_camera, "offset", _origin_offset, MOVE_SECONDS)
	_tween.tween_property(_camera, "zoom", _origin_zoom, MOVE_SECONDS)
	_tween.chain().tween_callback(_finish_restore)


func _capture() -> void:
	_origin_position = _camera.position
	_origin_offset = _camera.offset
	_origin_zoom = _camera.zoom


func _apply_origin() -> void:
	_camera.position = _origin_position
	_camera.offset = _origin_offset
	_camera.zoom = _origin_zoom


func _finish_restore() -> void:
	_holding = false
	restore_finished.emit()


func _frame_target(anchor: Node2D) -> Vector2:
	var viewport := _camera.get_viewport()
	var viewport_size := Vector2(1152, 648)
	if viewport != null:
		viewport_size = viewport.get_visible_rect().size
	var zoom := _origin_zoom * ZOOM_MULTIPLIER
	var view := Vector2(viewport_size.x / maxf(zoom.x, 0.01), viewport_size.y / maxf(zoom.y, 0.01))
	var target := anchor.global_position + Vector2(view.x * 0.08, view.y * 0.06)
	var half := view * 0.5
	target.x = clampf(target.x, half.x, maxf(half.x, WORLD_SIZE.x - half.x))
	target.y = clampf(target.y, half.y, maxf(half.y, WORLD_SIZE.y - half.y))
	return target


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
