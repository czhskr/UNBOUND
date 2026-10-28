class_name StageVisualDefinition
extends Resource

## 스테이지 화면. 배경 레이어 수에 제한을 두지 않는다.

@export var background_layers: Array[StageVisualLayer] = []
@export var platform_texture: Texture2D
@export var platform_position: Vector2 = Vector2(192, 184)
@export var ground_y: float = 155.0
@export var background_offset: Vector2 = Vector2.ZERO
@export var platform_z_index: int = 0


func validate() -> bool:
	if background_layers.is_empty():
		push_warning("Stage visual has no background layers.")
	if platform_texture == null:
		push_warning("Stage visual platform texture is null.")
	var seen := {}
	for layer in background_layers:
		if layer == null:
			push_warning("Stage visual has a null background layer.")
			continue
		if layer.texture == null:
			push_warning("Stage visual layer '%s' has no texture." % layer.layer_id)
		if layer.layer_id != &"" and seen.has(layer.layer_id):
			push_warning("Duplicate visual layer id '%s'." % layer.layer_id)
		seen[layer.layer_id] = true
	return true
