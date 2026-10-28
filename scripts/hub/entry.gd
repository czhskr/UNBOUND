extends Node2D

## Entry TV. 오버라이드와 스테이지는 화면 안 버튼으로만 고른다.

const WORLD_SIZE := Vector2(384.0, 216.0)
const CAMERA_START := Vector2(192.0, 108.0)
## entry.png 원본 크기. 1152x648에서는 4.5배로 빈틈 없이 맞는다.
const ART_SIZE := Vector2(256.0, 144.0)
## CRT 유리 안쪽. 곡면 밖을 피한 임시 사각형이며 최종 좌표가 아니다.
const TV_SAFE := Rect2(68.0, 36.0, 112.0, 64.0)
const TV_MARGIN := 12
## 모든 오버라이드가 같이 쓰는 프리뷰 배율. 최종값이 아니다.
const FORM_PREVIEW_SCALE := 3.0
## 모든 오버라이드가 같이 쓰는 세로 보정. 최종값이 아니다.
const FORM_PREVIEW_OFFSET_Y := -50.0
## 프리뷰 영역과 오버라이드 선택 줄 사이의 빈 간격. 최종값이 아니다.
const FORM_PREVIEW_GAP := 16.0
const FORM_SELECTOR_MIN_HEIGHT := 28.0
## 특성 설명 패널 너비. 시험값이다.
const TRAIT_PANEL_WIDTH := 240.0
const EMPTY_TRAIT_TITLE := "특성 없음"
const EMPTY_TRAIT_BODY := "고유 특성이 없습니다."

var _entering: bool = false
var _entry_resolved: bool = false
var _stage_index: int = 0
var _preview_form_id: StringName = &""
var _preview_feet_from_center: float = 0.0
var _echo_feet_from_center: float = 0.0
var _echo_feet_ready: bool = false
var _trait_panel: PanelContainer
var _trait_name_label: Label
var _trait_body_label: Label

@onready var _player: Node2D = $World/HubPlayer
@onready var _camera: Camera2D = $World/Camera2D
@onready var _tv: Control = $UI/TVUIRoot
@onready var _margin: MarginContainer = $UI/TVUIRoot/Margin
@onready var _form_name: Label = $UI/TVUIRoot/Margin/Columns/LeftPanel/FormSelector/FormName
@onready var _preview_root: Control = $UI/TVUIRoot/Margin/Columns/LeftPanel/FormPreview
@onready var _preview: AnimatedSprite2D = $UI/TVUIRoot/Margin/Columns/LeftPanel/FormPreview/PreviewSprite
@onready var _form_selector: Control = $UI/TVUIRoot/Margin/Columns/LeftPanel/FormSelector
@onready var _previous_form: Button = $UI/TVUIRoot/Margin/Columns/LeftPanel/FormSelector/PreviousFormButton
@onready var _next_form: Button = $UI/TVUIRoot/Margin/Columns/LeftPanel/FormSelector/NextFormButton
@onready var _trait: Label = $UI/TVUIRoot/Margin/Columns/RightPanel/TraitLabel
@onready var _atk: Label = $UI/TVUIRoot/Margin/Columns/RightPanel/AtkRow/AtkValue
@onready var _hp: Label = $UI/TVUIRoot/Margin/Columns/RightPanel/HpRow/HpValue
@onready var _attacks: Label = $UI/TVUIRoot/Margin/Columns/RightPanel/AttacksRow/AttacksValue
@onready var _stage_name: Label = $UI/TVUIRoot/Margin/Columns/RightPanel/StagePanel/StageCycle/StageName
@onready var _previous_stage: Button = $UI/TVUIRoot/Margin/Columns/RightPanel/StagePanel/StageCycle/PreviousStageButton
@onready var _next_stage: Button = $UI/TVUIRoot/Margin/Columns/RightPanel/StagePanel/StageCycle/NextStageButton
@onready var _start: Button = $UI/TVUIRoot/Margin/Columns/RightPanel/StagePanel/StartButton
@onready var _difficulty_name: Label = $UI/TVUIRoot/Margin/Columns/RightPanel/DifficultyPanel/DifficultyCycle/DifficultyName
@onready var _previous_difficulty: Button = $UI/TVUIRoot/Margin/Columns/RightPanel/DifficultyPanel/DifficultyCycle/PreviousDifficultyButton
@onready var _next_difficulty: Button = $UI/TVUIRoot/Margin/Columns/RightPanel/DifficultyPanel/DifficultyCycle/NextDifficultyButton


