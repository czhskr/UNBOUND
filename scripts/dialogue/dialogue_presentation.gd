extends Node

## 대사 신호만 받아 말풍선, 바, 장면 카메라를 맞춘다.

signal presentation_settled

const BUBBLE_SCENE := preload("res://scenes/ui/DialogueSpeechBubble.tscn")
const OVERLAY_SCENE := preload("res://scenes/ui/DialogueCinematicOverlay.tscn")

var _overlay: CanvasLayer
var _bubble: Control
var _anchor: Node2D
var _system_line: bool = false
var _input_frame: int = -1
var _close_left: int = 0
var _closing: bool = false


func _ready() -> void:
	_overlay = OVERLAY_SCENE.instantiate() as CanvasLayer
	add_child(_overlay)
	_bubble = BUBBLE_SCENE.instantiate() as Control
	_overlay.add_child(_bubble)
	var catcher := _overlay.get_node_or_null("DialogueClickCatcher") as CanvasItem
	if catcher != null:
		_overlay.move_child(catcher, -1)
	_overlay.connect(&"advance_requested", _on_advance_requested)
	_overlay.connect(&"dismissed", _on_dismissed)
	var runtime := _runtime()
	runtime.dialogue_started.connect(_on_started)
	runtime.line_changed.connect(_on_line_changed)
	runtime.dialogue_finished.connect(_on_finished)
	runtime.dialogue_cancelled.connect(_on_cancelled)


func _process(_delta: float) -> void:
	if _bubble == null or not _bubble.visible:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	if _system_line or _anchor == null or not is_instance_valid(_anchor):
		_bubble.call("place_system", viewport_size, 120.0)
		return
	var screen_pos: Vector2 = _anchor.get_global_transform_with_canvas().origin
	_bubble.call("place_above", screen_pos, viewport_size)


func _input(event: InputEvent) -> void:
	if not _dialogue_open():
		return
	if not _is_advance_event(event):
		return
	_progress()
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _is_advance_event(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed(&"dialogue_advance"):
		return true
	if event is not InputEventKey:
		return false
	var key := event as InputEventKey
	if not key.pressed:
		return false
	var code := key.keycode
	var physical := key.physical_keycode
	return code == KEY_J or code == KEY_K or physical == KEY_J or physical == KEY_K


func _on_started() -> void:
	_close_left = 0
	_input_frame = -1
	_overlay.call("show_bars", false)


func _on_line_changed(line: DialogueLine) -> void:
	if line == null:
		return
	var speaker := _speaker_id(line)
	_system_line = speaker == &"system"
	_anchor = null
	if not _system_line:
		_anchor = _anchor_for(speaker)
	_bubble.call("show_line", line)
	var cinematic := _cinematic()
	if cinematic != null:
		cinematic.focus_speaker(speaker, _anchor)


func _on_finished() -> void:
	_begin_close(false)


func _on_cancelled() -> void:
	_anchor = null
	_system_line = false
	_closing = false
	if _bubble != null:
		_bubble.call("hide_bubble")
	var cinematic := _cinematic()
	if cinematic != null:
		cinematic.restore(true)
	_close_left = 0
	_overlay.call("hide_bars", true)
	presentation_settled.emit()


func _on_advance_requested() -> void:
	_progress()


func _on_dismissed() -> void:
	_note_close_step()


func _progress() -> void:
	if not _dialogue_open():
		return
	if SceneFader.get_fader().transition_in_progress:
		return
	var frame := Engine.get_process_frames()
	if frame == _input_frame:
		return
	_input_frame = frame
	if bool(_bubble.call("is_line_typing")):
		_bubble.call("complete_current_line")
		return
	_runtime().advance()


func is_presentation_idle() -> bool:
	return not _closing


func _begin_close(immediate: bool) -> void:
	_anchor = null
	_system_line = false
	_closing = true
	if _bubble != null:
		_bubble.call("hide_bubble")
	_close_left = 1
	var cinematic := _cinematic()
	if cinematic != null:
		_close_left += 1
		if not cinematic.restore_finished.is_connected(_note_close_step):
			cinematic.restore_finished.connect(_note_close_step)
		cinematic.restore(immediate)
	_overlay.call("hide_bars", immediate)


func _note_close_step() -> void:
	if _close_left <= 0:
		return
	_close_left -= 1
	if _close_left > 0:
		return
	var cinematic := _cinematic()
	if cinematic != null and cinematic.restore_finished.is_connected(_note_close_step):
		cinematic.restore_finished.disconnect(_note_close_step)
	_closing = false
	_overlay.call("release_overlay")
	presentation_settled.emit()


func _dialogue_open() -> bool:
	return _runtime().is_dialogue_active


func _speaker_id(line: DialogueLine) -> StringName:
	var tagged := line.get_tag_value("speaker").strip_edges()
	if not tagged.is_empty():
		return StringName(tagged)
	var character_name := line.character.strip_edges()
	if character_name.is_empty():
		return &"player"
	return StringName(character_name.to_lower())


func _anchor_for(speaker_id: StringName) -> Node2D:
	for node in get_tree().get_nodes_in_group(&"dialogue_anchor"):
		var marker := node as Node2D
		if marker == null or not marker.has_meta(&"speaker_id"):
			continue
		if StringName(marker.get_meta(&"speaker_id")) == speaker_id:
			return marker
	return null


func _cinematic() -> DialogueCinematicController:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("DialogueCinematicController") as DialogueCinematicController


func _runtime() -> UnboundDialogueController:
	return get_node("/root/UnboundDialogue") as UnboundDialogueController
