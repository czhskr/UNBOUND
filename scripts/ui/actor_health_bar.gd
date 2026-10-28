class_name ActorHealthBar
extends Control

## 플레이어와 적이 같이 쓰는 머리 위 체력바.
## 위치, 색, 지연, 흔들림은 시험값이며 최종이 아니다.

const ACTOR_HEALTH_BAR_Y := 410.0
## 게이지, 제목, 여백은 시험값이며 최종 크기가 아니다.
const BAR_WIDTH := 192.0
const BAR_HEIGHT := 14.0
const TITLE_HEIGHT := 16.0
const TITLE_BAR_GAP := 2.0
const PANEL_PADDING_X := 8.0
const PANEL_PADDING_Y := 6.0
const FRAME_BORDER := 2.0
const TITLE_FONT_SIZE := 12
const PERCENT_FONT_SIZE := 10
const AFTERIMAGE_DELAY := 0.20
const AFTERIMAGE_FOLLOW := 0.30
const LOW_HP_RATIO := 0.25
const SHAKE_AMPLITUDE := 3.0
const SHAKE_DURATION := 0.14
const FLASH_SECONDS := 0.12
const PULSE_SECONDS := 0.45

const COLOR_HIGH := Color(0.36, 0.75, 0.42, 1.0)
const COLOR_MID := Color(0.93, 0.70, 0.20, 1.0)
const COLOR_LOW := Color(0.82, 0.18, 0.18, 1.0)
const COLOR_AFTERIMAGE := Color(0.95, 0.90, 0.82, 1.0)
const COLOR_PANEL := Color(0.75, 0.75, 0.73, 1.0)
const COLOR_HIGHLIGHT := Color(0.95, 0.95, 0.93, 1.0)
const COLOR_SHADOW := Color(0.28, 0.28, 0.30, 1.0)
const COLOR_WELL := Color(0.55, 0.55, 0.52, 1.0)
const COLOR_TITLE := Color(0.08, 0.08, 0.10, 1.0)
const _FONT := preload("res://assets/fonts/Galmuri9.ttf")

@export var follow_player: bool = false
@export var follow_enemy: bool = false

var current_ratio: float = 1.0
var afterimage_ratio: float = 1.0
var shake_offset: float = 0.0

var _actor: CombatActor
var _shown_hp: int = -1
var _shown_max: int = 1
var _after_tween: Tween
var _flash_tween: Tween
var _shake_tween: Tween
var _pulse_tween: Tween
var _panel: Panel
var _title: Label
var _frame: Panel
var _afterimage: ProgressBar
var _current: ProgressBar
var _percent: Label
var _flash: ColorRect
var _current_fill: StyleBoxFlat
var _fill_color: Color = COLOR_HIGH


func panel_size() -> Vector2:
	var frame := frame_size()
	return Vector2(
		PANEL_PADDING_X + frame.x + PANEL_PADDING_X,
		PANEL_PADDING_Y + TITLE_HEIGHT + TITLE_BAR_GAP + frame.y + PANEL_PADDING_Y
	)


func frame_size() -> Vector2:
	return Vector2(BAR_WIDTH + FRAME_BORDER * 2.0, BAR_HEIGHT + FRAME_BORDER * 2.0)


func gauge_size() -> Vector2:
	return Vector2(BAR_WIDTH, BAR_HEIGHT)


func content_inside_frame() -> bool:
	if _frame == null or _afterimage == null or _current == null or _percent == null or _flash == null:
		return false
	var outer := _frame.get_global_rect()
	return _rect_contains(outer, _afterimage.get_global_rect()) and _rect_contains(outer, _current.get_global_rect()) and _rect_contains(outer, _percent.get_global_rect()) and _rect_contains(outer, _flash.get_global_rect())


func progress_inside_panel() -> bool:
	if _panel == null or _title == null:
		return false
	return _title.text == "Progress" and _rect_contains(_panel.get_global_rect(), _title.get_global_rect())


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = get_node_or_null("PanelBackground") as Panel
	_title = get_node_or_null("PanelBackground/ProgressLabel") as Label
	_frame = get_node_or_null("PanelBackground/BarFrame") as Panel
	_afterimage = get_node_or_null("PanelBackground/BarFrame/AfterimageBar") as ProgressBar
	_current = get_node_or_null("PanelBackground/BarFrame/CurrentBar") as ProgressBar
	_percent = get_node_or_null("PanelBackground/BarFrame/PercentLabel") as Label
	_flash = get_node_or_null("PanelBackground/BarFrame/HitFlash") as ColorRect
	if _panel == null or _title == null or _frame == null or _afterimage == null or _current == null or _percent == null or _flash == null:
		push_error("ActorHealthBar is missing panel, title, frame, afterimage, current, percent, or flash.")
		return
	_style_panel()
	_style_bar(_afterimage, COLOR_AFTERIMAGE)
	_current_fill = _style_bar(_current, COLOR_HIGH)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.text = "Progress"
	_title.add_theme_font_override(&"font", _FONT)
	_title.add_theme_font_size_override(&"font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override(&"font_color", COLOR_TITLE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_percent.add_theme_font_override(&"font", _FONT)
	_percent.add_theme_font_size_override(&"font_size", PERCENT_FONT_SIZE)
	_percent.add_theme_color_override(&"font_color", Color(0.1, 0.11, 0.13, 1.0))
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 1)
	_flash.modulate.a = 0.0
	_layout()
	_refresh_bars()
	call_deferred("_bind_initial")


