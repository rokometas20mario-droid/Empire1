extends Node2D

# Jugovzhodno od baze in izven njenega vidnega roba ter kolizije. Isto tocko
# uporabita zacetni delavec in vsi pozneje izdelani delavci.
const DELAVEC_SPAWN_ODMIK: Vector2 = Vector2(220.0, 190.0)
const DELAVEC_SPAWN_SIRINA: float = 35.0

const SAVE_PATH = "user://savegame.json"
const VIR_LOKALNA_PROSOJNOST_SHADER = preload("res://vir_lokalna_prosojnost.gdshader")
const RALLY_ZASTAVICA_TEKSTURA = preload("res://assets/ui_icons/rally_zastavica.png")
const MAP_VERSION: int = 5
const NOVA_MAPA_PATH: String = "res://TiledMapa/prava mapa.tmx"
const IGRALCEVA_BAZA_POZICIJA: Vector2 = Vector2(1216, 3232)
const AI_BAZA_POZICIJA: Vector2 = Vector2(11648, 3200)

# --- Podatki mape, potrebni za branje "prava mapa.tmx" in izometrično pretvorbo ---
const MAP_SIRINA_PLOSCIC: float = 50.0
const MAP_VISINA_PLOSCIC: float = 50.0
const PLOSCICA_SIRINA: float = 256.0
const PLOSCICA_VISINA: float = 128.0

# Gore prepoznamo neposredno iz tmx po gid-u (tileset "objekti_posamicno.tsx",
# lokalni id 6, type="mountain"), ne po imenu vozlišča, ker ga YATI uvoznik
# ne nastavi zanesljivo za vse ploščice.
const OBJEKTI_TILESET_VIR: String = "objekti_posamicno.tsx"
const GORA_LOKALNI_ID: int = 6
const GID_FLIP_MASKA: int = 0x1FFFFFFF
const PRICAKOVANO_STEVILO_GORA: int = 0

# Notranji rob celotnega (2 ploščici širokega) vodnega pasu okoli mape.
# Te iste točke uporabimo tudi kot zunanjo mejo prehodnega območja za navigacijsko mrežo.
const KOPNI_DIAMANT: PackedVector2Array = [
	Vector2(6400, 256),
	Vector2(12288, 3200),
	Vector2(6400, 6144),
	Vector2(512, 3200),
]

# Zunanji rob CELOTNEGA zemljevida (kopno + vodni pas) - izven te diamantne
# oblike je povsod voda (glej tudi _razsiri_ozadje_vode). Uporabljeno tudi za
# postavitev dekorativnih čolnov/otočkov po vodni površini.
const ZUNANJI_DIAMANT: PackedVector2Array = [
	Vector2(6400, 0), Vector2(12800, 3200), Vector2(6400, 6400), Vector2(0, 3200)
]


# Vozlišča, ki pripadajo igralnim sistemom in morajo ostati v glavni sceni.
const SISTEMSKA_VOZLISCA = [
	"SelectionBox", "FogModulate", "FogOfWar", "MainCamera", "delavec",
	"GlavnaHisa", "AIBaza", "AIController", "CanvasLayer", "NovaMapa",
	"PostavitevOverlay"
]

@export var delavec_scene: PackedScene
@export var hisa_scene: PackedScene
@export var drvarnica_scene: PackedScene
@export var kamnolom_scene: PackedScene
@export var rudnik_scene: PackedScene
@export var kmetija_scene: PackedScene
@export var polje_scene: PackedScene
@export var vojasnica_scene: PackedScene
@export var bojevnik_scene: PackedScene
@export var kopjenik_scene: PackedScene
@export var teska_enota_scene: PackedScene
@export var lutka_scene: PackedScene
@export var obzidje_scene: PackedScene
@export var vrata_scene: PackedScene
var building_vrata: bool = false
@export var stolp_scene: PackedScene
@export var poveljnik_scene: PackedScene

var cena_poveljnika = {"FOOD": 60, "WOOD": 40, "GOLD": 30}
var populacija_cena_poveljnika = 3
var poveljnik_producing: bool = false
var poveljnik_timer: float = 0.0
var poveljnik_cas_izdelave: float = 15.0
var glavna_production_queue: Array[String] = []
var glavna_current_type: String = ""
var glavna_production_timer: float = 0.0
var delavec_cas_izdelave: float = 5.0
const MAX_GLAVNA_QUEUE: int = 10
const MAX_VOJASNICA_QUEUE: int = 10

var poveljnik_stats_po_levelu = {
	3: {"max_hp": 140, "damage": 16, "aura_range": 99999.0, "aura_bonus": 10},
}

var building_lutka: bool = false
var postavljam_rally: bool = false
var rally_zastavica: Node2D = null
var building_obzidje: bool = false
var stevilo_zidov: int = 0

var obzidje_level: int = 1
var obzidje_hp_po_levelu = {1: 100, 2: 200, 3: 350}
var cena_zidu = {"WOOD": 20, "STONE": 15}
var cena_nadgradnje_obzidja = {
	2: {"WOOD": 150, "STONE": 100},
	3: {"WOOD": 250, "STONE": 180},
}

var building_stolp: bool = false
var stevilo_stolpov: int = 0

var stolp_level: int = 1
var stolp_hp_po_levelu = {1: 150, 2: 250, 3: 400}
var stolp_damage_po_levelu = {1: 15, 2: 25, 3: 40}
var stolp_range_po_levelu = {1: 200, 2: 250, 3: 300}
var cena_stolpa = {"WOOD": 60, "STONE": 40}
var cena_nadgradnje_stolpa = {
	2: {"WOOD": 150, "STONE": 120},
	3: {"WOOD": 250, "STONE": 200},
}
var cas_nadgradnje_stolpa = {2: 15.0, 3: 25.0}

@onready var resource_label = $CanvasLayer/LesLabel
@onready var debug_label = $CanvasLayer/DebugLabel
@onready var hover_label = $CanvasLayer/HoverLabel
@onready var multi_select_label = $CanvasLayer/MultiSelectLabel
@onready var panel_delavec = $CanvasLayer/PanelDelavec
@onready var panel_vojasnica = $CanvasLayer/PanelVojasnica
@onready var vojasnica_nadgradi_button = $CanvasLayer/PanelVojasnica/ButtonNadgradiVojasnico
@onready var panel_glavna_hisa = $CanvasLayer/PanelGlavnaHisa
@onready var glavna_hisa_nadgradi_button = $CanvasLayer/PanelGlavnaHisa/ButtonNadgradiGlavno
@onready var panel_obzidje = $CanvasLayer/PanelObzidje
@onready var vrata_odpri_button = $CanvasLayer/PanelObzidje/ButtonOdpriVrata
@onready var panel_stolp = $CanvasLayer/PanelStolp
@onready var stolp_nadgradi_button = $CanvasLayer/PanelStolp/ButtonNadgradiStolp
@onready var panel_kmetija = $CanvasLayer/PanelKmetija
@onready var panel_zrusi = $CanvasLayer/PanelZrusi
@onready var game_over_label = $CanvasLayer/GameOverLabel
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var camera = $MainCamera

# --- Touch vnos ---
var touch_points = {}
var touch_start_time = {}
var touch_start_pos = {}
var long_press_triggered = {}
var long_press_threshold = 0.3
var touch_moved_enough = 10.0

# Zadnja znana pozicija "kazalca" (prst na telefonu ALI miška na
# računalniku) v SVETOVNIH koordinatah - get_global_mouse_position() sam
# po sebi na telefonu NE deluje zanesljivo (ni resnične miške, samo dotik),
# zato duh postavitve (glej _posodobi_postavitev_ghost) namesto tega
# uporablja to spremenljivko, ki jo ročno posodabljamo iz VSEH vrst vnosa
# (dotik-dol, dotik-vlečenje, miškino premikanje).
var zadnja_kazalec_pozicija: Vector2 = Vector2.ZERO

var multi_select_mode = false
var selected_building = null
var igra_koncana: bool = false

var is_panning = false
var pan_start_touch = Vector2.ZERO
var pan_start_cam_pos = Vector2.ZERO

var pinch_start_distance = 0.0
var pinch_start_zoom = Vector2.ONE
var min_zoom = 0.5
var max_zoom = 2.0

# Igra je bila doslej nastavljena SAMO za dotik (pinch-zoom/vlečenje s
# prstom) - na računalniku z miško ni bilo NOBENEGA načina za premik po
# mapi ali za zoom. Dodano zdaj: puščice/WASD za premik kamere (glej
# _process spodaj), kolešček miške za zoom (glej _unhandled_input). Namenoma
# NE uporablja miškinih gumbov za premik kamere - levi gumb je zdaj zaseden
# z vlečenjem za postavljanje zidu (glej _obzidje_vlek_aktiven), desni pa z
# ukazi (napad/premik/popravilo), zato bi se prekrivalo.
var kamera_hitrost: float = 1000.0
var _navigacija_posodobitev_timer: Timer = null
var _navigacija_pecenje_v_teku: bool = false
var _navigacija_ponovi_po_pecenju: bool = false
var _navigacija_poligon_v_pecenju: NavigationPolygon = null
var _navigacija_izvor_v_pecenju: NavigationMeshSourceGeometryData2D = null

var current_pop: int = 1
var max_pop: int = 5

var is_building: bool = false

# Smer, ki jo bo imela zgradba, ko jo postaviš (glej zgradba.gd:nastavi_smer).
# NAMENOMA ni to zasuk slike (rotation_degrees) - zavrtena izometrična
# sličica izgleda popačeno. Namesto tega gumb "Zavrti" kroži skozi poimenovane
# smeri; vsaka zgradba ima lahko svojo pravo sličico za vsako od njih
# (tekstura_jug/sever/vzhod/zahod na zgradba.gd). Večina zgradb ima sliko
# samo za jug/sever (obračanje samo med tema dvema), obzidje/vrata pa imajo
# vse 4 (potrebno, da se lahko sestavi kvadrat) - gumb sam ugotovi, katere
# smeri so za trenutno zgradbo dejansko na voljo, glej _razpolozljive_smeri_za().
const SMERI_ZAPOREDJE = ["jug", "sever", "vzhod", "zahod"]
var smer_gradnje: String = "jug"
@onready var zavrti_button = $CanvasLayer/ZavrtiButton
@onready var smer_predogled = $CanvasLayer/SmerPredogled
@onready var preklici_button = $CanvasLayer/PrekliciButton
@onready var obvestilo_label = $CanvasLayer/ObvestiloLabel

var _production_fill: Dictionary = {}
var _production_count: Dictionary = {}
var _ikonski_gumbi: Dictionary = {}
var _queue_strip_vojska: HBoxContainer = null
var _queue_strip_glavna: HBoxContainer = null
var _zadnji_queue_podpis_vojska: String = ""
var _zadnji_queue_podpis_glavna: String = ""
var _ikone_po_tipu: Dictionary = {}
var _nadgradnja_fill: Dictionary = {}

# Ločeno vozlišče (NE glavni "Main"/self!) samo za risanje "duha" postavitve/
# mreže/izbirnega pravokotnika. KLJUČNO: ker so VSE zgradbe/drevesa/enote
# otroci vozlišča "Main" (self), bi bilo risanje neposredno v Main._draw()
# VEDNO narisano ZA (pod) vsemi temi otroki - Godot najprej nariše lastno
# vsebino vozlišča, šele nato otroke NA VRHU. To je najverjetneje pravi
# razlog, da "duh" zgradbe po štirih zaporednih popravkih še vedno ni bil
# viden - sam mehanizem risanja je deloval, a je bil dobesedno prekrit z
# zemljevidom/zgradbami/drevesi nad njim. To ločeno vozlišče ima visok
# z_index (glej main.tscn), zato se vedno nariše NA VRHU vsega ostalega.
@onready var postavitev_overlay = $PostavitevOverlay

# Duh postavitve (silhueta) - namenoma NE ločen Sprite2D vozlišče (glej
# opombo v spominu: sum, da je to bil pravi vzrok, da se ni nikoli
# prikazal - ta pot je popolnoma odvisna samo od _draw() na Main vozlišču
# samem, ki ZAGOTOVO deluje (glej obstoječi pravokotnik za izbiro z
# vlečenjem, ki je vedno deloval).
var _ghost_vidna: bool = false
var _ghost_tekstura: Texture2D = null
var _ghost_pozicija: Vector2 = Vector2.ZERO
var _ghost_odmik: Vector2 = Vector2.ZERO
var _ghost_merilo: Vector2 = Vector2.ONE
var _zid_predogled_cache: Dictionary = {}
var _scena_meritve_cache: Dictionary = {}
const VIR_INDEKS_CELICA: float = 512.0
var _vir_prostorski_indeks: Dictionary = {}
var _vir_indeks_stevilo: int = -1
var _aktivni_lokalno_prosojni_viri: Dictionary = {}
var _voda_plast_za_gradnjo: TileMapLayer = null
var _poti_plast_za_gradnjo: TileMapLayer = null
var _zid_zasedeni_robovi_cache: Dictionary = {}
var _zid_cache_stevilo: int = -1
var _ne_zidne_zgradbe_cache: Array = []
var _ne_zidne_zgradbe_cache_stevilo: int = -1

# --- Razširitev obzidja "v vse smeri" (glej _obzidje_dotik spodaj) ---
# Ko igralec med gradnjo obzidja/vrat tapne na že postavljen segment,
# postane ta segment "sidro" in namesto takojšnje gradnje pokažemo VSE
# možne sosednje pozicije (v vseh smereh, kjer je to mogoče) - igralec
# nato tapne eno izmed njih, da tam dejansko zgradi nov (takoj gotov)
# segment. _obzidje_sidro == null pomeni, da trenutno ne kažemo nobenih
# kandidatov (normalno obnašanje - prvi/samostojni segment se zgradi
# natanko tam, kamor igralec tapne).
var _obzidje_sidro = null
var _obzidje_kandidati: Array = []

# Ali je trenutno aktivno "vlečenje" (drag) za postavljanje niza segmentov
# obzidja/vrat z miško ali enim prstom naenkrat - glej
# _obzidje_izracunaj_verigo/_obzidje_zgradi_verigo. Dva prsta sta še vedno
# rezervirana za povečavo in premik kamere.
var _obzidje_vlek_aktiven: bool = false

var building_polje: bool = false
var stevilo_polj: int = 0
var max_polj: int = 5
var cena_polja: int = 40

# Poenoten sistem za vse "skladiščne" zgradbe (drvarnica, kamnolom, rudnik, kmetija).
# Vsaka zgradba ima ceno (v lesu), skupino za dostavo in največje dovoljeno število.
var oddajne_zgradbe = {
	"WOOD": {"scene": null, "group": "drvarnica", "cost": 50, "count": 0, "max": 3},
	"STONE": {"scene": null, "group": "kamnolom", "cost": 50, "count": 0, "max": 3},
	"GOLD": {"scene": null, "group": "rudnik", "cost": 50, "count": 0, "max": 3},
	"FOOD": {"scene": null, "group": "kmetija", "cost": 50, "count": 0, "max": 3},
}

var zgradba_za_postavitev: PackedScene = null
var zgradba_kljuc: String = ""

# Vojašnica (v1: samo ena vojašnica hkrati)
var building_vojasnica: bool = false
var cena_vojasnice: int = 50
var stevilo_vojasnic: int = 0
var max_vojasnic: int = 1
var vojasnica_level: int = 0
var vojasnica_ref = null

var cena_nadgradnje_vojasnice = {
	2: {"STONE": 80, "WOOD": 40},
	3: {"STONE": 120, "WOOD": 60},
}
var cas_nadgradnje_vojasnice = {2: 20.0, 3: 30.0}

var cena_enote = {
	"BOJEVNIK": {"FOOD": 20, "WOOD": 10},
	"KOPJENIK": {"FOOD": 35, "WOOD": 20},
	"TESKA": {"FOOD": 45, "WOOD": 23},
}

var populacija_cena_enote = {
	"BOJEVNIK": 1,
	"KOPJENIK": 2,
	"TESKA": 5,
}

# Glavna stavba (v1: samo za populacijo vojske, brez vpliva na delavce - to pride kasneje)
var glavna_stavba_level: int = 1
var cena_nadgradnje_glavne_stavbe = {
	2: {"WOOD": 100, "STONE": 60},
	3: {"WOOD": 150, "STONE": 100},
}
var cas_nadgradnje_glavne_stavbe = {2: 30.0, 3: 45.0}

# Populacija za vojsko: osnova 25, +15 na level glavne stavbe, +10 na level vojašnice
var vojaska_populacija: int = 0
var max_vojaska_populacija: int = 25

var is_dragging := false
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO

var resources = {
	"WOOD": 0,
	"STONE": 0,
	"GOLD": 0,
	"FOOD": 0
}


func _enter_tree():
	# Staro ročno sestavljeno mapo odstranimo še preden se zaženejo otrokovi
	# _ready() klici. Tako AI že od začetka vidi novi lokaciji obeh baz.
	_odstrani_staro_mapo()
	_namesti_novo_tiled_mapo()


func _odstrani_staro_mapo():
	for otrok in get_children():
		if otrok.name in SISTEMSKA_VOZLISCA:
			continue
		remove_child(otrok)
		otrok.free()


func _namesti_novo_tiled_mapo():
	var mapa = get_node_or_null("NovaMapa")
	var mapa_je_ze_v_sceni = mapa != null

	if mapa == null:
		var mapa_scena = load(NOVA_MAPA_PATH) as PackedScene
		if mapa_scena == null:
			push_error("Nove Tiled mape ni mogoče naložiti: " + NOVA_MAPA_PATH)
			return
		mapa = mapa_scena.instantiate()
		mapa.name = "NovaMapa"

	var objekti = mapa.get_node_or_null("Objekti")
	if objekti == null:
		push_error("Nova mapa nima plasti Objekti")
		mapa.free()
		return

	var igralec_pozicija = Vector2.ZERO
	var ai_pozicija = Vector2.ZERO
	var ima_igralca = false
	var ima_ai = false
	var novi_viri = []

	# Poligoni gora (v svetovnih koordinatah) izračunani samo enkrat, uporabljeni
	# tako za njihovo kolizijo kot za izločanje virov/živali, ki bi sicer padli
	# znotraj vidne skale (glej _je_v_kateri_gori spodaj).
	var gorski_poligoni := _izracunaj_poligone_gora()

	_pripravi_ovire_mape(gorski_poligoni)

	for objekt in objekti.get_children():
		var ime = String(objekt.name).to_lower()

		if ime == "playerbase":
			igralec_pozicija = IGRALCEVA_BAZA_POZICIJA
			ima_igralca = true
			_odstrani_marker_oviro(objekti, objekt)
		elif ime == "enemybase":
			ai_pozicija = AI_BAZA_POZICIJA
			ima_ai = true
			_odstrani_marker_oviro(objekti, objekt)
		elif ime.begins_with("drevo"):
			novi_viri.append({"scene": load("res://tree.tscn"), "position": objekt.position})
			objekt.visible = false
		elif ime.begins_with("skale"):
			novi_viri.append({"scene": load("res://kamen.tscn"), "position": _sredisce_sprite_objekta(objekt)})
			objekt.visible = false
		elif ime.begins_with("zlato"):
			novi_viri.append({"scene": load("res://zlato.tscn"), "position": _sredisce_sprite_objekta(objekt)})
			objekt.visible = false
		elif ime.begins_with("grm_jagode"):
			novi_viri.append({"scene": load("res://hrana.tscn"), "position": _sredisce_sprite_objekta(objekt)})
			objekt.visible = false
		# Gore NISO več zaznane po imenu - glej _dodaj_gorske_ovire(), ki koordinate
		# vseh gora prebere neposredno iz "prava mapa.tmx".

	if not mapa_je_ze_v_sceni:
		add_child(mapa)
		move_child(mapa, 0)

	# Zemljevid je rombast (isometric diamond), kamerine omejitve pa so vedno
	# pravokotne - v vseh štirih kotih pravokotnika, kjer ni ploščic, je bilo
	# videti sivo praznino. Namesto pobarvanega pravokotnika (poskušeno prej,
	# ni bilo dobro) zdaj dejansko RAZŠIRIMO obstoječo "voda" plast s pravimi
	# vodnimi ploščicami vse do roba kamerinih meja - to je ista umetniška
	# podoba kot že vidna voda okoli otoka, samo dlje navzven.
	_razsiri_ozadje_vode(mapa)
	_dodaj_vodne_zalive_ovire(mapa)

	for podatek in novi_viri:
		# Vir, ki bi pristal znotraj silhuete gore (glej _je_v_kateri_gori), tu
		# preskočimo - prej so bila drevesa/kamni/zlato postavljena samo po
		# Tiled poziciji, brez vednosti o goreh, zato je izgledalo, kot da
		# rastejo/štrlijo iz skale.
		if _je_v_kateri_gori(podatek["position"], gorski_poligoni):
			continue
		var vir = podatek["scene"].instantiate()
		vir.position = podatek["position"]
		add_child(vir)

	var glavna_hisa = get_node_or_null("GlavnaHisa")
	var ai_baza = get_node_or_null("AIBaza")
	var prvi_delavec = get_node_or_null("delavec")
	var glavna_kamera = get_node_or_null("MainCamera")

	if ima_igralca and glavna_hisa:
		glavna_hisa.position = igralec_pozicija
		glavna_hisa.visible = true
	if ima_ai and ai_baza:
		ai_baza.position = ai_pozicija
		ai_baza.visible = true
	if ima_igralca and prvi_delavec:
		prvi_delavec.position = igralec_pozicija + DELAVEC_SPAWN_ODMIK
	if ima_igralca and glavna_kamera:
		glavna_kamera.position = igralec_pozicija
		glavna_kamera.limit_left = 0
		glavna_kamera.limit_top = 0
		glavna_kamera.limit_right = 12800
		glavna_kamera.limit_bottom = 6500

	# Navigacijsko mrežo zgradimo šele na koncu, ko so vse ovire (voda, gore,
	# kamen, zlato, drevesa, glavna stavba) že postavljene v sceno.
	_zgradi_navigacijsko_mrezo()

	# Živali (zival.gd/zival.tscn) so bile prej ročno postavljene v staro,
	# peš sestavljeno mapo - ta scenska drevesa je _odstrani_staro_mapo()
	# ob vsakem zagonu pobrisala, zato po prehodu na Tiled mapo živali niso
	# bile več nikoli ustvarjene. Sedaj jih po namestitvi nove mape na novo
	# naključno razporedimo po kopnem delu otoka.
	_zgradi_zivali(gorski_poligoni)


# YATI markerja "PlayerBase"/"EnemyBase" ovije v pravi fizikalni StaticBody2D
# (podeduje elipsasto kolizijo ploščice "main_building"), ker imata v Tiled-u
# eksplicitno nastavljen "type" ("player_base"/"enemy_base") - zato ju YATI-jeva
# uvozna logika ne prepozna in ju privzeto obravnava kot telo s kolizijo.
# Samo "visible = false" te kolizije NE izklopi - nevidna ovira je stala tik
# ob pravi bazi (GlavnaHisa/AIBaza) in je delavcem, predvsem AI, trajno
# blokirala pot do baze (navigacijska mreža jo je zaznala kot statično oviro).
# Pozicijo baze smo že prebrali pred klicem te funkcije (glej zgoraj), zato
# marker lahko kar v celoti odstranimo iz scene.
func _odstrani_marker_oviro(objekti: Node, objekt: Node) -> void:
	objekti.remove_child(objekt)
	objekt.free()


const STEVILO_ZIVALI := 9
const RAZPORED_ZIVALI: Array[String] = [
	"jelen", "jelen", "jelen",
	"divji_prasic", "divji_prasic", "divji_prasic",
	"pragovedo", "pragovedo", "pragovedo",
]


func _zgradi_zivali(gorski_poligoni: Array) -> void:
	var stare = get_node_or_null("Zivali")
	if stare:
		remove_child(stare)
		stare.free()

	var zival_scena := load("res://zival.tscn") as PackedScene
	if zival_scena == null:
		push_warning("zival.tscn ni najden - zivali ne bodo ustvarjene.")
		return

	var zivali := Node2D.new()
	zivali.name = "Zivali"
	add_child(zivali)

	var ustvarjenih := 0
	var poskusi := 0
	var razpored := RAZPORED_ZIVALI.duplicate()
	razpored.shuffle()

	while ustvarjenih < STEVILO_ZIVALI and poskusi < 500:
		poskusi += 1
		var tocka := Vector2(randf_range(600.0, 12200.0), randf_range(600.0, 5900.0))

		if not Geometry2D.is_point_in_polygon(tocka, KOPNI_DIAMANT):
			continue
		if tocka.distance_to(IGRALCEVA_BAZA_POZICIJA) < 500.0:
			continue
		if tocka.distance_to(AI_BAZA_POZICIJA) < 500.0:
			continue
		# Žival naj se ne pojavi na (ali tik ob) gori - preverimo pravo silhueto
		# gore namesto samo grobe razdalje do sidra, ki je bila za velike gore
		# premajhna (žival se je znala pojaviti tik ob/na skali).
		if _je_v_kateri_gori(tocka, gorski_poligoni):
			continue

		var nova := zival_scena.instantiate()
		nova.vrsta_zivali = String(razpored[ustvarjenih])
		nova.global_position = tocka
		zivali.add_child(nova)
		ustvarjenih += 1


func _sredisce_sprite_objekta(objekt: Node2D) -> Vector2:
	if objekt is Sprite2D:
		return objekt.position + objekt.offset * objekt.scale
	return objekt.position


func _doseg_klika_vira(vir: Node2D) -> float:
	if "resource_type" in vir and int(vir.resource_type) == 0:
		return 115.0
	return 90.0


# Razširi obstoječo "voda" TileMapLayer plast s pravimi vodnimi ploščicami
# (ista slika/tileset kot že vidna voda) vse do dobršne mere zunaj kamerinih
# meja, da v štirih kotih pravokotnika okoli rombastega zemljevida namesto
# sivine vidimo nadaljevanje istega morja. Uporabimo map_to_local(), da
# dobimo natančno svetovno pozicijo vsake kandidatne ploščice - brez
# ročnega podvajanja izometrične pretvorbe.
func _razsiri_ozadje_vode(mapa: Node) -> void:
	var voda := mapa.find_child("voda", true, false) as TileMapLayer
	if voda == null:
		push_warning("'voda' plast ni najdena - ozadje vode ne bo razširjeno.")
		return

	var ts := voda.tile_set
	if ts == null:
		return

	var vodni_vir_id := -1
	for i in range(ts.get_source_count()):
		var sid: int = ts.get_source_id(i)
		var src := ts.get_source(sid)
		if src is TileSetAtlasSource and "voda_tileset" in (src as TileSetAtlasSource).texture.resource_path:
			vodni_vir_id = sid
			break

	if vodni_vir_id == -1:
		push_warning("Vodni tileset ni najden - ozadje vode ne bo razširjeno.")
		return

	# Ploščica (3,3) v voda_tileset.png je v celoti vodna (wangid vseh 4 kotov
	# "voda", glej voda.tsx) - brez prehodnega/obalnega roba.
	var polna_vodna_plosica := Vector2i(3, 3)

	var rob := 2500.0
	var meje := Rect2(-rob, -rob, 12800.0 + 2.0 * rob, 6500.0 + 2.0 * rob)

	# Zunanji rob CELOTNEGA zemljevida (kopno + vodni pas) - enak diamant kot
	# ga uporablja _pripravi_ovire_mape() za zunanji rob ovir. Tega območja NE
	# smemo prekriti z novimi ploščicami, čeprav ga "voda" plast tam nima
	# eksplicitno zapolnjenega (samo 2 ploščici širok pas ob robu) - drugače bi
	# ploščice pristale tudi čez travo/gore/baze na sredini zemljevida (tam so
	# bile do zdaj samo po sreči nevidne, ker jih druge plasti rišejo čez).
	var zunanji_diamant := PackedVector2Array([
		Vector2(6400, 0), Vector2(12800, 3200), Vector2(6400, 6400), Vector2(0, 3200)
	])

	for gx in range(-70, 120):
		for gy in range(-70, 120):
			var celica := Vector2i(gx, gy)
			if voda.get_cell_source_id(celica) != -1:
				continue
			# map_to_local() vrne pozicijo v LOKALNEM prostoru "voda" vozlišča
			# (ki ima samo svoj position-zamik, npr. (6272,0)) - za primerjavo s
			# skupnimi svetovnimi mejami ga moramo pretvoriti v globalni prostor.
			var svet: Vector2 = voda.to_global(voda.map_to_local(celica))
			if not meje.has_point(svet):
				continue
			if Geometry2D.is_point_in_polygon(svet, zunanji_diamant):
				continue
			voda.set_cell(celica, vodni_vir_id, polna_vodna_plosica)


# Nekatere gore so bile v Tiled-u postavljene čez majhne vodne zalive/zajede na
# robu otoka (verjetno namerno, da je velika slika gore vizualno "zakrila"
# zaliv) - KOPNI_DIAMANT jih zato šteje za kopno, čeprav je tam v resnici
# (v "voda" plasti) ves čas bila prava vodna ploščica. Dokler je bila gora
# tam, tega ni bilo videti; zdaj ko so gore zamenjane z (manjšimi) drevesi, so
# ti zalivi vidni - a brez te funkcije bi bili še vedno hodljivi (vizualno
# voda, fizično prazen prostor). Tu vsaki taki "anomalni" vodni ploščici
# dodamo majhno kolizijsko oviro v obliki ploščice.
func _dodaj_vodne_zalive_ovire(mapa: Node) -> void:
	var voda := mapa.find_child("voda", true, false) as TileMapLayer
	if voda == null:
		return
	var ovire := get_node_or_null("IgralneOvire")
	if ovire == null:
		return

	var pol_sirina := PLOSCICA_SIRINA * 0.5
	var pol_visina := PLOSCICA_VISINA * 0.5
	var stevilo := 0

	for celica in voda.get_used_cells():
		var svet: Vector2 = voda.to_global(voda.map_to_local(celica))
		if not Geometry2D.is_point_in_polygon(svet, KOPNI_DIAMANT):
			continue
		var telo := StaticBody2D.new()
		telo.collision_layer = 1
		telo.collision_mask = 0
		var oblika := CollisionPolygon2D.new()
		oblika.polygon = PackedVector2Array([
			svet + Vector2(0, -pol_visina),
			svet + Vector2(pol_sirina, 0),
			svet + Vector2(0, pol_visina),
			svet + Vector2(-pol_sirina, 0),
		])
		telo.add_child(oblika)
		ovire.add_child(telo)
		stevilo += 1

	if stevilo > 0:
		print("Dodanih ", stevilo, " ovir za skrite vodne zalive (prej pod gorami).")


# Poišče naključno točko v vodi (izven ZUNANJI_DIAMANT, znotraj kamerinih meja
# z odmikom od roba, da dekoracija ni obrezana) dovolj daleč od že zasedenih
# točk. Vrne Vector2(-1,-1), če v razumnem številu poskusov ne najde proste.
func _nakljucna_vodna_tocka(meje: Rect2, zasedene: Array, min_razdalja: float) -> Vector2:
	for poskus in range(40):
		var tocka := Vector2(
			randf_range(meje.position.x, meje.position.x + meje.size.x),
			randf_range(meje.position.y, meje.position.y + meje.size.y)
		)
		if Geometry2D.is_point_in_polygon(tocka, ZUNANJI_DIAMANT):
			continue
		var dovolj_dalec := true
		for z in zasedene:
			if z.distance_to(tocka) < min_razdalja:
				dovolj_dalec = false
				break
		if dovolj_dalec:
			return tocka
	return Vector2(-1, -1)


