class_name TraitBehavior
extends Resource

## 이벤트 알림만 받는다. 수치 변경과 전투 중 누적 상태는 두지 않는다.


func on_equipped(_context: Dictionary) -> void:
	pass


func on_unequipped(_context: Dictionary) -> void:
	pass


func on_combat_started(_context: Dictionary) -> void:
	pass


func on_player_attack_success(_context: Dictionary) -> void:
	pass


func on_player_parry_success(_context: Dictionary) -> void:
	pass


func on_player_damaged(_context: Dictionary) -> void:
	pass


func on_combat_ended(_context: Dictionary) -> void:
	pass