func _process(_delta: float) -> void:
	if follow_enemy:
		var encounter := _encounter()
		var enemy: CombatActor = null
		if encounter != null and encounter.current_enemy != null and is_instance_valid(encounter.current_enemy):
			enemy = encounter.current_enemy
		if enemy != _actor:
			bind_actor(enemy)
	if _actor == null or not is_instance_valid(_actor):
		visible = false
		return
	visible = true
	var screen_x := _actor_screen_x()
	position = Vector2(screen_x - panel_size().x * 0.5 + shake_offset, ACTOR_HEALTH_BAR_Y)
	_refresh_bars()


func bind_actor(next: CombatActor) -> void:
	if _actor == next:
		return
	if _actor != null and is_instance_valid(_actor) and _actor.health_changed.is_connected(_on_health_changed):
		_actor.health_changed.disconnect(_on_health_changed)
	_actor = next
	if next == null:
		visible = false
		return
	if not next.health_changed.is_connected(_on_health_changed):
		next.health_changed.connect(_on_health_changed)
	_snap(next.current_hp, next.max_hp)


func flash_alpha() -> float:
	if _flash == null:
		return 0.0
	return _flash.modulate.a


func is_pulsing() -> bool:
	return _pulse_tween != null and _pulse_tween.is_valid() and _pulse_tween.is_running()


func shown_max_hp() -> int:
	return _shown_max


func bar_color() -> Color:
	return _fill_color


func percent_text() -> String:
	if _percent == null:
		return ""
	return _percent.text


func _bind_initial() -> void:
	if follow_player:
		bind_actor(_find_player())


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	var safe_max := maxi(max_hp, 1)
	if _shown_hp < 0 or current_hp >= _shown_hp:
		_snap(current_hp, safe_max)
		return
	_shown_hp = current_hp
	_shown_max = safe_max
	current_ratio = clampf(float(current_hp) / float(safe_max), 0.0, 1.0)
	_refresh_bars()
	_play_flash()
	_play_shake()
	_restart_afterimage(current_ratio)
	_update_pulse()


func _snap(current_hp: int, max_hp: int) -> void:
	_shown_hp = current_hp
	_shown_max = maxi(max_hp, 1)
	current_ratio = clampf(float(current_hp) / float(_shown_max), 0.0, 1.0)
	afterimage_ratio = current_ratio
	shake_offset = 0.0
	_kill_tween(_after_tween)
	_after_tween = null
	_kill_tween(_flash_tween)
	_flash_tween = null
	_kill_tween(_shake_tween)
	_shake_tween = null
	if _flash != null:
		_flash.modulate.a = 0.0
	_refresh_bars()
	_update_pulse()


func _restart_afterimage(target: float) -> void:
	_kill_tween(_after_tween)
	_after_tween = create_tween()
	_after_tween.tween_interval(AFTERIMAGE_DELAY)
	_after_tween.tween_property(self, "afterimage_ratio", target, AFTERIMAGE_FOLLOW)


func _play_flash() -> void:
	if _flash == null:
		return
	_kill_tween(_flash_tween)
	_flash.modulate.a = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, FLASH_SECONDS)


func _play_shake() -> void:
	_kill_tween(_shake_tween)
	shake_offset = 0.0
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "shake_offset", SHAKE_AMPLITUDE, SHAKE_DURATION * 0.25)
	_shake_tween.tween_property(self, "shake_offset", -SHAKE_AMPLITUDE, SHAKE_DURATION * 0.25)
	_shake_tween.tween_property(self, "shake_offset", SHAKE_AMPLITUDE * 0.35, SHAKE_DURATION * 0.25)
	_shake_tween.tween_property(self, "shake_offset", 0.0, SHAKE_DURATION * 0.25)