func _pripravi_ovire_mape(gorski_poligoni: Array):
	var stare_ovire = get_node_or_null("IgralneOvire")
	if stare_ovire:
		remove_child(stare_ovire)
		stare_ovire.free()

	var ovire = Node2D.new()
	ovire.name = "IgralneOvire"
	add_child(ovire)

	# Vodni pas je širok 2 ploščici (glej plast "voda" v prava mapa.tmx), zato mora
	# neprehodno območje segati vse do notranjega roba celotnega pasu - prej je
	# pokrivalo samo zunanjo ploščico, zato je delavec lahko prišel skoraj do sredine vode.
	#
	# POMEMBNO: _razsiri_ozadje_vode() vizualno pobarva vodne ploščice precej dlje
	# navzven kot samo ta ozek pas (vse do kamerinih meja + razsežnega roba) - če bi
	# oviro postavili samo do zunanji_diamant (kot prej), bi bilo vse ONKRAJ te meje
	# vizualno voda, a brez kolizije, torej prehodno (enote/živali bi lahko normalno
	# "hodile po vodi"). Zato tu oviro raztegnemo daleč čez celotno razširjeno
	# vodno območje (in še precej dlje za varnostno rezervo).
	var zunanji_vrh = Vector2(6400, -6400)
	var zunanji_desno = Vector2(25600, 3200)
	var zunanji_dno = Vector2(6400, 12800)
	var zunanji_levo = Vector2(-12800, 3200)
	var notranji_vrh = KOPNI_DIAMANT[0]
	var notranji_desno = KOPNI_DIAMANT[1]
	var notranji_dno = KOPNI_DIAMANT[2]
	var notranji_levo = KOPNI_DIAMANT[3]

	_dodaj_poligonsko_oviro(ovire, PackedVector2Array([
		zunanji_vrh, zunanji_desno, notranji_desno, notranji_vrh
	]))
	_dodaj_poligonsko_oviro(ovire, PackedVector2Array([
		zunanji_desno, zunanji_dno, notranji_dno, notranji_desno
	]))
	_dodaj_poligonsko_oviro(ovire, PackedVector2Array([
		zunanji_dno, zunanji_levo, notranji_levo, notranji_dno
	]))
	_dodaj_poligonsko_oviro(ovire, PackedVector2Array([
		zunanji_levo, zunanji_vrh, notranji_vrh, notranji_levo
	]))

	_dodaj_gorske_ovire(ovire, gorski_poligoni)


func _dodaj_poligonsko_oviro(stars: Node2D, tocke: PackedVector2Array):
	var telo = StaticBody2D.new()
	telo.collision_layer = 1
	telo.collision_mask = 0
	var oblika = CollisionPolygon2D.new()
	oblika.polygon = tocke
	telo.add_child(oblika)
	stars.add_child(telo)


# Isti izometrični pretvorbi (x,y) -> world pozicija, ki jo za uvoz iz Tiled-a
# uporablja tudi YATI (glej addons/YATI/TilemapCreator.gd -> transpose_coords),
# da se ovire ujemajo s položajem že uvoženih sprite-ov.
func _tmx_v_svet(x: float, y: float) -> Vector2:
	var trans_x := (x - y) * PLOSCICA_SIRINA / PLOSCICA_VISINA / 2.0 + MAP_VISINA_PLOSCIC * PLOSCICA_SIRINA / 2.0
	var trans_y := (x + y) * 0.5
	return Vector2(trans_x, trans_y)


# Prebere koordinate vseh gora neposredno iz "prava mapa.tmx" (plast objektov
# "Objekti"), po gid-u iz tileseta objekti_posamicno.tsx - ne po imenu vozlišča,
# ker ga uvoznik iz Tiled-a (YATI) ne nastavi zanesljivo za vse ploščice, zato so
# se prej trki za nekatere gore izgubili.
func _preberi_gore_iz_tmx() -> Array:
	var gore: Array = []
	var parser := XMLParser.new()
	if parser.open(NOVA_MAPA_PATH) != OK:
		push_error("Ne morem odpreti '" + NOVA_MAPA_PATH + "' za branje koordinat gora.")
		return gore

	var gora_gid: int = -1
	var v_objektih := false

	while parser.read() == OK:
		var vrsta := parser.get_node_type()

		if vrsta == XMLParser.NODE_ELEMENT:
			var ime_elementa := parser.get_node_name()

			if ime_elementa == "tileset" and gora_gid == -1:
				if parser.get_named_attribute_value_safe("source") == OBJEKTI_TILESET_VIR:
					var first_gid := int(parser.get_named_attribute_value_safe("firstgid"))
					gora_gid = first_gid + GORA_LOKALNI_ID

			elif ime_elementa == "objectgroup":
				v_objektih = parser.get_named_attribute_value_safe("name") == "Objekti"

			elif ime_elementa == "object" and v_objektih:
				var gid_niz := parser.get_named_attribute_value_safe("gid")
				if gid_niz != "":
					var gid_surov := int(gid_niz)
					var gid := gid_surov & GID_FLIP_MASKA
					if gora_gid != -1 and gid == gora_gid:
						gore.append({
							"x": float(parser.get_named_attribute_value_safe("x")),
							"y": float(parser.get_named_attribute_value_safe("y")),
							"w": float(parser.get_named_attribute_value_safe("width")),
							"h": float(parser.get_named_attribute_value_safe("height")),
							"flip_h": (gid_surov & 0x80000000) != 0,
						})

		elif vrsta == XMLParser.NODE_ELEMENT_END and v_objektih:
			if parser.get_node_name() == "objectgroup":
				v_objektih = false

	if gore.size() != PRICAKOVANO_STEVILO_GORA:
		push_warning("Pričakovanih %d gora iz tmx, dejansko najdenih %d." % [PRICAKOVANO_STEVILO_GORA, gore.size()])

	return gore


# Za vsako goro iz tmx ustvari stalno oviro v obliki dejanske kamnite silhuete.
# Zgodovina te oblike (pomembno za razumevanje, zakaj je taka, kot je):
# 1. Prvotno je bil uporabljen avtorsko narisan kolizijski poligon iz
#    objekti_posamicno.tsx, ki je pokrival samo ozek pas na sredini slike - dalo
#    se je hoditi po velikem delu vidne skale (predvsem pri dveh največjih gorah).
# 2. Nato je bila kolizija izračunana iz alfa-kanala slike gora.png, obrezana pod
#    y=420 (izključen ošiljen vrh) po izometrični konvenciji "hoje za visoko
#    sceno" - a to je bilo zavajajoče (izgledalo je, da lahko hodiš po skali, in
#    da drevesa rastejo iz gore).
# 3. Nato CELOTNA silhueta (concave, ~16 točk) BREZ obreza - vizualno pravilno,
#    A: Godot fizika tak zelo konkaven poligon (ozek zobat vrh) interno razdeli
#    na trikotnike, in ozki/tanki koščki med zobmi vrha so znali povzročiti
#    "tuneliranje" - lik pri hitrejšem premiku (predvsem enote/bojevniki, glej
#    enota.gd, ki nima navigacijskega agenta, samo raven premik + fizika) je
#    včasih zdrsnil NASKOZI goro prav na območju zobatega vrha. To je bil pravi
#    vzrok, da se je dalo "hoditi skozi goro" - potrjeno s testom skozi vrh iz
#    4 smeri (8/24 primerov je šlo skozi).
# 4. KONČNA REŠITEV: konveksna ovojnica (convex hull) celotne silhuete. Konveksni
#    poligoni v Godotu NISO razdeljeni na koščke, zato tuneliranje ni mogoče.
#    Cena: v dveh plitvih "dolinicah" tik ob vrhu (med zobmi) je kolizija rahlo
#    večja od slikovne silhuete - komaj opazno, in veliko boljše kot možnost
#    prehoda skozi goro.
# Točke so relativne glede na sidro (spodnje sredinsko sidro objekta v Tiled-u,
# native slikovna točka 512,768 znotraj slike velikosti 1024x768).
const GORA_NATIVNA_SIRINA := 1024.0
const GORA_NATIVNA_VISINA := 768.0
const GORA_PODNOZJE_TOCKE: Array[Vector2] = [
	Vector2(-496.0, -221.0),
	Vector2(-56.0, -720.0),
	Vector2(263.0, -549.0),
	Vector2(495.0, -175.0),
	Vector2(79.0, -2.0),
	Vector2(-154.0, -29.0),
	Vector2(-365.0, -119.0),
]


# Razdalja med sidri, pod katero dve gori štejemo za del istega "gorovja"
# (glej _izracunaj_poligone_gora spodaj). Dejanske gore v mapi ležijo v dveh
# gostih skupinah (razmiki med sosedami ~320-590), zato je 900 varno nad tem,
# a globoko pod razdaljo med samimi skupinami (>3500).
const GORA_ZDRUZI_RAZDALJA := 900.0


# Izračuna neprehodna območja gora v SVETOVNIH koordinatah. Gore v tej mapi
# niso 18 osamljenih vrhov - v resnici tvorijo dve gosti, tesno stisnjeni
# gorski skupini (po slikovnem pregledu). Če vsaki gori posebej zgradimo SVOJ
# kolizijski poligon (kot je bilo prej), lahko med sosednjimi vrhovi ostane
# tanka prehodna "reža" - vizualno je videti kot ena sklenjena skala, dejansko
# pa navigacijska mreža skozi tako režo vseeno spelje pot, zato je bilo možno
# "normalno hoditi čez gore". Rešitev: gore najprej združimo v skupine po
# bližini sidra (glej GORA_ZDRUZI_RAZDALJA), nato za VSAKO skupino zgradimo EN
# sam, sklenjen konveksni poligon čez vse točke vseh gora v tej skupini - tako
# med sosednjimi vrhovi znotraj skupine ni več nobene reže.
func _izracunaj_poligone_gora() -> Array:
	var gore := _preberi_gore_iz_tmx()
	var sidra: Array[Vector2] = []
	var tocke_na_goro: Array = []

	for gora in gore:
		var sidro := _tmx_v_svet(gora["x"], gora["y"])
		var scale_x: float = gora["w"] / GORA_NATIVNA_SIRINA
		var scale_y: float = gora["h"] / GORA_NATIVNA_VISINA
		var obrni_h: bool = gora.get("flip_h", false)

		var tocke := PackedVector2Array()
		for tocka in GORA_PODNOZJE_TOCKE:
			var dx := tocka.x * scale_x
			if obrni_h:
				dx = -dx
			tocke.append(sidro + Vector2(dx, tocka.y * scale_y))

		sidra.append(sidro)
		tocke_na_goro.append(tocke)

	# Preprosto združevanje po bližini (union-find): dve gori sta v isti
	# skupini, če sta njuni sidri bližje od GORA_ZDRUZI_RAZDALJA.
	var n := sidra.size()
	var starsi: Array[int] = []
	for i in range(n):
		starsi.append(i)

	var najdi_koren := func(i: int) -> int:
		while starsi[i] != i:
			i = starsi[i]
		return i

	for i in range(n):
		for j in range(i + 1, n):
			if sidra[i].distance_to(sidra[j]) <= GORA_ZDRUZI_RAZDALJA:
				var ki: int = najdi_koren.call(i)
				var kj: int = najdi_koren.call(j)
				if ki != kj:
					starsi[ki] = kj

	var skupine := {}
	for i in range(n):
		var koren: int = najdi_koren.call(i)
		if not skupine.has(koren):
			skupine[koren] = PackedVector2Array()
		for tocka in tocke_na_goro[i]:
			skupine[koren].append(tocka)

	var poligoni: Array = []
	for koren in skupine.keys():
		poligoni.append(Geometry2D.convex_hull(skupine[koren]))

	return poligoni


func _je_v_kateri_gori(tocka: Vector2, gorski_poligoni: Array) -> bool:
	for poligon in gorski_poligoni:
		if Geometry2D.is_point_in_polygon(tocka, poligon):
			return true
	return false


func _dodaj_gorske_ovire(ovire: Node2D, gorski_poligoni: Array) -> void:
	for poligon in gorski_poligoni:
		var telo := StaticBody2D.new()
		telo.collision_layer = 1
		telo.collision_mask = 0

		var oblika := CollisionPolygon2D.new()
		# Poligon je že v svetovnih koordinatah, telo pa ostane na (0,0)
		# (privzeta pozicija) - IgralneOvire in Main sta oba brez lastnega
		# premika, zato se svetovne in lokalne koordinate tu ujemajo.
		oblika.polygon = poligon
		telo.add_child(oblika)
		ovire.add_child(telo)


# Pripravi podatke za navigacijsko mrežo. Upošteva samo fizični sloj 1
# (teren, viri, stavbe in obzidje). Vrata so namenoma na sloju 32 in jih
# mreža ne izreže kot polno steno; igralčeve enote lahko zato pot načrtujejo
# skozi njihov sredinski prehod. Sovražne enote vrata še vedno zadenejo po
# fiziki, ker njihov collision_mask vključuje sloj 32.
func _pripravi_navigacijsko_pecenje() -> Array:
	var nav_poligon := NavigationPolygon.new()
	nav_poligon.agent_radius = 16.0
	nav_poligon.add_outline(KOPNI_DIAMANT)
	nav_poligon.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poligon.parsed_collision_mask = 1
	nav_poligon.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN

	var izvorni_podatki := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(nav_poligon, izvorni_podatki, self)
	return [nav_poligon, izvorni_podatki]


func _namesti_navigacijski_poligon(nav_poligon: NavigationPolygon) -> void:
	var stara_mreza = get_node_or_null("IgralnaMreza")
	if stara_mreza:
		remove_child(stara_mreza)
		stara_mreza.free()

	var mreza := NavigationRegion2D.new()
	mreza.name = "IgralnaMreza"
	mreza.navigation_polygon = nav_poligon
	add_child(mreza)
	move_child(mreza, 0)


# Začetna sinhrona izdelava se izvede samo med nalaganjem igre, preden igralec
# začne igrati. Med gradnjo se uporablja spodnja asinhrona različica.
func _zgradi_navigacijsko_mrezo() -> void:
	var pripravljeno = _pripravi_navigacijsko_pecenje()
	var nav_poligon: NavigationPolygon = pripravljeno[0]
	var izvorni_podatki: NavigationMeshSourceGeometryData2D = pripravljeno[1]
	NavigationServer2D.bake_from_source_geometry_data(nav_poligon, izvorni_podatki)
	_namesti_navigacijski_poligon(nav_poligon)


# Peka navigacijske mreže je bila največji preostali razlog za kratek zastoj.
# Klici se še vedno združijo, težko pečenje pa zdaj teče v ozadju. Stara
# veljavna mreža ostane aktivna, dokler nova ni dokončana.
func _zahtevaj_posodobitev_navigacije() -> void:
	if _navigacija_posodobitev_timer == null or not is_instance_valid(_navigacija_posodobitev_timer):
		_navigacija_posodobitev_timer = Timer.new()
		_navigacija_posodobitev_timer.one_shot = true
		_navigacija_posodobitev_timer.wait_time = 0.45
		_navigacija_posodobitev_timer.timeout.connect(_izvedi_zakasnjeno_posodobitev_navigacije)
		add_child(_navigacija_posodobitev_timer)
	_navigacija_posodobitev_timer.start()


func _izvedi_zakasnjeno_posodobitev_navigacije() -> void:
	if _navigacija_pecenje_v_teku:
		_navigacija_ponovi_po_pecenju = true
		return

	var pripravljeno = _pripravi_navigacijsko_pecenje()
	_navigacija_poligon_v_pecenju = pripravljeno[0]
	_navigacija_izvor_v_pecenju = pripravljeno[1]
	_navigacija_pecenje_v_teku = true
	NavigationServer2D.bake_from_source_geometry_data_async(
		_navigacija_poligon_v_pecenju,
		_navigacija_izvor_v_pecenju,
		Callable(self, "_navigacija_asinhrono_koncana")
	)


func _navigacija_asinhrono_koncana() -> void:
	if _navigacija_poligon_v_pecenju != null:
		_namesti_navigacijski_poligon(_navigacija_poligon_v_pecenju)
	_navigacija_poligon_v_pecenju = null
	_navigacija_izvor_v_pecenju = null
	_navigacija_pecenje_v_teku = false

	if _navigacija_ponovi_po_pecenju:
		_navigacija_ponovi_po_pecenju = false
		call_deferred("_izvedi_zakasnjeno_posodobitev_navigacije")



func _dodaj_test_surovine():
	resources["WOOD"] += 2000
	resources["STONE"] += 2000
	resources["GOLD"] += 2000
	resources["FOOD"] += 2000
	update_ui()
	_posodobi_stolp_gumb()
	_posodobi_glavna_hisa_gumb()
	print("TEST: dodane surovine")


func _on_ai_pavza_button_pressed():
	var ai = get_tree().get_first_node_in_group("ai_controller")
	if ai:
		ai.ai_pavziran = not ai.ai_pavziran
		debug_label.text = "AI PAVZIRAN" if ai.ai_pavziran else "AI AKTIVEN"
		print("AI pavziran: ", ai.ai_pavziran)


func igra_konec(zmaga: bool):

	if igra_koncana:
		return

	igra_koncana = true

	game_over_label.text = "ZMAGA!" if zmaga else "PORAZ"
	game_over_label.visible = true

	get_tree().paused = true


func _on_pause_button_pressed():
	if igra_koncana:
		return
	pause_menu.visible = true
	get_tree().paused = true


func _on_nadaljuj_button_pressed():
	pause_menu.visible = false
	get_tree().paused = false


func _on_izhod_button_pressed():
	shrani_igro()
	get_tree().quit()


func posodobi_cudo_stevec(_cas: float):
	pass


func _ready():
	add_to_group("main_script")

	if has_node("CanvasLayer/Minimap"):
		$CanvasLayer/Minimap.world_rect = Rect2(0, 0, 12800, 6500)

	oddajne_zgradbe["WOOD"]["scene"] = drvarnica_scene
	oddajne_zgradbe["STONE"]["scene"] = kamnolom_scene
	oddajne_zgradbe["GOLD"]["scene"] = rudnik_scene
	oddajne_zgradbe["FOOD"]["scene"] = kmetija_scene

	update_ui()
	_posodobi_stolp_gumb()
	_pripravi_ikonske_gumbe()

	$CanvasLayer/PanelGlavnaHisa/ButtonHisa.pressed.connect(_on_build_button_pressed)

	nalozi_igro()
	_posodobi_nadgradnja_ui()

	var drevesa_timer = Timer.new()
	drevesa_timer.wait_time = 0.2
	drevesa_timer.autostart = true
	drevesa_timer.timeout.connect(_posodobi_prosojnost_dreves)
	add_child(drevesa_timer)


# Približna "polovična velikost" (half-extent) zgradbe/enote za bolj
# natančno preverjanje vizualnega prekrivanja z drevesom kot zgolj razdalja
# med središčema - pomembno za velike zgradbe (npr. obzidje), kjer je
# središče lahko daleč od točke, kjer se sličica dejansko vidno prekriva z
# drevesom. Uporabi dejansko velikost prikazane sličice (Sprite2D), ne
# kolizijske oblike, ker gre tu za vizualni (ne fizični) učinek.
func _priblizna_polovicna_velikost(p) -> Vector2:
	for otrok in p.get_children():
		if otrok is Sprite2D and otrok.texture:
			return (otrok.texture.get_size() * otrok.global_scale) * 0.5
	return Vector2(30, 30)


# Svetovni pravokotnik DEJANSKE prikazane sličice. Upošteva položaj sličice
# nad korensko točko zgradbe (npr. krošnja ali visoka hiša), česar stari
# izračun samo po razdalji med korenoma ni poznal.
func _vizualni_svetovni_pravokotnik(objekt) -> Rect2:
	if not is_instance_valid(objekt):
		return Rect2()
	# Glavna baza je sama Sprite2D, druge zgradbe pa imajo Sprite2D kot otroka.
	# Prej korenska slika baze ni bila pregledana, zato jo je bilo mogoče
	# izbrati le v majhnem 60 x 60 območju okoli talne točke.
	var sprite_kandidati: Array = [objekt]
	sprite_kandidati.append_array(objekt.get_children())
	for sprite in sprite_kandidati:
		if sprite is Sprite2D and sprite.texture != null:
			var velikost = sprite.texture.get_size()
			var zacetek = sprite.offset - velikost * 0.5 if sprite.centered else sprite.offset
			var koti = [
				sprite.to_global(zacetek),
				sprite.to_global(zacetek + Vector2(velikost.x, 0)),
				sprite.to_global(zacetek + velikost),
				sprite.to_global(zacetek + Vector2(0, velikost.y)),
			]
			var min_x = koti[0].x
			var max_x = koti[0].x
			var min_y = koti[0].y
			var max_y = koti[0].y
			for kot in koti:
				min_x = min(min_x, kot.x)
				max_x = max(max_x, kot.x)
				min_y = min(min_y, kot.y)
				max_y = max(max_y, kot.y)
			return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	return Rect2(objekt.global_position - Vector2(30, 30), Vector2(60, 60))


# Mere PackedScene se med premikanjem predogleda ne spreminjajo. Prej je bila
# scena za vsak preverjeni zid in skoraj vsak okvir na novo instantiate/free,
# kar je povzročalo opazne mikro-zastoje. Zdaj vsako smer izmerimo samo enkrat.
func _meritve_scene(scena: PackedScene, smer: String = "") -> Dictionary:
	if scena == null:
		return {"lokalni_rect": Rect2(-40, -40, 80, 80), "polovicna": Vector2(40, 40), "kolizijski_polmer": 45.0}
	var dejanska_smer = smer if smer != "" else smer_gradnje
	var kljuc = scena.resource_path + ":" + dejanska_smer
	if _scena_meritve_cache.has(kljuc):
		return _scena_meritve_cache[kljuc]

	var zacasna = scena.instantiate()
	if zacasna.has_method("nastavi_smer"):
		zacasna.nastavi_smer(dejanska_smer)
	var lokalni_rect = Rect2(-40, -40, 80, 80)
	for otrok in zacasna.get_children():
		if otrok is Sprite2D and otrok.texture != null:
			var merilo = (otrok.scale * zacasna.scale).abs()
			var velikost = otrok.texture.get_size() * merilo
			var sredina = (otrok.position + otrok.offset) * zacasna.scale
			lokalni_rect = Rect2(sredina - velikost * 0.5, velikost)
			break
	var rezultat = {
		"lokalni_rect": lokalni_rect,
		"polovicna": lokalni_rect.size * 0.5,
		"kolizijski_polmer": _kolizijski_polmer(zacasna),
	}
	zacasna.free()
	_scena_meritve_cache[kljuc] = rezultat
	return rezultat


# Enak pravokotnik za zgradbo, ki še ni dodana v sceno.
func _vizualni_pravokotnik_scene_na(scena: PackedScene, pozicija: Vector2, smer: String = "") -> Rect2:
	var lokalni_rect: Rect2 = _meritve_scene(scena, smer)["lokalni_rect"]
	return Rect2(pozicija + lokalni_rect.position, lokalni_rect.size)


func _glavna_slicica(objekt) -> Sprite2D:
	if not is_instance_valid(objekt):
		return null
	for otrok in objekt.get_children():
		if otrok is Sprite2D and otrok.texture != null:
			return otrok
	return null


# Pretvori samo DEJANSKI svetovni presek med virom in stavbo/enoto v UV
# pravokotnik sličice vira. Tako shader prosoji samo zakriti košček krošnje,
# kamna ali drugega vira, preostanek pa ostane popolnoma viden.
func _uv_prekrivanje_za(sprite: Sprite2D, vir_rect: Rect2, objekt_rect: Rect2):
	var levo = max(vir_rect.position.x, objekt_rect.position.x)
	var zgoraj = max(vir_rect.position.y, objekt_rect.position.y)
	var desno = min(vir_rect.end.x, objekt_rect.end.x)
	var spodaj = min(vir_rect.end.y, objekt_rect.end.y)
	if desno <= levo or spodaj <= zgoraj:
		return null

	var svetovni_koti = [
		Vector2(levo, zgoraj), Vector2(desno, zgoraj),
		Vector2(desno, spodaj), Vector2(levo, spodaj),
	]
	var lokalni_prvi = sprite.to_local(svetovni_koti[0])
	var min_x = lokalni_prvi.x
	var max_x = lokalni_prvi.x
	var min_y = lokalni_prvi.y
	var max_y = lokalni_prvi.y
	for svetovni_kot in svetovni_koti:
		var lokalni = sprite.to_local(svetovni_kot)
		min_x = min(min_x, lokalni.x)
		max_x = max(max_x, lokalni.x)
		min_y = min(min_y, lokalni.y)
		max_y = max(max_y, lokalni.y)

	var velikost = sprite.texture.get_size()
	if velikost.x <= 0.0 or velikost.y <= 0.0:
		return null
	var zacetek = sprite.offset - velikost * 0.5 if sprite.centered else sprite.offset
	var uv_min = Vector2(
		clamp((min_x - zacetek.x) / velikost.x, 0.0, 1.0),
		clamp((min_y - zacetek.y) / velikost.y, 0.0, 1.0)
	)
	var uv_max = Vector2(
		clamp((max_x - zacetek.x) / velikost.x, 0.0, 1.0),
		clamp((max_y - zacetek.y) / velikost.y, 0.0, 1.0)
	)
	if uv_max.x - uv_min.x < 0.005 or uv_max.y - uv_min.y < 0.005:
		return null
	return Vector4(uv_min.x, uv_min.y, uv_max.x - uv_min.x, uv_max.y - uv_min.y)


func _material_lokalne_prosojnosti(sprite: Sprite2D) -> ShaderMaterial:
	if sprite.material is ShaderMaterial and sprite.material.shader == VIR_LOKALNA_PROSOJNOST_SHADER:
		return sprite.material
	var material = ShaderMaterial.new()
	material.shader = VIR_LOKALNA_PROSOJNOST_SHADER
	material.set_shader_parameter("alfa_pod_objektom", 0.38)
	material.set_shader_parameter("mehak_rob", 0.30)
	sprite.material = material
	return material


func _posodobi_prosojnost_dreves():
	var pomembni = []
	pomembni += get_tree().get_nodes_in_group("delavci")
	pomembni += get_tree().get_nodes_in_group("enote")
	pomembni += get_tree().get_nodes_in_group("zgradbe")
	pomembni += get_tree().get_nodes_in_group("ai_delavci")
	pomembni += get_tree().get_nodes_in_group("ai_enote")
	pomembni += get_tree().get_nodes_in_group("ai_zgradbe")

	var gh = get_tree().get_first_node_in_group("glavna_hisa")
	if gh:
		pomembni.append(gh)
	var ai = get_tree().get_first_node_in_group("ai_baza")
	if ai:
		pomembni.append(ai)

	# Namesto pregleda VSEH virov petkrat na sekundo obrnemo iskanje: za
	# vsako pomembno stavbo/enoto pogledamo samo vire v bližnjih prostorskih
	# celicah. To prepreči, da bi novi vizualni učinek sam povzročal zatikanje.
	var nova_prekrivanja: Dictionary = {}
	var ze_obravnavani_objekti: Dictionary = {}
	for p in pomembni:
		if not is_instance_valid(p):
			continue
		var p_id = p.get_instance_id()
		if ze_obravnavani_objekti.has(p_id):
			continue
		ze_obravnavani_objekti[p_id] = true
		var objekt_rect = _vizualni_svetovni_pravokotnik(p).grow(4.0)
		var iskalni_doseg = max(objekt_rect.size.x, objekt_rect.size.y) * 0.75 + 520.0
		for vir in _viri_blizu(objekt_rect.get_center(), iskalni_doseg):
			if not is_instance_valid(vir) or vir == p:
				continue
			var sprite = _glavna_slicica(vir)
			if sprite == null:
				continue
			var vir_rect = _vizualni_svetovni_pravokotnik(vir)
			var uv_rect = _uv_prekrivanje_za(sprite, vir_rect, objekt_rect)
			if uv_rect == null:
				continue
			var vir_id = vir.get_instance_id()
			if not nova_prekrivanja.has(vir_id):
				nova_prekrivanja[vir_id] = {"vir": vir, "sprite": sprite, "recti": []}
			var recti: Array = nova_prekrivanja[vir_id]["recti"]
			if recti.size() < 8:
				recti.append(uv_rect)

	# Viri, ki niso več prekriti, takoj dobijo nazaj polno sličico.
	for vir_id in _aktivni_lokalno_prosojni_viri.keys():
		if nova_prekrivanja.has(vir_id):
			continue
		var stari_podatki = _aktivni_lokalno_prosojni_viri[vir_id]
		var stari_vir = stari_podatki["vir"]
		var stari_sprite = stari_podatki["sprite"]
		if is_instance_valid(stari_vir):
			stari_vir.modulate.a = 1.0
		if is_instance_valid(stari_sprite) and stari_sprite.material is ShaderMaterial:
			for i in range(8):
				stari_sprite.material.set_shader_parameter("prekrivanje_" + str(i), Vector4(-2.0, -2.0, -1.0, -1.0))

	for vir_id in nova_prekrivanja.keys():
		var podatki = nova_prekrivanja[vir_id]
		var vir = podatki["vir"]
		var sprite = podatki["sprite"]
		var recti: Array = podatki["recti"]
		vir.modulate.a = 1.0
		var material = _material_lokalne_prosojnosti(sprite)
		for i in range(8):
			var vrednost = recti[i] if i < recti.size() else Vector4(-2.0, -2.0, -1.0, -1.0)
			material.set_shader_parameter("prekrivanje_" + str(i), vrednost)

	_aktivni_lokalno_prosojni_viri = nova_prekrivanja


func shrani_igro():

	var podatki = {
		"map_version": MAP_VERSION,
		"resources": resources,
		"current_pop": current_pop,
		"max_pop": max_pop,
		"glavna_stavba_level": glavna_stavba_level,
		"vojasnica_level": vojasnica_level,
		"obzidje_level": obzidje_level,
		"stolp_level": stolp_level,
		"vojaska_populacija": vojaska_populacija,
		"max_vojaska_populacija": max_vojaska_populacija,
		"stevilo_polj": stevilo_polj,
		"stevilo_vojasnic": stevilo_vojasnic,
		"stevilo_zidov": stevilo_zidov,
		"stevilo_stolpov": stevilo_stolpov,
		"glavna_hisa_hp": 0,
		"glavna_v_nadgradnji": false,
		"glavna_nadgradnja_cilj": 0,
		"glavna_nadgradnja_timer": 0.0,
		"glavna_nadgradnja_cas": 0.0,
		"glavna_ima_rally": false,
		"glavna_rally_x": 0.0,
		"glavna_rally_y": 0.0,
		"glavna_rally_spawn_index": 0,
		"glavna_current_type": glavna_current_type,
		"glavna_production_timer": glavna_production_timer,
		"glavna_production_queue": glavna_production_queue,
		"fog_explored": "",
		"zgradbe": [],
		"delavci": [],
		"enote": [],
	}

	var gh = get_tree().get_first_node_in_group("glavna_hisa")
	if gh:
		podatki["glavna_hisa_hp"] = gh.hp
		podatki["glavna_v_nadgradnji"] = gh.v_nadgradnji
		podatki["glavna_nadgradnja_cilj"] = gh.nadgradnja_ciljni_nivo
		podatki["glavna_nadgradnja_timer"] = gh.nadgradnja_timer
		podatki["glavna_nadgradnja_cas"] = gh.nadgradnja_cas
		podatki["glavna_ima_rally"] = gh.ima_rally_tocko
		podatki["glavna_rally_x"] = gh.rally_point.x
		podatki["glavna_rally_y"] = gh.rally_point.y
		podatki["glavna_rally_spawn_index"] = gh.rally_spawn_index

	for z in get_tree().get_nodes_in_group("zgradbe"):
		if not is_instance_valid(z):
			continue
		var podatki_zgradbe = {
			"tip": z.tip_zgradbe,
			"nivo": z.nivo_zgradbe if "nivo_zgradbe" in z else 1,
			"x": z.global_position.x,
			"y": z.global_position.y,
			"hp": z.hp,
			"max_hp": z.max_hp,
			"v_gradnji": z.v_gradnji,
			"gradnja_timer": z.gradnja_timer,
			"smer": z.smer_zgradbe if "smer_zgradbe" in z else "jug",
			"v_nadgradnji": z.v_nadgradnji if "v_nadgradnji" in z else false,
			"nadgradnja_cilj": z.nadgradnja_ciljni_nivo if "nadgradnja_ciljni_nivo" in z else 0,
			"nadgradnja_timer": z.nadgradnja_timer if "nadgradnja_timer" in z else 0.0,
			"nadgradnja_cas": z.nadgradnja_cas if "nadgradnja_cas" in z else 0.0,
			"ima_rally": z.ima_rally_tocko if "ima_rally_tocko" in z else false,
			"rally_x": z.rally_point.x if "rally_point" in z else 0.0,
			"rally_y": z.rally_point.y if "rally_point" in z else 0.0,
			"rally_spawn_index": z.rally_spawn_index if "rally_spawn_index" in z else 0,
		}
		if z.tip_zgradbe == "polje" and "zetveni_napredek" in z:
			podatki_zgradbe["zetveni_napredek"] = z.zetveni_napredek
			podatki_zgradbe["zraslo"] = z.zraslo
		if z.tip_zgradbe == "vojasnica" and z.has_method("stevilo_narocil"):
			podatki_zgradbe["production_current"] = z.current_unit_type
			podatki_zgradbe["production_timer"] = z.timer
			podatki_zgradbe["production_queue"] = z.production_queue
		podatki["zgradbe"].append(podatki_zgradbe)

	for w in get_tree().get_nodes_in_group("delavci"):
		if not is_instance_valid(w):
			continue
		podatki["delavci"].append({
			"x": w.global_position.x,
			"y": w.global_position.y,
			"hp": w.hp,
		})

	for u in get_tree().get_nodes_in_group("enote"):
		if not is_instance_valid(u):
			continue
		podatki["enote"].append({
			"ime": u.enota_ime,
			"x": u.global_position.x,
			"y": u.global_position.y,
			"hp": u.hp,
			"max_hp": u.max_hp,
			"damage": u.damage,
			"attack_range": u.attack_range,
			"speed": u.speed,
			"populacija_cena": u.populacija_cena,
		})

	var fog = get_node_or_null("FogOfWar")
	if is_instance_valid(fog) and fog.has_method("export_explored_base64"):
		podatki["fog_explored"] = fog.export_explored_base64()

	var datoteka = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if datoteka:
		datoteka.store_string(JSON.stringify(podatki))
		datoteka.close()
		print("Igra shranjena")


