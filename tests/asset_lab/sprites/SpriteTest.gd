extends Node2D

@export var animation_profile: CharacterAnimationProfile

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if animation_profile == null:
		push_error("SpriteTest has no CharacterAnimationProfile.")
		return
	sprite.sprite_frames = animation_profile.build_sprite_frames()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"idle")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				sprite.play(&"idle")
			KEY_2:
				sprite.play(&"attack")
			KEY_3:
				sprite.play(&"hit")
			KEY_4:
				sprite.play(&"death")
			KEY_5:
				sprite.play(&"run")


func _on_animation_finished() -> void:
	if sprite.animation in [&"attack", &"hit"]:
		sprite.play(&"idle")
