class_name RhythmController
extends Node

## 리듬 판정과 세그먼트 진행만 담당한다. 피해는 CombatActor.perform_attack()에 맡긴다.
## 속도 배율은 리듬 시간에만 적용한다. 화면의 턴 정지는 없다.

signal rhythm_speed_changed(multiplier: float, effect: RhythmNode.SpeedEffect)

const NODE_SCENE := preload("res://scenes/combat/rhythm/RhythmNode.tscn")
const NODE_SIZE := 36.0
const _SCOPE_TEXTURE := preload("res://assets/ui/scope.png")
## scope.png를 판정창 폭에 맞추지 않는다.
const SCOPE_VISUAL_SCALE := 0.5
## 화면 가장자리에서 스프라이트 전체가 밖에 있도록 더하는 여백.
const SPAWN_MARGIN := 8.0
## OVERLOAD가 기존 노드 뒤에 덧붙이는 수와 간격.
const OVERLOAD_NODE_COUNT := 10
const OVERLOAD_GAP_TICKS := 2

@export var bpm: float = 120.0
@export var ticks_per_beat: int = 2
@export var hit_window_seconds: float = 0.12
@export var approach_seconds: float = 4.0
## 더 이상 판정 이동에 쓰지 않는다. 씬에 남은 값만 유지한다.
@export var post_judge_seconds: float = 0.45
## 더 이상 판정 이동에 쓰지 않는다. 씬에 남은 값만 유지한다.
@export var despawn_margin: float = 8.0
## 중앙 판정대 표시 폭. 노드 목표점이 아니다. 최종 에셋 크기가 아니다.
@export var judge_zone_width: float = 48.0
## HIT 창보다 이른 입력 폭.
@export var bad_window_seconds: float = 0.30
## 판정 후 잔상.
@export var debris_horizontal_speed: float = 72.0
@export var debris_gravity: float = 480.0
@export var debris_hop_speed: float = 36.0
@export var debris_lifetime: float = 0.8
## 탈취 워프 연출. scheduled_time을 밀지 않게 짧게 둔다.
@export var steal_transition_seconds: float = 0.12
## 잠금 가능하려면 판정까지 남아 있어야 하는 시간.
@export var lock_warning_seconds: float = 0.8
## 노드가 레인에 보인 뒤 자동 잠금까지 기다리는 시간.
@export var lock_trigger_delay_seconds: float = 0.75
## 탈취하려면 판정까지 남아 있어야 하는 시간.
@export var steal_warning_seconds: float = 0.9
## 노드가 레인에 보인 뒤 자동 탈취까지 기다리는 시간.
@export var steal_trigger_delay_seconds: float = 0.85
## 리듬 시간만 곱한다. SLOW 0.8, FAST 1.5.
@export var slow_multiplier: float = 0.8
@export var fast_multiplier: float = 1.5
## 인덱스 0부터 1틱, 2틱, 3틱, 4틱, 5틱 가중치. 합이 100일 필요는 없다.
## 5틱 가중치 0은 최대 간격을 줄인다. 1틱 가중치는 그대로다.
@export var gap_weights: PackedInt32Array = PackedInt32Array([10, 30, 30, 30, 0])
@export var max_consecutive_one_tick_gaps: int = 2
@export var max_consecutive_same_owner: int = 3
@export var turn_lead_in_ticks: int = 4
@export var player_node_count: int = 4
@export var enemy_node_count: int = 3
## 턴 사이 정지는 제거됐다. 값은 바꾸지 않고 흐름에는 쓰지 않는다.
@export var turn_interval: float = 0.75
@export var judge_feedback_seconds: float = 0.38
@export var use_fixed_seed: bool = false
@export var pattern_seed: int = 1
## 디버그용. 기본 플레이는 랜덤 생성이다.
@export var use_forced_pattern: bool = false

@export var player: CombatActor
@export var enemy: CombatActor
@export var panel: Control
@export var combat_controller: Node

var current_time: float = 0.0
var rhythm_speed_multiplier: float = 1.0
var turn_index: int = 0
var stopped: bool = false
var dialogue_paused: bool = false
var _judge_frame: int = -1
var last_debug: String = ""
var judgment_log: PackedStringArray = PackedStringArray()

var _rng := RandomNumberGenerator.new()
var _nodes: Array[RhythmNode] = []
var _debris: Array[RhythmNode] = []
var _boundaries: Array[Dictionary] = []
var _flow_active: bool = false
var _segment_index: int = 0
var _segment_origin_tick: int = 0
var _clock_started: bool = false
var _lock_segment: int = -1
var _steal_segment: int = -1
var _node_container: Control
var _debug_label: Label
var _feedback_label: Label
var _feedback_left: float = 0.0
var _forced_owners: Array[int] = []
var _forced_gaps: Array[int] = []
var _node_lock_enabled: bool = false
var _node_steal_enabled: bool = false
var _node_speed_enabled: bool = false
var _overload_enabled: bool = false
var _overload_fired: bool = false
var _auto_lock_used: bool = false
var _stole_this_segment: bool = false
var _speed_effect: RhythmNode.SpeedEffect = RhythmNode.SpeedEffect.NONE
var _speed_event_label: Label
var _speed_event_left: float = 0.0
var _judge_scope: TextureRect
var _input_resume_frame: int = 0


func _ready() -> void:
	_bind_scene_nodes()
	if player == null or panel == null:
		push_error("RhythmController is missing player or RhythmPanel.")
		return
	_node_container = panel.get_node_or_null("NodeLayer") as Control
	if _node_container == null:
		_node_container = panel.get_node_or_null("NodeContainer") as Control
	_debug_label = panel.get_node_or_null("DebugLabel") as Label
	_feedback_label = panel.get_node_or_null("JudgeFeedback") as Label
	if _node_container == null:
		push_error("RhythmPanel is missing NodeLayer.")
		return
	_node_container.clip_contents = false
	panel.clip_contents = false
	_ensure_judge_scope()
	if use_fixed_seed:
		_rng.seed = pattern_seed
	else:
		_rng.randomize()
	if not player.died.is_connected(_on_actor_died):
		player.died.connect(_on_actor_died)
	if enemy != null and not enemy.died.is_connected(_on_actor_died):
		enemy.died.connect(_on_actor_died)
	_ensure_speed_event()
	SpeedEffectOverlay.mount(get_parent())
	print("RHYTHM: J/K judge")


