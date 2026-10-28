class_name EncounterDialogueSet
extends Resource

## 한 적의 일반 조우와 동일 오버라이드 첫 대사. 사망 대사는 넣지 않는다.

@export var first_encounter: DialogueResource
@export var repeat_dialogues: Array[DialogueResource] = []
@export var same_override_first: DialogueResource


func valid_repeat_indices() -> Array[int]:
	return indices_for(first_encounter, repeat_dialogues)


func indices_for(first: DialogueResource, repeats: Array[DialogueResource]) -> Array[int]:
	var indices: Array[int] = []
	var seen: Dictionary = {}
	for index in repeats.size():
		var entry: DialogueResource = repeats[index]
		if entry == null:
			push_warning("Encounter dialogue repeat %d is null." % index)
			continue
		if seen.has(entry) or entry == first:
			push_warning("Encounter dialogue repeat %d is duplicated." % index)
		seen[entry] = true
		indices.append(index)
	return indices
