extends Node2D

var is_visible_box: bool = false
var rect_to_draw: Rect2 = Rect2()

func draw_box(p1: Vector2, p2: Vector2):
	var top_left = Vector2(min(p1.x, p2.x), min(p1.y, p2.y))
	var size = Vector2(abs(p1.x - p2.x), abs(p1.y - p2.y))
	rect_to_draw = Rect2(top_left, size)
	is_visible_box = true
	queue_redraw()

func hide_box():
	is_visible_box = false
	queue_redraw()

func _draw():
	if is_visible_box and rect_to_draw.size.length() > 10.0:
		# Svetlo moder polprosojen pravokotnik z belo obrobo
		draw_rect(rect_to_draw, Color(0.2, 0.6, 1.0, 0.35), true)
		draw_rect(rect_to_draw, Color(1, 1, 1, 1.0), false, 2.0)
		draw_rect(rect_to_draw, Color(0.0, 0.8, 1.0, 1.0), false, 1.0)
