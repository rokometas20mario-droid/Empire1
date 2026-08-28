class_name ZivalAnimacije
extends RefCounted

const SMERI: Array[String] = ["jug", "sever", "vzhod", "zahod"]
const TEKSTURE: Dictionary = {
	"jelen": preload("res://assets/zivali/jelen_hoja.png"),
	"divji_prasic": preload("res://assets/zivali/divji_prasic_hoja.png"),
	"pragovedo": preload("res://assets/zivali/pragovedo_hoja.png"),
}
const BOCNE_TEKSTURE: Dictionary = {
	"jelen": preload("res://assets/zivali/jelen_bocno_v4.png"),
	"divji_prasic": preload("res://assets/zivali/divji_prasic_bocno_v4.png"),
	"pragovedo": preload("res://assets/zivali/pragovedo_bocno_v4.png"),
}
const SPREDAJ_TEKSTURE: Dictionary = {
	"jelen": preload("res://assets/zivali/jelen_spredaj_v1.png"),
	"divji_prasic": preload("res://assets/zivali/divji_prasic_spredaj_v1.png"),
	"pragovedo": preload("res://assets/zivali/pragovedo_spredaj_v1.png"),
}
const ZADAJ_TEKSTURE: Dictionary = {
	"jelen": preload("res://assets/zivali/jelen_zadaj_v1.png"),
	"divji_prasic": preload("res://assets/zivali/divji_prasic_zadaj_v1.png"),
	"pragovedo": preload("res://assets/zivali/pragovedo_zadaj_v1.png"),
}
const MRTVE_TEKSTURE: Dictionary = {
	"jelen": preload("res://assets/zivali/jelen_mrtva_v1.png"),
	"divji_prasic": preload("res://assets/zivali/divji_prasic_mrtva_v1.png"),
	"pragovedo": preload("res://assets/zivali/pragovedo_mrtva_v1.png"),
}
const MERILA: Dictionary = {
	"jelen": 0.30,
	"divji_prasic": 0.31,
	"pragovedo": 0.38,
}
const HITROSTI: Dictionary = {
	"jelen": 8.0,
	"divji_prasic": 7.0,
	"pragovedo": 6.0,
}

static var _okvirji_po_vrsti: Dictionary = {}


static func pripravi(sprite: AnimatedSprite2D, vrsta: String) -> void:
	var prava_vrsta := vrsta if vrsta in TEKSTURE else "jelen"
	if not prava_vrsta in _okvirji_po_vrsti:
		_okvirji_po_vrsti[prava_vrsta] = _ustvari_okvirje(prava_vrsta)
	sprite.sprite_frames = _okvirji_po_vrsti[prava_vrsta]
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var merilo: float = float(MERILA[prava_vrsta])
	sprite.scale = Vector2.ONE * merilo
	# Vseh osem bocnih faz uporablja isto talno crto. Trup, glava in rep se
	# premikajo samo toliko, kolikor zahteva naraven prenos teze skozi korak.
	sprite.position = Vector2(0.0, -155.0 * merilo)
	predvajaj(sprite, Vector2.ZERO, "jug")


static func smer_iz_vektorja(vektor: Vector2, prejsnja: String = "jug") -> String:
	if vektor.length_squared() < 0.01:
		return prejsnja
	if absf(vektor.x) > absf(vektor.y):
		return "vzhod" if vektor.x > 0.0 else "zahod"
	return "jug" if vektor.y > 0.0 else "sever"


static func predvajaj(sprite: AnimatedSprite2D, hitrost: Vector2, prejsnja_smer: String) -> String:
	var smer := smer_iz_vektorja(hitrost, prejsnja_smer)
	var se_premika := hitrost.length_squared() > 4.0
	var ime := ("walk_" if se_premika else "idle_") + smer
	if se_premika:
		if sprite.animation != ime or not sprite.is_playing():
			sprite.play(ime)
	else:
		if sprite.animation != ime:
			sprite.animation = ime
		sprite.pause()
		sprite.frame = 0
	# Zahod je natančno zrcaljena ista bočna hoja kot vzhod. Tako se ob menjavi
	# smeri ne zamenja telesna silhueta in žival ne zdrsne po tleh.
	sprite.flip_h = smer == "zahod"
	return smer


static func pokazi_mrtvo(sprite: AnimatedSprite2D, vrsta: String) -> void:
	var prava_vrsta := vrsta if vrsta in MRTVE_TEKSTURE else "jelen"
	var okvirji := SpriteFrames.new()
	if okvirji.has_animation("default"):
		okvirji.remove_animation("default")
	okvirji.add_animation("mrtva")
	okvirji.set_animation_loop("mrtva", false)
	okvirji.add_frame("mrtva", MRTVE_TEKSTURE[prava_vrsta])
	sprite.sprite_frames = okvirji
	sprite.animation = "mrtva"
	sprite.frame = 0
	sprite.pause()
	sprite.flip_h = false
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	var merila := {"jelen": 0.31, "divji_prasic": 0.30, "pragovedo": 0.38}
	var odmiki := {"jelen": -37.0, "divji_prasic": -34.0, "pragovedo": -42.0}
	var merilo: float = float(merila[prava_vrsta])
	sprite.scale = Vector2.ONE * merilo
	sprite.position = Vector2(0.0, float(odmiki[prava_vrsta]))


static func _ustvari_okvirje(vrsta: String) -> SpriteFrames:
	var rezultat := SpriteFrames.new()
	if rezultat.has_animation("default"):
		rezultat.remove_animation("default")
	var hitrost: float = float(HITROSTI[vrsta])
	for vrstica in range(SMERI.size()):
		var smer := SMERI[vrstica]
		var idle_ime := "idle_" + smer
		var walk_ime := "walk_" + smer
		rezultat.add_animation(idle_ime)
		rezultat.set_animation_loop(idle_ime, false)
		rezultat.set_animation_speed(idle_ime, 1.0)
		var je_bocna := smer == "vzhod" or smer == "zahod"
		var smerna_tekstura: Texture2D
		if je_bocna:
			smerna_tekstura = BOCNE_TEKSTURE[vrsta]
		elif smer == "jug":
			smerna_tekstura = SPREDAJ_TEKSTURE[vrsta]
		else:
			smerna_tekstura = ZADAJ_TEKSTURE[vrsta]
		var idle_okvir := _izrez_naravni(smerna_tekstura, 0)
		rezultat.add_frame(idle_ime, idle_okvir)
		rezultat.add_animation(walk_ime)
		rezultat.set_animation_loop(walk_ime, true)
		rezultat.set_animation_speed(walk_ime, hitrost)
		for stolpec in range(8):
			var okvir := _izrez_naravni(smerna_tekstura, stolpec)
			rezultat.add_frame(walk_ime, okvir)
	return rezultat


static func _izrez_naravni(tekstura: Texture2D, stolpec: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = tekstura
	atlas.region = Rect2(stolpec * 320, 0, 320, 330)
	return atlas


static func _izrez(tekstura: Texture2D, stolpec: int, vrstica: int) -> AtlasTexture:
	var x0 := int(round(float(stolpec) * tekstura.get_width() / 4.0))
	var x1 := int(round(float(stolpec + 1) * tekstura.get_width() / 4.0))
	var y0 := int(round(float(vrstica) * tekstura.get_height() / 4.0))
	var y1 := int(round(float(vrstica + 1) * tekstura.get_height() / 4.0))
	var atlas := AtlasTexture.new()
	atlas.atlas = tekstura
	atlas.region = Rect2(x0, y0, x1 - x0, y1 - y0)
	return atlas
