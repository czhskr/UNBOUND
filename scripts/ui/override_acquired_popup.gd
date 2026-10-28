class_name OverrideAcquiredPopup
extends CanvasLayer

## 오버라이드를 처음 획득했을 때만 보여 주는 비모달 알림.
## 전투를 멈추거나 입력을 막거나 로딩을 늦추지 않는다.
## 표시 시간은 시험값이며 최종이 아니다.

const HOLD_SECONDS := 1.6
const FADE_SECONDS := 0.45
const TITLE_TEXT := "오버라이드 획득"
const _FONT := preload("res://assets/fonts/Galmuri9.ttf")

var show_count: int = 0

var _title: Label
var _name_label: Label
var _fade_at_msec: int = 0
var _hide_at_msec: int = 0


static func present_pending() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var session := GameSession.get_session()
	if session == null or session.pending_override_notifications.is_empty():
		return
	var popup := tree.root.get_node_or_null("OverrideAcquiredPopup") as OverrideAcquiredPopup
	if popup == null:
		popup = OverrideAcquiredPopup.new()
		popup.name = "OverrideAcquiredPopup"
		tree.root.add_child(popup)
	popup._show_next()


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	var title := Label.new()
	title.name = "TitleLabel"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -220.0
	title.offset_right = 220.0
	title.offset_top = 72.0
	title.offset_bottom = 108.0
	title.add_theme_font_override(&"font", _FONT)
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", Color(0.97, 0.94, 0.88, 1.0))
	title.add_theme_color_override(&"font_outline_color", Color(0.06, 0.06, 0.08, 1.0))
	title.add_theme_constant_override(&"outline_size", 4)
	add_child(title)
	_title = title
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	name_label.offset_left = -220.0
	name_label.offset_right = 220.0
	name_label.offset_top = 108.0
	name_label.offset_bottom = 156.0
	name_label.add_theme_font_override(&"font", _FONT)
	name_label.add_theme_font_size_override(&"font_size", 36)
	name_label.add_theme_color_override(&"font_color", Color(0.98, 0.96, 0.9, 1.0))
	name_label.add_theme_color_override(&"font_outline_color", Color(0.06, 0.06, 0.08, 1.0))
	name_label.add_theme_constant_override(&"outline_size", 6)
	add_child(name_label)
	_name_label = name_label
	visible = false


func show_form(form_id: StringName) -> void:
	if _name_label == null or _title == null:
		return
	var shown := String(form_id)
	var form := FormRegistry.get_form(form_id)
	if form != null and not form.display_name.is_empty():
		shown = form.display_name
	_title.text = TITLE_TEXT
	_name_label.text = shown
	show_count += 1
	visible = true
	_set_alpha(1.0)
	var now := Time.get_ticks_msec()
	_fade_at_msec = now + int(round(HOLD_SECONDS * 1000.0))
	_hide_at_msec = _fade_at_msec + int(round(FADE_SECONDS * 1000.0))


func _process(_delta: float) -> void:
	if not visible:
		return
	var now := Time.get_ticks_msec()
	if now >= _hide_at_msec:
		visible = false
		_set_alpha(0.0)
		_show_next()
		return
	if now < _fade_at_msec:
		_set_alpha(1.0)
		return
	var span := maxi(_hide_at_msec - _fade_at_msec, 1)
	_set_alpha(clampf(float(_hide_at_msec - now) / float(span), 0.0, 1.0))


func _set_alpha(alpha: float) -> void:
	if _title != null:
		_title.modulate.a = alpha
	if _name_label != null:
		_name_label.modulate.a = alpha


func _show_next() -> void:
	if visible:
		return
	var session := GameSession.get_session()
	if session == null or session.pending_override_notifications.is_empty():
		return
	var form_id := session.pending_override_notifications[0]
	session.pending_override_notifications.remove_at(0)
	show_form(form_id)
