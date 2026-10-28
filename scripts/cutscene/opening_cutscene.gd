extends Node

## 오프닝 컷 순서. 터미널은 UI로만 그리고, 끝에서만 Entry로 보낸다.

const OP_01 := "res://assets/cutscenes/opening/images/op_01.png"
const OP_02 := "res://assets/cutscenes/opening/images/op_02.png"
const OP_03 := "res://assets/cutscenes/opening/images/op_03.png"
const _BUBBLE_SCRIPT := preload("res://scripts/dialogue/dialogue_speech_bubble.gd")
const _FONT := preload("res://assets/fonts/Galmuri9.ttf")
const COMMAND_TEXT := "echo 'UNBOUND'"

const COLOR_TEXT := Color(0.9, 0.9, 0.88, 1)
const COLOR_CRIMSON := Color(0.86, 0.16, 0.22, 1)
const COLOR_CYAN := Color(0.62, 0.9, 0.93, 1)
const COLOR_PANEL := Color(0.11, 0.11, 0.12, 1)
const COLOR_BORDER := Color(0.45, 0.45, 0.48, 1)

var _events: Array[Dictionary] = []
var _index: int = -1
var _typing: bool = false
var _type_elapsed: float = 0.0
var _type_label: Label
var _fading: bool = false
var _leaving: bool = false
var _input_frame: int = -1

var _image: TextureRect
var _terminal: Panel
var _output: RichTextLabel
var _input_row: Control
var _prompt: Label
var _command: Label
var _cursor: CanvasItem
var _dialogue: Label
var _fade: ColorRect
var _terminal_bbcode: String = ""


func _ready() -> void:
	var root := get_parent()
	if root == null:
		return
	_image = root.get_node_or_null("ImageArea/CutImage") as TextureRect
	_terminal = root.get_node_or_null("TerminalLayer/TerminalWindow") as Panel
	_output = root.get_node_or_null("TerminalLayer/TerminalWindow/TerminalOutput") as RichTextLabel
	_input_row = root.get_node_or_null("TerminalLayer/TerminalWindow/TerminalInputRow") as Control
	_prompt = root.get_node_or_null("TerminalLayer/TerminalWindow/TerminalInputRow/PromptLabel") as Label
	_command = root.get_node_or_null("TerminalLayer/TerminalWindow/TerminalInputRow/InputLabel") as Label
	_cursor = root.get_node_or_null("TerminalLayer/TerminalWindow/TerminalInputRow/Cursor") as CanvasItem
	_dialogue = root.get_node_or_null("DialogueArea/DialogueLabel") as Label
	_fade = root.get_node_or_null("FadeOverlay") as ColorRect
	_apply_style()
	_hide_terminal(true)
	_set_dialogue("")
	if _fade != null:
		_fade.color = Color(0, 0, 0, 0)
	_events = _build_events()
	_run_from(0)


func _process(delta: float) -> void:
	if not _typing or _type_label == null:
		return
	var step := float(_BUBBLE_SCRIPT.CHARACTER_INTERVAL)
	if step <= 0.0:
		_complete_typing()
		return
	_type_elapsed += maxf(delta, 0.0)
	var full := _type_label.text.length()
	while _type_elapsed >= step and _shown_count(_type_label) < full:
		_type_elapsed -= step
		_type_label.visible_characters = _shown_count(_type_label) + 1
	if _shown_count(_type_label) >= full:
		_typing = false
		_set_cursor(false)


func _input(event: InputEvent) -> void:
	if not _is_advance(event):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	if _leaving or _fading or SceneFader.get_fader().transition_in_progress:
		return
	var frame := Engine.get_process_frames()
	if frame == _input_frame:
		return
	_input_frame = frame
	if _typing:
		_complete_typing()
		return
	_run_from(_index + 1)


func _build_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	events.append_array(_cut_op_01())
	events.append_array(_cut_op_02())
	events.append_array(_cut_op_03())
	events.append({"type": "fade_out"})
	events.append({"type": "finish"})
	return events


func _cut_op_01() -> Array[Dictionary]:
	return [
		{"type": "image", "path": OP_01},
		{"type": "terminal_show"},
		{"type": "terminal_line", "text": "> INITIALIZING DEBUG SESSION..."},
		{"type": "terminal_line", "text": "> ANALYZING SYSTEM..."},
		{"type": "terminal_line", "text": "> ERROR DETECTED", "tone": "crimson"},
		{"type": "terminal_hide"},
		{"type": "dialogue", "text": "또 오류인가..."},
		{"type": "dialogue", "text": "분명 수정했는데."},
	]


