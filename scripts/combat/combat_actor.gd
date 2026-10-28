class_name CombatActor
extends Node2D

## 플레이어와 적이 공유하는 최소 전투 처리.
## 키 입력은 넣지 않는다. 리듬 시스템은 perform_attack()만 호출하면 된다.

signal health_changed(current_hp: int, max_hp: int)
signal died(actor: CombatActor)
signal death_animation_finished(actor: CombatActor)
signal attack_started(actor: CombatActor)
signal damage_dealt(attacker: CombatActor, target: CombatActor, amount: int)

enum ActionState { IDLE, ATTACK, HIT, DEAD }

@export var max_hp: int = 100
@export var attack_power: int = 20
## 이번 공격 한 번의 피해. -1이면 attack_power를 쓴다. 오버라이드 특성만 넣는다.
var _attack_damage_override: int = -1
## 연출 타이밍용. 피해 적용에는 사용하지 않는다.
@export var attack_hit_frame: int = 7
@export var animation_profile: CharacterAnimationProfile
## 상대 몸 앞에서 멈추는 간격. 72는 더 깊게 겹치는 시험값이며 최종이 아니다.
@export var attack_stop_gap: float = 72.0
## 테스트용 피격 밀림. 최종 밸런스가 아니다.
@export var hit_knockback_distance: float = 12.0
@export var motion_out_seconds: float = 0.07
@export var motion_return_seconds: float = 0.16

var current_hp: int = 100

var _state: ActionState = ActionState.IDLE
var _death_notified: bool = false
var _dialogue_paused: bool = false
var _motion_tween: Tween
var _motion_token: int = 0
var _attack_token: int = -1
var _awaiting_attack_end: bool = false

