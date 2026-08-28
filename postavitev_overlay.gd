extends Node2D

# Namenoma LOČENO vozlišče od "Main" (glavne skripte main.gd) - glej obsežno
# opombo pri "postavitev_overlay" v main.gd. Na kratko: Main je STARŠ vseh
# zgradb/dreves/enot v igri, zato bi bilo karkoli narisano neposredno v
# Main._draw() vedno prekrito z njimi (Godot najprej nariše lastno vsebino
# starša, šele nato otroke NA VRHU). To vozlišče je namesto tega SOSED
# (sibling), ne prednik teh objektov, in ima visok z_index (glej
# main.tscn), zato se njegova risba vedno pojavi NAD vsem ostalim.

var glavni: Node = null


func _ready() -> void:
	glavni = get_parent()


func _draw() -> void:
	if glavni != null and is_instance_valid(glavni) and glavni.has_method("_narisi_postavitveni_overlay"):
		glavni._narisi_postavitveni_overlay(self)
