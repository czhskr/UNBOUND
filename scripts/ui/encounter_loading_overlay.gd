class_name EncounterLoadingOverlay
extends CanvasLayer

## 다음 조우 전 연출. ResourceLoader와 연결하지 않는다.
## 시간과 퍼센트 단계는 시험값이며 최종이 아니다.

const DURATION := 0.65
const COMPLETE_HOLD_SECONDS := 1.5
const STEPS: Array[int] = [0, 12, 28, 46, 73, 91, 100]
const WINDOW_SIZE := Vector2(360, 156)

var shown_percent: int = 0
var samples: PackedInt32Array = PackedInt32Array()
var play_count: int = 0
var holding_complete: bool = false

var _playing: bool = false
var _dimmer: ColorRect
var _window: Panel
var _fill: ColorRect
var _percent: Label
var _fill_width: float = 280.0


func is_playing() -> bool:
	return _playing


func play() -> void:
	if _playing:
		return
	play_count += 1
	_playing = true
	holding_complete = false
	visible = true
	samples = PackedInt32Array()
	_place()
	var slice := DURATION / float(STEPS.size())
	var index := 0
	while index < STEPS.size():
		_set_percent(STEPS[index])
		await get_tree().create_timer(slice).timeout
		if not is_inside_tree():
			return
		index += 1
	_set_percent(100)
	holding_complete = true
	await get_tree().create_timer(COMPLETE_HOLD_SECONDS).timeout
	holding_complete = false
	if not is_inside_tree():
		return
	_playing = false
	visible = false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	_dimmer = ColorRect.new()
	_dimmer.name = "Dimmer"
	_dimmer.color = Color(0, 0, 0, 0.45)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_dimmer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_dimmer)
	_window = Panel.new()
	_window.name = "Window"
	_window.custom_minimum_size = WINDOW_SIZE
	_window.size = WINDOW_SIZE
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.add_theme_stylebox_override(&"panel", RetroTheme.window_style())
	add_child(_window)
	var title_bar := ColorRect.new()
	title_bar.name = "TitleBar"
	title_bar.position = Vector2(4, 4)
	title_bar.size = Vector2(WINDOW_SIZE.x - 8, 24)
	title_bar.color = RetroTheme.TITLE_BAR
	title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(title_bar)
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "SYSTEM"
	title.position = Vector2(8, 2)
	title.size = Vector2(WINDOW_SIZE.x - 16, 20)
	RetroTheme.apply_label(title, 14, RetroTheme.TITLE_TEXT)
	title_bar.add_child(title)
	var message := Label.new()
	message.name = "MessageLabel"
	message.text = "다음 개체 불러오는 중..."
	message.position = Vector2(16, 44)
	message.size = Vector2(WINDOW_SIZE.x - 32, 24)
	RetroTheme.apply_label(message, 14, RetroTheme.TEXT)
	_window.add_child(message)
	var well := ColorRect.new()
	well.name = "ProgressWell"
	well.position = Vector2(16, 84)
	well.size = Vector2(_fill_width, 18)
	well.color = Color(0.55, 0.55, 0.52, 1)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(well)
	_fill = ColorRect.new()
	_fill.name = "ProgressFill"
	_fill.position = Vector2(2, 2)
	_fill.size = Vector2(0, 14)
	_fill.color = Color(0.10, 0.16, 0.38, 1)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(_fill)
	_percent = Label.new()
	_percent.name = "PercentLabel"
	_percent.text = "0%"
	_percent.position = Vector2(16, 110)
	_percent.size = Vector2(WINDOW_SIZE.x - 32, 24)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	RetroTheme.apply_label(_percent, 14, RetroTheme.TEXT)
	_window.add_child(_percent)
	_place()


func _set_percent(value: int) -> void:
	shown_percent = clampi(value, 0, 100)
	if samples.is_empty() or samples[samples.size() - 1] != shown_percent:
		samples.append(shown_percent)
	if _percent != null:
		_percent.text = "%d%%" % shown_percent
	if _fill != null:
		_fill.size.x = _fill_width * float(shown_percent) / 100.0


func _place() -> void:
	var viewport := get_viewport()
	var size := Vector2(1152, 648)
	if viewport != null:
		var visible_size := viewport.get_visible_rect().size
		if visible_size.x > 1.0 and visible_size.y > 1.0:
			size = visible_size
	if _dimmer != null:
		_dimmer.position = Vector2.ZERO
		_dimmer.size = size
	if _window != null:
		_window.position = (size - WINDOW_SIZE) * 0.5
