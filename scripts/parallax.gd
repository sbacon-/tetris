extends ParallaxBackground

@export var scroll_speed = 15.0
@export var bg_texture: CompressedTexture2D = preload("res://assets/Gray.png")
@onready var sprite = $ParallaxLayer/Sprite2D

func _ready() -> void:
	sprite.texture = bg_texture

func _process(delta: float) -> void:
	sprite.region_rect.position += Vector2(scroll_speed,scroll_speed) * delta
	if sprite.region_rect.position > Vector2(128,128):
		sprite.region_rect.position = Vector2.ZERO
