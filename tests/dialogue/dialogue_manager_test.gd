extends Node2D

## Dialogue Manager 연동 확인용 장면. Entry에서는 재생하지 않는다.

const RESOURCE_PATH := "res://data/dialogue/tests/dialogue_manager_smoke.dialogue"


func _ready() -> void:
	var anchor := get_node_or_null("World/DummyPlayer/DialogueAnchor") as Node2D
	if anchor != null:
		anchor.add_to_group(&"dialogue_anchor")
		anchor.set_meta(&"speaker_id", &"player")
	var button := get_node_or_null("UI/StartButton") as Button
	if button != null:
		button.pressed.connect(start_test)
	call_deferred("start_test")


func start_test() -> void:
	var runtime := get_node("/root/UnboundDialogue") as UnboundDialogueController
	if runtime == null or runtime.is_dialogue_active:
		return
	var resource := load(RESOURCE_PATH) as DialogueResource
	if resource == null:
		push_error("Smoke dialogue resource did not load.")
		return
	runtime.start_dialogue(resource, "start", self)
