class_name EncounterDialogueResolver
extends RefCounted

## 조우 대사 선택. 리듬 RNG와 섞지 않는다.
## 반복은 일반 repeat 풀 하나만 쓴다.

const CUE := "start"

static var _rng := RandomNumberGenerator.new()
static var _ready := false


static func resolve(history: Dictionary, enemy_id: StringName, dialogue_set: EncounterDialogueSet, same_override: bool = false) -> DialogueResource:
	if enemy_id == &"" or dialogue_set == null:
		return null
	var state := _state_for(history, enemy_id)
	var same_first := dialogue_set.same_override_first
	if same_override and same_first != null and not bool(state["same_first_seen"]):
		state["same_first_seen"] = true
		history[enemy_id] = state
		return same_first
	var first := dialogue_set.first_encounter
	var same_revisit := same_override and bool(state["same_first_seen"])
	if not same_revisit and not bool(state["normal_first_seen"]):
		state["normal_first_seen"] = true
		history[enemy_id] = state
		if first != null:
			return first
	var picked := _take_repeat(dialogue_set, dialogue_set.repeat_dialogues, first, state)
	history[enemy_id] = state
	return picked


static func _state_for(history: Dictionary, enemy_id: StringName) -> Dictionary:
	var raw: Variant = history.get(enemy_id, {})
	var state: Dictionary = raw if raw is Dictionary else {}
	if not state.has("normal_first_seen"):
		state["normal_first_seen"] = false
	if not state.has("same_first_seen"):
		state["same_first_seen"] = false
	if not state.has("bag"):
		state["bag"] = []
	if not state.has("bag_index"):
		state["bag_index"] = 0
	if not state.has("last_repeat_index"):
		state["last_repeat_index"] = -1
	history[enemy_id] = state
	return state


static func _take_repeat(dialogue_set: EncounterDialogueSet, repeats: Array[DialogueResource], first: DialogueResource, state: Dictionary) -> DialogueResource:
	var indices := dialogue_set.indices_for(first, repeats)
	if indices.is_empty():
		return null
	var bag: Array = state["bag"]
	var bag_index := int(state["bag_index"])
	if bag.is_empty() or bag_index >= bag.size():
		bag = []
		for index in indices:
			bag.append(index)
		_shuffle(bag)
		var last := int(state["last_repeat_index"])
		if indices.size() >= 2 and last >= 0 and int(bag[0]) == last:
			var swap_with := 1
			for candidate in range(1, bag.size()):
				if int(bag[candidate]) != last:
					swap_with = candidate
					break
			var held: Variant = bag[0]
			bag[0] = bag[swap_with]
			bag[swap_with] = held
		bag_index = 0
	var picked := int(bag[bag_index])
	state["bag"] = bag
	state["bag_index"] = bag_index + 1
	state["last_repeat_index"] = picked
	if picked < 0 or picked >= repeats.size():
		return null
	return repeats[picked]


static func _shuffle(items: Array) -> void:
	if not _ready:
		_ready = true
		_rng.randomize()
	for index in range(items.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var held: Variant = items[index]
		items[index] = items[swap_index]
		items[swap_index] = held
