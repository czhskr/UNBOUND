class_name FormVisual
extends RefCounted

## SpriteFrames와 애니메이션만 교체한다.
## 발 위치와 배율은 CharacterVisual이 공통 기준에 오버라이드별 보정을 더해 적용한다.


static func apply_to_sprite(sprite: AnimatedSprite2D, form: FormDefinition) -> void:
	if sprite == null or form == null:
		push_error("Form visual apply is missing a sprite or a form.")
		return
	var frames := form.sprite_frames
	if frames == null and form.animation_profile != null:
		frames = form.animation_profile.build_sprite_frames()
	if frames == null:
		push_error("Form '%s' has no sprite frames." % form.form_id)
		return
	var anim := sprite.animation
	sprite.sprite_frames = frames
	## 플레이어 쪽은 오른쪽을 본다. 적은 Enemy 씬의 flip_h를 유지한다.
	sprite.flip_h = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if anim == &"" or not frames.has_animation(anim):
		anim = &"idle"
	if frames.has_animation(anim):
		sprite.play(anim)


static func opaque_feet_from_center(form: FormDefinition) -> float:
	if form == null:
		return 0.0
	var frames := form.sprite_frames
	if frames == null and form.animation_profile != null:
		frames = form.animation_profile.build_sprite_frames()
	if frames == null or not frames.has_animation(&"idle") or frames.get_frame_count(&"idle") <= 0:
		return 0.0
	return opaque_feet_of_texture(frames.get_frame_texture(&"idle", 0))


static func opaque_feet_of_texture(texture: Texture2D) -> float:
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
