class_name EncounterController
extends Node

## EnemyDefinition 배열만 순서대로 붙인다. 마지막 처치가 스테이지 클리어다.
## Arc 처치는 그 복귀 대신 엔딩 컷씬으로 보낸다.

const ENEMY_SCENE := preload("res://scenes/combat/actors/Enemy.tscn")
const ENCOUNTER_LOADING_SCENE := preload("res://scenes/ui/EncounterLoadingOverlay.tscn")
## 사망 애니메이션이 끝난 뒤 마지막 프레임을 유지하는 시간. 시험값이며 최종이 아니다.
const ENEMY_DEATH_HOLD_SECONDS := 2.0
const TEST_ENCOUNTERS: Array[EnemyDefinition] = [
	preload("res://data/enemies/definitions/test_enemy_a.tres"),
	preload("res://data/enemies/definitions/test_enemy_b.tres"),
	preload("res://data/enemies/definitions/test_enemy_c.tres"),
	preload("res://data/enemies/definitions/test_skill_enemy.tres"),
]

enum Phase { NORMAL_ENCOUNTERS, STAGE_CLEAR, FAILED }

@export var encounters: Array[EnemyDefinition] = []
## 남은 씬 값. 조우 진행에는 쓰지 않는다.
@export var encounter_transition_seconds: float = 0.75
@export var stage: Node2D
@export var spawn_point: Node2D
@export var enemy_hp: ProgressBar
@export var rhythm: RhythmController
@export var combat_controller: Node
## StageCombat만 Entry로 돌아간다. CombatTest는 끄고 둔다.
@export var return_to_hub: bool = false
## CombatTest는 획득과 해금이 세션에 남지 않게 끈다.
@export var progression_enabled: bool = true
## Clear / Rollback 표시 후 복귀까지. 임시값이다.
@export var result_hold_seconds: float = 1.0

var phase: Phase = Phase.NORMAL_ENCOUNTERS
var current_index: int = 0
var current_enemy: Enemy = null
var input_blocked: bool = false
var sequence_cleared: bool = false
var sequence_failed: bool = false
var stage_cleared: bool = false

var _player: CombatActor = null
var _waiting_for_death: bool = false
var _transitioning: bool = false
var _transition_skip_frame: bool = false
var _transition_left: float = 0.0
var _stage_resolved: bool = false
var _return_left: float = -1.0
var _configured_from_definition: bool = false
var _spawned_initial: bool = false
var active_stage_id: StringName = &""
var rhythm_hold: bool = false
var is_dialogue_lock_active: bool = false
## 조우 시작 전 테스트 대사. 스토리 스테이지는 비워 둔다.
@export var intro_dialogue_resource: DialogueResource
@export var intro_dialogue_cue: String = ""
## 처치 후 대사는 아직 재생하지 않는다. 연결만 남겨 둔다.
@export var outro_dialogue_resource: DialogueResource
@export var outro_dialogue_cue: String = ""
var _combat_started: bool = false
var _combat_paused: bool = false
var _dialogue_token: int = 0
var _rhythm_panel_visible: bool = true
var _hyper_running: bool = false
var _hyper_token: int = 0
var _sequence_token: int = 0
var _arrival_transition_count: int = -1
var _hyper_played_ids: Array[StringName] = []


func hides_speed_overlay() -> bool:
	return is_dialogue_lock_active or _hyper_running or rhythm_hold


func _refresh_vector_stack_indicator() -> void:
	var host := get_parent()
	if host == null:
		return
	var indicator := host.get_node_or_null("VectorStackIndicator")
	if indicator != null and indicator.has_method("refresh"):
		indicator.call("refresh")


func _ready() -> void:
	if not _bind_scene():
		return
	# 부모 StageCombat._ready가 definition을 넣은 뒤에 스폰한다.
	# CombatTest처럼 definition이 없으면 다음 프레임에 테스트 조우를 쓴다.
	call_deferred("_ensure_spawn")


func setup_stage(definition: StageDefinition) -> void:
	if definition == null:
		push_error("Encounter setup received no StageDefinition.")
		return
	_configured_from_definition = true
	active_stage_id = definition.stage_id
	encounters.clear()
	for enemy in definition.encounters:
		if enemy != null:
			encounters.append(enemy)
	_ensure_spawn()