func nalozi_igro():

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var datoteka = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not datoteka:
		return

	var json_niz = datoteka.get_as_text()
	datoteka.close()

	var json = JSON.new()
	if json.parse(json_niz) != OK:
		print("Napaka pri branju shranjene igre")
		return

	var podatki = json.get_data()

	# Stara shranjena igra uporablja koordinate prejšnje mape in je zato ne
	# nalagamo na novo postavitev.
	if int(podatki.get("map_version", 0)) != MAP_VERSION:
		print("Stara shranjena igra ni združljiva z novo mapo")
		return

	for w in get_tree().get_nodes_in_group("delavci"):
		w.queue_free()

	resources = podatki["resources"]
	current_pop = podatki["current_pop"]
	max_pop = podatki["max_pop"]
	# Skupne vrednosti ostanejo samo za združljivost s starejšimi shranjenimi
	# igrami. Od te različice naprej ima vsaka postavljena stavba svoj nivo.
	glavna_stavba_level = int(podatki.get("glavna_stavba_level", 1))
	var stari_vojasnica_level := int(podatki.get("vojasnica_level", 1))
	var stari_obzidje_level := int(podatki.get("obzidje_level", 1))
	var stari_stolp_level := int(podatki.get("stolp_level", 1))
	vojasnica_level = 0
	obzidje_level = 1
	stolp_level = 1
	vojaska_populacija = podatki["vojaska_populacija"]
	max_vojaska_populacija = podatki["max_vojaska_populacija"]
	stevilo_polj = podatki["stevilo_polj"]
	stevilo_vojasnic = podatki["stevilo_vojasnic"]
	stevilo_zidov = podatki["stevilo_zidov"]
	stevilo_stolpov = podatki["stevilo_stolpov"]
	glavna_production_queue.clear()
	for narocilo in podatki.get("glavna_production_queue", []):
		glavna_production_queue.append(str(narocilo))
	glavna_current_type = str(podatki.get("glavna_current_type", ""))
	glavna_production_timer = maxf(0.0, float(podatki.get("glavna_production_timer", 0.0)))
	poveljnik_producing = glavna_current_type == "POGLAVAR"
	poveljnik_timer = glavna_production_timer if poveljnik_producing else 0.0
	if glavna_current_type.is_empty() and not glavna_production_queue.is_empty():
		_zacni_naslednjo_glavna()

	var gh = get_tree().get_first_node_in_group("glavna_hisa")
	if gh and podatki.has("glavna_hisa_hp"):
		gh.hp = podatki["glavna_hisa_hp"]

	var scena_za_tip = {
		"drvarnica": drvarnica_scene,
		"kamnolom": kamnolom_scene,
		"rudnik": rudnik_scene,
		"kmetija": kmetija_scene,
		"hisa": hisa_scene,
		"obzidje": obzidje_scene,
		"vrata": vrata_scene,
		"vojasnica": vojasnica_scene,
		"polje": polje_scene,
		"stolp": stolp_scene,
	}

	var tip_v_resurs = {"drvarnica": "WOOD", "kamnolom": "STONE", "rudnik": "GOLD", "kmetija": "FOOD"}

	for z_podatki in podatki["zgradbe"]:

		var tip = z_podatki["tip"]
		if not scena_za_tip.has(tip):
			continue

		var nova = scena_za_tip[tip].instantiate()
		var privzeti_nivo := 1
		match tip:
			"vojasnica":
				privzeti_nivo = stari_vojasnica_level
			"obzidje", "vrata":
				privzeti_nivo = stari_obzidje_level
			"stolp":
				privzeti_nivo = stari_stolp_level
		var nivo_stavbe := clampi(int(z_podatki.get("nivo", privzeti_nivo)), 1, 3)
		nova.global_position = Vector2(z_podatki["x"], z_podatki["y"])
		if tip == "obzidje" or tip == "vrata":
			nova.max_hp = obzidje_hp_po_levelu[nivo_stavbe]
		elif tip == "stolp":
			nova.max_hp = stolp_hp_po_levelu[nivo_stavbe]
			nova.damage = stolp_damage_po_levelu[nivo_stavbe]
			nova.attack_range = stolp_range_po_levelu[nivo_stavbe]
		else:
			nova.max_hp = z_podatki["max_hp"]
		add_child(nova)
		nova.prikazi_nivo(nivo_stavbe)
		if nova.has_method("nastavi_smer"):
			nova.nastavi_smer(str(z_podatki.get("smer", "jug")))
		nova.hp = mini(int(z_podatki["hp"]), nova.max_hp)
		nova.v_gradnji = z_podatki.get("v_gradnji", false)
		nova.gradnja_timer = z_podatki.get("gradnja_timer", 0.0)
		nova.modulate.a = 0.5 if nova.v_gradnji else 1.0
		if bool(z_podatki.get("v_nadgradnji", false)):
			nova.obnovi_nadgradnjo(
				int(z_podatki.get("nadgradnja_cilj", nivo_stavbe + 1)),
				float(z_podatki.get("nadgradnja_timer", 0.0)),
				float(z_podatki.get("nadgradnja_cas", 1.0))
			)
		if bool(z_podatki.get("ima_rally", false)):
			nova.rally_point = Vector2(float(z_podatki.get("rally_x", 0.0)), float(z_podatki.get("rally_y", 0.0)))
			nova.ima_rally_tocko = true
			nova.rally_spawn_index = int(z_podatki.get("rally_spawn_index", 0))
			_ustvari_rally_zastavico(nova, nova.rally_point)

		if tip == "polje":
			nova.zetveni_napredek = float(z_podatki.get("zetveni_napredek", 0.0))
			nova.zraslo = bool(z_podatki.get("zraslo", false))
			if nova.zraslo:
				nova._ob_koncu_gradnje()

		if tip == "vojasnica":
			nova.production_queue.clear()
			for narocilo in z_podatki.get("production_queue", []):
				nova.production_queue.append(str(narocilo))
			nova.current_unit_type = str(z_podatki.get("production_current", ""))
			nova.timer = maxf(0.0, float(z_podatki.get("production_timer", 0.0)))
			nova.producing = not nova.current_unit_type.is_empty()
			if not nova.producing and not nova.production_queue.is_empty():
				nova._zacni_naslednjo()
			vojasnica_ref = nova
			vojasnica_level = nivo_stavbe

		if tip == "obzidje" or tip == "vrata":
			nova.add_to_group("obzidje")
			stevilo_zidov += 1

		if tip == "stolp":
			nova.add_to_group("stolpi")
			stevilo_stolpov += 1

		if tip_v_resurs.has(tip):
			nova.add_to_group(tip)
			oddajne_zgradbe[tip_v_resurs[tip]]["count"] += 1

	for d_podatki in podatki["delavci"]:
		var nov = delavec_scene.instantiate()
		nov.global_position = Vector2(d_podatki["x"], d_podatki["y"])
		add_child(nov)
		nov.hp = d_podatki["hp"]

	var enota_scena_za_ime = {
		"Bojevnik": bojevnik_scene,
		"Suličar": bojevnik_scene,
		"Kopjenik": kopjenik_scene,
		"Sekiraš": kopjenik_scene,
		"Kijač": teska_enota_scene,
		"Poveljnik": poveljnik_scene,
	}

	for e_podatki in podatki["enote"]:

		var ime = e_podatki["ime"]
		if not enota_scena_za_ime.has(ime):
			continue

		var nova_enota = enota_scena_za_ime[ime].instantiate()
		nova_enota.global_position = Vector2(e_podatki["x"], e_podatki["y"])
		nova_enota.max_hp = e_podatki["max_hp"]
		nova_enota.damage = e_podatki["damage"]
		nova_enota.attack_range = e_podatki["attack_range"]
		nova_enota.speed = e_podatki["speed"]
		nova_enota.populacija_cena = e_podatki["populacija_cena"]
		add_child(nova_enota)
		nova_enota.hp = e_podatki["hp"]

	var gh_load = get_tree().get_first_node_in_group("glavna_hisa")
	if gh_load:
		gh_load.prikazi_nivo(glavna_stavba_level)
		if bool(podatki.get("glavna_v_nadgradnji", false)):
			gh_load.obnovi_nadgradnjo(
				int(podatki.get("glavna_nadgradnja_cilj", glavna_stavba_level + 1)),
				float(podatki.get("glavna_nadgradnja_timer", 0.0)),
				float(podatki.get("glavna_nadgradnja_cas", 1.0))
			)
		if bool(podatki.get("glavna_ima_rally", false)):
			gh_load.rally_point = Vector2(float(podatki.get("glavna_rally_x", 0.0)), float(podatki.get("glavna_rally_y", 0.0)))
			gh_load.ima_rally_tocko = true
			gh_load.rally_spawn_index = int(podatki.get("glavna_rally_spawn_index", 0))
			_ustvari_rally_zastavico(gh_load, gh_load.rally_point)
	_posodobi_glavna_hisa_gumb()

	posodobi_max_vojasko_populacijo()

	var fog = get_node_or_null("FogOfWar")
	if is_instance_valid(fog) and fog.has_method("restore_explored_base64"):
		fog.restore_explored_base64(str(podatki.get("fog_explored", "")))

	# Naložene zgradbe so bile dodane PO začetnem izgradu navigacijske mreže
	# (glej klic v _ready()), zato mreža sama še ne "ve" zanje - brez tega bi
	# se enote v naloženi igri zaletavale/zatikale v vsako naloženo zgradbo.
	_zgradi_navigacijsko_mrezo()

	update_ui()

	print("Igra naložena (OPOMBA: AI se vedno začne na novo)")


func _napredek_besedilo(objekt):

	var besedilo = ""

	if "tip_zgradbe" in objekt:
		if "nivo_zgradbe" in objekt and objekt.tip_zgradbe in ["vojasnica", "obzidje", "vrata", "stolp"]:
			besedilo += " | Level %d" % objekt.nivo_zgradbe

	if objekt.is_in_group("glavna_hisa"):
		besedilo += " | Level %d" % (objekt.nivo_zgradbe if "nivo_zgradbe" in objekt else glavna_stavba_level)

	if "v_nadgradnji" in objekt and objekt.v_nadgradnji:
		besedilo += " | NADGRADNJA NA NIVO %d: še %ds" % [
			objekt.nadgradnja_ciljni_nivo, int(ceil(objekt.preostanek_nadgradnje()))
		]
		return besedilo

	if "v_gradnji" in objekt and objekt.v_gradnji:
		besedilo += " | V GRADNJI: %d/%ds" % [int(objekt.gradnja_timer), int(objekt.cas_gradnje)]
		return besedilo

	if "producing" in objekt and objekt.producing:
		besedilo += " | Izdeluje %s: %d/%ds" % [objekt.current_unit_type, int(objekt.timer), int(objekt.production_time)]
		return besedilo

	if objekt.is_in_group("glavna_hisa") and poveljnik_producing:
		besedilo += " | Izdeluje poveljnika: %d/%ds" % [int(poveljnik_timer), int(poveljnik_cas_izdelave)]
		return besedilo

	if "cas_zetve" in objekt and "zetveni_napredek" in objekt:
		var preostalo = max(0.0, objekt.cas_zetve - objekt.zetveni_napredek)
		besedilo += " | Žetev čez: %ds" % [int(ceil(preostalo))]
		return besedilo

	return besedilo


func update_ui():
	resource_label.text = "Les: %d | Kamen: %d | Zlato: %d | Hrana: %d | Pop: %d/%d | Vojska: %d/%d" % [
		resources["WOOD"],
		resources["STONE"],
		resources["GOLD"],
		resources["FOOD"],
		current_pop,
		max_pop,
		vojaska_populacija,
		max_vojaska_populacija
	]


func _pripravi_ikonske_gumbe() -> void:
	_ikone_po_tipu = {
		"DELAVEC": load("res://assets/ui_icons/delavec.png"),
		"POGLAVAR": load("res://assets/ui_icons/poglavar.png"),
		"BOJEVNIK": load("res://assets/ui_icons/sulicar.png"),
		"KOPJENIK": load("res://assets/ui_icons/sekiras.png"),
		"TESKA": load("res://assets/ui_icons/kijac.png"),
	}
	var nastavitve := [
		[$CanvasLayer/PanelDelavec/ButtonDrvarnica, "res://assets/ui_icons/drvarnica.png", "Drvarnica", "", {"WOOD": 50}],
		[$CanvasLayer/PanelDelavec/ButtonKamnolom, "res://assets/ui_icons/kamnolom.png", "Kamnolom", "", {"WOOD": 50}],
		[$CanvasLayer/PanelDelavec/ButtonRudnik, "res://assets/ui_icons/rudnik.png", "Rudnik zlata", "", {"WOOD": 50}],
		[$CanvasLayer/PanelDelavec/ButtonKmetija, "res://assets/ui_icons/kmetija.png", "Kmetija", "", {"WOOD": 50}],
		[$CanvasLayer/PanelDelavec/ButtonVojasnica, "res://assets/ui_icons/vojasnica.png", "Vojašnica", "", {"STONE": 50}],
		[$CanvasLayer/PanelDelavec/ButtonObzidje, "res://assets/ui_icons/obzidje.png", "Obzidje", "", cena_zidu],
		[$CanvasLayer/PanelDelavec/ButtonStolp, "res://assets/ui_icons/stolp.png", "Stolp", "", cena_stolpa],
		[$CanvasLayer/PanelDelavec/ButtonVrata, "res://assets/ui_icons/vrata.png", "Vrata", "", cena_zidu],
		[$CanvasLayer/PanelVojasnica/ButtonBojevnik, "res://assets/ui_icons/sulicar.png", "Suličar", "BOJEVNIK"],
		[$CanvasLayer/PanelVojasnica/ButtonKopjenik, "res://assets/ui_icons/sekiras.png", "Sekiraš – potreben nivo 2", "KOPJENIK"],
		[$CanvasLayer/PanelVojasnica/ButtonTeska, "res://assets/ui_icons/kijac.png", "Kijač – potreben nivo 3", "TESKA"],
		[$CanvasLayer/PanelGlavnaHisa/ButtonDelavec, "res://assets/ui_icons/delavec.png", "Delavec – 10 hrane", "DELAVEC", {"FOOD": 10}],
		[$CanvasLayer/PanelGlavnaHisa/ButtonHisa, "res://assets/ui_icons/hisa.png", "Hiša – 50 lesa", "", {"WOOD": 50}],
		[$CanvasLayer/PanelGlavnaHisa/ButtonPoveljnik, "res://assets/ui_icons/poglavar.png", "Poglavar – glavna stavba nivo 3", "POGLAVAR"],
		[$CanvasLayer/PanelKmetija/ButtonPostaviPolje, "res://assets/ui_icons/polje.png", "Polje", "", {"WOOD": cena_polja}],
	]
	for podatki in nastavitve:
		_nastavi_ikonski_gumb(podatki[0], podatki[1], podatki[2], podatki[3])
		if podatki.size() >= 5:
			_dodaj_ceno_na_gumb(podatki[0], podatki[4])

	_nastavi_nadgradnja_ikonski_gumb(vojasnica_nadgradi_button, "res://assets/nadgradnje/vojasnica_nivo2_jug.png")
	_nastavi_nadgradnja_ikonski_gumb(glavna_hisa_nadgradi_button, "res://assets/nadgradnje/glavna_nivo2.png")
	_nastavi_nadgradnja_ikonski_gumb(stolp_nadgradi_button, "res://assets/nadgradnje/stolp_nivo2_jug.png")
	_nastavi_ikonski_gumb($CanvasLayer/PanelVojasnica/ButtonRallyVoj, "res://assets/ui_icons/rally_zastavica.png", "Postavi zbirno točko", "")
	_nastavi_ikonski_gumb($CanvasLayer/PanelGlavnaHisa/ButtonRallyGlavna, "res://assets/ui_icons/rally_zastavica.png", "Postavi zbirno točko", "")
	_nastavi_ikonski_gumb($CanvasLayer/PanelObzidje/ButtonNadgradiObzidje, "res://assets/ui_icons/obzidje.png", "Nadgradi obzidje", "")
	_queue_strip_vojska = _ustvari_queue_strip(panel_vojasnica)
	_queue_strip_glavna = _ustvari_queue_strip(panel_glavna_hisa)


func _nastavi_ikonski_gumb(gumb: Button, pot: String, opis: String, production_key: String) -> void:
	gumb.text = ""
	gumb.modulate = Color.WHITE
	gumb.icon = load(pot)
	gumb.expand_icon = true
	gumb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gumb.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	gumb.tooltip_text = opis
	gumb.clip_contents = true
	if production_key.is_empty(): return
	_ikonski_gumbi[production_key] = gumb
	var fill := ColorRect.new()
	fill.name = "ProductionFill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = Color(1.0, 0.78, 0.12, 0.34)
	fill.anchor_left = 0.0; fill.anchor_right = 1.0; fill.anchor_top = 1.0; fill.anchor_bottom = 1.0
	fill.offset_left = 0.0; fill.offset_right = 0.0; fill.offset_top = 0.0; fill.offset_bottom = 0.0
	fill.visible = false
	gumb.add_child(fill)
	_production_fill[production_key] = fill
	var stevec := Label.new()
	stevec.name = "QueueCount"
	stevec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stevec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stevec.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stevec.add_theme_font_size_override("font_size", 18)
	stevec.add_theme_color_override("font_color", Color.WHITE)
	stevec.add_theme_color_override("font_outline_color", Color.BLACK)
	stevec.add_theme_constant_override("outline_size", 5)
	stevec.anchor_left = 1.0; stevec.anchor_right = 1.0
	stevec.offset_left = -27.0; stevec.offset_right = -2.0; stevec.offset_top = 1.0; stevec.offset_bottom = 27.0
	stevec.visible = false
	gumb.add_child(stevec)
	_production_count[production_key] = stevec


func _dodaj_ceno_na_gumb(gumb: Button, cena: Dictionary) -> void:
	if cena.is_empty():
		return
	var ozadje := ColorRect.new()
	ozadje.name = "CenaOzadje"
	ozadje.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ozadje.color = Color(0.02, 0.02, 0.02, 0.82)
	ozadje.anchor_left = 0.0
	ozadje.anchor_right = 1.0
	ozadje.anchor_top = 1.0
	ozadje.anchor_bottom = 1.0
	ozadje.offset_top = -21.0
	ozadje.offset_bottom = 0.0
	gumb.add_child(ozadje)

	var vrstica := HBoxContainer.new()
	vrstica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vrstica.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vrstica.alignment = BoxContainer.ALIGNMENT_CENTER
	vrstica.add_theme_constant_override("separation", 4)
	ozadje.add_child(vrstica)
	var oznake := {"WOOD": "L", "STONE": "K", "GOLD": "Z", "FOOD": "H"}
	var barve := {
		"WOOD": Color(0.92, 0.66, 0.32), "STONE": Color(0.82, 0.86, 0.9),
		"GOLD": Color(1.0, 0.82, 0.18), "FOOD": Color(0.55, 1.0, 0.38),
	}
	for vir in ["WOOD", "STONE", "GOLD", "FOOD"]:
		if int(cena.get(vir, 0)) <= 0:
			continue
		var napis := Label.new()
		napis.text = "%s%d" % [oznake[vir], int(cena[vir])]
		napis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		napis.add_theme_font_size_override("font_size", 11)
		napis.add_theme_color_override("font_color", barve[vir])
		napis.add_theme_color_override("font_outline_color", Color.BLACK)
		napis.add_theme_constant_override("outline_size", 3)
		vrstica.add_child(napis)


func _nastavi_nadgradnja_ikonski_gumb(gumb: Button, zacetna_ikona: String) -> void:
	_nastavi_ikonski_gumb(gumb, zacetna_ikona, "Nadgradnja", "")
	var fill := ColorRect.new()
	fill.name = "UpgradeFill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = Color(0.22, 0.72, 1.0, 0.42)
	fill.anchor_left = 0.0
	fill.anchor_right = 1.0
	fill.anchor_top = 1.0
	fill.anchor_bottom = 1.0
	fill.visible = false
	gumb.add_child(fill)
	_nadgradnja_fill[gumb] = fill


func _ustvari_queue_strip(panel: Control) -> HBoxContainer:
	var vrstica := HBoxContainer.new()
	vrstica.name = "CakalnaVrsta"
	vrstica.position = Vector2(10, 100)
	vrstica.size = Vector2(620, 42)
	vrstica.add_theme_constant_override("separation", 4)
	vrstica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vrstica)
	return vrstica


func _nastavi_napredek_gumba(tip: String, kolicina: int, napredek: float, aktiven: bool) -> void:
	if not _production_count.has(tip): return
	var stevec: Label = _production_count[tip]
	stevec.text = str(kolicina)
	stevec.visible = kolicina > 0
	var fill: ColorRect = _production_fill[tip]
	fill.visible = aktiven
	fill.anchor_top = 1.0 - clampf(napredek, 0.0, 1.0)
	fill.offset_top = 0.0


func _posodobi_production_ui() -> void:
	var gh_cas := poveljnik_cas_izdelave if glavna_current_type == "POGLAVAR" else delavec_cas_izdelave
	var gh_napredek := glavna_production_timer / gh_cas if not glavna_current_type.is_empty() and gh_cas > 0.0 else 0.0
	_nastavi_napredek_gumba("DELAVEC", _glavna_stevilo_tipa("DELAVEC"), gh_napredek, glavna_current_type == "DELAVEC")
	_nastavi_napredek_gumba("POGLAVAR", _glavna_stevilo_tipa("POGLAVAR"), gh_napredek, glavna_current_type == "POGLAVAR")
	var glavna_vrsta: Array[String] = []
	if not glavna_current_type.is_empty(): glavna_vrsta.append(glavna_current_type)
	glavna_vrsta.append_array(glavna_production_queue)
	_osvezi_queue_strip(_queue_strip_glavna, glavna_vrsta, true)

	var proizvodna = selected_building if is_instance_valid(selected_building) and "tip_zgradbe" in selected_building and selected_building.tip_zgradbe == "vojasnica" else vojasnica_ref
	var voj_vrsta: Array[String] = []
	for tip in ["BOJEVNIK", "KOPJENIK", "TESKA"]:
		var kolicina: int = int(proizvodna.stevilo_tipa(tip)) if is_instance_valid(proizvodna) and proizvodna.has_method("stevilo_tipa") else 0
		var aktivna: bool = bool(is_instance_valid(proizvodna) and proizvodna.producing and proizvodna.current_unit_type == tip)
		var napredek: float = float(proizvodna.napredek_produkcije()) if aktivna else 0.0
		_nastavi_napredek_gumba(tip, kolicina, napredek, aktivna)
	if is_instance_valid(proizvodna):
		if proizvodna.producing: voj_vrsta.append(proizvodna.current_unit_type)
		voj_vrsta.append_array(proizvodna.production_queue)
	_osvezi_queue_strip(_queue_strip_vojska, voj_vrsta, false)


func _osvezi_queue_strip(vrstica: HBoxContainer, narocila: Array[String], glavna: bool) -> void:
	if not is_instance_valid(vrstica): return
	var podpis := ",".join(narocila)
	if glavna and podpis == _zadnji_queue_podpis_glavna: return
	if not glavna and podpis == _zadnji_queue_podpis_vojska: return
	if glavna: _zadnji_queue_podpis_glavna = podpis
	else: _zadnji_queue_podpis_vojska = podpis
	for otrok in vrstica.get_children(): otrok.queue_free()
	for tip in narocila:
		if not _ikone_po_tipu.has(tip): continue
		var ikona := TextureRect.new()
		ikona.custom_minimum_size = Vector2(38, 38)
		ikona.texture = _ikone_po_tipu[tip]
		ikona.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ikona.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ikona.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vrstica.add_child(ikona)


func posodobi_max_vojasko_populacijo():

	var iz_vojasnice := 0
	for stavba in get_tree().get_nodes_in_group("zgradbe"):
		if is_instance_valid(stavba) and "tip_zgradbe" in stavba and stavba.tip_zgradbe == "vojasnica":
			iz_vojasnice += 10 * (clampi(stavba.nivo_zgradbe, 1, 3) - 1)

	var nivo_baze := glavna_stavba_level
	var glavna = get_tree().get_first_node_in_group("glavna_hisa")
	if is_instance_valid(glavna) and "nivo_zgradbe" in glavna:
		nivo_baze = glavna.nivo_zgradbe
		glavna_stavba_level = nivo_baze

	max_vojaska_populacija = 25 + 15 * (nivo_baze - 1) + iz_vojasnice
	update_ui()


func _nivo_glavne_baze() -> int:
	var glavna = get_tree().get_first_node_in_group("glavna_hisa")
	if is_instance_valid(glavna) and "nivo_zgradbe" in glavna:
		return clampi(glavna.nivo_zgradbe, 1, 3)
	return clampi(glavna_stavba_level, 1, 3)


func add_resource(type:String, amount:int):
	if type in resources:
		resources[type] += amount
		update_ui()


func _on_worker_button_pressed():
	print(" DELAVEC GUMB ")

	if _glavna_stevilo_narocil() >= MAX_GLAVNA_QUEUE:
		_pokazi_obvestilo("Čakalna vrsta glavne stavbe je polna")
		return

	if current_pop >= max_pop:
		print("Ni prostora")
		return

	if resources["FOOD"] < 10:
		print("Premalo hrane")
		return

	resources["FOOD"] -= 10
	current_pop += 1
	_dodaj_v_glavno_vrsto("DELAVEC")
	update_ui()
	print("Delavec dodan v čakalno vrsto")


func _izdelaj_delavca() -> void:
	var new_worker = delavec_scene.instantiate()
	var gh = get_tree().get_first_node_in_group("glavna_hisa")
	if gh:
		new_worker.global_position = (
			gh.global_position + DELAVEC_SPAWN_ODMIK
			+ Vector2(randf_range(-DELAVEC_SPAWN_SIRINA, DELAVEC_SPAWN_SIRINA), randf_range(-12.0, 12.0))
		)
	else:
		new_worker.global_position = Vector2(200, 200)
	add_child(new_worker)
	if gh and gh.ima_rally_tocko:
		var odmik := _odmik_nove_enote(int(gh.rally_spawn_index))
		gh.rally_spawn_index += 1
		new_worker.target_position = gh.rally_point + odmik
		new_worker.state = "WALKING_TO_RES"
	print("Nov delavec izdelan")



func _on_build_button_pressed():
	if max_pop >= 20:
		print("Dosežen maksimum populacije")
		return

	if resources["WOOD"] < 50:
		print("Premalo lesa")
		_pokazi_obvestilo("Premalo lesa")
		return

	resources["WOOD"] -= 50
	is_building = true
	_ponastavi_rotacijo_gradnje()
	update_ui()

	print("Postavi hišo")



func _process(delta):

	# Premik kamere s tipkovnico (puščice ali WASD) - glej opombo pri
	# kamera_hitrost zgoraj. Deluje ne glede na to, ali je igralec ravno v
	# načinu postavljanja zgradbe ali ne (isto kot je pinch/pan na telefonu
	# vedno deloval).
	var kamera_smer = Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		kamera_smer.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		kamera_smer.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		kamera_smer.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		kamera_smer.y += 1.0

	if kamera_smer != Vector2.ZERO:
		camera.global_position += kamera_smer.normalized() * kamera_hitrost * delta / camera.zoom.x

	zavrti_button.visible = _v_nacinu_postavljanja()
	smer_predogled.visible = zavrti_button.visible
	preklici_button.visible = zavrti_button.visible
	if zavrti_button.visible:
		zavrti_button.text = "⟳ " + _smer_prikaz(smer_gradnje)

	_posodobi_postavitev_ghost(delta)

	_posodobi_glavno_produkcijo(delta)
	_posodobi_production_ui()
	_posodobi_nadgradnja_ui()

	for idx in touch_points.keys():
		if not long_press_triggered.get(idx, false) and touch_points.size() == 1:
			var elapsed = (Time.get_ticks_msec() - touch_start_time[idx]) / 1000.0
			if elapsed >= long_press_threshold:
				var premik = touch_points[idx] - touch_start_pos[idx]
				if premik.length() < touch_moved_enough:
					long_press_triggered[idx] = true
					_touch_long_press(touch_start_pos[idx])


