class_name RhythmNode
extends Control

## 런타임에 주체를 바꿀 수 있게 시각을 씬 종류에 고정하지 않는다.
## Node.owner와 겹치지 않도록 필드 이름은 node_owner다.

enum NodeOwner { PLAYER, ENEMY }
enum NodeCategory { COMBAT, SPEED }
enum SpeedEffect { NONE, SLOW, FAST }

var node_owner: NodeOwner = NodeOwner.PLAYER
var node_category: NodeCategory = NodeCategory.COMBAT
var speed_effect: SpeedEffect = SpeedEffect.NONE
var scheduled_tick: int = 0
var scheduled_time: float = 0.0
var segment_index: int = 0
## 판정이 끝났는지만 나타낸다. 화면에서 지워졌는지는 따로 둔다.
var processed: bool = false
## 보스 잠금. owner는 바꾸지 않는다.
var is_locked: bool = false
## 노드 중심의 이동. steal 이후에는 travel_locked로 고정한다.
var travel_from_x: float = 0.0
var travel_to_x: float = 0.0
var travel_from_time: float = 0.0
var travel_to_time: float = 0.0
var travel_locked: bool = false
## 판정이 끝난 시각 잔상. 입력/잠금/탈취 대상이 아니다.
var is_visual_only: bool = false
var is_stealing: bool = false
## 재실행으로 다시 들어온 플레이어 노드. 같은 노드를 또 재실행하지 않는다.
var override_retried: bool = false
## OVERLOAD가 덧붙인 노드. LOCK, STEAL, SLOW, FAST 대상이 아니다.
var from_overload: bool = false
var steal_time_left: float = 0.0
var debris_velocity: Vector2 = Vector2.ZERO
var debris_time: float = 0.0

var _tag: Label
var _base: TextureRect
var _lock: TextureRect
var _caption: String = ""

## 64px 노드 그림을 판정 박스 안에 두는 공통 배율. 시험값이다.
const VISUAL_SCALE := 0.5
const STEAL_FPS := 18.0
const _PLAYER_TEXTURE := preload("res://assets/ui/player_node.png")
const _ENEMY_TEXTURE := preload("res://assets/ui/enemy_node.png")
const _LOCK_TEXTURE := preload("res://assets/ui/lock_overlay.png")
const _STEAL_TEXTURES: Array[Texture2D] = [
	preload("res://assets/effects/steal/steal_001.png"),
	preload("res://assets/effects/steal/steal_002.png"),
	preload("res://assets/effects/steal/steal_003.png"),
	preload("res://assets/effects/steal/steal_004.png"),
	preload("res://assets/effects/steal/steal_005.png"),
	preload("res://assets/effects/steal/steal_006.png"),
]

static var _steal_frames: SpriteFrames


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(36, 36)
	size = Vector2(36, 36)
	_base = TextureRect.new()
	_base.name = "BaseSprite"
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base)
	_lock = TextureRect.new()
	_lock.name = "LockOverlay"
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.z_index = 1
	_lock.visible = false
	add_child(_lock)
	_tag = Label.new()
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.position = Vector2.ZERO
	_tag.size = size
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag.add_theme_font_size_override(&"font_size", 14)
	_tag.add_theme_color_override(&"font_color", Color(0.05, 0.05, 0.08))
	add_child(_tag)
	_place_texture(_base, _PLAYER_TEXTURE)
	_place_texture(_lock, _LOCK_TEXTURE)
	_apply_visual()


func set_node_owner(next_owner: NodeOwner) -> void:
	node_owner = next_owner
	_apply_visual()


func set_locked(locked: bool) -> void:
	is_locked = locked
	_apply_visual()


static func visual_half_width() -> float:
	return maxf(_PLAYER_TEXTURE.get_size().x, _ENEMY_TEXTURE.get_size().x) * VISUAL_SCALE * 0.5


func set_speed_effect(effect: SpeedEffect, caption: String) -> void:
	node_category = NodeCategory.SPEED
	speed_effect = effect
	_caption = caption
	_apply_visual()


func play_steal_effect() -> void:
	var host := get_parent()
	if host == null:
		return
	var effect := AnimatedSprite2D.new()
	effect.name = "StealEffect"
	effect.centered = true
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	effect.sprite_frames = _steal_sprite_frames()
	effect.position = position + size * 0.5
	effect.z_index = 40
	effect.set_meta(&"follow_id", get_instance_id())
	host.add_child(effect)
	effect.play(&"default")
	effect.animation_finished.connect(effect.queue_free)


func _apply_visual() -> void:
	if _tag == null:
		return
	var speed_node := node_category == NodeCategory.SPEED
	if _base != null:
		_base.visible = not speed_node
		if not speed_node:
			_place_texture(_base, _ENEMY_TEXTURE if node_owner == NodeOwner.ENEMY else _PLAYER_TEXTURE)
	if _lock != null:
		_lock.visible = not speed_node and is_locked and node_owner == NodeOwner.PLAYER
	_tag.visible = speed_node
	if speed_node:
		_tag.text = _caption
		_tag.add_theme_font_size_override(&"font_size", 8)
	queue_redraw()


func _place_texture(rect: TextureRect, texture: Texture2D) -> void:
	if rect == null or texture == null:
		return
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var shown := texture.get_size() * VISUAL_SCALE
	rect.size = shown
	rect.position = size * 0.5 - shown * 0.5


func _draw() -> void:
	if node_category != NodeCategory.SPEED:
		return
	var fill := Color(0.45, 0.9, 0.82) if speed_effect == SpeedEffect.SLOW else Color(1.0, 0.48, 0.72)
	draw_rect(Rect2(3, 6, size.x - 6, size.y - 12), fill)
	draw_rect(Rect2(2, 5, size.x - 4, size.y - 10), Color(0.08, 0.08, 0.1), false, 2.0)


static func _steal_sprite_frames() -> SpriteFrames:
	if _steal_frames != null:
		return _steal_frames
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	frames.add_animation(&"default")
	frames.set_animation_speed(&"default", STEAL_FPS)
	frames.set_animation_loop(&"default", false)
	for texture in _STEAL_TEXTURES:
		frames.add_frame(&"default", texture)
	_steal_frames = frames
	return frames
