class_name FormDefinition
extends Resource

## 주인공이 장착하는 오버라이드. 스테이지 진행, 세이브, 적 전투 수치는 넣지 않는다.

@export var form_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## 지정하면 이 프레임을 그대로 쓴다. 비어 있으면 animation_profile로 만든다.
@export var sprite_frames: SpriteFrames
@export var animation_profile: CharacterAnimationProfile
## 공통 발 위치에 더하는 오버라이드별 보정. 공통 기준은 CharacterVisual에 있다.
@export var visual_offset: Vector2 = Vector2.ZERO
## 플레이어 최종 능력치. 적 능력치를 복사하지 않는다.
## Echo 20 / 100 / 4만 기존 전투 기준이다. 다른 숫자는 시험값이며 최종 밸런스가 아니다.
@export var base_attack_power: int = 20
@export var base_max_hp: int = 100
@export var base_attack_count: int = 4
## 이 오버라이드를 장착한 주인공에게만 해당하는 특성 ID. 적이 쓰는 행동이 아니다.
@export var trait_id: StringName = &""


func validate() -> bool:
	if form_id == &"":
		push_error("FormDefinition form_id is empty.")
		return false
	if sprite_frames == null and animation_profile == null:
		push_error("Form '%s' has no visual data." % form_id)
		return false
	return true
