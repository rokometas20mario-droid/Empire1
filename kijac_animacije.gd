class_name KijacAnimacije
extends RefCounted

const TEKSTURA: Texture2D = preload("res://assets/vojska/kijac_v3.png")
const TEKSTURA_IDLE: Texture2D = preload("res://assets/vojska/kijac_idle_v3.png")
const SMERI: Array[String] = ["jug", "sever", "vzhod", "zahod"]
static var _okvirji: SpriteFrames

static func pripravi(sprite: AnimatedSprite2D) -> void:
	if _okvirji == null: _okvirji = _ustvari_okvirje()
	sprite.sprite_frames = _okvirji
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	miruj(sprite, "jug")

static func smer_iz_vektorja(v: Vector2, prejsnja := "jug") -> String:
	if v.length_squared() < 0.01: return prejsnja
	if absf(v.x) > absf(v.y): return "vzhod" if v.x > 0 else "zahod"
	return "jug" if v.y > 0 else "sever"

static func posodobi_gibanje(sprite: AnimatedSprite2D, hitrost: Vector2, prejsnja: String, razdalja := 0.0) -> String:
	if napad_poteka(sprite): return prejsnja
	var smer := smer_iz_vektorja(hitrost, prejsnja)
	_nastavi(sprite, smer)
	if hitrost.length_squared() > 4.0:
		var ime := "walk_" + smer
		sprite.animation = ime
		sprite.pause()
		sprite.frame = int(floor(razdalja / 12.0)) % 4
	else: miruj(sprite, smer)
	return smer

static func miruj(sprite: AnimatedSprite2D, smer: String) -> void:
	_nastavi(sprite, smer); sprite.animation = "idle_" + smer; sprite.pause(); sprite.frame = 0

static func napadi(sprite: AnimatedSprite2D, smer: String) -> void:
	_nastavi(sprite, smer); sprite.speed_scale = 1.0; sprite.play("attack_" + smer)

static func napad_poteka(sprite: AnimatedSprite2D) -> bool:
	return String(sprite.animation).begins_with("attack_") and sprite.is_playing()

static func _nastavi(sprite: AnimatedSprite2D, smer: String) -> void:
	sprite.flip_h = smer == "zahod"
	sprite.scale = Vector2.ONE * 0.43
	# Vsi okvirji imajo isto sidro stopal; lik zato ne raste in ne lebdi.
	sprite.position = Vector2(0, 4.0 - (256.0 - 128.0) * 0.43)

static func _ustvari_okvirje() -> SpriteFrames:
	var r := SpriteFrames.new(); r.remove_animation("default")
	for vrstica in 4:
		var smer := SMERI[vrstica]
		var vidna := 2 if smer == "vzhod" or smer == "zahod" else vrstica
		for predpona in ["idle_", "walk_", "attack_"]:
			r.add_animation(predpona + smer)
		r.set_animation_loop("idle_" + smer, false)
		r.add_frame("idle_" + smer, _izrez_idle(vrstica))
		r.set_animation_loop("walk_" + smer, true)
		# Vsi štirje koraki so posamezno poravnani na isto črto stopal. Tako je
		# izmenjava nog vidna, telo pa med hojo ne skače ali spreminja velikosti.
		for x in 4: r.add_frame("walk_" + smer, _izrez(x, vidna))
		r.set_animation_loop("attack_" + smer, false); r.set_animation_speed("attack_" + smer, 6.5)
		# Dolg vodoravni zamah je v izvirnem listu segel v sosednjo celico in
		# ustvaril packo. Uporabimo tri cele, talno zasidrane faze udarca.
		for x in [4, 5, 7]: r.add_frame("attack_" + smer, _izrez(x, vidna))
	return r

static func _izrez(x: int, y: int) -> AtlasTexture:
	var a := AtlasTexture.new(); a.atlas = TEKSTURA; a.region = Rect2(x * 192, y * 256, 192, 256); return a

static func _izrez_idle(x: int) -> AtlasTexture:
	var a := AtlasTexture.new(); a.atlas = TEKSTURA_IDLE; a.region = Rect2(x * 192, 0, 192, 256); return a
