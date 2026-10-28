class_name EnemyDefinition
extends Resource

## 전투 상대 하나. 일반 적과 보스를 타입으로 나누지 않는다.
## 공격력 20은 공유 프로필의 임시값이다. HP는 max_hp가 0보다 크면 그 값을 쓴다.

@export var enemy_id: StringName
@export var display_name: String = ""
## Hyper 이름 아래 한 줄. 비어 있으면 설명 칸만 남긴다.
@export var hyper_description: String = ""
## 페이즈 사망 연출 뒤의 선택 대사. 리소스가 없으면 기다리지 않는다.
@export var death_dialogue_resource: DialogueResource
@export var death_dialogue_cue: String = ""
## 다음 오버라이드로 바뀐 뒤 Hyper 전의 선택 대사. encounter_dialogue가 있으면 그쪽을 먼저 쓴다.
@export var phase_intro_dialogue_resource: DialogueResource
@export var phase_intro_dialogue_cue: String = ""
## 조우 대사. 첫 대사는 세션당 한 번이고, 이후는 반복 풀이다.
@export var encounter_dialogue: EncounterDialogueSet
@export var combat_profile: EnemyCombatProfile
## 0이면 공유 combat_profile의 HP를 쓴다. 공격력은 항상 프로필을 쓴다. 시험값이다.
@export var max_hp: int = 0
@export var animation_profile: CharacterAnimationProfile
## 공통 scale에 곱하는 보정. 1이면 공통 크기만 쓴다.
@export var visual_scale: float = 1.0
## 공통 발 위치에 더하는 보정. 프레임 여백이 다를 때만 쓴다.
@export var visual_offset: Vector2 = Vector2.ZERO
## 공통 EffectAnchor에 더하는 보정. 비어 있으면 공통 몸 중심만 쓴다.
@export var effect_anchor_offset: Vector2 = Vector2.ZERO
## 획득은 enemy_id와 같은 오버라이드 id를 쓴다. 이 필드는 그 경로가 아니다.
@export var form_reward: FormDefinition
## 특수 스킬. 기본은 끄고, 누가 쓰는지는 데이터로만 정한다.
@export var can_lock_nodes: bool = false
@export var can_steal_nodes: bool = false
@export var can_use_speed_nodes: bool = false
## 기존 노드 뒤에 OVERLOAD 노드를 한 번 추가한다. Arc만 켠다.
@export var can_overload: bool = false
## 같은 actor가 사망 연출 없이 넘어갈 다음 정의. Arc는 Leon의 다음 phase다.
@export var next_phase: EnemyDefinition
@export var phase_transition_animation: StringName = &"cast"
@export var phase_transition_effect_id: StringName = &""
