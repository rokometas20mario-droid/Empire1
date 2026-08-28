class_name SekirasAnimacije
extends RefCounted

# Celoten sekiraš je na novo narisan v enem listu: idle, štirje koraki in
# tri faze napada. Nobena poza zato ne prihaja iz drugega merila.
const TEKSTURA: Texture2D = preload("res://assets/vojska/sekiras_v3.png")
const STRANSKI_NAPAD: Texture2D = preload("res://assets/vojska/sekiras_side_attack_v3.png")
const SMERI: Array[String] = ["jug", "sever", "vzhod", "zahod"]
const MERILO := 0.27
# Stranski napadalni izrez ima nekoliko manjšo izvorno višino kot osnovni
# list, vendar je bilo 0.42 za odtenek preveliko. 0.39 poravna trup z bočno
# hojo, zato se ob začetku udarca ne poveča.
const STRANSKO_NAPAD_MERILO := 0.39
const TLA_Y := 4.0
static var _okvirji: SpriteFrames


static func pripravi(sprite: AnimatedSprite2D) -> void:
	if _okvirji == null:
		_okvirji = _ustvari_okvirje()
	sprite.sprite_frames = _okvirji
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	miruj(sprite, "jug")


static func smer_iz_vektorja(v: Vector2, prejsnja := "jug") -> String:
	if v.length_squared() < 0.01:
		return prejsnja
	if absf(v.x) > absf(v.y):
		return "vzhod" if v.x > 0.0 else "zahod"
	return "jug" if v.y > 0.0 else "sever"


static func posodobi_gibanje(
	sprite: AnimatedSprite2D,
	hitrost: Vector2,
	prejsnja_smer: String,
	prehojena_razdalja := 0.0
) -> String:
	var smer := smer_iz_vektorja(hitrost, prejsnja_smer)
	if hitrost.length_squared() > 4.0:
		# Premikanje ima vedno prednost. Tako lovljenje premikajoče se živali
		# nikoli ne ostane zaklenjeno v zadnjem okvirju udarca.
		if napad_poteka(sprite):
			sprite.stop()
		_nastavi_prikaz(sprite, false)
		sprite.flip_h = false
		var ime := "walk_" + smer
		sprite.animation = ime
		sprite.pause()
		sprite.frame = int(floor(prehojena_razdalja / 9.0)) % 4
	else:
		if not napad_poteka(sprite):
			miruj(sprite, smer)
	return smer


static func miruj(sprite: AnimatedSprite2D, smer: String) -> void:
	_nastavi_prikaz(sprite, false)
	sprite.flip_h = false
	sprite.animation = "idle_" + smer
	sprite.pause()
	sprite.frame = 0


static func napadi(sprite: AnimatedSprite2D, smer: String) -> void:
	_nastavi_prikaz(sprite, smer == "vzhod" or smer == "zahod")
	sprite.flip_h = false
	sprite.speed_scale = 1.0
	sprite.play("attack_" + smer)


static func napad_poteka(sprite: AnimatedSprite2D) -> bool:
	return String(sprite.animation).begins_with("attack_") and sprite.is_playing()


static func _nastavi_prikaz(sprite: AnimatedSprite2D, stranski_napad: bool) -> void:
	var merilo := STRANSKO_NAPAD_MERILO if stranski_napad else MERILO
	sprite.scale = Vector2.ONE * merilo
	sprite.position = Vector2(0.0, TLA_Y - (384.0 - 192.0) * merilo)


static func _ustvari_okvirje() -> SpriteFrames:
	var r := SpriteFrames.new()
	if r.has_animation("default"):
		r.remove_animation("default")
	for vrstica in range(4):
		var smer := SMERI[vrstica]
		var idle := "idle_" + smer
		var walk := "walk_" + smer
		var attack := "attack_" + smer
		r.add_animation(idle)
		r.set_animation_loop(idle, false)
		r.add_frame(idle, _izrez(0, vrstica))
		r.add_animation(walk)
		r.set_animation_loop(walk, true)
		for x in range(1, 5):
			r.add_frame(walk, _izrez(x, vrstica))
		r.add_animation(attack)
		r.set_animation_loop(attack, false)
		r.set_animation_speed(attack, 7.0)
		if smer == "vzhod":
			for x in range(3):
				r.add_frame(attack, _izrez_stranski_napad(x))
		elif smer == "zahod":
			for x in range(3, 6):
				r.add_frame(attack, _izrez_stranski_napad(x))
		else:
			for x in range(5, 8):
				r.add_frame(attack, _izrez(x, vrstica))
	return r


static func _izrez(x: int, y: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = TEKSTURA
	a.region = Rect2(x * 256, y * 384, 256, 384)
	return a


static func _izrez_stranski_napad(x: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = STRANSKI_NAPAD
	a.region = Rect2(x * 512, 0, 512, 384)
	return a