func _ready() -> void:
	var session := GameSession.get_session()
	session.ensure_defaults()
	session.consume_last_stage_result()
	if _player != null:
		_player.visible = false
		if _player.has_method("apply_form"):
			_player.call("apply_form", session.get_current_form())
	_prepare_buttons(_tv)
	_previous_form.pressed.connect(_cycle_form.bind(-1))
	_next_form.pressed.connect(_cycle_form.bind(1))
	_previous_stage.pressed.connect(_cycle_stage.bind(-1))
	_next_stage.pressed.connect(_cycle_stage.bind(1))
	_previous_difficulty.pressed.connect(_cycle_difficulty.bind(-1))
	_next_difficulty.pressed.connect(_cycle_difficulty.bind(1))
	_start.pressed.connect(_on_start_pressed)
	_bind_trait_hover()
	_build_trait_panel()
	_layout_left_column()
	if _preview_root != null and not _preview_root.resized.is_connected(_center_preview):
		_preview_root.resized.connect(_center_preview)
	if _margin != null:
		_margin.add_theme_constant_override(&"margin_left", TV_MARGIN)
		_margin.add_theme_constant_override(&"margin_top", TV_MARGIN)
		_margin.add_theme_constant_override(&"margin_right", TV_MARGIN)
		_margin.add_theme_constant_override(&"margin_bottom", TV_MARGIN)
	_stage_index = _saved_stage_index()
	refresh_tv()
	PauseMenu.mount(self, PauseMenu.Context.HUB)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_fit_view):
		viewport.size_changed.connect(_fit_view)
	_fit_view()
	print("ENTRY")


func _process(_delta: float) -> void:
	if not _entry_resolved and not SceneFader.get_fader().transition_in_progress:
		_entry_resolved = true
		OverrideAcquiredPopup.present_pending()
	_apply_input_lock()


func request_stage_entry(stage_id: StringName) -> void:
	if _clicks_blocked():
		return
	var state := _stage_state(stage_id)
	if state != "AVAILABLE" and state != "CLEARED":
		return
	if SceneFader.get_fader().transition_in_progress:
		return
	_entering = true
	_hide_trait_panel()
	_apply_input_lock()
	GameSession.get_session().start_stage(stage_id)
	SceneFader.get_fader().go_to_stage(stage_id)


func refresh_tv() -> void:
	_refresh_form()
	_refresh_stage()
	_refresh_difficulty()
	_apply_input_lock()


func _cycle_form(step: int) -> void:
	if _clicks_blocked():
		return
	var session := GameSession.get_session()
	var ids := session.acquired_form_ids
	if ids.size() <= 1:
		return
	var index := _form_index()
	var next := index + step
	if next < 0:
		next = ids.size() - 1
	elif next >= ids.size():
		next = 0
	var form_id := ids[next]
	if not session.equip_form(form_id):
		return
	if _player != null and _player.has_method("apply_form"):
		_player.call("apply_form", FormRegistry.get_form(form_id))
	refresh_tv()


func _cycle_stage(step: int) -> void:
	if _clicks_blocked():
		return
	var ids := StageRegistry.stage_ids()
	if ids.is_empty():
		return
	var next := _stage_index + step
	if next < 0:
		next = ids.size() - 1
	elif next >= ids.size():
		next = 0
	_stage_index = next
	var session := GameSession.get_session()
	session.selected_stage_id = ids[_stage_index]
	refresh_tv()


func _cycle_difficulty(step: int) -> void:
	if _clicks_blocked():
		return
	GameSession.get_session().cycle_difficulty(step)
	refresh_tv()


