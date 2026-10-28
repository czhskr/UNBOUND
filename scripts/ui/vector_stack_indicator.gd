class_name VectorStackIndicator
extends CanvasLayer

## 추적 보정 누적 피해. 뜨는 데미지 숫자가 아니라 플레이어 옆의 고정 표시다.
## 전투 입력이 열려 있고 스택이 있을 때만 보인다. 위치는 시험값이며 최종이 아니다.

const SIDE_OFFSET := Vector2(88.0, -64.0)
const FONT_SIZE := 28
const _FONT := preload("res://assets/fonts/Galmuri9.ttf")

var _label: Label


static func mount(scene: Node) -> void:
	if scene == null or scene.get_node_or_null("VectorStackIndicator") != null:
		return
	var layer := VectorStackIndicator.new()
	layer.name = "VectorStackIndicator"
	scene.add_child.call_deferred(layer)


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.name = "StackLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override(&"font", _FONT)
	_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	_label.add_theme_color_override(&"font_color", Color(0.97, 0.94, 0.88, 1.0))
	_label.add_theme_color_override(&"font_outline_color", Color(0.06, 0.06, 0.08, 1.0))
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.visible = false
	add_child(_label)


func shown_text() -> String:
	if _label == null or not _label.visible:
		return ""
	return _label.text


func refresh() -> void:
	if _label == null:
		return
	var actor := _player()
	var text := ""
	if actor != null:
		var traits := actor.get_node_or_null("TraitController") as TraitController
		if traits != null:
			text = traits.vector_indicator_text()
	var encounter := _encounter()
	var show := not text.is_empty() and encounter != null and encounter.is_combat_active()
	_label.text = text
	_label.visible = show
	if not show or actor == null:
		return
	var node: Node2D = actor
	var motion := actor.get_node_or_null("MotionRoot") as Node2D
	if motion != null:
		node = motion
	_label.position = node.get_global_transform_with_canvas().origin + SIDE_OFFSET


func _process(_delta: float) -> void:
	refresh()


func _encounter() -> EncounterController:
	var root := get_parent()
	if root == null:
		return null
	return root.get_node_or_null("EncounterController") as EncounterController


func _player() -> Player:
	var root := get_parent()
	if root == null:
		return null
	var player := root.get_node_or_null("World/Player") as Player
	if player == null:
		player = root.get_node_or_null("Stage/Player") as Player
	return player
