extends Control

const SAVE_PATH = "user://savegame.json"
const VERZIJA = "v0.1"

var izbrana_tezavnost: String = "srednje"


func _ready():
	$Verzija.text = VERZIJA
	$ButtonNadaljuj.visible = FileAccess.file_exists(SAVE_PATH)
	_posodobi_tezavnost_gumbe()


func _posodobi_tezavnost_gumbe():
	$Tezavnost/ButtonLahko.modulate = Color(1, 1, 1, 1)
	$Tezavnost/ButtonSrednje.modulate = Color(1, 1, 1, 1)
	$Tezavnost/ButtonTezko.modulate = Color(1, 1, 1, 1)

	match izbrana_tezavnost:
		"lahko":
			$Tezavnost/ButtonLahko.modulate = Color(1, 1, 0.3, 1)
		"srednje":
			$Tezavnost/ButtonSrednje.modulate = Color(1, 1, 0.3, 1)
		"tezko":
			$Tezavnost/ButtonTezko.modulate = Color(1, 1, 0.3, 1)


func _on_lahko_pressed():
	izbrana_tezavnost = "lahko"
	_posodobi_tezavnost_gumbe()


func _on_srednje_pressed():
	izbrana_tezavnost = "srednje"
	_posodobi_tezavnost_gumbe()


func _on_tezko_pressed():
	izbrana_tezavnost = "tezko"
	_posodobi_tezavnost_gumbe()


func _on_nova_igra_pressed():
	GameState.nova_igra = true
	GameState.tezavnost = izbrana_tezavnost
	get_tree().change_scene_to_file("res://LoadingScreen.tscn")


func _on_nadaljuj_pressed():
	GameState.nova_igra = false
	get_tree().change_scene_to_file("res://LoadingScreen.tscn")


func _on_izhod_pressed():
	get_tree().quit()