func set_dialogue_paused(paused: bool) -> void:
	var opening := dialogue_paused and not paused
	dialogue_paused = paused
	if opening:
		_input_resume_frame = Engine.get_physics_frames() + 1


func _process(delta: float) -> void:
	if dialogue_paused:
		return
	var step := maxf(delta, 0.0)
	_tick_feedback(step)
	_tick_speed_event(step)
	_tick_steal_transitions(step)
	_update_debris(step)
	advance_time(step)


func _unhandled_input(event: InputEvent) -> void:
	if SceneFader.get_fader().transition_in_progress or dialogue_paused:
		return
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if _direct_attack_debug_enabled():
		return
	if key_event.keycode == KEY_J or key_event.keycode == KEY_K:
		_mark_input_handled()
		try_judge()


func tick_seconds() -> float:
	return 60.0 / maxf(bpm, 1.0) / float(maxi(ticks_per_beat, 1))


func generate_owner_sequence() -> Array[int]:
	var owners: Array[int] = []
	for _index in maxi(player_node_count, 0):
		owners.append(RhythmNode.NodeOwner.PLAYER)
	for _index in maxi(enemy_node_count, 0):
		owners.append(RhythmNode.NodeOwner.ENEMY)
	if owners.is_empty():
		return owners
	var limit := maxi(max_consecutive_same_owner, 1)
	for _attempt in 32:
		_shuffle(owners)
		if _longest_run(owners) <= limit:
			return owners
	return _place_owners_with_limit(owners, limit)


func choose_tick_gap(consecutive_one_tick_gaps: int) -> int:
	var weights := _gap_weight_table()
	if consecutive_one_tick_gaps >= maxi(max_consecutive_one_tick_gaps, 0):
		weights[0] = 0
	var total := 0
	for weight in weights:
		total += weight
	if total <= 0:
		return 2
	var roll := _rng.randi_range(1, total)
	var cursor := 0
	for index in weights.size():
		cursor += weights[index]
		if roll <= cursor:
			return index + 1
	return weights.size()


func generate_turn_pattern() -> Array[Dictionary]:
	if use_forced_pattern and not _forced_owners.is_empty():
		return _build_pattern(_forced_owners, _forced_gaps, true)
	return _build_pattern(generate_owner_sequence(), [], false)


## owners는 NodeOwner 값 또는 "P" / "E". gaps는 노드 사이 간격이고 첫 노드는 리드인을 쓴다.
func set_forced_pattern(owners: Array, gaps: Array) -> void:
	_forced_owners.clear()
	for owner in owners:
		_forced_owners.append(_owner_from(owner))
	_forced_gaps.clear()
	for gap in gaps:
		_forced_gaps.append(maxi(int(gap), 1))
	use_forced_pattern = true


func clear_forced_pattern() -> void:
	use_forced_pattern = false
	_forced_owners.clear()
	_forced_gaps.clear()


func try_judge() -> void:
	if dialogue_paused or stopped or _battle_is_over() or _encounter_input_blocked():
		return
	if Engine.get_physics_frames() < _input_resume_frame:
		return
	var frame := Engine.get_physics_frames()
	if frame == _judge_frame:
		return
	_judge_frame = frame
	var judged := _judged_input_time()
	var hit_node := _closest_in_hit_window(judged)
	if hit_node != null:
		if _is_locked_player(hit_node):
			_resolve_whiff(hit_node)
		else:
			_resolve(hit_node, true)
	else:
		var early := _closest_upcoming(judged)
		if early != null:
			var until := early.scheduled_time - judged
			if until <= _difficulty_hit_window() + maxf(bad_window_seconds, 0.0):
				if _is_locked_player(early):
					_resolve_whiff(early)
				else:
					_resolve_bad(early)


func advance_time(delta: float) -> void:
	if dialogue_paused or stopped or _battle_is_over() or not _flow_active or _encounter_holds_rhythm():
		return
	if player == null or enemy == null or not is_instance_valid(player) or not is_instance_valid(enemy):
		return
	var step := maxf(delta, 0.0)
	current_time += step * maxf(rhythm_speed_multiplier, 0.01)
	_update_positions()
	_trigger_boundaries()
	_try_auto_interference()
	_resolve_misses()
	_ensure_next_segment()


func restart_with_seed(seed_value: int) -> void:
	use_fixed_seed = true
	pattern_seed = seed_value
	_rng.seed = seed_value
	restart_encounter()


func set_enemy(next_enemy: CombatActor) -> void:
	if enemy != null and is_instance_valid(enemy) and enemy.died.is_connected(_on_actor_died):
		enemy.died.disconnect(_on_actor_died)
	enemy = next_enemy
	if enemy != null and is_instance_valid(enemy) and not enemy.died.is_connected(_on_actor_died):
		enemy.died.connect(_on_actor_died)


func clear_pending_segment() -> void:
	_flow_active = false
	_auto_lock_used = false
	_stole_this_segment = false
	_lock_segment = -1
	_steal_segment = -1
	_segment_index = 0
	_segment_origin_tick = 0
	_clock_started = false
	_overload_fired = false
	_boundaries.clear()
	current_time = 0.0
	reset_rhythm_speed()
	_hide_feedback()
	_hide_speed_event()
	_clear_nodes()


func restart_encounter() -> void:
	if _battle_is_over():
		return
	stopped = false
	_flow_active = false
	_auto_lock_used = false
	_stole_this_segment = false
	_lock_segment = -1
	_steal_segment = -1
	_segment_index = 0
	_segment_origin_tick = 0
	_clock_started = false
	_overload_fired = false
	_boundaries.clear()
	reset_rhythm_speed()
	current_time = 0.0
	turn_index = 0
	judgment_log = PackedStringArray()
	_hide_feedback()
	_hide_speed_event()
	_clear_nodes()
	_flow_active = true
	_start_segment()


