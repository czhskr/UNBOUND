extends Node2D

## StageCombat 화면 맞춤. 전투 판정은 다루지 않는다.
## 평상시 카메라는 고정이고, 대사 포커스와 공격 흔들림만 움직인다.

const WORLD_SIZE := Vector2(384.0, 216.0)
const CAMERA_START := Vector2(192.0, 108.0)
## 전투 그림만 위로 옮긴다. ground_y와 공격 좌표는 그대로다. 시험값이다.
const COMBAT_WORLD_VISUAL_OFFSET_Y := -24.0
## 배경은 플랫폼보다 더 올린다. 스테이지별 오프셋에 더한다. 시험값이다.
const BACKGROUND_EXTRA_OFFSET_Y := -12.0
## 플랫폼만 아래로 내린다. 캐릭터와 배경은 그대로다. 시험값이며 +16, +20도 후보이다.
const PLATFORM_EXTRA_OFFSET_Y := 18.0
## visual이 없을 때의 발 위치. The Veil ground_y와 같다.
const FALLBACK_GROUND_Y := 155.0
const _STRIP_MIN_HEIGHT := 200
const _LAYER_REPEAT_TIMES := 3
const DEBUG_ATK_BANNER_SECONDS := 2.0
const DEBUG_ATK_ON_TEXT := "DEBUG: ATK 100 ON"
const DEBUG_ATK_OFF_TEXT := "DEBUG: ATK 100 OFF"
const _BANNER_FONT := preload("res://assets/fonts/Galmuri9.ttf")

## 예전 공통 배율. 캐릭터에는 더 이상 강제하지 않는다.
@export var stage_id: StringName = &"the_veil"
@export var character_scale: float = 1.333
## 전투 카메라 이동. 테스트 임시값이다.
@export var combat_camera_shift: float = 7.0
@export var combat_camera_move_duration: float = 0.08
@export var combat_camera_return_duration: float = 0.18

var active_definition: StageDefinition
var _ground_y: float = FALLBACK_GROUND_Y
var _combat_camera_x: float = 0.0
var _camera_tween: Tween
var _atk_banner: Label
var _atk_banner_timer: Timer

@onready var camera: Camera2D = $World/Camera2D
@onready var layout: Control = $UI/Layout


func _ready() -> void:
	active_definition = _resolve_definition()
	if active_definition != null:
		if active_definition.visual_definition == null:
			push_error("Stage '%s' has no visual definition." % active_definition.stage_id)
		else:
			apply_visual_definition(active_definition.visual_definition)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_fit_view):
		viewport.size_changed.connect(_fit_view)
	_fit_view()
	if camera != null:
		camera.position = CAMERA_START
	_apply_player_form()
	_apply_character_ground()
	DamagePopup.mount(self)
	VectorStackIndicator.mount(self)
	PauseMenu.mount(self)
	var world := get_node_or_null("World")
	if world != null and not world.child_entered_tree.is_connected(_on_world_child):
		world.child_entered_tree.connect(_on_world_child)
	var encounter := get_node_or_null("EncounterController") as EncounterController
	if encounter != null and active_definition != null:
		encounter.setup_stage(active_definition)
	_start_stage_bgm()


func _resolve_definition() -> StageDefinition:
	var session := GameSession.get_session()
	var resolved_id := session.current_stage_id
	if resolved_id == &"":
		resolved_id = stage_id
	if resolved_id == &"":
		resolved_id = &"the_veil"
	var definition := StageRegistry.get_stage(resolved_id)
	if definition == null and resolved_id != &"the_veil":
		push_error("Stage '%s' is missing. Falling back to the_veil." % resolved_id)
		definition = StageRegistry.get_stage(&"the_veil")
	if definition == null:
		return null
	stage_id = definition.stage_id
	session.current_stage_id = definition.stage_id
	return definition


func _start_stage_bgm() -> void:
	if active_definition == null or active_definition.bgm == null:
		return
	var player := get_node_or_null("StageBgm") as AudioStreamPlayer
	if player != null and player.playing and player.stream == active_definition.bgm:
		return
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "StageBgm"
		player.bus = GameSession.AUDIO_BUS_BGM
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
	var stream := active_definition.bgm
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	player.stream = stream
	player.play()