func _unhandled_input(event):

	if igra_koncana:
		return

	# ZAČASNA TESTNA BLIŽNJICA - pritisk na P doda surovine za lažje testiranje.
	# To vrstico kasneje lahko preprosto zbriševa.
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		_dodaj_test_surovine()

	if event is InputEventKey and event.pressed and event.keycode == KEY_O:
		_on_ai_pavza_button_pressed()

	if event is InputEventScreenTouch:

		if event.pressed:

			touch_points[event.index] = event.position
			touch_start_time[event.index] = Time.get_ticks_msec()
			touch_start_pos[event.index] = event.position
			long_press_triggered[event.index] = false
			zadnja_kazalec_pozicija = get_viewport().get_canvas_transform().affine_inverse() * event.position

			if touch_points.size() == 2:
				var keys = touch_points.keys()
				pinch_start_distance = touch_points[keys[0]].distance_to(touch_points[keys[1]])
				pinch_start_zoom = camera.zoom
				is_panning = false
			elif touch_points.size() == 1:
				is_panning = false
				pan_start_touch = event.position
				pan_start_cam_pos = camera.global_position
				if building_obzidje or building_vrata:
					drag_start = zadnja_kazalec_pozicija
					drag_end = drag_start
					_obzidje_vlek_aktiven = true

		else:

			# POMEMBNO: uporabi POZICIJO SPUSTA prsta (event.position), NE
			# touch_start_pos (pozicijo, kjer se je dotik ZAČEL)! Odkar
			# med postavljanjem zgradbe vlečenje prsta ne premika več
			# kamere (glej InputEventScreenDrag spodaj), se je dalo prst
			# med postavljanjem prosto vleči, da premakneš silhueto - a
			# ker se je tap prej vedno postavil na ZAČETNO točko dotika,
			# je zgradba pristala tam, kjer si prst PRVIČ položil, ne kjer
			# je (pravilno, preverjeno) silhueta na koncu pokazala. To je
			# najverjetneje pravi vzrok za "stisnem nekam, pa zgradi
			# drugam" IN posledično za navidezno "gradim čez drevesa/
			# druge zgradbe" (postavitev se je zgodila na NEPREVERJENI
			# stari poziciji, ne na tisti, ki jo je _postavitev_veljavna()
			# dejansko preverila in prikazala zeleno/rdeče).
			if touch_points.size() == 1 and not is_panning and not long_press_triggered.get(event.index, false):
				if _obzidje_vlek_aktiven and (building_obzidje or building_vrata):
					_obzidje_vlek_aktiven = false
					var pos_konec_dotika = get_viewport().get_canvas_transform().affine_inverse() * event.position
					var je_obzidje_dotik = building_obzidje
					if drag_start.distance_to(pos_konec_dotika) < ZID_ROB_DOLZINA * 0.45:
						_obzidje_dotik(pos_konec_dotika, je_obzidje_dotik)
					else:
						_obzidje_zgradi_verigo(drag_start, pos_konec_dotika, je_obzidje_dotik)
					postavitev_overlay.queue_redraw()
				else:
					_touch_tap(event.position)

			if touch_points.size() <= 1:
				is_panning = false
				_posodobi_multi_select_label()

			touch_points.erase(event.index)
			touch_start_time.erase(event.index)
			touch_start_pos.erase(event.index)
			long_press_triggered.erase(event.index)

			if touch_points.size() < 2:
				pinch_start_distance = 0.0

	elif event is InputEventScreenDrag:

		touch_points[event.index] = event.position
		zadnja_kazalec_pozicija = get_viewport().get_canvas_transform().affine_inverse() * event.position

		if touch_points.size() == 2:
			_obzidje_vlek_aktiven = false

			var keys = touch_points.keys()
			var cur_dist = touch_points[keys[0]].distance_to(touch_points[keys[1]])

			if pinch_start_distance > 0:
				var faktor = cur_dist / pinch_start_distance
				var nova_zoom = pinch_start_zoom * faktor
				nova_zoom.x = clamp(nova_zoom.x, min_zoom, max_zoom)
				nova_zoom.y = clamp(nova_zoom.y, min_zoom, max_zoom)
				camera.zoom = nova_zoom

		elif touch_points.size() == 1:
			if _obzidje_vlek_aktiven and (building_obzidje or building_vrata):
				drag_end = zadnja_kazalec_pozicija
				postavitev_overlay.queue_redraw()

			# Med postavljanjem zgradbe naj vlečenje s prstom premika SAMO
			# silhueto (glej zadnja_kazalec_pozicija zgoraj), NE kamere.
			# Prej se je kamera premikala HKRATI s poskusom premika
			# silhuete (ista gesta je sprožala oboje), kar je dajalo vtis,
			# da je premikanje "nerodno"/trzajoče - tla so pod prstom kar
			# naprej bežala. Za premik kamere med gradnjo najprej prekliči
			# (✕ Prekliči) ali uporabi dva prsta.
			if not _v_nacinu_postavljanja():
				var premik = event.position - pan_start_touch

				if premik.length() > touch_moved_enough:
					is_panning = true

				if is_panning:
					camera.global_position = pan_start_cam_pos - premik / camera.zoom.x

	if event is InputEventMouseButton:

		print("MIŠKA DOGODEK - gumb: ", event.button_index, " pritisnjen: ", event.pressed)

		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:

				drag_start = get_global_mouse_position()
				drag_end = drag_start
				is_dragging = true

				if postavljam_rally:
					_nastavi_rally_tocko(get_global_mouse_position())
					return

				if is_building:
					if _place_house(get_global_mouse_position()):
						is_building = false
					return

				if zgradba_za_postavitev != null:
					_place_oddajno_zgradbo(get_global_mouse_position())
					return

				if building_polje:
					if _place_polje(get_global_mouse_position()):
						building_polje = false
					return

				if building_vojasnica:
					if _place_vojasnica(get_global_mouse_position()):
						building_vojasnica = false
					return

				if building_lutka:
					_place_lutka(get_global_mouse_position())
					building_lutka = false
					return

				if building_obzidje or building_vrata:
					# Miška (računalnik) NAMENOMA ne zgradi/izbere takoj na
					# pritisk - namesto tega začne "vlečenje" (glej
					# _obzidje_izracunaj_verigo/_obzidje_zgradi_verigo v
					# spodnjem release-branchu), da lahko igralec z enim
					# potegom postavi cel niz segmentov naenkrat, à la Clash
					# of Clans. Kratek klik brez premika (glej OBZIDJE_
					# ZID_ROB_DOLZINA*0.45 prag ob spustu) se še vedno obnaša
					# kot prej (en tap = kandidati/gradnja/preklic - glej
					# _obzidje_dotik). Na telefonu ista stvar deluje z enim
					# prstom, dva prsta pa ostaneta za kamero.
					_obzidje_vlek_aktiven = true
					return

				if building_stolp:
					if _place_stolp(get_global_mouse_position()):
						building_stolp = false
					return

				var mouse_pos = get_global_mouse_position()

				# Klik izbere NAJBLIŽJEGA delavca ali enoto (ne prvega v seznamu)
				var najblizji_akter = null
				var najkrajsa_razdalja = 60.0

				for w in get_tree().get_nodes_in_group("delavci"):
					var d = w.global_position.distance_to(mouse_pos)
					if d < najkrajsa_razdalja:
						najkrajsa_razdalja = d
						najblizji_akter = w

				for u in get_tree().get_nodes_in_group("enote"):
					var d = u.global_position.distance_to(mouse_pos)
					if d < najkrajsa_razdalja:
						najkrajsa_razdalja = d
						najblizji_akter = u

				if najblizji_akter != null:
					var frakcija_akterja = "IGRALEC"
					if "je_ai" in najblizji_akter and najblizji_akter.je_ai:
						frakcija_akterja = "AI"
					debug_label.text = "KLIK na: " + najblizji_akter.name + " (" + frakcija_akterja + ") | razdalja: " + str(najkrajsa_razdalja) + " | poz. klika: " + str(mouse_pos)
					print("KLIK NA AKTERJA: ", najblizji_akter.name, " razdalja: ", najkrajsa_razdalja)
					if najblizji_akter.is_selected:
						najblizji_akter.set_selected(false)
					else:
						select_single_actor(najblizji_akter)
					selected_building = null
					_posodobi_multi_select_label()
					_posodobi_gradbeni_panel()
					return
				else:
					var enote_seznam = get_tree().get_nodes_in_group("enote")
					var stevilo_delavcev = get_tree().get_nodes_in_group("delavci").size()
					var pozicije = ""
					for i in range(min(3, enote_seznam.size())):
						pozicije += str(enote_seznam[i].global_position) + " "
					debug_label.text = "KLIK - nič v dosegu | klik: " + str(mouse_pos) + " | enot: " + str(enote_seznam.size()) + " delavcev: " + str(stevilo_delavcev) + " | poz. enot: " + pozicije
					print("KLIK - noben akter v dosegu")

				# NOVO: če imamo izbrane delavce, ima ukaz za gradnjo/popravilo
				# PREDNOST pred golo izbiro zgradbe - sicer klik na zgradbo v
				# gradnji delavca nikoli ne pošlje graditi, ker ga spodnja
				# izbira zgradbe vedno prestreže prej in ga le "izbere".
				var izbrani_delavci_zgodaj_m = []
				for w_zgodaj in get_tree().get_nodes_in_group("delavci"):
					if w_zgodaj.is_selected:
						izbrani_delavci_zgodaj_m.append(w_zgodaj)

				if izbrani_delavci_zgodaj_m.size() > 0:
					var tarca_stavba_m = _najdi_stavbo_za_izbiro(mouse_pos)
					var v_gradnji_m = tarca_stavba_m != null and "v_gradnji" in tarca_stavba_m and tarca_stavba_m.v_gradnji
					var poskodovana_m = tarca_stavba_m != null and "hp" in tarca_stavba_m and "max_hp" in tarca_stavba_m and tarca_stavba_m.hp < tarca_stavba_m.max_hp
					if tarca_stavba_m != null and (v_gradnji_m or poskodovana_m):
						if v_gradnji_m:
							for w_g in izbrani_delavci_zgodaj_m:
								w_g.ukazi_gradnja(tarca_stavba_m)
						else:
							for w_g in izbrani_delavci_zgodaj_m:
								w_g.ukazi_popravilo(tarca_stavba_m)
						_pokazi_ukaz_krog(mouse_pos)
						return
					# Sicer (zgradba je že dokončana IN na polnem HP) klik nanjo
					# ne pošlje ukaza - pade skozi na spodnjo izbiro zgradbe, da
					# se delavec odznači in zgradba izbere (glej spodaj).

				var najdena_stavba_m = _najdi_stavbo_za_izbiro(mouse_pos)

				if najdena_stavba_m != null:
					for w_desel in get_tree().get_nodes_in_group("delavci"):
						w_desel.set_selected(false)
					for u_desel in get_tree().get_nodes_in_group("enote"):
						u_desel.set_selected(false)
					selected_building = najdena_stavba_m
					_posodobi_multi_select_label()
					_posodobi_gradbeni_panel()
					return
				else:
					selected_building = null
					_posodobi_gradbeni_panel()

				var delavec_ukaz_poslan_m := false
				for w in get_tree().get_nodes_in_group("delavci"):

					if w.is_selected:
						delavec_ukaz_poslan_m = true

						var found_tree = false

						for tree in get_tree().get_nodes_in_group("trees"):

							if not _fog_je_pozicija_trenutno_vidna(tree.global_position):
								continue
							if tree.global_position.distance_to(mouse_pos) < _doseg_klika_vira(tree):
								w.start_mining(tree)
								found_tree = true
								break

						if found_tree == false:
							w.target_resource = null
							w.target_position = mouse_pos
							w.state = "WALKING_TO_RES"

				var premik_enote: Array = []
				for u in get_tree().get_nodes_in_group("enote"):
					if u.is_selected:
						premik_enote.append(u)
				if delavec_ukaz_poslan_m and premik_enote.is_empty():
					_pokazi_ukaz_krog(mouse_pos)
				_ukazi_formacijo(premik_enote, mouse_pos)


			else:

				if _obzidje_vlek_aktiven:
					_obzidje_vlek_aktiven = false
					is_dragging = false

					var pos_konec = get_global_mouse_position()
					var je_obzidje_v = building_obzidje

					if drag_start.distance_to(pos_konec) < ZID_ROB_DOLZINA * 0.45:
						# Premalo premika za "vlečenje" - obravnavaj kot
						# navaden tap (obstoječa kandidatna/gradbena logika).
						_obzidje_dotik(pos_konec, je_obzidje_v)
					else:
						_obzidje_zgradi_verigo(drag_start, pos_konec, je_obzidje_v)

					postavitev_overlay.queue_redraw()
					return

				is_dragging = false

				var rect = Rect2(
					Vector2(min(drag_start.x, drag_end.x), min(drag_start.y, drag_end.y)),
					Vector2(abs(drag_start.x - drag_end.x), abs(drag_end.y - drag_start.y))
				)

				if rect.size.length() > 15:

					for w in get_tree().get_nodes_in_group("delavci"):
						w.set_selected(rect.has_point(w.global_position))

					for u in get_tree().get_nodes_in_group("enote"):
						u.set_selected(rect.has_point(u.global_position))

					selected_building = null
					_posodobi_multi_select_label()
					_posodobi_gradbeni_panel()

				postavitev_overlay.queue_redraw()

		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			# Zoom s koleščkom miške - glej opombo pri kamera_hitrost zgoraj,
			# prej je zoom deloval samo s pinch-om (dva prsta) na telefonu.
			var korak = 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1111111
			var nova_zoom_k = camera.zoom * korak
			nova_zoom_k.x = clamp(nova_zoom_k.x, min_zoom, max_zoom)
			nova_zoom_k.y = clamp(nova_zoom_k.y, min_zoom, max_zoom)
			camera.zoom = nova_zoom_k

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:

			var mouse_pos_r = get_global_mouse_position()

			var tarca = null
			var najkrajsa = 120.0

			var mozne_tarce = get_tree().get_nodes_in_group("sovraznik") + get_tree().get_nodes_in_group("zgradbe")

			for e in mozne_tarce:
				if _je_skrita_zival(e):
					continue
				if e.is_in_group("sovraznik") and not _fog_je_trenutno_vidno(e):
					continue
				var d = e.razdalja_do_klika(mouse_pos_r) if e.has_method("razdalja_do_klika") else e.global_position.distance_to(mouse_pos_r)
				if d < najkrajsa:
					najkrajsa = d
					tarca = e

			if tarca != null:

				var izbrani_delavci = []
				var izbrane_enote = []

				for w in get_tree().get_nodes_in_group("delavci"):
					if w.is_selected:
						izbrani_delavci.append(w)

				for u in get_tree().get_nodes_in_group("enote"):
					if u.is_selected:
						izbrane_enote.append(u)

				if izbrani_delavci.size() > 0 and tarca.is_in_group("zgradbe"):

					if "v_gradnji" in tarca and tarca.v_gradnji:
						for w in izbrani_delavci:
							w.ukazi_gradnja(tarca)
						debug_label.text = "GRADNJA | klik: " + str(mouse_pos_r) + " | tarča: " + tarca.name
						print("UKAZ ZA GRADNJO: ", tarca.name)
					else:
						for w in izbrani_delavci:
							w.ukazi_popravilo(tarca)
						debug_label.text = "POPRAVILO | klik: " + str(mouse_pos_r) + " | tarča: " + tarca.name + " | HP: " + str(tarca.hp) + "/" + str(tarca.max_hp)
						print("UKAZ ZA POPRAVILO: ", tarca.name)
					_pokazi_ukaz_krog(mouse_pos_r)

				elif izbrani_delavci.size() > 0 and tarca.is_in_group("zivali"):

					for w in izbrani_delavci:
						w.ukazi_lov(tarca)
					_pokazi_ukaz_krog(tarca.global_position, true)

					debug_label.text = "LOV | klik: " + str(mouse_pos_r) + " | tarča: " + tarca.name
					print("UKAZ ZA LOV: ", tarca.name)

				elif izbrane_enote.size() > 0 and tarca.is_in_group("sovraznik"):

					_ukazi_skupinski_napad(izbrane_enote, tarca)

					debug_label.text = "NAPAD OK | klik: " + str(mouse_pos_r) + " | tarča poz: " + str(tarca.global_position) + " | razdalja: " + str(najkrajsa)
					print("UKAZ ZA NAPAD na: ", tarca.name)

			else:
				# Skriti sovražniki ne smejo razkriti svojih koordinat niti prek
				# starega diagnostičnega napisa.
				debug_label.text = "NAPAD - NI VIDNE TARČE | klik: " + str(mouse_pos_r)


	if event is InputEventMouseMotion:

		zadnja_kazalec_pozicija = get_global_mouse_position()

		if is_dragging:
			drag_end = get_global_mouse_position()
			postavitev_overlay.queue_redraw()

		var hover_pos = get_global_mouse_position()
		var hover_akter = null
		var hover_razdalja = 45.0

		var mozni_hover = get_tree().get_nodes_in_group("delavci") + get_tree().get_nodes_in_group("enote") + get_tree().get_nodes_in_group("zgradbe") + get_tree().get_nodes_in_group("sovraznik")

		for a in mozni_hover:
			if not is_instance_valid(a):
				continue
			if _je_skrita_zival(a):
				continue
			if a.is_in_group("sovraznik") and not _fog_je_trenutno_vidno(a):
				continue
			var d = a.global_position.distance_to(hover_pos)
			if d < hover_razdalja and "hp" in a:
				hover_razdalja = d
				hover_akter = a

		if hover_akter != null:
			var ime = hover_akter.name
			if "enota_ime" in hover_akter:
				ime = hover_akter.enota_ime
			var frakcija = "IGRALEC"
			if "je_ai" in hover_akter and hover_akter.je_ai:
				frakcija = "AI"
			hover_label.text = ime + " (" + frakcija + "): " + str(hover_akter.hp) + " / " + str(hover_akter.max_hp) + " HP" + _napredek_besedilo(hover_akter)
			hover_label.visible = true
		else:
			hover_label.visible = false


func _touch_tap(screen_pos):

	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * screen_pos

	_touch_prikazi_hp(world_pos)

	if postavljam_rally:
		_nastavi_rally_tocko(world_pos)
		return

	if is_building:
		if _place_house(world_pos):
			is_building = false
		return

	if zgradba_za_postavitev != null:
		_place_oddajno_zgradbo(world_pos)
		return

	if building_polje:
		if _place_polje(world_pos):
			building_polje = false
		return

	if building_vojasnica:
		if _place_vojasnica(world_pos):
			building_vojasnica = false
		return

	if building_lutka:
		_place_lutka(world_pos)
		building_lutka = false
		return

	if building_obzidje:
		_obzidje_dotik(world_pos, true)
		return

	if building_vrata:
		_obzidje_dotik(world_pos, false)
		return

	if building_stolp:
		if _place_stolp(world_pos):
			building_stolp = false
		return

	# 1. Tap na svojega delavca/enoto = izberi
	var najblizji_akter = null
	var najkrajsa_razdalja = 60.0

	for w in get_tree().get_nodes_in_group("delavci"):
		var d = w.global_position.distance_to(world_pos)
		if d < najkrajsa_razdalja:
			najkrajsa_razdalja = d
			najblizji_akter = w

	for u in get_tree().get_nodes_in_group("enote"):
		var d = u.global_position.distance_to(world_pos)
		if d < najkrajsa_razdalja:
			najkrajsa_razdalja = d
			najblizji_akter = u

	if najblizji_akter != null:
		if multi_select_mode:
			najblizji_akter.set_selected(true)
		elif najblizji_akter.is_selected:
			najblizji_akter.set_selected(false)
		else:
			select_single_actor(najblizji_akter)
		selected_building = null
		_posodobi_multi_select_label()
		_posodobi_gradbeni_panel()
		return

	# NOVO: če imamo izbrane delavce, ima ukaz za gradnjo/popravilo PREDNOST
	# pred golo izbiro zgradbe - sicer tap na zgradbo v gradnji delavca
	# nikoli ne pošlje graditi, ker ga spodnja izbira zgradbe vedno
	# prestreže prej in ga le "izbere" (to je bil vzrok, da se delavec ni
	# odzval na ukaz za gradnjo).
	var izbrani_delavci_zgodaj = []
	for w_zgodaj in get_tree().get_nodes_in_group("delavci"):
		if w_zgodaj.is_selected:
			izbrani_delavci_zgodaj.append(w_zgodaj)

	if izbrani_delavci_zgodaj.size() > 0:
		var tarca_stavba = _najdi_stavbo_za_izbiro(world_pos)
		var v_gradnji_t = tarca_stavba != null and "v_gradnji" in tarca_stavba and tarca_stavba.v_gradnji
		var poskodovana_t = tarca_stavba != null and "hp" in tarca_stavba and "max_hp" in tarca_stavba and tarca_stavba.hp < tarca_stavba.max_hp
		if tarca_stavba != null and (v_gradnji_t or poskodovana_t):
			if v_gradnji_t:
				for w_g in izbrani_delavci_zgodaj:
					w_g.ukazi_gradnja(tarca_stavba)
			else:
				for w_g in izbrani_delavci_zgodaj:
					w_g.ukazi_popravilo(tarca_stavba)
			_pokazi_ukaz_krog(world_pos)
			return
		# Sicer (zgradba je že dokončana IN na polnem HP) klik nanjo ne pošlje
		# ukaza - pade skozi na spodnjo izbiro zgradbe, da se delavec odznači
		# in zgradba izbere (glej spodaj).

	# 2. Ni zadel akterja - preveri, ali je tap na zgradbo (vedno ima prednost)
	multi_select_mode = false

	var najdena_stavba = _najdi_stavbo_za_izbiro(world_pos)

	if najdena_stavba != null:
		for w_desel in get_tree().get_nodes_in_group("delavci"):
			w_desel.set_selected(false)
		for u_desel in get_tree().get_nodes_in_group("enote"):
			u_desel.set_selected(false)
		selected_building = najdena_stavba
		_posodobi_multi_select_label()
		_posodobi_gradbeni_panel()
		return
	else:
		selected_building = null
		_posodobi_gradbeni_panel()

	var izbrani_delavci = []
	var izbrane_enote = []

	for w in get_tree().get_nodes_in_group("delavci"):
		if w.is_selected:
			izbrani_delavci.append(w)

	for u in get_tree().get_nodes_in_group("enote"):
		if u.is_selected:
			izbrane_enote.append(u)

	if izbrani_delavci.size() > 0:

		var najblizje_drevo = null
		var naj_d = 115.0
		for tree in get_tree().get_nodes_in_group("trees"):
			if not _fog_je_pozicija_trenutno_vidna(tree.global_position):
				continue
			var d = tree.global_position.distance_to(world_pos)
			if d < naj_d and d < _doseg_klika_vira(tree):
				naj_d = d
				najblizje_drevo = tree

		if najblizje_drevo != null:
			for w in izbrani_delavci:
				w.start_mining(najblizje_drevo)
			_pokazi_ukaz_krog(world_pos)
			return

		var najblizja_zival = null
		var naj_dz = 120.0
		for z_niv in get_tree().get_nodes_in_group("zivali"):
			if _je_skrita_zival(z_niv):
				continue
			if not _fog_je_trenutno_vidno(z_niv):
				continue
			var d_ziv = z_niv.razdalja_do_klika(world_pos) if z_niv.has_method("razdalja_do_klika") else z_niv.global_position.distance_to(world_pos)
			if d_ziv < naj_dz:
				naj_dz = d_ziv
				najblizja_zival = z_niv

		if najblizja_zival != null:
			for w in izbrani_delavci:
				w.ukazi_lov(najblizja_zival)
			_pokazi_ukaz_krog(najblizja_zival.global_position, true)
			return

		var v_gradnji_zgradba = null
		naj_d = 60.0
		for z in get_tree().get_nodes_in_group("zgradbe"):
			if "v_gradnji" in z and z.v_gradnji:
				var d = z.global_position.distance_to(world_pos)
				if d < naj_d:
					naj_d = d
					v_gradnji_zgradba = z

		if v_gradnji_zgradba != null:
			for w in izbrani_delavci:
				w.ukazi_gradnja(v_gradnji_zgradba)
			_pokazi_ukaz_krog(world_pos)
			return

		var najblizja_zgradba = null
		naj_d = 60.0
		for z in get_tree().get_nodes_in_group("zgradbe"):
			if z.hp < z.max_hp:
				var d = z.global_position.distance_to(world_pos)
				if d < naj_d:
					naj_d = d
					najblizja_zgradba = z

		if najblizja_zgradba != null:
			for w in izbrani_delavci:
				w.ukazi_popravilo(najblizja_zgradba)
			_pokazi_ukaz_krog(world_pos)
			return

		for w in izbrani_delavci:
			w.target_resource = null
			w.target_position = world_pos
			w.state = "WALKING_TO_RES"
		_pokazi_ukaz_krog(world_pos)
		return

	if izbrane_enote.size() > 0:

		var najblizji_sovraznik = null
		var naj_ds = 120.0
		for e in get_tree().get_nodes_in_group("sovraznik"):
			if _je_skrita_zival(e):
				continue
			if not _fog_je_trenutno_vidno(e):
				continue
			var d = e.razdalja_do_klika(world_pos) if e.has_method("razdalja_do_klika") else e.global_position.distance_to(world_pos)
			if d < naj_ds:
				naj_ds = d
				najblizji_sovraznik = e

		if najblizji_sovraznik != null:
			_ukazi_skupinski_napad(izbrane_enote, najblizji_sovraznik)
			return

		_ukazi_formacijo(izbrane_enote, world_pos)
		return


