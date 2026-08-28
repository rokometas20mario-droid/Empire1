class_name EnotaAnimacije
extends RefCounted

# Prvi pravi vojaski lik. Vrstice so JUG, SEVER, VZHOD, ZAHOD.
# Stolpci: mirovanje, trije koraki, zamah, sunek in zakljucek napada.
const TEKSTURA: Texture2D = preload("res://assets/vojska/sulicar_v1.png")
const TEKSTURA_HOJA: Texture2D = preload("res://assets/vojska/sulicar_hoja_v3.png")
const SMERI: Array[String] = ["jug", "sever", "vzhod", "zahod"]
const CILJNA_VISINA := 92.0
const TLA_Y := 4.0
const STOLPCEV := 7
const VRSTIC := 4

static var _okvirji: SpriteFrames = null


static func pripravi(sprite: AnimatedSprite2D) -> void:
	if _okvirji == null:
		_okvirji = _ustvari_okvirje()
	sprite.sprite_frames = _okvirji
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	miruj(sprite, "jug")


static func smer_iz_vektorja(vektor: Vector2, prejsnja: String = "jug") -> String:
	if vektor.length_squared() < 0.01:
		return prejsnja
	if absf(vektor.x) > absf(vektor.y):
		return "vzhod" if vektor.x > 0.0 else "zahod"
	return "jug" if vektor.y > 0.0 else "sever"


static func posodobi_gibanje(
	sprite: AnimatedSprite2D,
	hitrost: Vector2,
	prejsnja_smer: String,
	prehojena_razdalja: float = 0.0
) -> String:
	# Sunka sulice ne prekinemo z mirovanjem v istem fizikalnem okvirju.
	if napad_poteka(sprite):
		return prejsnja_smer
	var smer := smer_iz_vektorja(hitrost, prejsnja_smer)
	if hitrost.length_squared() > 4.0:
		var ime := "walk_" + smer
		_nastavi_prikaz(sprite, "walk", smer)
		# Cista bocna vrstica je narisana proti zahodu; za vzhod jo zrcalimo.
		# Sprednja/zadnja smer ostaneta nezrcaljeni.
		sprite.flip_h = smer == "vzhod" if smer == "vzhod" or smer == "zahod" else false
		if sprite.animation != ime:
			sprite.animation = ime
		# Okvir ni več odvisen od časa, ampak od dejansko prehojenih pikslov.
		# Stopalo zato ne more drseti, ko se enota upočasni ali zavije.
		sprite.pause()
		var stevilo := sprite.sprite_frames.get_frame_count(ime)
		sprite.frame = int(floor(prehojena_razdalja / 10.0)) % maxi(1, stevilo)
		sprite.speed_scale = 1.0
	else:
		miruj(sprite, smer)
	return smer


static func miruj(sprite: AnimatedSprite2D, smer: String) -> void:
	_nastavi_prikaz(sprite, "idle", smer)
	sprite.flip_h = smer == "vzhod" if smer == "vzhod" or smer == "zahod" else false
	var ime := "idle_" + smer
	if sprite.animation != ime:
		sprite.animation = ime
	sprite.pause()
	sprite.frame = 0
	sprite.speed_scale = 1.0


static func napadi(sprite: AnimatedSprite2D, smer: String) -> void:
	_nastavi_prikaz(sprite, "attack", smer)
	sprite.flip_h = false
	sprite.speed_scale = 1.0
	sprite.play("attack_" + smer)


static func napad_poteka(sprite: AnimatedSprite2D) -> bool:
	return String(sprite.animation).begins_with("attack_") and sprite.is_playing()


static func _nastavi_prikaz(sprite: AnimatedSprite2D, vrsta: String, smer: String) -> void:
	# Stojeci in hodni list nista narisana v istem merilu: sprednji hodni lik
	# je visok okoli 220 px, stojeci pa le 183 px. Enotno scale=0.50 ga je
	# zato med hojo povecalo za skoraj petino. Merilo je zdaj izracunano iz
	# dejanske visine lika za vsako smer, zato ostane velikost nespremenjena.
	var visine_idle := {"jug": 183.0, "sever": 171.0, "vzhod": 165.0, "zahod": 165.0}
	var visine_walk := {"jug": 209.0, "sever": 208.0, "vzhod": 186.0, "zahod": 186.0}
	var visina: float = visine_walk.get(smer, 200.0) if vrsta == "walk" else visine_idle.get(smer, 175.0)
	var merilo := CILJNA_VISINA / visina
	# Stopala v stojecem listu segajo do dna 384-pikselnega okvirja, v hoji
	# pa do y=365. Položaj se zato izracuna iz pravega spodnjega roba in ne
	# iz enega fiksnega odmika, ki je hodnega vojaka dvignil nad senco.
	var spodnji_rob := 365.0 if vrsta == "walk" else 384.0
	sprite.scale = Vector2.ONE * merilo
	sprite.position = Vector2(0.0, TLA_Y - (spodnji_rob - 192.0) * merilo)


static func _ustvari_okvirje() -> SpriteFrames:
	var rezultat := SpriteFrames.new()
	if rezultat.has_animation("default"):
		rezultat.remove_animation("default")
	for vrstica in range(SMERI.size()):
		var smer := SMERI[vrstica]
		var idle_ime := "idle_" + smer
		var walk_ime := "walk_" + smer
		var attack_ime := "attack_" + smer

		rezultat.add_animation(idle_ime)
		rezultat.set_animation_loop(idle_ime, false)
		rezultat.set_animation_speed(idle_ime, 1.0)
		# Bočni smeri uporabljata isti preverjeni desni profil; zahod se zrcali
		# pri predvajanju. Tako se med levo/desno hojo ne zamenjata dva različno
		# velika lika iz dveh ločeno narisanih vrstic.
		var vizualna_vrstica := 3 if smer == "vzhod" or smer == "zahod" else vrstica
		rezultat.add_frame(idle_ime, _izrez(0, vizualna_vrstica))

		rezultat.add_animation(walk_ime)
		rezultat.set_animation_loop(walk_ime, true)
		rezultat.set_animation_speed(walk_ime, 9.0)
		if smer == "vzhod" or smer == "zahod":
			# Četrta vrstica ima dejanski osemfazni korak: leva in desna noga
			# se izmenjujeta, trup pa ostaja zasidran nad isto talno točko.
			for stolpec in range(8):
				rezultat.add_frame(walk_ime, _izrez_hoje(stolpec, 3))
		else:
			for stolpec in range(8):
				rezultat.add_frame(walk_ime, _izrez_hoje(stolpec, vrstica))

		rezultat.add_animation(attack_ime)
		rezultat.set_animation_loop(attack_ime, false)
		rezultat.set_animation_speed(attack_ime, 7.5)
		for stolpec in [4, 5, 6]:
			rezultat.add_frame(attack_ime, _izrez(stolpec, vrstica))
	return rezultat


static func _izrez(stolpec: int, vrstica: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = TEKSTURA
	atlas.region = Rect2(stolpec * 256, vrstica * 384, 256, 384)
	return atlas


static func _izrez_hoje(stolpec: int, vrstica: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = TEKSTURA_HOJA
	atlas.region = Rect2(stolpec * 256, vrstica * 384, 256, 384)
	return atlas
