class_name CombatEffectPlayer
extends Node

## 피격, 패링, 전환 이펙트를 한 곳에서 재생한다.
## FPS와 배율은 SpriteTest에 있던 임시값이다. 최종 튜닝이 아니다.

const HIT_FPS := 30.0
const HIT_SCALE := 1.0
const PARRY_FPS := 45.0
const PARRY_SCALE := 0.5
const LEON_CAST_FPS := 23.0
const LEON_CAST_SCALE := 1.0


func _ready() -> void:
	add_to_group(&"combat_effects")


func play_hit(at: Vector2) -> void:
	_play("res://assets/effects/hit", "hit", 1, 6, HIT_FPS, HIT_SCALE, at)


func play_parry(at: Vector2) -> void:
	_play("res://assets/effects/parry", "parry", 0, 14, PARRY_FPS, PARRY_SCALE, at)


func play_effect(effect_id: StringName, at: Vector2) -> void:
	if effect_id == &"hit":
		play_hit(at)
	elif effect_id == &"parry":
		play_parry(at)
	elif effect_id == &"leon_cast":
		_play("res://assets/effects/leon_cast", "leon_cast", 1, 14, LEON_CAST_FPS, LEON_CAST_SCALE, at)
	elif effect_id != &"":
		push_warning("Unknown combat effect '%s'." % effect_id)


func _play(
	root: String,
	prefix: String,
	start_frame: int,
	end_frame: int,
	fps: float,
	effect_scale: float,
	at: Vector2
) -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"play")
	frames.set_animation_speed(&"play", fps)
	frames.set_animation_loop(&"play", false)
	for frame_index in range(start_frame, end_frame + 1):
		var path := "%s/%s_%03d.png" % [root, prefix, frame_index]
		if not ResourceLoader.exists(path):
			push_error("Combat effect is missing %s." % path)
			continue
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame(&"play", texture)
	if frames.get_frame_count(&"play") <= 0:
		return
	var sprite := AnimatedSprite2D.new()
	sprite.name = "%sEffect" % prefix
	sprite.sprite_frames = frames
	sprite.animation = &"play"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(effect_scale, effect_scale)
	sprite.z_index = 30
	add_child(sprite)
	sprite.global_position = at
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play(&"play")