func _bind_scene() -> bool:
	if stage == null:
		stage = _node_at("../Stage", "../World") as Node2D
	if spawn_point == null:
		spawn_point = _node_at("../Stage/EnemySpawnPoint", "../World/EnemySpawnPoint") as Node2D
	if enemy_hp == null:
		enemy_hp = _node_at("../EnemyHP", "../UI/Layout/EnemyHP") as ProgressBar
	if rhythm == null:
		rhythm = get_node_or_null("../RhythmController") as RhythmController
	if combat_controller == null:
		combat_controller = get_node_or_null("../CombatTestController")
	_player = _node_at("../Stage/Player", "../World/Player") as CombatActor
	if stage == null or spawn_point == null or rhythm == null or _player == null:
		push_error("EncounterController is missing stage, spawn, rhythm, or player.")
		return false
	if not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)
	_ensure_effects()
	_ensure_loading_overlay()
	return true


func _ensure_spawn() -> void:
	if _spawned_initial or stage == null:
		return
	if not _configured_from_definition and encounters.is_empty():
		encounters.assign(TEST_ENCOUNTERS)
	_spawned_initial = true
	_start_encounter_sequence(true)


func request_combat_dialogue(resource: DialogueResource, cue: String) -> void:
	intro_dialogue_resource = resource
	intro_dialogue_cue = cue
	if _hyper_running:
		return
	if _combat_started:
		if _intro_dialogue_cue_valid():
			_play_side_dialogue()
		elif resource != null:
			push_warning("Intro dialogue cue is empty. Skipping dialogue.")
		return
	_start_encounter_sequence(true)


func _play_side_dialogue() -> void:
	if not await _play_intro_dialogue():
		_unlock_dialogue()
		input_blocked = true
		return
	_unlock_dialogue()


func is_combat_active() -> bool:
	return _combat_started and phase == Phase.NORMAL_ENCOUNTERS and not _hyper_running and not is_dialogue_lock_active and not _combat_paused and not input_blocked and not rhythm_hold and not _waiting_for_death


func is_combat_paused() -> bool:
	return _combat_paused


func set_combat_paused(paused: bool) -> void:
	if _combat_paused == paused:
		return
	_combat_paused = paused
	if paused:
		input_blocked = true
		if rhythm != null:
			rhythm.set_dialogue_paused(true)
		_set_actor_dialogue_pause(true)
		_refresh_vector_stack_indicator()
		return
	if rhythm != null and not is_dialogue_lock_active:
		rhythm.set_dialogue_paused(false)
	if not is_dialogue_lock_active:
		_set_actor_dialogue_pause(false)
	if not _waiting_for_death and phase == Phase.NORMAL_ENCOUNTERS and not is_dialogue_lock_active and not _hyper_running:
		input_blocked = false
	_refresh_vector_stack_indicator()


func _process(delta: float) -> void:
	if _combat_paused:
		input_blocked = true
		return
	if _hyper_running and _transition_changed():
		_sequence_token += 1
		_hyper_token += 1
		_dialogue_token += 1
		_hyper_running = false
		_cancel_hyper()
		_unlock_dialogue()
		input_blocked = true
		return
	if is_dialogue_lock_active:
		return
	var step := maxf(delta, 0.0)
	if _return_left >= 0.0:
		_return_left -= step
		if _return_left <= 0.0:
			if SceneFader.get_fader().transition_in_progress:
				_return_left = 0.0
			else:
				_return_left = -1.0
				if return_to_hub and is_inside_tree():
					SceneFader.get_fader().go_to_entry()


func _prepare_dialogue_enemy() -> void:
	if current_index < 0 or current_index >= encounters.size():
		return
	var definition := encounters[current_index]
	if definition == null:
		return
	_place_enemy(definition)
	input_blocked = true


