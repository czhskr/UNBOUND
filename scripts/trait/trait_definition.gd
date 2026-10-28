class_name TraitDefinition
extends Resource

## 오버라이드에 연결되는 특성. 적 능력과 전투 수치는 담지 않는다.
## 쿨타임과 피해 배율은 이 리소스가 유일한 출처다. UI는 formatted_description()만 읽는다.

@export var trait_id: StringName
@export var display_name: String = ""
## 플레이스홀더: {cooldown} {stack_damage} {max_damage} {damage_percent}
@export_multiline var description: String = ""
@export var behavior: TraitBehavior
## 효과를 쓴 뒤 다시 쓸 수 있을 때까지. 0이면 쿨타임이 없다.
@export var cooldown_seconds: float = 0.0
## 추적 보정. 0이면 이 특성은 누적 피해를 쓰지 않는다.
@export var damage_per_stack: int = 0
@export var max_stacks: int = 0
## 상위 권한. 1이면 배율이 없다. 1.5는 설명에 +50%로 바뀐다.
@export var damage_multiplier: float = 1.0
## 경계 프로토콜. 현재 난이도 패링 창에 곱한다. 1이면 보너스가 없다. 시험값이다.
@export var parry_window_multiplier: float = 1.0


func validate() -> bool:
	if trait_id == &"":
		push_error("TraitDefinition trait_id is empty.")
		return false
	if behavior == null:
		push_error("Trait '%s' has no behavior." % trait_id)
		return false
	return true


func formatted_description() -> String:
	var stack_damage := damage_per_stack
	var max_damage := damage_per_stack * maxi(max_stacks, 0)
	var percent := int(round((damage_multiplier - 1.0) * 100.0))
	var cooldown := int(round(cooldown_seconds))
	var text := description
	text = text.replace("{stack_damage}", _signed(stack_damage))
	text = text.replace("{max_damage}", _signed(max_damage))
	text = text.replace("{damage_percent}", "%s%%" % _signed(percent))
	text = text.replace("{cooldown}", str(cooldown))
	return text


func _signed(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)
