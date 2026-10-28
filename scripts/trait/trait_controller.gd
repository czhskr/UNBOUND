class_name TraitController
extends Node

## 플레이어가 장착한 오버라이드 특성 하나와 런타임 상태만 담당한다.
## 공유 TraitDefinition에는 누적이나 쿨타임을 두지 않는다. 적에게는 적용하지 않는다.
## 쿨타임은 Time.get_ticks_msec() 기준이다. 리듬 배율과 Engine.time_scale은 쓰지 않는다.
## 세그먼트 시작은 쿨타임, 추적 누적, 상위 권한 강화를 지우지 않는다.

## 재실행이 노드를 다시 넣는 지연. 쿨타임이 아니다.
const LEON_RETRY_DELAY_SECONDS := 0.45

var active_trait: TraitDefinition
var owner_player: Player
var vector_stacks: int = 0
var seraph_armed: bool = false
var arc_emp_active: bool = false

var _combat_started: bool = false
var _combat_ended: bool = false
var _cooldown_until_msec: int = 0
var _suppress_seraph_arm: bool = false


func _ready() -> void:
	owner_player = get_parent() as Player


func apply_trait(trait_id: StringName) -> void:
	if active_trait != null and active_trait.trait_id == trait_id:
		return
	clear_trait()
	if trait_id == &"":
		return
	if not TraitRegistry.has_trait(trait_id):
		push_error("Unknown trait id '%s'. Combat continues without a trait." % trait_id)
		return
	var definition := TraitRegistry.get_trait(trait_id)
	if definition == null or definition.behavior == null:
		return
	active_trait = definition
	definition.behavior.on_equipped(_context())


func clear_trait() -> void:
	if active_trait != null and active_trait.behavior != null:
		active_trait.behavior.on_unequipped(_context())
	active_trait = null
	_reset_runtime_state()


func get_active_trait_id() -> StringName:
	if active_trait == null:
		return &""
	return active_trait.trait_id


func get_active_trait() -> TraitDefinition:
	return active_trait


func on_segment_started() -> void:
	arc_emp_active = false


func parry_window_multiplier() -> float:
	if not _is_trait(&"sentry_guard") or active_trait == null:
		return 1.0
	return maxf(active_trait.parry_window_multiplier, 0.0)


func vector_indicator_text() -> String:
	if not _is_trait(&"vector_tracking") or active_trait == null or vector_stacks <= 0:
		return ""
	var bonus := vector_stacks * active_trait.damage_per_stack
	if bonus <= 0:
		return ""
	if bonus > 0:
		return "+%d" % bonus
	return str(bonus)


func attack_damage_for_hit(base_damage: int) -> int:
	var amount := maxi(base_damage, 0)
	if _is_trait(&"vector_tracking") and active_trait != null:
		var cap := maxi(active_trait.max_stacks, 0)
		if cap > 0:
			vector_stacks = mini(vector_stacks + 1, cap)
		else:
			vector_stacks += 1
		amount += vector_stacks * active_trait.damage_per_stack
	if _is_trait(&"seraph_authority") and seraph_armed and active_trait != null:
		amount = maxi(int(round(float(amount) * active_trait.damage_multiplier)), 0)
		seraph_armed = false
		_start_cooldown()
		_suppress_seraph_arm = true
	return amount


func resolve_seraph_after_hit(dealt: bool) -> void:
	var consumed := _suppress_seraph_arm
	_suppress_seraph_arm = false
	if consumed or not dealt:
		return
	if not _is_trait(&"seraph_authority") or seraph_armed or not _cooldown_ready():
		return
	seraph_armed = true
	print("[SERAPH ARM]")


func on_player_failure() -> void:
	if _is_trait(&"vector_tracking"):
		vector_stacks = 0


func on_successful_parry() -> bool:
	if not _is_trait(&"arc_emp") or arc_emp_active:
		return false
	arc_emp_active = true
	return true


func consume_aegis_block() -> bool:
	if not _is_trait(&"aegis_firewall") or not _cooldown_ready():
		return false
	_start_cooldown()
	return true


func consume_cipher() -> bool:
	return _is_trait(&"cipher_encrypt")


func wants_purge_delete() -> bool:
	return _is_trait(&"purge_delete") and _cooldown_ready()


func mark_purge_spent() -> void:
	_start_cooldown()


func try_leon_retry(already_retried: bool) -> bool:
	if not _is_trait(&"leon_retry") or already_retried or not _cooldown_ready():
		return false
	_start_cooldown()
	return true


func leon_retry_delay() -> float:
	return LEON_RETRY_DELAY_SECONDS


func blocks_speed() -> bool:
	return _is_trait(&"arc_emp") and arc_emp_active


func notify_combat_started(context: Dictionary = {}) -> void:
	if _combat_started:
		return
	_combat_started = true
	if active_trait == null or active_trait.behavior == null:
		return
	active_trait.behavior.on_combat_started(context)


func notify_player_attack_success(context: Dictionary = {}) -> void:
	if active_trait == null or active_trait.behavior == null:
		return
	active_trait.behavior.on_player_attack_success(context)


func notify_player_parry_success(context: Dictionary = {}) -> void:
	if active_trait == null or active_trait.behavior == null:
		return
	active_trait.behavior.on_player_parry_success(context)


func notify_player_damaged(context: Dictionary = {}) -> void:
	if active_trait == null or active_trait.behavior == null:
		return
	active_trait.behavior.on_player_damaged(context)


func notify_combat_ended(context: Dictionary = {}) -> void:
	if _combat_ended:
		return
	_combat_ended = true
	if active_trait == null or active_trait.behavior == null:
		return
	active_trait.behavior.on_combat_ended(context)


func _start_cooldown() -> void:
	if active_trait == null or active_trait.cooldown_seconds <= 0.0:
		_cooldown_until_msec = 0
		return
	var wait_ms := int(round(active_trait.cooldown_seconds * 1000.0))
	_cooldown_until_msec = Time.get_ticks_msec() + maxi(wait_ms, 0)


func _cooldown_ready() -> bool:
	if active_trait == null or active_trait.cooldown_seconds <= 0.0:
		return true
	return Time.get_ticks_msec() >= _cooldown_until_msec


func _reset_runtime_state() -> void:
	_combat_started = false
	_combat_ended = false
	vector_stacks = 0
	seraph_armed = false
	_suppress_seraph_arm = false
	arc_emp_active = false
	_cooldown_until_msec = 0


func _is_trait(trait_id: StringName) -> bool:
	return active_trait != null and active_trait.trait_id == trait_id


func _context() -> Dictionary:
	return {"player": owner_player}