func _lock_for_dialogue() -> void:
	is_dialogue_lock_active = true
	input_blocked = true
	if rhythm != null:
		rhythm.set_dialogue_paused(true)
		_set_rhythm_panel_visible(false)
	_set_actor_health_visible(false)
	_set_actor_dialogue_pause(true)
	_refresh_vector_stack_indicator()


func _unlock_dialogue() -> void:
	is_dialogue_lock_active = false
	if rhythm != null:
		rhythm.set_dialogue_paused(false)
		_set_rhythm_panel_visible(true)
	_set_actor_dialogue_pause(false)
	if not _waiting_for_death and phase == Phase.NORMAL_ENCOUNTERS:
		input_blocked = false
	_refresh_vector_stack_indicator()


func _set_actor_health_visible(shown: bool) -> void:
	var bars := get_node_or_null("../ActorHealthBars")
	if bars != null:
		bars.visible = shown


func _set_rhythm_panel_visible(shown: bool) -> void:
	if rhythm == null or rhythm.panel == null:
		return
	if not shown:
		if rhythm.panel.visible:
			_rhythm_panel_visible = true
		rhythm.panel.visible = false
		return
	rhythm.panel.visible = _rhythm_panel_visible


func _set_actor_dialogue_pause(paused: bool) -> void:
	if _player != null and _player.has_method("set_dialogue_paused"):
		_player.call("set_dialogue_paused", paused)
	if current_enemy != null and is_instance_valid(current_enemy) and current_enemy.has_method("set_dialogue_paused"):
		current_enemy.call("set_dialogue_paused", paused)


func _on_dialogue_finished() -> void:
	var token := _dialogue_token
	await _wait_for_presentation()
	if token != _dialogue_token or not is_inside_tree() or _transition_changed():
		return
	if _hyper_running:
		return
	if _combat_started:
		_unlock_dialogue()
		return
	_start_encounter_sequence(false)


func _wait_for_presentation() -> void:
	var presentation := get_node_or_null("/root/DialoguePresentation")
	if presentation == null or not presentation.has_method("is_presentation_idle"):
		return
	if bool(presentation.call("is_presentation_idle")):
		return
	var gate: Dictionary = {"settled": false}
	var mark_settled := func() -> void:
		gate["settled"] = true
	presentation.connect(&"presentation_settled", mark_settled)
	var guard := 0
	while not bool(gate["settled"]) and guard < 180 and is_inside_tree():
		await get_tree().process_frame
		guard += 1
	if presentation.is_connected(&"presentation_settled", mark_settled):
		presentation.disconnect(&"presentation_settled", mark_settled)


func _on_dialogue_cancelled() -> void:
	_dialogue_token += 1
	if _hyper_running:
		return
	_unlock_dialogue()
	if _transition_changed() or not is_inside_tree():
		input_blocked = true
		return
	_resume_after_dialogue()


func _resume_after_dialogue() -> void:
	if not is_inside_tree() or SceneFader.get_fader().transition_in_progress:
		return
	if _combat_started or phase != Phase.NORMAL_ENCOUNTERS:
		return
	if current_enemy != null and is_instance_valid(current_enemy):
		_activate_enemy(current_enemy)
		return
	_spawn_current()


func _dialogue_runtime() -> UnboundDialogueController:
	return get_node_or_null("/root/UnboundDialogue") as UnboundDialogueController


func _spawn_current() -> void:
	if phase != Phase.NORMAL_ENCOUNTERS or sequence_cleared or sequence_failed:
		return
	if current_index < 0 or current_index >= encounters.size():
		return
	var definition := encounters[current_index]
	if definition == null or definition.combat_profile == null or definition.animation_profile == null:
		push_error("Encounter %s is missing a combat or animation profile." % current_index)
		return
	_spawn_enemy(definition)


func _spawn_enemy(definition: EnemyDefinition) -> void:
	var enemy := _place_enemy(definition)
	if enemy == null:
		return
	_start_encounter_sequence(false)


func _place_enemy(definition: EnemyDefinition) -> Enemy:
	if definition == null or definition.combat_profile == null or definition.animation_profile == null:
		push_error("Encounter is missing a combat or animation profile.")
		return null
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.name = "Enemy"
	enemy.apply_definition(definition)
	enemy.position = spawn_point.position
	_apply_stage_visual(enemy)
	stage.add_child(enemy)
	current_enemy = enemy
	_waiting_for_death = false
	if combat_controller != null:
		combat_controller.enemy = enemy
	return enemy


