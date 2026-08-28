class_name DelavecAnimacije
extends RefCounted

# Vse slike so razdeljene v mrezo 4 x 4. Vrstice so vedno:
# jug, sever, vzhod, zahod; stolpci so stirje koraki animacije.
const SMERI: Array[String] = ["jug", "sever", "vzhod", "zahod"]
const CILJNA_VISINA_OKVIRJA: float = 96.0
const OSNOVNI_ODMIK_Y: float = -34.0
# Enak osnovni ritem kot pri dobri hoji gor/dol. Ker sta bočna koraka sedaj
# res razlicna, hitrejse preklapljanje ni vec potrebno in bi delovalo sunkovito.
const HITROST_HOJE_PRI_125: float = 5.0

const MIRUJE: Texture2D = preload("res://assets/delavec/delavec_miruje.png")
const HOJA: Texture2D = preload("res://assets/delavec/delavec_hoja.png")
const HOJA_BOCNO: Texture2D = preload("res://assets/delavec/delavec_hoja_bocno_v2.png")
const ORODJE: Texture2D = preload("res://assets/delavec/delavec_orodje.png")
const GRADNJA: Texture2D = preload("res://assets/delavec/delavec_gradnja.png")
const KMET: Texture2D = preload("res://assets/delavec/delavec_kmet.png")
const KOSARA_POLNA: Texture2D = preload("res://assets/delavec/kosara_polna_v2.png")
const LOV: Texture2D = preload("res://assets/delavec/delavec_lov_v2.png")

static var _skupni_okvirji: SpriteFrames = null
static var _teksture_kosare: Dictionary = {}


static func pripravi(sprite: AnimatedSprite2D) -> void:
	if _skupni_okvirji == null:
		_skupni_okvirji = _ustvari_okvirje()
	sprite.sprite_frames = _skupni_okvirji
	sprite.centered = true
	sprite.position = Vector2(0.0, OSNOVNI_ODMIK_Y)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	predvajaj(sprite, "idle", "jug")


static func smer_iz_vektorja(vektor: Vector2, prejsnja: String = "jug") -> String:
	if vektor.length_squared() < 0.01:
		return prejsnja
	if abs(vektor.x) > abs(vektor.y):
		return "vzhod" if vektor.x > 0.0 else "zahod"
	return "jug" if vektor.y > 0.0 else "sever"


static func predvajaj(sprite: AnimatedSprite2D, vrsta: String, smer: String) -> void:
	var ime := vrsta + "_" + smer
	if not sprite.sprite_frames.has_animation(ime):
		ime = "idle_jug"

	# Mirovanje je namenoma samo en negiben okvir. Prejsnja stirislicna
	# "idle" animacija je imela lik v vsakem okvirju malo bolj desno, zato je
	# delavec na mestu drsel in ob koncu cikla preskocil nazaj na levo.
	if vrsta == "idle":
		if sprite.animation != ime:
			sprite.animation = ime
		sprite.pause()
		sprite.frame = 0
	else:
		if sprite.animation != ime or not sprite.is_playing():
			sprite.play(ime)

	# Nova bočna hoja uporablja eno preverjeno desno usmerjeno animacijo.
	# Enake korake uporablja tudi nošenje; surovina je ločen Sprite2D in zato
	# telo delavca med vračanjem ne potrebuje starega popačenega sprite lista.
	var uporablja_bocno_hojo := (
		(vrsta == "walk" or vrsta == "nosi" or vrsta == "lov")
		and (smer == "vzhod" or smer == "zahod")
	)
	sprite.flip_h = uporablja_bocno_hojo and smer == "zahod"

	# Hitrost menjave korakov sledi dejanski hitrosti enote. Pri glavnem
	# delavcu se tako noge zamenjajo dovolj hitro, da ne drsi po tleh, pocasni
	# kmet pa ne cepeta na mestu z enako hitrostjo kot delavec.
	if vrsta == "walk" or vrsta == "nosi":
		var hitrost_gibanja := 125.0
		var stars := sprite.get_parent()
		if stars is CharacterBody2D:
			hitrost_gibanja = (stars as CharacterBody2D).velocity.length()
		sprite.speed_scale = clampf(hitrost_gibanja / 125.0, 0.45, 1.35)
	else:
		sprite.speed_scale = 1.0

	sprite.scale = Vector2.ONE * _skala_za(vrsta)
	# Majhen dvig v prehodnih okvirjih naredi korak berljiv tudi pri majhnem
	# liku, senca pa ostane na tleh. Delavec se zato ne premika kot toga slika.
	var korak_y := 0.0
	if vrsta == "walk" or vrsta == "nosi":
		korak_y = -2.0 if sprite.frame % 2 == 1 else 0.0
	sprite.position = Vector2(0.0, OSNOVNI_ODMIK_Y + korak_y)


