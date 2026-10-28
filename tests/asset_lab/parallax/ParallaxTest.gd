extends Node2D

# 배경 테스트용 논리 화면: 384 x 216 (16:9)
const TEST_WORLD_SIZE := Vector2(384.0, 216.0)
const CAMERA_START := Vector2(192.0, 108.0)

@export var camera_speed: float = 150.0

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_camera_to_viewport)
	_fit_camera_to_viewport()
	camera.position = CAMERA_START
	camera.offset = Vector2.ZERO

func _fit_camera_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	# 프로젝트 뷰포트가 384x216이든 1152x648이든 같은 구도로 표시.
	var factor: float = minf(
		viewport_size.x / TEST_WORLD_SIZE.x,
		viewport_size.y / TEST_WORLD_SIZE.y
	)
	camera.zoom = Vector2(factor, factor)

func _process(delta: float) -> void:
	var horizontal := 0.0
	if Input.is_key_pressed(KEY_A):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_D):
		horizontal += 1.0
	camera.position.x += horizontal * camera_speed * delta
	if Input.is_key_pressed(KEY_R):
		camera.position = CAMERA_START
