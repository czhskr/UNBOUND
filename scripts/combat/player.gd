class_name Player
extends CombatActor

const DEBUG_ATTACK_VALUE := 100

var active_form_id: StringName = &""
var active_trait_id: StringName = &""
var debug_attack_override_enabled: bool = false


func get_effective_attack() -> int:
	if debug_attack_override_enabled:
		return DEBUG_ATTACK_VALUE
	return attack_power


func apply_form(form: FormDefinition) -> void:
	if form == null:
		push_error("Player.apply_form received a null form.")
		return
	if _sprite == null:
		_sprite = get_node_or_null("MotionRoot/VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	animation_profile = form.animation_profile
	active_form_id = form.form_id
	FormVisual.apply_to_sprite(_sprite, form)
	_trait_controller().apply_trait(form.trait_id)
	active_trait_id = _trait_controller().get_active_trait_id()


func get_active_trait_id() -> StringName:
	return _trait_controller().get_active_trait_id()


func notify_parry_success() -> bool:
	var started_emp := _trait_controller().on_successful_parry()
	_trait_controller().notify_player_parry_success(_hook_context(null))
	return started_emp


func notify_combat_started(stage_id: StringName = &"") -> void:
	var context := _hook_context(null)
	context["stage_id"] = stage_id
	_trait_controller().notify_combat_started(context)


func notify_combat_ended(stage_id: StringName = &"") -> void:
	var context := _hook_context(null)
	context["stage_id"] = stage_id
	_trait_controller().notify_combat_ended(context)


func perform_attack(target: CombatActor, deal_damage: bool = true) -> void:
	var committed := _attack_will_start(target, deal_damage)
	if committed:
		_attack_damage_override = _trait_controller().attack_damage_for_hit(get_effective_attack())
	else:
		_attack_damage_override = -1
	super.perform_attack(target, deal_damage)
	if committed:
		_trait_controller().notify_player_attack_success(_hook_context(target))
	_trait_controller().resolve_seraph_after_hit(committed)


func _attack_will_start(target: CombatActor, deal_damage: bool) -> bool:
	if not deal_damage or _dialogue_paused or not is_alive():
		return false
	if target == null or not is_instance_valid(target):
		return false
	if _sprite == null or _sprite.sprite_frames == null:
		return false
	return _sprite.sprite_frames.has_animation(&"attack")


func take_damage(amount: int, attacker: Node2D = null) -> void:
	if amount > 0 and is_alive() and not _dialogue_paused and _trait_controller().consume_aegis_block():
		print("[AEGIS BLOCK]")
		return
	super.take_damage(amount, attacker)


func _on_health_lost(attacker: Node2D) -> void:
	super._on_health_lost(attacker)
	_trait_controller().notify_player_damaged(_hook_context(attacker))


func _trait_controller() -> TraitController:
	var existing := get_node_or_null("TraitController") as TraitController
	if existing != null:
		return existing
	var created := TraitController.new()
	created.name = "TraitController"
	add_child(created)
	return created


func _hook_context(other: Node) -> Dictionary:
	var context := {"player": self}
	if other != null:
		context["target"] = other
	return context
