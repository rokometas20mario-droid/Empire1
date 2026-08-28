extends Node2D

# Pametnejši AI uporablja iste scene, animacije, gradnjo in boj kot igralec.
# Vsa logika v tej datoteki velja samo za vozlišča z je_ai = true.
@export var delavec_scene: PackedScene = preload("res://delavec.tscn")
@export var vojasnica_scene: PackedScene = preload("res://Vojasnica.tscn")
@export var bojevnik_scene: PackedScene = preload("res://Bojevnik.tscn")
@export var kopjenik_scene: PackedScene = preload("res://Kopjenik.tscn")
@export var teska_enota_scene: PackedScene = preload("res://TeskaEnota.tscn")
@export var poveljnik_scene: PackedScene = preload("res://Poveljnik.tscn")
@export var hisa_scene: PackedScene = preload("res://hisa.tscn")
@export var drvarnica_scene: PackedScene = preload("res://Drvarnica.tscn")
@export var kamnolom_scene: PackedScene = preload("res://Kamnolom.tscn")
@export var rudnik_scene: PackedScene = preload("res://Rudnik.tscn")
@export var kmetija_scene: PackedScene = preload("res://Kmetija.tscn")
@export var polje_scene: PackedScene = preload("res://Polje.tscn")
@export var obzidje_scene: PackedScene = preload("res://Obzidje.tscn")
@export var vrata_scene: PackedScene = preload("res://Vrata.tscn")
@export var stolp_scene: PackedScene = preload("res://Stolp.tscn")

const GLAVNA_NIVO2: Texture2D = preload("res://assets/nadgradnje/glavna_nivo2.png")
const GLAVNA_NIVO3: Texture2D = preload("res://assets/nadgradnje/glavna_nivo3.png")

const TIPI_SUROVIN: Array[String] = ["FOOD", "WOOD", "STONE", "GOLD"]
const TIP_VIRA: Dictionary = {"WOOD": 0, "STONE": 1, "GOLD": 2, "FOOD": 3}
const TIP_ODDAJNE_STAVBE: Dictionary = {
	"WOOD": "drvarnica", "STONE": "kamnolom", "GOLD": "rudnik", "FOOD": "kmetija"
}
const SCENE_ODDAJNIH_STAVB: Dictionary = {
	"WOOD": preload("res://Drvarnica.tscn"),
	"STONE": preload("res://Kamnolom.tscn"),
	"GOLD": preload("res://Rudnik.tscn"),
	"FOOD": preload("res://Kmetija.tscn"),
}
const CENA_ODDAJNE_STAVBE: Dictionary = {"WOOD": 50}
const CENA_HISE: Dictionary = {"WOOD": 50}
const CENA_POLJA: Dictionary = {"WOOD": 40}
const CENA_VOJASNICE: Dictionary = {"STONE": 50}
const CENA_STOLPA: Dictionary = {"WOOD": 60, "STONE": 40}
const CENA_ZIDU: Dictionary = {"WOOD": 20, "STONE": 15}

const CENE_GLAVNE: Dictionary = {
	2: {"WOOD": 100, "STONE": 60},
	3: {"WOOD": 150, "STONE": 100},
}
const CASI_GLAVNE: Dictionary = {2: 30.0, 3: 45.0}
const CENE_VOJASNICE: Dictionary = {
	2: {"STONE": 80, "WOOD": 40},
	3: {"STONE": 120, "WOOD": 60},
}
const CASI_VOJASNICE: Dictionary = {2: 20.0, 3: 30.0}
const CENE_STOLPA: Dictionary = {
	2: {"WOOD": 150, "STONE": 120},
	3: {"WOOD": 250, "STONE": 200},
}
const CASI_STOLPA: Dictionary = {2: 15.0, 3: 25.0}
const CENE_OBZIDJA: Dictionary = {
	2: {"WOOD": 150, "STONE": 100},
	3: {"WOOD": 250, "STONE": 180},
}
const CASI_OBZIDJA: Dictionary = {2: 12.0, 3: 20.0}

const HP_GLAVNE: Dictionary = {1: 500, 2: 700, 3: 950}
const HP_VOJASNICE: Dictionary = {1: 250, 2: 350, 3: 500}
const HP_STOLPA: Dictionary = {1: 150, 2: 250, 3: 400}
const SKODA_STOLPA: Dictionary = {1: 15, 2: 25, 3: 40}
const DOSEG_STOLPA: Dictionary = {1: 200.0, 2: 250.0, 3: 300.0}
const HP_OBZIDJA: Dictionary = {1: 100, 2: 200, 3: 350}

const ZID_KORAK_A: Vector2 = Vector2(128.0, -64.0)
const ZID_KORAK_B: Vector2 = Vector2(128.0, 64.0)
# Obrambni obroč je na kopenski strani baze; obarvana ploščad in bližnja obala
# ostaneta prosti. Desna stran baze zato uporablja obalo kot naravno zaščito.
const OBRAMBNI_POLMER_MREZE: int = 3
const NAJVEC_GRADBENIKOV: int = 2
const OSNOVNA_AI_POPULACIJA: int = 5
const POPULACIJA_NA_HISO: int = 5
const NAJVEC_HIS: int = 6
const NAJVEC_POLJ: int = 5

var ai_resources: Dictionary = {"WOOD": 0, "STONE": 0, "GOLD": 0, "FOOD": 0}
var ai_baza_pozicija: Vector2 = Vector2.ZERO
var ai_baza = null
var vojasnica_ref = null
var aktivno_gradbisce = null
var aktivna_nadgradnja = null

var ai_pavziran: bool = false
var preteceni_cas: float = 0.0
var delavci_tick: float = 0.0
var gradnja_tick: float = 0.0
var boj_tick: float = 0.0
var timer_izdelave_delavca: float = 0.0
var timer_izdelave_enote: float = 0.0
var cas_do_napada: float = 180.0
var napad_interval: float = 120.0

var max_stevilo_delavcev: int = 10
var max_stevilo_enot: int = 20
var cas_izdelave_delavca: float = 7.0
var cas_izdelave_enote: float = 10.0
var najmanjsi_napadalni_odred: int = 6
var stevilo_delavcev_start: int = 3
var izdelane_enote: int = 0
var spawn_indeks: int = 0

var napadalni_odred: Array = []
var trenutna_napadalna_tarca = null
var obrambni_center: Vector2 = Vector2.ZERO
var obzidje_nacrt: Array[Dictionary] = []
var obzidje_indeks: int = 0
var poruseni_zidovi: Array[Dictionary] = []
var stolp_koti: Array[Vector2] = []


