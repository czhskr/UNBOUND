class_name StageDefinition
extends Resource

## 스테이지 신원, 씬, 비주얼, 조우, 다음 스테이지 링크만 담는다.

@export var stage_id: StringName
@export var display_name: String = ""
@export var scene_path: String = ""
## 더 이상 화면을 고르지 않는다. 실제 화면은 visual_definition이다.
@export var background_theme_id: StringName
@export var visual_definition: StageVisualDefinition
## 스테이지 동안 반복하는 BGM. 적 전환으로는 바꾸지 않는다.
@export var bgm: AudioStream
@export var encounter_ids: Array[StringName] = []
@export var next_stage_id: StringName
@export var unlocked_by_default: bool = false
## false면 목록에는 있어도 입장할 씬이 없다.
@export var implemented: bool = true
## 기존 EnemyDefinition을 그대로 참조한다. ID 문자열로 다시 찾지 않는다.
@export var encounters: Array[EnemyDefinition] = []


func validate() -> bool:
	var valid := true
	if stage_id == &"":
		push_error("StageDefinition stage_id is empty.")
		valid = false
	if implemented and scene_path.strip_edges().is_empty():
		push_error("StageDefinition %s scene_path is empty." % stage_id)
		valid = false
	if implemented and encounters.is_empty():
		push_warning("StageDefinition %s has no encounters." % stage_id)
	if visual_definition == null:
		push_error("StageDefinition %s has no visual definition." % stage_id)
	else:
		visual_definition.validate()
	if not encounter_ids.is_empty() and encounter_ids.size() != encounters.size():
		push_error("StageDefinition %s encounter_ids do not match encounters." % stage_id)
		valid = false
	for index in encounters.size():
		var enemy := encounters[index]
		if enemy == null:
			push_error("StageDefinition %s encounter %s is null." % [stage_id, index])
			valid = false
			continue
		if index < encounter_ids.size() and enemy.enemy_id != encounter_ids[index]:
			push_error(
				"StageDefinition %s encounter %s id is %s, resource is %s."
				% [stage_id, index, encounter_ids[index], enemy.enemy_id]
			)
			valid = false
	return valid
