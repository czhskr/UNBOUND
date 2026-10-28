extends CanvasLayer

## 조우 시작 소개. 전투 중 반복 상태가 아니다.
## 진입, 유지, 퇴장 길이는 시험값이며 최종이 아니다.

signal intro_finished

const EFFECT_FPS := 23.0
const ENTER_DURATION := 0.55
const HOLD_DURATION := 0.65
const EXIT_DURATION := 0.4
const EFFECT_SCALE := Vector2(4.0, 2.15)
const VISUAL_SCALE := 6.5
const NAME_POSITION := Vector2(-250.0, -18.0)
const DESCRIPTION_POSITION := Vector2(-250.0, 70.0)
const DESCRIPTION_SIZE := Vector2(280.0, 36.0)
const VISUAL_POSITION := Vector2(220.0, -100.0)
const OFFSCREEN_MARGIN := 8.0

const _EFFECT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/effects/hyper/hyper_001.png"),
	preload("res://assets/effects/hyper/hyper_002.png"),
	preload("res://assets/effects/hyper/hyper_003.png"),
	preload("res://assets/effects/hyper/hyper_004.png"),
]
const _FONT := preload("res://assets/fonts/Galmuri9.ttf")

var _token: int = 0
var _effect: AnimatedSprite2D
var _content: Node2D
var _name_label: Label
var _description_label: Label
var _visual: AnimatedSprite2D
var _tween: Tween


func _ready() -> void:
	layer = 40
	visible = false
	_effect = get_node_or_null("HyperEffect") as AnimatedSprite2D
	_content = get_node_or_null("MovingContent") as Node2D
	_name_label = get_node_or_null("MovingContent/EnemyNameLabel") as Label
	_description_label = get_node_or_null("MovingContent/EnemyDescriptionLabel") as Label
	_visual = get_node_or_null("MovingContent/EnemyVisual") as AnimatedSprite2D
	if _effect == null or _content == null or _name_label == null or _description_label == null or _visual == null:
		push_error("HyperEncounterIntro is missing effect, name, description, or visual.")
		return
	_effect.sprite_frames = _build_effect_frames()
	_effect.centered = true
	_effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_effect.scale = EFFECT_SCALE
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_override(&"font", _FONT)
	_name_label.add_theme_font_size_override(&"font_size", 72)
	_name_label.add_theme_color_override(&"font_color", Color(0.05, 0.06, 0.09, 1.0))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.position = NAME_POSITION
	_name_label.size = Vector2(280.0, 84.0)
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.add_theme_font_override(&"font", _FONT)
	_description_label.add_theme_font_size_override(&"font_size", 28)
	_description_label.add_theme_color_override(&"font_color", Color(0.2, 0.22, 0.26, 0.78))
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description_label.position = DESCRIPTION_POSITION
	_description_label.size = DESCRIPTION_SIZE
	_visual.centered = true
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual.flip_h = true
	_visual.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	_visual.position = VISUAL_POSITION


func play(definition: EnemyDefinition) -> void:
	_token += 1
	var token := _token
	if definition == null or _effect == null or _content == null:
		intro_finished.emit()
		return
	_show_enemy(definition)
	var center := _viewport_center()
	_effect.position = center
	_effect.scale = EFFECT_SCALE
	var span := _content_span()
	var width := _viewport_size().x
	var start := Vector2(width - span.x + OFFSCREEN_MARGIN, center.y)
	var hold := Vector2(center.x, center.y)
	var exit_pos := Vector2(-span.y - OFFSCREEN_MARGIN, center.y)
	_content.position = start
	visible = true
	_effect.play(&"default")
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var enter := _tween.tween_property(_content, "position", hold, ENTER_DURATION)
	enter.set_trans(Tween.TRANS_CUBIC)
	enter.set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD_DURATION)
	var leave := _tween.tween_property(_content, "position", exit_pos, EXIT_DURATION)
	leave.set_trans(Tween.TRANS_CUBIC)
	leave.set_ease(Tween.EASE_IN)
	while _tween != null and _tween.is_valid() and _tween.is_running() and token == _token and is_inside_tree():
		await get_tree().process_frame
	if token != _token or not is_inside_tree():
		return
	_hide()
	intro_finished.emit()


func cancel() -> void:
	_token += 1
	_hide()
	intro_finished.emit()


func visual_position_for(definition: EnemyDefinition) -> Vector2:
	var padding := 0.0
	if definition != null:
		padding = definition.visual_offset.y
	return Vector2(VISUAL_POSITION.x, VISUAL_POSITION.y + padding * VISUAL_SCALE)


func feet_local_y(definition: EnemyDefinition) -> float:
	var placed := visual_position_for(definition)
	return placed.y + _opaque_feet_from_center(definition) * VISUAL_SCALE


func _show_enemy(definition: EnemyDefinition) -> void:
	_name_label.text = definition.display_name
	_description_label.text = definition.hyper_description
	var frames: SpriteFrames = null
	if definition.animation_profile != null:
		frames = definition.animation_profile.build_sprite_frames()
	_visual.sprite_frames = frames
	_visual.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	_visual.position = visual_position_for(definition)
	if frames != null and frames.has_animation(&"idle"):
		_visual.play(&"idle")
	elif frames != null and frames.get_animation_names().size() > 0:
		_visual.animation = frames.get_animation_names()[0]
		_visual.frame = 0
		_visual.stop()


func _content_span() -> Vector2:
	var min_x := minf(_name_label.position.x, _description_label.position.x)
	var max_x := maxf(_name_label.position.x + _name_label.size.x, _description_label.position.x + _description_label.size.x)
	var texture_size := _visual_texture_size()
	var half_width := texture_size.x * _visual.scale.x * 0.5
	min_x = minf(min_x, _visual.position.x - half_width)
	max_x = maxf(max_x, _visual.position.x + half_width)
	return Vector2(min_x, max_x)


func _visual_texture_size() -> Vector2:
	if _visual.sprite_frames != null and _visual.sprite_frames.has_animation(_visual.animation):
		var texture := _visual.sprite_frames.get_frame_texture(_visual.animation, _visual.frame)
		if texture != null:
			return texture.get_size()
	return Vector2(100.0, 100.0)


func _opaque_feet_from_center(definition: EnemyDefinition) -> float:
	if definition == null or definition.animation_profile == null:
		return 0.0
	var frames := definition.animation_profile.build_sprite_frames()
	if frames == null or not frames.has_animation(&"idle") or frames.get_frame_count(&"idle") <= 0:
		return 0.0
	var texture := frames.get_frame_texture(&"idle", 0)
	if texture == null:
		return 0.0
	var image := texture.get_image()
	if image == null or image.is_empty():
		return 0.0
	var height := image.get_height()
	var width := image.get_width()
	var bottom := height - 1
	for y in range(height - 1, -1, -1):
		var found := false
		for x in width:
			if image.get_pixel(x, y).a > 0.05:
				found = true
				break
		if found:
			bottom = y
			break
	return float(bottom) + 0.5 - float(height) * 0.5


func _viewport_center() -> Vector2:
	return _viewport_size() * 0.5


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(1152.0, 648.0)
	return viewport.get_visible_rect().size


func _hide() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	visible = false
	if _effect != null:
		_effect.stop()
	if _visual != null:
		_visual.stop()


func _build_effect_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if not frames.has_animation(&"default"):
		frames.add_animation(&"default")
	frames.set_animation_speed(&"default", EFFECT_FPS)
	frames.set_animation_loop(&"default", true)
	for texture in _EFFECT_TEXTURES:
		frames.add_frame(&"default", texture, 1.0)
	return frames
