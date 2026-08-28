extends "res://zgradba.gd"

var producing: bool = false
var current_unit_type: String = ""
var timer: float = 0.0
var production_time: float = 10.0
var production_queue: Array[String] = []
const MAX_PRODUCTION_QUEUE: int = 10


func zacni_produkcijo(tip: String):

	if v_gradnji:
		print("Vojašnica je še v gradnji")
		return

	if stevilo_narocil() >= MAX_PRODUCTION_QUEUE:
		print("Čakalna vrsta vojašnice je polna")
		return
	production_queue.append(tip)
	if not producing:
		_zacni_naslednjo()
	print("Dodano v čakalno vrsto: ", tip)


func stevilo_narocil() -> int:
	return production_queue.size() + (1 if producing else 0)


func stevilo_tipa(tip: String) -> int:
	var rezultat := 1 if producing and current_unit_type == tip else 0
	for narocilo in production_queue:
		if narocilo == tip: rezultat += 1
	return rezultat


func napredek_produkcije() -> float:
	if not producing or production_time <= 0.0: return 0.0
	return clampf(timer / production_time, 0.0, 1.0)


func _zacni_naslednjo() -> void:
	if production_queue.is_empty():
		producing = false
		current_unit_type = ""
		timer = 0.0
		return
	current_unit_type = production_queue.pop_front()
	producing = true
	timer = 0.0


func _process(delta):

	super._process(delta)

	if v_gradnji:
		return

	if producing:

		timer += delta

		if timer >= production_time:
			get_tree().call_group("main_script", "spawn_enoto", current_unit_type, global_position, self)
			producing = false
			current_unit_type = ""
			timer = 0.0
			_zacni_naslednjo()
