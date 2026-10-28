class_name StageVisualLayer
extends Resource

## 배경 레이어 하나. 텍스처, 순서, 패럴랙스, 위치만 담는다.

@export var layer_id: StringName
@export var texture: Texture2D
@export var z_index: int = 0
@export var scroll_ratio: float = 0.0
@export var offset: Vector2 = Vector2.ZERO
@export var visible: bool = true