func _pokazi_ukaz_krog(pos: Vector2, napad: bool = false) -> void:
	var nosilec := Node2D.new()
	nosilec.name = "UkazKrog"
	nosilec.global_position = pos
	nosilec.z_index = 300
	nosilec.scale = Vector2.ONE * 0.62
	var barva := Color(1.0, 0.24, 0.16, 0.95) if napad else Color(1.0, 0.86, 0.18, 0.95)
	for podatki in [[22.0, 3.2], [8.0, 2.0]]:
		var krog := Line2D.new()
		krog.width = float(podatki[1])
		krog.default_color = barva
		krog.closed = true
		krog.antialiased = true
		for i in range(33):
			var kot := TAU * float(i) / 32.0
			krog.add_point(Vector2(cos(kot), sin(kot)) * float(podatki[0]))
		nosilec.add_child(krog)
	add_child(nosilec)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(nosilec, "scale", Vector2.ONE * 1.12, 0.82).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(nosilec, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(nosilec.queue_free)


func _ukazi_formacijo(enote: Array, cilj: Vector2) -> void:
	# Vsaka enota dobi svoje mesto; naključni cilji so prej križali poti in
	# povzročali zaletavanje. Razpored ostane kompakten in predvidljiv.
	var st := enote.size()
	if st == 0: return
	_pokazi_ukaz_krog(cilj)
	var poglavar = null
	for u in enote:
		if (u.is_in_group("poveljniki") or ("tip_animacije" in u and u.tip_animacije == "poglavar")):
			poglavar = u
			break
	if is_instance_valid(poglavar):
		_ukazi_trikotno_formacijo(enote, cilj, poglavar)
		return
	var stolpci := ceili(sqrt(float(st)))
	var vrstice := ceili(float(st) / stolpci)
	var razmik := 38.0
	var prosta_mesta: Array[Vector2] = []
	for i in range(st):
		var x := i % stolpci
		var y := i / stolpci
		var odmik := Vector2((x - (stolpci - 1) * 0.5) * razmik, (y - (vrstice - 1) * 0.5) * razmik * 0.62)
		prosta_mesta.append(cilj + odmik)

	# Vsaka enota dobi najbližje še prosto mesto. Prejšnja razporeditev po
	# vrstnem redu seznama je enote po nepotrebnem križala in ustvarjala zamaške.
	var cakajoce := enote.duplicate()
	while not cakajoce.is_empty():
		var najboljsa_enota = null
		var najboljsi_indeks := -1
		var najboljsa_razdalja := INF
		for u in cakajoce:
			for i in range(prosta_mesta.size()):
				var d: float = u.global_position.distance_squared_to(prosta_mesta[i])
				if d < najboljsa_razdalja:
					najboljsa_razdalja = d
					najboljsa_enota = u
					najboljsi_indeks = i
		najboljsa_enota.ukazi_premik(prosta_mesta[najboljsi_indeks])
		cakajoce.erase(najboljsa_enota)
		prosta_mesta.remove_at(najboljsi_indeks)


func _ukazi_trikotno_formacijo(enote: Array, cilj: Vector2, poglavar) -> void:
	# Poglavar je konica trikotnika. Vsaka naslednja vrsta za njim ima eno
	# mesto več: 1 (poglavar), nato 2, 3, 4 ...
	var sredina := Vector2.ZERO
	for u in enote: sredina += u.global_position
	sredina /= float(enote.size())
	var naprej := (cilj - sredina).normalized()
	if naprej.length_squared() < 0.01: naprej = Vector2(0, 1)
	var bocno := Vector2(-naprej.y, naprej.x)
	var razmik_vrste := 38.0
	var razmik_bocno := 40.0

	poglavar.ukazi_premik(cilj)
	var prosta_mesta: Array[Vector2] = []
	var preostalo := enote.size() - 1
	var vrsta := 1
	while preostalo > 0:
		var v_vrsti := mini(vrsta + 1, preostalo)
		for i in range(v_vrsti):
			var stranski := (float(i) - float(v_vrsti - 1) * 0.5) * razmik_bocno
			prosta_mesta.append(cilj - naprej * (vrsta * razmik_vrste) + bocno * stranski)
		preostalo -= v_vrsti
		vrsta += 1

	var cakajoce := enote.duplicate()
	cakajoce.erase(poglavar)
	# Najbližja dodelitev prepreči križanje poti na poti v trikotnik.
	while not cakajoce.is_empty():
		var najboljsa_enota = null
		var najboljsi_indeks := -1
		var najboljsa_razdalja := INF
		for u in cakajoce:
			for i in range(prosta_mesta.size()):
				var d: float = u.global_position.distance_squared_to(prosta_mesta[i])
				if d < najboljsa_razdalja:
					najboljsa_razdalja = d
					najboljsa_enota = u
					najboljsi_indeks = i
		najboljsa_enota.ukazi_premik(prosta_mesta[najboljsi_indeks])
		cakajoce.erase(najboljsa_enota)
		prosta_mesta.remove_at(najboljsi_indeks)


func _ukazi_skupinski_napad(enote: Array, tarca) -> void:
	if not enote.is_empty() and is_instance_valid(tarca):
		_pokazi_ukaz_krog(tarca.global_position, true)
	if enote.is_empty() or not is_instance_valid(tarca): return
	# Razdeljena mesta okoli tarče preprečijo, da bi vsi vojaki lovili isto
	# točko. Večje skupine dobijo drugi obroč, zato se ne zagozdijo za prvim.
	var prosti_odmiki: Array[Vector2] = []
	for i in range(enote.size()):
		var obroc := i / 8
		var mesto := i % 8
		var na_obrocu := mini(8, enote.size() - obroc * 8)
		var kot := TAU * float(mesto) / float(maxi(1, na_obrocu))
		var doseg: float = float(enote[i].attack_range) if "attack_range" in enote[i] else 42.0
		var radij := minf(doseg * 0.70, 18.0 + obroc * 7.0)
		prosti_odmiki.append(Vector2(cos(kot), sin(kot)) * radij)

	var cakajoce := enote.duplicate()
	while not cakajoce.is_empty():
		var najboljsa_enota = null
		var najboljsi_indeks := -1
		var najboljsa_razdalja := INF
		for u in cakajoce:
			for i in range(prosti_odmiki.size()):
				var mesto: Vector2 = tarca.global_position + prosti_odmiki[i]
				var d: float = u.global_position.distance_squared_to(mesto)
				if d < najboljsa_razdalja:
					najboljsa_razdalja = d
					najboljsa_enota = u
					najboljsi_indeks = i
		najboljsa_enota.ukazi_napad_z_odmikom(tarca, prosti_odmiki[najboljsi_indeks])
		cakajoce.erase(najboljsa_enota)
		prosti_odmiki.remove_at(najboljsi_indeks)


func _touch_prikazi_hp(world_pos):

	var najblizji = null
	var najkrajsa = 60.0

	var mozni = get_tree().get_nodes_in_group("delavci") + get_tree().get_nodes_in_group("enote") + get_tree().get_nodes_in_group("zgradbe") + get_tree().get_nodes_in_group("sovraznik")

	for a in mozni:
		if not is_instance_valid(a):
			continue
		if _je_skrita_zival(a):
			continue
		if a.is_in_group("sovraznik") and not _fog_je_trenutno_vidno(a):
			continue
		var d = a.global_position.distance_to(world_pos)
		if d < najkrajsa and "hp" in a:
			najkrajsa = d
			najblizji = a

	if najblizji != null:
		var ime = najblizji.name
		if "enota_ime" in najblizji:
			ime = najblizji.enota_ime
		var frakcija = "IGRALEC"
		if "je_ai" in najblizji and najblizji.je_ai:
			frakcija = "AI"
		hover_label.text = ime + " (" + frakcija + "): " + str(najblizji.hp) + " / " + str(najblizji.max_hp) + " HP" + _napredek_besedilo(najblizji)
		hover_label.visible = true


func _je_skrita_zival(akter) -> bool:
	return (
		is_instance_valid(akter)
		and akter.is_in_group("zivali")
		and akter.has_method("je_skrita_pod_krosnjo")
		and akter.je_skrita_pod_krosnjo()
	)


func _fog_je_trenutno_vidno(akter) -> bool:
	if not is_instance_valid(akter) or not akter is Node2D:
		return false
	return _fog_je_pozicija_trenutno_vidna(akter.global_position)


func _fog_je_pozicija_trenutno_vidna(pozicija: Vector2) -> bool:
	var fog = get_node_or_null("FogOfWar")
	return fog == null or not fog.has_method("is_visible_now") or fog.is_visible_now(pozicija)


func _fog_dovoli_gradnjo(pozicija: Vector2) -> bool:
	if _fog_je_pozicija_trenutno_vidna(pozicija):
		return true
	_pokazi_obvestilo("V megli ni mogoče graditi – območje moraš najprej odkriti")
	return false


# Javni preverjevalnik uporabljajo vojaki in stolpi, da ne morejo samodejno
# napasti sovražnika, ki je še skrit v megli.
func je_tarca_vidna_v_megli(akter) -> bool:
	return _fog_je_trenutno_vidno(akter)


func _touch_long_press(screen_pos):

	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * screen_pos

	multi_select_mode = true

	var najblizji_akter = null
	var najkrajsa_razdalja = 60.0

	for w in get_tree().get_nodes_in_group("delavci"):
		var d = w.global_position.distance_to(world_pos)
		if d < najkrajsa_razdalja:
			najkrajsa_razdalja = d
			najblizji_akter = w

	for u in get_tree().get_nodes_in_group("enote"):
		var d = u.global_position.distance_to(world_pos)
		if d < najkrajsa_razdalja:
			najkrajsa_razdalja = d
			najblizji_akter = u

	if najblizji_akter != null:
		najblizji_akter.set_selected(true)
		selected_building = null

	_posodobi_multi_select_label()
	_posodobi_gradbeni_panel()


func _posodobi_multi_select_label():

	var stevilo = 0

	for w in get_tree().get_nodes_in_group("delavci"):
		if w.is_selected:
			stevilo += 1

	for u in get_tree().get_nodes_in_group("enote"):
		if u.is_selected:
			stevilo += 1

	if stevilo > 1:
		multi_select_label.text = str(stevilo) + " enot izbranih"
		multi_select_label.visible = true
	else:
		multi_select_label.visible = false


func _posodobi_gradbeni_panel():

	var kaksen_delavec_izbran = false
	for w in get_tree().get_nodes_in_group("delavci"):
		if w.is_selected:
			kaksen_delavec_izbran = true
			break

	panel_delavec.visible = false
	panel_vojasnica.visible = false
	panel_glavna_hisa.visible = false
	panel_obzidje.visible = false
	panel_stolp.visible = false
	panel_kmetija.visible = false
	panel_zrusi.visible = false
	vrata_odpri_button.visible = false

	if kaksen_delavec_izbran:
		panel_delavec.visible = true
		return

	if selected_building != null and is_instance_valid(selected_building):

		if selected_building.is_in_group("glavna_hisa"):
			panel_glavna_hisa.visible = true
			return

		# Gumb "Zruši" (glej _on_zrusi_button_pressed) je na voljo za VSAKO
		# igralčevo zgradbo razen glavne hiše (zgoraj, obravnavana posebej) -
		# tudi za tiste tipe (drvarnica/kamnolom/rudnik/hisa), ki nimajo
		# svojega posebnega panela in bi sicer ob izbiri ne pokazale ničesar.
		panel_zrusi.visible = true

		if "tip_zgradbe" in selected_building:
			match selected_building.tip_zgradbe:
				"vojasnica":
					vojasnica_ref = selected_building
					vojasnica_level = selected_building.nivo_zgradbe
					panel_vojasnica.visible = true
				"obzidje", "vrata":
					panel_obzidje.visible = true
					if selected_building.tip_zgradbe == "vrata":
						vrata_odpri_button.visible = true
						var odprta = selected_building.so_vrata_odprta() if selected_building.has_method("so_vrata_odprta") else false
						vrata_odpri_button.text = "Zapri vrata" if odprta else "Odpri vrata"
				"stolp":
					panel_stolp.visible = true
					_posodobi_stolp_gumb()
				"kmetija":
					panel_kmetija.visible = true


func _najdi_stavbo_za_izbiro(pos: Vector2):

	var mozne_stavbe = get_tree().get_nodes_in_group("zgradbe").duplicate()

	var gh = get_tree().get_first_node_in_group("glavna_hisa")
	if gh:
		mozne_stavbe.append(gh)

	var najblizja = null
	var naj_d = INF

	for s in mozne_stavbe:
		if not is_instance_valid(s):
			continue
		var vidni_pravokotnik = _vizualni_svetovni_pravokotnik(s).grow(10.0)
		if vidni_pravokotnik.has_point(pos):
			var d_vidni = vidni_pravokotnik.get_center().distance_to(pos)
			if d_vidni < naj_d:
				naj_d = d_vidni
				najblizja = s

	# Rezerva za majhne/nevidne gradbiščne objekte: klik blizu talne točke.
	if najblizja == null:
		var naj_d_koren = 100.0
		for s in mozne_stavbe:
			if not is_instance_valid(s):
				continue
			var d_koren = s.global_position.distance_to(pos)
			if d_koren < naj_d_koren:
				naj_d_koren = d_koren
				najblizja = s

	return najblizja


func _on_rally_button_pressed():

	if selected_building == null or not is_instance_valid(selected_building):
		print("Najprej izberi vojašnico ali glavno stavbo")
		return
	var je_proizvodna: bool = bool(selected_building.is_in_group("glavna_hisa") or (
		"tip_zgradbe" in selected_building and selected_building.tip_zgradbe == "vojasnica"
	))
	if not je_proizvodna:
		_pokazi_obvestilo("Zbirno točko imata samo baza in vojašnica")
		return

	postavljam_rally = true
	print("Klikni/tapni na mapo za rally točko")


func _nastavi_rally_tocko(pos: Vector2):

	postavljam_rally = false

	if selected_building == null or not is_instance_valid(selected_building):
		return

	selected_building.rally_point = pos
	selected_building.ima_rally_tocko = true
	selected_building.rally_spawn_index = 0
	_ustvari_rally_zastavico(selected_building, pos)

	print("Rally točka nastavljena")


func _ustvari_rally_zastavico(stavba, pos: Vector2) -> void:
	if not is_instance_valid(stavba):
		return
	if "rally_zastavica" in stavba and is_instance_valid(stavba.rally_zastavica):
		stavba.rally_zastavica.queue_free()
	var nosilec := Node2D.new()
	nosilec.name = "RallyZastavica"
	nosilec.global_position = pos
	nosilec.z_index = 70
	var sprite := Sprite2D.new()
	sprite.texture = RALLY_ZASTAVICA_TEKSTURA
	sprite.position = Vector2(0, -43)
	sprite.scale = Vector2(0.55, 0.55)
	nosilec.add_child(sprite)
	add_child(nosilec)
	stavba.rally_zastavica = nosilec
	rally_zastavica = nosilec


# Ali smo trenutno v katerem koli načinu postavljanja zgradbe (za prikaz
# gumba "Zavrti" - velja za VSE zgradbe, ne le obzidje/vrata).
func _v_nacinu_postavljanja() -> bool:
	return is_building or zgradba_za_postavitev != null or building_polje \
		or building_vojasnica or building_lutka or building_obzidje \
		or building_vrata or building_stolp


# Pokliči na začetku vsakega novega načina postavljanja, da smer ne "uide"
# iz prejšnje postavitve v naslednjo.
func _ponastavi_rotacijo_gradnje() -> void:
	smer_gradnje = "jug"
	_posodobi_smer_predogled()

	_obzidje_sidro = null
	_obzidje_kandidati = []
	_obzidje_vlek_aktiven = false

	# Duh postavitve naj bo takoj viden (v naravni velikosti), tudi preden
	# igralec kamorkoli tapne/premakne miško - postavi ga na sredino
	# trenutnega pogleda kamere.
	zadnja_kazalec_pozicija = camera.global_position
	_posodobi_postavitev_ghost()


# Prekliče KATERI KOLI trenutno aktiven način postavljanja zgradbe (brez
# vračila surovin - v igri trenutno ni sistema za vračilo, glej opombo pri
# neuspeli postavitvi spodaj) - nujno potrebno, saj se pred tem igralec
# NI mogel izmuzniti iz načina postavljanja, če ta ni uspel (npr. prevec
# blizu drevesa/zgradbe) - lahko se je "zataknil" brez možnosti, da bi
# storil karkoli drugega.
func _on_preklici_button_pressed() -> void:
	is_building = false
	zgradba_za_postavitev = null
	zgradba_kljuc = ""
	building_polje = false
	building_vojasnica = false
	building_lutka = false
	building_obzidje = false
	building_vrata = false
	building_stolp = false
	_ghost_vidna = false
	_obzidje_sidro = null
	_obzidje_kandidati = []
	_obzidje_vlek_aktiven = false
	postavitev_overlay.queue_redraw()
	_pokazi_obvestilo("Postavljanje preklicano")


# Kratko obvestilo na sredini zaslona (ne samo print() v konzolo, ki je
# igralec na telefonu sploh ne vidi) - uporabljeno za razlago, ZAKAJ neka
# postavitev ni uspela (predaleč/predblizu/ni surovin ipd.), da igralec ni
# pustil v negotovosti, zakaj se ob tapu ni nič zgodilo.
var _obvestilo_tween: Tween = null

func _pokazi_obvestilo(besedilo: String) -> void:
	obvestilo_label.text = besedilo
	obvestilo_label.modulate.a = 1.0
	obvestilo_label.visible = true

	if _obvestilo_tween != null and _obvestilo_tween.is_valid():
		_obvestilo_tween.kill()

	_obvestilo_tween = create_tween()
	_obvestilo_tween.tween_interval(1.4)
	_obvestilo_tween.tween_property(obvestilo_label, "modulate:a", 0.0, 0.5)
	_obvestilo_tween.tween_callback(func(): obvestilo_label.visible = false)


# Ugotovi, katere smeri ima ta konkretna zgradba dejansko na voljo (ima
# nastavljeno tekstura_* za to smer) - "jug" je vedno na voljo (privzeta
# smer vsake zgradbe, tudi tiste, ki še sploh nima smernih slik).
func _razpolozljive_smeri_za(scena: PackedScene) -> Array:
	if scena == null:
		return ["jug"]

	var zacasna = scena.instantiate()
	var na_voljo: Array = []
	var dovoljene_smeri: Array = SMERI_ZAPOREDJE if zacasna.tip_zgradbe in ["obzidje", "vrata"] else ["jug", "sever"]

	for smer in dovoljene_smeri:
		if smer == "jug":
			na_voljo.append(smer)
			continue
		if zacasna.has_method("_tekstura_za_smer") and zacasna._tekstura_za_smer(smer) != null:
			na_voljo.append(smer)

	zacasna.free()

	if na_voljo.is_empty():
		na_voljo = ["jug"]

	return na_voljo


func _on_zavrti_button_pressed():
	var na_voljo = _razpolozljive_smeri_za(_scena_za_trenutno_postavitev())
	var idx = na_voljo.find(smer_gradnje)
	if idx == -1:
		idx = 0
	else:
		idx = (idx + 1) % na_voljo.size()
	smer_gradnje = na_voljo[idx]
	zavrti_button.text = "⟳ " + _smer_prikaz(smer_gradnje)
	_posodobi_smer_predogled()


# Prikazno ime smeri za gumb (npr. "jug" -> "Vhod: Jug").
func _smer_prikaz(smer: String) -> String:
	match smer:
		"jug":
			return "Vhod: Jug"
		"sever":
			return "Vhod: Sever"
		"vzhod":
			return "Vhod: Vzhod"
		"zahod":
			return "Vhod: Zahod"
	return "Obrni smer"


# Kateri PackedScene se trenutno postavlja (glede na aktivni način
# postavljanja) - uporabljeno samo za sličico predogleda smeri spodaj.
func _scena_za_trenutno_postavitev() -> PackedScene:
	if is_building:
		return hisa_scene
	if zgradba_za_postavitev != null:
		return zgradba_za_postavitev
	if building_polje:
		return polje_scene
	if building_vojasnica:
		return vojasnica_scene
	if building_lutka:
		return lutka_scene
	if building_obzidje:
		return obzidje_scene
	if building_vrata:
		return vrata_scene
	if building_stolp:
		return stolp_scene
	return null


# Posodobi majhno sličico ob gumbu "Obrni smer" - igralec tako DEJANSKO vidi,
# kako bo zgradba izgledala v izbrani smeri, namesto da bi samo bral besedilo.
# Začasno instancira zgradbo (nikoli ne doda v drevo), prebere njeno sličico
# za izbrano smer, nato instanco takoj sprosti.
func _posodobi_smer_predogled() -> void:
	var scena = _scena_za_trenutno_postavitev()
	if scena == null:
		smer_predogled.visible = false
		return

	var zacasna = scena.instantiate()
	if zacasna.has_method("nastavi_smer"):
		zacasna.nastavi_smer(smer_gradnje)

	var tekstura: Texture2D = null
	_ghost_odmik = Vector2.ZERO
	_ghost_merilo = Vector2.ONE
	for otrok in zacasna.get_children():
		if otrok is Sprite2D:
			tekstura = otrok.texture
			_ghost_odmik = otrok.position
			_ghost_merilo = otrok.scale
			break

	zacasna.free()

	if tekstura != null:
		smer_predogled.texture = tekstura
		smer_predogled.visible = true
	else:
		smer_predogled.visible = false


# "Duh" (polprozorna slika) zgradbe, ki sledi kazalcu/prstu med postavljanjem,
# natanko na mestu, kamor bi zgradba pristala, če bi zdaj tapnil - vključno s
# "zlepljenjem" na obstoječe obzidje/vrata, kar je bilo prej najbolj nejasno
# (nisi videl, kam se bo segment dejansko postavil).
func _posodobi_postavitev_ghost(delta: float = 0.0) -> void:
	if not _v_nacinu_postavljanja():
		if _ghost_vidna:
			_ghost_vidna = false
			postavitev_overlay.queue_redraw()
		return

	# Ko je izbrano "sidro" (obstoječi segment obzidja/vrat, glej
	# _obzidje_dotik) kažemo namesto ene sledeče silhuete VSE kandidatne
	# pozicije naenkrat (glej _narisi_postavitveni_overlay) - navadna
	# silhueta bi bila tu samo moteča/zavajajoča.
	if _obzidje_sidro != null and is_instance_valid(_obzidje_sidro):
		if _ghost_vidna:
			_ghost_vidna = false
			postavitev_overlay.queue_redraw()
		return

	# Med vlečenjem (glej _obzidje_vlek_aktiven) kažemo VERIGO kandidatov
	# (glej zgoraj v _narisi_postavitveni_overlay), ne eno sledečo silhueto.
	if _obzidje_vlek_aktiven:
		if _ghost_vidna:
			_ghost_vidna = false
			postavitev_overlay.queue_redraw()
		return

	# Ista sličica, ki je že izračunana za predogled smeri ob gumbu -
	# se ni treba ponovno instancirati zgradbe.
	if smer_predogled.texture == null:
		if _ghost_vidna:
			_ghost_vidna = false
			postavitev_overlay.queue_redraw()
		return

	var mis_pozicija = zadnja_kazalec_pozicija

	if building_obzidje or building_vrata:
		mis_pozicija = _zlepi_na_obzidje(mis_pozicija)
	elif building_polje:
		var celica = _najblizja_veljavna_celica_polja(mis_pozicija)
		if celica != null:
			mis_pozicija = celica
	elif building_stolp:
		var priklop_stolpa = _zid_najblizje_krajisce(mis_pozicija, ZID_STOLP_SNAP_DOSEG)
		mis_pozicija = priklop_stolpa if priklop_stolpa != null else _zaokrozi_na_mrezo(mis_pozicija)
	else:
		mis_pozicija = _zaokrozi_na_mrezo(mis_pozicija)

	_ghost_tekstura = smer_predogled.texture

	# Gladko (lerp) sledenje ciljni poziciji namesto trenutnega "skoka" vsak
	# okvir - uporabnik je opisal prejšnje premikanje silhuete kot nerodno/
	# trzajoče. Samo če je bila silhueta že prej vidna (torej gre za
	# nadaljevanje istega vlečenja) - ob PRVEM prikazu (npr. ravno vstopili v
	# način postavljanja) se postavi TAKOJ na cilj, brez "priplavanja" od
	# stare/privzete pozicije.
	if _ghost_vidna and delta > 0.0:
		_ghost_pozicija = _ghost_pozicija.lerp(mis_pozicija, clamp(delta * 18.0, 0.0, 1.0))
	else:
		_ghost_pozicija = mis_pozicija

	_ghost_vidna = true

	postavitev_overlay.queue_redraw()


# Kliči namesto "nova.rotation_degrees = ..." pri vsakem _place_* - varno
# je klicati tudi na scenah, ki (še) ne podpirajo smeri (npr. testna lutka).
func _uporabi_smer_gradnje(nova) -> void:
	if nova.has_method("nastavi_smer"):
		nova.nastavi_smer(smer_gradnje)


# Ko igralec postavi novo zgradbo, ki potrebuje gradnjo, samodejno pošlji
# TRENUTNO IZBRANE delavce, naj jo takoj začnejo graditi - brez tega bi
# moral igralec po vsaki postavitvi ROČNO še enkrat tapniti nanjo in ukazati
# gradnjo, čeprav je delavec (da si sploh lahko odprl gradbeni meni) že
# izbran v trenutku postavitve. Namenoma poklican samo iz uspešnih
# _place_* klicev za zgradbe, ki DEJANSKO potrebujejo gradnjo (ne za polje,
# ki se postavi takoj) - noben DRUG ukaz (rudarjenje, popravilo, napad,
# lov) se s tem ne spremeni, tisti ostanejo ročni, kot doslej.
func _avtomatsko_dodeli_gradnjo(nova) -> void:
	if nova == null or not is_instance_valid(nova):
		return
	if not ("v_gradnji" in nova) or not nova.v_gradnji:
		return
	for w in get_tree().get_nodes_in_group("delavci"):
		if is_instance_valid(w) and w.is_selected:
			w.ukazi_gradnja(nova)


# --- Splošna mreža za postavljanje zgradb (razen polja/obzidja/vrat, ki ---
# --- imata svoje posebne, natančnejše sisteme lepljenja) ---

# Velikost ene "celice" nevidne mreže, na katero se izravnajo zgradbe ob
# postavitvi - da se stvari lepo poravnajo namesto na naključen piksel,
# kamor je igralec ravno tapnil (glavni razlog, da je postavljanje prej
# izgledalo "razmetano" oz. da so se stvari čudno prekrivale).
const SVET_MREZA_VELIKOST = 110.0

func _zaokrozi_na_mrezo(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / SVET_MREZA_VELIKOST) * SVET_MREZA_VELIKOST,
		round(pos.y / SVET_MREZA_VELIKOST) * SVET_MREZA_VELIKOST
	)


# --- Prava zasedenost celic mreže (ena zgradba = ena celica) ---
#
# Uporabnikova izrecna želja ("gremo narest na novo obzidje in vrata drugacen
# sistem... imamo mrezo kjer je postavljena igra... stavbe delane po mrezi"):
# vsaka zgradba naj zaseda TOČNO ENO celico te mreže (SVET_MREZA_VELIKOST,
# ista vrednost, ki se zdaj uporablja tudi za obzidje/vrata spodaj), z
# DEJANSKIM preverjanjem zasedenosti - ne le grobim krožnim prekrivanjem kot
# doslej (_prevec_blizu_zgradbe, ki ostaja kot dodatna varovalka za primere,
# ko je slika zgradbe večja od ene celice). NAMENOMA brez shranjenega
# slovarja/tabele zasedenosti (uporabnik: "pri stavbah bi zasedenost pri
# obzidju pa ne" - torej stavbe DA, a to ne pomeni nujno ločene podatkovne
# strukture) - namesto tega vedno na novo preberemo iz get_tree().
# get_nodes_in_group("zgradbe") (enak vzorec kot že obstoječi
# _vse_celice_polja_mreza/_prevec_blizu_zgradbe), kar se izogne problemu
# "obviselih" referenc na uničene zgradbe. Polje/obzidje/vrata NISO del te
# ena-na-celico logike (imajo svoje ločene sisteme), zato so tu izrecno
# izločeni.
const MREZNE_ZGRADBE_IZJEME = ["obzidje", "vrata", "polje"]

func _je_mrezna_zgradba(z) -> bool:
	if not is_instance_valid(z):
		return false
	if not ("tip_zgradbe" in z):
		return true
	return not (z.tip_zgradbe in MREZNE_ZGRADBE_IZJEME)


# --- Rezervirano območje okoli mrežnih zgradb (uporabnikova želja: "stavbe
# bi naredil da zasedejo 6 kvadratkov zato ker ce je preblizu se potem spet
# prekiravajo") ---
#
# Vidna slika zgradbe naj ostane enako velika kot doslej (uporabnikova
# izrecna potrditev: "ne uredu je tako 4 kvadratke ampak zasedenost je pa 6
# kvadratkov") - torej se tu NE spreminja sličica/scale, samo PROSTOR, ki ga
# zgradba rezervira za postavitev sosednjih zgradb, se poveča iz ene same
# celice na približno 6 celic. Namesto pravokotnega (2x3/3x2) območja, kar bi
# zahtevalo izbiro poljubne asimetrične usmerjenosti (ni bilo natančno
# dogovorjeno, katera stran naj ima "dodatni" rob), je tu uporabljen preprost
# IZOTROPEN (v vse smeri enak) krog, katerega PLOŠČINA ustreza 6 celicam:
# ploscina = 6 * SVET_MREZA_VELIKOST^2, polmer = sqrt(ploscina / PI). Dva
# taka kroga se ne prekrivata, če je razdalja med središčema >= vsota
# polmerov (2 * ta polmer, ker imata obe zgradbi isti polmer) - to je
# ZGRADBA_ZASEDENOST_RAZMIK spodaj. Vrednosti izračunani vnaprej (ne kot
# konstantni izraz s sqrt() - GDScript tega v `const` ne dovoli zanesljivo):
# polmer = sqrt(6 * 110^2 / PI) = 152.017..., razmik = 2 * polmer = 304.035.
const ZGRADBA_ZASEDENOST_POLMER = 152.02
const ZGRADBA_ZASEDENOST_RAZMIK = 304.03

# Ali bi zgradba na "pos" (po zaokroženju na mrežo) posegla v rezervirano
# območje (glej zgoraj) katere koli DRUGE mrežne zgradbe? Prej je to
# preverjalo samo strogo isto celico (SVET_MREZA_VELIKOST * 0.5) - zdaj
# preveri celotno rezervirano območje, da so sosednje zgradbe vedno lepo
# narazen.
func _celica_zgradbe_zasedena(pos: Vector2) -> bool:
	var celica = _zaokrozi_na_mrezo(pos)
	for z in get_tree().get_nodes_in_group("zgradbe"):
		if not _je_mrezna_zgradba(z):
			continue
		if z.global_position.distance_to(celica) < ZGRADBA_ZASEDENOST_RAZMIK:
			return true
	return false


# --- Minimalna razdalja od dreves (da zgradbe vizualno ne "sekajo" krošenj) ---

# Približna "polovična velikost" (half-extent) zgradbe iz njene sličice
# (Sprite2D, TRENUTNA smer_gradnje) - brez potrebe, da je zgradba že v
# drevesu. Deljeno med izračunom minimalne razdalje od dreves in mreže
# celic za polje spodaj.
func _priblizna_polovicna_velikost_scene(scena: PackedScene) -> Vector2:
	return _meritve_scene(scena, smer_gradnje)["polovicna"]


# Približna varnostna razdalja od debla drevesa do roba zgradbe, glede na
# velikost njene TRENUTNE (smer_gradnje) sličice - velike zgradbe (npr.
# obzidje, ki je precej širše od ostalih) tako potrebujejo več prostora,
# majhne pa se lahko postavijo bližje. Uporabi VEČJO od širine/višine (ne
# povprečje) - obzidje je npr. zelo široko in nizko, povprečje bi
# minimalno razdaljo močno podcenilo. Približek, glej tudi
# _posodobi_prosojnost_dreves() spodaj za rezervni ukrep (prosojnost krošnje),
# če bi kljub temu prišlo do rahlega prekrivanja.
func _minimalna_razdalja_od_dreves_za(scena: PackedScene) -> float:
	var polovicna = _priblizna_polovicna_velikost_scene(scena)
	return max(85.0, max(polovicna.x, polovicna.y) + 65.0)


# Preveri vse vire. DREVO je poseben primer: velika krošnja ne prepoveduje
# gradnje, ker se med prekrivanjem samodejno prosoji. Nedovoljena je samo
# postavitev neposredno na deblo/majhno talno oviro. Kamen, zlato in hrana
# še naprej uporabljajo svojo vidno površino in običajno varnostno razdaljo.
func _prevec_blizu_vira(pos: Vector2, min_razdalja: float, scena: PackedScene = null, smer: String = "") -> bool:
	var nov_pravokotnik = _vizualni_pravokotnik_scene_na(scena, pos, smer)
	var nov_talni_polmer = _polmer_za_prekrivanje_scene(scena, "")
	var iskalni_doseg = max(min_razdalja + 140.0, max(nov_pravokotnik.size.x, nov_pravokotnik.size.y) * 0.75 + 260.0)
	for vir in _viri_blizu(pos, iskalni_doseg):
		if not is_instance_valid(vir):
			continue

		var tip_vira = int(vir.resource_type) if "resource_type" in vir else -1
		if tip_vira == 0:
			# Drevesna scena ima pravo talno OviraShape (trenutno 24 px). Ne
			# uporabljamo velikega CollisionShape2D za nabiranje niti krošnje.
			var deblo_polmer = 24.0
			var ovira = vir.get_node_or_null("Ovira/OviraShape")
			if ovira != null and ovira.shape is CircleShape2D:
				deblo_polmer = ovira.shape.radius
			if vir.global_position.distance_to(pos) < nov_talni_polmer + deblo_polmer + 8.0:
				return true
			continue

		# Pri kamnu/zlatu/hrani vidna slika ostaja prava ovira.
		if nov_pravokotnik.size != Vector2.ZERO:
			var vir_pravokotnik = _vizualni_svetovni_pravokotnik(vir)
			if nov_pravokotnik.grow(18.0).intersects(vir_pravokotnik):
				return true

		var dodatek := 30.0
		if "resource_type" in vir:
			match tip_vira:
				1, 2:
					dodatek = 35.0 # kamen in zlato
				3:
					dodatek = 20.0 # manjši grm hrane

		if vir.global_position.distance_to(pos) < min_razdalja + dodatek:
			return true
	return false


func _vir_indeks_kljuc(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / VIR_INDEKS_CELICA), floor(pos.y / VIR_INDEKS_CELICA))


func _obnovi_vir_prostorski_indeks() -> void:
	_vir_prostorski_indeks.clear()
	var viri = get_tree().get_nodes_in_group("viri")
	for vir in viri:
		if not is_instance_valid(vir):
			continue
		var kljuc = _vir_indeks_kljuc(vir.global_position)
		if not _vir_prostorski_indeks.has(kljuc):
			_vir_prostorski_indeks[kljuc] = []
		_vir_prostorski_indeks[kljuc].append(vir)
	_vir_indeks_stevilo = viri.size()


# Vrne samo vire iz bližnjih 512-pikselnih območij. Število virov na mapi
# je veliko, zato je to precej ceneje od pregleda celotnega otoka za vsak
# posamezen zid in vsak okvir njegovega predogleda.
func _viri_blizu(pos: Vector2, doseg: float) -> Array:
	var trenutno_stevilo = get_tree().get_node_count_in_group("viri")
	if _vir_indeks_stevilo != trenutno_stevilo:
		_obnovi_vir_prostorski_indeks()
	var rezultat: Array = []
	var min_celica = _vir_indeks_kljuc(pos - Vector2(doseg, doseg))
	var max_celica = _vir_indeks_kljuc(pos + Vector2(doseg, doseg))
	for x in range(min_celica.x, max_celica.x + 1):
		for y in range(min_celica.y, max_celica.y + 1):
			var kljuc = Vector2i(x, y)
			if _vir_prostorski_indeks.has(kljuc):
				for vir in _vir_prostorski_indeks[kljuc]:
					if is_instance_valid(vir):
						rezultat.append(vir)
	return rezultat


# Voda je narisana v svoji TileMapLayer plasti. Za gradnjo uporabimo isto
# plast kot vizualni zemljevid, zato pravilo deluje tudi v manjših zalivih,
# ki niso del popolnoma ravnega zunanjega roba otoka.
func _dobi_vodno_plast_za_gradnjo() -> TileMapLayer:
	if is_instance_valid(_voda_plast_za_gradnjo):
		return _voda_plast_za_gradnjo
	var mapa = get_node_or_null("NovaMapa")
	if mapa != null:
		_voda_plast_za_gradnjo = mapa.find_child("voda", true, false) as TileMapLayer
	return _voda_plast_za_gradnjo


# Obarvana ploščad okoli obeh glavnih stavb je na Tiled plasti "Poti".
# Ta površina je namenjena samo glavni stavbi, delavcem in izdelanim enotam,
# zato nanjo ni dovoljeno postavljati ničesar - niti igralcu niti AI-ju.
func _dobi_poti_plast_za_gradnjo() -> TileMapLayer:
	if is_instance_valid(_poti_plast_za_gradnjo):
		return _poti_plast_za_gradnjo
	var mapa = get_node_or_null("NovaMapa")
	if mapa != null:
		_poti_plast_za_gradnjo = mapa.find_child("Poti", true, false) as TileMapLayer
	return _poti_plast_za_gradnjo


func _tocka_je_na_zasciteni_podlagi(tocka: Vector2) -> bool:
	var poti = _dobi_poti_plast_za_gradnjo()
	if poti == null:
		return false
	var celica = poti.local_to_map(poti.to_local(tocka))
	return poti.get_cell_source_id(celica) != -1


# Preveri več točk dejanskega talnega odtisa bodoče stavbe. Tako ni dovolj,
# da je samo njeno središče zunaj obarvane ploščadi - tudi rob stavbe, polja,
# zidu, vrat ali stolpa ne sme segati nanjo.
func _postavitev_posega_v_zasciteno_obmocje(pos: Vector2, scena: PackedScene, smer: String = "") -> bool:
	if scena == null:
		return _tocka_je_na_zasciteni_podlagi(pos)

	var dejanska_smer = smer if smer != "" else smer_gradnje
	var pot = scena.resource_path
	var tocke: Array[Vector2] = [pos]

	if pot.ends_with("Obzidje.tscn") or pot.ends_with("Vrata.tscn"):
		var dolzina_celic = VRATA_DOLZINA_CELIC if pot.ends_with("Vrata.tscn") else 1
		var os = _zid_korak_za_smer(dejanska_smer).normalized()
		var pravokotno = Vector2(-os.y, os.x)
		var pol_dolzina = ZID_ROB_DOLZINA * float(dolzina_celic) * 0.46
		for faktor in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var vzdolz = pos + os * pol_dolzina * faktor
			tocke.append(vzdolz)
			tocke.append(vzdolz + pravokotno * 10.0)
			tocke.append(vzdolz - pravokotno * 10.0)
	else:
		var meritve = _meritve_scene(scena, dejanska_smer)
		var polmer = float(meritve["kolizijski_polmer"])
		var rx = clamp(polmer * 0.9, 28.0, 105.0)
		var ry = clamp(polmer * 0.55, 18.0, 62.0)
		if pot.ends_with("Polje.tscn"):
			var polovica: Vector2 = meritve["polovicna"]
			rx = clamp(polovica.x * 0.82, 45.0, 125.0)
			ry = clamp(polovica.y * 0.72, 30.0, 72.0)
		tocke.append_array([
			pos + Vector2(rx, 0), pos + Vector2(-rx, 0),
			pos + Vector2(0, ry), pos + Vector2(0, -ry),
			pos + Vector2(rx * 0.65, ry * 0.65),
			pos + Vector2(-rx * 0.65, ry * 0.65),
			pos + Vector2(rx * 0.65, -ry * 0.65),
			pos + Vector2(-rx * 0.65, -ry * 0.65),
		])

	for tocka in tocke:
		if _tocka_je_na_zasciteni_podlagi(tocka):
			return true
	return false


func _tocka_je_na_vodi(tocka: Vector2) -> bool:
	# Zunaj notranjega roba vodnega pasu je vedno voda, tudi če je točka zunaj
	# prvotnih 50 x 50 celic in je morje dodano šele med zagonom igre.
	if not Geometry2D.is_point_in_polygon(tocka, KOPNI_DIAMANT):
		return true

	# Znotraj osnovnega diamanta so na zemljevidu še manjši zalivi. Vsaka
	# zapolnjena celica plasti "voda" je tam namerno negradljiva obala/voda.
	var voda = _dobi_vodno_plast_za_gradnjo()
	if voda == null:
		return false
	var celica = voda.local_to_map(voda.to_local(tocka))
	return voda.get_cell_source_id(celica) != -1


# Preverimo TALNI odtis bodoče stavbe, ne njene visoke slike. Tako npr. streha
# lahko vizualno sega čez obalo, podnožje pa mora v celoti ostati na kopnem.
# Zidovi in vrata dobijo vzorce vzdolž svoje dejanske izometrične osi.
func _postavitev_posega_v_vodo(pos: Vector2, scena: PackedScene, smer: String = "") -> bool:
	if scena == null:
		return _tocka_je_na_vodi(pos)

	var dejanska_smer = smer if smer != "" else smer_gradnje
	var pot = scena.resource_path
	var tocke: Array[Vector2] = [pos]

	if pot.ends_with("Obzidje.tscn") or pot.ends_with("Vrata.tscn"):
		var dolzina_celic = VRATA_DOLZINA_CELIC if pot.ends_with("Vrata.tscn") else 1
		var os = _zid_korak_za_smer(dejanska_smer).normalized()
		var pravokotno = Vector2(-os.y, os.x)
		var pol_dolzina = ZID_ROB_DOLZINA * float(dolzina_celic) * 0.46
		for faktor in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var vzdolz = pos + os * pol_dolzina * faktor
			tocke.append(vzdolz)
			tocke.append(vzdolz + pravokotno * 10.0)
			tocke.append(vzdolz - pravokotno * 10.0)
	else:
		var meritve = _meritve_scene(scena, dejanska_smer)
		var polmer = float(meritve["kolizijski_polmer"])
		var rx = clamp(polmer * 0.9, 28.0, 105.0)
		var ry = clamp(polmer * 0.55, 18.0, 62.0)

		# Polje nima fizične ovire, zato pri njem uporabimo njegovo pravo ploščato
		# izometrično sličico kot talni odtis.
		if pot.ends_with("Polje.tscn"):
			var polovica: Vector2 = meritve["polovicna"]
			rx = clamp(polovica.x * 0.82, 45.0, 125.0)
			ry = clamp(polovica.y * 0.72, 30.0, 72.0)

		tocke.append_array([
			pos + Vector2(rx, 0), pos + Vector2(-rx, 0),
			pos + Vector2(0, ry), pos + Vector2(0, -ry),
			pos + Vector2(rx * 0.65, ry * 0.65),
			pos + Vector2(-rx * 0.65, ry * 0.65),
			pos + Vector2(rx * 0.65, -ry * 0.65),
			pos + Vector2(-rx * 0.65, -ry * 0.65),
		])

	for tocka in tocke:
		if _tocka_je_na_vodi(tocka):
			return true
	return false


