class_name SpeedEffectOverlay
extends CanvasLayer

## 실제 속도 효과가 켜진 동안 패널 위 실행 글자와 가장자리 테두리를 보여 준다.

const _FONT := preload("res://assets/fonts/Galmuri9.ttf")
const PULSE_HALF_SECONDS := 0.45
const ALPHA_STRONG := 0.85
const ALPHA_WEAK := 0.25
const THICKNESS := 8.0
const SLOW_COLOR := Color(0.25, 0.55, 1.0, 1.0)
const FAST_COLOR := Color(1.0, 0.22, 0.28, 1.0)
## 리듬 패널 윗변에서 띄우는 거리.
const EXECUTE_TOP_MARGIN := 16.0

var _border: Control
var _label: Label
var _tween: Tween
var _shown: RhythmNode.SpeedEffect = RhythmNode.SpeedEffect.NONE
var _debug_visual: RhythmNode.SpeedEffect = RhythmNode.SpeedEffect.NONE


static func mount(parent: Node) -> void:
	if parent == null or parent.get_node_or_null("SpeedEffectOverlay") != null:
		return
	var overlay := SpeedEffectOverlay.new()
	overlay.name = "SpeedEffectOverlay"
	overlay.layer = 24
	parent.add_child.call_deferred(overlay)


func _ready() -> void:
	var frame := Control.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_border = Control.new()
	_border.name = "Border"
	_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_border)
	for side in ["Top", "Bottom", "Left", "Right"]:
		var bar := ColorRect.new()
		bar.name = side
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.color = SLOW_COLOR
		_border.add_child(bar)
	_layout_border()
	_label = Label.new()
	_label.name = "ExecuteLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override(&"font", _FONT)
	_label.add_theme_font_size_override(&"font_size", 28)
	_label.add_theme_color_override(&"font_color", Color(0.96, 0.96, 0.98, 1.0))
	_label.add_theme_color_override(&"font_outline_color", Color(0.04, 0.05, 0.08, 1.0))
	_label.add_theme_constant_override(&"outline_size", 6)
	frame.add_child(_label)
	visible = false


func debug_show_slow_visual() -> void:
	_show_debug_visual(RhythmNode.SpeedEffect.SLOW)


func debug_show_fast_visual() -> void:
	_show_debug_visual(RhythmNode.SpeedEffect.FAST)


func debug_clear_visual() -> void:
	_debug_visual = RhythmNode.SpeedEffect.NONE
	_shown = RhythmNode.SpeedEffect.NONE
	_apply(RhythmNode.SpeedEffect.NONE)
	sync_from_parent()


func sync_from_parent() -> void:
	if _debug_visual != RhythmNode.SpeedEffect.NONE:
		if _shown != _debug_visual:
			_shown = _debug_visual
			_apply(_debug_visual)
		return
	var effect := RhythmNode.SpeedEffect.NONE
	var host := get_parent()
	if host != null:
		var rhythm := host.get_node_or_null("RhythmController")
		if rhythm != null and rhythm.has_method("current_speed_effect"):
			var raw := int(rhythm.call("current_speed_effect"))
			if raw == RhythmNode.SpeedEffect.SLOW:
				effect = RhythmNode.SpeedEffect.SLOW
			elif raw == RhythmNode.SpeedEffect.FAST:
				effect = RhythmNode.SpeedEffect.FAST
		var encounter := host.get_node_or_null("EncounterController")
		if encounter != null and encounter.has_method("hides_speed_overlay") and bool(encounter.call("hides_speed_overlay")):
			effect = RhythmNode.SpeedEffect.NONE
	if effect == _shown:
		return
	_shown = effect
	_apply(effect)


func _show_debug_visual(effect: RhythmNode.SpeedEffect) -> void:
	_debug_visual = effect
	_shown = effect
	_apply(effect)


func label_text() -> String:
	if _label == null:
		return ""
	return _label.text


func border_color() -> Color:
	if _border == null:
		return Color.BLACK
	var bar := _border.get_node_or_null("Top") as ColorRect
	if bar == null:
		return Color.BLACK
	return bar.color


func pulse_running() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func _process(_delta: float) -> void:
	sync_from_parent()
	if visible:
		_place_execute_label()


func _apply(effect: RhythmNode.SpeedEffect) -> void:
	if _tween != null:
		_tween.kill()
	_tween = null
	if effect == RhythmNode.SpeedEffect.NONE or _border == null or _label == null:
		visible = false
		if _label != null:
			_label.text = ""
		return
	var tint := FAST_COLOR
	var text := "EXECUTE: FAST"
	if effect == RhythmNode.SpeedEffect.SLOW:
		tint = SLOW_COLOR
		text = "EXECUTE: SLOW"
	for child in _border.get_children():
		var bar := child as ColorRect
		if bar != null:
			bar.color = tint
	_label.text = text
	_label.reset_size()
	_place_execute_label()
	_border.modulate = Color(1, 1, 1, ALPHA_STRONG)
	visible = true
	_tween = create_tween()
	_tween.set_loops()
	_tween.tween_property(_border, "modulate:a", ALPHA_WEAK, PULSE_HALF_SECONDS)
	_tween.tween_property(_border, "modulate:a", ALPHA_STRONG, PULSE_HALF_SECONDS)


func _place_execute_label() -> void:
	if _label == null:
		return
	var panel := _rhythm_panel()
	if panel == null:
		return
	var rect := panel.get_global_rect()
	var label_size := _label.size
	if label_size.x < 1.0 or label_size.y < 1.0:
		label_size = _label.get_minimum_size()
	var origin := Vector2(
		rect.position.x + rect.size.x * 0.5 - label_size.x * 0.5,
		rect.position.y - EXECUTE_TOP_MARGIN - label_size.y
	)
	_label.global_position = origin


func _rhythm_panel() -> Control:
	var host := get_parent()
	if host == null:
		return null
	var rhythm := host.get_node_or_null("RhythmController")
	if rhythm == null:
		return null
	return rhythm.get("panel") as Control


func _layout_border() -> void:
	var viewport := get_viewport()
	var view := Vector2(1152, 648)
	if viewport != null:
		var visible_size := viewport.get_visible_rect().size
		if visible_size.x > 1.0 and visible_size.y > 1.0:
			view = visible_size
	var top := _border.get_node("Top") as ColorRect
	var bottom := _border.get_node("Bottom") as ColorRect
	var left := _border.get_node("Left") as ColorRect
	var right := _border.get_node("Right") as ColorRect
	top.position = Vector2.ZERO
	top.size = Vector2(view.x, THICKNESS)
	bottom.position = Vector2(0.0, view.y - THICKNESS)
	bottom.size = Vector2(view.x, THICKNESS)
	left.position = Vector2.ZERO
	left.size = Vector2(THICKNESS, view.y)
	right.position = Vector2(view.x - THICKNESS, 0.0)
	right.size = Vector2(THICKNESS, view.y)
