extends Node2D

# Tih, ponavljajoč se valovni obroč na vodni gladini - čisto ambientalna
# dekoracija, brez kolizije ali funkcije.

var cas := 0.0
var zamik := 0.0
var trajanje := 3.2
var osnovni_polmer := 10.0
var rast_polmera := 26.0


func _ready() -> void:
	zamik = randf() * trajanje


func _process(delta: float) -> void:
	cas += delta
	queue_redraw()


func _draw() -> void:
	var t := fmod(cas + zamik, trajanje) / trajanje
	var polmer := osnovni_polmer + t * rast_polmera
	var prosojnost := 1.0 - t
	draw_arc(Vector2.ZERO, polmer, 0, TAU, 20, Color(1, 1, 1, 0.4 * prosojnost), 1.6, true)
