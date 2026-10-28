class_name PauseMenu
extends CanvasLayer

## Entry와 StageCombat이 같이 쓰는 일시정지.
## 창 이름과 크기는 시험값이며 최종이 아니다.

enum Context { COMBAT, HUB }

const WINDOW_SIZE := Vector2(280, 196)
## 복귀 숫자의 총 시간. 시험값이며 최종 타이밍이 아니다.
const RESUME_COUNTDOWN_TOTAL := 2.0
const RESUME_COUNTDOWN_STEPS := 3
const RESUME_STEP_SECONDS := RESUME_COUNTDOWN_TOTAL / 3.0

var context: Context = Context.COMBAT

var _open: bool = false
var _counting: bool = false
var _dimmer: ColorRect
var _window: Panel
var _count_label: Label
var _options: OptionsWindow
var _resume_button: Button
var _options_button: Button
var _exit_button: Button


static func mount(scene: Node, next_context: Context = Context.COMBAT) -> void:
	if scene == null or scene.get_node_or_null("PauseMenu") != null or scene.has_meta(&"_pause_menu_pending"):
		return
	scene.set_meta(&"_pause_menu_pending", true)
	var menu := (load("res://scenes/ui/PauseMenu.tscn") as PackedScene).instantiate() as PauseMenu
	menu.name = "PauseMenu"
	menu.context = next_context
	scene.add_child.call_deferred(menu)


func is_open() -> bool:
	return _open


func is_counting() -> bool:
	return _counting


func countdown_text() -> String:
	if _count_label == null or not _count_label.visible:
		return ""
	return _count_label.text


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if _counting:
		if event is InputEventKey:
			_mark_handled()
		return
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		if _open and event is InputEventKey:
			_mark_handled()
		return
	_mark_handled()
	if not _open:
		if _can_open():
			open_menu()
		return
	if _options != null and _options.visible:
		_options.close_window()
		return
	resume_pause()


func open_menu() -> void:
	if _open or _counting or not _can_open():
		return
	if context == Context.COMBAT:
		var encounter := _encounter()
		if encounter == null:
			return
		encounter.set_combat_paused(true)
	_open = true
	visible = true
	if _window != null:
		_window.visible = true
	if _dimmer != null:
		_dimmer.visible = true
	if _count_label != null:
		_count_label.visible = false
		_count_label.text = ""
	if _options != null:
		_options.visible = false
	_place()


func resume_pause() -> void:
	if not _open or _counting:
		return
	_open = false
	if _options != null:
		_options.visible = false
	if context != Context.COMBAT:
		visible = false
		return
	_begin_countdown()


func exit_pause() -> void:
	if not _open or SceneFader.get_fader().transition_in_progress:
		return
	if context == Context.HUB:
		SceneFader.get_fader().go_to_main_menu()
		return
	SceneFader.get_fader().go_to_entry()


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
	title.text = "PAUSE"
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
	close.pressed.connect(resume_pause)
	_window.add_child(close)
	_resume_button = _add_button("ResumeButton", "돌아가기", Vector2(24, 48))
	_options_button = _add_button("OptionsButton", "옵션", Vector2(24, 92))
	_exit_button = _add_button("ExitButton", "나가기", Vector2(24, 136))
	_resume_button.pressed.connect(resume_pause)
	_options_button.pressed.connect(_show_options)
	_exit_button.pressed.connect(exit_pause)
	_options = (load("res://scenes/ui/OptionsWindow.tscn") as PackedScene).instantiate() as OptionsWindow
	_options.name = "OptionsWindow"
	_options.visible = false
	add_child(_options)
	_count_label = Label.new()
	_count_label.name = "CountdownLabel"
	_count_label.visible = false
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.size = Vector2(240, 140)
	RetroTheme.apply_label(_count_label, 96, RetroTheme.TITLE_TEXT)
	add_child(_count_label)
	_place()


func _add_button(node_name: String, text: String, at: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = at
	button.size = Vector2(232, 32)
	RetroTheme.apply_button(button, 14)
	_window.add_child(button)
	return button


func _begin_countdown() -> void:
	if _counting:
		return
	_counting = true
	if _window != null:
		_window.visible = false
	if _dimmer != null:
		_dimmer.visible = false
	visible = true
	_run_countdown()


func _run_countdown() -> void:
	if _count_label == null:
		_counting = false
		return
	_count_label.visible = true
	var step := 0
	while step < RESUME_COUNTDOWN_STEPS:
		var digit := RESUME_COUNTDOWN_STEPS - step
		_count_label.text = str(digit)
		_place()
		await get_tree().create_timer(RESUME_STEP_SECONDS).timeout
		if not is_inside_tree() or not _counting:
			return
		step += 1
	_count_label.visible = false
	_count_label.text = ""
	_counting = false
	visible = false
	var encounter := _encounter()
	if encounter != null and encounter.is_combat_paused():
		encounter.set_combat_paused(false)


func _can_open() -> bool:
	if _counting or SceneFader.get_fader().transition_in_progress:
		return false
	var dialogue := get_tree().root.get_node_or_null("UnboundDialogue")
	if dialogue != null and bool(dialogue.get("is_dialogue_active")):
		return false
	if context == Context.HUB:
		var host := get_parent()
		if host != null and host.has_method("can_open_pause"):
			return bool(host.call("can_open_pause"))
		return true
	var encounter := _encounter()
	return encounter != null and encounter.is_combat_active()


func _place() -> void:
	var viewport := get_viewport()
	var size := Vector2(1152, 648)
	if viewport != null:
		var visible := viewport.get_visible_rect().size
		if visible.x > 1.0 and visible.y > 1.0:
			size = visible
	if _dimmer != null:
		_dimmer.position = Vector2.ZERO
		_dimmer.size = size
	if _window != null:
		_window.position = (size - WINDOW_SIZE) * 0.5
	if _options != null:
		_options.position = (size - OptionsWindow.WINDOW_SIZE) * 0.5
	if _count_label != null:
		_count_label.position = (size - _count_label.size) * 0.5


func _show_options() -> void:
	if _options == null:
		return
	_options.sync_from_session()
	_options.visible = true
	_place()


func _encounter() -> EncounterController:
	var root := get_parent()
	if root == null:
		return null
	return root.get_node_or_null("EncounterController") as EncounterController


func _mark_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