func _ready() -> void:
	add_to_group("ai_controller")
	_nastavi_tezavnost()

	ai_baza = get_tree().get_first_node_in_group("ai_baza")
	if is_instance_valid(ai_baza):
		ai_baza_pozicija = ai_baza.global_position
		ai_baza.tip_zgradbe = "glavna"
		ai_baza.tekstura_nivo2_jug = GLAVNA_NIVO2
		ai_baza.tekstura_nivo3_jug = GLAVNA_NIVO3
		ai_baza.prikazi_nivo(maxi(1, int(ai_baza.nivo_zgradbe)))
		print("AI: baza najdena na ", ai_baza_pozicija)
	else:
		push_error("AI: baza ni najdena")
		return

	# Obrambni pas je pomaknjen proti notranjosti otoka, da AI na kopenski
	# strani zgradi zidove, vrata in stolpe, obarvana ploščad pa ostane prosta.
	obrambni_center = ai_baza_pozicija + Vector2(-220.0, 0.0)
	_pripravi_obzidje_nacrt()

	for i in range(stevilo_delavcev_start):
		call_deferred("_ustvari_delavca")


func _nastavi_tezavnost() -> void:
	match GameState.tezavnost:
		"lahko":
			cas_do_napada = 300.0
			napad_interval = 180.0
			max_stevilo_delavcev = 8
			max_stevilo_enot = 14
			cas_izdelave_delavca = 10.0
			cas_izdelave_enote = 13.0
			najmanjsi_napadalni_odred = 5
		"tezko":
			cas_do_napada = 90.0
			napad_interval = 70.0
			max_stevilo_delavcev = 12
			max_stevilo_enot = 28
			cas_izdelave_delavca = 5.0
			cas_izdelave_enote = 7.5
			najmanjsi_napadalni_odred = 7
		_:
			cas_do_napada = 180.0
			napad_interval = 120.0
			max_stevilo_delavcev = 10
			max_stevilo_enot = 20
			cas_izdelave_delavca = 7.0
			cas_izdelave_enote = 10.0
			najmanjsi_napadalni_odred = 6


func _process(delta: float) -> void:
	if ai_pavziran or not is_instance_valid(ai_baza):
		return

	preteceni_cas += delta
	delavci_tick += delta
	gradnja_tick += delta
	boj_tick += delta
	cas_do_napada -= delta

	if delavci_tick >= 0.75:
		delavci_tick = 0.0
		_dodeli_proste_delavce()

	_gradnja_in_produkcija(delta)

	if gradnja_tick >= 1.5:
		gradnja_tick = 0.0
		_nacrtuj_gradnjo_in_nadgradnje()

	if boj_tick >= 0.75:
		boj_tick = 0.0
		_preveri_obrambo()
		_posodobi_napadalni_odred()

	if cas_do_napada <= 0.0:
		_poslji_napad()


func add_ai_resource(tip: String, amount: int) -> void:
	if tip in ai_resources:
		ai_resources[tip] += amount


func ai_enota_umrla(_cena: int) -> void:
	_ocisti_napadalni_odred()


func ai_nivo_baze() -> int:
	return int(ai_baza.nivo_zgradbe) if is_instance_valid(ai_baza) else 1


func ai_nivo_vojasnice() -> int:
	var najboljsi := 1
	for stavba in _ai_zgradbe_tipa("vojasnica", true):
		najboljsi = maxi(najboljsi, int(stavba.nivo_zgradbe))
	return najboljsi


func _ai_delavci() -> Array:
	var rezultat: Array = []
	for delavec in get_tree().get_nodes_in_group("ai_delavci"):
		if is_instance_valid(delavec):
			rezultat.append(delavec)
	return rezultat


func _ai_enote() -> Array:
	var rezultat: Array = []
	for enota in get_tree().get_nodes_in_group("ai_enote"):
		if is_instance_valid(enota):
			rezultat.append(enota)
	return rezultat


func _ai_zgradbe_tipa(tip: String, samo_dokoncane: bool = false) -> Array:
	var rezultat: Array = []
	for stavba in get_tree().get_nodes_in_group("ai_zgradbe"):
		if not is_instance_valid(stavba) or not ("tip_zgradbe" in stavba):
			continue
		if str(stavba.tip_zgradbe) != tip:
			continue
		if samo_dokoncane and "v_gradnji" in stavba and bool(stavba.v_gradnji):
			continue
		rezultat.append(stavba)
	return rezultat


func _ustvari_delavca() -> void:
	if not is_instance_valid(ai_baza) or delavec_scene == null:
		return
	var nov = delavec_scene.instantiate()
	nov.je_ai = true
	var kot := float(spawn_indeks) * 2.39996
	var polmer := 170.0 + float(spawn_indeks % 3) * 24.0
	spawn_indeks += 1
	nov.global_position = ai_baza_pozicija + Vector2(cos(kot), sin(kot)) * polmer
	get_parent().add_child(nov)
	nov.call_deferred("_prevzemi_nadgradnje")


func _gradnja_in_produkcija(delta: float) -> void:
	var delavci := _ai_delavci()
	if delavci.size() < max_stevilo_delavcev:
		timer_izdelave_delavca += delta
		if timer_izdelave_delavca >= cas_izdelave_delavca and ai_resources["FOOD"] >= 10 and _ai_prosta_populacija() >= 1:
			ai_resources["FOOD"] -= 10
			timer_izdelave_delavca = 0.0
			_ustvari_delavca()
	else:
		timer_izdelave_delavca = 0.0

	_osvezi_vojasnico_ref()
	if not is_instance_valid(vojasnica_ref) or bool(vojasnica_ref.v_gradnji):
		timer_izdelave_enote = 0.0
		return
	if _ai_enote().size() >= _vojaska_meja():
		timer_izdelave_enote = 0.0
		return

	timer_izdelave_enote += delta
	if timer_izdelave_enote >= cas_izdelave_enote:
		if _poskusi_izdelati_enoto():
			timer_izdelave_enote = 0.0


func _vojaska_meja() -> int:
	var meja := max_stevilo_enot
	meja = mini(meja, 10 + ai_nivo_baze() * 5 + ai_nivo_vojasnice() * 4)
	return meja


func _ai_porabljena_populacija() -> int:
	var porabljena := _ai_delavci().size()
	for enota in _ai_enote():
		if "populacija_cena" in enota:
			porabljena += maxi(1, int(enota.populacija_cena))
		else:
			porabljena += 1
	return porabljena


func _ai_max_populacija() -> int:
	var dokoncane_hise := _ai_zgradbe_tipa("hisa", true).size()
	return OSNOVNA_AI_POPULACIJA + dokoncane_hise * POPULACIJA_NA_HISO


func _ai_prosta_populacija() -> int:
	return maxi(0, _ai_max_populacija() - _ai_porabljena_populacija())


func _potrebuje_ai_hiso() -> bool:
	if _ai_zgradbe_tipa("hisa").size() >= NAJVEC_HIS:
		return false
	# Pet prostih mest pomeni, da je mogoče izdelati tudi najdražjo težko
	# enoto. Ko rezerve ni več, AI pravočasno začne naslednjo hišo.
	return _ai_prosta_populacija() < 5


