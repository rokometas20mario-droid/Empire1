extends Node2D

var tarca = null
var skoda: int = 1
var vir_napada = null
var hitrost: float = 610.0
var zadnja_pozicija_tarce: Vector2


func izstreli(nova_tarca, nova_skoda: int, novi_vir) -> void:
	tarca = nova_tarca
	skoda = maxi(1, nova_skoda)
	vir_napada = novi_vir
	zadnja_pozicija_tarce = tarca.global_position if is_instance_valid(tarca) else global_position
	queue_redraw()


func _process(delta: float) -> void:
	if is_instance_valid(tarca):
		zadnja_pozicija_tarce = tarca.global_position + Vector2(0.0, -16.0)
	var smer := zadnja_pozicija_tarce - global_position
	var korak := hitrost * delta
	if smer.length() <= korak:
		global_position = zadnja_pozicija_tarce
		if is_instance_valid(tarca) and tarca.has_method("take_damage"):
			tarca.take_damage(skoda, vir_napada)
		queue_free()
		return
	rotation = smer.angle()
	global_position += smer.normalized() * korak


func _draw() -> void:
	# Majhna, vendar dobro berljiva kamnita sulica. Njena smer je os +X,
	# celotno vozlišče pa se med letom obrača proti tarči.
	draw_line(Vector2(-17, 0), Vector2(12, 0), Color("#6b3f1e"), 3.0, true)
	draw_line(Vector2(-14, -1), Vector2(8, -1), Color("#b07838"), 1.0, true)
	draw_colored_polygon(
		PackedVector2Array([Vector2(12, -4), Vector2(20, 0), Vector2(12, 4), Vector2(9, 0)]),
		Color("#9aa0a0")
	)
	draw_line(Vector2(12, -3), Vector2(19, 0), Color("#d8dddd"), 1.0, true)