func pending_nodes() -> Array[RhythmNode]:
	var pending: Array[RhythmNode] = []
	for node in _nodes:
		if is_instance_valid(node) and not node.processed:
			pending.append(node)
	pending.sort_custom(func(a: RhythmNode, b: RhythmNode) -> bool:
		return a.scheduled_time < b.scheduled_time
	)
	return pending


func _start_segment() -> void:
	if stopped or _battle_is_over() or _node_container == null:
		return
	if player == null or enemy == null or not is_instance_valid(player) or not is_instance_valid(enemy):
		return
	if player_node_count + enemy_node_count <= 0:
		return
	var pattern := generate_turn_pattern()
	if pattern.is_empty():
		return
	_segment_index += 1
	turn_index = _segment_index
	print("RHYTHM SEGMENT START")
	var origin := _segment_origin_tick
	var seconds := tick_seconds()
	var first_time := INF
	var last_tick := origin
	for entry in pattern:
		var tick := origin + int(entry["tick"])
		var node := _add_combat_node(int(entry["node_owner"]), tick, _segment_index)
		first_time = minf(first_time, node.scheduled_time)
		last_tick = maxi(last_tick, tick)
	_segment_origin_tick = last_tick
	_arm_segment(origin, seconds)
	if not _clock_started and first_time < INF:
		_clock_started = true
		current_time = first_time - approach_seconds
	print("SEGMENT %d" % _segment_index)
	_notify_segment_started()
	_spawn_overload()
	_update_positions()


func _ensure_next_segment() -> void:
	if not _flow_active or stopped or _battle_is_over():
		return
	var seconds := tick_seconds()
	for _step in 4:
		var next_first := float(_segment_origin_tick + maxi(turn_lead_in_ticks, 0)) * seconds
		if next_first - current_time > approach_seconds + seconds:
			return
		var origin_before := _segment_origin_tick
		_start_segment()
		if _segment_origin_tick == origin_before:
			return


func _add_combat_node(owner: int, tick: int, segment_id: int) -> RhythmNode:
	var node := NODE_SCENE.instantiate() as RhythmNode
	_node_container.add_child(node)
	node.set_node_owner(owner)
	node.scheduled_tick = tick
	node.scheduled_time = float(tick) * tick_seconds()
	node.segment_index = segment_id
	_nodes.append(node)
	print("NODE SPAWN")
	return node


func _arm_segment(origin_tick: int, seconds: float) -> void:
	var slot := _segment_index % 4
	if slot == 1:
		_lock_segment = _segment_index
		_auto_lock_used = false
	elif slot == 2:
		_steal_segment = _segment_index
		_stole_this_segment = false
	elif slot == 3 and _speed_allowed():
		_queue_boundary(float(origin_tick) * seconds, RhythmNode.SpeedEffect.SLOW)
	elif slot == 0 and _speed_allowed():
		_queue_boundary(float(origin_tick) * seconds, RhythmNode.SpeedEffect.FAST)


func _resolve_misses() -> void:
	var snapshot := _nodes.duplicate()
	for node in snapshot:
		if stopped or _battle_is_over():
			return
		if not is_instance_valid(node) or node.processed or node.is_visual_only or node.is_stealing:
			continue
		if node.node_category == RhythmNode.NodeCategory.SPEED:
			continue
		if current_time > node.scheduled_time + hit_window_for(node):
			_resolve(node, false)


func set_node_lock_enabled(enabled: bool) -> void:
	_node_lock_enabled = enabled
	if not enabled:
		_auto_lock_used = false


func set_node_steal_enabled(enabled: bool) -> void:
	_node_steal_enabled = enabled
	if not enabled:
		_stole_this_segment = false


func set_node_speed_enabled(enabled: bool) -> void:
	_node_speed_enabled = enabled
	if not enabled:
		reset_rhythm_speed()


func set_overload_enabled(enabled: bool) -> void:
	_overload_enabled = enabled
	if enabled:
		_spawn_overload()


func refresh_presentation() -> void:
	_update_positions()


func _spawn_overload() -> void:
	if not _overload_enabled or _overload_fired or _node_container == null:
		return
	var last_tick := 0
	var combat_count := 0
	for node in _nodes:
		if not is_instance_valid(node) or node.node_category != RhythmNode.NodeCategory.COMBAT:
			continue
		combat_count += 1
		last_tick = maxi(last_tick, node.scheduled_tick)
	if combat_count == 0:
		return
	var player_added := 0
	var enemy_added := 0
	var seconds := tick_seconds()
	var min_time := current_time + maxf(approach_seconds, 0.01)
	var min_tick := int(ceil(min_time / maxf(seconds, 0.001)))
	var first_tick := maxi(last_tick + OVERLOAD_GAP_TICKS, min_tick)
	for index in OVERLOAD_NODE_COUNT:
		var tick := first_tick + OVERLOAD_GAP_TICKS * index
		var owner := RhythmNode.NodeOwner.PLAYER if index % 2 == 0 else RhythmNode.NodeOwner.ENEMY
		var spawned := _add_combat_node(owner, tick, _segment_index)
		spawned.from_overload = true
		last_tick = tick
		if owner == RhythmNode.NodeOwner.PLAYER:
			player_added += 1
		else:
			enemy_added += 1
	_segment_origin_tick = maxi(_segment_origin_tick, last_tick)
	_overload_fired = true
	print("[OVERLOAD] +%d player=%d enemy=%d gap_ticks=%d" % [OVERLOAD_NODE_COUNT, player_added, enemy_added, OVERLOAD_GAP_TICKS])


func add_speed_node(effect: RhythmNode.SpeedEffect, scheduled_tick: int) -> RhythmNode:
	if not _speed_allowed():
		return null
	if effect != RhythmNode.SpeedEffect.SLOW and effect != RhythmNode.SpeedEffect.FAST:
		return null
	_queue_boundary(float(maxi(scheduled_tick, 1)) * tick_seconds(), effect)
	return null


func current_speed_effect() -> RhythmNode.SpeedEffect:
	return _speed_effect


func _sync_speed_overlay() -> void:
	var host := get_parent()
	if host == null:
		return
	var overlay := host.get_node_or_null("SpeedEffectOverlay")
	if overlay != null and overlay.has_method("sync_from_parent"):
		overlay.call("sync_from_parent")