@onready var _sprite: AnimatedSprite2D = get_node_or_null("MotionRoot/VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
@onready var _motion: Node2D = get_node_or_null("MotionRoot") as Node2D


func _ready() -> void:
	max_hp = maxi(max_hp, 1)
	current_hp = max_hp
	if _sprite == null:
		_sprite = get_node_or_null("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	if _sprite == null:
		_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite == null:
		push_error("%s requires a child AnimatedSprite2D." % name)
		return
	_ensure_effect_anchor()
	if animation_profile == null:
		push_error("%s has no CharacterAnimationProfile." % name)
		return
	_sprite.sprite_frames = animation_profile.build_sprite_frames()
	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"idle")
	if not attack_started.is_connected(_play_attack_sfx):
		attack_started.connect(_play_attack_sfx)
	health_changed.emit(current_hp, max_hp)
	_refresh_dialogue_speaker()
	CharacterVisual.apply_actor(self)


func _play_attack_sfx(_actor: CombatActor) -> void:
	GameAudio.play_attack()


func is_alive() -> bool:
	return _state != ActionState.DEAD


func is_attacking() -> bool:
	return _state == ActionState.ATTACK


func set_dialogue_paused(paused: bool) -> void:
	if _dialogue_paused == paused:
		return
	_dialogue_paused = paused
	if _state == ActionState.DEAD:
		return
	var motion_active := _motion_tween != null and _motion_tween.is_valid()
	if _sprite != null and (_state != ActionState.IDLE or motion_active):
		if paused:
			_sprite.pause()
		else:
			_sprite.play()
	if _motion_tween != null and _motion_tween.is_valid():
		if paused:
			_motion_tween.pause()
		else:
			_motion_tween.play()


func _refresh_dialogue_speaker() -> void:
	var speaker := &"enemy"
	if self is Player:
		speaker = &"player"
	elif self is Enemy:
		var enemy := self as Enemy
		if enemy.definition != null and enemy.definition.enemy_id != &"":
			speaker = enemy.definition.enemy_id
	set_dialogue_speaker(speaker)


func dialogue_anchor() -> Marker2D:
	var motion := _motion
	if motion == null:
		motion = get_node_or_null("MotionRoot") as Node2D
	var anchor := get_node_or_null("MotionRoot/DialogueAnchor") as Marker2D
	if anchor == null and motion != null:
		anchor = Marker2D.new()
		anchor.name = "DialogueAnchor"
		anchor.position = Vector2(0.0, -80.0)
		motion.add_child(anchor)
	if anchor == null:
		return null
	if not anchor.is_in_group(&"dialogue_anchor"):
		anchor.add_to_group(&"dialogue_anchor")
	return anchor


func set_dialogue_speaker(speaker_id: StringName) -> void:
	var anchor := dialogue_anchor()
	if anchor == null or speaker_id == &"":
		return
	anchor.set_meta(&"speaker_id", speaker_id)


func perform_attack(target: CombatActor, deal_damage: bool = true) -> void:
	if _dialogue_paused or not is_alive():
		return
	if target == null or not is_instance_valid(target):
		return
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(&"attack"):
		return

	# 잠금 WHIFF는 제자리 애니메이션만 재생한다. 전진 공격은 도착 뒤에 시작한다.
	if not deal_damage and not self is Enemy:
		_play_combat_animation(&"attack", ActionState.ATTACK)
		attack_started.emit(self)
		return
	_lunge_toward(target, deal_damage)


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _dialogue_paused or not is_alive():
		return

	var before_hp := current_hp
	current_hp = clampi(current_hp - maxi(amount, 0), 0, max_hp)
	health_changed.emit(current_hp, max_hp)
	if current_hp < before_hp:
		_on_health_lost(attacker)
	if current_hp > 0:
		_play_combat_animation(&"hit", ActionState.HIT)
		_knockback(attacker)
	else:
		_begin_death()


func _on_health_lost(_attacker: Node2D) -> void:
	_play_hit_effect()


func get_effect_center_global_position() -> Vector2:
	var anchor := get_node_or_null("MotionRoot/EffectAnchor") as Node2D
	if anchor != null:
		return anchor.global_position
	if _sprite != null:
		return _sprite.global_position
	return global_position


func _ensure_effect_anchor() -> void:
	if _motion == null:
		_motion = get_node_or_null("MotionRoot") as Node2D
	if _motion == null:
		return
	if _motion.get_node_or_null("EffectAnchor") != null:
		return
	var anchor := Marker2D.new()
	anchor.name = "EffectAnchor"
	anchor.position = Vector2(0, -24)
	_motion.add_child(anchor)


func _play_hit_effect() -> void:
	var effects := get_tree().get_first_node_in_group(&"combat_effects")
	if effects != null and effects.has_method("play_hit"):
		effects.call("play_hit", get_effect_center_global_position())


func _begin_death() -> void:
	if _state == ActionState.DEAD:
		return
	_state = ActionState.DEAD
	_stop_motion(true)
	GameAudio.play_death()
	var has_death := _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"death")
	if has_death and _sprite.sprite_frames.get_frame_count(&"death") > 0:
		_sprite.play(&"death")
		_sprite.frame = 0
		_sprite.frame_progress = 0.0
	died.emit(self)
	if not has_death or _sprite.sprite_frames.get_frame_count(&"death") <= 0:
		_notify_death_animation_finished()


func _play_combat_animation(anim: StringName, next_state: ActionState) -> void:
	if not is_alive() or _sprite == null:
		return
	_state = next_state
	_sprite.play(anim)
	_sprite.frame = 0
	_sprite.frame_progress = 0.0


func _on_animation_finished() -> void:
	if not is_instance_valid(_sprite):
		return
	if _state == ActionState.DEAD:
		if _sprite.animation == &"death":
			_hold_death_frame()
			_notify_death_animation_finished()
		return
	if _awaiting_attack_end and _sprite.animation == &"attack" and _attack_token == _motion_token:
		_awaiting_attack_end = false
		_start_dash_out(_attack_token)
		return
	if _sprite.animation == &"death":
		return
	if _state != ActionState.ATTACK and _state != ActionState.HIT:
		return
	_state = ActionState.IDLE
	_sprite.play(&"idle")


func _lunge_toward(target: Node2D, deal_damage: bool) -> void:
	if target == null:
		return
	var target_x := _visual_x(target)
	var direction := 1.0 if target_x >= global_position.x else -1.0
	var goal := target_x - direction * attack_stop_gap
	var offset_x := goal - global_position.x
	if direction > 0.0:
		offset_x = maxf(offset_x, 0.0)
	else:
		offset_x = minf(offset_x, 0.0)
	_play_dash_in(Vector2(offset_x, 0.0), target, deal_damage)
	_notify_combat_camera(direction)


