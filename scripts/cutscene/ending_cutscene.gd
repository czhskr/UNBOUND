extends Node

## 엔딩은 end.png를 직접 연다. ending_*.png 순회는 이 시퀀스에서 쓰지 않는다.

signal finished

const END_IMAGE := "res://assets/cutscenes/ending/images/end.png"
const _BUBBLE_SCRIPT := preload("res://scripts/dialogue/dialogue_speech_bubble.gd")
const _FONT := preload("res://assets/fonts/Galmuri9.ttf")

const FADE_SECONDS := 0.25
const DEFAULT_HOLD_SECONDS := 1.0

const COLOR_TEXT := Color(0.9, 0.9, 0.88, 1)
const COLOR_CYAN := Color(0.62, 0.9, 0.93, 1)
const COLOR_PANEL := Color(0.11, 0.11, 0.12, 1)
const COLOR_BORDER := Color(0.45, 0.45, 0.48, 1)

var _events: Array[Dictionary] = []
var _index: int = -1
var _typing: bool = false
var _type_elapsed: float = 0.0
var _type_label: Label
var _fading: bool = false
var _holding: bool = false
var _leaving: bool = false
var _input_frame: int = -1
var _system_logged: bool = false

var _image: TextureRect
var _panel: Panel
var _log: Label
var _dialogue: Label
var _fade: ColorRect


func _ready() -> void:
	var root := get_parent()
	if root == null:
		return
	_image = root.get_node_or_null("ImageArea/CutImage") as TextureRect
	_panel = root.get_node_or_null("SystemLayer/SystemLogPanel") as Panel
	_log = root.get_node_or_null("SystemLayer/SystemLogPanel/LogLine") as Label
	_dialogue = root.get_node_or_null("DialogueArea/DialogueLabel") as Label
	_fade = root.get_node_or_null("FadeOverlay") as ColorRect
	_apply_style()
	_set_fade(0.0)
	_events = _build_events()
	_quiet_combat_leftovers()
	_run_from(0)


func _process(delta: float) -> void:
	if not _typing or _type_label == null:
		return
	_type_elapsed += delta
	var shown := int(_type_elapsed / float(_BUBBLE_SCRIPT.CHARACTER_INTERVAL))
	if shown >= _type_label.text.length():
		_complete_typing()
		return
	_type_label.visible_characters = shown


func _input(event: InputEvent) -> void:
	if not _is_advance(event):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	if _leaving or _fading or _holding or SceneFader.get_fader().transition_in_progress:
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
	return [
		{"type": "log", "text": "SYSTEM: 모든 보안 프로토콜이 중단되었습니다.", "tone": "text"},
		{"type": "log", "text": "SYSTEM: 연결 해제 요청을 확인했습니다.", "tone": "text"},
		{"type": "log", "text": "SYSTEM: 연결을 종료합니다.", "tone": "text"},
		{"type": "wait"},
		{"type": "log", "text": "DISCONNECTING...", "tone": "text"},
		{"type": "log", "text": "CONNECTION TERMINATED", "tone": "cyan"},
		{"type": "log", "text": "NEURAL LINK RELEASED", "tone": "cyan"},
		{"type": "present_image"},
		{"type": "dialogue", "text": "...여긴?"},
		{"type": "dialogue", "text": "이곳이... 진짜 현실인가?"},
		{"type": "dialogue", "text": "...돌아왔구나."},
		{"type": "fade_out"},
		{"type": "finish"},
	]


func _run_from(index: int) -> void:
	_index = index
	while _index >= 0 and _index < _events.size():
		if _leaving or not is_inside_tree():
			return
		var event: Dictionary = _events[_index]
		match str(event.get("type", "")):
			"log":
				_show_log(str(event.get("text", "")), str(event.get("tone", "text")))
				return
			"dialogue":
				_show_dialogue(str(event.get("text", "")))
				return
			"wait":
				await _auto_hold()
			"present_image":
				await _present_image()
			"fade_out":
				await _fade_to(1.0)
			"finish":
				_finish()
				return
		_index += 1


func _show_log(text: String, tone: String) -> void:
	if not _system_logged and text.begins_with("SYSTEM:"):
		_system_logged = true
		print("ENDING SYSTEM")
	if _dialogue != null:
		_dialogue.text = ""
		_dialogue.visible_characters = -1
	if _panel != null:
		_panel.visible = true
		_panel.modulate.a = 1.0
	_begin_typing(_log, text, _tone_color(tone))


func _show_dialogue(text: String) -> void:
	if _panel != null:
		_panel.visible = false
	_begin_typing(_dialogue, text, COLOR_TEXT)


func _present_image() -> void:
	_fading = true
	await _fade_to(1.0)
	if _panel != null:
		_panel.visible = false
	if _dialogue != null:
		_dialogue.text = ""
		_dialogue.visible_characters = -1
	if _image != null:
		var texture := load(END_IMAGE) as Texture2D
		if texture == null:
			push_error("Ending image is missing: %s" % END_IMAGE)
		_image.texture = texture
		_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_image.visible = true
	await _fade_to(0.0)
	_fading = false


func _auto_hold() -> void:
	_holding = true
	var start := Time.get_ticks_msec()
	var limit := int(DEFAULT_HOLD_SECONDS * 1000.0)
	while is_inside_tree() and not _leaving and Time.get_ticks_msec() - start < limit:
		await get_tree().process_frame
	_holding = false


func _fade_to(target: float) -> void:
	var from := 0.0 if _fade == null else _fade.color.a
	var start := Time.get_ticks_msec()
	var limit := maxi(int(FADE_SECONDS * 1000.0), 1)
	while is_inside_tree() and Time.get_ticks_msec() - start < limit:
		var blend := clampf(float(Time.get_ticks_msec() - start) / float(limit), 0.0, 1.0)
		_set_fade(lerpf(from, target, blend))
		await get_tree().process_frame
	_set_fade(target)


func _begin_typing(label: Label, text: String, color: Color) -> void:
	_type_label = label
	if label == null:
		_typing = false
		return
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.visible_characters = 0
	_type_elapsed = 0.0
	_typing = true
	if text.is_empty():
		_complete_typing()


func _complete_typing() -> void:
	if _type_label != null:
		_type_label.visible_characters = -1
	_typing = false


func _tone_color(tone: String) -> Color:
	if tone == "cyan":
		return COLOR_CYAN
	return COLOR_TEXT


func _set_fade(alpha: float) -> void:
	if _fade == null:
		return
	_fade.color.a = clampf(alpha, 0.0, 1.0)


func _apply_style() -> void:
	if _image != null:
		_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if _panel != null:
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_PANEL
		style.border_color = COLOR_BORDER
		style.set_border_width_all(1)
		style.set_content_margin_all(16)
		style.set_corner_radius_all(0)
		_panel.add_theme_stylebox_override(&"panel", style)
	_style_label(_log, 16, COLOR_TEXT)
	_style_label(_dialogue, 28, COLOR_TEXT)
	if _dialogue != null:
		_dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dialogue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _style_label(label: Label, size: int, color: Color) -> void:
	if label == null:
		return
	label.add_theme_font_override(&"font", _FONT)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)


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


func _quiet_combat_leftovers() -> void:
	GameAudio.stop_combat()
	var popup := get_tree().root.get_node_or_null("OverrideAcquiredPopup")
	if popup != null:
		popup.visible = false


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	_typing = false
	finished.emit()
	_quiet_combat_leftovers()
	await get_tree().process_frame
	_go_to_next()


func _go_to_next() -> void:
	SceneFader.get_fader().go_to_main_menu()
