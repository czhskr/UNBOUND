class_name FormRegistry
extends RefCounted

## form_id가 어떤 FormDefinition을 가리키는지. 획득과 장착 상태는 GameState가 가진다.

const ECHO := preload("res://data/forms/echo.tres")
const SENTRY := preload("res://data/forms/sentry.tres")
const VECTOR := preload("res://data/forms/vector.tres")
const PURGE := preload("res://data/forms/purge.tres")
const CIPHER := preload("res://data/forms/cipher.tres")
const AEGIS := preload("res://data/forms/aegis.tres")
const SERAPH := preload("res://data/forms/seraph.tres")
const LEON := preload("res://data/forms/leon.tres")
const ARC := preload("res://data/forms/arc.tres")
## 획득/장착 경로 확인용. 최종 콘텐츠가 아니다.
const TEST_FORM := preload("res://data/forms/test_form.tres")

static var _loaded: bool = false
static var _forms: Dictionary = {}


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	register(ECHO)
	register(SENTRY)
	register(VECTOR)
	register(PURGE)
	register(CIPHER)
	register(AEGIS)
	register(SERAPH)
	register(LEON)
	register(ARC)
	register(TEST_FORM)


static func register(definition: FormDefinition) -> bool:
	if definition == null:
		push_error("Cannot register a null FormDefinition.")
		return false
	if not definition.validate():
		push_error("Refusing to register invalid form '%s'." % definition.form_id)
		return false
	if _forms.has(definition.form_id):
		push_error("Duplicate form id '%s'." % definition.form_id)
		return false
	_forms[definition.form_id] = definition
	return true


static func has_form(form_id: StringName) -> bool:
	ensure_loaded()
	return _forms.has(form_id)


static func get_form(form_id: StringName) -> FormDefinition:
	ensure_loaded()
	if not _forms.has(form_id):
		push_error("Unknown form id '%s'." % form_id)
		return null
	return _forms[form_id] as FormDefinition
