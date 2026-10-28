class_name TraitRegistry
extends RefCounted

## trait_id가 어떤 TraitDefinition을 가리키는지. 장착 상태는 TraitController가 가진다.

const TEST_TRAIT := preload("res://data/traits/test_trait.tres")
const SENTRY_GUARD := preload("res://data/traits/sentry_guard.tres")
const VECTOR_TRACKING := preload("res://data/traits/vector_tracking.tres")
const PURGE_DELETE := preload("res://data/traits/purge_delete.tres")
const CIPHER_ENCRYPT := preload("res://data/traits/cipher_encrypt.tres")
const AEGIS_FIREWALL := preload("res://data/traits/aegis_firewall.tres")
const SERAPH_AUTHORITY := preload("res://data/traits/seraph_authority.tres")
const LEON_RETRY := preload("res://data/traits/leon_retry.tres")
const ARC_EMP := preload("res://data/traits/arc_emp.tres")

static var _loaded: bool = false
static var _traits: Dictionary = {}


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	register(TEST_TRAIT)
	register(SENTRY_GUARD)
	register(VECTOR_TRACKING)
	register(PURGE_DELETE)
	register(CIPHER_ENCRYPT)
	register(AEGIS_FIREWALL)
	register(SERAPH_AUTHORITY)
	register(LEON_RETRY)
	register(ARC_EMP)


static func register(definition: TraitDefinition) -> bool:
	if definition == null:
		push_error("Cannot register a null TraitDefinition.")
		return false
	if not definition.validate():
		push_error("Refusing to register invalid trait '%s'." % definition.trait_id)
		return false
	if _traits.has(definition.trait_id):
		push_error("Duplicate trait id '%s'." % definition.trait_id)
		return false
	_traits[definition.trait_id] = definition
	return true


static func has_trait(trait_id: StringName) -> bool:
	ensure_loaded()
	if trait_id == &"":
		return false
	return _traits.has(trait_id)


static func get_trait(trait_id: StringName) -> TraitDefinition:
	ensure_loaded()
	if trait_id == &"":
		return null
	if not _traits.has(trait_id):
		push_error("Unknown trait id '%s'." % trait_id)
		return null
	return _traits[trait_id] as TraitDefinition