func _update_pulse() -> void:
	var low := current_ratio > 0.0 and current_ratio <= LOW_HP_RATIO
	if low:
		if _pulse_tween != null and _pulse_tween.is_valid() and _pulse_tween.is_running():
			return
		_pulse_tween = create_tween()
		_pulse_tween.set_loops()
		_pulse_tween.tween_property(self, "modulate:a", 0.72, PULSE_SECONDS)
		_pulse_tween.tween_property(self, "modulate:a", 1.0, PULSE_SECONDS)
		return
	_kill_tween(_pulse_tween)
	_pulse_tween = null
	modulate.a = 1.0


func _style_panel() -> void:
	var panel_style := _bevel_style(COLOR_PANEL, COLOR_HIGHLIGHT, COLOR_SHADOW)
	_panel.add_theme_stylebox_override(&"panel", panel_style)
	var frame_style := _bevel_style(COLOR_WELL, COLOR_SHADOW, COLOR_HIGHLIGHT)
	_frame.add_theme_stylebox_override(&"panel", frame_style)
	_frame.clip_contents = true
	_panel.clip_contents = true


func _bevel_style(fill: Color, top_left: Color, bottom_right: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(0)
	style.set_content_margin_all(0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.border_color = top_left
	style.shadow_color = bottom_right
	style.shadow_size = 2
	style.shadow_offset = Vector2(1, 1)
	return style


func _style_bar(bar: ProgressBar, fill_color: Color) -> StyleBoxFlat:
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.clip_contents = true
	var background := StyleBoxFlat.new()
	background.bg_color = COLOR_WELL
	background.set_border_width_all(0)
	background.set_corner_radius_all(0)
	background.set_content_margin_all(0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(0)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override(&"background", background)
	bar.add_theme_stylebox_override(&"fill", fill)
	return fill


func _layout() -> void:
	var panel := panel_size()
	var frame := frame_size()
	var gauge := gauge_size()
	custom_minimum_size = panel
	size = panel
	_panel.position = Vector2.ZERO
	_panel.size = panel
	_title.position = Vector2(PANEL_PADDING_X, PANEL_PADDING_Y)
	_title.size = Vector2(frame.x, TITLE_HEIGHT)
	_frame.position = Vector2(PANEL_PADDING_X, PANEL_PADDING_Y + TITLE_HEIGHT + TITLE_BAR_GAP)
	_frame.size = frame
	var gauge_origin := Vector2(FRAME_BORDER, FRAME_BORDER)
	_afterimage.position = gauge_origin
	_current.position = gauge_origin
	_percent.position = gauge_origin
	_flash.position = gauge_origin
	_afterimage.size = gauge
	_current.size = gauge
	_percent.size = gauge
	_flash.size = gauge
	_afterimage.z_index = 0
	_current.z_index = 1
	_percent.z_index = 2
	_flash.z_index = 3


func _refresh_bars() -> void:
	if _afterimage == null or _current == null or _flash == null or _percent == null:
		return
	_layout()
	var after_value := clampf(afterimage_ratio, 0.0, 1.0) * 100.0
	var current_value := clampf(current_ratio, 0.0, 1.0) * 100.0
	_afterimage.value = after_value
	_current.value = current_value
	_fill_color = _gradient(current_ratio)
	if _current_fill != null:
		_current_fill.bg_color = _fill_color
	_percent.text = "%d%%" % roundi(current_ratio * 100.0)


func _rect_contains(outer: Rect2, inner: Rect2) -> bool:
	return outer.position.x <= inner.position.x + 0.5 and outer.position.y <= inner.position.y + 0.5 and outer.end.x + 0.5 >= inner.end.x and outer.end.y + 0.5 >= inner.end.y


func _gradient(ratio: float) -> Color:
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped >= 0.5:
		return COLOR_MID.lerp(COLOR_HIGH, (clamped - 0.5) / 0.5)
	return COLOR_LOW.lerp(COLOR_MID, clamped / 0.5)


func _actor_screen_x() -> float:
	var node: Node2D = _actor
	var motion := _actor.get_node_or_null("MotionRoot") as Node2D
	if motion != null:
		node = motion
	return node.get_global_transform_with_canvas().origin.x


func _find_player() -> CombatActor:
	var root := _scene_root()
	if root == null:
		return null
	var player := root.get_node_or_null("World/Player") as CombatActor
	if player == null:
		player = root.get_node_or_null("Stage/Player") as CombatActor
	return player


func _encounter() -> EncounterController:
	var root := _scene_root()
	if root == null:
		return null
	return root.get_node_or_null("EncounterController") as EncounterController


func _scene_root() -> Node:
	var layer := get_parent()
	if layer == null:
		return null
	return layer.get_parent()


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