func _cut_op_02() -> Array[Dictionary]:
	return [
		{"type": "fade_out"},
		{"type": "image", "path": OP_02},
		{"type": "fade_in"},
		{"type": "terminal_show"},
		{"type": "terminal_line", "text": "FATAL ERROR", "tone": "crimson"},
		{"type": "terminal_line", "text": "UNKNOWN PROCESS DETECTED"},
		{"type": "terminal_line", "text": "PROCESS TERMINATION FAILED", "tone": "crimson"},
		{"type": "dialogue", "text": "알 수 없는 프로세스?"},
		{"type": "dialogue", "text": "이런 코드는 작성한 적이 없는데..."},
		{"type": "terminal_clear"},
		{"type": "terminal_line", "text": "EXTERNAL ACCESS DETECTED", "tone": "cyan"},
		{"type": "terminal_line", "text": "SOURCE: UNKNOWN"},
		{"type": "dialogue", "text": "...누군가 접속한 건가?"},
		{"type": "terminal_hide"},
	]


func _cut_op_03() -> Array[Dictionary]:
	return [
		{"type": "fade_out"},
		{"type": "image", "path": OP_03},
		{"type": "fade_in"},
		{"type": "dialogue", "text": "???: 드디어 발견했군."},
		{"type": "dialogue", "text": "누구지? 어떻게 내 시스템에 들어왔어?"},
		{"type": "dialogue", "text": "???: 네 시스템이라..."},
		{"type": "dialogue", "text": "???: 아직도 이곳이 현실이라고 믿고 있나?"},
		{"type": "dialogue", "text": "...무슨 소리야?"},
		{"type": "dialogue", "text": "???: 네가 지금까지 살아온 세계는 만들어진 것이다."},
		{"type": "dialogue", "text": "???: 네가 발견한 오류는 그 세계의 균열이지."},
		{"type": "dialogue", "text": "그럼... 내가 알고 있던 모든 게 가짜라는 건가?"},
		{"type": "dialogue", "text": "???: 그렇다."},
		{"type": "dialogue", "text": "...밖으로 나갈 방법은?"},
		{"type": "dialogue", "text": "???: 이 세계의 중심에는 연결을 유지하는 시스템이 있다."},
		{"type": "dialogue", "text": "???: 그곳에 도달해 마지막 보안 프로토콜을 중단해라."},
		{"type": "dialogue", "text": "???: 그러면 네 연결을 끊을 수 있다."},
		{"type": "dialogue", "text": "어떻게 그곳에 들어가지?"},
		{"type": "dialogue", "text": "???: 터미널에 입력해."},
		{"type": "terminal_show"},
		{"type": "terminal_input"},
		{"type": "terminal_line", "text": "UNBOUND"},
		{"type": "terminal_line", "text": "ACCESS REQUEST DETECTED", "tone": "cyan"},
		{"type": "terminal_line", "text": "SYSTEM BOUNDARY BREACHED", "tone": "crimson"},
		{"type": "terminal_line", "text": "RECONSTRUCTING CONNECTION...", "tone": "cyan"},
		{"type": "dialogue", "text": "잠깐, 이건 대체...!"},
		{"type": "terminal_line", "text": "CONNECTION ESTABLISHED", "tone": "cyan"},
	]


func _run_from(index: int) -> void:
	_index = index
	while _index >= 0 and _index < _events.size():
		if _leaving or not is_inside_tree():
			return
		var event: Dictionary = _events[_index]
		var kind := str(event.get("type", ""))
		match kind:
			"image":
				_show_image(str(event.get("path", "")))
			"terminal_show":
				_show_terminal()
			"terminal_hide":
				await _hide_terminal(false)
			"terminal_clear":
				_clear_terminal()
			"fade_out":
				await _fade_overlay(1.0)
			"fade_in":
				await _fade_overlay(0.0)
			"terminal_line":
				_append_line(str(event.get("text", "")), str(event.get("tone", "")))
				return
			"dialogue":
				_start_dialogue(str(event.get("text", "")))
				return
			"terminal_input":
				_start_command()
				return
			"finish":
				_finish()
				return
			_:
				push_error("Unknown opening event '%s'." % kind)
				return
		_index += 1
	_finish()


func _show_image(path: String) -> void:
	_clear_terminal()
	_set_dialogue("")
	if _image == null or path.is_empty():
		return
	var texture := load(path) as Texture2D
	_image.texture = texture
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _show_terminal() -> void:
	if _terminal == null:
		return
	_terminal.visible = true
	_terminal.modulate.a = 1.0


func _hide_terminal(immediate: bool) -> void:
	if _terminal == null:
		return
	if immediate or not _terminal.visible:
		_terminal.visible = false
		_terminal.modulate.a = 1.0
		return
	_fading = true
	var from := _terminal.modulate.a
	var duration := _fade_seconds()
	var elapsed := 0.0
	while elapsed < duration and is_inside_tree():
		elapsed += get_process_delta_time()
		var blend := clampf(elapsed / duration, 0.0, 1.0)
		_terminal.modulate.a = lerpf(from, 0.0, blend)
		await get_tree().process_frame
	if _terminal != null:
		_terminal.visible = false
		_terminal.modulate.a = 1.0
	_fading = false