func _start_encounter_sequence(allow_intro_dialogue: bool) -> void:
	if _hyper_running or _combat_started or phase != Phase.NORMAL_ENCOUNTERS:
		return
	if not is_inside_tree():
		return
	if current_enemy == null or not is_instance_valid(current_enemy):
		if current_index < 0 or current_index >= encounters.size():
			return
		var definition := encounters[current_index]
		if definition == null:
			return
		if _place_enemy(definition) == null:
			return
	_run_encounter_intro(allow_intro_dialogue)


func _run_encounter_intro(allow_intro_dialogue: bool) -> void:
	if current_enemy == null or not is_instance_valid(current_enemy) or current_enemy.definition == null:
		return
	_sequence_token += 1
	var token := _sequence_token
	_capture_transition()
	_hyper_running = true
	_refresh_vector_stack_indicator()
	if not is_dialogue_lock_active:
		_lock_for_dialogue()
	var definition := current_enemy.definition
	print("ENCOUNTER PREPARE: %s" % definition.display_name)
	var intro := _intro_for(definition, allow_intro_dialogue)
	var intro_resource := intro["resource"] as DialogueResource
	var intro_cue := str(intro["cue"])
	if intro_resource != null and not intro_cue.strip_edges().is_empty():
		print("INTRO DIALOGUE: %s" % intro_resource.resource_path)
		if not await _play_dialogue(intro_resource, intro_cue):
			_hyper_running = false
			return
	else:
		if allow_intro_dialogue and intro_dialogue_resource != null:
			push_warning("Intro dialogue cue is empty. Skipping dialogue.")
		print("INTRO DIALOGUE: NONE")
	if not _sequence_ok(token) or current_enemy == null or not is_instance_valid(current_enemy):
		_hyper_running = false
		return
	definition = current_enemy.definition
	var played := definition != null and _hyper_played_ids.has(definition.enemy_id)
	if not await _run_hyper(definition, played):
		return
	_remember_hyper(definition)
	_hyper_running = false
	if not _sequence_ok(token):
		_unlock_dialogue()
		input_blocked = true
		return
	_unlock_dialogue()
	if current_enemy != null and is_instance_valid(current_enemy):
		_activate_enemy(current_enemy)


func _intro_for(definition: EnemyDefinition, allow_override: bool) -> Dictionary:
	if allow_override and intro_dialogue_resource != null:
		if _intro_dialogue_cue_valid():
			return {"resource": intro_dialogue_resource, "cue": intro_dialogue_cue}
		return {"resource": null, "cue": ""}
	var resolved: DialogueResource = null
	if definition != null:
		var same_override := GameSession.get_session().get_current_form_id() == definition.enemy_id
		resolved = GameSession.get_session().resolve_encounter_dialogue(definition.enemy_id, definition.encounter_dialogue, same_override)
	if resolved != null:
		return {"resource": resolved, "cue": EncounterDialogueResolver.CUE}
	return {"resource": null, "cue": ""}


func _intro_dialogue_cue_valid() -> bool:
	return intro_dialogue_resource != null and not intro_dialogue_cue.strip_edges().is_empty()


func _play_intro_dialogue() -> bool:
	return await _play_dialogue(intro_dialogue_resource, intro_dialogue_cue)


