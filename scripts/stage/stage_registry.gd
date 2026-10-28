class_name StageRegistry
extends RefCounted

## stage_id가 어떤 데이터와 씬을 가리키는지. 해금 상태는 GameState가 가진다.

const THE_VEIL := preload("res://data/stages/the_veil.tres")
const RUPTURE := preload("res://data/stages/rupture.tres")
const REVELATION := preload("res://data/stages/revelation.tres")

static var _loaded: bool = false
static var _stages: Dictionary = {}


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	register(THE_VEIL)
	register(RUPTURE)
	register(REVELATION)


static func register(definition: StageDefinition) -> bool:
	if definition == null:
		push_error("Cannot register a null StageDefinition.")
		return false
	if not definition.validate():
		push_error("Refusing to register invalid stage '%s'." % definition.stage_id)
		return false
	if _stages.has(definition.stage_id):
		push_error("Duplicate stage id '%s'." % definition.stage_id)
		return false
	_stages[definition.stage_id] = definition
	return true


static func has_stage(stage_id: StringName) -> bool:
	ensure_loaded()
	return _stages.has(stage_id)


static func is_stage_playable(stage_id: StringName) -> bool:
	ensure_loaded()
	if not _stages.has(stage_id):
		return false
	var definition := _stages[stage_id] as StageDefinition
	if definition == null or not definition.implemented:
		return false
	return not definition.scene_path.strip_edges().is_empty()


static func stage_ids() -> Array[StringName]:
	ensure_loaded()
	var ids: Array[StringName] = []
	for key in _stages.keys():
		ids.append(StringName(key))
	return ids


static func get_stage(stage_id: StringName) -> StageDefinition:
	ensure_loaded()
	if not _stages.has(stage_id):
		push_error("Unknown stage id '%s'." % stage_id)
		return null
	return _stages[stage_id] as StageDefinition


static func default_unlocked_ids() -> Array[StringName]:
	ensure_loaded()
	var ids: Array[StringName] = []
	for key in _stages.keys():
		var definition := _stages[key] as StageDefinition
		if definition != null and definition.unlocked_by_default:
			ids.append(definition.stage_id)
	return ids