func _on_start_pressed() -> void:
	var ids := StageRegistry.stage_ids()
	if _stage_index < 0 or _stage_index >= ids.size():
		return
	request_stage_entry(ids[_stage_index])


func _refresh_form() -> void:
	var session := GameSession.get_session()
	var form_id := session.get_current_form_id()
	var form := session.get_current_form()
	var title := String(form_id)
	if form != null and not form.display_name.is_empty():
		title = form.display_name
	_form_name.text = title
	_trait.text = "특성: %s" % _trait_title(form)
	_atk.text = str(session.final_attack_power(form_id))
	_hp.text = str(session.final_max_hp(form_id))
	_attacks.text = str(session.final_attack_count(form_id))
	var multiple := session.acquired_form_ids.size() > 1
	_set_enabled(_previous_form, multiple)
	_set_enabled(_next_form, multiple)
	_show_form_preview(form)
	_sync_trait_panel()


func _refresh_stage() -> void:
	var ids := StageRegistry.stage_ids()
	if ids.is_empty():
		_stage_name.text = ""
		_apply_stage_button("UNAVAILABLE")
		return
	_stage_index = clampi(_stage_index, 0, ids.size() - 1)
	var stage_id := ids[_stage_index]
	var session := GameSession.get_session()
	_stage_name.text = session.stage_display_name(stage_id)
	var state := _stage_state(stage_id)
	var multiple := ids.size() > 1
	_set_enabled(_previous_stage, multiple)
	_set_enabled(_next_stage, multiple)
	_apply_stage_button(state)


func _refresh_difficulty() -> void:
	if _difficulty_name == null:
		return
	_difficulty_name.text = GameSession.get_session().difficulty_label()
	_set_enabled(_previous_difficulty, true)
	_set_enabled(_next_difficulty, true)


func _saved_stage_index() -> int:
	var ids := StageRegistry.stage_ids()
	if ids.is_empty():
		return 0
	var session := GameSession.get_session()
	var found := ids.find(session.selected_stage_id)
	if found >= 0:
		return found
	var fallback := ids.find(GameSession.STAGE_THE_VEIL)
	if fallback < 0:
		fallback = 0
	session.selected_stage_id = ids[fallback]
	return fallback


func _apply_stage_button(state: String) -> void:
	var open := state == "AVAILABLE" or state == "CLEARED"
	_set_enabled(_start, open)
	if state == "LOCKED":
		_start.text = "잠김"
	elif state == "UNAVAILABLE":
		_start.text = "이용 불가"
	else:
		_start.text = "진입"


func _show_form_preview(form: FormDefinition) -> void:
	if _preview == null:
		return
	_preview.scale = Vector2(FORM_PREVIEW_SCALE, FORM_PREVIEW_SCALE)
	_preview.flip_h = false
	if form == null:
		_hide_form_preview(&"")
		_center_preview()
		return
	if form.form_id == _preview_form_id and _preview.visible:
		_center_preview()
		return
	var frames := form.sprite_frames
	if frames == null and form.animation_profile != null:
		frames = form.animation_profile.build_sprite_frames()
	if frames == null or not frames.has_animation(&"idle") or frames.get_frame_count(&"idle") <= 0:
		_hide_form_preview(form.form_id)
		_center_preview()
		return
	_preview.visible = true
	_preview.sprite_frames = frames
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.play(&"idle")
	_preview.frame = 0
	_preview_form_id = form.form_id
	_preview_feet_from_center = FormVisual.opaque_feet_of_texture(frames.get_frame_texture(&"idle", 0))
	_center_preview()


func _hide_form_preview(form_id: StringName) -> void:
	_preview_form_id = &""
	if _preview != null:
		_preview.visible = false
		_preview.stop()
	push_warning("Form '%s' has no idle preview." % form_id)


