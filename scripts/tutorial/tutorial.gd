extends Control

## 튜토리얼 껍데기. 설명과 캡처 경로는 여기 두고, 세션은 바꾸지 않는다.

const WINDOW_SIZE := Vector2(520, 360)
const PAGES: Array[Dictionary] = [
	{
		"title": "노드 입력",
		"images": ["res://assets/tutorial/captures/tutorial_node.png"],
		"description": "노드가 중앙 판정 지점에 도달할 때 J 또는 K를 입력합니다.",
	},
	{
		"title": "적 스킬: 노드 잠금",
		"images": ["res://assets/tutorial/captures/tutorial_lock.png"],
		"description": "잠긴 노드를 입력하면 공격에 실패하고, 다음 플레이어 공격 노드가 삭제됩니다.",
	},
	{
		"title": "적 스킬: SLOW / FAST",
		"images": ["res://assets/tutorial/captures/tutorial_speed.png"],
		"description": "일정 시간 동안 노드 이동 속도를 느리게 하거나 빠르게 합니다.",
	},
	{
		"title": "적 스킬: STEAL",
		"images": ["res://assets/tutorial/captures/tutorial_steal.png"],
		"description": "플레이어 노드를 적 노드로 변환합니다.",
	},
]

var _page: int = 0

@onready var _panel: Panel = $TutorialPanel
@onready var _title: Label = $TutorialPanel/Title
@onready var _image: TextureRect = $TutorialPanel/CaptureImage
@onready var _placeholder: Label = $TutorialPanel/CaptureImage/Placeholder
@onready var _description: Label = $TutorialPanel/Description
@onready var _prev: Button = $TutorialPanel/PrevButton
@onready var _next: Button = $TutorialPanel/NextButton
@onready var _back: Button = $TutorialPanel/BackButton


func _ready() -> void:
	_panel.add_theme_stylebox_override(&"panel", RetroTheme.window_style())
	RetroTheme.apply_label(_title, 16, RetroTheme.TITLE_TEXT)
	RetroTheme.apply_label(_placeholder, 12, RetroTheme.TITLE_TEXT)
	RetroTheme.apply_label(_description, 12, RetroTheme.TEXT)
	RetroTheme.apply_button(_prev, 14)
	RetroTheme.apply_button(_next, 14)
	RetroTheme.apply_button(_back, 14)
	_prev.pressed.connect(_show_previous)
	_next.pressed.connect(_show_next)
	_back.pressed.connect(_back_to_menu)
	_show_page()
	_place()
	print("TUTORIAL")


func _show_previous() -> void:
	if SceneFader.get_fader().transition_in_progress or _page <= 0:
		return
	_page -= 1
	_show_page()


func _show_next() -> void:
	if SceneFader.get_fader().transition_in_progress or _page >= PAGES.size() - 1:
		return
	_page += 1
	_show_page()


func _back_to_menu() -> void:
	if SceneFader.get_fader().transition_in_progress:
		return
	_back.disabled = true
	SceneFader.get_fader().go_to_main_menu()


func _show_page() -> void:
	var page: Dictionary = PAGES[_page]
	_title.text = str(page["title"])
	_description.text = str(page["description"])
	_prev.disabled = _page <= 0
	_next.disabled = _page >= PAGES.size() - 1
	var texture := _first_texture(page["images"])
	_image.texture = texture
	_placeholder.visible = texture == null


func _first_texture(images: Variant) -> Texture2D:
	if images is not Array:
		return null
	for path in images:
		var resource_path := str(path)
		if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
			continue
		var texture := load(resource_path) as Texture2D
		if texture != null:
			return texture
	return null


func _place() -> void:
	var viewport := get_viewport()
	var size := Vector2(1152, 648)
	if viewport != null:
		var visible := viewport.get_visible_rect().size
		if visible.x > 1.0 and visible.y > 1.0:
			size = visible
	_panel.position = (size - WINDOW_SIZE) * 0.5