func _poskusi_izdelati_enoto() -> bool:
	var nivo_baze := ai_nivo_baze()
	var nivo_vojasnice := ai_nivo_vojasnice()
	var scena: PackedScene = bojevnik_scene
	var cena: Dictionary = {"FOOD": 20, "WOOD": 10}
	var potrebna_populacija := 1

	var ima_poglavarja := false
	for poveljnik in get_tree().get_nodes_in_group("poveljniki"):
		if is_instance_valid(poveljnik) and "je_ai" in poveljnik and bool(poveljnik.je_ai):
			ima_poglavarja = true
			break

	if nivo_baze >= 3 and not ima_poglavarja and ai_resources["GOLD"] >= 30:
		scena = poveljnik_scene
		cena = {"FOOD": 60, "WOOD": 40, "GOLD": 30}
		potrebna_populacija = 3
	elif nivo_vojasnice >= 3 and izdelane_enote % 5 == 4:
		scena = teska_enota_scene
		cena = {"FOOD": 45, "WOOD": 23}
		potrebna_populacija = 5
	elif nivo_vojasnice >= 2 and izdelane_enote % 3 == 2:
		scena = kopjenik_scene
		cena = {"FOOD": 35, "WOOD": 20}
		potrebna_populacija = 2

	if _ai_prosta_populacija() < potrebna_populacija or not _ima_surovine(cena):
		return false
	_odstej_surovine(cena)

	var nova = scena.instantiate()
	nova.je_ai = true
	nova.global_position = _naslednja_spawn_pozicija()
	get_parent().add_child(nova)
	if nova.has_method("uporabi_nadgradnje"):
		nova.uporabi_nadgradnje(nivo_baze, nivo_vojasnice)
	izdelane_enote += 1
	return true


func _naslednja_spawn_pozicija() -> Vector2:
	var izvor: Vector2 = vojasnica_ref.global_position if is_instance_valid(vojasnica_ref) else ai_baza_pozicija
	var indeks := _ai_enote().size()
	var obroc := 1 + indeks / 8
	var kot := float(indeks % 8) * TAU / 8.0
	return izvor + Vector2(cos(kot), sin(kot)) * (95.0 + 38.0 * float(obroc))


func _dodeli_proste_delavce() -> void:
	var delavci := _ai_delavci()
	if delavci.is_empty():
		return

	_zagotovi_gradbenike(delavci)
	var prosti: Array = []
	for delavec in delavci:
		if str(delavec.state) == "IDLE":
			prosti.append(delavec)
	if prosti.is_empty():
		return

	var popravilo = _najdi_poskodovano_ai_stavbo()
	if is_instance_valid(popravilo):
		var serviser = _najblizje_vozlisce(prosti, popravilo.global_position)
		if is_instance_valid(serviser):
			serviser.ukazi_popravilo(popravilo)
			prosti.erase(serviser)

	var aktivni_po_tipu := _stevilo_delavcev_po_surovini(delavci)
	for delavec in prosti:
		var tip := _izberi_tip_surovine(aktivni_po_tipu, delavci.size())
		if tip == "FOOD" and _stevilo_lovcev(delavci) < 2:
			var zival = _najdi_zival_za_lov(delavec.global_position)
			if is_instance_valid(zival):
				delavec.ukazi_lov(zival)
				aktivni_po_tipu["FOOD"] += 1
				continue

		var vir = _najdi_vir_tipa(delavec.global_position, tip)
		if not is_instance_valid(vir):
			for rezervni_tip in TIPI_SUROVIN:
				vir = _najdi_vir_tipa(delavec.global_position, rezervni_tip)
				if is_instance_valid(vir):
					tip = rezervni_tip
					break
		if is_instance_valid(vir):
			delavec.start_mining(vir)
			aktivni_po_tipu[tip] += 1


func _stevilo_delavcev_po_surovini(delavci: Array) -> Dictionary:
	var rezultat: Dictionary = {"WOOD": 0, "STONE": 0, "GOLD": 0, "FOOD": 0}
	for delavec in delavci:
		if str(delavec.state) == "HUNTING":
			rezultat["FOOD"] += 1
			continue
		var vir = delavec.target_resource
		if is_instance_valid(vir) and "resource_type" in vir:
			var tip := _ime_surovine(int(vir.resource_type))
			rezultat[tip] += 1
	return rezultat


func _izberi_tip_surovine(aktivni: Dictionary, stevilo_delavcev: int) -> String:
	var delezi: Dictionary = {"WOOD": 0.30, "STONE": 0.28, "FOOD": 0.34, "GOLD": 0.08}
	if ai_nivo_baze() < 2:
		delezi["WOOD"] = 0.34
		delezi["STONE"] = 0.33
		delezi["FOOD"] = 0.33
		delezi["GOLD"] = 0.0

	var rezerve: Dictionary = {
		"WOOD": 180.0, "STONE": 150.0, "FOOD": 130.0 + float(_ai_enote().size()) * 5.0,
		"GOLD": 60.0
	}
	var najboljsi := "WOOD"
	var najboljsa_ocena := INF
	for tip in TIPI_SUROVIN:
		var delez := float(delezi[tip])
		if delez <= 0.0:
			continue
		var cilj_delavcev := maxf(1.0, float(stevilo_delavcev) * delez)
		var zasedenost := float(aktivni[tip]) / cilj_delavcev
		var zaloga := float(ai_resources[tip]) / maxf(1.0, float(rezerve[tip]))
		var ocena := zasedenost + zaloga * 0.45
		if ocena < najboljsa_ocena:
			najboljsa_ocena = ocena
			najboljsi = tip
	return najboljsi


func _ime_surovine(tip: int) -> String:
	match tip:
		1: return "STONE"
		2: return "GOLD"
		3: return "FOOD"
		_: return "WOOD"


func _najdi_vir_tipa(pos: Vector2, tip: String):
	var najblizji = null
	var najboljsa_ocena := INF
	var iskani_tip := int(TIP_VIRA[tip])
	for vir in get_tree().get_nodes_in_group("viri"):
		if not is_instance_valid(vir) or not ("resource_type" in vir):
			continue
		if int(vir.resource_type) != iskani_tip:
			continue
		if "resource_amount" in vir and int(vir.resource_amount) <= 0:
			continue
		var zasedenost := _koliko_delavcev_na_cilju(vir)
		var ocena := pos.distance_to(vir.global_position) + float(zasedenost) * 260.0
		if ocena < najboljsa_ocena:
			najboljsa_ocena = ocena
			najblizji = vir
	return najblizji


func _koliko_delavcev_na_cilju(cilj) -> int:
	var stevilo := 0
	for delavec in _ai_delavci():
		if delavec.target_resource == cilj or delavec.hunt_target == cilj:
			stevilo += 1
	return stevilo


func _stevilo_lovcev(delavci: Array) -> int:
	var stevilo := 0
	for delavec in delavci:
		if str(delavec.state) == "HUNTING":
			stevilo += 1
	return stevilo


