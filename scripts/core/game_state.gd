class_name GameSession
extends Node

## 메모리 세션 상태. 전투 노드 참조와 세이브 파일은 두지 않는다.

enum StageResult { NONE, CLEARED, ROLLBACK }
enum Difficulty { EASY, NORMAL, HARD }

const DEFAULT_FORM_ID := &"echo"
const STAGE_THE_VEIL := &"the_veil"
## 리듬 입력 보정. 판정창 폭은 바꾸지 않는다.
const RHYTHM_OFFSET_MIN_MS := -150
const RHYTHM_OFFSET_MAX_MS := 150
const RHYTHM_OFFSET_STEP_MS := 5
## 난이도별 HIT/PARRY 허용 폭.
const DIFFICULTY_WINDOW_EASY := 0.16
const DIFFICULTY_WINDOW_NORMAL := 0.12
const DIFFICULTY_WINDOW_HARD := 0.09
const AUDIO_BUS_BGM := "BGM"
const AUDIO_BUS_SFX := "SFX"

var current_stage_id: StringName = &""
var unlocked_stage_ids: Array[StringName] = [&"the_veil"]
var cleared_stage_ids: Array[StringName] = []
var last_stage_result: StageResult = StageResult.NONE
## 장착 중인 오버라이드. 세이브는 없다.
var current_form_id: StringName = DEFAULT_FORM_ID
var acquired_form_ids: Array[StringName] = [&"echo"]
var _reported_missing_default_form: bool = false
## 0~1 선형 음량과 입력 보정. 세이브는 없다.
var master_linear: float = 0.5
var bgm_linear: float = 1.0
var sfx_linear: float = 1.0
var rhythm_input_offset_ms: int = 0
## 전투 중 획득은 여기에만 쌓고, Entry가 열린 뒤에 순서대로 보여 준다.
var pending_override_notifications: Array[StringName] = []
## HIT/PARRY 허용 폭. 세이브는 없다. 기본은 보통이다.
var difficulty: Difficulty = Difficulty.NORMAL
## Entry 스테이지 선택. 재진입해도 유지하고, 새 세션만 허상이다.
var selected_stage_id: StringName = STAGE_THE_VEIL
## 적별 조우 대사. 세이브는 없다. 새 실행이면 비운다.
var encounter_dialogue_state: Dictionary = {}
## 이번 실행에서 오프닝을 끝까지 봤는지. 시작 버튼을 누른 순간에는 올리지 않는다.
var opening_seen: bool = false
## 시작 전 필수 리소스를 한 번 읽었는지. 세이브는 없다.
var startup_resources_ready: bool = false


static func get_session() -> GameSession:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState") as GameSession


func _ready() -> void:
	ensure_defaults()
	validate_current_form()
	ensure_audio_buses()
	apply_audio_volumes()


func ensure_defaults() -> void:
	if not FormRegistry.has_form(DEFAULT_FORM_ID):
		if not _reported_missing_default_form:
			_reported_missing_default_form = true
			push_error("Default form 'echo' is missing from FormRegistry.")
	elif not acquired_form_ids.has(DEFAULT_FORM_ID):
		acquired_form_ids.append(DEFAULT_FORM_ID)
	for unlocked_id in StageRegistry.default_unlocked_ids():
		if not unlocked_stage_ids.has(unlocked_id):
			unlocked_stage_ids.append(unlocked_id)
	if unlocked_stage_ids.is_empty():
		unlocked_stage_ids.append(STAGE_THE_VEIL)


func start_stage(stage_id: StringName) -> void:
	current_stage_id = stage_id
	last_stage_result = StageResult.NONE


func complete_stage(stage_id: StringName) -> StringName:
	if not StageRegistry.has_stage(stage_id):
		push_error("complete_stage received unknown stage '%s'." % stage_id)
		return &""
	current_stage_id = stage_id
	last_stage_result = StageResult.CLEARED
	mark_stage_cleared(stage_id)
	var definition := StageRegistry.get_stage(stage_id)
	if definition == null or definition.next_stage_id == &"":
		return &""
	if not StageRegistry.has_stage(definition.next_stage_id):
		push_warning(
			"Stage '%s' points at unknown next stage '%s'."
			% [stage_id, definition.next_stage_id]
		)
		return &""
	if unlock_stage(definition.next_stage_id):
		return definition.next_stage_id
	return &""


func mark_stage_cleared(stage_id: StringName) -> bool:
	if stage_id == &"" or not StageRegistry.has_stage(stage_id):
		push_error("mark_stage_cleared received unknown stage '%s'." % stage_id)
		return false
	if cleared_stage_ids.has(stage_id):
		return false
	cleared_stage_ids.append(stage_id)
	return true


func is_stage_cleared(stage_id: StringName) -> bool:
	return cleared_stage_ids.has(stage_id)


func unlock_stage(stage_id: StringName) -> bool:
	if stage_id == &"" or not StageRegistry.has_stage(stage_id):
		push_error("unlock_stage received unknown stage '%s'." % stage_id)
		return false
	if unlocked_stage_ids.has(stage_id):
		return false
	unlocked_stage_ids.append(stage_id)
	return true


func rollback_stage(stage_id: StringName) -> void:
	current_stage_id = stage_id
	last_stage_result = StageResult.ROLLBACK