static func tekstura_kosare(smer: String, tip: String) -> AtlasTexture:
	var kljuc := smer + ":" + tip
	if kljuc in _teksture_kosare:
		return _teksture_kosare[kljuc]

	# Nova slika je 4 x 4. Vrstice: JUG, SEVER, VZHOD, ZAHOD.
	# Stolpci: LES, KAMEN, ZLATO, HRANA. Vsak izrez je že ena sama,
	# do vrha napolnjena košara, zato se ločena surovina ne more več
	# premakniti stran od košare ali lebdeti čez delavca.
	var vrstica := SMERI.find(smer)
	if vrstica < 0:
		vrstica = 0
	var stolpec := {
		"WOOD": 0,
		"STONE": 1,
		"GOLD": 2,
		"FOOD": 3,
	}.get(tip, 0) as int
	var tekstura := _izrez(KOSARA_POLNA, stolpec, vrstica, 4, 4)
	_teksture_kosare[kljuc] = tekstura
	return tekstura


static func _ustvari_okvirje() -> SpriteFrames:
	var okvirji := SpriteFrames.new()
	if okvirji.has_animation("default"):
		okvirji.remove_animation("default")

	for vrstica in range(SMERI.size()):
		var smer := SMERI[vrstica]
		# Umetnine imajo med vrsticami razlicno velike prazne robove, zato za
		# hojo in mirovanje uporabimo preverjene zacetke vrstic. Enaka delitev
		# slike na tocne cetrtine je stranskima smerema prej odrezala vrh glave.
		var idle_y: int = [0, 315, 637, 937][vrstica]
		var idle_h: int = [315, 315, 300, 310][vrstica]
		var walk_y: int = [0, 315, 630, 932][vrstica]
		var walk_h: int = [315, 315, 302, 315][vrstica]
		# Za vsako smer izberemo en naraven, dobro centriran stojeci okvir.
		# Spredaj, zadaj in desno je to tretji stolpec; levo drugi.
		var idle_stolpec: int = 1 if smer == "zahod" else 2
		_dodaj_mirujoci_okvir(okvirji, "idle_" + smer, MIRUJE, idle_y, idle_h, idle_stolpec)
		if smer == "vzhod" or smer == "zahod":
			# Namenska bočna lista ima res razlicna koraka: dolg stik s tlemi in
			# prehodni korak z dvignjeno peto. Stara skoraj enaka stranska okvirja
			# se ne uporabljata vec.
			_dodaj_bocno_hojo(
				okvirji,
				"walk_" + smer,
				HITROST_HOJE_PRI_125
			)
			_dodaj_bocno_hojo(
				okvirji,
				"nosi_" + smer,
				HITROST_HOJE_PRI_125
			)
		else:
			# Hojo gor/dol pustimo pri dosedanjem tempu, ker je bila videti dobro.
			_dodaj_animacijo_obmocje(
				okvirji,
				"walk_" + smer,
				HOJA,
				walk_y,
				walk_h,
				5.0,
				4
			)
			# Med nošenjem gor/dol uporabimo povsem iste pravilne korake kot pri
			# navadni hoji. Vidna surovina se doda posebej v delavec.gd.
			_dodaj_animacijo_obmocje(
				okvirji,
				"nosi_" + smer,
				HOJA,
				walk_y,
				walk_h,
				5.0,
				4
			)
		_dodaj_animacijo(okvirji, "orodje_" + smer, ORODJE, vrstica, 6.0, 4)
		_dodaj_animacijo(okvirji, "gradnja_" + smer, GRADNJA, vrstica, 6.0, 4)
		_dodaj_animacijo(okvirji, "kmet_" + smer, KMET, vrstica, 6.0, 4)
		var lov_vrstica := 2 if smer == "vzhod" or smer == "zahod" else vrstica
		_dodaj_animacijo(okvirji, "lov_" + smer, LOV, lov_vrstica, 8.0, 4)
		okvirji.set_animation_loop("lov_" + smer, false)

	return okvirji