func _show_result_popup(kind: String) -> void:
	if panel == null or _judge_scope == null:
		return
	var center := _judge_scope.get_global_rect().get_center()
	var local := panel.get_global_transform().affine_inverse() * center
	JudgeResultPopup.spawn(panel, local + Vector2(0.0, -36.0), kind)


func reset_rhythm_speed() -> void:
	var unchanged := is_equal_approx(rhythm_speed_multiplier, 1.0) and _speed_effect == RhythmNode.SpeedEffect.NONE
	rhythm_speed_multiplier = 1.0
	_speed_effect = RhythmNode.SpeedEffect.NONE
	if not unchanged:
		rhythm_speed_changed.emit(1.0, RhythmNode.SpeedEffect.NONE)
	_sync_speed_overlay()


func try_lock_next_player_node() -> bool:
	if not _locks_allowed() or _has_active_lock():
		return false
	var target := _next_lock_candidate(false)
	if target == null:
		return false
	return lock_player_node(target)


func lock_player_node(node: RhythmNode) -> bool:
	if not _can_lock(node) or _has_active_lock():
		return false
	if _negated_by_cipher():
		print("[CIPHER NULLIFY] LOCK")
		return false
	node.set_locked(true)
	print("[BOSS LOCK] node tick=%d" % node.scheduled_tick)
	return true


func try_steal_next_player_node() -> bool:
	if not _steal_allowed() or _stole_this_segment:
		return false
	var target := _next_steal_candidate(false)
	if target == null:
		return false
	return steal_player_node(target)


func steal_player_node(node: RhythmNode) -> bool:
	if not _can_steal(node) or _stole_this_segment:
		return false
	if _negated_by_cipher():
		print("[CIPHER NULLIFY] STEAL")
		return false
	node.is_stealing = true
	node.steal_time_left = maxf(steal_transition_seconds, 0.01)
	node.modulate.a = 0.35
	node.play_steal_effect()
	_stole_this_segment = true
	print("[BOSS STEAL] node tick=%d" % node.scheduled_tick)
	_show_judge_feedback("STEAL")
	return true


func _resolve_whiff(node: RhythmNode) -> void:
	if stopped or node.processed or not is_instance_valid(node):
		return
	node.processed = true
	_set_debug("WHIFF")
	print("[WHIFF]")
	_show_judge_feedback("WHIFF")
	if player != null and enemy != null and is_instance_valid(player) and is_instance_valid(enemy):
		player.perform_attack(enemy, false)
	_delete_next_player_after(node)
	_become_debris(node)


func _resolve_lock_skip(node: RhythmNode) -> void:
	if stopped or node.processed or not is_instance_valid(node):
		return
	node.processed = true
	_set_debug("LOCK SKIP")
	print("[LOCK SKIP]")
	_show_judge_feedback("SKIP")
	_become_debris(node)


func _delete_next_player_after(current: RhythmNode) -> void:
	var best: RhythmNode = null
	for node in _nodes:
		if not is_instance_valid(node) or node == current or node.processed:
			continue
		if node.node_category != RhythmNode.NodeCategory.COMBAT:
			continue
		if node.node_owner != RhythmNode.NodeOwner.PLAYER:
			continue
		if node.scheduled_time <= current.scheduled_time:
			continue
		if best == null or node.scheduled_time < best.scheduled_time:
			best = node
	if best == null:
		print("[DELETE NEXT PLAYER] none")
		return
	best.processed = true
	var tick := best.scheduled_tick
	_release_node(best)
	print("[DELETE NEXT PLAYER] tick=%d" % tick)


func _queue_boundary(time: float, effect: RhythmNode.SpeedEffect) -> void:
	_boundaries.append({
		"time": time,
		"effect": effect,
		"fired": false,
	})


func _trigger_boundaries() -> void:
	for index in _boundaries.size():
		var event: Dictionary = _boundaries[index]
		if bool(event["fired"]) or current_time < float(event["time"]):
			continue
		event["fired"] = true
		_boundaries[index] = event
		_activate_speed_effect(int(event["effect"]))


func _activate_speed_effect(effect: int) -> void:
	if _speed_blocked_by_emp():
		print("[ARC EMP] ignore speed")
		return
	var speed_effect := RhythmNode.SpeedEffect.FAST
	if effect == RhythmNode.SpeedEffect.SLOW:
		speed_effect = RhythmNode.SpeedEffect.SLOW
	var multiplier := maxf(fast_multiplier, 0.01)
	var label := "FAST"
	if speed_effect == RhythmNode.SpeedEffect.SLOW:
		multiplier = maxf(slow_multiplier, 0.01)
		label = "SLOW"
	var changed := not is_equal_approx(rhythm_speed_multiplier, multiplier) or _speed_effect != speed_effect
	rhythm_speed_multiplier = multiplier
	_speed_effect = speed_effect
	if changed:
		rhythm_speed_changed.emit(multiplier, speed_effect)
	var text := "%s x%s" % [label, _format_multiplier(multiplier)]
	_set_debug(text)
	print("[%s]" % text)
	_sync_speed_overlay()


func _tick_taken(tick: int) -> bool:
	for node in _nodes:
		if is_instance_valid(node) and node.scheduled_tick == tick:
			return true
	return false


func _speed_allowed() -> bool:
	return _node_speed_enabled


func _speed_caption(effect: RhythmNode.SpeedEffect) -> String:
	if effect == RhythmNode.SpeedEffect.SLOW:
		return "SLOW\nx%s" % _format_multiplier(slow_multiplier)
	return "FAST\nx%s" % _format_multiplier(fast_multiplier)


func _format_multiplier(value: float) -> String:
	return "%0.1f" % value


func _ensure_speed_event() -> void:
	if panel == null:
		return
	var host: Node = panel.get_node_or_null("SpecialEventLayer")
	if host == null:
		host = panel
	_speed_event_label = host.get_node_or_null("SpeedEvent") as Label
	if _speed_event_label != null:
		return
	_speed_event_label = Label.new()
	_speed_event_label.name = "SpeedEvent"
	_speed_event_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_event_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speed_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speed_event_label.add_theme_font_size_override(&"font_size", 14)
	_speed_event_label.visible = false
	_speed_event_label.z_index = 20
	host.add_child(_speed_event_label)


