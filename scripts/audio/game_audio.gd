class_name GameAudio
extends RefCounted

## 공용 효과음. 캐릭터별 파일은 만들지 않고 SFX 버스로만 재생한다.

const ATTACK := preload("res://assets/audio/sfx/attack.mp3")
const CLICK := preload("res://assets/audio/sfx/click.mp3")
const DEATH := preload("res://assets/audio/sfx/death.mp3")
const HOVER := preload("res://assets/audio/sfx/hover.mp3")
const PARRY := preload("res://assets/audio/sfx/parry.mp3")

static var sfx_counts: Dictionary = {}


static func play_attack() -> void:
	_play(ATTACK, &"attack")


static func play_click() -> void:
	_play(CLICK, &"click")


static func play_death() -> void:
	_play(DEATH, &"death")


static func play_hover() -> void:
	_play(HOVER, &"hover")


static func play_parry() -> void:
	_play(PARRY, &"parry")


static func stop_combat() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var combat: Array[AudioStream] = [ATTACK, PARRY, DEATH]
	for child in tree.root.get_children():
		var player := child as AudioStreamPlayer
		if player == null or not combat.has(player.stream):
			continue
		player.stop()
		player.queue_free()


static func count_of(key: StringName) -> int:
	return int(sfx_counts.get(key, 0))


static func bind_button(button: Button) -> void:
	if button == null or button.has_meta(&"ui_sfx_bound"):
		return
	button.set_meta(&"ui_sfx_bound", true)
	button.pressed.connect(_on_button_pressed.bind(button))
	button.mouse_entered.connect(_on_button_hover.bind(button))


static func _on_button_pressed(button: Button) -> void:
	if button == null or button.disabled:
		return
	play_click()


static func _on_button_hover(button: Button) -> void:
	if button == null or button.disabled:
		return
	play_hover()


static func _play(stream: AudioStream, key: StringName) -> void:
	if stream == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = GameSession.AUDIO_BUS_SFX
	player.stream = stream
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	sfx_counts[key] = count_of(key) + 1