func _play_dialogue(resource: DialogueResource, cue: String) -> bool:
	var runtime := _dialogue_runtime()
	if runtime == null:
		push_error("Dialogue runtime is missing.")
		return true
	if runtime.is_dialogue_active:
		push_error("Dialogue is already active.")
		return true
	_lock_for_dialogue()
	_dialogue_token += 1
	var token := _dialogue_token
	var gate: Dictionary = {"ended": false}
	var mark_ended := func() -> void:
		gate["ended"] = true
	if not runtime.dialogue_finished.is_connected(mark_ended):
		runtime.dialogue_finished.connect(mark_ended)
	if not runtime.dialogue_cancelled.is_connected(mark_ended):
		runtime.dialogue_cancelled.connect(mark_ended)
	await runtime.start_dialogue(resource, cue, self)
	if not runtime.is_dialogue_active and token == _dialogue_token:
		push_warning("Intro dialogue did not start. Continuing to Hyper.")
		_disconnect_dialogue_wait(runtime, mark_ended)
		return _sequence_ok(_sequence_token)
	while not bool(gate["ended"]) and is_inside_tree() and token == _dialogue_token and not _transition_changed():
		await get_tree().process_frame
	_disconnect_dialogue_wait(runtime, mark_ended)
	if not is_inside_tree() or token != _dialogue_token or _transition_changed():
		return false
	await _wait_for_presentation()
	return is_inside_tree() and token == _dialogue_token and not _transition_changed()


func _disconnect_dialogue_wait(runtime: UnboundDialogueController, mark_ended: Callable) -> void:
	if runtime == null:
		return
	if runtime.dialogue_finished.is_connected(mark_ended):
		runtime.dialogue_finished.disconnect(mark_ended)
	if runtime.dialogue_cancelled.is_connected(mark_ended):
		runtime.dialogue_cancelled.disconnect(mark_ended)


func _sequence_ok(token: int) -> bool:
	return token == _sequence_token and is_inside_tree() and not _transition_changed()


func _capture_transition() -> void:
	_arrival_transition_count = SceneFader.get_fader().accepted_transition_count


func _transition_changed() -> bool:
	if _arrival_transition_count < 0:
		return false
	return SceneFader.get_fader().accepted_transition_count != _arrival_transition_count


func _run_hyper(definition: EnemyDefinition, already_played: bool) -> bool:
	_hyper_token += 1
	var token := _hyper_token
	var intro := _hyper_intro()
	if not already_played:
		if intro == null:
			push_error("HyperEncounterIntro is missing.")
		else:
			_set_actor_health_visible(false)
			if definition != null and definition.enemy_id == &"arc":
				print("ARC HYPER START")
			print("HYPER START: %s" % definition.display_name)
			await _await_hyper(intro, definition, token)
			if not _hyper_still_valid(token):
				_set_actor_health_visible(true)
				_hyper_running = false
				return false
			if definition != null and definition.enemy_id == &"arc":
				print("ARC HYPER END")
			print("HYPER END: %s" % definition.display_name)
	if not _hyper_still_valid(token):
		_hyper_running = false
		return false
	return true


func _hyper_still_valid(token: int) -> bool:
	if token == _hyper_token and is_inside_tree() and not _transition_changed():
		return true
	_unlock_dialogue()
	input_blocked = true
	_cancel_hyper()
	return false


func _remember_hyper(definition: EnemyDefinition) -> void:
	if definition == null or definition.enemy_id == &"":
		return
	if not _hyper_played_ids.has(definition.enemy_id):
		_hyper_played_ids.append(definition.enemy_id)


func _hyper_intro() -> Node:
	return get_node_or_null("../HyperEncounterIntro")


func _await_hyper(intro: Node, definition: EnemyDefinition, token: int) -> void:
	var playback: Variant = intro
	await playback.play(definition)
	if token != _hyper_token or not is_inside_tree():
		return


func _cancel_hyper() -> void:
	var intro := _hyper_intro()
	if intro != null and intro.has_method(&"cancel"):
		intro.call(&"cancel")


func _activate_enemy(enemy: Enemy) -> void:
	if enemy == null or enemy.definition == null or _combat_started:
		return
	_combat_started = true
	if not is_dialogue_lock_active:
		rhythm_hold = false
		input_blocked = false
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	if not enemy.death_animation_finished.is_connected(_on_enemy_death_animation_finished):
		enemy.death_animation_finished.connect(_on_enemy_death_animation_finished)
	_bind_enemy_hp(enemy)
	print("ENCOUNTER START: %s" % enemy.definition.display_name)
	_set_actor_health_visible(true)
	_apply_enemy_skills(enemy.definition)
	rhythm.set_enemy(enemy)
	rhythm.restart_encounter()
	_refresh_vector_stack_indicator()