func is_stage_unlocked(stage_id: StringName) -> bool:
	return unlocked_stage_ids.has(stage_id)


func consume_last_stage_result() -> StageResult:
	var result := last_stage_result
	last_stage_result = StageResult.NONE
	return result


func acquire_form(form_id: StringName) -> bool:
	if form_id == &"" or not FormRegistry.has_form(form_id):
		push_error("Cannot acquire unknown form '%s'." % form_id)
		return false
	if acquired_form_ids.has(form_id):
		return false
	acquired_form_ids.append(form_id)
	if not pending_override_notifications.has(form_id):
		pending_override_notifications.append(form_id)
	return true


func has_form(form_id: StringName) -> bool:
	return acquired_form_ids.has(form_id)


func equip_form(form_id: StringName) -> bool:
	if not FormRegistry.has_form(form_id):
		push_warning("Cannot equip unknown form '%s'." % form_id)
		return false
	if not has_form(form_id):
		push_warning("Cannot equip unacquired form '%s'." % form_id)
		return false
	current_form_id = form_id
	return true


func get_current_form_id() -> StringName:
	return current_form_id


func get_current_form() -> FormDefinition:
	validate_current_form()
	if not FormRegistry.has_form(current_form_id):
		return null
	return FormRegistry.get_form(current_form_id)


func validate_current_form() -> void:
	if not FormRegistry.has_form(DEFAULT_FORM_ID):
		if not _reported_missing_default_form:
			_reported_missing_default_form = true
			push_error("Default form 'echo' is missing from FormRegistry.")
		return
	if not has_form(DEFAULT_FORM_ID):
		acquired_form_ids.append(DEFAULT_FORM_ID)
	if current_form_id != &"" and FormRegistry.has_form(current_form_id) and has_form(current_form_id):
		return
	push_error("current_form_id '%s' is invalid. Falling back to echo." % current_form_id)
	current_form_id = DEFAULT_FORM_ID


func final_attack_power(form_id: StringName) -> int:
	var form := FormRegistry.get_form(form_id)
	if form == null:
		return 0
	return form.base_attack_power


func final_max_hp(form_id: StringName) -> int:
	var form := FormRegistry.get_form(form_id)
	if form == null:
		return 0
	return form.base_max_hp


func final_attack_count(form_id: StringName) -> int:
	var form := FormRegistry.get_form(form_id)
	if form == null:
		return 0
	return form.base_attack_count


func ensure_audio_buses() -> void:
	_ensure_bus(AUDIO_BUS_BGM)
	_ensure_bus(AUDIO_BUS_SFX)


func apply_audio_volumes() -> void:
	_apply_bus_linear("Master", master_linear)
	_apply_bus_linear(AUDIO_BUS_BGM, bgm_linear)
	_apply_bus_linear(AUDIO_BUS_SFX, sfx_linear)


func set_master_linear(value: float) -> void:
	master_linear = clampf(value, 0.0, 1.0)
	_apply_bus_linear("Master", master_linear)


func set_bgm_linear(value: float) -> void:
	bgm_linear = clampf(value, 0.0, 1.0)
	_apply_bus_linear(AUDIO_BUS_BGM, bgm_linear)


func set_sfx_linear(value: float) -> void:
	sfx_linear = clampf(value, 0.0, 1.0)
	_apply_bus_linear(AUDIO_BUS_SFX, sfx_linear)


func set_rhythm_input_offset_ms(value: int) -> void:
	var step := maxi(RHYTHM_OFFSET_STEP_MS, 1)
	var stepped := int(round(float(value) / float(step))) * step
	rhythm_input_offset_ms = clampi(stepped, RHYTHM_OFFSET_MIN_MS, RHYTHM_OFFSET_MAX_MS)


func rhythm_input_offset_seconds() -> float:
	return float(rhythm_input_offset_ms) / 1000.0


func difficulty_hit_window() -> float:
	match difficulty:
		Difficulty.EASY:
			return DIFFICULTY_WINDOW_EASY
		Difficulty.HARD:
			return DIFFICULTY_WINDOW_HARD
		_:
			return DIFFICULTY_WINDOW_NORMAL


func difficulty_label() -> String:
	match difficulty:
		Difficulty.EASY:
			return "쉬움"
		Difficulty.HARD:
			return "어려움"
		_:
			return "보통"


func cycle_difficulty(step: int) -> void:
	var index := posmod(int(difficulty) + step, 3)
	if index == 0:
		difficulty = Difficulty.EASY
	elif index == 1:
		difficulty = Difficulty.NORMAL
	else:
		difficulty = Difficulty.HARD


func resolve_encounter_dialogue(enemy_id: StringName, dialogue_set: EncounterDialogueSet, same_override: bool = false) -> DialogueResource:
	return EncounterDialogueResolver.resolve(encounter_dialogue_state, enemy_id, dialogue_set, same_override)


func reset_encounter_dialogue_history() -> void:
	encounter_dialogue_state.clear()


func stage_display_name(stage_id: StringName) -> String:
	var definition := StageRegistry.get_stage(stage_id)
	if definition == null or definition.display_name.is_empty():
		return String(stage_id)
	return definition.display_name


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _apply_bus_linear(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var volume := -80.0
	if linear > 0.001:
		volume = linear_to_db(linear)
	AudioServer.set_bus_volume_db(index, volume)
