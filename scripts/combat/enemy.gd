class_name Enemy
extends CombatActor

## 모든 전투 상대가 같이 쓰는 actor.
## HP와 공격력은 combat_profile의 임시값이다. 방향은 flip_h로 둔다.

@export var combat_profile: EnemyCombatProfile

var definition: EnemyDefinition
var visual_scale: float = 1.0

var _phasing: bool = false
var _phase_death_handled: bool = false


func _ready() -> void:
	_apply_combat_profile()
	super._ready()
	_apply_visual_scale()


func apply_definition(next_definition: EnemyDefinition) -> void:
	if next_definition == null:
		push_error("Enemy.apply_definition received a null definition.")
		return
	definition = next_definition
	combat_profile = next_definition.combat_profile
	animation_profile = next_definition.animation_profile
	visual_scale = next_definition.visual_scale
	_phasing = false
	_phase_death_handled = false
	_death_notified = false
	_state = ActionState.IDLE
	_apply_combat_profile()
	current_hp = max_hp
	if _sprite != null and animation_profile != null:
		_sprite.sprite_frames = animation_profile.build_sprite_frames()
		_sprite.play(&"idle")
	_apply_visual_scale()
	_refresh_dialogue_speaker()
	if is_inside_tree():
		health_changed.emit(current_hp, max_hp)


func is_alive() -> bool:
	return super.is_alive() and not _phasing


func set_dialogue_paused(paused: bool) -> void:
	super.set_dialogue_paused(paused)
	if not _phasing or _sprite == null:
		return
	if paused:
		_sprite.pause()
	else:
		_sprite.play()


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _dialogue_paused or _phasing:
		return
	if not is_alive():
		return
	var before_hp := current_hp
	current_hp = clampi(current_hp - maxi(amount, 0), 0, max_hp)
	health_changed.emit(current_hp, max_hp)
	if current_hp < before_hp:
		_on_health_lost(attacker)
	if current_hp > 0:
		_play_combat_animation(&"hit", ActionState.HIT)
		_knockback(attacker)
	elif _can_phase():
		_begin_phase_death()
	else:
		_begin_death()


func _on_animation_finished() -> void:
	if _phasing and _sprite != null and _sprite.animation == &"death":
		_after_phase_death()
		return
	if _phasing and _sprite != null and _sprite.animation == _transition_animation():
		_finish_phase_transition()
		return
	super._on_animation_finished()


func _apply_combat_profile() -> void:
	if combat_profile == null:
		push_error("%s has no EnemyCombatProfile." % name)
		return
	max_hp = maxi(combat_profile.max_hp, 1)
	attack_power = maxi(combat_profile.attack_damage, 0)
	if definition != null and definition.max_hp > 0:
		max_hp = definition.max_hp


func _can_phase() -> bool:
	return definition != null and definition.next_phase != null


func _transition_animation() -> StringName:
	if definition == null or definition.phase_transition_animation == &"":
		return &"cast"
	return definition.phase_transition_animation


func _begin_phase_death() -> void:
	_phasing = true
	_phase_death_handled = false
	_stop_motion(true)
	var encounter := _encounter()
	if encounter != null:
		if definition != null:
			encounter.grant_defeated_override(definition.enemy_id)
		encounter.hold_for_phase_transition()
	var has_death := _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"death") and _sprite.sprite_frames.get_frame_count(&"death") > 0
	if has_death:
		_sprite.play(&"death")
		_sprite.frame = 0
		_sprite.frame_progress = 0.0
		GameAudio.play_death()
		return
	_after_phase_death()


func _after_phase_death() -> void:
	if _phase_death_handled:
		return
	_phase_death_handled = true
	var encounter := _encounter()
	if encounter != null:
		encounter.present_phase_death_dialogue(self)
		return
	resume_phase_cast()


func resume_phase_cast() -> void:
	if not _phasing or not is_inside_tree():
		return
	if definition != null and definition.enemy_id == &"leon":
		print("LEON CAST")
	print("PHASE CAST")
	_play_phase_effect()
	var anim_name := _transition_animation()
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim_name):
		_sprite.play(anim_name)
		_sprite.frame = 0
		_sprite.frame_progress = 0.0
		return
	push_error("Phase transition animation '%s' is missing." % anim_name)
	_finish_phase_transition()


func _finish_phase_transition() -> void:
	if definition == null or definition.next_phase == null:
		_phasing = false
		return
	var next_definition := definition.next_phase
	var kept_position := position
	apply_definition(next_definition)
	position = kept_position
	print("PHASE: %s" % next_definition.display_name)
	if next_definition.enemy_id == &"arc":
		print("ARC APPLY")
	var encounter := _encounter()
	if encounter != null:
		encounter.present_phase(self)


func _play_phase_effect() -> void:
	if definition == null or definition.phase_transition_effect_id == &"":
		return
	var effects := get_tree().get_first_node_in_group(&"combat_effects")
	if effects != null and effects.has_method("play_effect"):
		effects.call("play_effect", definition.phase_transition_effect_id, get_effect_center_global_position())


func _composition_lift() -> float:
	var node: Node = self
	while node != null:
		if node.has_method("combat_visual_offset_y"):
			return float(node.call("combat_visual_offset_y"))
		node = node.get_parent()
	return 0.0


func _apply_visual_scale() -> void:
	var extra := Vector2.ZERO
	var anchor_extra := Vector2.ZERO
	if definition != null:
		extra = definition.visual_offset
		anchor_extra = definition.effect_anchor_offset
	CharacterVisual.apply_actor(self, extra, anchor_extra, visual_scale, _composition_lift())


func _encounter() -> EncounterController:
	var node: Node = self
	while node != null:
		var found := node.get_node_or_null("EncounterController") as EncounterController
		if found != null:
			return found
		node = node.get_parent()
	return null