func _visual_x(actor: Node2D) -> float:
	var visual_x := actor.global_position.x
	var motion := actor.get_node_or_null("MotionRoot") as Node2D
	if motion != null:
		visual_x += motion.position.x * actor.global_scale.x
	return visual_x


func _knockback(attacker: Node2D) -> void:
	var direction := -1.0 if self is Player else 1.0
	if attacker != null:
		direction = 1.0 if global_position.x >= attacker.global_position.x else -1.0
	_play_motion(Vector2(direction * hit_knockback_distance, 0.0))


func _play_dash_in(offset: Vector2, target: Node2D, deal_damage: bool) -> void:
	if _state == ActionState.DEAD or _motion == null:
		return
	_stop_motion(false)
	var token := _motion_token
	_motion_tween = create_tween()
	_motion_tween.tween_property(_motion, "position", offset, maxf(motion_out_seconds, 0.01))
	_motion_tween.tween_callback(_begin_attack_animation.bind(token, target, deal_damage))


func _begin_attack_animation(token: int, target: Node2D, deal_damage: bool) -> void:
	if token != _motion_token or _state == ActionState.DEAD or not is_alive():
		return
	_attack_token = token
	_awaiting_attack_end = true
	_play_combat_animation(&"attack", ActionState.ATTACK)
	attack_started.emit(self)
	if not deal_damage:
		_attack_damage_override = -1
	if deal_damage and target is CombatActor and is_instance_valid(target) and (target as CombatActor).is_alive():
		var victim := target as CombatActor
		var amount := attack_power
		if _attack_damage_override >= 0:
			amount = _attack_damage_override
			_attack_damage_override = -1
		damage_dealt.emit(self, victim, amount)
		victim.take_damage(amount, self)
	var frame_count := 0
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"attack"):
		frame_count = _sprite.sprite_frames.get_frame_count(&"attack")
	if frame_count <= 0:
		_awaiting_attack_end = false
		_start_dash_out(token)


func _start_dash_out(token: int) -> void:
	if token != _motion_token or _state == ActionState.DEAD or _motion == null:
		return
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = create_tween()
	_motion_tween.tween_property(_motion, "position", Vector2.ZERO, maxf(motion_return_seconds, 0.01))
	_motion_tween.tween_callback(_finish_attack_motion.bind(token))


func _finish_attack_motion(token: int) -> void:
	if token != _motion_token or _state == ActionState.DEAD:
		return
	if _motion != null:
		_motion.position = Vector2.ZERO
	if _state == ActionState.ATTACK:
		_state = ActionState.IDLE
		if _sprite != null:
			_sprite.play(&"idle")


func _play_motion(offset: Vector2) -> void:
	if _state == ActionState.DEAD or _motion == null:
		return
	_stop_motion(false)
	_motion_tween = create_tween()
	_motion_tween.tween_property(_motion, "position", offset, maxf(motion_out_seconds, 0.01))
	_motion_tween.tween_property(_motion, "position", Vector2.ZERO, maxf(motion_return_seconds, 0.01))


func _stop_motion(reset_position: bool) -> void:
	_motion_token += 1
	_awaiting_attack_end = false
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null
	if reset_position and _motion != null:
		_motion.position = Vector2.ZERO


func _exit_tree() -> void:
	_stop_motion(true)


func _notify_combat_camera(direction: float) -> void:
	var node := get_parent()
	while node != null:
		if node.has_method("kick_combat_camera"):
			node.call("kick_combat_camera", direction)
			return
		node = node.get_parent()


func _hold_death_frame() -> void:
	if _sprite == null or _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(&"death"):
		return
	var count := _sprite.sprite_frames.get_frame_count(&"death")
	if count <= 0:
		return
	_sprite.pause()
	_sprite.frame = count - 1
	_sprite.frame_progress = 0.0


func _notify_death_animation_finished() -> void:
	if _death_notified:
		return
	_death_notified = true
	death_animation_finished.emit(self)