func _najdi_zival_za_lov(pos: Vector2):
	var najblizja = null
	var najboljsa_ocena := INF
	for zival in get_tree().get_nodes_in_group("zivali"):
		if not is_instance_valid(zival) or ("mrtva" in zival and bool(zival.mrtva)):
			continue
		# Posamezen delavec lahko varno upleni jelena, merjasec in pragovedo pa
		# ga v neposrednem boju ubijeta. Ne pošiljamo osamljenega lovca v
		# samomor; nevarne živali bo pozneje lahko napadla vojaška skupina.
		if "damage" in zival and int(zival.damage) > 0:
			continue
		var nevarnost := 0.0
		if "vrsta_zivali" in zival:
			match str(zival.vrsta_zivali):
				"divji_prasic": nevarnost = 120.0
				"pragovedo": nevarnost = 280.0
		var razdalja := pos.distance_to(zival.global_position)
		if razdalja > 1100.0:
			continue
		var ocena := razdalja + nevarnost + float(_koliko_delavcev_na_cilju(zival)) * 350.0
		if ocena < najboljsa_ocena:
			najboljsa_ocena = ocena
			najblizja = zival
	return najblizja


func _najdi_poskodovano_ai_stavbo():
	var rezultat = null
	var najnizji_delez := 0.82
	for stavba in get_tree().get_nodes_in_group("ai_zgradbe"):
		if not is_instance_valid(stavba) or bool(stavba.v_gradnji) or int(stavba.max_hp) <= 0:
			continue
		var delez := float(stavba.hp) / float(stavba.max_hp)
		if delez < najnizji_delez:
			najnizji_delez = delez
			rezultat = stavba
	return rezultat


func _najblizje_vozlisce(seznam: Array, pos: Vector2):
	var rezultat = null
	var razdalja := INF
	for vozlisce in seznam:
		if is_instance_valid(vozlisce):
			var d: float = vozlisce.global_position.distance_to(pos)
			if d < razdalja:
				razdalja = d
				rezultat = vozlisce
	return rezultat


func _zagotovi_gradbenike(delavci: Array) -> void:
	if not is_instance_valid(aktivno_gradbisce) or not bool(aktivno_gradbisce.v_gradnji):
		aktivno_gradbisce = null
		return
	var gradbeniki := 0
	for delavec in delavci:
		if str(delavec.state) == "GRADI" and delavec.gradnja_target == aktivno_gradbisce:
			gradbeniki += 1
	if gradbeniki >= NAJVEC_GRADBENIKOV:
		return

	var kandidati: Array = []
	for delavec in delavci:
		if int(delavec.carried_amount) > 0:
			continue
		if str(delavec.state) in ["IDLE", "WALKING_TO_RES"]:
			kandidati.append(delavec)
	kandidati.sort_custom(func(a, b): return a.global_position.distance_to(aktivno_gradbisce.global_position) < b.global_position.distance_to(aktivno_gradbisce.global_position))
	for delavec in kandidati:
		delavec.ukazi_gradnja(aktivno_gradbisce)
		gradbeniki += 1
		if gradbeniki >= NAJVEC_GRADBENIKOV:
			break


func _nacrtuj_gradnjo_in_nadgradnje() -> void:
	if is_instance_valid(aktivno_gradbisce) and bool(aktivno_gradbisce.v_gradnji):
		return
	aktivno_gradbisce = null
	if is_instance_valid(aktivna_nadgradnja) and bool(aktivna_nadgradnja.v_nadgradnji):
		return
	aktivna_nadgradnja = null

	# Najprej osnovno gospodarstvo, nato tehnološki razvoj in vojska.
	for tip in ["WOOD", "STONE", "FOOD"]:
		if _ai_zgradbe_tipa(str(TIP_ODDAJNE_STAVBE[tip])).is_empty():
			if _poskusi_zgraditi_oddajno_stavbo(tip):
				return

	# Prvo polje nastane takoj ob prvi dokončani kmetiji. S tem kmetija ni
	# samo skladišče hrane, ampak ima vidno njivo, kmeta in reden pridelek.
	if _ai_zgradbe_tipa("polje").is_empty() and not _ai_zgradbe_tipa("kmetija", true).is_empty():
		if _poskusi_zgraditi_polje():
			return

	# Hiše so pravi pogoj za nove delavce in vojake. AI jih postavi vnaprej,
	# ko nima več prostora za naslednjo večjo enoto, ne šele ko že obstane.
	if _potrebuje_ai_hiso():
		if _poskusi_zgraditi("hisa", hisa_scene, CENA_HISE):
			return

	if ai_nivo_baze() < 2:
		if _poskusi_nadgraditi(ai_baza, CENE_GLAVNE, CASI_GLAVNE):
			return
		# To je ključna tehnološka stopnja. Če še ni dovolj surovin, jih AI
		# prihrani namesto da bi jih sproti zapravljal za širitev.
		return

	if ai_nivo_baze() >= 2 and _ai_zgradbe_tipa("vojasnica").is_empty():
		if _poskusi_zgraditi("vojasnica", vojasnica_scene, CENA_VOJASNICE):
			return
		return

	if ai_nivo_baze() >= 2 and _ai_zgradbe_tipa("rudnik").is_empty():
		if _poskusi_zgraditi_oddajno_stavbo("GOLD"):
			return
		return

	_osvezi_vojasnico_ref()
	if is_instance_valid(vojasnica_ref) and ai_nivo_vojasnice() < mini(3, ai_nivo_baze()):
		if _poskusi_nadgraditi(vojasnica_ref, CENE_VOJASNICE, CASI_VOJASNICE):
			return
		return

	if ai_nivo_baze() < 3 and is_instance_valid(vojasnica_ref):
		if _poskusi_nadgraditi(ai_baza, CENE_GLAVNE, CASI_GLAVNE):
			return
		return

	# Po razvoju jedra AI postopoma zapre bazo z obzidjem in vrati.
	if ai_nivo_baze() >= 2 and is_instance_valid(vojasnica_ref):
		if _poskusi_obnoviti_porusen_zid():
			return
		if obzidje_indeks < obzidje_nacrt.size() and _poskusi_naslednji_zid():
			return

	var zeljeni_stolpi := 1
	if obzidje_indeks >= obzidje_nacrt.size() / 2:
		zeljeni_stolpi = 2
	if obzidje_indeks >= obzidje_nacrt.size():
		zeljeni_stolpi = 4
	if _ai_zgradbe_tipa("stolp").size() < zeljeni_stolpi:
		if _poskusi_zgraditi_stolp():
			return

	# Širjenje gospodarstva: do tri stavbe vsake vrste glede na čas in delavce.
	var zeljeno_oddajnih := 1
	if preteceni_cas >= 150.0 and _ai_delavci().size() >= 7:
		zeljeno_oddajnih = 2
	if preteceni_cas >= 300.0 and _ai_delavci().size() >= 9:
		zeljeno_oddajnih = 3
	for tip in ["WOOD", "STONE", "FOOD", "GOLD"]:
		if _ai_zgradbe_tipa(str(TIP_ODDAJNE_STAVBE[tip])).size() < zeljeno_oddajnih:
			if _poskusi_zgraditi_oddajno_stavbo(tip):
				return

	var zeljena_polja := mini(NAJVEC_POLJ, _ai_zgradbe_tipa("kmetija", true).size() * 2)
	if ai_nivo_baze() < 2:
		zeljena_polja = mini(1, zeljena_polja)
	elif ai_nivo_baze() < 3:
		zeljena_polja = mini(3, zeljena_polja)
	if _ai_zgradbe_tipa("polje").size() < zeljena_polja:
		if _poskusi_zgraditi_polje():
			return

	var ciljna_populacija := max_stevilo_delavcev + max_stevilo_enot + 5
	var zeljene_hise := int(ceil(float(maxi(0, ciljna_populacija - OSNOVNA_AI_POPULACIJA)) / float(POPULACIJA_NA_HISO)))
	zeljene_hise = mini(NAJVEC_HIS, zeljene_hise)
	if _ai_zgradbe_tipa("hisa").size() < zeljene_hise:
		if _poskusi_zgraditi("hisa", hisa_scene, CENA_HISE):
			return

	# Nato se nadgradi vsak stolp, vrata in vsak segment obzidja.
	for tip in ["stolp", "vrata", "obzidje"]:
		for stavba in _ai_zgradbe_tipa(tip, true):
			if int(stavba.nivo_zgradbe) >= 3:
				continue
			var cene: Dictionary = CENE_STOLPA if tip == "stolp" else CENE_OBZIDJA
			var casi: Dictionary = CASI_STOLPA if tip == "stolp" else CASI_OBZIDJA
			if _poskusi_nadgraditi(stavba, cene, casi):
				return


