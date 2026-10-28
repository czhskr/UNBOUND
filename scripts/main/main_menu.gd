extends Control

## 레트로 창 메인 메뉴. 시작은 필수 리소스가 준비된 뒤에만 연다.

const WINDOW_SIZE := Vector2(320, 268)

var _loader: StartupPreload
var _loading_log: PackedStringArray = PackedStringArray()

@onready var _window: Panel = $RetroWindow
@onready var _start_button: Button = $RetroWindow/StartButton
@onready var _tutorial_button: Button = $RetroWindow/TutorialButton
@onready var _options_button: Button = $RetroWindow/OptionsButton
@onready var _exit_button: Button = $RetroWindow/ExitButton
@onready var _options: OptionsWindow = $OptionsWindow


func _ready() -> void:
	_apply_retro_style()
	_start_button.pressed.connect(_on_start_pressed)
	_tutorial_button.pressed.connect(_on_tutorial_pressed)
	_options_button.pressed.connect(_open_options)
	_exit_button.pressed.connect(_on_exit_pressed)
	if not _options.closed.is_connected(_place):
		_options.closed.connect(_place)
	_options.visible = false
	_start_button.disabled = true
	_start_button.text = "로딩중... 0%"
	_remember_loading_text()
	apply_platform_rules(OS.has_feature("web"))
	_place()
	_loader = StartupPreload.new()
	_loader.name = "StartupPreload"
	add_child(_loader)
	_loader.begin()
	if _loader.startup_ready:
		_show_start_ready()
	print("MAIN MENU")


func _process(_delta: float) -> void:
	if _loader == null or _start_button == null:
		return
	if _loader.failed:
		_start_button.disabled = true
		_start_button.text = "로딩 실패"
		_remember_loading_text()
		return
	if not _loader.startup_ready:
		_start_button.disabled = true
		_start_button.text = "로딩중... %d%%" % _loader.shown_percent
		_remember_loading_text()
		return
	_show_start_ready()


func apply_platform_rules(on_web: bool) -> void:
	_exit_button.visible = not on_web


func loading_log() -> PackedStringArray:
	return _loading_log


func _show_start_ready() -> void:
	if _start_button.text != "시작" or _start_button.disabled:
		_start_button.text = "시작"
		_start_button.disabled = false
		_remember_loading_text()


func _on_start_pressed() -> void:
	if _loader == null or not _loader.startup_ready or _start_button.disabled:
		return
	var fader := SceneFader.get_fader()
	if fader.transition_in_progress:
		return
	_start_button.disabled = true
	if GameSession.get_session().opening_seen:
		fader.go_to_entry()
	else:
		fader.go_to_opening()


func _on_tutorial_pressed() -> void:
	if SceneFader.get_fader().transition_in_progress:
		return
	SceneFader.get_fader().go_to_tutorial()


func _open_options() -> void:
	if SceneFader.get_fader().transition_in_progress or _options == null:
		return
	_options.sync_from_session()
	_options.visible = true
	_place()


func _on_exit_pressed() -> void:
	if SceneFader.get_fader().transition_in_progress or not _exit_button.visible:
		return
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _options == null or not _options.visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	_options.close_window()
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _apply_retro_style() -> void:
	_window.add_theme_stylebox_override(&"panel", RetroTheme.window_style())
	var title_bar := _window.get_node("TitleBar") as ColorRect
	title_bar.color = RetroTheme.TITLE_BAR
	RetroTheme.apply_label(_window.get_node("TitleBar/TitleLabel") as Label, 16, RetroTheme.TITLE_TEXT)
	RetroTheme.apply_button(_start_button, 16)
	RetroTheme.apply_button(_tutorial_button, 16)
	RetroTheme.apply_button(_options_button, 16)
	RetroTheme.apply_button(_exit_button, 16)


func _place() -> void:
	var viewport := get_viewport()
	var size := Vector2(1152, 648)
	if viewport != null:
		var visible := viewport.get_visible_rect().size
		if visible.x > 1.0 and visible.y > 1.0:
			size = visible
	_window.position = (size - WINDOW_SIZE) * 0.5
	if _options != null:
		_options.position = (size - OptionsWindow.WINDOW_SIZE) * 0.5


func _remember_loading_text() -> void:
	if _start_button == null:
		return
	if _loading_log.is_empty() or _loading_log[_loading_log.size() - 1] != _start_button.text:
		_loading_log.append(_start_button.text)