func _layout_left_column() -> void:
	if _preview_root == null or _form_selector == null:
		return
	var selector_height := maxf(_form_selector.get_combined_minimum_size().y, FORM_SELECTOR_MIN_HEIGHT)
	_form_selector.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_form_selector.offset_left = 0.0
	_form_selector.offset_right = 0.0
	_form_selector.offset_top = -selector_height
	_form_selector.offset_bottom = 0.0
	_form_selector.z_index = 1
	_preview_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_root.offset_left = 0.0
	_preview_root.offset_top = 0.0
	_preview_root.offset_right = 0.0
	_preview_root.offset_bottom = -(selector_height + FORM_PREVIEW_GAP)
	_preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_root.clip_contents = true
	_preview_root.z_index = 0
	if _preview.get("mouse_filter") != null:
		_preview.set("mouse_filter", Control.MOUSE_FILTER_IGNORE)


func _center_preview() -> void:
	if _preview == null or _preview_root == null:
		return
	var center := _preview_root.size * 0.5
	var baseline_y := center.y + FORM_PREVIEW_OFFSET_Y + _echo_preview_feet() * FORM_PREVIEW_SCALE
	var feet_y := _preview_feet_from_center * FORM_PREVIEW_SCALE
	_preview.position = Vector2(center.x, baseline_y - feet_y)


func _echo_preview_feet() -> float:
	if _echo_feet_ready:
		return _echo_feet_from_center
	_echo_feet_ready = true
	_echo_feet_from_center = FormVisual.opaque_feet_from_center(FormRegistry.get_form(&"echo"))
	return _echo_feet_from_center


func _bind_trait_hover() -> void:
	if _trait == null:
		return
	_trait.mouse_filter = Control.MOUSE_FILTER_STOP
	_trait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trait.custom_minimum_size.y = 22.0
	_trait.mouse_entered.connect(_on_trait_hover.bind(true))
	_trait.mouse_exited.connect(_on_trait_hover.bind(false))


func _build_trait_panel() -> void:
	if _tv == null:
		return
	var panel := PanelContainer.new()
	panel.name = "TraitInfoPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 8
	panel.custom_minimum_size = Vector2(TRAIT_PANEL_WIDTH, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.96, 0.93, 1.0)
	style.border_color = Color(0.12, 0.14, 0.18, 1.0)
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	panel.add_child(box)
	var title := Label.new()
	title.name = "TraitNameLabel"
	RetroTheme.apply_label(title, 15, RetroTheme.TEXT)
	box.add_child(title)
	var body := Label.new()
	body.name = "TraitDescriptionLabel"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(TRAIT_PANEL_WIDTH - 16.0, 0.0)
	RetroTheme.apply_label(body, 13, RetroTheme.TEXT)
	box.add_child(body)
	_tv.add_child(panel)
	_trait_panel = panel
	_trait_name_label = title
	_trait_body_label = body


func _on_trait_hover(inside: bool) -> void:
	if inside and not _pause_open() and not _entering:
		_show_trait_panel()
	else:
		_hide_trait_panel()


func _show_trait_panel() -> void:
	if _trait_panel == null:
		return
	_fill_trait_panel()
	_trait_panel.visible = true
	_place_trait_panel()


func _hide_trait_panel() -> void:
	if _trait_panel != null:
		_trait_panel.visible = false


func _sync_trait_panel() -> void:
	if _trait_panel == null or not _trait_panel.visible:
		return
	_fill_trait_panel()
	_place_trait_panel()


func _fill_trait_panel() -> void:
	var title := EMPTY_TRAIT_TITLE
	var body := EMPTY_TRAIT_BODY
	var form := GameSession.get_session().get_current_form()
	if form != null and form.trait_id != &"" and TraitRegistry.has_trait(form.trait_id):
		var definition := TraitRegistry.get_trait(form.trait_id)
		if definition != null:
			title = definition.display_name
			body = definition.formatted_description()
	if _trait_name_label != null:
		_trait_name_label.text = title
	if _trait_body_label != null:
		_trait_body_label.text = body