# --- Polje: 8 celic tik ob kmetiji, postavljene kot POVEZAN "obroč" (eno ---
# --- zraven drugega vse okoli), namesto starega 3x3 diagonalnega vzorca  ---

# Uporabnik je izrecno želel, da so polja postavljena TIK ob kmetiji, brez
# vidne praznine vmes. Ker izometrične sličice običajno vsebujejo nekaj
# prosojnega roba okoli dejanske slike, mora biti ta "margina" NEGATIVNA
# (celici se torej rahlo približata glede na golo vsoto polovičnih
# velikosti), da polje na koncu res vizualno "prisloni" ob kmetijo.
const POLJE_MREZA_MARGINA = -22.0

const POLJE_TAP_DOSEG_FAKTOR = 0.75


# Polovična velikost KONKRETNE, že postavljene kmetije - namenoma NE
# _priblizna_polovicna_velikost_scene(kmetija_scene) (ki vedno uporabi
# TRENUTNO globalno izbrano smer_gradnje - pravilno za nekaj, kar šele
# postavljaš, a napačno za že obstoječo kmetijo, katere dejanska smer je
# morda čisto druga). Uporabi dejansko živo sličico TE kmetije, da se mreža
# polj vedno ujema z njeno resnično prikazano velikostjo/smerjo.
func _polje_kmetija_pol(kmetija) -> Vector2:
	return _priblizna_polovicna_velikost(kmetija)


# 4 pozicije polj tik ob KONKRETNI kmetiji - samo N/J/V/Z (brez vogalnih
# celic), po uporabnikovi izrecni želji ("naredimo samo 4 polja okoli
# kmetije da so tik ob stavbi").
#
# POPRAVEK (Round 16): prejšnji poskus je končno pozicijo zaokrožil na
# najbližjo mrežno celico (_zaokrozi_na_mrezo, korak 110) - to se je
# izkazalo za NAPAKO, ne izboljšavo. Dejanske polovične velikosti kmetije
# (~160x109) in polja (~130x84) se preprosto ne delijo lepo s 110, zato je
# zaokroževanje na najbližjo celico pri levo/desno razdalji (268) zaokrožilo
# NAVZDOL na 220 - kar je polje dejansko POTISNILO 48px PREGLOBOKO v
# kmetijo (vidno prekrivanje) - pri zgoraj/spodaj razdalji (171.5) pa
# NAVZGOR na 220, kar je pustilo 48px VRZELI namesto "tik ob stavbi". Ker je
# bila uporabnikova prva in ponovljena zahteva izrecno "tik ob kmetiji, brez
# vrzeli", je to pomembnejše od dobesednega poravnavanja na 110-mrežo, ki se
# s temi konkretnimi velikostmi sličic sploh ne izide natančno - zato je
# zaokroževanje na mrežo tu ODSTRANJENO, ostane samo prvotni izračun iz
# dejanskih polovičnih velikosti sličic (kmetija_pol/polje_pol +
# POLJE_MREZA_MARGINA), ki je tik-ob-stavbi lastnost dosegal pravilno.
func _polje_obroc_pozicije(kmetija) -> Array:
	var kmetija_pol = _polje_kmetija_pol(kmetija)
	var polje_pol = _priblizna_polovicna_velikost_scene(polje_scene)

	var y_korak = kmetija_pol.y + polje_pol.y + POLJE_MREZA_MARGINA
	var x_korak = kmetija_pol.x + polje_pol.x + POLJE_MREZA_MARGINA

	var sredina = kmetija.global_position

	return [
		sredina + Vector2(-x_korak, 0),
		sredina + Vector2(x_korak, 0),
		sredina + Vector2(0, -y_korak),
		sredina + Vector2(0, y_korak),
	]


# Seznam VSEH kandidatnih celic "obroča" okoli VSEH obstoječih kmetij, vsaka
# označena, ali je trenutno veljavna ({"pozicija":.., "veljavna":..}).
# Celica je "veljavna" samo, če (a) je še ne zaseda drugo polje IN (b) na
# njej ne stoji nobena DRUGA zgradba/objekt (npr. če je kmetija zgrajena
# tik ob hiši ali obzidju, se tista prekrivajoča celica izloči) IN (c) ni
# preblizu drevesa. Vrne VSE kandidatne celice (ne samo proste), da jih
# risanje (glej _narisi_postavitveni_overlay) lahko obarva zeleno/rdeče -
# uporabnik naj VIDI tudi zakaj neka celica ni na voljo, ne samo da izgine.
func _vse_celice_polja_mreza() -> Array:
	var zasedene_pozicije: Array = []
	for z in get_tree().get_nodes_in_group("zgradbe"):
		if is_instance_valid(z) and z.tip_zgradbe == "polje":
			zasedene_pozicije.append(z.global_position)

	var polje_polmer = _polmer_za_prekrivanje_scene(polje_scene, "polje")
	var min_razdalja_dreves = _minimalna_razdalja_od_dreves_za(polje_scene)
	var polje_pol = _priblizna_polovicna_velikost_scene(polje_scene)
	var min_razdalja_zasedeno = min(polje_pol.x, polje_pol.y) * 0.8

	var vse: Array = []

	for kmetija in get_tree().get_nodes_in_group("zgradbe"):
		if not is_instance_valid(kmetija) or kmetija.tip_zgradbe != "kmetija":
			continue

		for celica in _polje_obroc_pozicije(kmetija):

			var veljavna = true
			if _postavitev_posega_v_vodo(celica, polje_scene, smer_gradnje):
				veljavna = false
			if _postavitev_posega_v_zasciteno_obmocje(celica, polje_scene, smer_gradnje):
				veljavna = false
			for zp in zasedene_pozicije:
				if zp.distance_to(celica) < min_razdalja_zasedeno:
					veljavna = false
					break

			if veljavna and _prevec_blizu_zgradbe(celica, polje_polmer, false):
				veljavna = false

			if veljavna and _prevec_blizu_vira(celica, min_razdalja_dreves, polje_scene, smer_gradnje):
				veljavna = false

			vse.append({"pozicija": celica, "veljavna": veljavna})

	return vse


# Samo trenutno PROSTE (veljavne) celice - uporabljeno za dejansko
# preverjanje/najbližjo-celico logiko (tap mora zadeti eno od teh).
func _prosta_polja_mreza() -> Array:
	var proste: Array = []
	for vnos in _vse_celice_polja_mreza():
		if vnos["veljavna"]:
			proste.append(vnos["pozicija"])
	return proste


# Vrne pozicijo najbližje veljavne (proste) celice "obroča" okoli katere
# koli obstoječe kmetije, če je tap dovolj blizu nje - sicer null (neveljavna
# postavitev).
func _najblizja_veljavna_celica_polja(pos: Vector2):
	var polje_pol = _priblizna_polovicna_velikost_scene(polje_scene)
	var doseg = max(polje_pol.x, polje_pol.y) * POLJE_TAP_DOSEG_FAKTOR

	var najblizja = null
	var najkrajsa = INF

	for celica in _prosta_polja_mreza():
		var d = celica.distance_to(pos)
		if d < najkrajsa:
			najkrajsa = d
			najblizja = celica

	if najblizja != null and najkrajsa <= doseg:
		return najblizja
	return null


func _place_house(pos) -> bool:

	pos = _zaokrozi_na_mrezo(pos)
	if not _fog_dovoli_gradnjo(pos):
		return false

	if _postavitev_posega_v_vodo(pos, hisa_scene, smer_gradnje):
		_pokazi_obvestilo("Na vodi ni mogoče graditi")
		return false
	if _postavitev_posega_v_zasciteno_obmocje(pos, hisa_scene, smer_gradnje):
		_pokazi_obvestilo("Na obarvanem območju glavne stavbe ni mogoče graditi")
		return false

	if _celica_zgradbe_zasedena(pos):
		print("Ta celica mreže je že zasedena")
		_pokazi_obvestilo("Ta celica mreže je že zasedena")
		return false

	var min_razdalja = _minimalna_razdalja_od_dreves_za(hisa_scene)
	if _prevec_blizu_vira(pos, min_razdalja, hisa_scene, smer_gradnje):
		print("Hiša je preblizu vira")
		_pokazi_obvestilo("Hiša je preblizu drevesa, kamna ali drugega vira")
		return false

	if _prevec_blizu_zgradbe(pos, _polmer_za_prekrivanje_scene(hisa_scene, "hisa"), false):
		print("Tu že stoji druga zgradba")
		_pokazi_obvestilo("Tu že stoji druga zgradba")
		return false

	var nova = hisa_scene.instantiate()

	nova.global_position = pos
	_uporabi_smer_gradnje(nova)

	add_child(nova)
	_zahtevaj_posodobitev_navigacije()
	_avtomatsko_dodeli_gradnjo(nova)

	print("Nova hiša")
	return true


func zgradba_dokoncana(zgradba):

	if not is_instance_valid(zgradba):
		return

	if zgradba.tip_zgradbe == "hisa":
		max_pop += 5
		update_ui()
		print("Hiša dokončana, +5 populacije")


# Osnovna populacija (brez katere koli hiše) - uporabljeno kot spodnja meja,
# da rušenje hiš nikoli ne spravi max_pop pod to izhodiščno vrednost.
const OSNOVNA_MAX_POP = 5


# Polje pokliče to funkcijo ob koncu vsake žetve. Polje in njegov namenski
# kmet ostaneta, njiva se vrne na prazno sliko in takoj začne nov cikel rasti.
func polje_pobrano(polje, kolicina_hrane: int) -> void:
	if not is_instance_valid(polje):
		return

	add_resource("FOOD", kolicina_hrane)
	_pokazi_obvestilo("Žetev končana: +%d hrane. Polje ponovno raste." % kolicina_hrane)


# Klicano OB VSAKI izgubi igralčeve zgradbe - tako ob uničenju v boju
# (zgradba.gd:take_damage) KOT ob ročnem rušenju (glej _on_zrusi_button_
# pressed spodaj) - EN sam kraj, ki poskrbi, da se ustrezno štetje
# (stevilo_vojasnic/stevilo_zidov/stevilo_stolpov/stevilo_polj/oddajne_
# zgradbe[...]["count"]/max_pop) vedno ujema z dejansko živimi zgradbami.
# Prej se je to (namerno ali ne) zgodilo samo ob ročni gradnji, nikoli ob
# izgubi - zgradba, uničena v boju, je za vedno "zasedla" svoje mesto v
# štetju, kar bi igralca lahko trajno blokiralo pri obnovi (npr. edina
# dovoljena vojašnica).
func zgradba_unicena(zgradba):

	if not is_instance_valid(zgradba):
		return

	if not ("tip_zgradbe" in zgradba):
		return
	if "rally_zastavica" in zgradba and is_instance_valid(zgradba.rally_zastavica):
		zgradba.rally_zastavica.queue_free()
		zgradba.rally_zastavica = null

	match zgradba.tip_zgradbe:
		"hisa":
			max_pop = max(OSNOVNA_MAX_POP, max_pop - 5)
		"vojasnica":
			stevilo_vojasnic = max(0, stevilo_vojasnic - 1)
			if vojasnica_ref == zgradba:
				vojasnica_ref = null
				vojasnica_level = 0
			posodobi_max_vojasko_populacijo()
		"stolp":
			stevilo_stolpov = max(0, stevilo_stolpov - 1)
		"obzidje", "vrata":
			stevilo_zidov = max(0, stevilo_zidov - 1)
		"polje":
			stevilo_polj = max(0, stevilo_polj - 1)
		"drvarnica":
			oddajne_zgradbe["WOOD"]["count"] = max(0, oddajne_zgradbe["WOOD"]["count"] - 1)
		"kamnolom":
			oddajne_zgradbe["STONE"]["count"] = max(0, oddajne_zgradbe["STONE"]["count"] - 1)
		"rudnik":
			oddajne_zgradbe["GOLD"]["count"] = max(0, oddajne_zgradbe["GOLD"]["count"] - 1)
		"kmetija":
			oddajne_zgradbe["FOOD"]["count"] = max(0, oddajne_zgradbe["FOOD"]["count"] - 1)

	if selected_building == zgradba:
		selected_building = null
		_posodobi_gradbeni_panel()

	_zahtevaj_posodobitev_navigacije()
	update_ui()


# Gumb "Zruši" (glej PanelZrusi/ButtonZrusi v main.tscn) - na voljo za VSAKO
# izbrano igralčevo zgradbo RAZEN glavne hiše (ki bi končala igro). NAMENOMA
# brez vračila surovin (v igri trenutno ni sistema za vračilo, glej opombo
# pri _on_preklici_button_pressed) - samo takojšnja odstranitev, enako kot bi
# jo sovražnik uničil v boju (deli isto zgradba_unicena štetje zgoraj).
func _on_zrusi_button_pressed() -> void:

	if selected_building == null or not is_instance_valid(selected_building):
		return

	if selected_building.is_in_group("glavna_hisa"):
		return

	var zgradba = selected_building
	zgradba_unicena(zgradba)
	zgradba.queue_free()

	_pokazi_obvestilo("Zgradba zrušena")



func _place_oddajno_zgradbo(pos) -> bool:

	pos = _zaokrozi_na_mrezo(pos)
	if not _fog_dovoli_gradnjo(pos):
		return false

	if _postavitev_posega_v_vodo(pos, zgradba_za_postavitev, smer_gradnje):
		_pokazi_obvestilo("Na vodi ni mogoče graditi")
		return false
	if _postavitev_posega_v_zasciteno_obmocje(pos, zgradba_za_postavitev, smer_gradnje):
		_pokazi_obvestilo("Na obarvanem območju glavne stavbe ni mogoče graditi")
		return false

	if _celica_zgradbe_zasedena(pos):
		print("Ta celica mreže je že zasedena")
		_pokazi_obvestilo("Ta celica mreže je že zasedena")
		return false

	var min_razdalja = _minimalna_razdalja_od_dreves_za(zgradba_za_postavitev)
	if _prevec_blizu_vira(pos, min_razdalja, zgradba_za_postavitev, smer_gradnje):
		print("Zgradba je preblizu vira")
		_pokazi_obvestilo("Zgradba je preblizu drevesa, kamna ali drugega vira")
		return false

	if _prevec_blizu_zgradbe(pos, _polmer_za_prekrivanje_scene(zgradba_za_postavitev, zgradba_kljuc), false):
		print("Tu že stoji druga zgradba")
		_pokazi_obvestilo("Tu že stoji druga zgradba")
		return false

	var podatki = oddajne_zgradbe[zgradba_kljuc]

	var nova = zgradba_za_postavitev.instantiate()

	nova.global_position = pos
	_uporabi_smer_gradnje(nova)

	nova.add_to_group(podatki["group"])

	add_child(nova)
	_zahtevaj_posodobitev_navigacije()
	_avtomatsko_dodeli_gradnjo(nova)

	podatki["count"] += 1

	zgradba_za_postavitev = null
	zgradba_kljuc = ""

	print("Zgradba zgrajena: ", podatki["group"])
	return true
	
func select_single_actor(actor):

	for w in get_tree().get_nodes_in_group("delavci"):
		if is_instance_valid(w):
			w.set_selected(w == actor)

	for u in get_tree().get_nodes_in_group("enote"):
		if is_instance_valid(u):
			u.set_selected(u == actor)

func _handle_single_click(mouse_pos):

	print("KLIK MAPA")

	var delavci = get_tree().get_nodes_in_group("delavci")

	for d in delavci:
		if d.is_selected:
			print("IMAM DELAVCA")

			for drevo in get_tree().get_nodes_in_group("trees"):
				print("NAŠEL DREVO:", drevo.name)

				d.start_mining(drevo)
				return

# Vsa risalna logika za izbirni pravokotnik/mrežo/"duha" postavitve je
# ZDAJ tukaj, klicana IZ PostavitevOverlay._draw() (glej postavitev_overlay.gd
# in opombo pri "postavitev_overlay" zgoraj) - "platno" je to ločeno
# vozlišče, NE Main/self, zato vse draw_*/to_local klice namensko kličemo
# NA "platno", ne implicitno na self.
func _podatki_zidnega_predogleda(scena: PackedScene, smer: String) -> Dictionary:
	var kljuc = str(scena.resource_path) + ":" + smer
	if _zid_predogled_cache.has(kljuc):
		return _zid_predogled_cache[kljuc]

	var podatki = {"tekstura": null, "odmik": Vector2.ZERO, "merilo": Vector2.ONE}
	if scena != null:
		var zacasna = scena.instantiate()
		if zacasna.has_method("nastavi_smer"):
			zacasna.nastavi_smer(smer)
		for otrok in zacasna.get_children():
			if otrok is Sprite2D and otrok.texture != null:
				podatki = {"tekstura": otrok.texture, "odmik": otrok.position, "merilo": otrok.scale}
				break
		zacasna.free()
	_zid_predogled_cache[kljuc] = podatki
	return podatki


# Zidni kandidat je prikazan s pravo sličico in tanko črto med njegovima
# krajiščema. Ni več velikih kvadratov/pravokotnikov, ki so zakrili sliko in
# dajali vtis, da se zid postavlja po zmedeni mreži.
func _narisi_zidni_kandidat(platno: CanvasItem, kandidat: Dictionary, scena: PackedScene, dolzina_celic: int) -> void:
	var smer = str(kandidat["smer"])
	var pozicija: Vector2 = kandidat["pozicija"]
	var veljavna = bool(kandidat["veljavna"])
	var barva = Color(0.3, 1.0, 0.4, 0.9) if veljavna else Color(1.0, 0.25, 0.2, 0.9)
	var podatki = _podatki_zidnega_predogleda(scena, smer)
	var tekstura = podatki["tekstura"]
	if tekstura != null:
		var merilo: Vector2 = podatki["merilo"]
		var odmik: Vector2 = podatki["odmik"]
		var velikost: Vector2 = tekstura.get_size() * merilo.abs()
		var sredina = platno.to_local(pozicija + odmik)
		var rect = Rect2(sredina - velikost * 0.5, velikost)
		var tint = Color(0.85, 1.0, 0.85, 0.58) if veljavna else Color(1.0, 0.45, 0.4, 0.55)
		platno.draw_texture_rect(tekstura, rect, false, tint)

	var krajisci = _zid_krajisci_iz_podatkov(pozicija, smer, dolzina_celic)
	var a = platno.to_local(krajisci[0])
	var b = platno.to_local(krajisci[1])
	platno.draw_line(a, b, barva, 5.0, true)
	platno.draw_circle(a, 5.0, barva)
	platno.draw_circle(b, 5.0, barva)


func _narisi_postavitveni_overlay(platno: CanvasItem) -> void:

	if is_dragging and not _obzidje_vlek_aktiven:

		var p1 = platno.to_local(drag_start)
		var p2 = platno.to_local(drag_end)

		var rect = Rect2(
			Vector2(min(p1.x, p2.x), min(p1.y, p2.y)),
			Vector2(abs(p2.x - p1.x), abs(p2.y - p1.y))
		)

		platno.draw_rect(rect, Color(1, 1, 1, 0.2), true)
		platno.draw_rect(rect, Color(1, 1, 1, 1), false, 2)

	if _v_nacinu_postavljanja() and not building_polje and not (building_obzidje or building_vrata):
		# Navadne zgradbe še uporabljajo preprosto mrežo. Za obzidje in vrata
		# je mreža odslej popolnoma nevidna; igralec vidi le pravi zidni kos.
		var zoom = camera.zoom if camera.zoom.x > 0.0 else Vector2(1, 1)
		var vidno_pol = (get_viewport_rect().size / zoom) * 0.5
		var sredisce = camera.global_position
		var zgoraj_levo = sredisce - vidno_pol
		var spodaj_desno = sredisce + vidno_pol

		var barva_mreze = Color(1, 1, 1, 0.16)

		var x = floor(zgoraj_levo.x / SVET_MREZA_VELIKOST) * SVET_MREZA_VELIKOST
		while x <= spodaj_desno.x:
			platno.draw_line(platno.to_local(Vector2(x, zgoraj_levo.y)), platno.to_local(Vector2(x, spodaj_desno.y)), barva_mreze, 1.0)
			x += SVET_MREZA_VELIKOST

		var y = floor(zgoraj_levo.y / SVET_MREZA_VELIKOST) * SVET_MREZA_VELIKOST
		while y <= spodaj_desno.y:
			platno.draw_line(platno.to_local(Vector2(zgoraj_levo.x, y)), platno.to_local(Vector2(spodaj_desno.x, y)), barva_mreze, 1.0)
			y += SVET_MREZA_VELIKOST

	if building_polje:
		# Pri polju pokaži VSEH 8 kandidatnih celic naenkrat, ne samo tisto,
		# kjer je trenutno prst/miška - VELJAVNE (proste, brez prekrivanja)
		# zeleno, NEVELJAVNE (zaseda jih druga zgradba/drevo/že obstoječe
		# polje) pa rdeče, da igralec takoj vidi CELOTEN vzorec IN razlog,
		# zakaj neke celice ne more uporabiti, namesto da bi ta preprosto
		# izginila.
		var polje_pol = _priblizna_polovicna_velikost_scene(polje_scene)
		for vnos in _vse_celice_polja_mreza():
			var lok = platno.to_local(vnos["pozicija"])
			var r = Rect2(lok - polje_pol, polje_pol * 2.0)
			var barva = Color(0.3, 1.0, 0.4, 0.9) if vnos["veljavna"] else Color(1.0, 0.25, 0.2, 0.85)
			platno.draw_rect(r, barva, false, 2)
			platno.draw_rect(r, Color(barva.r, barva.g, barva.b, 0.15), true)

	if _obzidje_sidro != null and is_instance_valid(_obzidje_sidro):
		# Igralec je tapnil na obstoječi segment obzidja/vrat - namesto ene
		# sledeče silhuete pokažemo VSE smeri, kamor se od tega segmenta da
		# (ali NE da) razširiti zid naenkrat, enako obarvano zeleno/rdeče kot
		# pri polju - glej _obzidje_kandidati_za_sidro.
		var sidro_lok = platno.to_local(_obzidje_sidro.global_position)
		platno.draw_circle(sidro_lok, 8.0, Color(1.0, 0.9, 0.2, 0.9))

		var kandidat_scena = vrata_scene if building_vrata else obzidje_scene
		var kandidat_dolzina = VRATA_DOLZINA_CELIC if building_vrata else 1
		for kandidat in _obzidje_kandidati:
			_narisi_zidni_kandidat(platno, kandidat, kandidat_scena, kandidat_dolzina)

	if _obzidje_vlek_aktiven:
		# Igralec z miško VLEČE, da postavi cel niz segmentov naenkrat - glej
		# _obzidje_izracunaj_verigo. Prikaži živo (vsak okvir na novo
		# izračunan) predogled cele verige, enako obarvano zeleno/rdeče.
		platno.draw_line(platno.to_local(drag_start), platno.to_local(drag_end), Color(1, 1, 1, 0.5), 2.0)

		var vlek_scena = vrata_scene if building_vrata else obzidje_scene
		var vlek_dolzina = VRATA_DOLZINA_CELIC if building_vrata else 1
		for kandidat in _obzidje_izracunaj_verigo(drag_start, drag_end):
			_narisi_zidni_kandidat(platno, kandidat, vlek_scena, vlek_dolzina)

	if _ghost_vidna and _ghost_tekstura != null:

		var velikost = _ghost_tekstura.get_size() * _ghost_merilo.abs()
		var sredina = platno.to_local(_ghost_pozicija + _ghost_odmik)

		var rect2 = Rect2(
			sredina - velikost * 0.5,
			velikost
		)

		var barva = Color(0.2, 1.0, 0.3, 0.9) if _postavitev_veljavna() else Color(1.0, 0.25, 0.2, 0.9)

		# Dejanska polprozorna slika zgradbe (ne samo okvir) - narisana
		# NEPOSREDNO tukaj, brez ločenega Sprite2D vozlišča, ki se je v
		# prejšnjih poskusih izkazalo za nezanesljivo (verjetno zato, ker
		# ga koda z $NodePath ni znala zanesljivo najti). Narisano na
		# "platno" (PostavitevOverlay), ki ima visok z_index, da se to
		# res vidi NAD zemljevidom/zgradbami/drevesi, ne pod njimi.
		platno.draw_texture_rect(_ghost_tekstura, rect2, false, Color(1, 1, 1, 0.6))

		if building_obzidje or building_vrata:
			var dolzina = VRATA_DOLZINA_CELIC if building_vrata else 1
			var kraji = _zid_krajisci_iz_podatkov(_ghost_pozicija, smer_gradnje, dolzina)
			platno.draw_line(platno.to_local(kraji[0]), platno.to_local(kraji[1]), barva, 5.0, true)
			platno.draw_circle(platno.to_local(kraji[0]), 5.0, barva)
			platno.draw_circle(platno.to_local(kraji[1]), 5.0, barva)
		else:
			platno.draw_rect(rect2, barva, false, 4)
			platno.draw_rect(rect2, Color(barva.r, barva.g, barva.b, 0.12), true)


# Ali bi bila postavitev na trenutni "duhovi" poziciji sploh veljavna (za
# obarvanje kvadrata postavitve zeleno/rdeče) - ne spreminja stanja igre,
# samo preveri.
func _postavitev_veljavna() -> bool:

	var pozicija = zadnja_kazalec_pozicija
	if building_obzidje or building_vrata:
		pozicija = _zlepi_na_obzidje(pozicija)
		if _obzidje_ze_zaseceno(pozicija, smer_gradnje, _dolzina_trenutne_gradnje_v_celicah()):
			return false

	if building_polje:
		var polje_celica = _najblizja_veljavna_celica_polja(pozicija)
		if polje_celica == null:
			return false
		return _fog_je_pozicija_trenutno_vidna(polje_celica)
	elif building_obzidje or building_vrata:
		pass
	elif building_stolp:
		var priklop_stolpa = _zid_najblizje_krajisce(pozicija, ZID_STOLP_SNAP_DOSEG)
		pozicija = priklop_stolpa if priklop_stolpa != null else _zaokrozi_na_mrezo(pozicija)
	else:
		pozicija = _zaokrozi_na_mrezo(pozicija)

	if not _fog_je_pozicija_trenutno_vidna(pozicija):
		return false

	var scena = _scena_za_trenutno_postavitev()

	if _postavitev_posega_v_vodo(pozicija, scena, smer_gradnje):
		return false
	if _postavitev_posega_v_zasciteno_obmocje(pozicija, scena, smer_gradnje):
		return false

	if not (building_obzidje or building_vrata) and _celica_zgradbe_zasedena(pozicija):
		return false

	var min_razdalja = _minimalna_razdalja_od_dreves_za(scena)
	if _prevec_blizu_vira(pozicija, min_razdalja, scena, smer_gradnje):
		return false

	var je_zid = building_obzidje or building_vrata
	var tip = "obzidje" if building_obzidje else ("vrata" if building_vrata else "")
	var nov_polmer = _polmer_za_prekrivanje_scene(scena, tip)
	var nov_tip = "stolp" if building_stolp else tip
	if _prevec_blizu_zgradbe(pozicija, nov_polmer, je_zid, smer_gradnje, _dolzina_trenutne_gradnje_v_celicah(), nov_tip):
		return false

	return true


# --- Preprečitev postavitve zgradbe NAVZKRIŽ druge zgradbe ---

# Polmer za grobo "krožno" preverjanje prekrivanja med zgradbama. Za
# obzidje/vrata namenoma uporabi majhen polmer, vezan na njuno DEJANSKO
# (ozko) fizično kolizijo (glej RectangleShape2D 100x25), NE na njuno
# široko vizualno sličico - drugače bi bila vsaka zgradba v bližini
# katerega koli koska zidu vedno "preblizu", čeprav se v resnici sploh ne
# prekrivata. Za vse ostale zgradbe uporabi večjo od širine/višine slike.
# Polmer za grobo krožno preverjanje prekrivanja med zgradbama - iz
# DEJANSKE fizične kolizijske oblike (Ovira/OviraShape ali neposredni
# CollisionShape2D), NE iz široke vizualne sličice. Prej je ta funkcija
# uporabljala velikost sličice, kar je za velike zgradbe (npr. glavna
# hiša, ki je skalirana 1.6x) dalo tako velik polmer, da je blokiralo
# postavljanje SKORAJ VSEGA v bližini baze - ravno tam, kjer igralec
# najprej gradi. Kolizijski polmer je veliko manjši in bolj realen.
func _kolizijski_polmer(vozlisce) -> float:
	var shape_node = vozlisce.get_node_or_null("Ovira/OviraShape")
	if shape_node == null:
		shape_node = vozlisce.get_node_or_null("CollisionShape2D")
	if shape_node == null or shape_node.shape == null:
		return 45.0
	var shape = shape_node.shape
	if shape is CircleShape2D:
		return shape.radius
	if shape is RectangleShape2D:
		return max(shape.size.x, shape.size.y) * 0.5
	return 45.0


func _polmer_za_prekrivanje(z) -> float:
	return _kolizijski_polmer(z)


func _polmer_za_prekrivanje_scene(scena: PackedScene, tip: String) -> float:
	return float(_meritve_scene(scena, smer_gradnje)["kolizijski_polmer"])


func _ne_zidne_zgradbe() -> Array:
	var stevilo = get_tree().get_node_count_in_group("zgradbe") + get_tree().get_node_count_in_group("ai_zgradbe")
	if _ne_zidne_zgradbe_cache_stevilo == stevilo:
		return _ne_zidne_zgradbe_cache
	_ne_zidne_zgradbe_cache = []
	var videni: Dictionary = {}
	var vse = get_tree().get_nodes_in_group("zgradbe") + get_tree().get_nodes_in_group("ai_zgradbe")
	var gh = get_tree().get_first_node_in_group("glavna_hisa")
	var ai = get_tree().get_first_node_in_group("ai_baza")
	if gh:
		vse.append(gh)
	if ai:
		vse.append(ai)
	for z in vse:
		if not is_instance_valid(z) or videni.has(z.get_instance_id()):
			continue
		videni[z.get_instance_id()] = true
		var z_je_zid = "tip_zgradbe" in z and (z.tip_zgradbe == "obzidje" or z.tip_zgradbe == "vrata")
		if not z_je_zid:
			_ne_zidne_zgradbe_cache.append(z)
	_ne_zidne_zgradbe_cache_stevilo = stevilo
	return _ne_zidne_zgradbe_cache


# Ali bi nova zgradba (polmer "nov_polmer", na "pos") prekrivala katero
# koli obstoječo zgradbo (igralčevo ALI AI-jevo, vključno z glavnima
# stavbama)? Dva zidova/vrata segmenta smeta biti tik skupaj - to je
# namen _zlepi_na_obzidje - zato se ta kombinacija izpusti.
func _prevec_blizu_zgradbe(pos: Vector2, nov_polmer: float, nov_je_zid: bool, nov_smer: String = "", nov_dolzina: int = 1, nov_tip: String = "") -> bool:
	# Pri zidnem predogledu ni treba stokrat pregledovati vseh že postavljenih
	# zidov, saj njihovo zasedenost natančneje preverja robni hash spodaj.
	var vse = _ne_zidne_zgradbe() if nov_je_zid else get_tree().get_nodes_in_group("zgradbe") + get_tree().get_nodes_in_group("ai_zgradbe")
	if not nov_je_zid:
		var gh = get_tree().get_first_node_in_group("glavna_hisa")
		if gh:
			vse.append(gh)
		var ai = get_tree().get_first_node_in_group("ai_baza")
		if ai:
			vse.append(ai)

	for z in vse:
		if not is_instance_valid(z):
			continue

		var z_je_zid = "tip_zgradbe" in z and (z.tip_zgradbe == "obzidje" or z.tip_zgradbe == "vrata")
		if nov_je_zid and z_je_zid:
			continue

		# Stolp je dovoljen NATANKO v krajišču zidu, zid pa se sme končati
		# NATANKO v središču stolpa. To je povezava, ne prekrivanje.
		var z_je_stolp = "tip_zgradbe" in z and z.tip_zgradbe == "stolp"
		if nov_je_zid and z_je_stolp:
			var zid_smer = nov_smer if nov_smer != "" else smer_gradnje
			for krajisce in _zid_krajisci_iz_podatkov(pos, zid_smer, nov_dolzina):
				if krajisce.distance_to(z.global_position) < 18.0:
					z_je_stolp = false
					break
			if not z_je_stolp:
				continue

		if nov_tip == "stolp" and z_je_zid:
			var z_dolzina = VRATA_DOLZINA_CELIC if z.tip_zgradbe == "vrata" else 1
			var z_smer = z.smer_zgradbe if "smer_zgradbe" in z else "jug"
			for krajisce in _zid_krajisci_iz_podatkov(z.global_position, z_smer, z_dolzina):
				if krajisce.distance_to(pos) < 18.0:
					z_je_zid = false
					break
			if not z_je_zid:
				continue

		var obst_polmer = _polmer_za_prekrivanje(z)
		if pos.distance_to(z.global_position) < nov_polmer + obst_polmer + 15.0:
			return true

	return false