func _on_enemy_died(actor: CombatActor) -> void:
	if _is_run_over() or actor != current_enemy or _waiting_for_death:
		return
	if _is_ending_boss(actor):
		var enemy := actor as Enemy
		if enemy != null and enemy.definition != null:
			grant_defeated_override(enemy.definition.enemy_id)
	_waiting_for_death = true
	input_blocked = true
	_refresh_vector_stack_indicator()


func _on_enemy_death_animation_finished(actor: CombatActor) -> void:
	if not _waiting_for_death or actor != current_enemy or _is_run_over():
		return
	_hold_enemy_death(actor)


func _hold_enemy_death(actor: CombatActor) -> void:
	await get_tree().create_timer(ENEMY_DEATH_HOLD_SECONDS).timeout
	if not is_inside_tree() or not _waiting_for_death or actor != current_enemy or _is_run_over():
		return
	_waiting_for_death = false
	await _advance_after_death()


func _on_player_died(_actor: CombatActor) -> void:
	if _is_run_over():
		return
	phase = Phase.FAILED
	sequence_failed = true
	_waiting_for_death = false
	_transitioning = false
	input_blocked = true
	_mark_sequence_over()
	print("STAGE FAILED")
	_finish_stage(false)


func _advance_after_death() -> void:
	var defeated_id := &""
	var ending := false
	if current_enemy != null and is_instance_valid(current_enemy) and current_enemy.definition != null:
		defeated_id = current_enemy.definition.enemy_id
		ending = _is_ending_boss(current_enemy)
	if ending:
		_show_ending_blackout()
	grant_defeated_override(defeated_id)
	_remove_current_enemy()
	_combat_started = false
	if ending:
		_start_ending()
		return
	if current_index + 1 >= encounters.size():
		if stage_cleared:
			return
		stage_cleared = true
		phase = Phase.STAGE_CLEAR
		input_blocked = true
		_mark_sequence_over()
		print("STAGE CLEAR")
		_finish_stage(true)
		return
	current_index += 1
	await _present_encounter_loading()
	if not is_inside_tree() or phase != Phase.NORMAL_ENCOUNTERS:
		return
	_spawn_current()


func _present_encounter_loading() -> void:
	input_blocked = true
	rhythm_hold = true
	_refresh_vector_stack_indicator()
	if rhythm != null:
		rhythm.set_dialogue_paused(true)
		_set_rhythm_panel_visible(false)
	_set_actor_health_visible(false)
	var overlay := get_node_or_null("EncounterLoadingOverlay") as EncounterLoadingOverlay
	if overlay != null:
		await overlay.play()
	if not is_inside_tree():
		return
	rhythm_hold = false


func _ensure_loading_overlay() -> void:
	if get_node_or_null("EncounterLoadingOverlay") != null:
		return
	var overlay := ENCOUNTER_LOADING_SCENE.instantiate()
	overlay.name = "EncounterLoadingOverlay"
	add_child(overlay)


func hold_for_phase_transition() -> void:
	input_blocked = true
	rhythm_hold = true
	_set_actor_health_visible(false)
	_refresh_vector_stack_indicator()
	if rhythm != null:
		rhythm.clear_pending_segment()