func _poskusi_zgraditi_oddajno_stavbo(tip: String) -> bool:
	var scena: PackedScene = SCENE_ODDAJNIH_STAVB[tip]
	return _poskusi_zgraditi(str(TIP_ODDAJNE_STAVBE[tip]), scena, CENA_ODDAJNE_STAVBE, tip)


func _poskusi_zgraditi(tip: String, scena: PackedScene, cena: Dictionary, vir_tip: String = "") -> bool:
	if scena == null or not _ima_surovine(cena):
		return false
	var pos = _najdi_pozicijo_za_stavbo(tip, scena, vir_tip)
	if pos == null:
		return false
	_odstej_surovine(cena)

	var nova = scena.instantiate()
	nova.je_ai = true
	nova.global_position = pos
	var smer := "sever" if pos.y < ai_baza_pozicija.y else "jug"
	if nova.has_method("nastavi_smer"):
		nova.nastavi_smer(smer)
	get_parent().add_child(nova)
	if nova.has_method("prikazi_nivo"):
		nova.prikazi_nivo(1)
	if "v_gradnji" in nova and bool(nova.v_gradnji):
		aktivno_gradbisce = nova
	_zahtevaj_navigacijo()
	print("AI: gradi ", tip, " na ", pos)
	return true


func _najdi_pozicijo_za_stavbo(tip: String, scena: PackedScene, vir_tip: String = ""):
	var sredisce := obrambni_center + Vector2(-260.0, 0.0)
	if vir_tip != "":
		var vir = _najdi_vir_za_novo_stavbo(vir_tip, tip)
		if is_instance_valid(vir):
			var proti_bazi: Vector2 = ai_baza_pozicija - vir.global_position
			if proti_bazi.length_squared() < 1.0:
				proti_bazi = Vector2.RIGHT
			# Kmetija potrebuje širši pas za štiri njive; zato stoji dlje od
			# naravnega vira hrane kot navadna oddajna stavba od svojega vira.
			var odmik_od_vira := 560.0 if tip == "kmetija" else 320.0
			sredisce = vir.global_position + proti_bazi.normalized() * odmik_od_vira
	elif tip == "vojasnica":
		# Vojašnica je v notranjosti utrdbe, vendar na svojem vojaškem delu.
		sredisce = obrambni_center + Vector2(-260.0, 0.0)
	elif tip == "hisa":
		var indeks := _ai_zgradbe_tipa("hisa").size()
		var stanovanjska_mesta: Array[Vector2] = [
			Vector2(-80.0, -230.0), Vector2(170.0, -210.0),
			Vector2(-80.0, 230.0), Vector2(170.0, 210.0),
			Vector2(-390.0, -210.0), Vector2(-390.0, 210.0),
		]
		sredisce = obrambni_center + stanovanjska_mesta[indeks % stanovanjska_mesta.size()]

	var zamik_kota := float(abs(hash(tip)) % 360) * PI / 180.0
	# Če je bližnja notranjost že zapolnjena ali rezervirana za vrata, AI išče
	# tudi širše po kopenski strani. To je posebej pomembno za poznejše hiše,
	# da se razvoj ne ustavi zaradi pomanjkanja populacije.
	for obroc in range(0, 22):
		var polmer := float(obroc) * 150.0
		var stevilo := 1 if obroc == 0 else 16
		for i in range(stevilo):
			var kot := zamik_kota + float(i) * TAU / float(stevilo)
			var kandidat := sredisce + Vector2(cos(kot), sin(kot)) * polmer
			kandidat = _zaokrozi_na_mrezo(kandidat)
			if kandidat.distance_to(ai_baza_pozicija) < 230.0:
				continue
			if _je_na_obrambnem_pas(kandidat):
				continue
			if not _ima_ai_razmik(kandidat, tip):
				continue
			if tip == "kmetija" and not _ima_prostor_za_polje(kandidat):
				continue
			if _pozicija_veljavna(kandidat, scena, "jug", false, tip):
				return kandidat
	return null


func _najdi_vir_za_novo_stavbo(vir_tip: String, tip_stavbe: String):
	var najboljsi = null
	var najboljsa_ocena := INF
	var iskani_tip := int(TIP_VIRA[vir_tip])
	var obstojece := _ai_zgradbe_tipa(tip_stavbe)
	for vir in get_tree().get_nodes_in_group("viri"):
		if not is_instance_valid(vir) or not ("resource_type" in vir):
			continue
		if int(vir.resource_type) != iskani_tip:
			continue
		if "resource_amount" in vir and int(vir.resource_amount) <= 0:
			continue
		var ocena := ai_baza_pozicija.distance_to(vir.global_position)
		# Vsaka naslednja stavba iste vrste išče drugo skupino virov. Velika
		# kazen prepreči tri drvarnice ali rudnike na istem kupu.
		for stavba in obstojece:
			var razdalja: float = stavba.global_position.distance_to(vir.global_position)
			if razdalja < 850.0:
				ocena += 2400.0 + (850.0 - razdalja) * 4.0
		if ocena < najboljsa_ocena:
			najboljsa_ocena = ocena
			najboljsi = vir
	return najboljsi


func _ima_ai_razmik(pos: Vector2, tip: String) -> bool:
	var minimalni_razmik := 300.0
	match tip:
		"hisa": minimalni_razmik = 250.0
		"kmetija": minimalni_razmik = 390.0
		"vojasnica": minimalni_razmik = 340.0
		"drvarnica", "kamnolom", "rudnik": minimalni_razmik = 320.0
	for stavba in get_tree().get_nodes_in_group("ai_zgradbe"):
		if not is_instance_valid(stavba) or not ("tip_zgradbe" in stavba):
			continue
		var obstojeci_tip := str(stavba.tip_zgradbe)
		if obstojeci_tip in ["obzidje", "vrata", "stolp"]:
			continue
		var zahtevan := minimalni_razmik
		if obstojeci_tip == "polje":
			zahtevan = 270.0
		if obstojeci_tip != tip:
			zahtevan = minf(zahtevan, 270.0)
		if pos.distance_to(stavba.global_position) < zahtevan:
			return false
	return true


