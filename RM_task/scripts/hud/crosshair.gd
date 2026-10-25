extends Control

func _draw():
	var center = Vector2.ZERO 
	var size = 10.0  # 准心线的长度
	var thickness = 2.0 # 准心线的粗细
	var color = Color(0.0, 1.0, 0.0, 0.8)


	draw_line(Vector2(-size, 0), Vector2(-3, 0), color, thickness)
	draw_line(Vector2(3, 0), Vector2(size, 0), color, thickness)
	draw_line(Vector2(0, -size), Vector2(0, -3), color, thickness)
	draw_line(Vector2(0, 3), Vector2(0, size), color, thickness)
