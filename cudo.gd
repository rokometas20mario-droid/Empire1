extends "res://zgradba.gd"

@export var cas_do_zmage: float = 180.0

var aktiven: bool = true


func _process(delta):

	if not aktiven:
		return

	cas_do_zmage -= delta

	get_tree().call_group("main_script", "posodobi_cudo_stevec", cas_do_zmage)

	if cas_do_zmage <= 0:
		aktiven = false
		get_tree().call_group("main_script", "igra_konec", true)