func _show_speed_event(text: String) -> void:
	if _speed_event_label == null:
		return
	_speed_event_label.text = text
	_speed_event_label.visible = true
	var color := Color(0.4, 0.85, 0.78) if text == "SLOW" else Color(1.0, 0.45, 0.7)
	_speed_event_label.add_theme_color_override(&"font_color", color)
	_speed_event_left = 0.55


func _tick_speed_event(step: float) -> void:
	if _speed_event_label == null or not _speed_event_label.visible:
		return
	_speed_event_left -= step
	if _speed_event_left <= 0.0:
		_hide_speed_event()


func _hide_speed_event() -> void:
	_speed_event_left = 0.0
	if _speed_event_label != null:
		_speed_event_label.visible = false
		_speed_event_label.text = ""


func _try_auto_interference() -> void:
	if not _node_lock_enabled and not _node_steal_enabled:
		return
	# 테스트 규칙. 세그먼트 1 잠금, 2 탈취, 3 SLOW, 4 FAST. 최종 패턴이 아니다.
	if _lock_segment > 0 and not _auto_lock_used:
		_try_auto_lock()
	if _steal_segment > 0 and not _stole_this_segment:
		_try_auto_steal()


func _try_auto_lock() -> void:
	if not _node_lock_enabled:
		return
	if _has_active_lock():
		_auto_lock_used = true
		return
	var target := _next_lock_candidate(true)
	if target == null:
		return
	if lock_player_node(target):
		_auto_lock_used = true


func _try_auto_steal() -> void:
	if not _node_steal_enabled or _stole_this_segment:
		return
	var target := _next_steal_candidate(true)
	if target == null:
		return
	steal_player_node(target)


func _next_lock_candidate(require_descend: bool) -> RhythmNode:
	var best: RhythmNode = null
	for node in _nodes:
		if node.segment_index != _lock_segment or not _can_lock(node):
			continue
		if require_descend:
			var until := node.scheduled_time - current_time
			var descended := approach_seconds - until
			if descended < lock_trigger_delay_seconds:
				continue
		if best == null or node.scheduled_time < best.scheduled_time:
			best = node
	return best


func _next_steal_candidate(require_descend: bool) -> RhythmNode:
	var best: RhythmNode = null
	for node in _nodes:
		if node.segment_index != _steal_segment or not _can_steal(node):
			continue
		if require_descend:
			var until := node.scheduled_time - current_time
			var descended := approach_seconds - until
			if descended < steal_trigger_delay_seconds:
				continue
		if best == null or node.scheduled_time < best.scheduled_time:
			best = node
	return best


func _can_steal(node: RhythmNode) -> bool:
	if not _steal_allowed() or node == null or not is_instance_valid(node):
		return false
	if node.from_overload:
		return false
	if node.node_category != RhythmNode.NodeCategory.COMBAT:
		return false
	if node.processed or node.is_locked or node.is_stealing or node.is_visual_only:
		return false
	if node.node_owner != RhythmNode.NodeOwner.PLAYER:
		return false
	var until := node.scheduled_time - current_time
	return until >= steal_warning_seconds


func _can_lock(node: RhythmNode) -> bool:
	if not _locks_allowed() or node == null or not is_instance_valid(node):
		return false
	if node.from_overload:
		return false
	if node.node_category != RhythmNode.NodeCategory.COMBAT:
		return false
	if node.processed or node.is_locked or node.is_stealing or node.is_visual_only:
		return false
	if node.node_owner != RhythmNode.NodeOwner.PLAYER:
		return false
	var until := node.scheduled_time - current_time
	return until >= lock_warning_seconds


func _has_active_lock() -> bool:
	for node in _nodes:
		if _lock_still_active(node):
			return true
	for node in _debris:
		if _lock_still_active(node):
			return true
	return false


func _lock_still_active(node: RhythmNode) -> bool:
	return is_instance_valid(node) and node.is_locked and not node.is_queued_for_deletion()


func _locks_allowed() -> bool:
	return _node_lock_enabled


func _steal_allowed() -> bool:
	return _node_steal_enabled


func _resolve(node: RhythmNode, hit: bool) -> void:
	if stopped or node.processed or node.is_visual_only or node.is_stealing or not is_instance_valid(node):
		return
	if node.node_category == RhythmNode.NodeCategory.SPEED:
		return
	if node.is_locked and node.node_owner == RhythmNode.NodeOwner.PLAYER:
		if hit:
			_resolve_whiff(node)
		else:
			_resolve_lock_skip(node)
		return
	var kind := node.node_owner
	if not hit and kind == RhythmNode.NodeOwner.PLAYER and _requeue_player_failure(node):
		return
	node.processed = true
	if hit and kind == RhythmNode.NodeOwner.PLAYER:
		_set_debug("P HIT")
		print("P HIT")
		_show_judge_feedback("HIT")
		player.perform_attack(enemy, true)
		_try_purge_delete(node)
	elif hit and kind == RhythmNode.NodeOwner.ENEMY:
		enemy.perform_attack(player, false)
		_set_debug("PARRY")
		print("PARRY")
		_show_judge_feedback("PARRY")
		GameAudio.play_parry()
		if player.has_method("notify_parry_success") and bool(player.call("notify_parry_success")):
			reset_rhythm_speed()
			print("[ARC EMP]")
		_play_parry_effect(player)
	elif kind == RhythmNode.NodeOwner.PLAYER:
		_note_player_failure()
		_set_debug("P MISS")
		print("P MISS")
		_show_judge_feedback("MISS")
		_show_result_popup("MISS")
	else:
		_set_debug("E MISS")
		print("E MISS")
		_show_judge_feedback("MISS")
		_show_result_popup("MISS")
		_resolve_enemy_attack_success()
	# 일반 MISS는 다음 노드를 지우지 않는다. 판정이 끝난 노드는 잔상으로만 남긴다.
	_become_debris(node)


