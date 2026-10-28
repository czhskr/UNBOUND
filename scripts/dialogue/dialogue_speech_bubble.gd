extends Control

## 화면 좌표 말풍선. 본문은 애드온 DialogueLabel이 연다. 속도는 최종값이 아니다.

## 글자 간격 후보 0.025 / 0.035 / 0.050 중 작업값.
const CHARACTER_INTERVAL := 0.035
## 꼬리 반폭과 높이. 최종 크기가 아니다.
const TAIL_HALF_WIDTH := 8.0
const TAIL_HEIGHT := 12.0
const TAIL_MARGIN := 16.0

## 앵커를 기준으로 놓은 뒤 말풍선만 이 값만큼 내린다. 0이면 지금 위치 그대로다.
@export var bubble_offset_y: float = 80.0

@onready var _speaker: Label = $SpeakerLabel
@onready var _body: DialogueLabel = $DialogueText
@onready var _tail: Polygon2D = $Tail


func _ready() -> void:
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.seconds_per_step = CHARACTER_INTERVAL
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.shadow_size = 0
	var panel := $BubbleBackground as Panel
	if panel != null:
		panel.add_theme_stylebox_override(&"panel", style)
	if _tail != null:
		_tail.color = Color.BLACK
		_tail.polygon = PackedVector2Array([
			Vector2(-TAIL_HALF_WIDTH, 0.0),
			Vector2(TAIL_HALF_WIDTH, 0.0),
			Vector2(0.0, TAIL_HEIGHT),
		])
		_tail.z_index = -1


func show_line(line: DialogueLine) -> void:
	visible = true
	var speaker_name := ""
	if line != null:
		speaker_name = line.character.strip_edges()
	_speaker.visible = not speaker_name.is_empty()
	_speaker.text = speaker_name
	if _tail != null:
		_tail.visible = speaker_name.to_upper() != "SYSTEM"
	_body.seconds_per_step = CHARACTER_INTERVAL
	_body.dialogue_line = line
	_body.type_out()


func hide_bubble() -> void:
	visible = false
	_speaker.text = ""
	_speaker.visible = false
	if _tail != null:
		_tail.visible = false
	_body.dialogue_line = null
	_body.text = ""
	_body.visible_characters = 0


func complete_current_line() -> void:
	_body.skip_typing()


func is_line_typing() -> bool:
	return _body.is_typing


func visible_character_count() -> int:
	return _body.visible_characters


func place_above(anchor_screen: Vector2, viewport_size: Vector2) -> void:
	var spot := anchor_screen - Vector2(size.x * 0.5, size.y + 8.0)
	_clamp_to_viewport(spot, viewport_size)
	position.y += bubble_offset_y
	_place_tail(anchor_screen)


func place_system(viewport_size: Vector2, top_margin: float) -> void:
	var spot := Vector2((viewport_size.x - size.x) * 0.5, top_margin)
	_clamp_to_viewport(spot, viewport_size)
	position.y += bubble_offset_y
	if _tail != null:
		_tail.visible = false


func _place_tail(anchor_screen: Vector2) -> void:
	if _tail == null or not _tail.visible:
		return
	var bubble_x := get_global_transform_with_canvas().origin.x
	var local_x := anchor_screen.x - bubble_x
	var limit := maxf(TAIL_MARGIN, size.x - TAIL_MARGIN)
	_tail.position = Vector2(clampf(local_x, TAIL_MARGIN, limit), size.y - 1.0)


func _clamp_to_viewport(spot: Vector2, viewport_size: Vector2) -> void:
	var margin := 16.0
	var max_x := maxf(margin, viewport_size.x - size.x - margin)
	var max_y := maxf(margin, viewport_size.y - size.y - margin)
	position = Vector2(clampf(spot.x, margin, max_x), clampf(spot.y, margin, max_y))