func _ima_prostor_za_polje(kmetija_pos: Vector2) -> bool:
	for kandidat in _predvidene_polje_pozicije(kmetija_pos):
		if _polje_pozicija_prosta(kandidat, null, kmetija_pos):
			return true
	return false


func _predvidene_polje_pozicije(kmetija_pos: Vector2) -> Array[Vector2]:
	# Enaki odmiki kot obroč igralčevih štirih polj ob dejanski grafiki.
	return [
		kmetija_pos + Vector2(-268.0, 0.0),
		kmetija_pos + Vector2(268.0, 0.0),
		kmetija_pos + Vector2(0.0, -172.0),
		kmetija_pos + Vector2(0.0, 172.0),
	]


func _je_na_obrambnem_pas(pos: Vector2) -> bool:
	# Vrata so širša in morajo ostati uporabna, zato njihovo dejansko mesto
	# posebej rezerviramo. Navadni zidovi še naprej uporabljajo spodnji ožji
	# pas, da AI-ju ne odvzamemo prostora za hiše, kmetije in vojašnico.
	for podatek in obzidje_nacrt:
		if str(podatek["tip"]) == "vrata" and pos.distance_to(Vector2(podatek["pozicija"])) < 260.0:
			return true
	var lokalno := pos - obrambni_center
	var gx := lokalno.x / 256.0 - lokalno.y / 128.0
	var gy := lokalno.x / 256.0 + lokalno.y / 128.0
	var rob := maxf(abs(gx), abs(gy))
	return abs(rob - float(OBRAMBNI_POLMER_MREZE)) < 0.75


func _zaokrozi_na_mrezo(pos: Vector2) -> Vector2:
	var main = get_tree().get_first_node_in_group("main_script")
	if is_instance_valid(main) and main.has_method("_zaokrozi_na_mrezo"):
		return main._zaokrozi_na_mrezo(pos)
	return Vector2(round(pos.x / 110.0) * 110.0, round(pos.y / 110.0) * 110.0)


func _poskusi_zgraditi_polje() -> bool:
	if polje_scene == null or not _ima_surovine(CENA_POLJA):
		return false
	var kmetije := _ai_zgradbe_tipa("kmetija", true)
	# Najprej zapolni kmetijo z najmanj njivami, zato ima vsaka gospodarska
	# cona svojo proizvodnjo hrane, namesto vseh polj ob eni sami stavbi.
	kmetije.sort_custom(func(a, b): return _stevilo_polj_ob_kmetiji(a) < _stevilo_polj_ob_kmetiji(b))
	for kmetija in kmetije:
		var kandidati: Array = []
		var main = get_tree().get_first_node_in_group("main_script")
		if is_instance_valid(main) and main.has_method("_polje_obroc_pozicije"):
			kandidati = main._polje_obroc_pozicije(kmetija)
		else:
			kandidati.assign(_predvidene_polje_pozicije(kmetija.global_position))
		# Polja bližje AI-bazi so varnejša in ne širijo kmetijske cone po
		# nepotrebnem proti zunanjemu robu zemljevida.
		kandidati.sort_custom(func(a, b): return a.distance_to(ai_baza_pozicija) < b.distance_to(ai_baza_pozicija))
		for kandidat in kandidati:
			if not _polje_pozicija_prosta(kandidat, kmetija):
				continue
			_odstej_surovine(CENA_POLJA)
			var novo_polje = polje_scene.instantiate()
			novo_polje.je_ai = true
			novo_polje.global_position = kandidat
			get_parent().add_child(novo_polje)
			print("AI: gradi polje ob kmetiji na ", kandidat)
			return true
	return false


func _stevilo_polj_ob_kmetiji(kmetija) -> int:
	var stevilo := 0
	for polje in _ai_zgradbe_tipa("polje"):
		if polje.global_position.distance_to(kmetija.global_position) < 430.0:
			stevilo += 1
	return stevilo


func _polje_pozicija_prosta(pos: Vector2, lastna_kmetija = null, predvidena_kmetija: Vector2 = Vector2(INF, INF)) -> bool:
	if _je_na_obrambnem_pas(pos):
		return false
	var main = get_tree().get_first_node_in_group("main_script")
	if is_instance_valid(main):
		if main.has_method("_postavitev_posega_v_vodo") and main._postavitev_posega_v_vodo(pos, polje_scene, "jug"):
			return false
		if main.has_method("_postavitev_posega_v_zasciteno_obmocje") and main._postavitev_posega_v_zasciteno_obmocje(pos, polje_scene, "jug"):
			return false
		if main.has_method("_minimalna_razdalja_od_dreves_za") and main.has_method("_prevec_blizu_vira"):
			var min_razdalja = main._minimalna_razdalja_od_dreves_za(polje_scene)
			if main._prevec_blizu_vira(pos, min_razdalja, polje_scene, "jug"):
				return false
	var stavbe: Array = []
	stavbe.append_array(get_tree().get_nodes_in_group("ai_zgradbe"))
	stavbe.append_array(get_tree().get_nodes_in_group("zgradbe"))
	for stavba in stavbe:
		if not is_instance_valid(stavba) or stavba == lastna_kmetija or not ("tip_zgradbe" in stavba):
			continue
		var tip := str(stavba.tip_zgradbe)
		var meja := 130.0 if tip == "polje" else 205.0
		if tip in ["obzidje", "vrata"]:
			meja = 145.0
		if pos.distance_to(stavba.global_position) < meja:
			return false
	# Pri preverjanju še nepostavljene kmetije je njen položaj namenoma
	# dovoljen; odmik je izračunan tako, da se njiva vizualno dotakne stavbe.
	if predvidena_kmetija != Vector2(INF, INF) and pos.distance_to(predvidena_kmetija) < 80.0:
		return false
	return true


func _pozicija_veljavna(pos: Vector2, scena: PackedScene, smer: String, je_zid: bool, tip: String) -> bool:
	var main = get_tree().get_first_node_in_group("main_script")
	if not is_instance_valid(main):
		return true
	if main.has_method("_postavitev_posega_v_vodo") and main._postavitev_posega_v_vodo(pos, scena, smer):
		return false
	if main.has_method("_postavitev_posega_v_zasciteno_obmocje") and main._postavitev_posega_v_zasciteno_obmocje(pos, scena, smer):
		return false
	if not je_zid and main.has_method("_celica_zgradbe_zasedena") and main._celica_zgradbe_zasedena(pos):
		return false
	if main.has_method("_minimalna_razdalja_od_dreves_za") and main.has_method("_prevec_blizu_vira"):
		var min_razdalja = main._minimalna_razdalja_od_dreves_za(scena)
		if main._prevec_blizu_vira(pos, min_razdalja, scena, smer):
			return false
	if main.has_method("_polmer_za_prekrivanje_scene") and main.has_method("_prevec_blizu_zgradbe"):
		var polmer = main._polmer_za_prekrivanje_scene(scena, tip)
		var dolzina := 2 if tip == "vrata" else 1
		if main._prevec_blizu_zgradbe(pos, polmer, je_zid, smer, dolzina, tip):
			return false
	return true


