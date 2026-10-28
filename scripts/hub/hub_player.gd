extends Node2D

## Entry에 고정된 주인공. 이동과 전투 판정은 하지 않는다.

var input_enabled: bool = true
var active_form_id: StringName = &""
var active_trait_id: StringName = &""

@onready var _sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D


func _ready() -> void:
	_keep_visual_scale()
	if _sprite == null:
		push_error("HubPlayer is missing AnimatedSprite2D.")
		return
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	apply_form(GameSession.get_session().get_current_form())


func apply_form(form: FormDefinition) -> void:
	if form == null:
		push_error("HubPlayer.apply_form received a null form.")
		return
	if _sprite == null:
		_sprite = get_node_or_null("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	active_form_id = form.form_id
	active_trait_id = form.trait_id
	FormVisual.apply_to_sprite(_sprite, form)
	_keep_visual_scale()


func get_active_trait_id() -> StringName:
	return active_trait_id


func _keep_visual_scale() -> void:
	var extra := Vector2.ZERO
	var form := GameSession.get_session().get_current_form()
	if form != null:
		extra = form.visual_offset
	CharacterVisual.apply_actor(self, extra)


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		_play_idle()


func _process(_delta: float) -> void:
	_play_idle()


func _play_idle() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(&"idle"):
		return
	if _sprite.animation != &"idle":
		_sprite.play(&"idle")