func apply_visual_definition(visual: StageVisualDefinition) -> void:
	if visual == null:
		push_error("Stage visual definition is null.")
		return
	visual.validate()
	var root := get_node_or_null("World/BackgroundRoot") as Node2D
	if root == null:
		push_error("Stage is missing World/BackgroundRoot.")
		return
	_clear_generated_layers(root)
	for layer in visual.background_layers:
		if layer == null:
			continue
		_add_background_layer(root, visual, layer)
	_apply_platform(visual)
	_ground_y = visual.ground_y


func _clear_generated_layers(root: Node2D) -> void:
	var children := root.get_children()
	for child in children:
		root.remove_child(child)
		child.free()


func _add_background_layer(root: Node2D, visual: StageVisualDefinition, layer: StageVisualLayer) -> void:
	var parallax := Parallax2D.new()
	var layer_name := String(layer.layer_id)
	if layer_name.is_empty():
		layer_name = "Layer"
	parallax.name = layer_name
	parallax.scroll_scale = Vector2(layer.scroll_ratio, 1.0)
	parallax.z_index = layer.z_index
	parallax.visible = layer.visible
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = layer.texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = visual.background_offset + layer.offset + Vector2(0.0, COMBAT_WORLD_VISUAL_OFFSET_Y + BACKGROUND_EXTRA_OFFSET_Y)
	if layer.texture != null and layer.texture.get_height() >= _STRIP_MIN_HEIGHT:
		_tile_strip(parallax, sprite, layer.texture)
	root.add_child(parallax)
	parallax.add_child(sprite)


func _tile_strip(parallax: Parallax2D, sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var tile_width := texture.get_width()
	var copies := 1
	if tile_width > 0:
		copies = int(ceil(WORLD_SIZE.x / float(tile_width)))
	var region_width := float(tile_width * copies)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0.0, 0.0, region_width, texture.get_height())
	parallax.repeat_size = Vector2(region_width, 0.0)
	parallax.repeat_times = _LAYER_REPEAT_TIMES


func _apply_platform(visual: StageVisualDefinition) -> void:
	var platform := get_node_or_null("World/Platform") as Sprite2D
	if platform == null:
		push_error("Stage is missing World/Platform.")
		return
	platform.texture = visual.platform_texture
	platform.position = visual.platform_position + Vector2(0.0, COMBAT_WORLD_VISUAL_OFFSET_Y + PLATFORM_EXTRA_OFFSET_Y)
	platform.z_index = visual.platform_z_index
	platform.centered = true
	platform.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _apply_player_form() -> void:
	var player := get_node_or_null("World/Player") as Player
	if player == null:
		return
	var form := GameSession.get_session().get_current_form()
	if form == null:
		return
	player.apply_form(form)
	_apply_form_combat_stats(player, form)
	var combat_stage_id := &""
	if active_definition != null:
		combat_stage_id = active_definition.stage_id
	player.notify_combat_started(combat_stage_id)


func _apply_form_combat_stats(player: Player, form: FormDefinition) -> void:
	var session := GameSession.get_session()
	var form_id := form.form_id
	player.max_hp = maxi(session.final_max_hp(form_id), 1)
	player.current_hp = player.max_hp
	player.attack_power = maxi(session.final_attack_power(form_id), 0)
	player.health_changed.emit(player.current_hp, player.max_hp)
	var rhythm := get_node_or_null("RhythmController") as RhythmController
	if rhythm == null:
		return
	rhythm.player_node_count = maxi(session.final_attack_count(form_id), 0)


func combat_visual_offset_y() -> float:
	return COMBAT_WORLD_VISUAL_OFFSET_Y


