class_name MetalecStolpAnimacije
extends RefCounted

const TEKSTURA: Texture2D = preload("res://assets/stolp/metalec_sulic_v2.png")
const SMERI: Array[String] = ["jug", "sever", "vzhod", "zahod"]
const MERILO := 0.22
const ODMIK_DO_STOPAL := Vector2(0.0, -62.0)

static var _okvirji: SpriteFrames = null


static func pripravi(sprite: AnimatedSprite2D) -> void:
	if _okvirji == null:
		_okvirji = _ustvari_okvirje()
	sprite.sprite_frames = _okvirji
	sprite.centered = true
	sprite.scale = Vector2.ONE * MERILO
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	miruj(sprite, "jug")


static func smer_iz_vektorja(vektor: Vector2, prejsnja: String = "jug") -> String:
	if vektor.length_squared() < 0.01:
		return prejsnja
	if absf(vektor.x) > absf(vektor.y):
		return "vzhod" if vektor.x > 0.0 else "zahod"
	return "jug" if vektor.y > 0.0 else "sever"


static func miruj(sprite: AnimatedSprite2D, smer: String) -> void:
	var ime := "idle_" + smer
	if sprite.animation != ime:
		sprite.animation = ime
	sprite.pause()
	sprite.frame = 0


static func vrzi(sprite: AnimatedSprite2D, smer: String) -> void:
	sprite.play("met_" + smer)


static func _ustvari_okvirje() -> SpriteFrames:
	var rezultat := SpriteFrames.new()
	if rezultat.has_animation("default"):
		rezultat.remove_animation("default")
	for vrstica in range(SMERI.size()):
		var smer := SMERI[vrstica]
		var idle_ime := "idle_" + smer
		var met_ime := "met_" + smer
		rezultat.add_animation(idle_ime)
		rezultat.set_animation_loop(idle_ime, false)
		rezultat.set_animation_speed(idle_ime, 1.0)
		rezultat.add_frame(idle_ime, _izrez(0, vrstica))
		rezultat.add_animation(met_ime)
		rezultat.set_animation_loop(met_ime, false)
		rezultat.set_animation_speed(met_ime, 7.5)
		for stolpec in range(4):
			rezultat.add_frame(met_ime, _izrez(stolpec, vrstica))
	return rezultat


static func _izrez(stolpec: int, vrstica: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = TEKSTURA
	atlas.region = Rect2(stolpec * 256, vrstica * 384, 256, 384)
	return atlas