static func _dodaj_mirujoci_okvir(
	okvirji: SpriteFrames,
	ime: String,
	tekstura: Texture2D,
	y: int,
	visina: int,
	stolpec: int
) -> void:
	okvirji.add_animation(ime)
	okvirji.set_animation_speed(ime, 1.0)
	okvirji.set_animation_loop(ime, false)
	var x0 := int(round(float(stolpec) * tekstura.get_width() / 4.0))
	var x1 := int(round(float(stolpec + 1) * tekstura.get_width() / 4.0))
	var atlas := AtlasTexture.new()
	atlas.atlas = tekstura
	atlas.region = Rect2(x0, y, x1 - x0, mini(visina, tekstura.get_height() - y))
	okvirji.add_frame(ime, atlas)


static func _dodaj_animacijo_obmocje(
	okvirji: SpriteFrames,
	ime: String,
	tekstura: Texture2D,
	y: int,
	visina: int,
	hitrost: float,
	stevilo_okvirjev: int
) -> void:
	okvirji.add_animation(ime)
	okvirji.set_animation_speed(ime, hitrost)
	okvirji.set_animation_loop(ime, true)
	for stolpec in range(stevilo_okvirjev):
		var x0 := int(round(float(stolpec) * tekstura.get_width() / 4.0))
		var x1 := int(round(float(stolpec + 1) * tekstura.get_width() / 4.0))
		var atlas := AtlasTexture.new()
		atlas.atlas = tekstura
		atlas.region = Rect2(x0, y, x1 - x0, mini(visina, tekstura.get_height() - y))
		okvirji.add_frame(ime, atlas)


static func _dodaj_bocno_hojo(
	okvirji: SpriteFrames,
	ime: String,
	hitrost: float
) -> void:
	okvirji.add_animation(ime)
	okvirji.set_animation_speed(ime, hitrost)
	okvirji.set_animation_loop(ime, true)
	for stolpec in [0, 1, 0, 1]:
		okvirji.add_frame(ime, _izrez(HOJA_BOCNO, stolpec, 0, 2, 1))


static func _dodaj_animacijo(
	okvirji: SpriteFrames,
	ime: String,
	tekstura: Texture2D,
	vrstica: int,
	hitrost: float,
	stevilo_okvirjev: int
) -> void:
	okvirji.add_animation(ime)
	okvirji.set_animation_speed(ime, hitrost)
	okvirji.set_animation_loop(ime, true)
	for stolpec in range(stevilo_okvirjev):
		okvirji.add_frame(ime, _izrez(tekstura, stolpec, vrstica, 4, 4))


static func _izrez(
	tekstura: Texture2D,
	stolpec: int,
	vrstica: int,
	stolpcev: int,
	vrstic: int
) -> AtlasTexture:
	# Robove racunamo loceno, ker slike niso nujno deljive s 4. Tako se noben
	# piksel med sosednjima okvirjema ne izgubi in se okvirji ne prekrivajo.
	var x0 := int(round(float(stolpec) * tekstura.get_width() / stolpcev))
	var x1 := int(round(float(stolpec + 1) * tekstura.get_width() / stolpcev))
	var y0 := int(round(float(vrstica) * tekstura.get_height() / vrstic))
	var y1 := int(round(float(vrstica + 1) * tekstura.get_height() / vrstic))
	var atlas := AtlasTexture.new()
	atlas.atlas = tekstura
	atlas.region = Rect2(x0, y0, x1 - x0, y1 - y0)
	return atlas


static func _skala_za(vrsta: String) -> float:
	var visina_okvirja := 320.0
	match vrsta:
		"idle":
			visina_okvirja = 320.0
		"orodje":
			visina_okvirja = float(ORODJE.get_height()) / 4.0
		"gradnja":
			visina_okvirja = float(GRADNJA.get_height()) / 4.0
		"kmet":
			visina_okvirja = float(KMET.get_height()) / 4.0
		"lov":
			visina_okvirja = float(LOV.get_height()) / 4.0
	return CILJNA_VISINA_OKVIRJA / visina_okvirja