func _place_trait_panel() -> void:
	if _trait_panel == null or _trait == null or _tv == null:
		return
	var width := TRAIT_PANEL_WIDTH
	var height := maxf(_trait_panel.get_combined_minimum_size().y, 36.0)
	var label := _trait.get_global_rect()
	var tv := _tv.get_global_rect()
	var below := label.position.y + label.size.y + 6.0
	var above := label.position.y - height - 6.0
	var origin := Vector2(label.position.x, below)
	if below + height > tv.position.y + tv.size.y and above >= tv.position.y:
		origin.y = above
	var max_x := tv.position.x + tv.size.x - width
	var max_y := tv.position.y + tv.size.y - height
	origin.x = clampf(origin.x, tv.position.x, maxf(max_x, tv.position.x))
	origin.y = clampf(origin.y, tv.position.y, maxf(max_y, tv.position.y))
	_trait_panel.global_position = origin
	_trait_panel.size = Vector2(width, height)


func _trait_title(form: FormDefinition) -> String:
	if form == null or form.trait_id == &"":
		return "없음"
	if not TraitRegistry.has_trait(form.trait_id):
		return "없음"
	var definition := TraitRegistry.get_trait(form.trait_id)
	if definition == null or definition.display_name.is_empty():
		return "없음"
	return definition.display_name


func _form_index() -> int:
	var session := GameSession.get_session()
	var ids := session.acquired_form_ids
	for index in ids.size():
		if ids[index] == session.current_form_id:
			return index
	return 0


func _stage_state(stage_id: StringName) -> String:
	var session := GameSession.get_session()
	if not session.is_stage_unlocked(stage_id):
		return "LOCKED"
	if not StageRegistry.is_stage_playable(stage_id):
		return "UNAVAILABLE"
	if session.is_stage_cleared(stage_id):
		return "CLEARED"
	return "AVAILABLE"


func can_open_pause() -> bool:
	return _entry_resolved and not _entering and not SceneFader.get_fader().transition_in_progress


func _clicks_blocked() -> bool:
	return not _entry_resolved or _entering or SceneFader.get_fader().transition_in_progress or _pause_open()


func _pause_open() -> bool:
	var pause := get_node_or_null("PauseMenu")
	return pause != null and pause.has_method("is_open") and bool(pause.call("is_open"))


func _apply_input_lock() -> void:
	var locked := _clicks_blocked()
	if _pause_open() or _entering:
		_hide_trait_panel()
	if _tv == null:
		return
	_tv.modulate = Color(1, 1, 1, 0.55) if locked else Color.WHITE


func _prepare_buttons(root: Node) -> void:
	if root == null:
		return
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null:
			continue
		button.focus_mode = Control.FOCUS_NONE
		GameAudio.bind_button(button)
		button.mouse_entered.connect(_on_button_hover.bind(button, true))
		button.mouse_exited.connect(_on_button_hover.bind(button, false))


func _on_button_hover(button: Button, hovered: bool) -> void:
	if button.disabled:
		return
	button.modulate = Color(1.15, 1.12, 1.0) if hovered else Color.WHITE


func _set_enabled(button: Button, enabled: bool) -> void:
	if button == null:
		return
	button.disabled = not enabled
	button.modulate = Color.WHITE if enabled else Color(1, 1, 1, 0.4)


func _fit_view() -> void:
	if _camera == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var factor := minf(viewport_size.x / WORLD_SIZE.x, viewport_size.y / WORLD_SIZE.y)
	_camera.zoom = Vector2(factor, factor)
	_camera.position = CAMERA_START
	if _tv == null:
		return
	var cover := maxf(viewport_size.x / ART_SIZE.x, viewport_size.y / ART_SIZE.y)
	var shown := ART_SIZE * cover
	var origin := (viewport_size - shown) * 0.5
	var screen := Rect2(origin + TV_SAFE.position * cover, TV_SAFE.size * cover)
	_tv.anchor_left = 0.0
	_tv.anchor_top = 0.0
	_tv.anchor_right = 0.0
	_tv.anchor_bottom = 0.0
	_tv.offset_left = screen.position.x
	_tv.offset_top = screen.position.y
	_tv.offset_right = screen.position.x + screen.size.x
	_tv.offset_bottom = screen.position.y + screen.size.y
	_layout_left_column()
	_center_preview()
	if _trait_panel != null and _trait_panel.visible:
		_place_trait_panel()
