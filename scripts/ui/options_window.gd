class_name OptionsWindow
extends Panel

## Pause와 MainMenu가 같이 쓰는 옵션 창.
## 값은 GameSession 한 곳에만 둔다.

signal closed

const WINDOW_SIZE := Vector2(320, 292)

var _master_slider: HSlider
var _bgm_slider: HSlider
var _sfx_slider: HSlider
var _offset_slider: HSlider
var _master_value: Label
var _bgm_value: Label
var _sfx_value: Label
var _offset_value: Label


func _ready() -> void:
	custom_minimum_size = WINDOW_SIZE
	size = WINDOW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", RetroTheme.window_style())
	_build()
	sync_from_session()


func sync_from_session() -> void:
	var session := GameSession.get_session()
	if session == null:
		return
	_set_slider(_master_slider, _master_value, session.master_linear * 100.0, false)
	_set_slider(_bgm_slider, _bgm_value, session.bgm_linear * 100.0, false)
	_set_slider(_sfx_slider, _sfx_value, session.sfx_linear * 100.0, false)
	if _offset_slider != null:
		_offset_slider.set_value_no_signal(session.rhythm_input_offset_ms)
	_set_offset_text(session.rhythm_input_offset_ms)


func _build() -> void:
	var title_bar := ColorRect.new()
	title_bar.name = "TitleBar"
	title_bar.position = Vector2(4, 4)
	title_bar.size = Vector2(WINDOW_SIZE.x - 8, 24)
	title_bar.color = RetroTheme.TITLE_BAR
	title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_bar)
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "옵션"
	title.position = Vector2(8, 2)
	title.size = Vector2(WINDOW_SIZE.x - 48, 20)
	RetroTheme.apply_label(title, 14, RetroTheme.TITLE_TEXT)
	title_bar.add_child(title)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "×"
	close.position = Vector2(WINDOW_SIZE.x - 30, 4)
	close.size = Vector2(22, 22)
	RetroTheme.apply_button(close, 14)
	close.pressed.connect(close_window)
	add_child(close)
	_master_slider = _add_slider("MasterSlider", "전체 음량", 0.0, 100.0, 1.0, 40.0)
	_bgm_slider = _add_slider("BgmSlider", "BGM", 0.0, 100.0, 1.0, 78.0)
	_sfx_slider = _add_slider("SfxSlider", "효과음", 0.0, 100.0, 1.0, 116.0)
	_offset_slider = _add_slider("OffsetSlider", "입력 타이밍", float(GameSession.RHYTHM_OFFSET_MIN_MS), float(GameSession.RHYTHM_OFFSET_MAX_MS), float(GameSession.RHYTHM_OFFSET_STEP_MS), 154.0)
	_master_value = get_node("MasterSliderValue") as Label
	_bgm_value = get_node("BgmSliderValue") as Label
	_sfx_value = get_node("SfxSliderValue") as Label
	_offset_value = get_node("OffsetSliderValue") as Label
	var hint := Label.new()
	hint.name = "OffsetHint"
	hint.text = "음수 = 입력 판정을 앞당김\n양수 = 입력 판정을 늦춤"
	hint.position = Vector2(16, 214)
	hint.size = Vector2(288, 40)
	RetroTheme.apply_label(hint, 12, RetroTheme.TEXT)
	add_child(hint)
	_master_slider.value_changed.connect(_on_master)
	_bgm_slider.value_changed.connect(_on_bgm)
	_sfx_slider.value_changed.connect(_on_sfx)
	_offset_slider.value_changed.connect(_on_offset)


func _add_slider(node_name: String, caption: String, minimum: float, maximum: float, step: float, y: float) -> HSlider:
	var label := Label.new()
	label.name = node_name + "Caption"
	label.text = caption
	label.position = Vector2(16, y)
	label.size = Vector2(140, 18)
	RetroTheme.apply_label(label, 12, RetroTheme.TEXT)
	add_child(label)
	var value := Label.new()
	value.name = node_name + "Value"
	value.position = Vector2(180, y)
	value.size = Vector2(120, 18)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	RetroTheme.apply_label(value, 12, RetroTheme.TEXT)
	add_child(value)
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.position = Vector2(16, y + 18)
	slider.size = Vector2(288, 16)
	add_child(slider)
	return slider


func close_window() -> void:
	visible = false
	closed.emit()


func _on_master(value: float) -> void:
	GameSession.get_session().set_master_linear(value / 100.0)
	_set_percent(_master_value, value / 100.0)


func _on_bgm(value: float) -> void:
	GameSession.get_session().set_bgm_linear(value / 100.0)
	_set_percent(_bgm_value, value / 100.0)


func _on_sfx(value: float) -> void:
	GameSession.get_session().set_sfx_linear(value / 100.0)
	_set_percent(_sfx_value, value / 100.0)


func _on_offset(value: float) -> void:
	var session := GameSession.get_session()
	session.set_rhythm_input_offset_ms(int(value))
	_offset_slider.set_value_no_signal(session.rhythm_input_offset_ms)
	_set_offset_text(session.rhythm_input_offset_ms)


func _set_slider(slider: HSlider, label: Label, percent: float, from_user: bool) -> void:
	if slider == null:
		return
	if from_user:
		slider.value = percent
	else:
		slider.set_value_no_signal(percent)
	_set_percent(label, percent / 100.0)


func _set_percent(label: Label, linear: float) -> void:
	if label == null:
		return
	label.text = "%d%%" % roundi(clampf(linear, 0.0, 1.0) * 100.0)


func _set_offset_text(milliseconds: int) -> void:
	if _offset_value == null:
		return
	_offset_value.text = "%+d ms" % milliseconds
