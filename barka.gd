extends Node2D

# Majhen dekorativni čoln, ki se rahlo ziblje na vodi - brez kakršnekoli
# funkcije v igri, samo za zapolnitev praznega vodnega prostora.

var cas := 0.0
var zamik := 0.0
var izhodiscna_rotacija := 0.0


func _ready() -> void:
	zamik = randf() * TAU
	izhodiscna_rotacija = rotation


func _process(delta: float) -> void:
	cas += delta
	position.y += sin(cas * 0.7 + zamik) * 0.12
	rotation = izhodiscna_rotacija + deg_to_rad(sin(cas * 0.45 + zamik) * 4.0)
