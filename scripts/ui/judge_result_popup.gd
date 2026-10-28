class_name JudgeResultPopup
extends Control

## BAD/MISS 전용. 피해 숫자 팝업과 따로 둔다.

const _FONT := preload("res://assets/fonts/Galmuri9.ttf")
const SIZE := Vector2(88.0, 32.0)
const POP_SECONDS := 0.10
const SETTLE_SECONDS := 0.08
const LIFE_SECONDS := 0.55
const RISE_DISTANCE := 28.0
const FONT_SIZE := 22

static var shown: PackedStringArray = PackedStringArray()

var _kind: String = ""


static func spawn(parent: Control, anchor: Vector2, kind: String) -> void:
	if parent == null:
		return
	var popup := JudgeResultPopup.new()
	popup._kind = kind
	popup.custom_minimum_size = SIZE
	popup.size = SIZE
	popup.position = anchor - SIZE * 0.5
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(popup)
	popup._clamp_into_view()
	shown.append(kind)


func _ready() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.7, 0.7)
	var label := Label.new()
	label.name = "ResultLabel"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = _kind
	label.add_theme_font_override(&"font", _FONT)
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_color_override(&"font_color", _color_for(_kind))
	label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.07, 1.0))
	label.add_theme_constant_override(&"outline_size", 4)
	add_child(label)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.15, 1.15), POP_SECONDS)
	pop.tween_property(self, "scale", Vector2.ONE, SETTLE_SECONDS)
	var life := create_tween()
	life.tween_property(self, "position:y", position.y - RISE_DISTANCE, LIFE_SECONDS)
	life.parallel().tween_property(self, "modulate:a", 0.0, LIFE_SECONDS)
	life.tween_callback(queue_free)


func _clamp_into_view() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var view := viewport.get_visible_rect()
	var origin := global_position
	var limit_x := maxf(8.0, view.size.x - size.x - 8.0)
	var limit_y := maxf(8.0, view.size.y - size.y - 8.0)
	global_position = Vector2(clampf(origin.x, 8.0, limit_x), clampf(origin.y, 8.0, limit_y))


func _color_for(kind: String) -> Color:
	if kind == "BAD":
		return Color(1.0, 0.45, 0.25, 1.0)
	return Color(0.72, 0.76, 0.84, 1.0)
