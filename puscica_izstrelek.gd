extends Node2D

var tarca = null
var skoda: int = 1
var vir_napada = null
var hitrost: float = 720.0
var zadnja_pozicija_tarce: Vector2


func _ready() -> void:
	add_to_group("stolp_izstrelek")


func izstreli(nova_tarca, nova_skoda: int, novi_vir) -> void:
	tarca = nova_tarca
	skoda = maxi(1, nova_skoda)
	vir_napada = novi_vir
	zadnja_pozicija_tarce = (
		tarca.global_position + Vector2(0.0, -16.0)
		if is_instance_valid(tarca)
		else global_position
	)
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
	# Lesena prazgodovinska puscica; celotno vozlisce se obraca proti tarci.
	draw_line(Vector2(-15, 0), Vector2(10, 0), Color("#704421"), 2.2, true)
	draw_line(Vector2(-13, -0.7), Vector2(8, -0.7), Color("#c58a43"), 0.8, true)
	draw_colored_polygon(
		PackedVector2Array([Vector2(9, -3), Vector2(16, 0), Vector2(9, 3), Vector2(7, 0)]),
		Color("#aaa89d")
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-15, 0), Vector2(-10, -4), Vector2(-8, 0), Vector2(-10, 4)]),
		Color("#be6e45")
	)