func _poskusi_nadgraditi(stavba, cene: Dictionary, casi: Dictionary) -> bool:
	if not is_instance_valid(stavba) or bool(stavba.v_gradnji) or bool(stavba.v_nadgradnji):
		return false
	var naslednji := int(stavba.nivo_zgradbe) + 1
	if naslednji > 3 or not cene.has(naslednji) or not casi.has(naslednji):
		return false
	var cena: Dictionary = cene[naslednji]
	if not _ima_surovine(cena):
		return false
	if not stavba.zacni_nadgradnjo(naslednji, float(casi[naslednji])):
		return false
	_odstej_surovine(cena)
	aktivna_nadgradnja = stavba
	print("AI: nadgrajuje ", stavba.tip_zgradbe, " na nivo ", naslednji)
	return true


func _pripravi_obzidje_nacrt() -> void:
	obzidje_nacrt.clear()
	stolp_koti.clear()
	var m := OBRAMBNI_POLMER_MREZE

	# Zgornji levi rob vsebuje dvocelična vrata proti igralcu.
	obzidje_nacrt.append(_zid_podatek(Vector2(-2.0, -float(m)), "jug", "vrata"))
	for x in range(-m, m):
		if x == -m or x == -m + 1:
			continue
		obzidje_nacrt.append(_zid_podatek(Vector2(float(x) + 0.5, -float(m)), "jug", "obzidje"))
	for y in range(-m, m):
		obzidje_nacrt.append(_zid_podatek(Vector2(float(m), float(y) + 0.5), "vzhod", "obzidje"))
	for x in range(m - 1, -m - 1, -1):
		obzidje_nacrt.append(_zid_podatek(Vector2(float(x) + 0.5, float(m)), "jug", "obzidje"))
	for y in range(m - 1, -m - 1, -1):
		obzidje_nacrt.append(_zid_podatek(Vector2(-float(m), float(y) + 0.5), "vzhod", "obzidje"))

	for mreza in [Vector2(-m, -m), Vector2(m, -m), Vector2(m, m), Vector2(-m, m)]:
		stolp_koti.append(obrambni_center + _mreza_v_svet(mreza))


func _zid_podatek(mreza: Vector2, smer: String, tip: String) -> Dictionary:
	return {"pozicija": obrambni_center + _mreza_v_svet(mreza), "smer": smer, "tip": tip}


func _mreza_v_svet(mreza: Vector2) -> Vector2:
	return ZID_KORAK_A * mreza.x + ZID_KORAK_B * mreza.y


func _poskusi_naslednji_zid() -> bool:
	if obzidje_indeks >= obzidje_nacrt.size() or not _ima_surovine(CENA_ZIDU):
		return false
	var podatek: Dictionary = obzidje_nacrt[obzidje_indeks]
	var tip := str(podatek["tip"])
	var scena: PackedScene = vrata_scene if tip == "vrata" else obzidje_scene
	var pos: Vector2 = podatek["pozicija"]
	var smer := str(podatek["smer"])
	if not _pozicija_veljavna(pos, scena, smer, true, tip):
		# Če je na enem mestu naravni vir, ga AI ne prekrije. Naslednji segment
		# vseeno lahko zgradi, zato širjenje baze ne obstane za vedno.
		obzidje_indeks += 1
		return true
	_odstej_surovine(CENA_ZIDU)
	_ustvari_zid(pos, smer, tip)
	obzidje_indeks += 1
	return true


func _ustvari_zid(pos: Vector2, smer: String, tip: String):
	var scena: PackedScene = vrata_scene if tip == "vrata" else obzidje_scene
	var zid = scena.instantiate()
	zid.je_ai = true
	zid.global_position = pos
	zid.nastavi_smer(smer)
	get_parent().add_child(zid)
	zid.add_to_group("obzidje")
	zid.prikazi_nivo(1)
	_zahtevaj_navigacijo()
	return zid


func _poskusi_zgraditi_stolp() -> bool:
	if not _ima_surovine(CENA_STOLPA):
		return false
	var obstojeci := _ai_zgradbe_tipa("stolp").size()
	for odmik in range(stolp_koti.size()):
		var indeks := (obstojeci + odmik) % stolp_koti.size()
		var pos: Vector2 = stolp_koti[indeks]
		var ze_tam := false
		for stolp in _ai_zgradbe_tipa("stolp"):
			if stolp.global_position.distance_to(pos) < 40.0:
				ze_tam = true
				break
		if ze_tam:
			continue
		if not _pozicija_veljavna(pos, stolp_scene, "jug", false, "stolp"):
			continue
		_odstej_surovine(CENA_STOLPA)
		var nova = stolp_scene.instantiate()
		nova.je_ai = true
		nova.global_position = pos
		get_parent().add_child(nova)
		nova.prikazi_nivo(1)
		aktivno_gradbisce = nova if bool(nova.v_gradnji) else null
		_zahtevaj_navigacijo()
		return true
	return false


func _poskusi_obnoviti_porusen_zid() -> bool:
	if poruseni_zidovi.is_empty() or not _ima_surovine(CENA_ZIDU):
		return false
	var podatek: Dictionary = poruseni_zidovi[0]
	var tip := str(podatek["tip"])
	var scena: PackedScene = vrata_scene if tip == "vrata" else obzidje_scene
	if not _pozicija_veljavna(podatek["pozicija"], scena, str(podatek["smer"]), true, tip):
		return false
	_odstej_surovine(CENA_ZIDU)
	_ustvari_zid(podatek["pozicija"], str(podatek["smer"]), tip)
	poruseni_zidovi.pop_front()
	return true


func _ima_surovine(cena: Dictionary) -> bool:
	for tip in cena:
		if int(ai_resources.get(tip, 0)) < int(cena[tip]):
			return false
	return true


func _odstej_surovine(cena: Dictionary) -> void:
	for tip in cena:
		ai_resources[tip] = maxi(0, int(ai_resources.get(tip, 0)) - int(cena[tip]))


func _osvezi_vojasnico_ref() -> void:
	if is_instance_valid(vojasnica_ref):
		return
	var vojasnice := _ai_zgradbe_tipa("vojasnica")
	vojasnica_ref = vojasnice[0] if not vojasnice.is_empty() else null


func _zahtevaj_navigacijo() -> void:
	var main = get_tree().get_first_node_in_group("main_script")
	if is_instance_valid(main):
		if main.has_method("_zahtevaj_posodobitev_navigacije"):
			main._zahtevaj_posodobitev_navigacije()
		elif main.has_method("_zgradi_navigacijsko_mrezo"):
			main.call_deferred("_zgradi_navigacijsko_mrezo")


func ai_zgradba_dokoncana(stavba) -> void:
	if aktivno_gradbisce == stavba:
		aktivno_gradbisce = null
	if is_instance_valid(stavba) and str(stavba.tip_zgradbe) == "vojasnica":
		vojasnica_ref = stavba
	_posodobi_ai_nadgradnje()