func present_phase_death_dialogue(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var definition := enemy.definition
	var resource: DialogueResource = null
	var cue := ""
	if definition != null:
		resource = definition.death_dialogue_resource
		cue = definition.death_dialogue_cue
	if resource == null or cue.strip_edges().is_empty():
		print("PHASE DEATH DIALOGUE: NONE")
		_print_leon_death_dialogue_end(definition)
		enemy.resume_phase_cast()
		return
	print("PHASE DEATH DIALOGUE: %s" % resource.resource_path)
	if not await _play_dialogue(resource, cue):
		return
	_print_leon_death_dialogue_end(definition)
	if is_instance_valid(enemy):
		enemy.resume_phase_cast()


func _print_leon_death_dialogue_end(definition: EnemyDefinition) -> void:
	if definition != null and definition.enemy_id == &"leon":
		print("LEON DEATH DIALOGUE END")


func present_phase(enemy: Enemy) -> void:
	if enemy == null or enemy.definition == null:
		release_phase_transition(enemy)
		return
	if _hyper_played_ids.has(enemy.definition.enemy_id):
		release_phase_transition(enemy)
		return
	_capture_transition()
	_hyper_running = true
	_refresh_vector_stack_indicator()
	print("ENCOUNTER PREPARE: %s" % enemy.definition.display_name)
	var intro := _intro_for(enemy.definition, false)
	var intro_resource := intro["resource"] as DialogueResource
	var intro_cue := str(intro["cue"])
	if intro_resource == null:
		intro_resource = enemy.definition.phase_intro_dialogue_resource
		intro_cue = enemy.definition.phase_intro_dialogue_cue
	if not is_dialogue_lock_active:
		_lock_for_dialogue()
	var arc_phase := enemy.definition.enemy_id == &"arc"
	if intro_resource != null and not intro_cue.strip_edges().is_empty():
		print("INTRO DIALOGUE: %s" % intro_resource.resource_path)
		if arc_phase:
			print("ARC DIALOGUE START")
		if not await _play_dialogue(intro_resource, intro_cue):
			_hyper_running = false
			return
		if arc_phase:
			print("ARC DIALOGUE END")
	else:
		print("INTRO DIALOGUE: NONE")
	if not is_instance_valid(enemy) or enemy.definition == null:
		_hyper_running = false
		return
	if not await _run_hyper(enemy.definition, false):
		return
	_remember_hyper(enemy.definition)
	_hyper_running = false
	_unlock_dialogue()
	if not is_instance_valid(enemy):
		return
	release_phase_transition(enemy)


func release_phase_transition(enemy: Enemy) -> void:
	if enemy == null:
		return
	current_enemy = enemy
	_waiting_for_death = false
	_apply_enemy_skills(enemy.definition)
	_bind_enemy_hp(enemy)
	rhythm_hold = false
	input_blocked = false
	if not is_dialogue_lock_active and not _hyper_running:
		_set_actor_health_visible(true)
		_open_phase_combat(enemy)


func _open_phase_combat(enemy: Enemy) -> void:
	if enemy != null and enemy.definition != null and enemy.definition.enemy_id == &"arc":
		print("ARC COMBAT START")
	if rhythm == null or enemy == null:
		return
	rhythm.set_enemy(enemy)
	rhythm.restart_encounter()


func _is_ending_boss(actor: CombatActor) -> bool:
	if not return_to_hub:
		return false
	var enemy := actor as Enemy
	return enemy != null and enemy.definition != null and enemy.definition.enemy_id == &"arc"


func _show_ending_blackout() -> void:
	var host := get_parent()
	if host == null or host.get_node_or_null("EndingBlackout") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "EndingBlackout"
	layer.layer = 45
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.BLACK
	layer.add_child(rect)
	host.add_child(layer)


func _start_ending() -> void:
	if _stage_resolved:
		return
	_stage_resolved = true
	input_blocked = true
	_return_left = -1.0
	_mark_sequence_over()
	var stage_id := _resolved_stage_id()
	if _player != null and _player.has_method("notify_combat_ended"):
		_player.call("notify_combat_ended", stage_id)
	if progression_enabled:
		GameSession.get_session().complete_stage(stage_id)
	GameAudio.stop_combat()
	var popup := get_tree().root.get_node_or_null("OverrideAcquiredPopup")
	if popup != null:
		popup.visible = false
	print("ENDING")
	SceneFader.get_fader().go_to_ending()


func grant_defeated_override(enemy_id: StringName) -> void:
	if not progression_enabled:
		return
	if enemy_id == &"":
		push_warning("Defeated combatant has no override id. Encounter continues.")
		return
	if not FormRegistry.has_form(enemy_id):
		push_warning("No override data for '%s'. Encounter continues." % enemy_id)
		return
	if GameSession.get_session().acquire_form(enemy_id):
		print("OVERRIDE ACQUIRED: %s" % enemy_id)


func _apply_enemy_skills(definition: EnemyDefinition) -> void:
	if rhythm == null or definition == null:
		return
	rhythm.set_node_lock_enabled(definition.can_lock_nodes)
	rhythm.set_node_steal_enabled(definition.can_steal_nodes)
	rhythm.set_node_speed_enabled(definition.can_use_speed_nodes)
	rhythm.set_overload_enabled(definition.can_overload)


func _ensure_effects() -> void:
	if stage == null or stage.get_node_or_null("CombatEffectPlayer") != null:
		return
	var effects := CombatEffectPlayer.new()
	effects.name = "CombatEffectPlayer"
	stage.add_child(effects)


func _remove_current_enemy() -> void:
	var old := current_enemy
	current_enemy = null
	if combat_controller != null:
		combat_controller.enemy = null
	if rhythm != null:
		rhythm.set_enemy(null)
	if old == null or not is_instance_valid(old):
		return
	_disconnect_enemy(old)
	old.queue_free()


func _disconnect_enemy(actor: CombatActor) -> void:
	if actor.died.is_connected(_on_enemy_died):
		actor.died.disconnect(_on_enemy_died)
	if actor.death_animation_finished.is_connected(_on_enemy_death_animation_finished):
		actor.death_animation_finished.disconnect(_on_enemy_death_animation_finished)
	if actor.health_changed.is_connected(_on_enemy_health_changed):
		actor.health_changed.disconnect(_on_enemy_health_changed)


func _bind_enemy_hp(enemy: CombatActor) -> void:
	_disconnect_enemy_hp_only()
	if enemy_hp != null:
		enemy_hp.max_value = enemy.max_hp
		enemy_hp.value = enemy.current_hp
	if not enemy.health_changed.is_connected(_on_enemy_health_changed):
		enemy.health_changed.connect(_on_enemy_health_changed)
	print("ENEMY HP: %d/%d" % [enemy.current_hp, enemy.max_hp])


func _disconnect_enemy_hp_only() -> void:
	if current_enemy == null or not is_instance_valid(current_enemy):
		return
	if current_enemy.health_changed.is_connected(_on_enemy_health_changed):
		current_enemy.health_changed.disconnect(_on_enemy_health_changed)


func _on_enemy_health_changed(current_hp: int, max_hp: int) -> void:
	if enemy_hp != null:
		enemy_hp.max_value = max_hp
		enemy_hp.value = current_hp
	print("ENEMY HP: %d/%d" % [current_hp, max_hp])


func _apply_stage_visual(actor: Node2D) -> void:
	var view := get_parent()
	if view != null and view.has_method("apply_character_visual_scale"):
		view.call("apply_character_visual_scale", actor)


func _node_at(primary: String, alternate: String) -> Node:
	var node := get_node_or_null(primary)
	if node == null:
		node = get_node_or_null(alternate)
	return node


func _is_run_over() -> bool:
	return phase == Phase.STAGE_CLEAR or phase == Phase.FAILED


func _finish_stage(cleared: bool) -> void:
	if not return_to_hub or _stage_resolved:
		return
	_stage_resolved = true
	var stage_id := _resolved_stage_id()
	if _player != null and _player.has_method("notify_combat_ended"):
		_player.call("notify_combat_ended", stage_id)
	var session := GameSession.get_session()
	if not progression_enabled:
		_return_left = maxf(result_hold_seconds, 0.0)
		return
	if cleared:
		session.complete_stage(stage_id)
	else:
		session.rollback_stage(stage_id)
	_return_left = maxf(result_hold_seconds, 0.0)


func _resolved_stage_id() -> StringName:
	if active_stage_id != &"":
		return active_stage_id
	var session := GameSession.get_session()
	if session.current_stage_id != &"":
		return session.current_stage_id
	var view := get_parent()
	if view != null and view.get("stage_id") != null:
		var id := StringName(view.get("stage_id"))
		if id != &"":
			return id
	return &"the_veil"


func _mark_sequence_over() -> void:
	if rhythm != null:
		rhythm.set_node_lock_enabled(false)
		rhythm.set_node_steal_enabled(false)
		rhythm.set_node_speed_enabled(false)
	if combat_controller != null:
		combat_controller.battle_finished = true