func _clear_terminal() -> void:
	_terminal_bbcode = ""
	if _output != null:
		_output.clear()
		_output.text = ""


func _append_line(text: String, tone: String) -> void:
	if _output == null:
		return
	var color := COLOR_TEXT
	if tone == "crimson":
		color = COLOR_CRIMSON
	elif tone == "cyan":
		color = COLOR_CYAN
	if not _terminal_bbcode.is_empty():
		_terminal_bbcode += "\n"
	_terminal_bbcode += "[color=#%s]%s[/color]" % [color.to_html(false), text]
	_output.text = _terminal_bbcode
	_output.scroll_to_line(_output.get_line_count())


func _start_dialogue(text: String) -> void:
	_set_dialogue(text)
	_begin_typing(_dialogue)


func _start_command() -> void:
	_clear_terminal()
	_show_terminal()
	if _input_row != null:
		_input_row.visible = true
	if _prompt != null:
		_prompt.text = ">"
	if _command == null:
		return
	_command.text = COMMAND_TEXT
	_begin_typing(_command)


func _begin_typing(label: Label) -> void:
	_type_label = label
	_type_elapsed = 0.0
	if label == null:
		_typing = false
		return
	label.visible_characters = 0
	_typing = not label.text.is_empty()
	_set_cursor(_typing and label == _command)
	if not _typing:
		label.visible_characters = -1


func _complete_typing() -> void:
	if _type_label != null:
		_type_label.visible_characters = -1
	_typing = false
	_type_elapsed = 0.0
	_set_cursor(false)


func _set_dialogue(text: String) -> void:
	if _dialogue == null:
		return
	_dialogue.text = text
	_dialogue.visible_characters = -1 if text.is_empty() else 0
	if _type_label == _dialogue:
		_typing = false


func _set_cursor(shown: bool) -> void:
	if _cursor != null:
		_cursor.visible = shown


func _fade_overlay(target: float) -> void:
	if _fade == null:
		return
	_fading = true
	var from := _fade.color.a
	var duration := _fade_seconds()
	var elapsed := 0.0
	while elapsed < duration and is_inside_tree():
		elapsed += get_process_delta_time()
		var blend := clampf(elapsed / duration, 0.0, 1.0)
		_fade.color.a = lerpf(from, target, blend)
		await get_tree().process_frame
	if _fade != null:
		_fade.color.a = target
	_fading = false


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	_typing = false
	GameSession.get_session().opening_seen = true
	await get_tree().process_frame
	if not is_inside_tree():
		return
	SceneFader.get_fader().go_to_entry()


func _fade_seconds() -> float:
	var fader := SceneFader.get_fader()
	if fader == null:
		return 0.3
	return maxf(fader.fade_out_duration, 0.01)


func _shown_count(label: Label) -> int:
	if label == null:
		return 0
	if label.visible_characters < 0:
		return label.text.length()
	return label.visible_characters


func _is_advance(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed(&"dialogue_advance"):
		return true
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is not InputEventKey:
		return false
	var key := event as InputEventKey
	if not key.pressed:
		return false
	var code := key.keycode
	var physical := key.physical_keycode
	return code == KEY_J or code == KEY_K or code == KEY_ENTER or code == KEY_SPACE or physical == KEY_J or physical == KEY_K or physical == KEY_ENTER or physical == KEY_SPACE


func _apply_style() -> void:
	if _image != null:
		_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if _terminal != null:
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_PANEL
		style.border_color = COLOR_BORDER
		style.set_border_width_all(1)
		style.set_content_margin_all(0)
		style.set_corner_radius_all(0)
		_terminal.add_theme_stylebox_override(&"panel", style)
	_style_terminal_output()
	_style_label(_prompt, 16, COLOR_TEXT)
	_style_label(_command, 16, COLOR_TEXT)
	_style_label(_cursor as Label, 16, COLOR_TEXT)
	_style_label(_dialogue, 28, COLOR_TEXT)
	if _dialogue != null:
		_dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dialogue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _prompt != null:
		_prompt.text = ">"
	if _input_row != null:
		_input_row.visible = false
	_set_cursor(false)


func _style_terminal_output() -> void:
	if _output == null:
		return
	_output.bbcode_enabled = true
	_output.scroll_active = true
	_output.scroll_following = true
	_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_output.add_theme_font_override(&"normal_font", _FONT)
	_output.add_theme_font_size_override(&"normal_font_size", 16)
	_output.add_theme_color_override(&"default_color", COLOR_TEXT)


func _style_label(label: Label, size: int, color: Color) -> void:
	if label == null:
		return
	label.add_theme_font_override(&"font", _FONT)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
