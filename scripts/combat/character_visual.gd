class_name CharacterVisual
extends RefCounted

## 전투와 Entry가 같이 쓰는 시각 기준.
## 1.20과 (0, -48)은 화면을 위로 올린 뒤의 시험값이다. 최종 확정이 아니다.
## 공통 Y를 -40으로 내리면 플레이어가 플랫폼에 파고든다.

static var common_scale: float = 1.20
static var common_sprite_offset: Vector2 = Vector2(0, -48)
## 스프라이트 중심에서 몸 중심으로 내리는 양.
## 24는 발이 맞춰진 뒤 100px 캐릭터의 정강이에 붙었다.
## 16은 그 캐릭터의 몸통 쪽에 두는 작업값이며 최종이 아니다.
static var body_center_drop: float = 16.0


static func apply_actor(
	actor: Node2D,
	sprite_extra: Vector2 = Vector2.ZERO,
	anchor_extra: Vector2 = Vector2.ZERO,
	scale_multiplier: float = 1.0,
	visual_lift: float = 0.0
) -> void:
	if actor == null:
		return
	actor.scale = Vector2.ONE
	var scale_value := common_scale * scale_multiplier
	var visual := actor.get_node_or_null("MotionRoot/VisualRoot") as Node2D
	if visual == null:
		visual = actor.get_node_or_null("VisualRoot") as Node2D
	if visual != null:
		visual.scale = Vector2(scale_value, scale_value)
		visual.position = Vector2(0.0, visual_lift)
	var sprite := _sprite(actor)
	if sprite != null:
		sprite.position = common_sprite_offset + sprite_extra
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var anchor := actor.get_node_or_null("MotionRoot/EffectAnchor") as Node2D
	if anchor != null:
		var sprite_offset := common_sprite_offset + sprite_extra
		var center := sprite_offset * scale_value
		anchor.position = center + Vector2(0.0, body_center_drop) * scale_value + anchor_extra + Vector2(0.0, visual_lift)
	var dialogue := actor.get_node_or_null("MotionRoot/DialogueAnchor") as Node2D
	if dialogue != null:
		dialogue.position = Vector2(0.0, -80.0 + visual_lift)


static func _sprite(actor: Node) -> AnimatedSprite2D:
	var sprite := actor.get_node_or_null("MotionRoot/VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = actor.get_node_or_null("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	return sprite