func _resolve_bad(node: RhythmNode) -> void:
	if stopped or node.processed or node.is_visual_only or node.is_stealing or not is_instance_valid(node):
		return
	if node.node_category != RhythmNode.NodeCategory.COMBAT:
		return
	if node.node_owner == RhythmNode.NodeOwner.PLAYER and _requeue_player_failure(node):
		return
	node.processed = true
	_set_debug("BAD")
	print("BAD")
	_show_judge_feedback("BAD")
	_show_result_popup("BAD")
	if node.node_owner == RhythmNode.NodeOwner.PLAYER:
		_note_player_failure()
	elif node.node_owner == RhythmNode.NodeOwner.ENEMY:
		_resolve_enemy_attack_success()
	_become_debris(node)


func hit_window_for(node: RhythmNode) -> float:
	var window := _difficulty_hit_window()
	var traits := _traits()
	if traits != null and is_instance_valid(node) and node.node_category == RhythmNode.NodeCategory.COMBAT and node.node_owner == RhythmNode.NodeOwner.ENEMY:
		window *= traits.parry_window_multiplier()
	return window


func _difficulty_hit_window() -> float:
	var session := GameSession.get_session()
	if session == null:
		return hit_window_seconds
	return session.difficulty_hit_window()


func _notify_segment_started() -> void:
	var traits := _traits()
	if traits != null:
		traits.on_segment_started()


func _traits() -> TraitController:
	if player == null or not is_instance_valid(player):
		return null
	return player.get_node_or_null("TraitController") as TraitController


func _negated_by_cipher() -> bool:
	var traits := _traits()
	return traits != null and traits.consume_cipher()


func _speed_blocked_by_emp() -> bool:
	var traits := _traits()
	return traits != null and traits.blocks_speed()


func _note_player_failure() -> void:
	var traits := _traits()
	if traits != null:
		traits.on_player_failure()


func _requeue_player_failure(node: RhythmNode) -> bool:
	var traits := _traits()
	if traits == null or not traits.try_leon_retry(node.override_retried):
		return false
	node.processed = false
	node.is_visual_only = false
	node.is_stealing = false
	node.override_retried = true
	node.travel_locked = false
	node.modulate.a = 1.0
	node.set_locked(false)
	node.scheduled_time = current_time + traits.leon_retry_delay()
	if not _nodes.has(node):
		_nodes.append(node)
	_debris.erase(node)
	print("[LEON RETRY]")
	return true


func _try_purge_delete(current: RhythmNode) -> void:
	var traits := _traits()
	if traits == null or not traits.wants_purge_delete():
		return
	if _delete_next_enemy_after(current):
		traits.mark_purge_spent()


func _delete_next_enemy_after(current: RhythmNode) -> bool:
	var best: RhythmNode = null
	for node in _nodes:
		if not is_instance_valid(node) or node == current or node.processed or node.is_visual_only or node.is_stealing:
			continue
		if node.node_category != RhythmNode.NodeCategory.COMBAT:
			continue
		if node.node_owner != RhythmNode.NodeOwner.ENEMY:
			continue
		if node.scheduled_time <= current.scheduled_time:
			continue
		if absf(node.scheduled_time - current_time) <= hit_window_for(node):
			continue
		if best == null or node.scheduled_time < best.scheduled_time:
			best = node
	if best == null:
		return false
	best.processed = true
	var tick := best.scheduled_tick
	_release_node(best)
	print("[PURGE DELETE] tick=%d" % tick)
	return true


func _resolve_enemy_attack_success() -> void:
	if player == null or enemy == null or not is_instance_valid(player) or not is_instance_valid(enemy):
		return
	enemy.perform_attack(player, true)


func _is_locked_player(node: RhythmNode) -> bool:
	return node.is_locked and node.node_owner == RhythmNode.NodeOwner.PLAYER


func judged_input_delta(raw_input_time: float, target_time: float) -> float:
	return raw_input_time + _input_offset_seconds() - target_time


func _judged_input_time() -> float:
	return current_time + _input_offset_seconds()


func _input_offset_seconds() -> float:
	var session := GameSession.get_session()
	if session == null:
		return 0.0
	return session.rhythm_input_offset_seconds()


func _closest_in_hit_window(judged_time: float) -> RhythmNode:
	var best: RhythmNode = null
	var best_distance := INF
	for node in _nodes:
		if not _is_judge_candidate(node):
			continue
		var distance := absf(node.scheduled_time - judged_time)
		if distance > hit_window_for(node) or distance >= best_distance:
			continue
		best_distance = distance
		best = node
	return best


func _closest_upcoming(judged_time: float) -> RhythmNode:
	var best: RhythmNode = null
	var best_until := INF
	for node in _nodes:
		if not _is_judge_candidate(node):
			continue
		var until := node.scheduled_time - judged_time
		if until <= hit_window_for(node) or until >= best_until:
			continue
		best_until = until
		best = node
	return best


func _is_judge_candidate(node: RhythmNode) -> bool:
	if not is_instance_valid(node) or node.processed or node.is_visual_only or node.is_stealing:
		return false
	return node.node_category == RhythmNode.NodeCategory.COMBAT


func _update_positions() -> void:
	if _node_container == null:
		return
	var lane := _lane()
	var approach := maxf(approach_seconds, 0.01)
	var active: Array[RhythmNode] = []
	for entry in _nodes:
		if not is_instance_valid(entry):
			continue
		active.append(entry)
		var node := entry as RhythmNode
		if node.is_visual_only:
			continue
		if node.is_stealing:
			node.visible = true
			node.position.y = float(lane["y"])
			_track_steal_effect(node)
			continue
		if not node.travel_locked:
			var from_x: float = float(lane["player_spawn"])
			if node.node_owner == RhythmNode.NodeOwner.ENEMY:
				from_x = float(lane["enemy_spawn"])
			var to_x: float = float(lane["center"])
			node.travel_from_x = from_x
			node.travel_to_x = to_x
			node.travel_from_time = node.scheduled_time - approach
			node.travel_to_time = node.scheduled_time
		var center_x := node.travel_to_x
		var span := node.travel_to_time - node.travel_from_time
		if span > 0.001 and current_time < node.travel_to_time:
			var amount := clampf((current_time - node.travel_from_time) / span, 0.0, 1.0)
			center_x = lerpf(node.travel_from_x, node.travel_to_x, amount)
		var until := node.scheduled_time - current_time
		node.visible = until <= approach + 0.001
		node.position = Vector2(center_x - NODE_SIZE * 0.5, float(lane["y"]))
	_nodes = active
	_place_judge_scope(lane)


