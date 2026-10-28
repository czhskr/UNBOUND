class_name DamagePopup
extends Control

## 실제 HP가 줄어든 순간에만 숫자를 띄운다.
## 크기와 시간은 시험값이며 최종이 아니다.

const _FONT := preload("res://assets/fonts/Galmuri9.ttf")
const STAGGER: Array[float] = [-8.0, 0.0, 8.0, -4.0, 4.0]
const POPUP_LIFT := 150.0
const RISE_DISTANCE := 40.0
const POP_SECONDS := 0.10
const SETTLE_SECONDS := 0.08
const LIFE_SECONDS := 0.55
## 숫자 크기의 유일한 조정점. 시험값이며 최종이 아니다.
const DAMAGE_FONT_SIZE := 30

var _label: Label


static func mount(scene: Node) -> void:
	if scene == null or scene.get_node_or_null("DamagePopups") != null or scene.has_meta(&"_damage_popups_pending"):
		return
	scene.set_meta(&"_damage_popups_pending", true)
	var watcher := Watcher.new()
	watcher.name = "DamagePopups"
	scene.add_child.call_deferred(watcher)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = get_node_or_null("DamageLabel") as Label
	if _label == null:
		push_error("DamagePopup is missing DamageLabel.")
		return
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override(&"font", _FONT)
	_label.add_theme_font_size_override(&"font_size", DAMAGE_FONT_SIZE)
	_label.add_theme_color_override(&"font_color", Color(0.97, 0.94, 0.88, 1.0))
	_label.add_theme_color_override(&"font_outline_color", Color(0.06, 0.06, 0.08, 1.0))
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func play(amount: int, origin: Vector2) -> void:
	if _label == null:
		queue_free()
		return
	_label.text = str(amount)
	position = origin
	size = Vector2(72.0, 28.0)
	pivot_offset = size * 0.5
	scale = Vector2(0.7, 0.7)
	modulate.a = 1.0
	var motion := create_tween()
	motion.tween_property(self, "scale", Vector2(1.15, 1.15), POP_SECONDS)
	motion.tween_property(self, "scale", Vector2.ONE, SETTLE_SECONDS)
	motion.tween_property(self, "position:y", origin.y - RISE_DISTANCE, LIFE_SECONDS)
	motion.parallel().tween_property(self, "modulate:a", 0.0, LIFE_SECONDS)
	motion.chain().tween_callback(queue_free)


class Watcher extends CanvasLayer:
	var _step: int = 0
	var _enemy: CombatActor
	var _last_hp: Dictionary = {}
	var _callbacks: Dictionary = {}


	func _ready() -> void:
		layer = 18
		call_deferred("_bind_player")


	func _process(_delta: float) -> void:
		var enemy := _current_enemy()
		if is_instance_valid(_enemy) and enemy == _enemy:
			return
		if is_instance_valid(_enemy):
			_unwatch(_enemy)
		else:
			_forget_invalid()
		_enemy = enemy
		_watch(enemy)


	func _bind_player() -> void:
		var player := _find_player()
		_watch(player)


	func _watch(actor: CombatActor) -> void:
		if actor == null:
			return
		_last_hp[actor] = actor.current_hp
		if _callbacks.has(actor):
			return
		var callback := _on_health.bind(actor)
		_callbacks[actor] = callback
		actor.health_changed.connect(callback)


	func _forget_invalid() -> void:
		var stale: Array = []
		for actor in _callbacks.keys():
			if not is_instance_valid(actor):
				stale.append(actor)
		for actor in _last_hp.keys():
			if not is_instance_valid(actor) and not stale.has(actor):
				stale.append(actor)
		for actor in stale:
			_callbacks.erase(actor)
			_last_hp.erase(actor)


	func _unwatch(actor: CombatActor) -> void:
		if actor == null:
			return
		var callback: Variant = _callbacks.get(actor, null)
		if actor != null and is_instance_valid(actor) and callback is Callable and actor.health_changed.is_connected(callback):
			actor.health_changed.disconnect(callback)
		_callbacks.erase(actor)
		_last_hp.erase(actor)


	func _on_health(current_hp: int, _max_hp: int, actor: CombatActor) -> void:
		var previous := int(_last_hp.get(actor, current_hp))
		_last_hp[actor] = current_hp
		var lost := previous - current_hp
		if lost <= 0 or actor == null or not is_instance_valid(actor):
			return
		_spawn(actor, lost)


	func _spawn(actor: Node2D, amount: int) -> void:
		var packed := load("res://scenes/ui/DamagePopup.tscn") as PackedScene
		var popup := packed.instantiate() as DamagePopup
		if popup == null:
			return
		add_child(popup)
		var stagger := DamagePopup.STAGGER[_step % DamagePopup.STAGGER.size()]
		_step += 1
		popup.play(amount, _snapshot(actor) + Vector2(stagger, -DamagePopup.POPUP_LIFT))


	func _snapshot(actor: Node2D) -> Vector2:
		var motion := actor.get_node_or_null("MotionRoot") as Node2D
		var node := motion if motion != null else actor
		var canvas := node.get_global_transform_with_canvas()
		var lift := 0.0
		var visual := actor.get_node_or_null("MotionRoot/VisualRoot") as Node2D
		if visual != null:
			lift = visual.position.y
		return canvas.origin + canvas.basis_xform(Vector2(0.0, lift))


	func _find_player() -> CombatActor:
		var root := get_parent()
		if root == null:
			return null
		var player := root.get_node_or_null("World/Player") as CombatActor
		if player == null:
			player = root.get_node_or_null("Stage/Player") as CombatActor
		return player


	func _current_enemy() -> CombatActor:
		var root := get_parent()
		if root == null:
			return null
		var encounter := root.get_node_or_null("EncounterController") as EncounterController
		if encounter == null or encounter.current_enemy == null or not is_instance_valid(encounter.current_enemy):
			return null
		return encounter.current_enemy