func ai_nadgradnja_zgradbe_dokoncana(stavba, _stari_nivo: int, novi_nivo: int) -> void:
	if aktivna_nadgradnja == stavba:
		aktivna_nadgradnja = null
	if not is_instance_valid(stavba):
		return
	var tip := str(stavba.tip_zgradbe)
	match tip:
		"glavna":
			_posodobi_hp(stavba, int(HP_GLAVNE[novi_nivo]))
		"vojasnica":
			_posodobi_hp(stavba, int(HP_VOJASNICE[novi_nivo]))
			vojasnica_ref = stavba
		"stolp":
			_posodobi_hp(stavba, int(HP_STOLPA[novi_nivo]))
			stavba.damage = int(SKODA_STOLPA[novi_nivo])
			stavba.attack_range = float(DOSEG_STOLPA[novi_nivo])
		"obzidje", "vrata":
			_posodobi_hp(stavba, int(HP_OBZIDJA[novi_nivo]))
	_posodobi_ai_nadgradnje()


func _posodobi_hp(stavba, novi_max: int) -> void:
	var razlika := novi_max - int(stavba.max_hp)
	stavba.max_hp = novi_max
	stavba.hp = mini(novi_max, int(stavba.hp) + maxi(0, razlika))


func _posodobi_ai_nadgradnje() -> void:
	var baza_nivo := ai_nivo_baze()
	var vojasnica_nivo := ai_nivo_vojasnice()
	for enota in _ai_enote():
		if enota.has_method("uporabi_nadgradnje"):
			enota.uporabi_nadgradnje(baza_nivo, vojasnica_nivo)
	for delavec in _ai_delavci():
		if delavec.has_method("uporabi_nadgradnjo_baze"):
			delavec.uporabi_nadgradnjo_baze(baza_nivo)


func ai_zgradba_unicena(stavba) -> void:
	if not is_instance_valid(stavba):
		return
	if stavba == vojasnica_ref:
		vojasnica_ref = null
	if stavba == aktivno_gradbisce:
		aktivno_gradbisce = null
	if stavba == aktivna_nadgradnja:
		aktivna_nadgradnja = null
	if str(stavba.tip_zgradbe) in ["obzidje", "vrata"]:
		poruseni_zidovi.append({
			"pozicija": stavba.global_position,
			"smer": str(stavba.smer_zgradbe),
			"tip": str(stavba.tip_zgradbe),
		})


func _poslji_napad() -> void:
	var proste_enote: Array = []
	for enota in _ai_enote():
		if not napadalni_odred.has(enota):
			proste_enote.append(enota)
	if proste_enote.size() < najmanjsi_napadalni_odred:
		cas_do_napada = 15.0
		return

	# Del vojske vedno ostane doma. Z rastjo vojske so napadalni valovi večji.
	var stevilo_za_napad := maxi(najmanjsi_napadalni_odred, int(floor(float(proste_enote.size()) * 0.72)))
	stevilo_za_napad = mini(stevilo_za_napad, proste_enote.size())
	var cilj = _izberi_napadno_tarco(ai_baza_pozicija)
	if not is_instance_valid(cilj):
		cas_do_napada = 20.0
		return

	napadalni_odred.clear()
	for i in range(stevilo_za_napad):
		var enota = proste_enote[i]
		napadalni_odred.append(enota)
		_ukazi_napad_z_razmikom(enota, cilj, i)
	trenutna_napadalna_tarca = cilj
	cas_do_napada = napad_interval
	print("AI: napadalni val z ", napadalni_odred.size(), " enotami na ", cilj.name)


func _izberi_napadno_tarco(iz_pozicije: Vector2):
	var kandidati: Array = []
	kandidati.append_array(get_tree().get_nodes_in_group("zgradbe"))
	var glavna = get_tree().get_first_node_in_group("glavna_hisa")
	if is_instance_valid(glavna) and not kandidati.has(glavna):
		kandidati.append(glavna)
	if kandidati.is_empty():
		kandidati.append_array(get_tree().get_nodes_in_group("enote"))
		kandidati.append_array(get_tree().get_nodes_in_group("delavci"))

	var rezultat = null
	var najboljsa_ocena := INF
	for kandidat in kandidati:
		if not is_instance_valid(kandidat):
			continue
		var ocena := iz_pozicije.distance_to(kandidat.global_position)
		if "tip_zgradbe" in kandidat:
			var tip := str(kandidat.tip_zgradbe)
			if tip in ["stolp", "vojasnica"]:
				ocena -= 180.0
		if ocena < najboljsa_ocena:
			najboljsa_ocena = ocena
			rezultat = kandidat
	return rezultat


func _ukazi_napad_z_razmikom(enota, cilj, indeks: int) -> void:
	if not is_instance_valid(enota) or not is_instance_valid(cilj):
		return
	var kot := float(indeks) * 2.39996
	var polmer := 8.0 + float(indeks % 3) * 7.0
	var odmik := Vector2(cos(kot), sin(kot)) * polmer
	if enota.has_method("ukazi_napad_z_odmikom"):
		enota.ukazi_napad_z_odmikom(cilj, odmik)
	else:
		enota.ukazi_napad(cilj)


func _ocisti_napadalni_odred() -> void:
	var veljavni: Array = []
	for enota in napadalni_odred:
		if is_instance_valid(enota):
			veljavni.append(enota)
	napadalni_odred = veljavni


func _posodobi_napadalni_odred() -> void:
	_ocisti_napadalni_odred()
	if napadalni_odred.is_empty():
		trenutna_napadalna_tarca = null
		return
	if is_instance_valid(trenutna_napadalna_tarca):
		return

	var sredina := Vector2.ZERO
	for enota in napadalni_odred:
		sredina += enota.global_position
	sredina /= float(napadalni_odred.size())
	var nova_tarca = _izberi_napadno_tarco(sredina)
	if not is_instance_valid(nova_tarca):
		return
	trenutna_napadalna_tarca = nova_tarca
	for i in range(napadalni_odred.size()):
		_ukazi_napad_z_razmikom(napadalni_odred[i], nova_tarca, i)


func _preveri_obrambo() -> void:
	var vsiljivec = null
	var najkrajsa := 900.0
	var kandidati: Array = []
	kandidati.append_array(get_tree().get_nodes_in_group("enote"))
	kandidati.append_array(get_tree().get_nodes_in_group("delavci"))
	for kandidat in kandidati:
		if not is_instance_valid(kandidat):
			continue
		var razdalja: float = kandidat.global_position.distance_to(ai_baza_pozicija)
		if razdalja < najkrajsa:
			najkrajsa = razdalja
			vsiljivec = kandidat
	if not is_instance_valid(vsiljivec):
		return

	var branilci: Array = []
	for enota in _ai_enote():
		if napadalni_odred.has(enota):
			continue
		if enota.global_position.distance_to(ai_baza_pozicija) <= 1250.0:
			branilci.append(enota)
	for i in range(mini(6, branilci.size())):
		var branilec = branilci[i]
		if str(branilec.state) != "ATTACKING" or branilec.attack_target != vsiljivec:
			_ukazi_napad_z_razmikom(branilec, vsiljivec, i)
