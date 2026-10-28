class_name TestTraitBehavior
extends TraitBehavior

## 파이프라인 확인용. 피해, 판정, 속도는 바꾸지 않는다.


func on_equipped(_context: Dictionary) -> void:
	print("TRAIT EQUIPPED: test_trait")


func on_unequipped(_context: Dictionary) -> void:
	print("TRAIT CLEARED: test_trait")


func on_combat_started(_context: Dictionary) -> void:
	print("TRAIT COMBAT START: test_trait")


func on_player_attack_success(_context: Dictionary) -> void:
	print("TRAIT EVENT: PLAYER_ATTACK_SUCCESS")


func on_player_parry_success(_context: Dictionary) -> void:
	print("TRAIT EVENT: PLAYER_PARRY_SUCCESS")


func on_player_damaged(_context: Dictionary) -> void:
	print("TRAIT EVENT: PLAYER_DAMAGED")


func on_combat_ended(_context: Dictionary) -> void:
	print("TRAIT COMBAT END: test_trait")
