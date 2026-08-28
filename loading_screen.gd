extends Control

const SAVE_PATH = "user://savegame.json"

var nasveti = [
	"Delavci nabirajo počasneje kot vojaki – pošlji jih stran, če vidiš sovražnika v bližini.",
	"Vsaka zgradba potrebuje čas, da se zgradi – napredek vidiš, ko tapneš/klikneš nanjo.",
	"Vojašnico lahko zgradiš šele, ko nadgradiš glavno stavbo na 2. nivo.",
	"Poveljnik da bližnjim vojakom bonus napada, dokler je živ.",
	"Desni klik (ali tap) na sovražnika ukaže napad, na svojo poškodovano zgradbo pa popravilo.",
	"Enote same napadejo sovražnika, ki pride blizu – ni ti treba vsega ročno ukazovati.",
	"Nasprotnik prvič napade po nekaj minutah, nato periodično znova.",
	"Vrata v obzidju spustijo skozi tvoje enote, sovražnika pa ne.",
	"Izberi delavca za seznam zgradb, ki jih lahko zgradi; tapni svojo zgradbo za njene možnosti.",
	"Rally točko nastaviš v panelu vojašnice ali glavne stavbe – nove enote gredo samodejno tja.",
	"Igro lahko kadarkoli shraniš v meniju za pavzo (gumb zgoraj desno).",
]

var trenutni_indeks: int = 0
var casovnik: float = 0.0
var interval: float = 6.0


func _ready():
	nasveti.shuffle()
	_prikazi_nasvet()


func _process(delta):
	casovnik += delta
	if casovnik >= interval:
		casovnik = 0.0
		_naslednji_nasvet()


func _prikazi_nasvet():
	$NasvetLabel.text = nasveti[trenutni_indeks]


func _naslednji_nasvet():
	trenutni_indeks = (trenutni_indeks + 1) % nasveti.size()
	casovnik = 0.0
	_prikazi_nasvet()


func _prejsnji_nasvet():
	trenutni_indeks = (trenutni_indeks - 1 + nasveti.size()) % nasveti.size()
	casovnik = 0.0
	_prikazi_nasvet()


func _on_puscica_desno_pressed():
	_naslednji_nasvet()


func _on_puscica_levo_pressed():
	_prejsnji_nasvet()


func _on_nadaljuj_pressed():
	if GameState.nova_igra and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	get_tree().change_scene_to_file("res://main.tscn")
