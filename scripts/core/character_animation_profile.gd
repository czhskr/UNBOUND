class_name CharacterAnimationProfile
extends Resource

## 프레임 범위, FPS, 반복만 담는다. 전투 상태와 피해는 CombatActor가 담당한다.

@export_group("Frames")
@export var frame_root: String = ""

@export_group("Idle")
@export var idle_start_frame: int = 0
@export var idle_end_frame: int = 0
@export var idle_fps: float = 0.0
@export var idle_loop: bool = false

@export_group("Attack")
@export var attack_start_frame: int = 0
@export var attack_end_frame: int = 0
@export var attack_fps: float = 0.0
@export var attack_loop: bool = false
## 비어 있지 않으면 start/end 대신 이 목록만 재생한다. Leon 공격처럼 빠진 프레임용이다.
@export var attack_frames: PackedInt32Array = PackedInt32Array()

@export_group("Hit")
@export var hit_start_frame: int = 0
@export var hit_end_frame: int = 0
@export var hit_fps: float = 0.0
@export var hit_loop: bool = false

@export_group("Death")
@export var death_start_frame: int = 0
@export var death_end_frame: int = 0
@export var death_fps: float = 0.0
@export var death_loop: bool = false

@export_group("Run")
@export var run_start_frame: int = 0
@export var run_end_frame: int = 0
@export var run_fps: float = 0.0
@export var run_loop: bool = false
## SpriteTest에 run이 없을 때 idle 프레임을 run으로 다시 쓴다.
@export var reuse_idle_for_run: bool = false

@export_group("Cast")
@export var cast_start_frame: int = 0
@export var cast_end_frame: int = -1
@export var cast_fps: float = 0.0
@export var cast_loop: bool = false


func build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	if frame_root.strip_edges().is_empty():
		push_error("%s frame_root is empty." % _profile_name())
		return frames
	_add_animation(frames, &"idle", idle_start_frame, idle_end_frame, idle_fps, idle_loop)
	if attack_frames.is_empty():
		_add_animation(frames, &"attack", attack_start_frame, attack_end_frame, attack_fps, attack_loop)
	else:
		_add_frame_list(frames, &"attack", attack_frames, attack_fps, attack_loop)
	_add_animation(frames, &"hit", hit_start_frame, hit_end_frame, hit_fps, hit_loop)
	_add_animation(frames, &"death", death_start_frame, death_end_frame, death_fps, death_loop)
	if reuse_idle_for_run:
		_copy_animation(frames, &"idle", &"run", idle_fps, idle_loop)
	else:
		_add_animation(frames, &"run", run_start_frame, run_end_frame, run_fps, run_loop)
	if cast_fps > 0.0 and cast_end_frame >= cast_start_frame:
		_add_animation(frames, &"cast", cast_start_frame, cast_end_frame, cast_fps, cast_loop)
	return frames


func _add_animation(
	frames: SpriteFrames,
	anim_name: StringName,
	start_frame: int,
	end_frame: int,
	fps: float,
	loop_animation: bool
) -> void:
	if start_frame < 0 or end_frame < 0 or start_frame > end_frame:
		push_error(
			"%s %s has invalid frame range %d..%d."
			% [_profile_name(), anim_name, start_frame, end_frame]
		)
		return
	if fps <= 0.0:
		push_error("%s %s fps must be > 0. Current value: %s." % [_profile_name(), anim_name, fps])
		return

	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop_animation)
	var root := frame_root.strip_edges().trim_suffix("/")
	for frame_index in range(start_frame, end_frame + 1):
		var path := "%s/%s/%s_%03d.png" % [root, anim_name, anim_name, frame_index]
		if not ResourceLoader.exists(path):
			push_error("%s %s is missing frame file %s." % [_profile_name(), anim_name, path])
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("%s %s failed to load %s." % [_profile_name(), anim_name, path])
			continue
		frames.add_frame(anim_name, texture)


func _add_frame_list(
	frames: SpriteFrames,
	anim_name: StringName,
	frame_list: PackedInt32Array,
	fps: float,
	loop_animation: bool
) -> void:
	if frame_list.is_empty():
		return
	if fps <= 0.0:
		push_error("%s %s fps must be > 0. Current value: %s." % [_profile_name(), anim_name, fps])
		return
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop_animation)
	var root := frame_root.strip_edges().trim_suffix("/")
	for frame_index in frame_list:
		var path := "%s/%s/%s_%03d.png" % [root, anim_name, anim_name, frame_index]
		if not ResourceLoader.exists(path):
			push_error("%s %s is missing frame file %s." % [_profile_name(), anim_name, path])
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("%s %s failed to load %s." % [_profile_name(), anim_name, path])
			continue
		frames.add_frame(anim_name, texture)


func _copy_animation(
	frames: SpriteFrames,
	source_name: StringName,
	target_name: StringName,
	fps: float,
	loop_animation: bool
) -> void:
	if not frames.has_animation(source_name) or frames.get_frame_count(source_name) <= 0:
		push_error("%s cannot reuse %s for %s." % [_profile_name(), source_name, target_name])
		return
	frames.add_animation(target_name)
	frames.set_animation_speed(target_name, fps)
	frames.set_animation_loop(target_name, loop_animation)
	var count := frames.get_frame_count(source_name)
	for frame_index in count:
		frames.add_frame(target_name, frames.get_frame_texture(source_name, frame_index))


func _profile_name() -> String:
	if resource_path.is_empty():
		return "CharacterAnimationProfile"
	return resource_path