func _zacni_gradnjo_zgradbe(resource_key: String):

	var podatki = oddajne_zgradbe[resource_key]

	if podatki["count"] >= podatki["max"]:
		print("Doseženo največje število za: ", resource_key)
		_pokazi_obvestilo("Doseženo največje število za: " + resource_key)
		return

	if resources["WOOD"] < podatki["cost"]:
		print("Premalo lesa")
		_pokazi_obvestilo("Premalo lesa")
		return

	resources["WOOD"] -= podatki["cost"]
	zgradba_za_postavitev = podatki["scene"]
	zgradba_kljuc = resource_key
	_ponastavi_rotacijo_gradnje()
	update_ui()

	print("Postavi zgradbo: ", resource_key)


func _on_drvarnica_button_pressed():
	_zacni_gradnjo_zgradbe("WOOD")


func _on_kamnolom_button_pressed():
	_zacni_gradnjo_zgradbe("STONE")


func _on_rudnik_button_pressed():
	_zacni_gradnjo_zgradbe("GOLD")


func _on_kmetija_button_pressed():
	_zacni_gradnjo_zgradbe("FOOD")


func _on_polje_button_pressed():

	if oddajne_zgradbe["FOOD"]["count"] <= 0:
		print("Najprej zgradi kmetijo")
		_pokazi_obvestilo("Najprej zgradi kmetijo")
		return

	if stevilo_polj >= max_polj:
		print("Doseženo največje število polj")
		_pokazi_obvestilo("Doseženo največje število polj")
		return

	if resources["WOOD"] < cena_polja:
		print("Premalo lesa")
		_pokazi_obvestilo("Premalo lesa")
		return

	resources["WOOD"] -= cena_polja
	building_polje = true
	_ponastavi_rotacijo_gradnje()
	update_ui()

	print("Postavi polje")


func _place_polje(pos) -> bool:

	var celica = _najblizja_veljavna_celica_polja(pos)
	if celica == null:
		print("Polje lahko postaviš samo tik ob kmetiji (eno od 8 polj okoli nje)")
		_pokazi_obvestilo("Polje lahko postaviš samo tik ob kmetiji (eno od 8 polj okoli nje)")
		return false
	if not _fog_dovoli_gradnjo(celica):
		return false

	if _postavitev_posega_v_vodo(celica, polje_scene, smer_gradnje):
		_pokazi_obvestilo("Na vodi ni mogoče graditi")
		return false
	if _postavitev_posega_v_zasciteno_obmocje(celica, polje_scene, smer_gradnje):
		_pokazi_obvestilo("Na obarvanem območju glavne stavbe ni mogoče graditi")
		return false

	var min_razdalja = _minimalna_razdalja_od_dreves_za(polje_scene)
	if _prevec_blizu_vira(celica, min_razdalja, polje_scene, smer_gradnje):
		print("Ta celica je preblizu vira - izberi drugo")
		_pokazi_obvestilo("Polje je preblizu drevesa, kamna ali drugega vira")
		return false

	# OPOMBA: namenoma NE kličemo splošnega _prevec_blizu_zgradbe() tukaj na
	# LASTNO kmetijo - razmik celic (_polje_obroc_pozicije) je že posebej
	# izračunan tako, da se ne prekriva s kmetijo, ki je nujno tik zraven
	# vsake celice po zasnovi. Prekrivanje z DRUGIMI zgradbami/drevesi je že
	# preverjeno prej, v _vse_celice_polja_mreza() (od koder je "celica"
	# sploh prišla - _najblizja_veljavna_celica_polja vrača samo proste,
	# torej že filtrirane, celice).

	var nova = polje_scene.instantiate()

	nova.global_position = celica
	_uporabi_smer_gradnje(nova)

	add_child(nova)

	stevilo_polj += 1

	print("Polje zgrajeno")
	return true


func _on_vojasnica_button_pressed():

	# Pogoj se bere neposredno iz dejanske baze. Tako ga ne more pokvariti
	# zastarela skupna spremenljivka po shranjevanju ali izračunu populacije.
	glavna_stavba_level = _nivo_glavne_baze()
	if glavna_stavba_level < 2:
		print("Za vojašnico moraš najprej nadgraditi glavno stavbo (level 2)")
		return

	if stevilo_vojasnic >= max_vojasnic:
		print("Vojašnica je že zgrajena")
		return

	if resources["STONE"] < cena_vojasnice:
		print("Premalo kamna")
		_pokazi_obvestilo("Premalo kamna")
		return

	resources["STONE"] -= cena_vojasnice
	building_vojasnica = true
	_ponastavi_rotacijo_gradnje()
	update_ui()

	print("Postavi vojašnico")


func _place_vojasnica(pos) -> bool:

	pos = _zaokrozi_na_mrezo(pos)
	if not _fog_dovoli_gradnjo(pos):
		return false

	if _postavitev_posega_v_vodo(pos, vojasnica_scene, smer_gradnje):
		_pokazi_obvestilo("Na vodi ni mogoče graditi")
		return false
	if _postavitev_posega_v_zasciteno_obmocje(pos, vojasnica_scene, smer_gradnje):
		_pokazi_obvestilo("Na obarvanem območju glavne stavbe ni mogoče graditi")
		return false

	if _celica_zgradbe_zasedena(pos):
		print("Ta celica mreže je že zasedena")
		_pokazi_obvestilo("Ta celica mreže je že zasedena")
		return false

	var min_razdalja = _minimalna_razdalja_od_dreves_za(vojasnica_scene)
	if _prevec_blizu_vira(pos, min_razdalja, vojasnica_scene, smer_gradnje):
		print("Vojašnica je preblizu vira")
		_pokazi_obvestilo("Vojašnica je preblizu drevesa, kamna ali drugega vira")
		return false

	if _prevec_blizu_zgradbe(pos, _polmer_za_prekrivanje_scene(vojasnica_scene, "vojasnica"), false):
		print("Tu že stoji druga zgradba")
		_pokazi_obvestilo("Tu že stoji druga zgradba")
		return false

	var nova = vojasnica_scene.instantiate()

	nova.global_position = pos
	_uporabi_smer_gradnje(nova)

	add_child(nova)
	_zahtevaj_posodobitev_navigacije()
	_avtomatsko_dodeli_gradnjo(nova)

	stevilo_vojasnic += 1
	vojasnica_level = 1
	vojasnica_ref = nova
	nova.prikazi_nivo(1)

	print("Vojašnica zgrajena")
	return true


func _on_nadgradi_vojasnico_pressed():

	var cilj = selected_building if is_instance_valid(selected_building) and "tip_zgradbe" in selected_building and selected_building.tip_zgradbe == "vojasnica" else vojasnica_ref
	if not is_instance_valid(cilj):
		print("Najprej zgradi vojašnico")
		return
	if cilj.v_gradnji or cilj.v_nadgradnji:
		_pokazi_obvestilo("Vojašnica je trenutno zasedena")
		return

	var trenutni_level: int = cilj.nivo_zgradbe
	if trenutni_level >= 3:
		print("Vojašnica je že na najvišjem nivoju")
		return

	var naslednji_level = trenutni_level + 1
	var cena = cena_nadgradnje_vojasnice[naslednji_level]

	if resources["STONE"] < cena["STONE"] or resources["WOOD"] < cena["WOOD"]:
		print("Premalo surovin za nadgradnjo vojašnice")
		_pokazi_obvestilo("Premalo surovin za nadgradnjo vojašnice")
		return

	if not cilj.zacni_nadgradnjo(naslednji_level, cas_nadgradnje_vojasnice[naslednji_level]):
		return
	resources["STONE"] -= cena["STONE"]
	resources["WOOD"] -= cena["WOOD"]
	vojasnica_ref = cilj
	update_ui()
	_pokazi_obvestilo("Nadgradnja vojašnice: %ds" % int(cas_nadgradnje_vojasnice[naslednji_level]))
	print("Začeta nadgradnja vojašnice na level ", naslednji_level)


func _on_nadgradi_glavno_stavbo_pressed():

	var gh_lvl = get_tree().get_first_node_in_group("glavna_hisa")
	var trenutni_level := glavna_stavba_level
	if is_instance_valid(gh_lvl) and "nivo_zgradbe" in gh_lvl:
		trenutni_level = gh_lvl.nivo_zgradbe
	if not is_instance_valid(gh_lvl):
		return
	if gh_lvl.v_nadgradnji:
		_pokazi_obvestilo("Glavna baza se že nadgrajuje")
		return
	if trenutni_level >= 3:
		print("Glavna stavba je že na najvišjem nivoju")
		_pokazi_obvestilo("Glavna baza je že na najvišjem nivoju")
		return

	var naslednji_level = trenutni_level + 1
	var cena = cena_nadgradnje_glavne_stavbe[naslednji_level]

	if resources["WOOD"] < cena["WOOD"] or resources["STONE"] < cena["STONE"]:
		print("Premalo surovin za nadgradnjo glavne stavbe")
		_pokazi_obvestilo("Premalo surovin za nadgradnjo glavne stavbe")
		return

	if not gh_lvl.zacni_nadgradnjo(naslednji_level, cas_nadgradnje_glavne_stavbe[naslednji_level]):
		return
	resources["WOOD"] -= cena["WOOD"]
	resources["STONE"] -= cena["STONE"]
	update_ui()
	_posodobi_glavna_hisa_gumb()
	_pokazi_obvestilo("Nadgradnja glavne baze: %ds" % int(cas_nadgradnje_glavne_stavbe[naslednji_level]))
	print("Začeta nadgradnja glavne stavbe na level ", naslednji_level)


func _posodobi_glavna_hisa_gumb() -> void:
	var glavna = get_tree().get_first_node_in_group("glavna_hisa")
	_posodobi_nadgradnja_gumb(glavna_hisa_nadgradi_button, glavna, "glavna", cena_nadgradnje_glavne_stavbe, cas_nadgradnje_glavne_stavbe)


func _nadgradnja_ikona(tip: String, nivo: int, smer: String = "jug") -> Texture2D:
	var pot := ""
	match tip:
		"glavna":
			pot = "res://assets/nadgradnje/glavna_nivo%d.png" % nivo
		"vojasnica":
			pot = "res://assets/nadgradnje/vojasnica_nivo%d_%s.png" % [nivo, smer]
		"stolp":
			pot = "res://assets/nadgradnje/stolp_nivo%d_%s.png" % [nivo, smer]
	if pot.is_empty() or not ResourceLoader.exists(pot):
		return null
	return load(pot)


func _posodobi_nadgradnja_gumb(gumb: Button, stavba, tip: String, cene: Dictionary, casi: Dictionary) -> void:
	if not is_instance_valid(gumb):
		return
	gumb.text = ""
	gumb.expand_icon = true
	gumb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gumb.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	if not is_instance_valid(stavba):
		gumb.disabled = true
		gumb.tooltip_text = "Najprej izberi ali zgradi stavbo"
		return

	var nivo := clampi(int(stavba.nivo_zgradbe), 1, 3)
	var smer := str(stavba.smer_zgradbe) if "smer_zgradbe" in stavba else "jug"
	if smer not in ["jug", "sever"]:
		smer = "jug"
	var prikazni_nivo := nivo
	if stavba.v_nadgradnji:
		prikazni_nivo = stavba.nadgradnja_ciljni_nivo
	elif nivo < 3:
		prikazni_nivo = nivo + 1
	var ikona := _nadgradnja_ikona(tip, prikazni_nivo, smer)
	if ikona != null:
		gumb.icon = ikona

	var fill: ColorRect = _nadgradnja_fill.get(gumb, null)
	if is_instance_valid(fill):
		fill.visible = stavba.v_nadgradnji
		fill.anchor_top = 1.0 - stavba.napredek_nadgradnje() if stavba.v_nadgradnji else 1.0

	if stavba.v_nadgradnji:
		gumb.disabled = true
		gumb.tooltip_text = "Nadgradnja na nivo %d – še %ds" % [
			stavba.nadgradnja_ciljni_nivo, int(ceil(stavba.preostanek_nadgradnje()))
		]
		return
	if nivo >= 3:
		gumb.disabled = true
		gumb.tooltip_text = "Najvišji nivo"
		return

	var naslednji := nivo + 1
	var cena: Dictionary = cene[naslednji]
	var dovolj_surovin: bool = bool(resources["WOOD"] >= int(cena.get("WOOD", 0)) and resources["STONE"] >= int(cena.get("STONE", 0)))
	gumb.disabled = stavba.v_gradnji or not dovolj_surovin
	gumb.tooltip_text = "Nivo %d • %ds • %d lesa • %d kamna" % [
		naslednji, int(casi[naslednji]), int(cena.get("WOOD", 0)), int(cena.get("STONE", 0))
	]


func _posodobi_vojasnica_gumb() -> void:
	var vojasnica = selected_building if is_instance_valid(selected_building) and "tip_zgradbe" in selected_building and selected_building.tip_zgradbe == "vojasnica" else vojasnica_ref
	_posodobi_nadgradnja_gumb(vojasnica_nadgradi_button, vojasnica, "vojasnica", cena_nadgradnje_vojasnice, cas_nadgradnje_vojasnice)


func _posodobi_nadgradnja_ui() -> void:
	_posodobi_glavna_hisa_gumb()
	_posodobi_vojasnica_gumb()
	_posodobi_stolp_gumb()


func nadgradnja_zgradbe_dokoncana(stavba, stari_nivo: int, novi_nivo: int) -> void:
	if not is_instance_valid(stavba):
		return
	if stavba.is_in_group("glavna_hisa"):
		glavna_stavba_level = novi_nivo
		if novi_nivo == 3:
			var stats3 = poveljnik_stats_po_levelu[3]
			for p in get_tree().get_nodes_in_group("poveljniki"):
				var razlika = stats3["max_hp"] - p.max_hp
				p.max_hp = stats3["max_hp"]
				p.hp = mini(p.hp + razlika, p.max_hp)
				p.damage = stats3["damage"]
				p.aura_range = stats3["aura_range"]
				p.aura_damage_bonus = stats3["aura_bonus"]
		_pokazi_obvestilo("Glavna baza je dosegla nivo %d" % novi_nivo)
	elif stavba.tip_zgradbe == "vojasnica":
		vojasnica_ref = stavba
		vojasnica_level = maxi(vojasnica_level, novi_nivo)
		_pokazi_obvestilo("Vojašnica je dosegla nivo %d" % novi_nivo)
	elif stavba.tip_zgradbe == "stolp":
		var novi_max := int(stolp_hp_po_levelu[novi_nivo])
		var razlika_hp := novi_max - int(stolp_hp_po_levelu[stari_nivo])
		stavba.max_hp = novi_max
		stavba.hp = mini(stavba.hp + razlika_hp, novi_max)
		stavba.damage = stolp_damage_po_levelu[novi_nivo]
		stavba.attack_range = stolp_range_po_levelu[novi_nivo]
		stolp_level = maxi(stolp_level, novi_nivo)
		_pokazi_obvestilo("Stolp je dosegel nivo %d" % novi_nivo)
	posodobi_max_vojasko_populacijo()
	_posodobi_nadgradnje_enot_in_delavcev()
	_posodobi_nadgradnja_ui()
	update_ui()


func enota_umrla(cena: int):
	vojaska_populacija -= cena
	if vojaska_populacija < 0:
		vojaska_populacija = 0
	update_ui()


func _posodobi_nadgradnje_enot_in_delavcev() -> void:
	for e in get_tree().get_nodes_in_group("enote"):
		if is_instance_valid(e) and e.has_method("uporabi_nadgradnje"):
			e.uporabi_nadgradnje(glavna_stavba_level, maxi(1, vojasnica_level))
	for d in get_tree().get_nodes_in_group("delavci"):
		if is_instance_valid(d) and d.has_method("uporabi_nadgradnjo_baze"):
			d.uporabi_nadgradnjo_baze(glavna_stavba_level)


func delavec_umrl():
	current_pop -= 1
	if current_pop < 0:
		current_pop = 0
	update_ui()


func _zacni_izdelavo_enote(tip: String, potreben_level: int):

	var proizvodna_vojasnica = selected_building if is_instance_valid(selected_building) and "tip_zgradbe" in selected_building and selected_building.tip_zgradbe == "vojasnica" else vojasnica_ref
	if not is_instance_valid(proizvodna_vojasnica):
		print("Vojašnica ne obstaja")
		return
	vojasnica_ref = proizvodna_vojasnica
	vojasnica_level = proizvodna_vojasnica.nivo_zgradbe

	if proizvodna_vojasnica.nivo_zgradbe < potreben_level:
		print("Izbrana vojašnica ni dovolj nadgrajena za to enoto")
		return

	if proizvodna_vojasnica.v_gradnji:
		print("Vojašnica je še v gradnji")
		return

	if proizvodna_vojasnica.stevilo_narocil() >= MAX_VOJASNICA_QUEUE:
		print("Čakalna vrsta vojašnice je polna")
		_pokazi_obvestilo("Čakalna vrsta vojašnice je polna")
		return

	var potrebna_pop = populacija_cena_enote[tip]

	if vojaska_populacija + potrebna_pop > max_vojaska_populacija:
		print("Ni dovolj prostora za populacijo vojske")
		return

	var cena = cena_enote[tip]

	if resources["FOOD"] < cena["FOOD"] or resources["WOOD"] < cena["WOOD"]:
		print("Premalo surovin za enoto")
		_pokazi_obvestilo("Premalo surovin za enoto")
		return

	resources["FOOD"] -= cena["FOOD"]
	resources["WOOD"] -= cena["WOOD"]
	vojaska_populacija += potrebna_pop
	update_ui()

	proizvodna_vojasnica.zacni_produkcijo(tip)


func _on_bojevnik_button_pressed():
	_zacni_izdelavo_enote("BOJEVNIK", 1)


func _on_kopjenik_button_pressed():
	_zacni_izdelavo_enote("KOPJENIK", 2)


func _on_teska_button_pressed():
	_zacni_izdelavo_enote("TESKA", 3)


func _on_lutka_button_pressed():
	building_lutka = true
	_ponastavi_rotacijo_gradnje()
	print("Postavi testno lutko")


func _place_lutka(pos):
	if _postavitev_posega_v_vodo(pos, lutka_scene, smer_gradnje):
		_pokazi_obvestilo("Na vodi ni mogoče graditi")
		return
	if _postavitev_posega_v_zasciteno_obmocje(pos, lutka_scene, smer_gradnje):
		_pokazi_obvestilo("Na obarvanem območju glavne stavbe ni mogoče graditi")
		return
	var nova = lutka_scene.instantiate()
	nova.global_position = pos
	_uporabi_smer_gradnje(nova)
	add_child(nova)
	print("Lutka postavljena")


func _on_obzidje_button_pressed():

	# Surovine se NE odštejejo več tukaj - samo zgodnja informativna
	# preverba, da igralec takoj ve, če nima dovolj za VSAJ en segment.
	# Dejansko odštevanje je zdaj v _place_obzidje, PER dejansko postavljen
	# segment (glej opombo tam) - potrebno, ker lahko z vlečenjem (glej
	# _obzidje_zgradi_verigo) en "obisk" postavi več segmentov naenkrat.
	if resources["WOOD"] < cena_zidu["WOOD"] or resources["STONE"] < cena_zidu["STONE"]:
		print("Premalo surovin za obzidje")
		_pokazi_obvestilo("Premalo surovin za obzidje")
		return

	building_obzidje = true
	_ponastavi_rotacijo_gradnje()

	print("Postavi obzidje")


# --- NOVO obzidje/vrata: robovi ISTE mreže, ki jo zdaj uporabljajo tudi ---
# --- Izometrična mreža obzidja (2 : 1) ---
#
# Zid ne uporablja kvadratne mreže stavb. Njegovi dve osi sta roba
# izometrične talne ploščice: 128 px v desno in 64 px gor/dol. Nova grafika
# je izdelana na isti geometriji, zato se sosednja segmenta končata v isti
# slikovni točki brez vrzeli. Vrata zasedejo natanko dva zaporedna robova.
const ZID_KORAK_A = Vector2(128.0, -64.0)
const ZID_KORAK_B = Vector2(128.0, 64.0)
const ZID_ROB_DOLZINA = 143.108
const ZID_CELICA = ZID_ROB_DOLZINA # združljivost s starejšimi pragovi dotika
const VRATA_DOLZINA_CELIC = 2
const ZID_SNAP_DOSEG = 100.0
const ZID_STOLP_SNAP_DOSEG = 115.0

func _dolzina_trenutne_gradnje_v_celicah() -> int:
	return VRATA_DOLZINA_CELIC if building_vrata else 1


func _zid_os_je_a(smer: String) -> bool:
	return smer == "jug" or smer == "sever"


func _zid_korak_za_smer(smer: String) -> Vector2:
	match smer:
		"sever":
			return -ZID_KORAK_A
		"vzhod":
			return ZID_KORAK_B
		"zahod":
			return -ZID_KORAK_B
		_:
			return ZID_KORAK_A


func _zid_mreza_v_svet(mreza: Vector2) -> Vector2:
	return ZID_KORAK_A * mreza.x + ZID_KORAK_B * mreza.y


func _zid_svet_v_mrezo(pos: Vector2) -> Vector2:
	# Inverz matrike [128 128; -64 64].
	return Vector2(pos.x / 256.0 - pos.y / 128.0, pos.x / 256.0 + pos.y / 128.0)


func _zid_krajisci_iz_podatkov(pos: Vector2, smer: String, dolzina_celic: int) -> Array:
	var pol_koraka = _zid_korak_za_smer(smer) * (float(dolzina_celic) * 0.5)
	return [pos - pol_koraka, pos + pol_koraka]


func _zid_najblizje_krajisce(pos: Vector2, doseg: float = ZID_SNAP_DOSEG):
	var rezultat = null
	var najkrajsa = doseg
	for zid in get_tree().get_nodes_in_group("obzidje"):
		if not is_instance_valid(zid):
			continue
		for krajisce in _obzidje_krajisci(zid):
			var d = pos.distance_to(krajisce)
			if d < najkrajsa:
				najkrajsa = d
				rezultat = krajisce
	for stolp in get_tree().get_nodes_in_group("stolpi"):
		if is_instance_valid(stolp):
			var d = pos.distance_to(stolp.global_position)
			if d < najkrajsa:
				najkrajsa = d
				rezultat = stolp.global_position
	return rezultat


func _zid_najblizje_vozlisce(pos: Vector2) -> Vector2:
	var povezava = _zid_najblizje_krajisce(pos, ZID_SNAP_DOSEG)
	if povezava != null:
		return povezava
	var mreza = _zid_svet_v_mrezo(pos)
	return _zid_mreza_v_svet(Vector2(round(mreza.x), round(mreza.y)))


func _zid_zacetno_vozlisce_za_vlek(zacetek: Vector2, konec: Vector2) -> Vector2:
	var kandidati: Array = []
	for zid in get_tree().get_nodes_in_group("obzidje"):
		if is_instance_valid(zid):
			kandidati.append_array(_obzidje_krajisci(zid))
	for stolp in get_tree().get_nodes_in_group("stolpi"):
		if is_instance_valid(stolp):
			kandidati.append(stolp.global_position)

	var najmanjsa_zacetna = ZID_SNAP_DOSEG
	for kandidat in kandidati:
		najmanjsa_zacetna = min(najmanjsa_zacetna, zacetek.distance_to(kandidat))

	if najmanjsa_zacetna < ZID_SNAP_DOSEG:
		var najboljsi = null
		var najblizje_cilju = INF
		for kandidat in kandidati:
			# Če igralec začne približno na sredini segmenta, sta oba konca
			# enako daleč. Izberemo tistega v smeri vlečenja.
			if zacetek.distance_to(kandidat) <= najmanjsa_zacetna + 4.0:
				var d_cilj = kandidat.distance_to(konec)
				if d_cilj < najblizje_cilju:
					najblizje_cilju = d_cilj
					najboljsi = kandidat
		if najboljsi != null:
			return najboljsi

	return _zid_najblizje_vozlisce(zacetek)


# Zaokroži na najbližji rob izometrične mreže. Če je kazalec blizu konca
# obstoječega zidu ali stolpa, ima ta prava povezava prednost pred prosto
# mrežo; izbrana smer še vedno določa eno izmed dveh izometričnih osi.
func _zlepi_na_mrezo_zidu(pos: Vector2, smer: String, dolzina_celic: int) -> Vector2:
	var korak = _zid_korak_za_smer(smer)
	var priklop = _zid_najblizje_krajisce(pos, ZID_SNAP_DOSEG)
	if priklop != null:
		var kandidat_naprej = priklop + korak * (float(dolzina_celic) * 0.5)
		var kandidat_nazaj = priklop - korak * (float(dolzina_celic) * 0.5)
		return kandidat_naprej if kandidat_naprej.distance_to(pos) <= kandidat_nazaj.distance_to(pos) else kandidat_nazaj

	var mreza = _zid_svet_v_mrezo(pos)
	var polovica = float(dolzina_celic) * 0.5
	var ulomek = polovica - floor(polovica)
	if _zid_os_je_a(smer):
		mreza.x = round(mreza.x - ulomek) + ulomek
		mreza.y = round(mreza.y)
	else:
		mreza.x = round(mreza.x)
		mreza.y = round(mreza.y - ulomek) + ulomek
	return _zid_mreza_v_svet(mreza)


# Kot (radiani), pod katerim je bil postavljen zadnji segment - vedno enak
# Zgradba.kot_stene_za_smer(smer_gradnje) v trenutku postavitve. Uporabljeno
# za usklajevanje fizične kolizije novega segmenta z isto vrednostjo, ki jo
# že uporablja nastavi_smer().
var _zadnji_kot_zlepljenja = null

# Glavna vstopna točka za "kam pristane naslednji segment", ki jo kličejo
# duh postavitve, _postavitev_veljavna in _place_obzidje/_place_vrata -
# preprosto zaokroži na mrežo robov glede na TRENUTNO izbrano smer
# (smer_gradnje, gumb "Zavrti") in trenutno gradnjo (obzidje=1 celica,
# vrata=2 celici). Ker je zdaj VSA logika mrežna, iskanje "najbližjega
# obstoječega zidu" ni več potrebno - vsaka pozicija na mapi enolično določi
# svoje mesto na mreži, tudi če v bližini še ni nobenega zidu.
func _zlepi_na_obzidje(pos: Vector2) -> Vector2:
	_zadnji_kot_zlepljenja = Zgradba.kot_stene_za_smer(smer_gradnje)
	return _zlepi_na_mrezo_zidu(pos, smer_gradnje, _dolzina_trenutne_gradnje_v_celicah())


# Poravna fizično kolizijo novo postavljenega zidu/vrat z isto vrednostjo, ki
# jo je nastavi_smer() (zgradba.gd) že uporabila - varnostna mreža, če bi se
# kdaj razšli.
func _uskladi_kolizijo_zidu(nova) -> void:
	if _zadnji_kot_zlepljenja == null:
		return
	var kolizija = nova.get_node_or_null("CollisionShape2D")
	if kolizija != null:
		kolizija.rotation = _zadnji_kot_zlepljenja


func _place_obzidje(pos) -> bool:

	var koncna_pozicija = _zlepi_na_obzidje(pos)
	if not _fog_dovoli_gradnjo(koncna_pozicija):
		return false

	if _postavitev_posega_v_vodo(koncna_pozicija, obzidje_scene, smer_gradnje):
		_pokazi_obvestilo("Na vodi ni mogoče graditi")
		return false
	if _postavitev_posega_v_zasciteno_obmocje(koncna_pozicija, obzidje_scene, smer_gradnje):
		_pokazi_obvestilo("Na obarvanem območju glavne stavbe ni mogoče graditi")
		return false

	if _obzidje_ze_zaseceno(koncna_pozicija, smer_gradnje, 1):
		print("Tu že stoji del obzidja")
		_pokazi_obvestilo("Tu že stoji del obzidja")
		return false

	var min_razdalja = _minimalna_razdalja_od_dreves_za(obzidje_scene)
	if _prevec_blizu_vira(koncna_pozicija, min_razdalja, obzidje_scene, smer_gradnje):
		print("Obzidje je preblizu vira - izberi drugo mesto")
		_pokazi_obvestilo("Obzidje je preblizu drevesa, kamna ali drugega vira")
		return false

	if _prevec_blizu_zgradbe(koncna_pozicija, _polmer_za_prekrivanje_scene(obzidje_scene, "obzidje"), true, smer_gradnje, 1, "obzidje"):
		print("Tu že stoji druga zgradba")
		_pokazi_obvestilo("Tu že stoji druga zgradba")
		return false

	# Surovine se odštejejo TUKAJ (ne več vnaprej ob pritisku gumba "Obzidje")
	# - tako se vsak DEJANSKO postavljen segment plača posebej, kar je nujno
	# potrebno zdaj, ko lahko en "obisk" gradbenega načina z vlečenjem (glej
	# _obzidje_zgradi_verigo) postavi VEČ segmentov naenkrat.
	if resources["WOOD"] < cena_zidu["WOOD"] or resources["STONE"] < cena_zidu["STONE"]:
		print("Premalo surovin za obzidje")
		_pokazi_obvestilo("Premalo surovin za obzidje")
		return false

	resources["WOOD"] -= cena_zidu["WOOD"]
	resources["STONE"] -= cena_zidu["STONE"]
	update_ui()

	var nova = obzidje_scene.instantiate()

	nova.global_position = koncna_pozicija
	_uporabi_smer_gradnje(nova)
	nova.max_hp = obzidje_hp_po_levelu[1]

	add_child(nova)
	nova.add_to_group("obzidje")
	nova.prikazi_nivo(1)
	_uskladi_kolizijo_zidu(nova)
	_zahtevaj_posodobitev_navigacije()
	_avtomatsko_dodeli_gradnjo(nova)

	stevilo_zidov += 1

	print("Obzidje zgrajeno")
	return true


func _on_vrata_button_pressed():

	# Glej opombo v _on_obzidje_button_pressed - samo zgodnja preverba tukaj,
	# dejansko odštevanje je zdaj v _place_vrata, per postavljen segment.
	if resources["WOOD"] < cena_zidu["WOOD"] or resources["STONE"] < cena_zidu["STONE"]:
		print("Premalo surovin za vrata")
		_pokazi_obvestilo("Premalo surovin za vrata")
		return

	building_vrata = true
	_ponastavi_rotacijo_gradnje()

	print("Postavi vrata")


func _place_vrata(pos) -> bool:

	var koncna_pozicija = _zlepi_na_obzidje(pos)
	if not _fog_dovoli_gradnjo(koncna_pozicija):
		return false

	if _postavitev_posega_v_vodo(koncna_pozicija, vrata_scene, smer_gradnje):
		_pokazi_obvestilo("Na vodi ni mogoče graditi")
		return false
	if _postavitev_posega_v_zasciteno_obmocje(koncna_pozicija, vrata_scene, smer_gradnje):
		_pokazi_obvestilo("Na obarvanem območju glavne stavbe ni mogoče graditi")
		return false

	if _obzidje_ze_zaseceno(koncna_pozicija, smer_gradnje, VRATA_DOLZINA_CELIC):
		print("Tu že stoji del obzidja")
		_pokazi_obvestilo("Tu že stoji del obzidja")
		return false

	var min_razdalja = _minimalna_razdalja_od_dreves_za(vrata_scene)
	if _prevec_blizu_vira(koncna_pozicija, min_razdalja, vrata_scene, smer_gradnje):
		print("Vrata so preblizu vira - izberi drugo mesto")
		_pokazi_obvestilo("Vrata so preblizu drevesa, kamna ali drugega vira")
		return false

	if _prevec_blizu_zgradbe(koncna_pozicija, _polmer_za_prekrivanje_scene(vrata_scene, "vrata"), true, smer_gradnje, VRATA_DOLZINA_CELIC, "vrata"):
		print("Tu že stoji druga zgradba")
		_pokazi_obvestilo("Tu že stoji druga zgradba")
		return false

	# Glej opombo v _place_obzidje - surovine se zdaj odštejejo tukaj, PER
	# SEGMENT, ne več vnaprej ob pritisku gumba.
	if resources["WOOD"] < cena_zidu["WOOD"] or resources["STONE"] < cena_zidu["STONE"]:
		print("Premalo surovin za vrata")
		_pokazi_obvestilo("Premalo surovin za vrata")
		return false

	resources["WOOD"] -= cena_zidu["WOOD"]
	resources["STONE"] -= cena_zidu["STONE"]
	update_ui()

	var nova = vrata_scene.instantiate()

	nova.global_position = koncna_pozicija
	_uporabi_smer_gradnje(nova)
	nova.max_hp = obzidje_hp_po_levelu[1]

	add_child(nova)
	nova.add_to_group("obzidje")
	nova.prikazi_nivo(1)
	_uskladi_kolizijo_zidu(nova)
	_zahtevaj_posodobitev_navigacije()
	_avtomatsko_dodeli_gradnjo(nova)

	stevilo_zidov += 1

	print("Vrata zgrajena")
	return true


