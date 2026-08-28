class_name PoglavarAnimacije
extends RefCounted

const BAZA = preload("res://kijac_animacije.gd")
const TEKSTURA: Texture2D = preload("res://assets/vojska/poglavar_v3.png")
const TEKSTURA_IDLE: Texture2D = preload("res://assets/vojska/poglavar_idle_v3.png")
const TEKSTURA_BOCNA_HOJA: Texture2D = preload("res://assets/vojska/poglavar_side_walk_v4.png")
const SMERI: Array[String] = ["jug", "sever", "vzhod", "zahod"]
static var _okvirji: SpriteFrames

static func pripravi(sprite: AnimatedSprite2D) -> void:
	if _okvirji == null: _okvirji = _ustvari_okvirje()
	sprite.sprite_frames = _okvirji; sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR; miruj(sprite, "jug")
static func smer_iz_vektorja(v: Vector2, p := "jug") -> String: return BAZA.smer_iz_vektorja(v, p)
static func posodobi_gibanje(s: AnimatedSprite2D, v: Vector2, p: String, d := 0.0) -> String:
	var smer := smer_iz_vektorja(v, p)
	if v.length_squared() > 4.0:
		# Premik mora prekiniti prejšnji zamah. Prej je poglavar med lovljenjem
		# ali novim bočnim ukazom ostal zaklenjen v napadalni animaciji, zato je
		# bilo videti, kot da drsi in samo maha z orožjem.
		if napad_poteka(s):
			s.stop()
		_nastavi(s, smer, "walk")
		s.animation = "walk_" + smer; s.pause(); s.frame = int(floor(d / 10.0)) % 4
	elif not napad_poteka(s):
		miruj(s, smer)
	return smer
static func miruj(s: AnimatedSprite2D, smer: String) -> void: _nastavi(s, smer, "idle"); s.animation = "idle_" + smer; s.pause(); s.frame = 0
static func napadi(s: AnimatedSprite2D, smer: String) -> void: _nastavi(s, smer, "attack"); s.speed_scale = 1.0; s.play("attack_" + smer)
static func napad_poteka(s: AnimatedSprite2D) -> bool: return String(s.animation).begins_with("attack_") and s.is_playing()
static func _nastavi(s: AnimatedSprite2D, smer: String, vrsta: String) -> void:
	var bocna_hoja := vrsta == "walk" and (smer == "vzhod" or smer == "zahod")
	if bocna_hoja:
		s.flip_h = smer == "zahod"
		s.scale = Vector2.ONE * 0.27
		s.position = Vector2(0, 4.0 - (384.0 - 192.0) * 0.27)
	else:
		s.flip_h = false
		s.scale = Vector2.ONE * 0.42
		s.position = Vector2(0, 4.0 - (256.0 - 128.0) * 0.42)
static func _ustvari_okvirje() -> SpriteFrames:
	var r := SpriteFrames.new(); r.remove_animation("default")
	for vrstica in 4:
		# Vzhod in zahod imata vsak svojo narisano vrstico. Prej je bil zahod samo
		# zrcaljen vzhod, kar je pri ščitu, sekiri in korakih povzročilo drsenje.
		var smer := SMERI[vrstica]; var vidna := vrstica
		for p in ["idle_", "walk_", "attack_"]: r.add_animation(p + smer)
		r.set_animation_loop("idle_" + smer, false); r.add_frame("idle_" + smer, _izrez_idle(vrstica))
		r.set_animation_loop("walk_" + smer, true)
		if smer == "vzhod" or smer == "zahod":
			for x in 4: r.add_frame("walk_" + smer, _izrez_bocne_hoje(x))
		else:
			for x in 4: r.add_frame("walk_" + smer, _izrez(x, vidna))
		r.set_animation_loop("attack_" + smer, false); r.set_animation_speed("attack_" + smer, 6.5)
		# Srednji vodoravni zamah je v izvorni grafiki segel v sosednjo celico in
		# ustvaril belo packo. Tri čiste faze ohranijo udarec brez spremembe merila.
		for x in [4, 5, 7]: r.add_frame("attack_" + smer, _izrez(x, vidna))
	return r
static func _izrez(x: int, y: int) -> AtlasTexture:
	var a := AtlasTexture.new(); a.atlas = TEKSTURA; a.region = Rect2(x * 192, y * 256, 192, 256); return a
static func _izrez_idle(x: int) -> AtlasTexture:
	var a := AtlasTexture.new(); a.atlas = TEKSTURA_IDLE; a.region = Rect2(x * 192, 0, 192, 256); return a
static func _izrez_bocne_hoje(x: int) -> AtlasTexture:
	var a := AtlasTexture.new(); a.atlas = TEKSTURA_BOCNA_HOJA; a.region = Rect2(x * 256, 0, 256, 384); return a