func _lane() -> Dictionary:
	var width := maxf(_node_container.size.x, NODE_SIZE * 2.0)
	var height := maxf(_node_container.size.y, NODE_SIZE)
	var center := width * 0.5
	var spawns := _offscreen_spawn(width)
	return {
		"center": center,
		"zone": maxf(judge_zone_width, 1.0),
		"player_spawn": spawns.x,
		"enemy_spawn": spawns.y,
		"player_judge": center,
		"enemy_judge": center,
		"y": (height - NODE_SIZE) * 0.5,
		"width": width,
		"height": height,
	}


func _offscreen_spawn(width: float) -> Vector2:
	var half := RhythmNode.visual_half_width()
	var left := -half - SPAWN_MARGIN
	var right := width + half + SPAWN_MARGIN
	var viewport := _node_container.get_viewport()
	if viewport == null:
		return Vector2(left, right)
	var view := viewport.get_visible_rect()
	if view.size.x <= 1.0:
		return Vector2(left, right)
	var to_local := _node_container.get_global_transform_with_canvas().affine_inverse()
	var view_left := (to_local * Vector2(view.position.x, view.position.y)).x
	var view_right := (to_local * Vector2(view.end.x, view.position.y)).x
	if view_right < view_left:
		var swap := view_left
		view_left = view_right
		view_right = swap
	return Vector2(view_left - SPAWN_MARGIN - half, view_right + SPAWN_MARGIN + half)


func _ensure_judge_scope() -> void:
	if _node_container == null:
		return
	_judge_scope = _node_container.get_node_or_null("JudgeScope") as TextureRect
	if _judge_scope == null:
		_judge_scope = TextureRect.new()
		_judge_scope.name = "JudgeScope"
		_node_container.add_child(_judge_scope)
	_judge_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_judge_scope.texture = _SCOPE_TEXTURE
	_judge_scope.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_judge_scope.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_judge_scope.stretch_mode = TextureRect.STRETCH_SCALE
	_judge_scope.z_index = 8
	_judge_scope.visible = true


func _place_judge_scope(lane: Dictionary) -> void:
	if _judge_scope == null or _judge_scope.texture == null:
		return
	var shown := _judge_scope.texture.get_size() * SCOPE_VISUAL_SCALE
	var center := Vector2(float(lane["center"]), float(lane["y"]) + NODE_SIZE * 0.5)
	_judge_scope.size = shown
	_judge_scope.position = center - shown * 0.5
	_judge_scope.visible = true


func _track_steal_effect(node: RhythmNode) -> void:
	if _node_container == null:
		return
	var follow_id := node.get_instance_id()
	for child in _node_container.get_children():
		if child.name != "StealEffect" or child.get_meta(&"follow_id", 0) != follow_id:
			continue
		if child is Node2D:
			(child as Node2D).position = node.position + node.size * 0.5


func _become_debris(node: RhythmNode) -> void:
	if node == null or not is_instance_valid(node) or node.is_visual_only:
		return
	node.processed = true
	node.is_visual_only = true
	node.is_stealing = false
	node.modulate.a = 1.0
	var direction := -1.0 if node.node_owner == RhythmNode.NodeOwner.ENEMY else 1.0
	node.debris_velocity = Vector2(direction * debris_horizontal_speed, -debris_hop_speed)
	node.debris_time = 0.0
	node.z_index = 4
	_nodes.erase(node)
	if not _debris.has(node):
		_debris.append(node)


func _update_debris(step: float) -> void:
	if step <= 0.0 or _debris.is_empty():
		return
	var limit := 96.0
	if _node_container != null:
		limit = _node_container.size.y + 80.0
	var kept: Array[RhythmNode] = []
	for node in _debris:
		if not is_instance_valid(node):
			continue
		node.debris_time += step
		node.debris_velocity.y += debris_gravity * step
		node.position += node.debris_velocity * step
		if node.debris_time >= debris_lifetime or node.position.y > limit:
			node.queue_free()
			continue
		kept.append(node)
	_debris = kept


func _tick_steal_transitions(step: float) -> void:
	if step <= 0.0:
		return
	var snapshot: Array = _nodes.duplicate()
	for entry in snapshot:
		if not is_instance_valid(entry):
			continue
		var node := entry as RhythmNode
		if not node.is_stealing:
			continue
		node.steal_time_left -= step
		node.modulate.a = 0.35 if int(node.steal_time_left * 24.0) % 2 == 0 else 0.9
		if node.steal_time_left > 0.0:
			continue
		_finish_steal(node)


func _finish_steal(node: RhythmNode) -> void:
	if not is_instance_valid(node) or node.processed:
		return
	var lane := _lane()
	var center_x := node.position.x + NODE_SIZE * 0.5
	var mirrored := float(lane["center"]) * 2.0 - center_x
	node.is_stealing = false
	node.modulate.a = 1.0
	node.set_node_owner(RhythmNode.NodeOwner.ENEMY)
	node.travel_locked = true
	node.travel_from_x = mirrored
	node.travel_to_x = float(lane["center"])
	node.travel_from_time = current_time
	node.travel_to_time = node.scheduled_time
	node.position = Vector2(mirrored - NODE_SIZE * 0.5, float(lane["y"]))


func _release_node(node: RhythmNode) -> void:
	if is_instance_valid(node):
		node.queue_free()
	_nodes.erase(node)
	_debris.erase(node)


func _closest_pending() -> RhythmNode:
	var best: RhythmNode = null
	var best_distance := INF
	for node in _nodes:
		if not is_instance_valid(node) or node.processed or node.is_visual_only or node.is_stealing:
			continue
		if node.node_category != RhythmNode.NodeCategory.COMBAT:
			continue
		var distance := absf(node.scheduled_time - current_time)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


func _pending_count() -> int:
	var count := 0
	for node in _nodes:
		if is_instance_valid(node) and not node.processed:
			count += 1
	return count


func _combat_busy() -> bool:
	return not _visual_idle(player) or not _visual_idle(enemy)