# --- Razširitev obzidja "v vse smeri" (à la Clash of Clans) ---
#
# Uporabnikova želja: najprej izbereš "Obzidje"/"Vrata" iz menija (kot
# doslej), nato pa NE tapneš kar kamorkoli - namesto tega tapneš na ŽE
# POSTAVLJEN segment obzidja/vrat, kar prikaže VSE smeri, kamor se od
# tega segmenta da (ali NE da) postaviti naslednji, povezan segment.
# Šele naslednji tap na eno izmed teh (zelenih, veljavnih) ponujenih
# pozicij dejansko zgradi nov segment - TAKOJ gotov (glej
# potrebuje_gradnjo=false v Obzidje.tscn/Vrata.tscn), brez gradbišča.
# Če v bližini tapa ni nobenega obstoječega segmenta, se ohrani staro
# obnašanje: prvi/samostojni segment se zgradi natanko tam, kamor je
# igralec tapnil.
# Tap mora zadeti dovolj blizu obstoječega segmenta, da ga izberemo kot
# sidro, ne pa pomotoma začnemo novega samostojnega zidu.
const OBZIDJE_SIDRO_DOSEG = 80.0

func _obzidje_dotik(pos: Vector2, je_obzidje: bool) -> void:

	# 1. Če trenutno že kažemo kandidate okoli izbranega sidra in je ta tap
	# blizu enega izmed VELJAVNIH kandidatov, tam takoj zgradi nov segment.
	if _obzidje_sidro != null and is_instance_valid(_obzidje_sidro):

		var najblizji_kandidat = null
		var najkrajsa_k = OBZIDJE_SIDRO_DOSEG

		for kandidat in _obzidje_kandidati:
			if not kandidat["veljavna"]:
				continue
			var d = kandidat["pozicija"].distance_to(pos)
			if d < najkrajsa_k:
				najkrajsa_k = d
				najblizji_kandidat = kandidat

		if najblizji_kandidat != null:
			_zgradi_na_kandidatu(najblizji_kandidat, je_obzidje)
			_obzidje_sidro = null
			_obzidje_kandidati = []
			if je_obzidje:
				building_obzidje = false
			else:
				building_vrata = false
			postavitev_overlay.queue_redraw()
			return

		# Tap ni zadel nobenega ponujenega kandidata - PREJ je koda tu padla
		# skozi na spodnjo "prosti prostor" vejo, kar je pomenilo, da je
		# vsak tap mimo (npr. igralec je hotel samo PREKLICATI izbiro) v
		# resnici zgradil naključen samostojen segment natanko tam, kamor je
		# igralec tapnil ("čudno se postavljajo", "ne moreš odznačiti" -
		# uporabnikovo poročilo). Zdaj tak "mimo" tap namesto tega VEDNO
		# samo prekliče celoten način postavljanja, brez gradnje - enako kot
		# gumb "✕ Prekliči".
		_obzidje_sidro = null
		_obzidje_kandidati = []
		building_obzidje = false
		building_vrata = false
		_ghost_vidna = false
		postavitev_overlay.queue_redraw()
		_pokazi_obvestilo("Razširitev preklicana")
		return

	# 2. Ali je ta tap blizu OBSTOJEČEGA segmenta obzidja/vrat? Če da, ta
	# postane novo "sidro" - namesto takojšnje gradnje pokažemo možne smeri
	# razširitve (glej _narisi_postavitveni_overlay).
	var najblizji_obstojeci = null
	var najkrajsa_o = OBZIDJE_SIDRO_DOSEG

	for z in get_tree().get_nodes_in_group("obzidje"):
		if not is_instance_valid(z):
			continue
		var d = z.global_position.distance_to(pos)
		if d < najkrajsa_o:
			najkrajsa_o = d
			najblizji_obstojeci = z

	if najblizji_obstojeci != null:
		_obzidje_sidro = najblizji_obstojeci
		_obzidje_kandidati = _obzidje_kandidati_za_sidro(najblizji_obstojeci)
		postavitev_overlay.queue_redraw()
		return

	# 3. Sicer (prazen prostor, brez bližnjega obstoječega zidu/vrat) -
	# ohrani staro obnašanje: zgradi prvi/samostojni segment natanko tam,
	# kamor je igralec tapnil.
	if je_obzidje:
		if _place_obzidje(pos):
			building_obzidje = false
	else:
		if _place_vrata(pos):
			building_vrata = false


# Ali na tej poziciji (že zaokroženi na rob mreže) že stoji obstoječi
# segment obzidja/vrat (torej ni smiselno tega ponuditi kot "nov" kandidat
# za gradnjo, niti dovoliti, da nanjo pristane drug segment)? Toleranca
# (30) je namenoma precej manjša od ZID_CELICA (110) - dovolj velika za
# numerične zaokrožitve, dovolj majhna, da ne pobriše sosednjih (različnih)
# mest na mreži.
func _zid_enotni_robovi(pos: Vector2, smer: String, dolzina_celic: int) -> Array:
	var robovi: Array = []
	var korak = _zid_korak_za_smer(smer)
	for i in range(dolzina_celic):
		var odmik = float(i) - (float(dolzina_celic - 1) * 0.5)
		robovi.append(pos + korak * odmik)
	return robovi


func _zid_rob_cache_kljuc(pos: Vector2) -> Vector2i:
	# Vsi robovi ležijo na pol-piksel natančni mreži; ×10 varno odstrani
	# plavajoča odstopanja brez združevanja sosednjih robov.
	return Vector2i(round(pos.x * 10.0), round(pos.y * 10.0))


func _obnovi_zid_zasedenost_cache() -> void:
	_zid_zasedeni_robovi_cache.clear()
	var zidovi = get_tree().get_nodes_in_group("obzidje")
	for z in zidovi:
		if not is_instance_valid(z):
			continue
		var z_smer = z.smer_zgradbe if "smer_zgradbe" in z else "jug"
		var z_dolzina = VRATA_DOLZINA_CELIC if ("tip_zgradbe" in z and z.tip_zgradbe == "vrata") else 1
		for rob in _zid_enotni_robovi(z.global_position, z_smer, z_dolzina):
			_zid_zasedeni_robovi_cache[_zid_rob_cache_kljuc(rob)] = true
	_zid_cache_stevilo = zidovi.size()


# Zasedenost se preverja po posameznih ENOTNIH robovih. Tako dvocelična
# vrata pravilno zasedejo dve mesti in segment ne more skrito pristati na
# polovici vrat, vogali in krajišča pa ostanejo dovoljeni.
func _obzidje_ze_zaseceno(pos: Vector2, smer: String = "", dolzina_celic: int = -1) -> bool:
	var nova_smer = smer if smer != "" else smer_gradnje
	var nova_dolzina = dolzina_celic if dolzina_celic > 0 else _dolzina_trenutne_gradnje_v_celicah()
	var novi_robovi = _zid_enotni_robovi(pos, nova_smer, nova_dolzina)
	var trenutno_stevilo = get_tree().get_node_count_in_group("obzidje")
	if _zid_cache_stevilo != trenutno_stevilo:
		_obnovi_zid_zasedenost_cache()
	for nov_rob in novi_robovi:
		if _zid_zasedeni_robovi_cache.has(_zid_rob_cache_kljuc(nov_rob)):
			return true
	return false


# --- Robovi mreže okoli "sidra" (obstoječega segmenta obzidja/vrat) ---
#
# Vsak segment stoji na ROBU celice mreže, ki ima natanko DVE "krajišči"
# (kotni točki) - npr. vodoravni segment dolžine ene celice ima krajišči
# 55px levo in desno od svojega središča. Iz VSAKEGA krajišča lahko novi
# segment odide v do 4 smeri (naravnost naprej po isti liniji, ali zavij
# pravokotno v katero od dveh smeri - natanko tako, kot v pravem AoE zid
# poteka po robovih mreže in tvori kote/vogale). To nadomesti stari sistem
# (4 poimenovane smeri × ±1 korak od SREDIŠČA sidra), ki ni poznal pravih
# vogalov - zdaj so kandidati geometrijsko pravi robovi mreže.

# Obe krajiščni (kotni) točki roba, na katerem stoji "sidro".
func _obzidje_krajisci(sidro) -> Array:
	var smer = sidro.smer_zgradbe if "smer_zgradbe" in sidro else "jug"
	var sidro_dolzina_celic = VRATA_DOLZINA_CELIC if ("tip_zgradbe" in sidro and sidro.tip_zgradbe == "vrata") else 1
	return _zid_krajisci_iz_podatkov(sidro.global_position, smer, sidro_dolzina_celic)


# Do 4 kandidatna mesta (robovi mreže), ki se stikajo v EN krajišče - dva
# vodoravna (levo/desno od krajišča) in dva navpična (gor/dol od krajišča).
# "dolzina_celic" je dolžina TRENUTNO postavljane gradnje (1 za obzidje,
# VRATA_DOLZINA_CELIC za vrata) - NE dolžina sidra, saj lahko npr. na
# obstoječe obzidje navežeš nova vrata (ali obratno).
func _obzidje_kandidati_iz_krajisca(krajisce: Vector2, dolzina_celic: int) -> Array:
	var zamik_a = ZID_KORAK_A * (float(dolzina_celic) * 0.5)
	var zamik_b = ZID_KORAK_B * (float(dolzina_celic) * 0.5)
	return [
		{"pozicija": krajisce + zamik_a, "smer": "jug"},
		{"pozicija": krajisce - zamik_a, "smer": "sever"},
		{"pozicija": krajisce + zamik_b, "smer": "vzhod"},
		{"pozicija": krajisce - zamik_b, "smer": "zahod"},
	]


# Vsi kandidati okoli "sidra" (do 8: 4 na vsako od dveh krajišč, minus
# podvojeni/že zasedeni), vsak označen kot veljavna/neveljavna glede na
# enaka pravila kot pri navadni gradnji (drevo/druga zgradba v bližini).
# Pozicija, kjer že stoji segment (vključno s samim sidrom), se sploh ne
# ponudi (glej _obzidje_ze_zaseceno).
func _obzidje_kandidati_za_sidro(sidro) -> Array:

	var dolzina_celic = _dolzina_trenutne_gradnje_v_celicah()
	var scena = vrata_scene if building_vrata else obzidje_scene
	var tip = "vrata" if building_vrata else "obzidje"
	var min_razdalja_dreves = _minimalna_razdalja_od_dreves_za(scena)
	var zid_polmer = _polmer_za_prekrivanje_scene(scena, tip)

	var kandidati: Array = []

	for krajisce in _obzidje_krajisci(sidro):
		for surov in _obzidje_kandidati_iz_krajisca(krajisce, dolzina_celic):
			var pozicija = surov["pozicija"]

			var podvojen = false
			for k in kandidati:
				if k["pozicija"].distance_to(pozicija) < 20.0:
					podvojen = true
					break
			if podvojen:
				continue

			var kandidat_smer = surov["smer"]
			if _obzidje_ze_zaseceno(pozicija, kandidat_smer, dolzina_celic):
				continue

			var veljavna = true
			if _postavitev_posega_v_vodo(pozicija, scena, kandidat_smer):
				veljavna = false
			if _postavitev_posega_v_zasciteno_obmocje(pozicija, scena, kandidat_smer):
				veljavna = false
			if _prevec_blizu_vira(pozicija, min_razdalja_dreves, scena, kandidat_smer):
				veljavna = false
			if veljavna and _prevec_blizu_zgradbe(pozicija, zid_polmer, true, kandidat_smer, dolzina_celic, tip):
				veljavna = false

			kandidati.append({"pozicija": pozicija, "smer": surov["smer"], "veljavna": veljavna})

	return kandidati


# Dejansko zgradi nov segment na izbranem kandidatu, s pravilno smerjo
# (usklajena slika + fizična kolizija) glede na to, katera od štirih
# smernih linij je ta kandidat izračunala.
func _zgradi_na_kandidatu(kandidat: Dictionary, je_obzidje: bool) -> void:
	var prejsnja_smer = smer_gradnje
	smer_gradnje = kandidat["smer"]

	if je_obzidje:
		_place_obzidje(kandidat["pozicija"])
	else:
		_place_vrata(kandidat["pozicija"])

	smer_gradnje = prejsnja_smer


# --- Vlečenje (drag) za postavljanje NIZA segmentov, à la Clash of Clans ---
# Deluje z miško in enim prstom. Začetek se zaskoči v najbližje krajišče,
# smer pa na eno izmed dveh izometričnih osi.
func _obzidje_izracunaj_verigo(zacetek: Vector2, konec: Vector2) -> Array:
	var dolzina_celic = _dolzina_trenutne_gradnje_v_celicah()
	var zacetno_vozlisce = _zid_zacetno_vozlisce_za_vlek(zacetek, konec)
	var zacetna_mreza = _zid_svet_v_mrezo(zacetno_vozlisce)
	var koncna_mreza = _zid_svet_v_mrezo(konec)
	var razlika = koncna_mreza - zacetna_mreza

	# V izometričnih koordinatah preprosto izberemo močnejšo od dveh osi.
	# Tako vlečenje vedno tvori popolnoma raven niz po robu talne ploščice.
	var os_a = abs(razlika.x) >= abs(razlika.y)
	var podpisani_robovi = int(round(razlika.x if os_a else razlika.y))
	if podpisani_robovi == 0:
		return []

	var predznak = 1 if podpisani_robovi > 0 else -1
	var stevilo_robov = abs(podpisani_robovi)
	var stevilo_segmentov = int(ceil(float(stevilo_robov) / float(dolzina_celic)))
	var os_mreza = Vector2(1, 0) if os_a else Vector2(0, 1)
	var smer = ("jug" if predznak > 0 else "sever") if os_a else ("vzhod" if predznak > 0 else "zahod")

	var scena = vrata_scene if building_vrata else obzidje_scene
	var tip = "vrata" if building_vrata else "obzidje"
	var min_razdalja_dreves = _minimalna_razdalja_od_dreves_za(scena)
	var zid_polmer = _polmer_za_prekrivanje_scene(scena, tip)

	var veriga: Array = []
	for i in range(stevilo_segmentov):
		var zacetek_segmenta = zacetna_mreza + os_mreza * float(predznak * i * dolzina_celic)
		var sredina_segmenta = zacetek_segmenta + os_mreza * float(predznak) * (float(dolzina_celic) * 0.5)
		var pozicija = _zid_mreza_v_svet(sredina_segmenta)

		if _obzidje_ze_zaseceno(pozicija, smer, dolzina_celic):
			continue

		var veljavna = true
		if _postavitev_posega_v_vodo(pozicija, scena, smer):
			veljavna = false
		if _postavitev_posega_v_zasciteno_obmocje(pozicija, scena, smer):
			veljavna = false
		if _prevec_blizu_vira(pozicija, min_razdalja_dreves, scena, smer):
			veljavna = false
		if veljavna and _prevec_blizu_zgradbe(pozicija, zid_polmer, true, smer, dolzina_celic, tip):
			veljavna = false

		veriga.append({"pozicija": pozicija, "smer": smer, "veljavna": veljavna})

	return veriga


# Ob spustu miške po pravem vlečenju (ne kratkem tapu) - dejansko zgradi VSE
# veljavne segmente v izračunani verigi, vsakega posebej plačanega (glej
# opombo o odštevanju surovin v _place_obzidje/_place_vrata) - ustavi se, če
# igralcu med gradnjo verige zmanjka surovin, in o tem obvesti.
func _obzidje_zgradi_verigo(zacetek: Vector2, konec: Vector2, je_obzidje: bool) -> void:

	var veriga = _obzidje_izracunaj_verigo(zacetek, konec)

	if veriga.is_empty():
		building_obzidje = false
		building_vrata = false
		return

	var zgrajenih = 0
	var preskocenih_prekrivanje = 0
	var zmanjkalo_surovin = false

	# POMEMBNO: building_obzidje/building_vrata NAMENOMA ostaneta
	# nespremenjena skozi CELOTNO zanko - _zgradi_na_kandidatu spodaj (prek
	# _place_obzidje/_place_vrata -> _zlepi_na_obzidje) bere building_vrata,
	# da ve, ali gradi 1-celično obzidje ali 2-celična vrata. Če bi ju
	# resetirala PRED zanko (kot je bilo prej, ko obzidje/vrata nista imela
	# različne dolžine), bi vsak segment v verigi vrat napačno dobil dolžino
	# obzidja.
	for kandidat in veriga:
		if not kandidat["veljavna"]:
			preskocenih_prekrivanje += 1
			continue
		if resources["WOOD"] < cena_zidu["WOOD"] or resources["STONE"] < cena_zidu["STONE"]:
			zmanjkalo_surovin = true
			break
		_zgradi_na_kandidatu(kandidat, je_obzidje)
		zgrajenih += 1

	building_obzidje = false
	building_vrata = false

	if zgrajenih > 0:
		_pokazi_obvestilo("Zgrajenih segmentov: " + str(zgrajenih))
	elif zmanjkalo_surovin:
		_pokazi_obvestilo("Premalo surovin za nadaljevanje zidu")
	elif preskocenih_prekrivanje > 0:
		_pokazi_obvestilo("Tam ni bilo mogoče graditi")


func _on_nadgradi_obzidje_pressed():

	if not is_instance_valid(selected_building) or not ("tip_zgradbe" in selected_building) or selected_building.tip_zgradbe not in ["obzidje", "vrata"]:
		print("Najprej izberi segment obzidja ali vrata")
		return
	var trenutni_level: int = selected_building.nivo_zgradbe
	if trenutni_level >= 3:
		print("Obzidje je že na najvišjem nivoju")
		return

	var naslednji_level = trenutni_level + 1
	var cena = cena_nadgradnje_obzidja[naslednji_level]

	if resources["WOOD"] < cena["WOOD"] or resources["STONE"] < cena["STONE"]:
		print("Premalo surovin za nadgradnjo obzidja")
		_pokazi_obvestilo("Premalo surovin za nadgradnjo obzidja")
		return

	resources["WOOD"] -= cena["WOOD"]
	resources["STONE"] -= cena["STONE"]

	var stari_max = obzidje_hp_po_levelu[trenutni_level]
	var novi_max = obzidje_hp_po_levelu[naslednji_level]
	var razlika = novi_max - stari_max

	selected_building.max_hp = novi_max
	selected_building.hp = mini(selected_building.hp + razlika, novi_max)
	selected_building.prikazi_nivo(naslednji_level)
	# Samo združljivost s starimi shranjenimi igrami; gradnja tega ne bere.
	obzidje_level = naslednji_level

	update_ui()

	print("Izbrani segment nadgrajen na level ", naslednji_level)


# Gumb "+ Razširi" v panelu izbranega obzidja/vrat (PanelObzidje) - glavni,
# najbolj razumljiv način do sistema za razširitev zidu (glej
# _obzidje_kandidati_za_sidro/_obzidje_dotik): igralec najprej NORMALNO
# izbere/tapne že postavljen segment (kar je vedno delovalo in prikazalo
# ta panel), nato pa tu pritisne "+ Razširi", namesto da bi moral vedeti,
# da mora najprej ponovno pritisniti "Obzidje"/"Vrata" v splošnem meniju
# delavca in ŠELE POTEM tapniti na obstoječi segment - ta drugi način
# (prek gradbenega menija) še vedno deluje kot dodatna bližnjica, a ni bil
# dovolj očiten/odkrit sam po sebi.
func _on_razsiri_obzidje_pressed():

	if selected_building == null or not is_instance_valid(selected_building):
		return

	if not ("tip_zgradbe" in selected_building):
		return

	var tip = selected_building.tip_zgradbe
	if tip != "obzidje" and tip != "vrata":
		return

	# Samo zgodnja preverba - glej opombo v _on_obzidje_button_pressed,
	# dejansko odštevanje se zdaj zgodi šele v _place_obzidje/_place_vrata,
	# PER dejansko postavljen segment.
	if resources["WOOD"] < cena_zidu["WOOD"] or resources["STONE"] < cena_zidu["STONE"]:
		print("Premalo surovin za razširitev obzidja")
		_pokazi_obvestilo("Premalo surovin za razširitev obzidja")
		return

	# Vzpostavi natanko isto stanje, kot bi ga povzročil tap na obstoječi
	# segment med "building_obzidje/building_vrata" - glej _obzidje_dotik.
	building_obzidje = (tip == "obzidje")
	building_vrata = (tip == "vrata")
	_obzidje_sidro = selected_building
	_obzidje_kandidati = _obzidje_kandidati_za_sidro(selected_building)

	selected_building = null
	_posodobi_gradbeni_panel()

	postavitev_overlay.queue_redraw()

	_pokazi_obvestilo("Izberi zeleno mesto za nov segment")


func _on_odpri_vrata_pressed() -> void:
	if selected_building == null or not is_instance_valid(selected_building):
		return
	if not ("tip_zgradbe" in selected_building) or selected_building.tip_zgradbe != "vrata":
		return
	if selected_building.has_method("preklopi_vrata_rocno"):
		selected_building.preklopi_vrata_rocno()
		var odprta = selected_building.so_vrata_odprta() if selected_building.has_method("so_vrata_odprta") else false
		vrata_odpri_button.text = "Zapri vrata" if odprta else "Odpri vrata"


func _on_stolp_button_pressed():

	if resources["WOOD"] < cena_stolpa["WOOD"] or resources["STONE"] < cena_stolpa["STONE"]:
		print("Premalo surovin za stolp")
		_pokazi_obvestilo("Premalo surovin za stolp")
		return

	building_stolp = true
	_ponastavi_rotacijo_gradnje()

	print("Postavi stolp")


func _place_stolp(pos) -> bool:
	# Stolp se, kadar je dovolj blizu, zaskoči NATANKO v krajišče zidu ali
	# vrat. Sicer ostane na običajni mreži stavb.
	var priklop = _zid_najblizje_krajisce(pos, ZID_STOLP_SNAP_DOSEG)
	pos = priklop if priklop != null else _zaokrozi_na_mrezo(pos)
	if not _fog_dovoli_gradnjo(pos):
		return false

	if _postavitev_posega_v_vodo(pos, stolp_scene, smer_gradnje):
		_pokazi_obvestilo("Na vodi ni mogoče graditi")
		return false
	if _postavitev_posega_v_zasciteno_obmocje(pos, stolp_scene, smer_gradnje):
		_pokazi_obvestilo("Na obarvanem območju glavne stavbe ni mogoče graditi")
		return false

	if _celica_zgradbe_zasedena(pos):
		print("Ta celica mreže je že zasedena")
		_pokazi_obvestilo("Ta celica mreže je že zasedena")
		return false

	var min_razdalja = _minimalna_razdalja_od_dreves_za(stolp_scene)
	if _prevec_blizu_vira(pos, min_razdalja, stolp_scene, smer_gradnje):
		print("Stolp je preblizu vira")
		_pokazi_obvestilo("Stolp je preblizu drevesa, kamna ali drugega vira")
		return false

	if _prevec_blizu_zgradbe(pos, _polmer_za_prekrivanje_scene(stolp_scene, "stolp"), false, "", 1, "stolp"):
		print("Tu že stoji druga zgradba")
		_pokazi_obvestilo("Tu že stoji druga zgradba")
		return false

	if resources["WOOD"] < cena_stolpa["WOOD"] or resources["STONE"] < cena_stolpa["STONE"]:
		_pokazi_obvestilo("Premalo surovin za stolp")
		return false

	resources["WOOD"] -= cena_stolpa["WOOD"]
	resources["STONE"] -= cena_stolpa["STONE"]
	update_ui()

	var nova = stolp_scene.instantiate()

	nova.global_position = pos
	_uporabi_smer_gradnje(nova)
	nova.max_hp = stolp_hp_po_levelu[1]
	nova.damage = stolp_damage_po_levelu[1]
	nova.attack_range = stolp_range_po_levelu[1]

	add_child(nova)
	nova.add_to_group("stolpi")
	nova.prikazi_nivo(1)
	_zahtevaj_posodobitev_navigacije()
	_avtomatsko_dodeli_gradnjo(nova)

	stevilo_stolpov += 1

	print("Stolp zgrajen")
	return true


func _on_nadgradi_stolp_pressed():

	if not is_instance_valid(selected_building) or not ("tip_zgradbe" in selected_building) or selected_building.tip_zgradbe != "stolp":
		print("Najprej izberi stolp")
		return
	if selected_building.v_gradnji or selected_building.v_nadgradnji:
		_pokazi_obvestilo("Stolp je trenutno zaseden")
		return
	var trenutni_level: int = selected_building.nivo_zgradbe
	if trenutni_level >= 3:
		print("Stolp je že na najvišjem nivoju")
		return

	var naslednji_level = trenutni_level + 1
	var cena = cena_nadgradnje_stolpa[naslednji_level]

	if resources["WOOD"] < cena["WOOD"] or resources["STONE"] < cena["STONE"]:
		print("Premalo surovin za nadgradnjo stolpov")
		_pokazi_obvestilo("Premalo surovin za nadgradnjo stolpov")
		return

	if not selected_building.zacni_nadgradnjo(naslednji_level, cas_nadgradnje_stolpa[naslednji_level]):
		return
	resources["WOOD"] -= cena["WOOD"]
	resources["STONE"] -= cena["STONE"]
	update_ui()
	_posodobi_stolp_gumb()
	_pokazi_obvestilo("Nadgradnja stolpa: %ds" % int(cas_nadgradnje_stolpa[naslednji_level]))
	print("Začeta nadgradnja stolpa na level ", naslednji_level)


func _posodobi_stolp_gumb() -> void:
	var stolp = selected_building if is_instance_valid(selected_building) and "tip_zgradbe" in selected_building and selected_building.tip_zgradbe == "stolp" else null
	_posodobi_nadgradnja_gumb(stolp_nadgradi_button, stolp, "stolp", cena_nadgradnje_stolpa, cas_nadgradnje_stolpa)


func _on_poveljnik_button_pressed():

	if glavna_stavba_level < 3:
		print("Poglavar zahteva glavno stavbo level 3")
		_pokazi_obvestilo("Poglavar je na voljo šele na nivoju 3")
		return
	if not get_tree().get_nodes_in_group("poveljniki").is_empty():
		_pokazi_obvestilo("En poglavar je že živ")
		return

	if glavna_current_type == "POGLAVAR" or glavna_production_queue.has("POGLAVAR"):
		print("Poglavar se že izdeluje ali čaka")
		return
	if _glavna_stevilo_narocil() >= MAX_GLAVNA_QUEUE:
		_pokazi_obvestilo("Čakalna vrsta glavne stavbe je polna")
		return

	if vojaska_populacija + populacija_cena_poveljnika > max_vojaska_populacija:
		print("Ni dovolj prostora za populacijo vojske")
		return

	if resources["FOOD"] < cena_poveljnika["FOOD"] or resources["WOOD"] < cena_poveljnika["WOOD"] or resources["GOLD"] < cena_poveljnika["GOLD"]:
		print("Premalo surovin za poveljnika")
		_pokazi_obvestilo("Premalo surovin za poveljnika")
		return

	resources["FOOD"] -= cena_poveljnika["FOOD"]
	resources["WOOD"] -= cena_poveljnika["WOOD"]
	resources["GOLD"] -= cena_poveljnika["GOLD"]
	vojaska_populacija += populacija_cena_poveljnika
	update_ui()

	_dodaj_v_glavno_vrsto("POGLAVAR")

	print("Poglavar dodan v čakalno vrsto")


func _dodaj_v_glavno_vrsto(tip: String) -> void:
	glavna_production_queue.append(tip)
	if glavna_current_type.is_empty():
		_zacni_naslednjo_glavna()


func _glavna_stevilo_narocil() -> int:
	return glavna_production_queue.size() + (0 if glavna_current_type.is_empty() else 1)


func _glavna_stevilo_tipa(tip: String) -> int:
	var rezultat := 1 if glavna_current_type == tip else 0
	for narocilo in glavna_production_queue:
		if narocilo == tip: rezultat += 1
	return rezultat


func _zacni_naslednjo_glavna() -> void:
	if glavna_production_queue.is_empty():
		glavna_current_type = ""
		glavna_production_timer = 0.0
		poveljnik_producing = false
		poveljnik_timer = 0.0
		return
	glavna_current_type = glavna_production_queue.pop_front()
	glavna_production_timer = 0.0
	poveljnik_producing = glavna_current_type == "POGLAVAR"
	poveljnik_timer = 0.0


func _posodobi_glavno_produkcijo(delta: float) -> void:
	if glavna_current_type.is_empty(): return
	glavna_production_timer += delta
	poveljnik_timer = glavna_production_timer if glavna_current_type == "POGLAVAR" else 0.0
	var potreben_cas := poveljnik_cas_izdelave if glavna_current_type == "POGLAVAR" else delavec_cas_izdelave
	if glavna_production_timer < potreben_cas: return
	var koncan_tip := glavna_current_type
	glavna_current_type = ""
	glavna_production_timer = 0.0
	poveljnik_producing = false
	poveljnik_timer = 0.0
	if koncan_tip == "POGLAVAR": _izdelaj_poveljnika()
	else: _izdelaj_delavca()
	_zacni_naslednjo_glavna()


func _izdelaj_poveljnika():

	var gh = get_tree().get_first_node_in_group("glavna_hisa")
	var pos = gh.global_position if gh else Vector2(200, 200)

	var stats = poveljnik_stats_po_levelu[3]

	var zaporedje := int(gh.rally_spawn_index) if is_instance_valid(gh) else 0
	var zbirni_odmik := _odmik_nove_enote(zaporedje)
	if is_instance_valid(gh): gh.rally_spawn_index += 1
	var nov = poveljnik_scene.instantiate()
	nov.max_hp = stats["max_hp"]
	nov.damage = stats["damage"]
	nov.aura_range = stats["aura_range"]
	nov.aura_damage_bonus = stats["aura_bonus"]
	nov.global_position = pos + Vector2(zbirni_odmik.x * 0.55, 55.0 + zbirni_odmik.y * 0.35)

	add_child(nov)
	nov.uporabi_nadgradnje(glavna_stavba_level, maxi(1, vojasnica_level))

	if gh and "ima_rally_tocko" in gh and gh.ima_rally_tocko:
		nov.target_position = gh.rally_point + zbirni_odmik
		nov.state = "WALKING"

	print("Poveljnik izdelan")


func spawn_enoto(tip: String, pos: Vector2, proizvodna_vojasnica = null):

	var scena = null

	if tip == "BOJEVNIK":
		scena = bojevnik_scene
	elif tip == "KOPJENIK":
		scena = kopjenik_scene
	elif tip == "TESKA":
		scena = teska_enota_scene

	if scena == null:
		return

	var izvorna_vojasnica = proizvodna_vojasnica if is_instance_valid(proizvodna_vojasnica) else vojasnica_ref
	var zaporedje := int(izvorna_vojasnica.rally_spawn_index) if is_instance_valid(izvorna_vojasnica) else 0
	var zbirni_odmik := _odmik_nove_enote(zaporedje)
	if is_instance_valid(izvorna_vojasnica): izvorna_vojasnica.rally_spawn_index += 1
	var nova = scena.instantiate()
	# Tudi pred vojašnico se novinci ne pojavijo drug na drugem.
	nova.global_position = pos + Vector2(zbirni_odmik.x * 0.55, 55.0 + zbirni_odmik.y * 0.35)
	add_child(nova)
	nova.uporabi_nadgradnje(glavna_stavba_level, maxi(1, vojasnica_level))

	if is_instance_valid(izvorna_vojasnica) and izvorna_vojasnica.ima_rally_tocko:
		nova.target_position = izvorna_vojasnica.rally_point + zbirni_odmik
		nova.state = "WALKING"

	print("Nova enota: ", tip)


func _odmik_nove_enote(zaporedje: int) -> Vector2:
	# Osem mest na vsakem obroču okoli zbirne točke. Naslednji obroč je večji,
	# zato se tudi več zapored izdelanih vojakov nikoli ne naloži na isto mesto.
	var obroc := zaporedje / 8
	var mesto := zaporedje % 8
	var radij := 30.0 + float(obroc) * 27.0
	var kot := -PI * 0.5 + TAU * float(mesto) / 8.0
	return Vector2(cos(kot), sin(kot) * 0.62) * radij
