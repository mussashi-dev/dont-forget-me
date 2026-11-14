extends Node2D
## Piso e régua de 16 px da Sala de Comparação (cada quadrado = 1 tile).

func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 200), Color("#1d1230"))
	for x: int in range(0, 321, 16):
		draw_line(Vector2(x, 0), Vector2(x, 200), Color(1, 1, 1, 0.06))
	for y: int in range(0, 201, 16):
		draw_line(Vector2(0, y), Vector2(320, y), Color(1, 1, 1, 0.06))
	# linha do chão (150) e marcas de altura a cada tile acima dela
	draw_line(Vector2(0, 150), Vector2(320, 150), Color("#ffcf70"), 1.0)
	for i: int in range(1, 7):
		var y: float = 150.0 - i * 16.0
		draw_line(Vector2(0, y), Vector2(10, y), Color("#ffcf70"), 1.0)