func _visual_idle(actor: CombatActor) -> bool:
	if actor == null or not is_instance_valid(actor) or not actor.is_alive():
		return false
	if actor.is_attacking():
		return false
	var sprite := actor.get_node_or_null("MotionRoot/VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = actor.get_node_or_null("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return true
	return sprite.animation != &"attack" and sprite.animation != &"hit"


func _on_actor_died(_actor: CombatActor) -> void:
	_stop_rhythm()


func _stop_rhythm() -> void:
	if stopped:
		return
	stopped = true
	_flow_active = false
	_auto_lock_used = false
	_stole_this_segment = false
	reset_rhythm_speed()
	_clear_nodes()


func _clear_nodes() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	for node in _debris:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	_debris.clear()


func _battle_is_over() -> bool:
	return combat_controller != null and bool(combat_controller.get("battle_finished"))


func _encounter_input_blocked() -> bool:
	var encounter := get_node_or_null("../EncounterController") as EncounterController
	return encounter != null and encounter.input_blocked


func _encounter_holds_rhythm() -> bool:
	var encounter := get_node_or_null("../EncounterController") as EncounterController
	return encounter != null and encounter.rhythm_hold


func _play_parry_effect(actor: CombatActor) -> void:
	if actor == null:
		return
	var effects := get_tree().get_first_node_in_group(&"combat_effects")
	if effects != null and effects.has_method("play_parry"):
		var at := actor.global_position
		if actor.has_method("get_effect_center_global_position"):
			at = actor.call("get_effect_center_global_position") as Vector2
		effects.call("play_parry", at)


func _direct_attack_debug_enabled() -> bool:
	return combat_controller != null and bool(combat_controller.get("direct_attack_debug"))


func _bind_scene_nodes() -> void:
	if player == null:
		player = _node_at("../Stage/Player", "../World/Player") as CombatActor
	if enemy == null:
		enemy = _node_at("../Stage/Enemy", "../World/Enemy") as CombatActor
	if panel == null:
		panel = _node_at("../RhythmLayer/RhythmPanel", "../UI/Layout/RhythmPanel") as Control
	if combat_controller == null:
		combat_controller = get_node_or_null("../CombatTestController")


func _node_at(primary: String, alternate: String) -> Node:
	var node := get_node_or_null(primary)
	if node == null:
		node = get_node_or_null(alternate)
	return node


func _build_pattern(owners: Array[int], gaps: Array[int], forced: bool) -> Array[Dictionary]:
	var pattern: Array[Dictionary] = []
	var tick := 0
	var one_tick_run := 0
	for index in owners.size():
		var gap := maxi(turn_lead_in_ticks, 0)
		if index > 0:
			if forced and index - 1 < gaps.size():
				gap = gaps[index - 1]
			elif forced:
				gap = 2
			else:
				gap = choose_tick_gap(one_tick_run)
			if gap == 1:
				one_tick_run += 1
			else:
				one_tick_run = 0
		tick += gap
		pattern.append({
			"node_owner": owners[index],
			"tick": tick,
		})
	return pattern


func _gap_weight_table() -> Array[int]:
	var weights: Array[int] = [0, 0, 0, 0, 0]
	for index in mini(gap_weights.size(), weights.size()):
		weights[index] = maxi(gap_weights[index], 0)
	return weights


func _longest_run(owners: Array[int]) -> int:
	var best := 0
	var run := 0
	var previous := -1
	for kind in owners:
		if kind == previous:
			run += 1
		else:
			previous = kind
			run = 1
		best = maxi(best, run)
	return best


func _place_owners_with_limit(pool_source: Array[int], limit: int) -> Array[int]:
	var pool: Array[int] = []
	pool.append_array(pool_source)
	var result: Array[int] = []
	var run_owner := -1
	var run_count := 0
	while not pool.is_empty():
		var candidates: Array[int] = []
		for index in pool.size():
			if int(pool[index]) == run_owner and run_count >= limit:
				continue
			candidates.append(index)
		if candidates.is_empty():
			for index in pool.size():
				candidates.append(index)
		var pick := candidates[_rng.randi_range(0, candidates.size() - 1)]
		var kind := int(pool[pick])
		pool.remove_at(pick)
		if kind == run_owner:
			run_count += 1
		else:
			run_owner = kind
			run_count = 1
		result.append(kind)
	return result


func _owner_from(value: Variant) -> int:
	if value is String or value is StringName:
		return RhythmNode.NodeOwner.ENEMY if str(value).to_upper() == "E" else RhythmNode.NodeOwner.PLAYER
	return int(value)


func _show_judge_feedback(text: String) -> void:
	if _feedback_label == null:
		return
	_feedback_label.text = text
	_feedback_label.visible = true
	_feedback_left = judge_feedback_seconds
	var color := Color(0.95, 0.95, 0.9)
	if text == "HIT":
		color = Color(0.55, 0.95, 1.0)
	elif text == "PARRY":
		color = Color(1.0, 0.62, 0.28)
	elif text == "MISS":
		color = Color(1.0, 0.45, 0.42)
	elif text == "BAD":
		color = Color(1.0, 0.72, 0.28)
	elif text == "WHIFF":
		color = Color(0.95, 0.85, 0.35)
	elif text == "SKIP":
		color = Color(0.72, 0.55, 0.95)
	elif text == "STEAL":
		color = Color(0.95, 0.45, 0.75)
	elif text.begins_with("SLOW"):
		color = Color(0.4, 0.85, 0.78)
	elif text.begins_with("FAST"):
		color = Color(1.0, 0.45, 0.7)
	_feedback_label.add_theme_color_override(&"font_color", color)


func _tick_feedback(delta: float) -> void:
	if _feedback_label == null or not _feedback_label.visible:
		return
	_feedback_left -= maxf(delta, 0.0)
	if _feedback_left <= 0.0:
		_hide_feedback()


func _hide_feedback() -> void:
	_feedback_left = 0.0
	if _feedback_label == null:
		return
	_feedback_label.visible = false
	_feedback_label.text = ""


func _shuffle(items: Array[int]) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var tmp = items[index]
		items[index] = items[swap_index]
		items[swap_index] = tmp


func _set_debug(text: String) -> void:
	last_debug = text
	judgment_log.append(text)
	if _debug_label != null:
		_debug_label.text = text


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
