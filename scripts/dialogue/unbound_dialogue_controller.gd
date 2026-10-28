class_name UnboundDialogueController
extends Node

## 애드온 Dialogue Manager의 줄 진행만 맡는다. 말풍선과 카메라는 건드리지 않는다.

signal dialogue_started
signal line_changed(line: DialogueLine)
signal dialogue_finished
signal dialogue_cancelled

var is_dialogue_active: bool = false
var is_waiting_for_input: bool = false
var current_resource: DialogueResource
var current_line: DialogueLine

var _session: int = 0
var _fetching: bool = false
var _scene_controller: Node


func scene_controller() -> Node:
	return _scene_controller


func start_dialogue(resource: DialogueResource, cue: String = "", scene_controller: Node = null) -> void:
	if is_dialogue_active or resource == null:
		if resource == null:
			push_error("Dialogue resource is missing.")
		return
	_session += 1
	var session := _session
	is_dialogue_active = true
	is_waiting_for_input = false
	current_resource = resource
	current_line = null
	_scene_controller = scene_controller
	dialogue_started.emit()
	await _fetch_line(cue, session)


func advance() -> void:
	if not is_dialogue_active or _fetching or not is_waiting_for_input or current_line == null:
		return
	is_waiting_for_input = false
	var next_id := current_line.next_id
	await _fetch_line(next_id, _session)


func cancel() -> void:
	if not is_dialogue_active:
		return
	_session += 1
	_clear_runtime()
	dialogue_cancelled.emit()


func _fetch_line(key: String, session: int) -> void:
	_fetching = true
	var addon := Engine.get_singleton(&"DialogueManager")
	var line: DialogueLine = await addon.get_next_dialogue_line(current_resource, key)
	if session != _session:
		return
	_fetching = false
	if line == null:
		_clear_runtime()
		dialogue_finished.emit()
		return
	if not line.responses.is_empty():
		push_warning("Dialogue responses are not supported.")
		_clear_runtime()
		dialogue_finished.emit()
		return
	current_line = line
	is_waiting_for_input = true
	line_changed.emit(line)


func _clear_runtime() -> void:
	_fetching = false
	is_dialogue_active = false
	is_waiting_for_input = false
	current_resource = null
	current_line = null
	_scene_controller = null
