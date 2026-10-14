
extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				sprite.play("idle")
			KEY_2:
				sprite.play("attack")
			KEY_3:
				sprite.play("hit")
			KEY_4:
				sprite.play("death")
			KEY_5:
				sprite.play("run")

func _on_animation_finished() -> void:
	if sprite.animation in ["attack", "hit"]:
		sprite.play("idle")
