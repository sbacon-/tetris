extends GPUParticles2D

func set_color(x: int) -> void:
	texture.region = Rect2(x*8,0,8,8)

func play() -> void:
	emitting = true