func apply_character_visual_scale(actor: Node) -> void:
	var body := actor as Node2D
	if body == null:
		return
	body.position.y = _ground_y
	var extra := Vector2.ZERO
	var anchor_extra := Vector2.ZERO
	var scale_multiplier := 1.0
	if body is Enemy:
		var enemy := body as Enemy
		scale_multiplier = enemy.visual_scale
		if enemy.definition != null:
			extra = enemy.definition.visual_offset
			anchor_extra = enemy.definition.effect_anchor_offset
	elif body is Player:
		var form := GameSession.get_session().get_current_form()
		if form != null:
			extra = form.visual_offset
	CharacterVisual.apply_actor(body, extra, anchor_extra, scale_multiplier, COMBAT_WORLD_VISUAL_OFFSET_Y)


func request_combat_dialogue(resource: DialogueResource, cue: String) -> void:
	var encounter := get_node_or_null("EncounterController") as EncounterController
	if encounter == null:
		push_error("StageCombat has no EncounterController.")
		return
	encounter.request_combat_dialogue(resource, cue)


func kick_combat_camera(direction: float) -> void:
	if camera == null:
		return
	var target := signf(direction) * combat_camera_shift
	if is_zero_approx(target) and is_zero_approx(_combat_camera_x):
		return
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_method(_set_combat_camera_x, _combat_camera_x, target, maxf(combat_camera_move_duration, 0.01))
	_camera_tween.tween_method(_set_combat_camera_x, target, 0.0, maxf(combat_camera_return_duration, 0.01))


func _set_combat_camera_x(value: float) -> void:
	_combat_camera_x = value
	_apply_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_Q:
		return
	if SceneFader.get_fader().transition_in_progress:
		return
	var encounter := get_node_or_null("EncounterController") as EncounterController
	if encounter == null or not encounter.is_combat_active():
		return
	var player := get_node_or_null("World/Player") as Player
	if player == null:
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	player.debug_attack_override_enabled = not player.debug_attack_override_enabled
	var text := DEBUG_ATK_ON_TEXT if player.debug_attack_override_enabled else DEBUG_ATK_OFF_TEXT
	_show_atk_banner(text)


func _show_atk_banner(text: String) -> void:
	_ensure_atk_banner()
	_atk_banner.text = text
	_atk_banner.visible = true
	_atk_banner_timer.start(DEBUG_ATK_BANNER_SECONDS)


func _ensure_atk_banner() -> void:
	if _atk_banner != null and _atk_banner_timer != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "DebugAtkBanner"
	layer.layer = 40
	add_child(layer)
	var label := Label.new()
	label.name = "Banner"
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_left = -180.0
	label.offset_right = 180.0
	label.offset_top = 8.0
	label.offset_bottom = 28.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", _BANNER_FONT)
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.visible = false
	layer.add_child(label)
	var timer := Timer.new()
	timer.name = "BannerTimer"
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(_hide_atk_banner)
	add_child(timer)
	_atk_banner = label
	_atk_banner_timer = timer


func _hide_atk_banner() -> void:
	if _atk_banner != null:
		_atk_banner.visible = false


func _apply_camera() -> void:
	if camera == null:
		return
	camera.position = Vector2(CAMERA_START.x + _combat_camera_x, CAMERA_START.y)


func _apply_character_ground() -> void:
	var spawn := get_node_or_null("World/EnemySpawnPoint") as Node2D
	if spawn != null:
		spawn.position.y = _ground_y
	apply_character_visual_scale(get_node_or_null("World/Player"))
	apply_character_visual_scale(get_node_or_null("World/Enemy"))


func _on_world_child(node: Node) -> void:
	if not node is Enemy:
		return
	apply_character_visual_scale(node)


func _fit_view() -> void:
	var viewport := get_viewport()
	if viewport == null or camera == null or layout == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var factor := minf(viewport_size.x / WORLD_SIZE.x, viewport_size.y / WORLD_SIZE.y)
	var zoom := Vector2(factor, factor)
	camera.zoom = zoom
	# 384x216 배치를 월드와 같은 배율로 두되, 이후 카메라 이동은 따라가지 않는다.
	layout.scale = zoom
	layout.position = viewport_size * 0.5 - CAMERA_START * factor
