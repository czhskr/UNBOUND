extends Node

## CombatTest 전용 입력. 프로젝트 InputMap에는 등록하지 않는다.
## 기본 경로: R = 장면 재시작. J는 RhythmController의 리듬 입력이다.
## direct_attack_debug를 켜면 J/K가 리듬 대신 직접 공격이 된다.

const WORLD_SIZE := Vector2(384.0, 216.0)

@export var player: CombatActor
@export var enemy: CombatActor
@export var player_hp: ProgressBar
@export var enemy_hp: ProgressBar
@export var camera: Camera2D

var battle_finished: bool = false
@export var direct_attack_debug: bool = false


func _ready() -> void:
	# 씬에 적힌 NodePath가 런타임에 비면, 이 테스트 장면의 고정 경로로 다시 연결한다.
	if player == null:
		player = _node_at("../Stage/Player", "../World/Player") as CombatActor
	if enemy == null:
		enemy = _node_at("../Stage/Enemy", "../World/Enemy") as CombatActor
	if player_hp == null:
		player_hp = _node_at("../PlayerHP", "../UI/Layout/PlayerHP") as ProgressBar
	if enemy_hp == null:
		enemy_hp = _node_at("../EnemyHP", "../UI/Layout/EnemyHP") as ProgressBar
	if camera == null:
		camera = _node_at("../Camera2D", "../World/Camera2D") as Camera2D
	if player == null:
		push_error("CombatTestController is missing the player.")
		return

	_bind_hp(player, player_hp, "PLAYER")
	DamagePopup.mount(get_parent())
	PauseMenu.mount(get_parent())
	print("PLAYER HP: %d/%d" % [player.current_hp, player.max_hp])
	if _scene_reset_allowed():
		print("COMBAT TEST: R reset")

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_fit_camera):
		viewport.size_changed.connect(_fit_camera)
	_fit_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_R:
		if not _scene_reset_allowed():
			return
		if SceneFader.get_fader().transition_in_progress:
			return
		_mark_input_handled()
		get_tree().reload_current_scene()
		return
	if not direct_attack_debug:
		return
	match key_event.keycode:
		KEY_J:
			_mark_input_handled()
			_request_attack(player, enemy)
		KEY_K:
			_mark_input_handled()
			_request_attack(enemy, player)


func _scene_reset_allowed() -> bool:
	var scene := get_tree().current_scene
	return scene == null or not scene.scene_file_path.ends_with("StageCombat.tscn")


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _bind_hp(actor: CombatActor, bar: ProgressBar, label: String) -> void:
	if bar != null:
		bar.max_value = actor.max_hp
		bar.value = actor.current_hp
	actor.health_changed.connect(func(current_hp: int, max_hp: int) -> void:
		if bar != null:
			bar.max_value = max_hp
			bar.value = current_hp
		print("%s HP: %d/%d" % [label, current_hp, max_hp])
	)


func _request_attack(attacker: CombatActor, target: CombatActor) -> void:
	if _input_blocked() or attacker == null or target == null:
		return
	attacker.perform_attack(target, true)


func _input_blocked() -> bool:
	if battle_finished:
		return true
	var encounter := get_node_or_null("../EncounterController") as EncounterController
	return encounter != null and encounter.input_blocked


func _node_at(primary: String, alternate: String) -> Node:
	var node := get_node_or_null(primary)
	if node == null:
		node = get_node_or_null(alternate)
	return node


func _fit_camera() -> void:
	if camera == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var factor := minf(viewport_size.x / WORLD_SIZE.x, viewport_size.y / WORLD_SIZE.y)
	camera.zoom = Vector2(factor, factor)
